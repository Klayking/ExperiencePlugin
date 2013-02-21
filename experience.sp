/*
-----------------------------------------------------------------------------
Experience Plugin - Sourcemod Plugin
-----------------------------------------------------------------------------
Code Written By Aaron Scherer (c) 2013
Visit www.seductiveturtle.com in TF2!
-----------------------------------------------------------------------------
This plugin is a simple experience and level plugin. Players will get 
experience from killing enemies, capturing points, and other things. As they
get more points, they will gain levels. With levels, I'm planning on adding 
benefits.
 
Thank you and enjoy!
- Aaron
-----------------------------------------------------------------------------
Version History
-- 1.0 ( Feb 18, 2013 )
 . Initial release!
-----------------------------------------------------------------------------
*/

#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0"

// Database handle
new Handle:db = INVALID_HANDLE;

// Logfile path var
new String:Logfile[PLATFORM_MAX_PATH];

// Plugin Info
public Plugin:myinfo =
{
	name = "Experience Plugin",
	author = "Aaron Scherer",
	description = "Tracks basic player experience to a MySQL database",
	version = PLUGIN_VERSION,
	url = "http://www.seductiveturtle.com.com/"
};

public OnPluginStart()
{
	PrintToServer("---------- Initializing the Experience Plugin ----------");
	
	switch(Initialize())
	{
		case 1:
			PrintToServer("Error: %s\r\n--------- Error loading the Experience Plugin ---------", "Failed to Register the Commands!" );
		case 2:
			PrintToServer("Error: %s\r\n--------- Error loading the Experience Plugin ---------", "Failed to Initialize the Database!");
		case 3:
			PrintToServer("Error: %s\r\n--------- Error loading the Experience Plugin ---------", "Failed to Load the Config!");
		default:
			PrintToServer("---------- Loaded the Experience Plugin ----------");
	}
}

Initialize()
{
	if(!RegisterCommands()) {
		return 1;
	}
	
	if(!InitializeDatabase()) {
		return 2;
	}
	
	return 0;
}

/************************** Database **************************
*
* Database commands for connecting and running queries
*
*/

ConnectToDatabase()
{
	new String:error[255];
	db = SQL_DefConnect(error, sizeof(error));
	 
	if (db == INVALID_HANDLE)
	{
		return false;
	}
	
	return true;
}

SendQuery(String:query[])
{
	
	if(ConnectToDatabase()) {
	
		SQL_TQuery(db, SQL_ErrorCallback, "SET NAMES 'utf8'");
		SQL_TQuery(db, SQL_ErrorCallback, query);

		CloseHandle(db);
		
		return true;
	}
	return false;
}

public SQL_ErrorCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual("", error))
	{
		LogToFile(Logfile, "SQL Error: %s", error);
		PrintToServer( "There was an error with your query! Check the logs." );
	}
}

/************************** Events **************************
*
* Events for the plugin
*
*/

public OnClientAuthorized(client, const String:auth[])
{
	
	new String:PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	
	PrintToServer("----------Client Authorization Check for Experience Plugin <%s>----------", PlayerName );
	
	
	
	if ( IsFakeClient( client ) ) {
		return false;
	}

	PrintToServer("Inserting Player: %s", PlayerName);
	InsertPlayer(client);
	
	return true;
}

public Event_PlayerKill( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client_id = GetEventInt(event, "attacker");
	
	new client = GetClientOfUserId( client_id );
	if ( client != 0 && IsFakeClient( client ) ) {
		return false;
	}
	
	return FetchAndInsertExperience( "kill", client );
}

public Event_PlayerAssist( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client_id = GetEventInt(event, "assister");
	if( client_id == -1 )
	{
		return false;
	}
	
	
	new client = GetClientOfUserId( client_id );
	if ( client != 0 && IsFakeClient( client ) ) {
		return false;
	}
	
	return FetchAndInsertExperience( "assist", client );
}

FetchAndInsertExperience( const String:event_type[], client )
{	
	new TFClassType:client_class = TF2_GetPlayerClass(client);
	if (client_class == TFClass_Unknown)
		return false;
	
	new String:client_class_string[16];
	GetClientClassString( client_class_string, client_class );
	
	new String:query[1024];
	Format( query, sizeof( query ), "SELECT ec.value FROM experience_config AS ec JOIN experience_config_category AS ecc ON ec.config_category_id = ecc.id WHERE ecc.name != 'basic' AND ec.key = '%s' and ecc.name IN( 'default', '%s' ) ORDER BY ecc.name != 'default' DESC LIMIT 1;", event_type, client_class_string );
	
	if( ConnectToDatabase() ) {
		SQL_TQuery( db, GetExperienceAndInsert, query, client );
		return true;
	}
	
	return false;
}

public GetExperienceAndInsert( Handle:owner, Handle:hndl, const String:error[], any:data )
{
	
	new client = data;
	
	new TFClassType:client_class = TF2_GetPlayerClass(client);
	if ( client_class == TFClass_Unknown )
		return false;
	
	new String:client_class_string[16];
	GetClientClassString( client_class_string, client_class );
	
	if( SQL_GetRowCount( hndl ) == 1) {
		
		SQL_FetchRow( hndl );
		
		new experience = SQL_FetchInt( hndl, 0 );
		
		new String:SteamID[32];
		GetClientAuthString(client, SteamID, sizeof(SteamID));

		PrintToChat( client, "You've gained %d experience!", experience );
		PrintToServer( "%s<%s> has gained %d experience.", client, SteamID, experience );
		
		new String:query[1024];
		Format( query, sizeof( query ), "INSERT INTO `experience_player_class` ( experience_player_id, player_class, level, experience, insert_date, modified_date ) VALUES( ( SELECT id FROM experience_player WHERE steam_id = '%s' ), '%s', 1, %d, NOW(), NOW() ) ON DUPLICATE KEY UPDATE experience = experience + %d, modified_date = NOW();", SteamID, client_class_string, experience, experience );
		
		SendQuery( query );
		
		return true;
	}
	
	LogToFile(Logfile, "SQL Error: %s", "There was an error finding the configs for the experience." );
	PrintToServer( "There was an error with your query! Check the logs." );
	return false;
}

/************************** Actions **************************
*
* Actions for the plugin
*
*/

Action:InsertPlayer(client)
{

	new String:SteamID[32];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	new String:PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	ReplaceString(PlayerName, sizeof(PlayerName), "\"", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "'", "");
	ReplaceString(PlayerName, sizeof(PlayerName), ";", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "´", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "`", "");

	PrintToServer("Atempting to insert %s<%s> into `experience_tracker`", PlayerName, SteamID);
	
	new String:query[1024];
	Format(query, sizeof(query), "INSERT INTO `experience_player` (steam_id, player_name, insert_date, modified_date)  VALUES ('%s', '%s', NOW(), NOW() ) ON DUPLICATE KEY UPDATE modified_date = NOW();", SteamID, PlayerName );
	
	SendQuery(query);
}


/************************** Commands **************************
*
* Commands for the plugin
*
*/

GetClientClassString( String:class_name[16], TFClassType:class_type )
{
	if( class_type == TFClass_Scout )
		class_name = "scout";
	if( class_type == TFClass_Sniper )
		class_name = "sniper";
	if( class_type == TFClass_Soldier )
		class_name = "soldier";
	if( class_type == TFClass_DemoMan )
		class_name = "demoman";
	if( class_type == TFClass_Medic )
		class_name = "medic";
	if( class_type == TFClass_Heavy )
		class_name = "heavy";
	if( class_type == TFClass_Pyro )
		class_name = "pyro";
	if( class_type == TFClass_Spy )
		class_name = "spy";
	if( class_type == TFClass_Engineer )
		class_name = "engineer";	
	return true;
}

RegisterCommands()
{	
	// Plugin version public Cvar
	CreateConVar("sm_experience_version", PLUGIN_VERSION, "Experience Tracker Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	HookEvent( "player_death", Event_PlayerKill );
	HookEvent( "player_death", Event_PlayerAssist );

	// Log file for SQL errors
	BuildPath(Path_SM, Logfile, sizeof(Logfile), "logs/experience.log");	
	return true;
}

InitializeDatabase()
{
	
	new String:query[1024];
	Format( query, sizeof(query), "CREATE TABLE IF NOT EXISTS `experience_player` ( `id` int(11) unsigned NOT NULL AUTO_INCREMENT, `steam_id` varchar(32) NOT NULL DEFAULT '', `player_name` varchar(128) NOT NULL DEFAULT '', `insert_date` datetime NOT NULL, `modified_date` datetime NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `steam_id` (`steam_id`), KEY `player_name` (`player_name`), KEY `insert_date` (`insert_date`), KEY `modified_date` (`modified_date`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;CREATE TABLE IF NOT EXISTS `experience_config_category` ( `id` int(11) unsigned NOT NULL, `name` varchar(64) NOT NULL DEFAULT '', PRIMARY KEY (`id`), KEY `name` (`name`) ) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;" );
	
	new success = SendQuery( query );
	
	if( success ) {
		Format( query, sizeof( query ), "CREATE TABLE IF NOT EXISTS `experience_config` ( `id` int(11) unsigned NOT NULL AUTO_INCREMENT, `config_category_id` int(11) unsigned NOT NULL, `key` varchar(64) NOT NULL DEFAULT '', `type` varchar(64) NOT NULL DEFAULT 'float', `value` varchar(64) NOT NULL DEFAULT '', PRIMARY KEY (`id`), UNIQUE KEY `config_category_id_2` (`config_category_id`,`key`), KEY `config_category_id` (`config_category_id`), KEY `key` (`key`), KEY `type` (`type`) ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;" );
		
		success = SendQuery( query );
	}
	
	if( ConnectToDatabase() ) {
		SQL_TQuery(db, InitializeTables, "SELECT * FROM experience_config;");
	}
	
	return success;
}

public InitializeTables( Handle:owner, Handle:hndl, const String:error[], any:data )
{
	if( SQL_GetRowCount( hndl ) < 1 ) {
		
		new String:query[1024];
		Format( query, sizeof( query ), "LOCK TABLES `experience_config` WRITE; INSERT INTO `experience_config` (`id`, `config_category_id`, `key`, `type`, `value`) VALUES (1,1,'max_class_level','int','20'), (2,1,'experience_multiplier','float','1'), (3,2,'kill','float','30'), (4,2,'assist','float','15');UNLOCK TABLES; LOCK TABLES `experience_config_category` WRITE; INSERT INTO `experience_config_category` (`id`, `name`) VALUES (1,'basic'), (2,'default'); UNLOCK TABLES;" );
		
		return SendQuery( query );
	}
	
	return false;
}