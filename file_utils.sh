#!/bin/bash

# create a file only if it does not already exists
# USAGE: create_only_if_not_exist FILE
# RETURNS: 0 if the file was successfully created, non-zero otherwise
# does not print anything
function create_only_if_not_exist() {
    local f="$1"
    ( 
        set -C
        echo -n "" > "$f"
    ) 2> /dev/null
}

# USAGE: increment_name_while_failed ACTION FILENAME_PREFIX [FILENAME_SUFFIX]
function increment_name_while_failed(){
    local action="$1"
    local prefix="$2"
    local suffix="$3"
    
    local i=1
    while ! "$action" "$prefix$i$suffix"
    do
        let i++
    done
    
    echo "$prefix$i$suffix"
}

# create a new file without overwriting any existing file, by incrementing a counter at the end of the file
# USAGE: create_only_if_not_exist FILENAME_PREFIX [FILENAME_SUFFIX]
# prints the filename of the newly created file on stdout
function new_file_no_overwrite_by_incrementation() {
    increment_name_while_failed create_only_if_not_exist "$@"
}

# mkdir but all streams redirected to /dev/null
# RETURNS: mkdir's return value
function silent_mkdir (){
    mkdir "$@" &> /dev/null
}


# USAGE: new_dir_by_incrementation DIRNAME_PREFIX [DIRNAME_SUFFIX]
function new_dir_by_incrementation() {
    increment_name_while_failed silent_mkdir "$@"
}


# USAGE: randomize_name_while_failed ACTION FILENAME_PREFIX [FILENAME_SUFFIX]
function randomize_name_while_failed(){
    local action="$1"
    local prefix="$2"
    local suffix="$3"
    
    local i="$RANDOM"
    while ! "$action" "$prefix$i$suffix"
    do
        i="$RANDOM"
    done
    
    echo "$prefix$i$suffix"
}

# USAGE: temp_file FILENAME_PREFIX [FILENAME_SUFFIX]
function temp_file(){
    randomize_name_while_failed create_only_if_not_exist "$@"
}