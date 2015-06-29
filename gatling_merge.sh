#!/bin/bash
unset CDPATH
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$SOURCE_DIR"/file_utils.sh
. "$SOURCE_DIR"/svn_tools.sh

commits_statuses="gatling_merge_statuses"

STASH_FILE_MARKER="STASH_FILE"
TOMERGE="TOMERGE"
DONE="DONE"
BRANCH="BRANCH" # branch line special marker
# TODO deal with comments and empty lines
# TODO add network connectivity check

# TODO TODO return instead of exit

# TODO return 2 in case merge succeeded with conflicts, return 0 in case merge succeeded without problems, return 1 in case of last commit success & cleanup
# TODO add -q option to remove all the "useless" queries (getting logs, analyzing status only to display it to the user)

function usage(){
    # prints EOF + error message when reached the end of the file containing the commits to merge
    echo
    echo "Merge with a gatling gun! 'load' the commits to merge, then 'fire' each one to commit the merge and start the next one!"
    echo
    echo "USAGE: $(basename $0)"
    echo
    echo -e "\tload BRANCH COMMIT [...] "
    echo -e "\t\tsaves all commits to be merged, and attempts to merge the first; BRANCH can be either an url or a working copy path"
    echo
    echo -e "\tfire"
    echo -e "\t\tcommits the current changes on the working copy, marks it as merged, and attempt to merge the next one"
    echo
    echo -e "\trapidfire"
    echo -e "\t\tcommits the current changes on the working copy, marks it as merged, and attempt to merge the next one"
    echo
    echo -e "\tretry"
    echo -e "\t\treverts all changes on the working copy and then re-attempts to merge the current commit"
    echo
    echo -e "\tstatus [-v]"
    echo -e "\t\tdisplays all the logs that have to be merged, the svn status and the log of the current commit undergoing a merge"
    echo -e "\t\t-v : verbose mode"
    echo
    echo -e "\tcleanup"
    echo -e "\t\trestore changes and remove the commits statuses file, if present"
    echo
    echo -e "\t-h or --help : print this help message and exit"
    echo 
    echo "--test runs the tests"
    echo
    echo "'fire' and 'rapidfire' will automatically start cleanup if there is no more commit to process"
    echo "'load' and 'retry' will complain with a message with a line starting by EOF if there is no more commit to process."
    echo "'load', 'fire', 'rapidfire' and 'retry' update the working copy before merging"
}


# echo with a prefix
function log () {
    echo ">" "$@"
}

# without line feed to be able to complete the line
function log_incomplete () {
    echo -n ">" "$@"
}

function log_incomplete_part (){
    echo -n "$@"
}

function log_complete(){
    echo "$@"
}

# USAGE: log_cat FILE
function log_cat(){
    local fname="$1"
    log "Contents of file $fname:"
    awk '{print "> > $0"}' "$fname"
}

function check_env() {
    [ -r "$commits_statuses" ] && return 0
    
    [ -e "$commits_statuses" ] \
        && echo "Error: $commits_statuses not readable." \
        || echo "Error: $commits_statuses not found."
        
    echo "either go back to your base directory, or use load BRANCH COMMIT [...] to create it"
    exit -1
}


# print_log COMMIT [BRANCH]
function print_log() {
    if [ -z "$2" ]
    then
        svn log -c "$1" || exit $?
    else
        svn log -c "$1" "$2" || exit $?
    fi
}

# TODO introduce commit parameter
function print_current_log() {
    if ! current_commit
    then
        exit $?
    fi
    local commit="$ans"
    
    get_merge_branch || return $?
    local branch="$ans"
    
    print_log "$commit" "$branch"
}

# USAGE: print_first_line_current_log
function print_first_line_current_log() {
    print_current_log | perl -ne 'if (/-------------------/) {next}; if (/^r\d+/) {next}; if (/^\s*$/) {next}; print; exit'
}


# return in $ans
# exits if there is no/no more commits statuses file
ans=""
function current_commit() {
    check_env
    
    ans=$(awk -v "TOMERGE=$TOMERGE" '$2 == TOMERGE {print $1; exit}' "$commits_statuses")
    if [ -z "$ans" ]
    then
        echo "EOF: No more commits to merge in $commits_statuses. You might want to run '$(basename "$0") cleanup'"
        return 1
    fi
    return 0
}


# USAGE: is_svn_server_or_working_copy PATH_OR_URL
# returns non-zero if it is not
# print error messages on STDERR if it is not
function is_svn_server_or_working_copy(){
    local path_or_url="$1"
    
    svn info "$path_or_url" > /dev/null
}


# take the last line marked BRANCH before the commit to process => allow multiple source branches
# BUG: there must be a branch before a commit
# return in $ans
function get_merge_branch() {
    if ! current_commit
    then
        return $?
    fi
    local commit="$ans"
    
    ans=$(awk -v "BRANCH=$BRANCH" -v "commit=$commit" '$2 == BRANCH {b = $1}; $1 == commit {print b; exit}' "$commits_statuses")
}


# counts conflicts and missing/obstructed file problems, and print them when they are non-zero
function print_count_svn_problems(){
    svn status | awk '
        /^C/ || /^ C/ || /^      C/ {conflicts++};
        /^!/ || /^~/ {file_problems++};
        END {
            if (conflicts) { printf("%d conflict(s) ", conflicts)};
            if (file_problems) { printf("%d local file problem(s)", file_problems)};
        }'
}

# perform an update followed by a svn merge of the current commit in the file
function merge() {
    log "updating working copy"
    svn up -q || return $?
        
    if ! current_commit
    then
        return 1
    fi
    local commit="$ans"
    
    get_merge_branch || return $?
    local branch="$ans"
    
    log_incomplete "merging revision $commit from $(basename "$branch")."
    svn merge -q --accept postpone -c "$commit" "$branch" || return $?   # use ancestry info
    
    log_complete " $(print_count_svn_problems )"
    print_current_log
}


# commits semi-quietly (only print dots and commited revision: ...)
# pass all arguments to svn ci
function semi_quiet_svn_commit(){
    
    local commit_rev="Committed revision"
    local semi_quiet_commit_tmp_file="$(temp_file "semi_quiet_commit_tmp_file")"
    
    if ! svn ci "$@" > "$semi_quiet_commit_tmp_file" # BUG BUG BUG ! $semi_quiet_commit_tmp_file can be empty sometimes!
    then
        log_cat "$semi_quiet_commit_tmp_file"
        rm "$semi_quiet_commit_tmp_file"
        return -1
    fi
    log_complete "$(grep "$commit_rev" "$semi_quiet_commit_tmp_file")"
    rm "$semi_quiet_commit_tmp_file"
}

# commit the changes on the current branch
function commit() {

    local log="$(temp_file "$0")"
    
    # extract the log message
    print_current_log | awk 'NR <= 3 {next}; ! /------/ {print $0}; /------/ {exit}' > "$log"
    
    log_incomplete "commiting merge... "
    
    # perform commit
    if ! semi_quiet_svn_commit -F "$log"
    then
        rm "$log"
        return -1
    else
        rm "$log" || return $?
    fi
    
    step_to_next_commit
}


# outputs the server url if it is correct, or the server url corresponding to the given working copy
# USAGE: find_server_url PATH_OR_URL
# RETURN: non-zero on error
# STDOUT: the branch url, or nothing on error
# STDERR: error messages on error
function find_server_url() {
    local path_or_url="$1"
    
    if ! is_svn_server_or_working_copy "$path_or_url" 2> /dev/null
    then
        echo "$path_or_url is neither a valid working copy path nor a valid svn server path" 1>&2
        return -1
    fi
    
    
    if [ -e "$1" ]
    then
        # working copy path
        svn info "$1" | grep '^URL:' | cut -b 6-
    else
        # url
        echo "$1"
    fi
}


# find the server url and store it in the commit statuses file
# USAGE: load_svn_server_url PATH_OR_URL
# RETURN: non-zero on error
# STDERR: error messages on error
function load_svn_server_url() {
    local branch_url_or_working_copy="$1"
    
    log_incomplete "finding source url "
    
    find_server_url "$branch_url_or_working_copy" > /dev/null || return -1
    local branch_url=$(find_server_url "$branch_url_or_working_copy" )
    
    log_complete "$branch_url"
    echo -e "$branch_url\t$BRANCH" >> "$commits_statuses"
}


# loads the given commits int the commit statutes file
# USAGE: load_commits COMMIT [...]
# RETURN: on-zero on error
# STDERR: error messages on error
function load_commits() {
    if [ $# -eq 0 ]
    then
        echo "no commit to load" 1>&2
        return -1
    fi
    
    for commit in "$@"
    do
        echo -e "$commit\t$TOMERGE" >> "$commits_statuses"
    done
}


# USAGE: save_and_clean_local_changes
function save_and_clean_local_changes(){
    log "stashing local changes (this may take a while)"
    
    local stash_file="$(svn_stash_save )"
    [ -z "$stash_file" ] && return -1
    
    echo -e "$stash_file\t$STASH_FILE_MARKER" >> "$commits_statuses"
}


# USAGE: get_stash_files GATLING_MERGE_STATUS_FILE
function get_stash_files(){
    local gatling_merge_status_file="$1"
    
    awk '$2 ~ "'"$STASH_FILE_MARKER"'" {print $1}' "$gatling_merge_status_file"
}


function put_back_and_rm_on_success() {
    local stash_file="$1"
    
    svn patch "$stash_file" || return -1
    rm "$stash_file"
}


# USAGE: put_back_saved_local_changes GATLING_MERGE_STATUS_FILE
function put_back_saved_local_changes(){
    local gatling_merge_status_file="$1"
    
    log "restoring local changes"
    get_stash_files "$gatling_merge_status_file" | (
        failed_stash_files=""
        while read -r stash_file
        do
            if ! put_back_and_rm_on_success "$stash_file"
            then
                failed_stash_files="$failed_stash_files $stash_file"
            fi
        done
        if [ -n "$failed_stash_files" ]
        then
            log "failed stash files: $failed_stash_files. Those are not deleted so you can recover." 1>&2
        fi
    )
}


# load without error recovery
function no_error_recovery_load(){

    load_svn_server_url "$1" || return -1
    shift
    
    load_commits "$@" || return -1
    
    save_and_clean_local_changes || return -1
}


# USAGE: load   BRANCH_URL_OR_WORKING_COPY_PATH   COMMIT [...]
function load() {
    if [ -e "$commits_statuses" ]
    then
        echo "$commits_statuses already exists"
        echo "You might either go directly to the other steps, or call '$(basename "$0") cleanup"
        return -1
    fi
    
    if ! no_error_recovery_load "$@"
    then
        rm "$commits_statuses" &> /dev/null
        return -1
    fi
    
    merge
}


function step_to_next_commit () {
    
    local commits_temp="$(temp_file "$0")"
    
    cp "$commits_statuses" "$commits_temp" || exit $?
    awk -v "TOMERGE=$TOMERGE" -v "DONE=$DONE" '$2 == TOMERGE && !s {print $1, DONE; s = 1; next}; {print}' "$commits_temp" > "$commits_statuses" 
    
    if [ $? -ne 0 ] # not sure about awk return codes
    then
        rm "$commits_temp"
        exit -1
    fi
    rm "$commits_temp"
}


function fire() {
    check_env
    if ! current_commit # check that there is a current commit to merge
    then
        return 1
    fi
    
    if ! commit
    then
        echo "commit failed."
        return -1
    fi
    
    if ! current_commit > /dev/null # no more commit to process
    then
        log "No more commits to process... cleaning up"
        cleanup
        return 1 # indicate end of merge process
    fi
    
    merge
}

function rapidfire() {
    check_env
    if [ $# -ne 1 ]
    then
        echo "rapidfire: you need to provide a merge verification command. Usually, this is your build command."
        return 1
    fi
    local verify_merge="$1"
    
    local fire_return=0
    while [ $fire_return -eq 0 ]
    do
        log "verifying merge with '$verify_merge'"
        eval "$verify_merge"
        local ret=$?
        if [ $ret -ne 0 ]
        then
            echo "verifying merge failed and returned $ret"
            echo "stopping rapid fire"
            return -1
        fi
        fire
        fire_return=$?
    done
}


function retry() {
    check_env
    
    log "erasing every local modification of this working copy"
    svn revert -qR . || exit $?
    
    merge
}


function status() {
    check_env
    
    case "$1" in
        "" )
            status_normal;;
        "-v" )
            status_verbose;;
        * )
            echo "unknown status option '$1'";;
    esac
}


function status_normal() {
    if ! current_commit # prints message that there is no more commit
    then
        return 0 # no commit but its ok
    fi
    
    awk -v "TOMERGE=$TOMERGE" -v "DONE=$DONE" '
        BEGIN {done=1};
        $2 == TOMERGE || $2 == DONE {total++};
        $2 == DONE {done++};
        $2 == TOMERGE && !current {current=$1};
        END {
            printf("merge %d/%d from rev %s", done, total, current)
            };
        ' "$commits_statuses"
        
    print_first_line_current_log | awk '{print " | "$0}'
}


function status_verbose(){
    awk -v "TOMERGE=$TOMERGE" -v "DONE=$DONE" '$2 == TOMERGE || $2 == DONE {print}' "$commits_statuses"
    print_current_log
}


function cleanup() {
    check_env
    
    put_back_saved_local_changes "$commits_statuses"
    
    log "removing status file '$commits_statuses'"
    rm "$commits_statuses"
}


function test_suite(){
    test_stash
}


if [[ "$BASH_SOURCE" == "$0" ]]
then
    cmd="$1"
    shift
    
    case "$cmd" in
        --help | -h ) usage;;
        --test ) test_suite ;;
        load ) load "$@" ;;
        fire ) fire ;;
        rapidfire ) rapidfire "$@";;
        retry ) retry ;;
        status ) status "$@" ;;
        cleanup ) cleanup ;;
        * ) 
            echo "Unrecognized command '$cmd'. Check the help:"
            usage
            exit -1
    esac
fi
