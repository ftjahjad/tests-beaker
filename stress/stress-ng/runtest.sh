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

# Optional test parameters - stress-ng git location
GIT_URL=${GIT_URL:-"git://kernel.ubuntu.com/cking/stress-ng.git"}
# Optional test git branch
#GIT_BRANCH=${GIT_BRANCH:-"master"}
GIT_BRANCH=${GIT_BRANCH:-"tags/V0.09.56"}

rlJournalStart
BUILDDIR="stress-ng"

EXCLUDE_CPU=""
EXCLUDE_OS=""
ARCH=`uname -m`
case ${ARCH} in
    (x86_64)
        EXCLUDE_CPU="-x cpu-online"
        EXCLUDE_OS="-x cpu-online,rlimit,quota,"
        ;;
esac

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
rlPhaseEnd

rlPhaseStartTest
#    FLAGS="--all 0 --timeout 300 --verbose"
#    FLAGS="--sequential 0 --timeout 300 --verbose"
    FLAGS="--all 0 --timeout 30 --verbose"
    rlRun "${BUILDDIR}/stress-ng --class interrupt ${FLAGS}" 0 "Running stress-ng on class interrupt for 5 minutes"
    rlRun "${BUILDDIR}/stress-ng --class cpu       ${FLAGS} ${EXCLUDE_CPU}" 0 "Running stress-ng on class cpu for 5 minutes"
    rlRun "${BUILDDIR}/stress-ng --class cpu-cache ${FLAGS}" 0 "Running stress-ng on class cpu-cache for 5 minutes"
    rlRun "${BUILDDIR}/stress-ng --class memory    ${FLAGS}" 0 "Running stress-ng on class memory for 5 minutes"
    rlRun "${BUILDDIR}/stress-ng --class os        ${FLAGS} ${EXCLUDE_OS}" 0 "Running stress-ng on class os for 5 minutes"

rlPhaseEnd

rlPhaseStartCleanup
    # do something
rlPhaseEnd

rlJournalPrintText
rlJournalEnd
