/************************** Database **************************
*
* Database commands for connecting and running queries
*
*/

// Database handle
new Handle:db = INVALID_HANDLE;

// Logfile path var
new String:Logfile[PLATFORM_MAX_PATH];

public Database_Connect()
{
	new String:error[255];
	db = SQL_DefConnect(error, sizeof(error));
	 
	if (db == INVALID_HANDLE)
	{
		return false;
	}
	
	return true;
}

public Database_FastQuery(String:query[])
{
	return Database_Query( query, Database_ErrorCallback, query );
}

public Database_Query( String:query[], CallbackType callback, any:data )
{
	if( Database_Connect() ) {
		SQL_TQuery( db, callback, query, data );
		
		CloseHandle( db );
		
		return true;
	}
	
	return false;
}

public Database_Initialize()
{
	
	new String:query[1024];
	Format( query, sizeof(query), "CREATE TABLE IF NOT EXISTS `experience_player` ( `id` int(11) unsigned NOT NULL AUTO_INCREMENT, `steam_id` varchar(32) NOT NULL DEFAULT '', `player_name` varchar(128) NOT NULL DEFAULT '', `insert_date` datetime NOT NULL, `modified_date` datetime NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `steam_id` (`steam_id`), KEY `player_name` (`player_name`), KEY `insert_date` (`insert_date`), KEY `modified_date` (`modified_date`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;CREATE TABLE IF NOT EXISTS `experience_config_category` ( `id` int(11) unsigned NOT NULL, `name` varchar(64) NOT NULL DEFAULT '', PRIMARY KEY (`id`), KEY `name` (`name`) ) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;" );
	
	new success = Database_FastQuery( query );
	
	if( success ) {
		Format( query, sizeof( query ), "CREATE TABLE IF NOT EXISTS `experience_config` ( `id` int(11) unsigned NOT NULL AUTO_INCREMENT, `config_category_id` int(11) unsigned NOT NULL, `key` varchar(64) NOT NULL DEFAULT '', `type` varchar(64) NOT NULL DEFAULT 'float', `value` varchar(64) NOT NULL DEFAULT '', PRIMARY KEY (`id`), UNIQUE KEY `config_category_id_2` (`config_category_id`,`key`), KEY `config_category_id` (`config_category_id`), KEY `key` (`key`), KEY `type` (`type`) ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;" );
		
		success = Database_FastQuery( query );
	}
	
	if( ConnectToDatabase() ) {
		Database_Query( Database_InitializeTables, "SELECT * FROM experience_config;" );
	}
	
	return success;
}

public Database_ErrorCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual("", error))
	{
		LogToFile(Logfile, "SQL Error: %s", error);
		PrintToServer( "There was an error with your query! Check the logs." );
	}
}

public Database_InsertClient( client )
{
	new String:SteamID[32];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	new String:PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	ReplaceString(PlayerName, sizeof(PlayerName), "\"", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "\"", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "'", "");
	ReplaceString(PlayerName, sizeof(PlayerName), ";", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "´", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "`", "");

	PrintToServer("Atempting to insert %s<%s> into `experience_tracker`", PlayerName, SteamID);
	
	new String:query[1024];
	Format(query, sizeof(query), "INSERT INTO `experience_player` (steam_id, player_name, insert_date, modified_date)  VALUES ('%s', '%s', NOW(), NOW() ) ON DUPLICATE KEY UPDATE modified_date = NOW();", SteamID, PlayerName );
	
	Database_FastQuery(query);
}

public Database_InitializeTables( Handle:owner, Handle:hndl, const String:error[], any:data )
{
	if( SQL_GetRowCount( hndl ) < 1 ) {
		
		new String:query[1024];
		Format( query, sizeof( query ), "LOCK TABLES `experience_config` WRITE; INSERT INTO `experience_config` (`id`, `config_category_id`, `key`, `type`, `value`) VALUES (1,1,'max_class_level','int','20'), (2,1,'experience_multiplier','float','1'), (3,2,'kill','float','30'), (4,2,'assist','float','15');UNLOCK TABLES; LOCK TABLES `experience_config_category` WRITE; INSERT INTO `experience_config_category` (`id`, `name`) VALUES (1,'basic'), (2,'default'); UNLOCK TABLES;" );
		
		return Database_FastQuery( query );
	}
	
	return false;
}