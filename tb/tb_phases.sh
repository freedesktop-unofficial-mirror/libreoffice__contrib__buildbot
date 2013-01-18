#!/usr/bin/env bash
# -*- tab-width : 4; indent-tabs-mode : nil -*-
#
#    Copyright (C) 2011-2013 Norbert Thiebaud
#    License: GPLv3
#

pre_autogen()
{
    if [ "${R}" = "0" ] ; then
        if [ ! -f autogen.lastrun -o "${tb_KEEP_AUTOGEN}" != "YES" ] ; then
            copy_autogen_config
        fi
    fi
}

do_autogen()
{
    if [ "${R}" = "0" ] ; then
        if ! ${TB_NICE} ./autogen.sh >tb_${B}_autogen.log 2>&1 ; then
            tb_REPORT_LOG=tb_${B}_autogen.log
            tb_REPORT_MSGS="autogen/configure failed - error is:"
            R=1
        fi
    fi
}

pre_clean()
{
    if [ "${R}" = "0" ] ; then
        true # log files to clean, if any
    fi
}

do_clean()
{
    if [ "${R}" = "0" ] ; then
        if ! ${TB_NICE} ${TB_WATCHDOG} ${MAKE?} -sr clean > "tb_${B?}_clean.log" 2>&1 ; then
            tb_REPORT_LOG="tb_${B?}_clean.log"
            tb_REPORT_MSGS"cleaning up failed - error is:"
            R=1
        fi
    fi
}

do_make()
{
local current_timestamp=
local optdir=""
local extra_buildid=""

    tb_OPT_DIR=""
    if [ "${tb_BUILD_TYPE?}" = "tb" ] ; then
        current_timestamp=$(sed -e "s/ /_/" "${TB_METADATA_DIR?}/tb_${B}_current-git-timestamp.log")
        extra_buildid="TinderBox: ${TB_NAME?}, Branch:${B}, Time: $current_timestamp"
    fi
    if [ "${R}" = "0" ] ; then
        if ! ${TB_NICE} ${TB_WATCHDOG} ${MAKE?} EXTRA_BUILDID="$extra_buildid" -sr > "tb_${B?}_build.log" 2>&1 ; then
            tb_REPORT_LOG="tb_${B?}_build.log"
            tb_REPORT_MSGS="build failed - error is:"
            R=1
        else
            # if we want to populate bibisect we need to 'install'
            if [ "${tb_BUILD_TYPE?}" = "tb" -a ${TB_BIBISECT} != "0" ] ; then
                if ! ${TB_NICE} ${TB_WATCHDOG} ${MAKE?} EXTRA_BUILDID="${extra_buildid}" -sr install-tb >>"tb_${B?}_build.log" 2>&1 ; then
                    tb_REPORT_LOG="tb_${B}_build.log"
                    tb_REPORT_MSGS="build failed - error is:"
                    R=1
                else
                    tb_OPT_DIR="$(find_dev_install_location)"
                fi
            fi
        fi
    fi
}


do_test()
{
    if [ "${R}" = "0" ] ; then
        if [ "${TB_DO_TESTS}" = "1" ] ; then
            if ! ${TB_NICE_CPU} ${TB_NICE_IO} ${TB_WATCHDOG} ${MAKE?} -sr check > "tb_${B?}_tests.log" 2>&1 ; then
                tb_REPORT_LOG="tb_${B?}_tests.log"
                tb_REPORT_MSGS="check failed - error is:"
                R=1
            fi
        fi
    fi
}

post_make()
{
    if [ "${tb_BUILD_TYPE?}" = "tb" ] ; then
        if [ "${R}" != "0" ] ; then
            if [ -f "${tb_REPORT_LOG?}" ] ; then
                if [ -f "${TB_PROFILE_DIR?}/${B?}/false_negatives" ] ; then
                    grep -F "$(cat "${TB_PROFILE_DIR?}/${B?}/false_negatives")" "${tb_REPORT_LOG?}" && R="2"
                    if [ "${R?}" == "2" ] ; then
                        log_msgs "False negative detected"
                    fi
                elif [ -f "${TB_PROFILE_DIR?}/false_negatives" ] ; then
                    grep -F "$(cat "${TB_PROFILE_DIR?}/false_negatives")" "${tb_REPORT_LOG?}" && R="2"
                    if [ "${R?}" == "2" ] ; then
                        log_msgs "False negative detected"
                    fi
                fi
            fi
        fi
    fi
}

do_push()
{
    [ $V ] && echo "Push: phase starting"

    if [ "${R}" != "0" ] ; then
        return 0;
    fi

    if [ "${tb_BUILD_TYPE?}" = "tb" ] ; then
        # Push nightly build if needed
        if [ "$TB_PUSH_NIGHTLIES" = "1" ] ; then
            push_nightly
        fi
        # Push bibisect to remote bibisect if needed
        if [ "$TB_BIBISECT" = "1" ] ; then
            push_bibisect
        fi
    fi
    return 0;
}

tb_call()
{
    [ $V ] && declare -F "$1" > /dev/null && echo "call $1"
    declare -F "$1" > /dev/null && $1
}

phase()
{
    local f=${1}
    for x in {pre_,do_,post_}${f} ; do
        tb_call ${x}
    done
}


do_build()
{
    local phases="$@"
    local p
    [ $V ] && echo "do_build (${tb_BUILD_TYPE?}) phase_list=${phases?}"

    for p in ${phases?} ; do
        [ $V ] && echo "phase $p"
        phase $p
    done

}
