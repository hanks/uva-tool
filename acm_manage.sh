#!/bin/bash

#################################################################################################
# Test Shell Script for acm program.
#
# Usage is:
#    ./acm_manage.sh i questionID
#    ./acm_manage.sh r questionID
#    ./acm_manage.sh d questionID
#    ./acm_manage.sh s questionID
#    ./acm_manage.sh s
#    ./acm_manage.sh h
#    ./acm_manage.sh help
#
# Main Function is:
#    1. init acm directory and create source, test, expect files from website for you.
#    2. run your code with your test data file, and check its correctness with your expect file.
#    3. debug your code with your test data file.
#    4. submit your code to uva website using uva-node and get the judge result
#
# Platform:
#    Linux, Mac OSX, Unix
#
# Support Program Language:
#    C
#
# Author: 
#    Hanks
#
# Email:
#    zhouhan315[atgmaildotcom]
#
# Version:
#      1.0
#################################################################################################

########################
# varibles define start
########################

# script name
SCRIPT_NAME="acm_manage.sh"

# diretory for question
QUESTION_DIR=
# question id
QUESTION_ID=
# question name
QUESTION_NAME=

# file name prefix
TEST_FILE_PREFIX="test_"
EXPECT_FILE_PREFIX="expect_"
RESULT_FILE_PREFIX="result_"

# file type
SOURCE_FILE_TYPE=".c"
DATA_FILE_TYPE=".txt"

# path for test data file
TEST_DATA_FILE_PATH=
# path for executable file
EXECUTABLE_FILE_PATH=
# path for result file
RESULT_FILE_PATH=
# path for source code file
SOURCE_CODE_PATH=
# path for expect data file
EXPECT_FILE_PATH=
# default executable file name
DEFAILT_EXECUTABLE_FILE_NAME="a.out"
# diff result file
DIFF_RESULT_FILE="diff.txt"
# gdb command temp file
DEFAULT_DEBUG_COMMAND_FILE_NAME="gdb_cmd_temp"
DEBUG_COMMAND_FILE_PATH=

# cost second time
RUN_START_TIME=
RUN_END_TIME=
TIME_COST=

# accept time is 3 millisecond
ACCEPT_TIME=3000

# make format of each line of content from echo be corrent 
IFS="  
"

# init compiler command, default is clang, if no, use gcc
COMPILE_COMMAND=
DEBUG_OPTION="-g"
OPTIMIZE_OPTION="-ansi -Wall" 
DEBUG_TOOL="gdb"

# acm workspace existed flag
IS_WORKSPACE_NOT_EXIST=false
IS_ACM_ROOT_NOT_EXIST=false

#config variable
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")"; pwd)
ACM_ROOT_NAME=
ACM_ROOT=
CONFIG_FILE_NAME="$SCRIPT_DIRECTORY/acm_manage.ini"
CRAWLER_FILE="$SCRIPT_DIRECTORY/crawler.py"
SET_PATH=

# use for submit
UVA_KEY_FILE="$HOME/.ssh/uva-node.key"
UVA_ACCOUNT_NAME=
UVA_ACCOUNT_PWD=
UVA_NODE="$SCRIPT_DIRECTORY/uva-node"
UVA_WAITING_TIME=15
STAT_NUM=2

######################
# varibles define end
######################

#######################
# function define start
#######################

# add acm_manage.sh to your PATH environment varibale,
# so you can use this command defaultly.
set_script_to_path()
{
    # ask user whether to add to path or not
    loop=true
    while $loop; do
        read -n1 -p "Add this script to your PATH to run anywhere. [y/n]?" answer 
        case $answer in 
            Y | y)
                echo
                echo "Fine, continue."
                SET_PATH=true
                loop=false
                ;; 
            N | n)
                echo
                echo "Ok, I got it. Donot set to path."
                SET_PATH=fasle
                loop=false
                return
                ;; 
            *) 
                echo "Error choice, please answer with y or n."
                ;; 
        esac
        echo
    done
    
    PROFILE_PATH=~/.profile
    BASH_PROFILE_PATH=~/.bash_profile
    OS_TYPE=`uname`

    ADD_PATH_COMMAND="export PATH=\$PATH:$SCRIPT_DIRECTORY"
    TARGET_PROFILE_PATH=
    
    if [ $OS_TYPE = "Darwin" ]; then
        echo "You are a Mac system user."
        TARGET_PROFILE_PATH=$PROFILE_PATH
    elif [ $OS_TYPE = "Linux" ]; then
        echo "You are a Linux system user."
        TARGET_PROFILE_PATH=$BASH_PROFILE_PATH        
    elif [ $OS_TYPE = "FreeBSD" ]; then
        echo "You are a FreeBSD system user."
        TARGET_PROFILE_PATH=$BASH_PROFILE_PATH                
    fi
    echo "Start to add this script to your path."
    echo "#Add acm_manage.sh command to your PATH" >> $TARGET_PROFILE_PATH
    echo $ADD_PATH_COMMAND >> $TARGET_PROFILE_PATH
    echo "Add path is done. You can check $TARGET_PROFILE_PATH."
    echo "So you can run this script anywhere. Enjoy."
}


# print help info for user
print_help()
{
    echo
    echo "Usage: acm_manage.sh [i|r|d|s|h|help] questionID"
    echo "Like: acm_manage.sh i 101"
    echo "Options: These are optional argument"
    echo " i questinID: init acm directory, create directory, source, test file and expect file automatically for you."
    echo " r quesitonID: run your code with your test data. And diff output and expect file to check correctness "
    echo " s questionID: submit your code to website, and get the judgement."
    echo " d questionID: start debug tool (like gdb, lldb) to debug your code."    
    echo " s: just fetch stat from uva."
    echo " h|help: show help info."    
    echo
    echo "When you first run this shell, you should "
    echo "enter the directory the script is in "
    echo "and run the script. Have fun."
    echo
}

read_conf_info_from_file()
{
    ACM_ROOT=`cat $CONFIG_FILE_NAME | grep ACM_ROOT | awk -F"=" '{print $2}'`
    SET_PATH=`cat $CONFIG_FILE_NAME | grep SET_PATH | awk -F"=" '{print $2}'`
    echo "ACM_ROOT is $ACM_ROOT"
    echo "SET_PATH is $SET_PATH"
}

create_conf_file()
{
    # create configure init file
    echo "ACM_ROOT=$ACM_ROOT" >> $CONFIG_FILE_NAME
    echo "SET_PATH=$SET_PATH" >> $CONFIG_FILE_NAME
    echo
    echo "Create config file $CONFIG_FILE_NAME in the current directory."
    echo
}

set_acm_root()
{
    echo "This is your first time and last time to see this message, just config some info. ^_^"
    echo "Please input your acm root directory name(like uva), it will be created in your current directory:"
    read ACM_ROOT_NAME
    ACM_ROOT=$SCRIPT_DIRECTORY/$ACM_ROOT_NAME/
    if [ ! -d $ACM_ROOT ]; then
        mkdir $ACM_ROOT
        echo "Create $ACM_ROOT directory for you."
    fi
}

init_acm_root_directory() 
{
    if [ ! -f $CONFIG_FILE_NAME ]; then
        # config file is not existed, create it
        set_acm_root
        set_script_to_path
        create_conf_file
        echo "Now you can see usage to rock acm."
        print_help
        echo
    else
        # read config info from file and init ACM_ROOT
        read_conf_info_from_file
    fi    
}

# init question name
init_question_name()
{
    
    QUESTION_NAME=$(python $CRAWLER_FILE q $QUESTION_ID $ACM_ROOT)
}

# init files path
init_path()
{
    echo
    # build paths for files
    QUESTION_DIR=$ACM_ROOT$QUESTION_NAME
    #echo "questoin directory is $QUESTION_DIR"
    SOURCE_CODE_PATH=$QUESTION_DIR/$QUESTION_NAME$SOURCE_FILE_TYPE
    echo "Source file is $SOURCE_CODE_PATH"
    TEST_DATA_FILE_PATH=$QUESTION_DIR/$TEST_FILE_PREFIX$QUESTION_NAME$DATA_FILE_TYPE
    #echo "test data is $TEST_DATA_FILE_PATH"
    EXPECT_FILE_PATH=$QUESTION_DIR/$EXPECT_FILE_PREFIX$QUESTION_NAME$DATA_FILE_TYPE
    #echo "expect is $EXPECT_FILE_PATH"
    EXECUTABLE_FILE_PATH=$QUESTION_DIR/$DEFAILT_EXECUTABLE_FILE_NAME
    #echo "executable is $EXECUTABLE_FILE_PATH"
    RESULT_FILE_PATH=$QUESTION_DIR/$RESULT_FILE_PREFIX$QUESTION_NAME$DATA_FILE_TYPE
    #echo "result is $RESULT_FILE_PATH"
    DEBUG_COMMAND_FILE_PATH=$QUESTION_DIR/$DEFAULT_DEBUG_COMMAND_FILE_NAME
}

# init source code template, default is c language
init_source_code()
{
    echo "#include <stdio.h>" >> $SOURCE_CODE_PATH
    echo "#include <string.h>" >> $SOURCE_CODE_PATH
    echo "#include <stdlib.h>" >> $SOURCE_CODE_PATH
    echo >> $SOURCE_CODE_PATH
    echo "int main(int argc, char *args[]) {" >> $SOURCE_CODE_PATH
    echo >> $SOURCE_CODE_PATH
    echo "    return 0;" >> $SOURCE_CODE_PATH
    echo "}" >> $SOURCE_CODE_PATH    
}

# init test and expect data file from user input
init_test_and_expect_data()
{
    loop=true
    while $loop; do
        read -n1 -p "Do you want to input test and expect data now. [y/n]?" answer 
        case $answer in 
            Y | y)
                echo "Input start:"
                echo "Please pay attention to the command to end your input."
                echo "or else you will need modify these file by yourself again."
                echo
                echo "Please input your test input data and Press Enter and then ctrl+D to end input:"
                cat > $TEST_DATA_FILE_PATH
                echo "Please input your expect output data and Press Enter and then ctrl+D to end input:"
                cat > $EXPECT_FILE_PATH
                echo "Input end."
                loop=false
                ;; 
            N | n)
                touch $TEST_DATA_FILE_PATH
                touch $EXPECT_FILE_PATH
                echo
                echo "Create empty test and expect file. You need add test data by yourself."
                loop=false
                ;; 
            *)
                echo "Wrong input, please answer just by y or n."
                ;; 
        esac
    done
    
}

# create acm directory and files for user
init_acm_workspace() 
{
    echo "Init acm workspace for you."
    # if directory is not existed, create a new one
    # or else, do nothing to protect the existed source files
    #if $IS_WORKSPACE_NOT_EXIST; then
    #    # create acm diretory
    #    mkdir $QUESTION_DIR
    #    
    #    # init source and test data
    #   init_source_code
    #    init_test_and_expect_data
    #    init_push_to_github
    #    echo "Init is done, let's rock."
    #else
    #    echo "Sorry, workspace is already exsited, you can start rock."
    #fi
    
    # if directory existed, do nothing
    #return

    Status=$(python $CRAWLER_FILE $QUESTION_ID $ACM_ROOT)

    if [ "$Status" -eq 1 ]
    then
        echo "Init question directory is done, let's rock."
        init_push_to_github
    else
        echo "Sorry, workspace is already exsited, you can start rock."    
    fi
}

# check workspace existed
workspace_exist_check()
{
    if $IS_WORKSPACE_NOT_EXIST; then
        echo "Workspace \"$QUESTION_NAME\" is not existed. Please use command \"$SCRIPT_NAME i $QUESTION_NAME\" to init workspace."
        exit 1
    fi
}

compile_code() 
{
    echo "Compile start."
    echo "Clear old executable file."
    rm $EXECUTABLE_FILE_PATH > /dev/null
    $COMPILE_COMMAND $DEBUG_OPTION $SOURCE_CODE_PATH $OPTIMIZE_OPTION -o $EXECUTABLE_FILE_PATH
    echo "Compile end."
}

run_code() 
{
    # delete result file firstly if existed, to avoid
    # result confict with old one
    echo
    echo "Clear old result file."
    rm $RESULT_FILE_PATH > /dev/null

    # create a new empty result file
    touch $RESULT_FILE_PATH
    
    # run code with test data, and redirect output to result file
    echo
    echo "Start to run code:"
    # record start time, %N means nanoseconds
    # second is 1
    # millisecond is 0.001
    # macrosecond is 0.000001
    # nanosecond is 0.000000001
    #RUN_START_TIME=`date +%s%N`
    # get total millisecond from epoth
    RUN_START_TIME=$(python -c 'import time; print int(round(time.time()*1000))')
    #while read -r line
    #do
    #    echo $line | $EXECUTABLE_FILE_PATH >> $RESULT_FILE_PATH
    #done < $TEST_DATA_FILE_PATH
    # record end time
    cat $TEST_DATA_FILE_PATH | $EXECUTABLE_FILE_PATH >> $RESULT_FILE_PATH
    RUN_END_TIME=$(python -c 'import time; print int(round(time.time()*1000))')
    echo "Run is done."
}

print_run_time_cost()
{
    # cost in milliseconds
    TIME_COST=$((RUN_END_TIME-RUN_START_TIME))
    # cost in seconds
    SECOND_TIME_COST=`echo "$TIME_COST / 1000 " | bc -l`
    echo "Run time cost is ${SECOND_TIME_COST:0:4} seconds."
}

print_output() 
{
    echo
    echo "Output is:"
    cat $RESULT_FILE_PATH
}

register_your_uva_account() 
{
    if [ ! -f $UVA_KEY_FILE ]; then
        # if there is no a uva-node key file, means need to login in first
        echo "This is your first time to submit your code to uva using acm manage."
        echo "So need you to login uva firstly. Acm manage will encrypt your password,"
        echo "do not worry about that."

        echo "Please input your account name:"
        read UVA_ACCOUNT_NAME
        
        echo "Please input your password:"
        stty -echo
        read UVA_ACCOUNT_PWD
        stty echo

        # start to login to uva
        echo
        node $UVA_NODE add uva $UVA_ACCOUNT_NAME $UVA_ACCOUNT_PWD
        
        echo "Login is successful."
        node $UVA_NODE use uva $UVA_ACCOUNT_NAME
    fi
}

fetch_stat_from_uva()
{
   echo "Your are going to fetch your statistics from uva website."
   register_your_uva_account
   TOTAL_STAT_NUM=10 
   echo "Your lastest $TOTAL_STAT_NUM results are:"
   node $UVA_NODE stat $TOTAL_STAT_NUM
}

submit_to_uva()
{
    echo "You are going to submit your code to uva website."
    register_your_uva_account
    echo "Start to submit your code."
    node $UVA_NODE send $QUESTION_ID $SOURCE_CODE_PATH

    echo
    echo "Please wait for about $UVA_WAITING_TIME seconds to get the online judge result..."
    sleep $UVA_WAITING_TIME
    echo "Your lastest $STAT_NUM results are:"
    node $UVA_NODE stat $STAT_NUM 
}

judge_result()
{
    echo
    echo "Diff result is:"
    git diff --no-index --color "$RESULT_FILE_PATH" "$EXPECT_FILE_PATH" > $DIFF_RESULT_FILE
    # test whether diff file is empty
    if test -s $DIFF_RESULT_FILE; then
        # if no empty, means wrong
        cat $DIFF_RESULT_FILE
        echo "Wrong answer. Try again."
    else
        if [ $TIME_COST -le $ACCEPT_TIME ]; then
            echo "Accept. Congratulations"
        else
            echo "Time limit exceeded. Cost time $TIME_COST > Accept time $ACCEPT_TIME milliseconds"
        fi        
    fi
    rm $DIFF_RESULT_FILE
}

debug_code()
{
    echo "Debug is start."
    echo "start < $TEST_DATA_FILE_PATH" > $DEBUG_COMMAND_FILE_PATH
    #$DEBUG_TOOL $EXECUTABLE_FILE_PATH
    $DEBUG_TOOL -x $DEBUG_COMMAND_FILE_PATH $EXECUTABLE_FILE_PATH
    rm $DEBUG_COMMAND_FILE_PATH
    echo "Debug is done."
}

# shift command arguments for while loop process
skip_command() 
{
    shift 2
}

# detect clang installed, or else use gcc
select_compile_tool()
{
    which clang > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        COMPILE_COMMAND="clang"
    else
        COMPILE_COMMAND="gcc"
    fi
    echo "Use $COMPILE_COMMAND to compile source code."    
}

# detect whether is installed, or else auto install
detect_node_install()
{
    which node > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        # auto install it
        # echo "Auto install node for your. You need to input your sudo password."
        # sudo apt-get install node
        echo "Need lastest Node js installed in your computer."
        echo "Please go to official site http://nodejs.org/ to download it."
        exit 0
    fi
}

# push to github when init a new question
init_push_to_github()
{

    cd $QUESTION_DIR
    git add $QUESTION_DIR > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        git commit -m "start $QUESTION_NAME [auto commit]"
        git push > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
            echo "Sync github is done. Have fun."    
        else
            echo "You have not set this repository to your github."
        fi    
    else
        echo "You do not use git!! But it is ok."
    fi    
}

#######################
# function define end
#######################

##################
# Main part start
##################

# if no right number of argument, show help and exit
# if use h or help command, show help and exit
if [ "$1" = "h" ]
then
    print_help
    exit 0
elif [ "$1" = "help" ]
then
    print_help
    exit 0
elif [ "$1" = "s" ]
then
    if [ $# -eq 1 ]
    then
        fetch_stat_from_uva
        exit 0
    fi
elif [ $# -lt 2 ] 
then
    print_help
    exit 1
fi

init_acm_root_directory

# get question name and init path for all files
QUESTION_ID="$2"

init_question_name
init_path

# check if workspace is existed.
if [ ! -d $QUESTION_DIR ]; then
    IS_WORKSPACE_NOT_EXIST=true
fi

# option argument command implementation
while [ "$1" ]
do
    echo
    if [ "$1" = "i" ]; then
        init_acm_workspace
    elif [ "$1" = "r" ]
    then
        workspace_exist_check
        echo "Run code with your test data and check correctness."
        select_compile_tool
        compile_code
        run_code
        print_output
        print_run_time_cost
        judge_result
    elif [ "$1" = "d" ]
    then
        workspace_exist_check
        echo "Debug your code with debug tool, default is gdb"
        select_compile_tool
        compile_code
        debug_code
    elif [ "$1" = "s" ]
    then
        workspace_exist_check
        detect_node_install        
        submit_to_uva
    else
        echo "$SCRIPT_NAME does not recognize option $1."
        print_help
        exit 1
    fi
    # skip command for loop argument process now
    # maybe there are some extensions in the future
    shift 2
done

##################
# Main part end
##################
