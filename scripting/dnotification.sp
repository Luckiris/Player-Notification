#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <sdkhooks>
#include <PTaH>

/* ConVar of the plugin */
ConVar cvTagConnect;
ConVar cvTagDisconnect;
ConVar cvHideConnect;
ConVar cvHideDisconnect;
ConVar cvHideAdminConnect;
ConVar cvHideAdminDisconnect;
ConVar cvHideAdminTeam;
ConVar cvAdminSeeOtherAdmin;
ConVar cvHideAdminSpectator;
ConVar cvHideAdminConsole;

/* Global Vars of the plugin */
ArrayList gAdminList; // <- Contains the list of admins connected on the server 
bool gIsInvisible[MAXPLAYERS + 1]; // <- Contains the list of the admins in spectator

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Dream - Player view and notification",
	author = "Luckiris",
	description = "Manage what the player can see in-game",
	version = "1.0",
	url = "http://dream-community.de"
};

public void OnPluginStart()
{
	LoadTranslations("dnotification.phrases.txt");
	
	cvTagConnect = CreateConVar("sm_dnotification_tag_connect", "[DREAM]", "Tag before the connect message on the server");
	cvTagDisconnect = CreateConVar("sm_dnotification_tag_disconnect", "[DREAM]", "Tag before the disconnect message on the server");
	cvHideConnect = CreateConVar("sm_dnotification_hide_normal_connect", "1", "Hide the normal connet message");
	cvHideDisconnect = CreateConVar("sm_dnotification_hide_normal_disconnect", "1", "Hide the normal disconnect message");
	cvHideAdminConnect = CreateConVar("sm_dnotification_hide_admin_connect", "1", "Hide the admin connecting");
	cvHideAdminDisconnect = CreateConVar("sm_dnotification_hide_admin_disconnect", "1", "Hide the admin disconnecting");
	cvHideAdminTeam = CreateConVar("sm_dnotification_hide_admin_team", "1", "Hide the admin joining a team");
	cvAdminSeeOtherAdmin = CreateConVar("sm_dnotification_admin_see_message", "1", "Admins can see other admins connecting");
	cvHideAdminSpectator = CreateConVar("sm_dnotification_hide_admin_spectator", "1", "Hide the admins in spectator");
	cvHideAdminConsole = CreateConVar("sm_dnotification_hide_admin_console", "1", "Block the commands that could show admins in console");
	gAdminList = new ArrayList();

	HookEvent("player_connect", EventConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", EventDisconnect, EventHookMode_Pre);
	HookEvent("player_team", EventTeam, EventHookMode_Pre);
	
	PTaH(PTaH_ExecuteStringCommand, Hook, Message);

	AutoExecConfig(true, "dnotification");
}

/* Messages */
public Action EventConnect(Handle event, char[] name, bool dontBroadcast)
{
	/*	Hide the default connection message if needed
	
	*/
	if (cvHideConnect.BoolValue) 
	{
		/* Hiding the normal event */
		SetEventBroadcast(event, true);
	}
	else
	{
		SetEventBroadcast(event, false);
	}
	
	return Plugin_Continue;
}

public Action EventDisconnect(Handle event, char[] name, bool dontBroadcast)
{	
	/*	Hide the default leaving message if needed
		Prepare a new leaving message if needed with new information.
			
		TAG - NAME OF PLAYER - left the server (translated) - REASON
		
		IF the client is admin
		THEN the message is hidden for all clients and the client is removed from the list of admins
	
	*/
	
	if (cvHideDisconnect.BoolValue) 
	{
		/* Hiding the normal event */
		SetEventBroadcast(event, true);

		/* Variables for the message */
		char tag[120];
		char playerName[120];
		char reason[1024];
		int targetNumber = gAdminList.FindValue(GetEventInt(event, "userid"));
		bool isTargetAdmin = false;
		
		/* Filling the vars */
		GetConVarString(cvTagDisconnect, tag, sizeof(tag));
		GetEventString(event, "name", playerName, sizeof(playerName));
		GetEventString(event, "reason", reason, sizeof(reason));
		
		/* Removing the player from the global list */
		if (targetNumber != -1)
		{
			isTargetAdmin = true;
			gAdminList.Erase(targetNumber);
		}
		
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (IsValidClient(i) && (!cvHideAdminDisconnect.BoolValue || !isTargetAdmin))
			{
				PrintToChat(i, " \x01\x04%s\x01 \x0B%s\x01 \x06%t\x01 [\x03%s\x01]", tag, playerName, "Disconnected", reason);
			}
			else if (IsValidClient(i) && (cvHideAdminDisconnect.BoolValue && isTargetAdmin && IsAdmin(i, ADMFLAG_BAN) && cvAdminSeeOtherAdmin.BoolValue))
			{
				PrintToChat(i, " \x01\x04%s\x01 \x0B%s\x01 \x06%t\x01 [\x03%s\x01]", tag, playerName, "Disconnected", reason);
			}
		}
	}
	else
	{
		SetEventBroadcast(event, false);
	}
	
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	/*	Prepare a new connection message if needed with new information.
		
		TAG - NAME OF PLAYER - COUNTRY OF PLAYER - STEAM ID OF PLAYER - joined the server (translated)
		
		IF the client is admin
		THEN the message is hidden for all clients and the client is added to the list of admins
	*/
	if (cvHideConnect.BoolValue)
	{
		/* Variables for the message */
		char tag[120];
		char name[120];
		char ip[20];
		char country[120];
		char steamID[64];
		bool isTargetAdmin;
		
		/* Filling the variables */
		GetConVarString(cvTagConnect, tag, sizeof(tag));
		GetClientName(client, name, sizeof(name));
		GetClientIP(client, ip, sizeof(ip));
		GeoipCountry(ip, country, sizeof(country));
		GetClientAuthId(client, AuthId_Engine, steamID, sizeof(steamID), true);
		isTargetAdmin = IsAdmin(client, ADMFLAG_BAN);
		
		/* Adding the admin to the global list */
		if (isTargetAdmin)
		{
			gAdminList.Push(GetClientUserId(client));
		}
	
		/* Sending the message to the players */ 
		for (int i = 1; i < MAXPLAYERS; i++)
		{	
			if (IsValidClient(i) && (!cvHideAdminConnect.BoolValue || !isTargetAdmin))
			{
				PrintToChat(i, " \x01\x04%s\x01 \x0B%s\x01 (\x0E%s\x01) [\x03%s\x01] \x09%t", tag, name, country, steamID, "Connected");
			}
			else if (IsValidClient(i) && (cvHideAdminDisconnect.BoolValue && isTargetAdmin && IsAdmin(i, ADMFLAG_BAN)  && cvAdminSeeOtherAdmin.BoolValue))
			{
				PrintToChat(i, " \x01\x04%s\x01 \x0B%s\x01 (\x0E%s\x01) [\x03%s\x01] \x09%t", tag, name, country, steamID, "Connected");
			}
		}
		gIsInvisible[client] = false;
	}		
}

/* TEAM */ 
public Action EventTeam(Handle event, char[] name, bool dontBroadcast)
{
	/*	Hide the team join message if needed
	
		IF the client is admin
		THEN we hide the message "player joined team"
	*/
	if (cvHideAdminTeam.BoolValue)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (IsValidClient(client) && IsAdmin(client, ADMFLAG_BAN))
		{
			/* Hiding the normal event */
			SetEventBroadcast(event, true);
			
			if (GetEventInt(event, "team") == 1)
			{
				gIsInvisible[client] = true;
			}
			else
			{
				gIsInvisible[client] = false;
			}
		}
	}
	
	/* Apply scorebard visibility changes for all players */
	if (cvHideAdminSpectator.BoolValue)
	{
		SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, HookSpec);
	}

	return Plugin_Continue;
}

/* INVISIBLE */
public void HookSpec(int entity)
{
	/* Hide the client in the scoreboard regarding his status */
	int data = FindSendPropInfo("CCSPlayerResource", "m_bConnected");
	
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (IsValidClient(i))
		{
			SetEntData(entity, data + (i * 4), !gIsInvisible[i], _, true);
		}
	}
}

public void OnClientDisconnect_Post(int client)
{
	/* Turn off the invisibility */
	gIsInvisible[client] = false;
}

/* PTaH */
public Action Message(int client, char message[1024])
{
	/*	Block the console commands status and ping in order to hide the admins
	
		IF the player is not admin
		THEN he doesn't have access to those commands
	
	*/
	Action result = Plugin_Continue;
	
	if (cvHideAdminConsole.BoolValue)
	{
		if (IsValidClient(client))
		{
			bool admin = IsAdmin(client, ADMFLAG_BAN);
			if (StrContains(message, "ping") != -1 || StrContains(message, "status") != -1)
			{
				result = Plugin_Handled;
			}
			if (admin)
			{
				result = Plugin_Continue;
			}
		}
	}
	return result;
}

/* Utils */
public bool IsAdmin(int client, int flag)
{
	/*	Check if the clients has the flags
	
	*/
	return CheckCommandAccess(client, "sm_admin", flag, true);
}

public bool IsValidClient(int client)
{
	/*	Check if the client is in game, connected and not a bot
	
	*/
	bool valid = false;
	if (client > 0 && client < MAXPLAYERS && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{
		valid = true;
	}
	return valid;
}