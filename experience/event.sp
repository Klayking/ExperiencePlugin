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
	Event_InsertPlayer(client);
	
	return true;
}

public Event_PlayerKill( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client_id = GetEventInt(event, "attacker");
	
	new client = GetClientOfUserId( client_id );
	if ( client != 0 && IsFakeClient( client ) ) {
		return false;
	}
	
	return Database_FetchAndInsertExperience( "kill", client );
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
	
	return Database_FetchAndInsertExperience( "assist", client );
}

public Event_InsertPlayer( client )
{
	return Database_InsertClient( client );
}