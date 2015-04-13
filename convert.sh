#!/bin/bash

# variable declaration section
YEAR=$(date +"%Y")
TIMESTAMP=$(date +"%s")
BASENAME=`basename $0`

# color section
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

#function section
function migration_notice(){
    printf "${BLUE}[Migration NOTICE] ${NORMAL}$1\n"  | tee -a $ACCESS_LOG;
}

function migration_hint(){
    printf "${YELLOW}[Migration HINT] ${NORMAL}$1\n"  | tee -a $ACCESS_LOG;
}

function migration_warning(){
    printf "${YELLOW}[Migration WARNING] ${NORMAL}$1\n"  | tee -a $ACCESS_LOG;
}

function migration_error(){
    printf "${RED}[Migration ERROR] ${NORMAL}$1\n"  | tee -a $ACCESS_LOG;
}

# display help
if [ "$1" == "--help" ]; then
    printf "\nConvert MyISAM tables to InnoDB engine\n"
    printf "Version 1.0\n"
    printf "https://github.com/jazlopez/mysql-engine-migration\n\n"
    printf "Usage: $BASENAME \n\n"
    printf "\t--include     Only convert specified tables. Separate the list by comma and enclose each table name by single quote e.g. include='users','post','forums'\n"
    printf "\t              If you define an include list --limit is ignored.\n"
    printf "\t              --include takes first precedence and will make the script to ignore --exclude.\n"
    printf "\t              Beware that defining a large number of tables can overload the server.\n"
    printf "\t--exclude     Do not convert the specified tables. Separate the list by comma and enclose each table name by single quote e.g. --exclude 'users','post','forums'\n"
    printf "\t--limit       Limit how many tables you want to convert in the batch. If not specified it will convert all MyISAM tables\n"
    printf "\t              If --include option used this value is ignored\n"
    printf "\t--mode        Use --mode debug to generate only the commands to an output file. Database is not affected.\n"
    printf "\t--log-dir     Log directory. Must be writable. If not defined the log directory is created on user's home path.\n"
    printf "\n\n"
    printf "Developer Contact Information:\n"
    printf "\tJaziel Lopez\n"
    printf "\tjuan.jaziel@gmail.com\n"
    printf "\tTijuana, MX\n"
    printf "\thttps://github.com/jazlopez\n"
    printf "\thttps://bitbucket.org/jazlopez\n"
    exit 0
fi

migration_notice "Starting migration script..."
migration_notice "Please wait, validating migration script parameters..."
sleep 5

# traverse to get parameters
while [[ $# > 1 ]]
do
key="$1"

case $key in
    --include)
    INCLUDE="$2"
    shift
    ;;
    --exclude)
    EXCLUDE="$2"
    shift
    ;;
    --limit)
    LIMIT="$2"
    shift
    ;;
    --mode)
    DRY_RUN="$2"
    shift
    ;;
    --log-dir)
    LOG_DIR_PATH="$2"
    shift
    ;;
    *)
esac
shift
done

# if log dir path not provided use $HOME
if [ -z "$LOG_DIR_PATH" ]; then LOG_DIR_PATH=$HOME ; fi

#check if directory is writable
if [ ! -w "$LOG_DIR_PATH" ]; then migration_error "$LOG_DIR_PATH is not writable. Migration log files need to be created." && exit 0; fi

migration_notice "$LOG_DIR_PATH is writable. Setting up log files..."
migration_notice "Checking log folder..."

MIGRATION_FOLDER_PATH="$LOG_DIR_PATH/migration-logs"

if [ ! -d "$MIGRATION_FOLDER_PATH" ]; then mkdir "$MIGRATION_FOLDER_PATH"    &&
    migration_notice "Created migration log folder: $MIGRATION_FOLDER_PATH ..."; fi

#create operations.log
ERROR_LOG="$MIGRATION_FOLDER_PATH/error-$TIMESTAMP.log"
ACCESS_LOG="$MIGRATION_FOLDER_PATH/access-$TIMESTAMP.log"
OPERATIONS_LOG="$MIGRATION_FOLDER_PATH/operations-$TIMESTAMP.log"
STATISTICS_LOG="$MIGRATION_FOLDER_PATH/statistics-$TIMESTAMP.csv"

touch "$ERROR_LOG" && migration_notice "Created error log: $ERROR_LOG";
touch "$ACCESS_LOG" && migration_notice "Created access log: $ACCESS_LOG";
touch "$OPERATIONS_LOG" && migration_notice "Created operations log: $OPERATIONS_LOG";
touch "$STATISTICS_LOG" && migration_notice "Created statistics csv: $STATISTICS_LOG";

migration_notice "Continue to database connection";

# database access
# retry logic max 3 attempts or exit
ERROR_ATTEMPT_CONNECTION=0
MAX_ATTEMPTS_CONNECTION=3

until [ $ERROR_ATTEMPT_CONNECTION -ge $MAX_ATTEMPTS_CONNECTION ]
do

    read -p "${GREEN}[Migration Database]${NORMAL} Migration Database Name:" db

    read -p "${GREEN}[Migration Database]${NORMAL} Migration Database Username:" username

    read -p "${GREEN}[Migration Database]${NORMAL} Migration Database Host:" host

    read -s -p "${GREEN}[Migration Database]${NORMAL} Database Password:" password

    printf "\n"

    mysql -u$username -p$password -h$host --connect_timeout=10 -e "USE $db;" > /dev/null 2>&1 && break

    ERROR_ATTEMPT_CONNECTION=$[ERROR_ATTEMPT_CONNECTION+1]

    migration_error "Unable to connect to database. Check your host and database credentials"
done

# exhausted attempts?
if [ $ERROR_ATTEMPT_CONNECTION == $MAX_ATTEMPTS_CONNECTION ]; then
    migration_error "Exhausted to connect connect to database. Script will end...Bye"
    exit 1;
fi

migration_notice "Connected to database"

# get list of MyISAM tables
isamLIST="SELECT CONCAT('ALTER TABLE \`',table_schema,'\`.\`',table_name,'\` ENGINE=InnoDB;') "
isamLIST="$isamLIST FROM information_schema.tables "
isamLIST="$isamLIST WHERE table_schema='$db' "
isamLIST="$isamLIST AND ENGINE='MyISAM' "

# include tables?
if [ -n "$INCLUDE" ];
        then isamLIST="$isamLIST AND table_name IN ($INCLUDE)";
    else
        # exclude tables?
        if [ -n "$EXCLUDE" ]; then isamLIST="$isamLIST AND table_name NOT IN ($EXCLUDE)"; fi

        # include limit?
        if [ -n "$LIMIT" ]; then
            isamLIST="$isamLIST LIMIT $LIMIT";
        else
            # are you sure you dont want limit the script?
            migration_warning "--limit was not specified and the script will try to convert all tables in once execution and may overload the server."
            read -r -p "${YELLOW}[Migration CONFIRMATION]${NORMAL} Are you sure you do not want to limit the script?[Y/n]:} " response
            case $response in
                [nN][oO]|[nN])
                    read -p "${YELLOW}[Migration CONFIRMATION]${NORMAL} Please enter how many tables the script will try to convert:" LIMIT

                    # update the new provided limit
                    isamLIST="$isamLIST LIMIT $LIMIT";
                    shift
                    ;;
                [yY][eE][ss]|[yY])
                    migration_notice "User double-checked there is not limit for migration"
                    shift
                    ;;
                *)
                    migration_error "Invalid response, script will end..."
                    exit 1;
                    ;;
            esac
        fi
fi

migration_notice "Getting MyISAM tables"
printf "$isamLIST \n" >> $ACCESS_LOG

RUN_TIME=$(TIMEFORMAT="%lU";{ time mysql -u$username -p$password $db -h$host -e "$isamLIST" --skip-column-names  > $OPERATIONS_LOG;}  2>&1 )

#check for errors
ERROR_MyISAM=$?

if [ "$ERROR_MyISAM" != 0 ]; then
    migration_error "Unable to get list of MyISAM tables."
    migration_hint "Using --exclude or --include? Please make sure the tables in the list are comma separated and each table is enclosed by single quote, e.g. --include 'users','posts'"
    migration_error "No more further actions taken due to the error.... Bye."
    exit 1;
fi

migration_notice "Query to get MyISAM tables took $RUN_TIME"

# check if --dry-run is enabled to list only what are the queries to be performed in real mode
if [ "$DRY_RUN" == "debug"  ]; then
    migration_notice "Debug mode enabled."
    migration_notice "No further actions are taken. Database is not affected"
    migration_notice "Please see $OPERATIONS_LOG and if you are sure about the commands in the log run the script without --mode"
    exit 0;
fi

# test operations log file exists
if [ ! -f $OPERATIONS_LOG ]; then printf "[Migration ERROR] Operations log file expected at $OPERATIONS_LOG does not exist. Unable to proceed... Bye" | tee -a $ACCESS_LOG && exit 1; fi;

#add csv header file
printf "Database Migration Engine Script Results\n" >> $STATISTICS_LOG
printf "SQL Statement,Time,Migrated,Error,Date\n" >> $STATISTICS_LOG

# open operations log file
while read line
    do
        if [ -n "$line" ]; then

            ALTER_RUN_TIME=$(TIMEFORMAT="%lU";{ time mysql -u$username -p$password $db -h$host -e "$line" --skip-column-names >> $ACCESS_LOG 2>$ERROR_LOG;} 2>&1 )

            ERROR_ALTER=$?
            ERROR_ALTER_MESSAGE=""
            MIGRATED=""

            if [ "$ERROR_ALTER" != 0 ]; then
                ERROR_ALTER_MESSAGE=$(cat $ERROR_LOG | sed '1!d')
                MIGRATED="NO"
                migration_error "ALTER STATEMENT: $line can not be processed due to following error:"
                migration_error "$ERROR_ALTER_MESSAGE"
            else
                MIGRATED="YES"
                migration_notice "ALTER STATEMENT: $line took $ALTER_RUN_TIME"
            fi

            #write csv file
            printf "$line,$ALTER_RUN_TIME,$MIGRATED,$ERROR_ALTER_MESSAGE,$(date +%Y-%m-%d:%H:%M:%S)\n" >> $STATISTICS_LOG

        fi

done < $OPERATIONS_LOG

migration_notice "Script completed."
migration_notice "Check statistic log at $STATISTICS_LOG"
migration_notice "Bye..."
sleep 3
exit 0;