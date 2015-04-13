# mysql-engine-migration
Bash script to handle mysql engine migrations

./convert.sh --help

Convert MyISAM tables to InnoDB engine
Version 1.0
https://github.com/jazlopez/mysql-engine-migration

Usage: convert.sh 

	--include     Only convert specified tables. Separate the list by comma and enclose each table name by single quote e.g. include='users','post','forums'
	              If you define an include list --limit is ignored.
	              --include takes first precedence and will make the script to ignore --exclude.
	              Beware that defining a large number of tables can overload the server.
	--exclude     Do not convert the specified tables. Separate the list by comma and enclose each table name by single quote e.g. --exclude 'users','post','forums'
	--limit       Limit how many tables you want to convert in the batch. If not specified it will convert all MyISAM tables
	              If --include option used this value is ignored
	--mode        Use --mode debug to generate only the commands to an output file. Database is not affected.
	--log-dir     Log directory. Must be writable. If not defined the log directory is created on user's home path.


Developer Contact Information:
	Jaziel Lopez
	juan.jaziel@gmail.com
	Tijuana, MX
	https://github.com/jazlopez
	https://bitbucket.org/jazlopez
