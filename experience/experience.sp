/************************** Commands **************************
*
* Commands and Helpers for the plugin
*
*/

public Experience_GetExperienceAndInsert( Handle:owner, Handle:hndl, const String:error[], any:data )
{
	
	new client = data;
	
	new TFClassType:client_class = TF2_GetPlayerClass(client);
	if ( client_class == TFClass_Unknown )
		return false;
	
	new String:client_class_string[16];
	Experience_GetClientClassString( client_class_string, client_class );
	
	if( SQL_GetRowCount( hndl ) == 1) {
		
		SQL_FetchRow( hndl );
		
		new experience = SQL_FetchInt( hndl, 0 );
		
		new String:SteamID[32];
		GetClientAuthString(client, SteamID, sizeof(SteamID));

		PrintToChat( client, "You've gained %d experience!", experience );
		PrintToServer( "%s<%s> has gained %d experience.", client, SteamID, experience );
		
		new String:query[1024];
		Format( query, sizeof( query ), "INSERT INTO `experience_player_class` ( experience_player_id, player_class, level, experience, insert_date, modified_date ) VALUES( ( SELECT id FROM experience_player WHERE steam_id = '%s' ), '%s', 1, %d, NOW(), NOW() ) ON DUPLICATE KEY UPDATE experience = experience + %d, modified_date = NOW();", SteamID, client_class_string, experience, experience );
		
		Database_FastQuery( query );
		
		return true;
	}
	
	LogToFile(Logfile, "SQL Error: %s", "There was an error finding the configs for the experience." );
	PrintToServer( "There was an error with your query! Check the logs." );
	return false;
}

public Experience_GetClientClassString( String:class_name[16], TFClassType:class_type )
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

public Experience_FetchAndInsertExperience( const String:event_type[], client )
{	
	new TFClassType:client_class = TF2_GetPlayerClass(client);
	if (client_class == TFClass_Unknown)
		return false;
	
	new String:client_class_string[16];
	Experience_GetClientClassString( client_class_string, client_class );
	
	new String:query[1024];
	Format( query, sizeof( query ), "SELECT ec.value FROM experience_config AS ec JOIN experience_config_category AS ecc ON ec.config_category_id = ecc.id WHERE ecc.name != 'basic' AND ec.key = '%s' and ecc.name IN( 'default', '%s' ) ORDER BY ecc.name != 'default' DESC LIMIT 1;", event_type, client_class_string );
	
	return Database_ThreadQuery( query, Experience_GetExperienceAndInsert, query, data );
}