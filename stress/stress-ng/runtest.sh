#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/stress/stress-ng
#   Description: Run stress-ng test
#   Author: Jeff Bastian <jbastian@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# include beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart
BUILDDIR="stress-ng"

# task parameters
TIMEOUT=${TIMEOUT:-30}
#LOOKASIDE=${LOOKASIDE:-http://download.eng.bos.redhat.com/qa/rhts/lookaside/}
EXTRA_FLAGS=${EXTRA_FLAGS:-}
CLASSES=${CLASSES:-interrupt cpu cpu-cache memory os}

# - stress-ng git location
GIT_URL=${GIT_URL:-"git://kernel.ubuntu.com/cking/stress-ng.git"}
# Optional test git branch
#GIT_BRANCH=${GIT_BRANCH:-"master"}
GIT_BRANCH=${GIT_BRANCH:-"tags/V0.09.56"}

#EXCLUDE_CPU=""
#EXCLUDE_OS=""
#ARCH=`uname -m`
#case ${ARCH} in
#    (x86_64)
#        EXCLUDE_CPU="-exclude cpu-online"
#        EXCLUDE_OS="--exclude chroot,cpu-online,dnotify,inode-flags,mmapaddr,mmapfixed,quota,rlimit,spawn,swap"
#        ;;
#esac
###############################3
# exclude specific tests from the classes
# cpu hotplug testing is handled in other Beaker tasks
#EXCLUDE_CPU="--exclude cpu-online"
#EXCLUDE_OS="--exclude cpu-online"
# RHEL uses SELinux, not AppArmor
#EXCLUDE_OS="${EXCLUDE_OS},apparmor"
# tests which trigger SELinux AVCs
#EXCLUDE_OS="${EXCLUDE_OS},mmapaddr,mmapfixed"
# tests which report fail
#EXCLUDE_OS="${EXCLUDE_OS},dnotify"
# tests which report error
#EXCLUDE_OS="${EXCLUDE_OS},bind-mount,exec,inode-flags,mlockmany,oom-pipe,spawn,swap,watchdog"
# systemd-coredump does not like these stressors
#EXCLUDE_OS="${EXCLUDE_OS},bad-altstack,opcode"
# architecture specific excludes
#ARCH=`uname -m`
#case ${ARCH} in
#    aarch64)
#        ;;
#    ppc64|ppc64le)
#        # POWER does not have UEFI firmware
#        EXCLUDE_OS="${EXCLUDE_OS},efivar"
#        ;;
#    s390x)
#        # System z does not have UEFI firmware
#        EXCLUDE_OS="${EXCLUDE_OS},efivar"
#        ;;
#    x86_64)
#        # x86 may have either UEFI or Legacy BIOS
#        if [ ! -d /sys/firmware/efi/vars ] ; then
#            EXCLUDE_OS="${EXCLUDE_OS},efivar"
#        fi
#        ;;
#    *)
#        ;;
#esac
######################################################3

# initialize test exclusion lists
# NOTE: be sure to use the += operator to append to the exclusion list!!!
EXCLUDE=""
# cpu hotplug testing is handled in other Beaker tasks
EXCLUDE+=",cpu-online"
# RHEL uses SELinux, not AppArmor
EXCLUDE+=",apparmor"
# tests which trigger SELinux AVCs
EXCLUDE+=",mmapaddr,mmapfixed"
# tests which report fail
EXCLUDE+=",dnotify"
# tests which report error
EXCLUDE+=",bind-mount,exec,inode-flags,mlockmany,oom-pipe,spawn,swap,watchdog,dirdeep"
# systemd-coredump does not like these stressors
EXCLUDE+=",bad-altstack,opcode"
# fanotify fails on systems with many CPUs (>128?):
#     cannot initialize fanotify, errno=24 (Too many open files)
EXCLUDE+=",fanotify"
# architecture specific excludes
ARCH=`uname -m`
case ${ARCH} in
    aarch64)
        # clone invokes oom-killer loop
        EXCLUDE+=",clone"
        ;;
    ppc64|ppc64le)
        # POWER does not have UEFI firmware
        EXCLUDE+=",efivar"
        # kill locks up the kernel on ppc64(le)
        EXCLUDE+=",kill"
        ;;
    s390x)
        # System z does not have UEFI firmware
        EXCLUDE+=",efivar"
        # dev test gets stuck in uninterruptible I/O (state D)
        EXCLUDE+=",dev"
        ;;
    x86_64)
        # x86 may have either UEFI or Legacy BIOS
        if [ ! -d /sys/firmware/efi/vars ] ; then
            EXCLUDE+=",efivar"
        fi
        ;;
esac
# finally, strip any leading or trailing commas
EXCLUDE=$(sed -e 's/^,//' -e 's/,$//' <<<$EXCLUDE)

rlPhaseStartSetup
    rlLog "Downloading stress-ng from source"
    rlRun "git clone $GIT_URL" 0
    if [ $? != 0 ]; then
        echo "Failed to git clone $GIT_URL." | tee -a $OUTPUTFILE
        rhts-report-result $TEST WARN $OUTPUTFILE
        rhts-abort -t recipe
    fi

    # build
    rlLog "Building stress-ng from source"
    rlRun "pushd stress-ng" 0 
    rlRun "git checkout $GIT_BRANCH" 0
    rlRun "make" 0 "Building stress-ng"
    rlRun "popd" 0 "Done building stress-ng"

#    if [ -f /lib/systemd/systemd ] ; then
#        if [ ! -d /etc/systemd/coredump.conf.d ] ; then
#            mkdir /etc/systemd/coredump.conf.d
#        fi
#        cat >/etc/systemd/coredump.conf.d/stress-ng.conf <<EOF
#[Coredump]
#Storage=none
#ProcessSizeMax=0
#EOF
#        systemctl restart systemd-coredump.socket
#    fi
##############################################
    #disable systemd-coredump collection
    if [ -f /lib/systemd/systemd ] ; then
        rlLog "Disabling systemd-coredump collection"
        if [ ! -d /etc/systemd/coredump.conf.d ] ; then
            mkdir /etc/systemd/coredump.conf.d
        fi
        cat >/etc/systemd/coredump.conf.d/stress-ng.conf <<EOF
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
        rlRun "systemctl mask --now systemd-coredump.socket" 0 "Masking and stopping systemd-coredump.socket"
    fi
rlPhaseEnd

rlPhaseStartTest
#    FLAGS="--all 0 --timeout 300 --verbose"
#    FLAGS="--sequential 0 --timeout 300 --verbose"
#    FLAGS="--all 0 --timeout 30 --verbose"
#    FLAGS="--sequential 0 --timeout 30 --verbose"
#    rlRun "${BUILDDIR}/stress-ng --class interrupt ${FLAGS}" 0 "Running stress-ng on class interrupt for 5 minutes"
#    rlRun "${BUILDDIR}/stress-ng --class cpu       ${FLAGS} ${EXCLUDE_CPU}" 0 "Running stress-ng on class cpu for 5 minutes"
#    rlRun "${BUILDDIR}/stress-ng --class cpu-cache ${FLAGS}" 0 "Running stress-ng on class cpu-cache for 5 minutes"
#    rlRun "${BUILDDIR}/stress-ng --class memory    ${FLAGS}" 0 "Running stress-ng on class memory for 5 minutes"
#    rlRun "${BUILDDIR}/stress-ng --class os        ${FLAGS} ${EXCLUDE_OS}" 0 "Running stress-ng on class os for 5 minutes"
#
#    for CLASS in ${CLASSES} ; do
#        FLAGS="--class ${CLASS} --sequential 0 --timeout ${TIMEOUT} --log-file ${CLASS}.log ${EXTRA_FLAGS}"
#        case ${CLASS} in
#            cpu)
#                FLAGS="${FLAGS} ${EXCLUDE_CPU}"
#                ;;
#            os)
#                FLAGS="${FLAGS} ${EXCLUDE_OS}"
#                ;;
#        esac
#
#        rlRun "${BUILDDIR}/stress-ng ${FLAGS}" \
#            0 "Running stress-ng on class ${CLASS} for ${TIMEOUT} seconds per stressor"
#
#        RESULT="PASS"
#        if [ $? -ne 0 ] ; then
#            RESULT="FAIL"
#        fi
#
#        rlReport "Class ${CLASS}" ${RESULT} 0 ${CLASS}.log
#    done
#################################################################################
    for CLASS in ${CLASSES} ; do
        FLAGS="--class ${CLASS} --sequential 0 --timeout ${TIMEOUT} --log-file ${CLASS}.log ${EXTRA_FLAGS}"
        if [ -n "${EXCLUDE}" ]; then
            FLAGS="${FLAGS} --exclude ${EXCLUDE}"
        fi

        rlRun "${BUILDDIR}/stress-ng ${FLAGS}" \
            0 "Running stress-ng on class ${CLASS} for ${TIMEOUT} seconds per stressor"
        RET=$?

        RESULT="PASS"
        if [ $RET -ne 0 ] ; then
            RESULT="FAIL"
        fi

        rlReport "Class ${CLASS}" ${RESULT} 0 ${CLASS}.log
    done
rlPhaseEnd

rlPhaseStartCleanup
    # restore default systemd-coredump config
    if [ -f /lib/systemd/systemd ] ; then
        rm -f /etc/systemd/coredump.conf.d/stress-ng.conf
        rlRun "systemctl unmask systemd-coredump.socket" 0 "Unmasking systemd-coredump.socket"
        rlRun "systemctl start systemd-coredump.socket" 0 "Restarting systemd-coredump.socket"
    fi
rlPhaseEnd

rlPhaseStartCleanup
    # do something
    # restore default systemd-coredump config
    #if [ -f /lib/systemd/systemd ] ; then
    #    rm -f /etc/systemd/coredump.conf.d/stress-ng.conf
    #    systemctl restart systemd-coredump.socket
    #fi
################################################333
    if [ -f /lib/systemd/systemd ] ; then
        rm -f /etc/systemd/coredump.conf.d/stress-ng.conf
        rlRun "systemctl unmask systemd-coredump.socket" 0 "Unmasking systemd-coredump.socket"
        rlRun "systemctl start systemd-coredump.socket" 0 "Restarting systemd-coredump.socket"
    fi
rlPhaseEnd

rlJournalPrintText
rlJournalEnd
