#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

#define MESS "[iesaba] %s"
#define TEAM_T 2
#define TEAM_CT 3
#define PLUGIN_VERSION "1.2"

new Handle:deathrun_manager_version = INVALID_HANDLE;
new Handle:deathrun_enabled         = INVALID_HANDLE;
new Handle:deathrun_swapteam        = INVALID_HANDLE;
new Handle:deathrun_block_radio     = INVALID_HANDLE;
new Handle:deathrun_block_suicide   = INVALID_HANDLE;
new Handle:deathrun_fall_damage     = INVALID_HANDLE;
new Handle:deathrun_limit_terror    = INVALID_HANDLE;

public Plugin:myinfo =
{
	name        = "Deathrun Manager",
	author      = "Rogue",
	description = "Manages terrorists/counter-terrorists on DR servers",
	version     = PLUGIN_VERSION,
	url         = "http://www.surf-infamous.com/"
};

public OnPluginStart()
{
	AddCommandListener(BlockRadio, "coverme");
	AddCommandListener(BlockRadio, "takepoint");
	AddCommandListener(BlockRadio, "holdpos");
	AddCommandListener(BlockRadio, "regroup");
	AddCommandListener(BlockRadio, "followme");
	AddCommandListener(BlockRadio, "takingfire");
	AddCommandListener(BlockRadio, "go");
	AddCommandListener(BlockRadio, "fallback");
	AddCommandListener(BlockRadio, "sticktog");
	AddCommandListener(BlockRadio, "getinpos");
	AddCommandListener(BlockRadio, "stormfront");
	AddCommandListener(BlockRadio, "report");
	AddCommandListener(BlockRadio, "roger");
	AddCommandListener(BlockRadio, "enemyspot");
	AddCommandListener(BlockRadio, "needbackup");
	AddCommandListener(BlockRadio, "sectorclear");
	AddCommandListener(BlockRadio, "inposition");
	AddCommandListener(BlockRadio, "reportingin");
	AddCommandListener(BlockRadio, "getout");
	AddCommandListener(BlockRadio, "negative");
	AddCommandListener(BlockRadio, "enemydown");
	AddCommandListener(BlockKill, "kill");
	AddCommandListener(Cmd_JoinTeam, "jointeam");

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);

	deathrun_manager_version = CreateConVar("deathrun_manager_version", PLUGIN_VERSION, "Deathrun Manager version; not changeable", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	deathrun_enabled         = CreateConVar("deathrun_enabled", "1", "Enable or disable Deathrun Manager; 0 - disabled, 1 - enabled");
	deathrun_swapteam        = CreateConVar("deathrun_swapteam", "1", "Enable or disable automatic swapping of CTs and Ts; 1 - enabled, 0 - disabled");
	deathrun_block_radio     = CreateConVar("deathrun_block_radio", "1", "Allow or disallow radio commands; 1 - radio commands are blocked, 0 - radio commands can be used");
	deathrun_block_suicide   = CreateConVar("deathrun_block_suicide", "1", "Block or allow the 'kill' command; 1 - command is blocked, 0 - command is allowed");
	deathrun_fall_damage     = CreateConVar("deathrun_fall_damage", "1", "Blocks fall damage given to terrorists; 1 - enabled, 0 - disabled");
	deathrun_limit_terror    = CreateConVar("deathrun_limit_terror", "0", "Limits terrorist team to chosen value; 0 - disabled");

	SetConVarString(deathrun_manager_version, PLUGIN_VERSION);
	AutoExecConfig(true, "deathrun_manager");
}

public OnConfigsExecuted()
{
	decl String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));

	if (strncmp(mapname, "dr_", 3, false) == 0 || (strncmp(mapname, "deathrun_", 9, false) == 0) || (strncmp(mapname, "dtka_", 5, false) == 0))
	{
		LogMessage("Deathrun map detected. Enabling Deathrun Manager.");
		SetConVarInt(deathrun_enabled, 1);
	}
	else
	{
		LogMessage("Current map is not a deathrun map. Disabling Deathrun Manager.");
		SetConVarInt(deathrun_enabled, 0);
	}
}

public IsValidClient(client)
{
	if (client == 0)
		return false;

	if (!IsClientConnected(client))
		return false;

	if (IsFakeClient(client))
		return false;

	if (!IsClientInGame(client))
		return false;

	return true;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_swapteam) == 1))
	{
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == TEAM_T)
			{
				CS_SwitchTeam(i, TEAM_CT);
				movect(GetRandomPlayer(TEAM_CT));
			}
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_swapteam) == 1) && (GetClientTeam(client) == TEAM_T))
		moveter(client);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_fall_damage) == 1))
	{
		new ev_attacker = GetEventInt(event, "attacker");
		new ev_client = GetEventInt(event, "userid");
		new client = GetClientOfUserId(ev_client);

		if ((ev_attacker == 0) && (IsPlayerAlive(client)) && (GetClientTeam(client) == TEAM_T))
			SetEntData(client, FindSendPropOffs("CBasePlayer", "m_iHealth"), 100);
	}
}

void:movect(client)
{
	CreateTimer(1.5, movectt, client);
}

void:moveter(client)
{
	CreateTimer(1.0, movet, client);
}

public Action:movectt(Handle:timer, any:client)
{
	new counter = GetRandomPlayer(TEAM_CT);
	if ((counter != -1) && (GetTeamClientCount(TEAM_T) == 0))
	{
		CS_SwitchTeam(counter, TEAM_T);
		PrintToChatAll(MESS, "A random player has been moved to Terrorist");
	}
}

public Action:movet(Handle:timer, any:client)
{
	CS_SwitchTeam(client, TEAM_CT);
	PrintToChat(client, MESS, "You have died and have been moved to Counter-Terrorists");
}

public Action:BlockRadio(client, const String:command[], args)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_block_radio) == 1))
	{
		PrintToChat(client, MESS, "Radio commands are blocked to prevent spam!");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:BlockKill(client, const String:command[], args)
{
	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_block_suicide) == 1))
	{
		PrintToChat(client, MESS, "Do not attempt to suicide to avoid death!");
		PrintToChat(client, MESS, "If you wish to join the spectator team, type 'spectate' into console");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*  For some reason hooking this command means that you can not use the 'jointeam' command via console.
    Not that it really matters anyway, because the command is hidden. Changing team VIA the GUI
    (pressing M) still works fine though. I know of a way to 'fix' it if it's a major problem for anybody. */ 
public Action:Cmd_JoinTeam(client, const String:command[], args)
{
	if (args == 0)
		return Plugin_Continue;

	new argg, String:arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	argg = StringToInt(arg);

	if (GetConVarInt(deathrun_enabled) == 1 && (GetConVarInt(deathrun_limit_terror) > 0) && (argg == 2))
	{
		new teamcount = GetTeamClientCount(TEAM_T);

		if (teamcount >= GetConVarInt(deathrun_limit_terror))
		{
			PrintToChat(client, MESS, "There is already enough players on the Terrorist team!");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && (GetClientTeam(i) == team))
		clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
