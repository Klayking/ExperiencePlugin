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
#include <sdktools>
#include <colors>
#include <tf2>
#include <tf2_stocks>

#include "experience/database.sp"
#include "experience/event.sp"
#include "experience/experience.sp"

#define PLUGIN_VERSION  "1.0"
#define MAX_NAME_LENGTH 32

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
	
	switch( Initialize( ) )
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

public Initialize()
{
	if(!RegisterCommands()) {
		return 1;
	}
	
	if(!Database_Initialize()) {
		return 2;
	}
	
	return 0;
}

public RegisterCommands()
{	
	// Plugin version public Cvar
	CreateConVar("sm_experience_version", PLUGIN_VERSION, "Experience Tracker Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	HookEvent( "player_death", Event_PlayerKill );
	HookEvent( "player_death", Event_PlayerAssist );

	// Log file for SQL errors
	BuildPath(Path_SM, Logfile, sizeof(Logfile), "logs/experience.log");	
	return true;
}
