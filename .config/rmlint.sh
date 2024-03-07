#!/bin/sh

PROGRESS_CURR=0
PROGRESS_TOTAL=207                         

# This file was autowritten by rmlint
# rmlint was executed from: /home/buidai289/.config/
# Your command line was: rmlint

RMLINT_BINARY="/usr/bin/rmlint"

# Only use sudo if we're not root yet:
# (See: https://github.com/sahib/rmlint/issues/27://github.com/sahib/rmlint/issues/271)
SUDO_COMMAND="sudo"
if [ "$(id -u)" -eq "0" ]
then
  SUDO_COMMAND=""
fi

USER='root'
GROUP='root'

# Set to true on -n
DO_DRY_RUN=

# Set to true on -p
DO_PARANOID_CHECK=

# Set to true on -r
DO_CLONE_READONLY=

# Set to true on -q
DO_SHOW_PROGRESS=true

# Set to true on -c
DO_DELETE_EMPTY_DIRS=

# Set to true on -k
DO_KEEP_DIR_TIMESTAMPS=

# Set to true on -i
DO_ASK_BEFORE_DELETE=

##################################
# GENERAL LINT HANDLER FUNCTIONS #
##################################

COL_RED='[0;31m'
COL_BLUE='[1;34m'
COL_GREEN='[0;32m'
COL_YELLOW='[0;33m'
COL_RESET='[0m'

print_progress_prefix() {
    if [ -n "$DO_SHOW_PROGRESS" ]; then
        PROGRESS_PERC=0
        if [ $((PROGRESS_TOTAL)) -gt 0 ]; then
            PROGRESS_PERC=$((PROGRESS_CURR * 100 / PROGRESS_TOTAL))
        fi
        printf '%s[%3d%%]%s ' "${COL_BLUE}" "$PROGRESS_PERC" "${COL_RESET}"
        if [ $# -eq "1" ]; then
            PROGRESS_CURR=$((PROGRESS_CURR+$1))
        else
            PROGRESS_CURR=$((PROGRESS_CURR+1))
        fi
    fi
}

handle_emptyfile() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty file:${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_emptydir() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty directory: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rmdir "$1"
    fi
}

handle_bad_symlink() {
    print_progress_prefix
    echo "${COL_GREEN} Deleting symlink pointing nowhere: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_unstripped_binary() {
    print_progress_prefix
    echo "${COL_GREEN} Stripping debug symbols of: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        strip -s "$1"
    fi
}

handle_bad_user_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER" "$1"
    fi
}

handle_bad_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chgrp ${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chgrp "$GROUP" "$1"
    fi
}

handle_bad_user_and_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}:${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER:$GROUP" "$1"
    fi
}

###############################
# DUPLICATE HANDLER FUNCTIONS #
###############################

check_for_equality() {
    if [ -f "$1" ]; then
        # Use the more lightweight builtin `cmp` for regular files:
        cmp -s "$1" "$2"
        echo $?
    else
        # Fallback to `rmlint --equal` for directories:
        "$RMLINT_BINARY" -p --equal  "$1" "$2"
        echo $?
    fi
}

original_check() {
    if [ ! -e "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo "${COL_RED}^^^^^^ Error: duplicate has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    # Check they are not the exact same file (hardlinks allowed):
    if [ "$1" = "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original and duplicate point to the *same* path - cancelling.....${COL_RESET}"
        return 1
    fi

    # Do double-check if requested:
    if [ -z "$DO_PARANOID_CHECK" ]; then
        return 0
    else
        if [ "$(check_for_equality "$1" "$2")" -ne "0" ]; then
            echo "${COL_RED}^^^^^^ Error: files no longer identical - cancelling.....${COL_RESET}"
            return 1
        fi
    fi
}

cp_symlink() {
    print_progress_prefix
    echo "${COL_YELLOW}Symlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with symlink
            rm -rf "$1"
            ln -s "$2" "$1"
            # make the symlink's mtime the same as the original
            touch -mr "$2" -h "$1"
        fi
    fi
}

cp_hardlink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't hardlink so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    echo "${COL_YELLOW}Hardlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with hardlink
            rm -rf "$1"
            ln "$2" "$1"
        fi
    fi
}

cp_reflink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't clone so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    # reflink $1 to $2's data, preserving $1's  mtime
    echo "${COL_YELLOW}Reflinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            touch -mr "$1" "$0"
            if [ -d "$1" ]; then
                rm -rf "$1"
            fi
            cp --archive --reflink=always "$2" "$1"
            touch -mr "$0" "$1"
        fi
    fi
}

clone() {
    print_progress_prefix
    # clone $1 from $2's data
    # note: no original_check() call because rmlint --dedupe takes care of this
    echo "${COL_YELLOW}Cloning to: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        if [ -n "$DO_CLONE_READONLY" ]; then
            $SUDO_COMMAND $RMLINT_BINARY --dedupe  --dedupe-readonly "$2" "$1"
        else
            $RMLINT_BINARY --dedupe  "$2" "$1"
        fi
    fi
}

skip_hardlink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already hardlinked to original): ${COL_RESET}$1"
}

skip_reflink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already reflinked to original): ${COL_RESET}$1"
}

user_command() {
    print_progress_prefix

    echo "${COL_YELLOW}Executing user command: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        # You can define this function to do what you want:
        echo 'no user command defined.'
    fi
}

remove_cmd() {
    print_progress_prefix
    echo "${COL_YELLOW}Deleting: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            if [ -n "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                touch -r "$(dirname "$1")" "$STAMPFILE"
            fi
            if [ -n "$DO_ASK_BEFORE_DELETE" ]; then
              rm -ri "$1"
            else
              rm -rf "$1"
            fi
            if [ -n "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                # Swap back old directory timestamp:
                touch -r "$STAMPFILE" "$(dirname "$1")"
                rm "$STAMPFILE"
            fi

            if [ -n "$DO_DELETE_EMPTY_DIRS" ]; then
                DIR=$(dirname "$1")
                while [ ! "$(ls -A "$DIR")" ]; do
                    print_progress_prefix 0
                    echo "${COL_GREEN}Deleting resulting empty dir: ${COL_RESET}$DIR"
                    rmdir "$DIR"
                    DIR=$(dirname "$DIR")
                done
            fi
        fi
    fi
}

original_cmd() {
    print_progress_prefix
    echo "${COL_GREEN}Keeping:  ${COL_RESET}$1"
}

##################
# OPTION PARSING #
##################

ask() {
    cat << EOF

This script will delete certain files rmlint found.
It is highly advisable to view the script first!

Rmlint was executed in the following way:

   $ rmlint

Execute this script with -d to disable this informational message.
Type any string to continue; CTRL-C, Enter or CTRL-D to abort immediately
EOF
    read -r eof_check
    if [ -z "$eof_check" ]
    then
        # Count Ctrl-D and Enter as aborted too.
        echo "${COL_RED}Aborted on behalf of the user.${COL_RESET}"
        exit 1;
    fi
}

usage() {
    cat << EOF
usage: $0 OPTIONS

OPTIONS:

  -h   Show this message.
  -d   Do not ask before running.
  -x   Keep rmlint.sh; do not autodelete it.
  -p   Recheck that files are still identical before removing duplicates.
  -r   Allow deduplication of files on read-only btrfs snapshots. (requires sudo)
  -n   Do not perform any modifications, just print what would be done. (implies -d and -x)
  -c   Clean up empty directories while deleting duplicates.
  -q   Do not show progress.
  -k   Keep the timestamp of directories when removing duplicates.
  -i   Ask before deleting each file
EOF
}

DO_REMOVE=
DO_ASK=

while getopts "dhxnrpqcki" OPTION
do
  case $OPTION in
     h)
       usage
       exit 0
       ;;
     d)
       DO_ASK=false
       ;;
     x)
       DO_REMOVE=false
       ;;
     n)
       DO_DRY_RUN=true
       DO_REMOVE=false
       DO_ASK=false
       DO_ASK_BEFORE_DELETE=false
       ;;
     r)
       DO_CLONE_READONLY=true
       ;;
     p)
       DO_PARANOID_CHECK=true
       ;;
     c)
       DO_DELETE_EMPTY_DIRS=true
       ;;
     q)
       DO_SHOW_PROGRESS=
       ;;
     k)
       DO_KEEP_DIR_TIMESTAMPS=true
       STAMPFILE=$(mktemp 'rmlint.XXXXXXXX.stamp')
       ;;
     i)
       DO_ASK_BEFORE_DELETE=true
       ;;
     *)
       usage
       exit 1
  esac
done

if [ -z $DO_REMOVE ]
then
    echo "#${COL_YELLOW} ///${COL_RESET}This script will be deleted after it runs${COL_YELLOW}///${COL_RESET}"
fi

if [ -z $DO_ASK ]
then
  usage
  ask
fi

if [ -n "$DO_DRY_RUN" ]
then
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
    echo "#${COL_YELLOW} /// ${COL_RESET} This is only a dry run; nothing will be modified! ${COL_YELLOW}///${COL_RESET}"
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
fi

######### START OF AUTOGENERATED OUTPUT #########

handle_bad_symlink '/home/buidai289/.config/chromium/SingletonLock' # bad symlink pointing nowhere
handle_bad_symlink '/home/buidai289/.config/chromium/SingletonCookie' # bad symlink pointing nowhere
handle_emptydir '/home/buidai289/.config/yay' # empty folder
handle_emptydir '/home/buidai289/.config/ranger' # empty folder
handle_emptydir '/home/buidai289/.config/gtk-3.0' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Webstore Downloads' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/NativeMessagingHosts' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/blob_storage/45210c7b-7e47-44f7-99cb-389c90634f48' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/blob_storage' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/Sync Extension Settings' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/Sync App Settings' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.youtube.com_0.indexeddb.blob/2/00' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.youtube.com_0.indexeddb.blob/2' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.youtube.com_0.indexeddb.blob' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Default/Download Service/Files' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Crash Reports/pending' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Crash Reports/new' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Crash Reports/completed' # empty folder
handle_emptydir '/home/buidai289/.config/chromium/Crash Reports/attachments' # empty folder
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/AvailabilityDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/8/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SegmentInfoDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/optimization_guide_hint_cache_store/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/PersistentOriginTrials/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/parcel_tracking_db/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Extension State/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SegmentInfoDB/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/GCM Store/Encryption/000003.log' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/MediaDeviceSalts-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_mega.nz_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/First Run' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/commerce_subscription_db/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SegmentInfoDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/commerce_subscription_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalStorageConfigDB/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/5/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/SharedStorage' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/EventDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/AutofillStrikeDatabase/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/File System/000/t/Paths/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/discounts_db/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/shared_proto_db/metadata/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/1/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/PersistentOriginTrials/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/discounts_db/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/chrome_cart_db/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/optimization_guide_hint_cache_store/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/16/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Login Data-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/coupon_db/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/9/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/first_party_sets.db-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/optimization_guide_hint_cache_store/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/File System/000/p/Paths/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Trust Tokens-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/BrowsingTopicsSiteData-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/9/IndexedDB/indexeddb.leveldb/000004.log' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Extension Rules/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Shared Dictionary/db-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Top Sites-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/VideoDecodeStats/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/parcel_tracking_db/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/7/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/BudgetDatabase/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/commerce_subscription_db/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/DIPS-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/VideoDecodeStats/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Reporting and NEL-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/shared_proto_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Sync Data/LevelDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_blog.desdelinux.net_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/GCM Store/Encryption/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/PersistentOriginTrials/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_developer.mozilla.org_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Affiliation Database-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Extension Cookies-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Favicons-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalStorageConfigDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/AutofillStrikeDatabase/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/chrome_cart_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/History-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Login Data For Account-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Safe Browsing Cookies-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/InterestGroups-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/AutofillStrikeDatabase/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Local Extension Settings/dmghijelimhndkbmpgbldicpogfkceaj/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Session Storage/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Cookies-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Shortcuts-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/coupon_db/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/AvailabilityDB/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Site Characteristics Database/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/segmentation_platform/ukm_db-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Download Service/EntryDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/13/IndexedDB/indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/coupon_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Network Action Predictor-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Extension Scripts/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalStorageConfigDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Service Worker/Database/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/VideoDecodeStats/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/parcel_tracking_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalDB/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/BudgetDatabase/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_fontawesome.com_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Local Storage/leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_blog.desdelinux.net_0.indexeddb.leveldb/000004.log' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/databases/Databases.db-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Download Service/EntryDB/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/PrivateAggregation-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/EventDB/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Download Service/EntryDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/5/IndexedDB/indexeddb.leveldb/000004.log' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/chrome_cart_db/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Web Data-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/File System/Origins/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.youtube.com_0.indexeddb.leveldb/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/heavy_ad_intervention_opt_out.db-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/discounts_db/LOCK' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/BudgetDatabase/LOG' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/AvailabilityDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Segmentation Platform/SignalDB/LOG.old' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/WebStorage/QuotaManager-journal' # empty file
handle_emptyfile '/home/buidai289/.config/chromium/Default/Feature Engagement Tracker/EventDB/LOG' # empty file

original_cmd  '/home/buidai289/.config/chromium/ShaderCache/data_0' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/DawnCache/data_0' '/home/buidai289/.config/chromium/ShaderCache/data_0' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/GraphiteDawnCache/data_0' '/home/buidai289/.config/chromium/ShaderCache/data_0' # duplicate

original_cmd  '/home/buidai289/.config/chromium/ShaderCache/data_3' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/DawnCache/data_3' '/home/buidai289/.config/chromium/ShaderCache/data_3' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/GraphiteDawnCache/data_3' '/home/buidai289/.config/chromium/ShaderCache/data_3' # duplicate

original_cmd  '/home/buidai289/.config/chromium/ShaderCache/data_2' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/DawnCache/data_2' '/home/buidai289/.config/chromium/ShaderCache/data_2' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/GraphiteDawnCache/data_2' '/home/buidai289/.config/chromium/ShaderCache/data_2' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/GrShaderCache/data_2' '/home/buidai289/.config/chromium/ShaderCache/data_2' # duplicate

original_cmd  '/home/buidai289/.config/pulse/0356b0d0853546859d339990ef74d373-default-sink' # original
remove_cmd    '/home/buidai289/.config/pulse/0356b0d0853546859d339990ef74d373-default-source' '/home/buidai289/.config/pulse/0356b0d0853546859d339990ef74d373-default-sink' # duplicate

original_cmd  '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-hi.hyb' # original
remove_cmd    '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-mr.hyb' '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-hi.hyb' # duplicate

original_cmd  '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-as.hyb' # original
remove_cmd    '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-bn.hyb' '/home/buidai289/.config/chromium/hyphen-data/120.0.6050.0/hyph-as.hyb' # duplicate

original_cmd  '/home/buidai289/.config/chromium/TrustTokenKeyCommitments/2024.1.2.1/LICENSE' # original
remove_cmd    '/home/buidai289/.config/chromium/CertificateRevocation/8579/LICENSE' '/home/buidai289/.config/chromium/TrustTokenKeyCommitments/2024.1.2.1/LICENSE' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/FirstPartySetsPreloaded/2024.2.28.0/LICENSE' '/home/buidai289/.config/chromium/TrustTokenKeyCommitments/2024.1.2.1/LICENSE' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/Shared Dictionary/cache/index' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/CacheStorage/379f1cbab5b08b6fc9e08681e42d8be311441c88/69ad51c2-afc9-4103-9dff-f4ae7868ac39/index' '/home/buidai289/.config/chromium/Default/Shared Dictionary/cache/index' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/ScriptCache/index' '/home/buidai289/.config/chromium/Default/Shared Dictionary/cache/index' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/CacheStorage/379f1cbab5b08b6fc9e08681e42d8be311441c88/4a08bf74-455e-4d2c-9384-1855cf8f6145/index' '/home/buidai289/.config/chromium/Default/Shared Dictionary/cache/index' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/CacheStorage/6d38d5207225737629af3268cdd36fc174326e46/5fcdf3f6-b4f0-44f0-9f40-b8f86baa9afd/index' '/home/buidai289/.config/chromium/Default/Shared Dictionary/cache/index' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/Safe Browsing Cookies' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension Cookies' '/home/buidai289/.config/chromium/Default/Safe Browsing Cookies' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/Sync Data/LevelDB/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension Rules/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension Scripts/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/shared_proto_db/metadata/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/shared_proto_db/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension State/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/GCM Store/Encryption/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/Database/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Local Extension Settings/dmghijelimhndkbmpgbldicpogfkceaj/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/Origins/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/000/t/Paths/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/000/p/Paths/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/MANIFEST-000001' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/File System/000/t/Paths/000003.log' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/000/p/Paths/000003.log' '/home/buidai289/.config/chromium/Default/File System/000/t/Paths/000003.log' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_developer.mozilla.org_0.indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/7/IndexedDB/indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/8/IndexedDB/indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/13/IndexedDB/indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_fontawesome.com_0.indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/16/IndexedDB/indexeddb.leveldb/MANIFEST-000001' '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/MANIFEST-000001' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/Local Storage/leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Sync Data/LevelDB/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension Rules/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension Scripts/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Session Storage/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/shared_proto_db/metadata/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/shared_proto_db/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Extension State/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/GCM Store/Encryption/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/1/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.youtube.com_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Service Worker/Database/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_www.sliderrevolution.com_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_developer.mozilla.org_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/5/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/Local Extension Settings/dmghijelimhndkbmpgbldicpogfkceaj/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/7/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/8/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/9/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_blog.desdelinux.net_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/13/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/Origins/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_mega.nz_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/000/t/Paths/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/File System/000/p/Paths/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/IndexedDB/https_fontawesome.com_0.indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate
remove_cmd    '/home/buidai289/.config/chromium/Default/WebStorage/16/IndexedDB/indexeddb.leveldb/CURRENT' '/home/buidai289/.config/chromium/Default/Site Characteristics Database/CURRENT' # duplicate

original_cmd  '/home/buidai289/.config/chromium/Default/Login Data' # original
remove_cmd    '/home/buidai289/.config/chromium/Default/Login Data For Account' '/home/buidai289/.config/chromium/Default/Login Data' # duplicate
                                               
                                               
                                               
######### END OF AUTOGENERATED OUTPUT #########
                                               
if [ $PROGRESS_CURR -le $PROGRESS_TOTAL ]; then
    print_progress_prefix                      
    echo "${COL_BLUE}Done!${COL_RESET}"      
fi                                             
                                               
if [ -z $DO_REMOVE ] && [ -z $DO_DRY_RUN ]     
then                                           
  echo "Deleting script " "$0"             
  rm -f '/home/buidai289/.config/rmlint.sh';                                     
fi                                             
