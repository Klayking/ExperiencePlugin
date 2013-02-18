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
#include <geoip>

#define PLUGIN_VERSION "1.0"

// Database handle
new Handle:db = INVALID_HANDLE;

// Cvars
new Handle:cvar_tableName = INVALID_HANDLE;
new Handle:cvar_AddTime = INVALID_HANDLE;

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
	
	try
	{
		InitializeDatabase();
		RegisterCommands();
		
		PrintToServer("---------- Loaded the Experience Plugin ----------");
	}
	catch(int errorId)
	{
		new String:error[1024];
		
		switch( errorId )
		{
			case 1:
				error = "Could not connect to the database";
				break;
			default:
				error = "Generic Error";
				break;
		}
		
		PrintToServer( "Error: %s\r\n---------- Error loading the Experience Plugin ----------", error );
	}
}

################################# Database #################################
#
# Database commands for connecting and running queries
#

// Connect to the database
ConnectToDatabase()
{
	new String:error[255]
	db = SQL_DefConnect(error, sizeof(error))
	 
	if (db == INVALID_HANDLE)
	{
		throw 1;
	}
	
	return true;
}

InitializeDatabase()
{
	SendQuery( "CREATE TABLE IF NOT EXISTS `"<< cvar_tableName << "` ( `id` BIGINT (32) UNSIGNED NOT NULL AUTO_INCREMENT, `steam_id` VARCHAR (32) NOT NULL, `player_name` VARCHAR (128) NOT NULL, `level` BIGINT (32) UNSIGNED NOT NULL, `experience` BIGINT (64) UNSIGNED NOT NULL, `insert_date` DATETIME NOT NULL, `modified_date` DATETIME NOT NULL, PRIMARY KEY (`id`), KEY `steam_id` (`steam_id`), KEY `player_name` (`player_name`), KEY `insert_date` (`insert_date`), KEY `modified_date` (`modified_date`) ) ENGINE = INNODB DEFAULT CHARSET = latin1" );
}

// Do the query
SendQuery(String:query[])
{
	
	ConnectToDatabase();
	
	SQL_TQuery(db, SQL_ErrorCallback, "SET NAMES 'utf8'");
	SQL_TQuery(db, SQL_ErrorCallback, query);

	CloseHandle(db);
}

// Error logging
public SQL_ErrorCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual("", error))
		LogToFile(Logfile, "SQL Error: %s", error);
}

################################# Events #################################
#
# Events for the plugin
#

// When a client connects, insert them into the database
public OnClientAuthorized(client, const String:auth[])
{
	if ( IsFakeClient( client ) )
		return;

	CreateTimer( GetConVarFloat( cvar_AddTime ), timer_InsertPlayer, client);
}




################################# Timers #################################
#
# Timers for the plugin
#

public Action:timer_InsertPlayer(Handle:timer, any:data)
{
	new client = data;

	if (!IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
		return;

	new String:SteamID[32];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	new String:PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	ReplaceString(PlayerName, sizeof(PlayerName), "\"", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "'", "");
	ReplaceString(PlayerName, sizeof(PlayerName), ";", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "´", "");
	ReplaceString(PlayerName, sizeof(PlayerName), "`", "");

	new String:query[1024];
	Format(query, sizeof(query), "INSERT INTO player_tracker (steamid, playername, level, experience, insert_date, modified_date) \
													  VALUES ('%s', '%s', 1, 0, NOW, NOW ) \
													  ON DUPLICATE KEY UPDATE modified_date = NOW()",
													  SteamID, PlayerName );
	SendQuery(query);
}


################################# Commands #################################
#
# Commands for the plugin
#
		
RegisterCommands()
{	
	// Plugin version public Cvar
	CreateConVar("sm_experience_version", PLUGIN_VERSION, "Experience Tracjer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Config Cvars
	cvar_AddTime = CreateConVar("sm_experience_addtime", "90.0", "Add/update players in the database after this many seconds", FCVAR_PLUGIN, true, 1.0);
	cvar_AddTime = CreateConVar("sm_experience_tableName", "experience_tracker", "Table Name to use for the tracker", FCVAR_PLUGIN, true, 1.0);

	// Make that config!
	AutoExecConfig(true, "experience");

	// Log file for SQL errors
	BuildPath(Path_SM, Logfile, sizeof(Logfile), "logs/experience.log");

	// Init player arrays
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			CreateTimer(GetConVarFloat(cvar_AddTime), timer_InsertPlayer, i);
	}
}