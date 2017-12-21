#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <sdkhooks>
#include <PTaH>
#include <multicolors>
#include <cstrike>

#pragma newdecls required

/* ConVar */
ConVar cvHideConnect;
ConVar cvHideDisconnect;
ConVar cvHideAdminConnect;
ConVar cvHideAdminDisconnect;
ConVar cvHideAdminTeam;
ConVar cvAdminSeeOtherAdmin;
ConVar cvSupporterSeeOtherAdmin;
ConVar cvHideAdminSpectator;
ConVar cvHideAdminConsole;

/* Global Vars */
ArrayList gAdminList; // <- Contains the list of admins connected on the server 
ArrayList gSupporterList; // <- Contains the list of supporters connected on the server 
bool gIsInvisible[MAXPLAYERS + 1]; // <- Contains the status of the clients
int gPlayerManager; // <- Player entity manager

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
	LoadTranslations("dnotification.phrases");
	LoadTranslations("common.phrases");
	
	cvHideConnect = CreateConVar("sm_dnotification_hide_normal_connect", "1", "Hide the normal connet message");
	cvHideDisconnect = CreateConVar("sm_dnotification_hide_normal_disconnect", "1", "Hide the normal disconnect message");
	cvHideAdminConnect = CreateConVar("sm_dnotification_hide_admin_connect", "1", "Hide the admin connecting");
	cvHideAdminDisconnect = CreateConVar("sm_dnotification_hide_admin_disconnect", "1", "Hide the admin disconnecting");
	cvHideAdminTeam = CreateConVar("sm_dnotification_hide_admin_team", "1", "Hide the admin joining a team");
	cvAdminSeeOtherAdmin = CreateConVar("sm_dnotification_admin_see_message", "1", "Admins can see other admins connecting/disconnecting");
	cvSupporterSeeOtherAdmin = CreateConVar("sm_dnotification_admin_see_message", "1", "Supporters can see admins connecting/disconnecting");
	cvHideAdminSpectator = CreateConVar("sm_dnotification_hide_admin_spectator", "1", "Hide the admins in spectator");
	cvHideAdminConsole = CreateConVar("sm_dnotification_hide_admin_console", "1", "Block the commands that could show admins in console");
	
	gAdminList = new ArrayList();
	gSupporterList = new ArrayList();

	HookEvent("player_connect", EventConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", EventDisconnect, EventHookMode_Pre);
	HookEvent("player_team", EventTeam, EventHookMode_Pre);
	
	PTaH(PTaH_ExecuteStringCommand, Hook, Message);

	AutoExecConfig(true, "dnotification");
	
	RegAdminCmd("sm_adminspec", CommandSpecList, ADMFLAG_SLAY, "Command to list the admins in spectator in invisible mode");
	RegAdminCmd("sm_stealth", CommandStealth, ADMFLAG_BAN, "Command to put yourself in invisible mode");
	RegAdminCmd("sm_info", CommandInfo, ADMFLAG_SLAY, "Command to see some informations about clients");
}

/* Map start and end */
public void OnMapStart()
{
	gAdminList = new ArrayList();
	gSupporterList = new ArrayList();	
	
	gPlayerManager = FindEntityByClassname(-1, "cs_player_manager");
	if(gPlayerManager != -1)
	{
		SDKHook(gPlayerManager, SDKHook_ThinkPost, HookSpec);
	}
}

public void OnMapEnd()
{
	delete gAdminList;
	delete gSupporterList;
}

/* Admins commands */
public Action CommandSpecList(int client, int args)
{
	char list[250] = "";
	int count = 0;
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (IsValidClient(i))
		{
			if (IsAdmin(i) && GetClientTeam(i) == CS_TEAM_SPECTATOR)
			{
				Format(list, sizeof(list), "%s %N - ", list, i);
				count++;
			}
		}
	}
	if (count > 0)
		CPrintToChat(client, "[SM] List of admins in Spectators : %s.", list);
	else
		CPrintToChat(client, "[SM] No admins in Spectators.");			

	return Plugin_Handled;
}

public Action CommandStealth(int client, int args)
{
	if (gIsInvisible[client])
	{
		gIsInvisible[client] = false;
		CPrintToChat(client, "[SM] You are now visible.");
		LogAction(client, -1, "\"%L\" toggled off his invisibility mode in Spectators", client);				
	}
	else
	{
		gIsInvisible[client] = true;
		if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		CPrintToChat(client, "[SM] You are now invisible.");
		LogAction(client, -1, "\"%L\" toggled on his invisibility mode in Spectators", client);		
	}

	return Plugin_Handled;
}

public Action CommandInfo(int client, int args)
{
	/* Variables for the informations */
	char name[MAX_NAME_LENGTH];
	char ip[20];
	char country[64];
	char steamID[64];
	bool isAdmin, isSupporter, isVip;	
	Panel panel;
	int target;
	char content[250] = "";
	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_info <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		target = target_list[i];
		
		/* Filling the variables */
		GetClientName(target, name, sizeof(name));
		GetClientIP(target, ip, sizeof(ip));
		GeoipCountry(ip, country, sizeof(country));
		GetClientAuthId(target, AuthId_Engine, steamID, sizeof(steamID), true);
		isAdmin = IsAdmin(target);
		isSupporter = IsAdmin(target, ADMFLAG_SLAY);
		isVip = IsAdmin(target, ADMFLAG_CUSTOM5);
		
		panel = new Panel();
		
		/* Title */
		if (isAdmin)
		{		
			Format(content, sizeof(content), "Admin");			
		}
		else if (isSupporter)
		{
			Format(content, sizeof(content), "Supporter");			
		}
		if (isVip)
		{
			Format(content, sizeof(content), "%s - VIP", content);			
		}		
		Format(content, sizeof(content), "%s - %s", name, content);			
		panel.SetTitle(content);
		panel.DrawItem("", ITEMDRAW_SPACER);
		
		/* Country */
		Format(content, sizeof(content), "%s", country);	
		panel.DrawText(content);
		panel.DrawItem("", ITEMDRAW_SPACER);
		
		/* STEAM ID */
		Format(content, sizeof(content), "%s", steamID);	
		panel.DrawText(content);
		panel.DrawItem("", ITEMDRAW_SPACER);
		
		/* EXIT BUTTON */		
		panel.CurrentKey = GetMaxPageItems(panel.Style);
		panel.DrawItem("Exit", ITEMDRAW_CONTROL);
		
		panel.Send(client, Handler_DoNothing, 30);
	}	

	delete panel;
	
	return Plugin_Handled;
}

public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)
{
	/* Do nothing */
}


/* Messages */
public Action EventConnect(Handle event, char[] name, bool dontBroadcast)
{
	/*	Hide the default connection message if needed
	
	*/
	if (cvHideConnect.BoolValue) 
		SetEventBroadcast(event, true);
	else
		SetEventBroadcast(event, false);
	
	return Plugin_Continue;
}

public Action EventDisconnect(Handle event, char[] name, bool dontBroadcast)
{	
	/*	Hide the default leaving message if needed
		Prepare a new leaving message if needed with new information.
		
		IF the client is admin
		THEN the message is hidden for all clients and the client is removed from the list of admins
	
	*/
	
	if (cvHideDisconnect.BoolValue) 
	{
		/* Hiding the normal event */
		SetEventBroadcast(event, true);

		/* Variables for the message */
		char playerName[MAX_NAME_LENGTH];
		char reason[128];
		int adminNumber = gAdminList.FindValue(GetEventInt(event, "userid"));
		int supporterNumber = gSupporterList.FindValue(GetEventInt(event, "userid"));
		bool isTargetAdmin = false;
		bool isTargetSupporter = false;
		bool isPlayerAdmin, isPlayerSupporter;
		
		/* Filling the vars */
		GetEventString(event, "name", playerName, sizeof(playerName));
		GetEventString(event, "reason", reason, sizeof(reason));
		
		/* Removing the player from the global list */
		if (adminNumber != -1)
		{
			isTargetAdmin = true;
			gAdminList.Erase(adminNumber);
		}
		if (supporterNumber != -1)
		{
			isTargetSupporter = true;
			gSupporterList.Erase(supporterNumber);
		}
		
		/* Sending the message to the players */ 
		for (int i = 1; i < MAXPLAYERS; i++)
		{	
			if (!IsValidClient(i))
				continue;
			
			isPlayerAdmin = IsAdmin(i);
			isPlayerSupporter = IsAdmin(i, ADMFLAG_SLAY);
			
			if (cvHideAdminDisconnect.BoolValue)
			{	
				if (isTargetAdmin)
				{
					if (isPlayerAdmin && cvAdminSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Admin player disconnect", playerName, reason);
					else if (isPlayerSupporter && cvSupporterSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Admin player disconnect", playerName, reason);					
				}	
				else if (isTargetSupporter)
				{
					if (isPlayerAdmin && cvAdminSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Supporter player disconnect", playerName, reason);
					else if (isPlayerSupporter && cvSupporterSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Supporter player disconnect", playerName, reason);	
					else
						CPrintToChat(i, "%t", "Normal player disconnect", playerName, reason);						
				}
				else
				{
					CPrintToChat(i, "%t", "Normal player disconnect", playerName, reason);	
				}	
			}
			else
			{
				if (isTargetAdmin)
					CPrintToChat(i, "%t", "Admin player disconnect", playerName, reason);
				else if (isTargetSupporter)
					CPrintToChat(i, "%t", "Supporter player disconnect", playerName, reason);	
				else
					CPrintToChat(i, "%t", "Normal player disconnect", playerName, reason);		
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
		
		IF the client is admin
		THEN the message is hidden for all clients and the client is added to the list of admins
	*/
	if (cvHideConnect.BoolValue)
	{
		/* Variables for the message */
		char name[MAX_NAME_LENGTH];
		char ip[20];
		char country[64];
		bool isTargetAdmin, isTargetSupporter, isPlayerAdmin, isPlayerSupporter;
		
		/* Filling the variables */
		GetClientName(client, name, sizeof(name));
		GetClientIP(client, ip, sizeof(ip));
		GeoipCountry(ip, country, sizeof(country));
		//GetClientAuthId(client, AuthId_Engine, steamID, sizeof(steamID), true);
		isTargetAdmin = IsAdmin(client);
		isTargetSupporter = IsAdmin(client, ADMFLAG_SLAY);
		
		/* Adding the admin/supporters to the global list */
		if (isTargetAdmin)
			gAdminList.Push(GetClientUserId(client));	
		else if (isTargetSupporter)
			gSupporterList.Push(GetClientUserId(client));
	
		/* Sending the message to the players */ 
		for (int i = 1; i < MAXPLAYERS; i++)
		{	
			if (!IsValidClient(i))
				continue;
			
			isPlayerAdmin = IsAdmin(i);
			isPlayerSupporter = IsAdmin(i, ADMFLAG_SLAY);
			
			if (cvHideAdminConnect.BoolValue)
			{	
				if (isTargetAdmin)
				{
					if (isPlayerAdmin && cvAdminSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Admin player connect", name);
					else if (isPlayerSupporter && cvSupporterSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Admin player connect", name);					
				}	
				else if (isTargetSupporter)
				{
					if (isPlayerAdmin && cvAdminSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Supporter player connect", name);
					else if (isPlayerSupporter && cvSupporterSeeOtherAdmin.BoolValue)
						CPrintToChat(i, "%t", "Supporter player connect", name);	
					else
						CPrintToChat(i, "%t", "Normal player connect", name, country);						
				}
				else
				{
					CPrintToChat(i, "%t", "Normal player connect", name, country);	
				}	
			}
			else
			{
				if (isTargetAdmin)
					CPrintToChat(i, "%t", "Admin player connect", name);
				else if (isTargetSupporter)
					CPrintToChat(i, "%t", "Supporter player connect", name);	
				else
					CPrintToChat(i, "%t", "Normal player connect", name, country);		
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
		if (IsValidClient(client) && IsAdmin(client))
		{
			/* Hiding the normal event */
			SetEventBroadcast(event, true);
			
			if (GetEventInt(event, "team") == 1 && cvHideAdminSpectator.BoolValue)
				gIsInvisible[client] = true;
			else
				gIsInvisible[client] = false;
		}
	}
	
	return Plugin_Continue;
}

/* INVISIBLE */
public void HookSpec(int entity)
{
	/* Apply scorebard visibility changes for all players */
	/* Hide the client in the scoreboard regarding his status */
	int data = FindSendPropInfo("CCSPlayerResource", "m_bConnected");
	
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (IsValidClient(i))
		{
			SetEntData(gPlayerManager, data + (i * 4), !gIsInvisible[i], _, true);
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
			if (StrContains(message, "ping") != -1 
			|| StrContains(message, "status") != -1
			|| StrContains(message, "plugins") != -1
			|| StrContains(message, "exts") != -1
			|| StrContains(message, "meta") != -1)
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

/* 
	Utils 
*/
stock bool IsAdmin(int client, int flag = ADMFLAG_BAN)
{
	/*	Check if the clients has the flags
	
	*/
	return CheckCommandAccess(client, "sm_admin", flag, true);
}

stock bool IsValidClient(int client)
{
	/*	Check if the client is in game, connected and not a bot
	
	*/
	if (client < 1 && client >= MAXPLAYERS)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	if (IsFakeClient(client))
		return false;
	return true;
}