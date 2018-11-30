#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of kernel/networking/route/mr
#   Description:  Multicast routing testing
#   Author: Jianlin Shi<jishi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. ./common/include.sh || exit 1
. ./common/install.sh || exit 1

# Functions



# Parameters
TEST_TYPE=${TEST_TYPE:-"netns"}
TEST_TOPO=${TEST_TOPO:-"default"}
SEC_TYPE=${SEC_TYPE:-"nosec ipsec"}


. ./include.sh || exit 1


TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}
rlJournalStart

rlPhaseStartSetup
    rlRun "iproute_upstream_install"
    # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
    if [ $? -ne 0 ] && [ "$CI" = "yes" ]; then
        report_result $TEST WARN
        rhts-abort -t recipe
    fi

    rlRun "netperf_install"
    # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
    if [ $? -ne 0 ] && [ "$CI" = "yes" ]; then
        report_result $TEST WARN
        rhts-abort -t recipe
    fi

    rlLog "items include:$TEST_ITEMS"
rlPhaseEnd

for DO_SEC in $SEC_TYPE
do
    pmtu_test
done

rlJournalEnd
