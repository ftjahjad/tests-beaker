#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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
#   library-prefix = RpmSnapshot
#   library-version = 10
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_RpmSnapshot_LIB_VERSION=10
: <<'=cut'
=pod

=head1 NAME

BeakerLib library RpmSnapshot

=head1 DESCRIPTION

This library provide snapshoting functionality for rpm installed on the system.

=head1 USAGE

To use this functionality you need to import library distribution/RpmSnapshot and
add following line to Makefile.

	@echo "RhtsRequires:    library(distribution/RpmSnapshot)" >> $(METADATA)

And in the code to include rlImport distribution/RpmSnapshot or just
I<rlImport --all> to import all libraries specified in Makelife.

B<Code example>

	RpmSnapshotCreate  [RPM_SNAPSHOT]
	yum update -y
	RpmSnapshotRevert  [RPM_SNAPSHOT]
	RpmSnapshotDiscard [RPM_SNAPSHOT]

RPM_SNAPSHOT is a file which is or will be containing a list of rpms.

There is also a global variable RPM_SNAPSHOT which can be used for nested
snapshoting a reverting.

=head1 FUNCTIONS

=cut

echo -n "loading library RpmSnapshot v$__INTERNAL_RpmSnapshot_LIB_VERSION... "


# __INTERNAL_RpmSnapshot_get_rpm_list ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_RpmSnapshot_get_rpm_list() {
  rpm -qa --qf "%{NAME} %{VERSION} %{RELEASE} %{ARCH} %{sourcerpm}\n" | grep -vF '(none)' | sort | uniq
  local res=$PIPESTATUS
  [[ $res -ne 0 ]] && rlLogError "could not get list of packages!"
  return $res
}; # end of __INTERNAL_RpmSnapshot_get_rpm_list }}}


# __INTERNAL_RpmSnapshot_show_diff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_RpmSnapshot_show_diff() {
  diff -U0 $1 $2 | tail -n +3 |grep -e '^[+-]'
}; # end of __INTERNAL_RpmSnapshot_show_diff }}}


# RpmSnapshotCreate ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
RpmSnapshotCreate() {
  local res=0
  rlLog "Making packages snapshot"
  RPM_SNAPSHOT="${1:-$(mktemp)}"
  rlLog "Creating snapshot $RPM_SNAPSHOT"
  __INTERNAL_RpmSnapshot_get_rpm_list > "$RPM_SNAPSHOT" || let res++
  rlLogDebug "$FUNCNAME(): current pakages are $(cat "$RPM_SNAPSHOT")"
  rlLog "Snapshot is saved in RPM_SNAPSHOT='$RPM_SNAPSHOT'"
  return $res
}; # end of RpmSnapshotCreate }}}


# Function stripped of its functionality in upstream version of lib
# __INTERNAL_RpmSnapshot_GetRpmPathInMnt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_RpmSnapshot_GetRpmPathInMnt() {
  rlLogDebug "$FUNCNAME(): begin $*"
  rlLogWarning "Function always returns error in this version of library"
  RpmSnapshot_GetRpmPathInMnt="ERROR"
  return 1
}; # end of __INTERNAL_RpmSnapshot_GetRpmPathInMnt }}}


# RpmSnapshotRevert ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
RpmSnapshotRevert() {
  local s="${1:-$RPM_SNAPSHOT}"
  local res=0
  if [[ -r "$s" ]]; then
    rlLog "Restore packages state from snapshot $s"
      local revert tmpdir=`mktemp -d -t RpmSnpsht-XXXXX` N V R A SRC
      local tmp="$tmpdir/tmp" tmp2="$tmpdir/tmp2" install="$tmpdir/install" remove="$tmpdir/remove" upgrade="$tmpdir/upgrade"
      rlLogDebug "$FUNCNAME(): using tmpdir='$tmpdir'"
      __INTERNAL_RpmSnapshot_get_rpm_list > $tmp || let res++
      rlLogDebug "$FUNCNAME(): current pakages are `cat $tmp`"
      __INTERNAL_RpmSnapshot_show_diff $s $tmp >$tmp2
      rlLogDebug "$FUNCNAME(): diff against snapshot is `cat $tmp2`"
      grep '^+' $tmp2 | sed -e 's/^.\([0-9]\+:\)\?//' >$remove
      grep '^-' $tmp2 | sed -e 's/^.\([0-9]\+:\)\?//' >$tmp
      rlLogDebug "$FUNCNAME(): for inspection `cat $tmp`"
      cat $tmp | while IFS=' ' read N V R A SRC; do
        rlLogDebug "$FUNCNAME(): checking $N $V $R $A, source package $SRC"
        if grep -qE "^${N} \S+ \S+ $A " $remove; then
          rlLogDebug "$FUNCNAME(): found $N in new set"
          rlLogDebug "$FUNCNAME(): unmarking $N from removals"
          sed -ri "/^${N} \S+ \S+ $A /d" $remove
          if __INTERNAL_RpmSnapshot_GetRpmPathInMnt $N $V $R $A $SRC; then
            rlLogDebug "$FUNCNAME(): marking $N $V $R $A for up/down-grade"
            echo "$RpmSnapshot_GetRpmPathInMnt" >> $upgrade
          else
            rlLogDebug "$FUNCNAME(): marking $N $V $R $A for up/down-grade by yum"
            echo "$N-$V-$R.$A" >> $upgrade.yum
          fi
        else
          rlLogDebug "$FUNCNAME(): not found $N $V $R $A in new set"
          if __INTERNAL_RpmSnapshot_GetRpmPathInMnt $N $V $R $A $SRC; then
            rlLogDebug "$FUNCNAME(): marking $N $V $R $A for install"
            echo "$RpmSnapshot_GetRpmPathInMnt" >> $install
          else
            rlLogDebug "$FUNCNAME(): marking $N $V $R $A for install by yum"
            echo "$N-$V-$R.$A" >> $install.yum
          fi
        fi
      done

      [[ -s $remove ]] && {
        rlLog "rpm -e --nodeps ..."
        local rpackages=''
        while IFS=' ' read N V R A SRC; do
          rpackages="$rpackages $N-$V-$R.$A"
        done < "$remove"
        echo "Packages to be removed: $rpackages"
        rlLogDebug "$FUNCNAME(): acctually running rpm -e --nodeps $rpackages"
        eval "rpm -e --nodeps $rpackages"
      }
      [[ -s $install ]] &&{
        rlLog "rpm -ivh --nodeps ..."
        echo "Packages to be installed: `cat $install`"
        rpm -ivh --nodeps `cat $install`
      }
      [[ -s $install.yum ]] &&{
        rlLog "yum install -y ..."
        echo "Packages to be installed using yum: `cat $install.yum`"
        yum install -y `cat $install.yum`
      }
      [[ -s $upgrade ]] &&{
        rlLog "rpm -Uvh --nodeps ..."
        echo "Packages to be up/down-graded: `cat $upgrade`"
        rpm -Uvh --nodeps --oldpackage `cat $upgrade`
      }
      [[ -s $upgrade.yum ]] &&{
        echo "Packages to be up/down-graded `cat $upgrade.yum`"
        rlLog "yum install -y ..."
        yum install -y `cat $upgrade.yum`
        rlLog "yum downgrade -y ..."
        yum downgrade -y `cat $upgrade.yum`
      }
      rlLog "Check state after restore"
      __INTERNAL_RpmSnapshot_get_rpm_list > $tmp
      ! __INTERNAL_RpmSnapshot_show_diff $s $tmp || let res++
      rm -rf $tmpdir
  else
    rlLogError "No snapshot available!"
    let res++
  fi
  return $res
}; # end of RpmSnapshotRevert }}}


# RpmSnapshotDiscard ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
RpmSnapshotDiscard() {
  local s="${1:-$RPM_SNAPSHOT}"
  local res=0
  [[ -z "$1" ]] && unset RPM_SNAPSHOT
  if [[ -r "$s" ]]; then
    rm -f $s
  else
    rlLogError "No snapshot available!"
    let res++
  fi
  return $res
}; # end of RpmSnapshotDiscard }}}


# RpmSnapshotShowDiff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
RpmSnapshotShowDiff() {
  local s="${1:-$RPM_SNAPSHOT}"
  if [[ -r "$s" ]]; then
    local tmp=`mktemp`
    __INTERNAL_RpmSnapshot_get_rpm_list > $tmp
    __INTERNAL_RpmSnapshot_show_diff $s $tmp
    rm -f $tmp
  else
    rlLog "No snapshot available!"
  fi
}; # end of RpmSnapshotShowDiff }}}


# RpmSnapshotLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
RpmSnapshotLibraryLoaded() {
  which rpm &>/dev/null || {
    rlLogError "rpm not found"
    return 1
  }
  return 0
}; # end of RpmSnapshotLibraryLoaded }}}


echo "done."

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

