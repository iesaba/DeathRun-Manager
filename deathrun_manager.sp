#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define MESS "[iesaba] %s"
#define PLUGIN_VERSION "1.3"

new Handle:deathrun_manager_version = INVALID_HANDLE;
new Handle:deathrun_enabled         = INVALID_HANDLE;
new Handle:deathrun_limit_terror    = INVALID_HANDLE;

public Plugin:myinfo =
{
	name        = "Deathrun Manager",
	author      = "Rogue (Remodeled by k725)",
	description = "Manages Terrorists/Counter-Terrorists on DeathRun Servers",
	version     = PLUGIN_VERSION,
	url         = "http://www.surf-infamous.com/"
};

/**
 * プラグイン開始
 */
public OnPluginStart()
{
	AddCommandListener(BlockKill, "kill");
	AddCommandListener(TeamJoin, "jointeam");

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);

	deathrun_manager_version = CreateConVar("deathrun_manager_version", PLUGIN_VERSION, "Deathrun Manager version; not changeable", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	deathrun_enabled         = CreateConVar("deathrun_enabled", "1", "Enable or disable Deathrun Manager; 0 - disabled, 1 - enabled");
	deathrun_limit_terror    = CreateConVar("deathrun_limit_terror", "1", "Limits terrorist team to chosen value");

	SetConVarString(deathrun_manager_version, PLUGIN_VERSION);
	AutoExecConfig(true, "deathrun_manager");
}

/**
 * 設定読み込み終了
 */
public OnConfigsExecuted()
{
	decl String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));

	if ((strncmp(mapname, "dr_", 3, false) == 0) || (strncmp(mapname, "deathrun_", 9, false) == 0) || (strncmp(mapname, "dtka_", 5, false) == 0))
		SetConVarInt(deathrun_enabled, 1);
	else
		SetConVarInt(deathrun_enabled, 0);
}

/**
 * マップスタート
 */
public OnMapStart()
{
	PrecacheModel("models/player/tm_leet_varianta.mdl");
	PrecacheModel("models/player/ctm_sas.mdl");
}

/**
 * 自殺防止
 */
public Action:BlockKill(client, const String:command[], args)
{
	if (GetConVarInt(deathrun_enabled) == 1)
	{
		PrintCenterText(client, "死ぬことから逃げないで欲しいですよ");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/**
 * チームに入ろうとした時
 */
public Action:TeamJoin(client, const String:command[], args)
{
	if (args == 0)
		return Plugin_Continue;

	if (GetConVarInt(deathrun_enabled) == 1)
	{
		decl String:arg[32];
		GetCmdArg(1, arg, sizeof(arg));
		new argg    = StringToInt(arg);
		new countTR = GetTeamClientCount(CS_TEAM_T);
		new countCT = GetTeamClientCount(CS_TEAM_CT);
		new limitTR = GetConVarInt(deathrun_limit_terror);

		if ((argg == CS_TEAM_T) && (countTR >= limitTR))
		{
			PrintToChat(client, MESS, "TRに1人以上いますよCTに誰も居ないので行ってね");
			return Plugin_Handled;
		}
		else if ((argg == CS_TEAM_CT) && (countTR == 0 && countCT >= 1))
		{
			PrintToChat(client, MESS, "CTに1人以上居ますがTRに誰も居ないので行ってね");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/**
 * プレイヤーが死亡した時
 */
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (GetConVarInt(deathrun_enabled) == 1 && (GetClientTeam(client) == CS_TEAM_T))
		CreateTimer(0.2, Timer_PlayerDeath, client);
}

/**
 * Event_PlayerDeathのタイマー用
 */
public Action:Timer_PlayerDeath(Handle:timer, any:client)
{
	CS_SwitchTeam(client, CS_TEAM_CT);
	SetEntityModel(client, "models/player/ctm_sas.mdl");
	PrintToChat(client, MESS, "TRが死亡。CTへ移動");
}

/**
 * ラウンドが終了した時
 */
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(deathrun_enabled) == 1)
	{
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsValidClient(i) && (GetClientTeam(i) == CS_TEAM_T))
			{
				CreateTimer(0.4, Timer_RoundEnd, i);
			}
		}
	}
}

/**
 * Event_RoundEndのタイマー用
 */
public Action:Timer_RoundEnd(Handle:timer, any:client)
{
	new counter = GetRandomPlayer(CS_TEAM_CT);

	CS_SwitchTeam(client, CS_TEAM_CT);
	SetEntityModel(client, "models/player/ctm_sas.mdl");

	if ((counter != -1) && (GetTeamClientCount(CS_TEAM_T) == 0))
	{
		CS_SwitchTeam(counter, CS_TEAM_T);
		SetEntityModel(counter, "models/player/tm_leet_varianta.mdl");
		PrintToChatAll(MESS, "CTのプレイヤー1人をTRに移動");
	}
}

/**
 * ランダムに指定されたチームのプレイヤーを取得
 */
static GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && (GetClientTeam(i) == team))
			clients[clientCount++] = i;
	}

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

/**
 * 指定されたプレイヤーが本物か確認
 */
static IsValidClient(client)
{
	if (client == 0 || !IsClientConnected(client) || IsFakeClient(client) || !IsClientInGame(client))
		return false;

	return true;
}
