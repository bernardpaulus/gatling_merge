#!/bin/bash
unset CDPATH
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$SOURCE_DIR"/file_utils.sh

# USAGE: is_svn_working_copy [DIR]
# if DIR is absent, the current directory is taken
# returns 0 if DIR is a working copy, 1 otherwise
function is_svn_working_copy () {
    local dir="$1"
    svn info "$dir" &> /dev/null
}


stash_prefix="svn_stash_"
stash_suffix=".diff"
# stash all the changes to the working copy or the given files
# that is, save the diff in a file and revert the files
# USAGE: svn_stash_save [FILE [...]]
# RETURNS: 0 on success, -1 on error
# STDOUT: the name of the new stash file, on success
# STDERR: prints error message on error
function svn_stash_save() {
    
    local stash_file="$(new_file_no_overwrite_by_incrementation "$stash_prefix" "$stash_suffix")"
    if ! svn diff "$@" > "$stash_file" 
    then
        echo "stash ($stash_file) creation failed"
        rm "$stash_file"
        return -1
    fi
    
    if [ $# -eq 0 ]
    then
        if ! svn revert -qR .
        then
            rm "$stash_file"
            return -1
        fi
        
    elif ! svn revert -qR "$@"
    then
        rm "$stash_file"
        return -1
    fi
    
    echo "$stash_file"
}

# USAGE: svn_stash_pop STASH_NAME
function svn_stash_pop() {
    local stash_file="$1"
    
    svn patch "$stash_file" || return -1
    rm "$stash_file"
}


function mk_test_directory() {
    if [ ! -d "$tmp_directory" ]
    then 
        echo "tmp $tmp_directory does not exist" 
        return -1
    fi
    local dir_name="$1"
    
    echo "$tmp_directory/$(new_dir_by_incrementation "$dir_name")"
}

function mk_test_repo () {
    
    local svn_repo="$(mk_test_directory svn_repo)"
    svnadmin create "$svn_repo" || return -1
    echo "$tmp_directory/$svn_repo"
}

function mk_test_working_copy () {
    locale svn_repo="$1"
    
    local svn_working_copy="$(mk_test_directory svn_working_copy)"
    svn checkout "$svn_repo" || return -1
    echo "$tmp_directory/$svn_repo"
}

function mk_svn_test_setup() {
    echo TODO TODO TODO 1>&2
    
    return -1
}

