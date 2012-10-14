/**
 * Deathmatch plugin for Day of Defeat: Source by Root
 * Big thanks to Andresso
 *
 *
 * Version 2.0
 *
 * Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1 // Force strict semicolon mode.

#define REQUIRE_EXTENSIONS

// ====[ INCLUDES ]====================================================
#include <sourcemod>
#include <sdktools>
#include <dodhooks>
#include <sdkhooks>
#include <sendproxy>
#include <sorting>

// ====[ CONSTANTS ]===================================================
#define PLUGIN_NAME        "DoD:S Deathmatch"
#define PLUGIN_AUTHOR      "Root & Andresso"
#define PLUGIN_DESCRIPTION "Adds deathmatch gameplay for DoD:S"
#define PLUGIN_VERSION     "2.0"
#define PLUGIN_CONTACT     "http://www.dodsplugins.com/"

#define DOD_MAXPLAYERS  33
#define MAX_SPAWNPOINTS 32

#define AMMO_OFFSET_COLT 4
#define AMMO_OFFSET_P38  8

enum
{
	Team_Unassigned = 0,
	Team_Spectator,
	Team_Allies,
	Team_Axis,
	Team_Custom
};

enum
{
	SpawnPointTeam_Allies = 0,
	SpawnPointTeam_Axis,

	SpawnPointTeam_Size
};

// ====[ VARIABLES ]===================================================
new bool:g_bLateLoad;

new	bool:g_bHealthRegen[DOD_MAXPLAYERS + 1];
new Float:g_fHealthRegenDelay[DOD_MAXPLAYERS + 1];
new Handle:g_hRegenTimer;

new g_iNumSpawnPoints[SpawnPointTeam_Size];
new Float:g_vecSpawnPointAngles[SpawnPointTeam_Size][MAX_SPAWNPOINTS][3];
new Float:g_vecSpawnPointOrigin[SpawnPointTeam_Size][MAX_SPAWNPOINTS][3];

// ====[ PLUGIN ]======================================================
#include "deathmatch/offsets.sp"
#include "deathmatch/misc.sp"
#include "deathmatch/convars.sp"
#include "deathmatch/config.sp"
#include "deathmatch/commands.sp"
#include "deathmatch/events.sp"

public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version     = PLUGIN_VERSION,
	url         = PLUGIN_CONTACT
};

/* APLRes:AskPluginLoad2()
 *
 * Called before the plugin starts up.
 * --------------------------------------------------------------------- */
public APLRes:AskPluginLoad2(Handle:myself, bool:lateLoad, String:error[], err_max)
{
	g_bLateLoad = lateLoad;
}

/* OnPluginStart()
 *
 * When the plugin starts up.
 * --------------------------------------------------------------------- */
public OnPluginStart()
{
	LoadTranslations("deathmatch.phrases");

	// Create and exec configuration file in cfg/sourcemod folder
	AutoExecConfig(true, "plugin.deathmatch", "sourcemod");

	HookUserMessage(GetUserMessageId("HintText"), Hook_HintText, true);
	HookUserMessage(GetUserMessageId("VGUIMenu"), Hook_VGUIMenu, true);

	AddAmbientSoundHook(AmbientSHook:HookFlagSound);

	if (g_bLateLoad)
	{
		// Apply the hooks on all players
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				SDKHook(i, SDKHook_ShouldCollide, OnShouldCollide);

				SendProxy_Hook(i, "m_iTeamNum", Prop_Int, Hook_TeamNum);
			}
		}

		// If the round is active, restart the round
		if (_:GameRules_GetRoundState() == DoDRoundState_RoundRunning)
		{
			SetRoundState(DoDRoundState_Restart);
		}
	}

	LoadCommands();
	LoadConVars();
	LoadEvents();
	LoadOffsets();
}

/* OnGetGameDescription()
 *
 * When the game description is polled.
 * --------------------------------------------------------------------- */
public Action:OnGetGameDescription(String:gameDesc[64])
{
	// Changes the game description from "Day of Defeat: Source" to "DoD:S Deathmatch")
	Format(gameDesc, sizeof(gameDesc), PLUGIN_NAME);
	return Plugin_Changed;
}

/* OnMapStart()
 *
 * When the map starts.
 * --------------------------------------------------------------------- */
public OnMapStart()
{
	LoadConfig();

	new playerResource = FindEntityByClassname(-1, "dod_player_manager");

	if (playerResource != -1)
	{
		SDKHook(playerResource, SDKHook_ThinkPost, OnPlayerResourceThinkPost);
	}
	else
	{
		SetFailState("Fatal Error: Unable to find entity \"dod_player_manager\"!");
	}

	g_hRegenTimer = CreateTimer(g_ConVars[ConVar_RegenTick][Value], Timer_RegenHealth, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

	PrecacheSound("UI/gift_drop.wav", true);
}

/* OnMapEnd()
 *
 * When the map ends.
 * --------------------------------------------------------------------- */
public OnMapEnd()
{
	// Memory leaks: fuck 'em
	g_hRegenTimer = INVALID_HANDLE;
}

/* OnConfigsExecuted()
 *
 * When game configurations (e.g., map-specific configs) are executed.
 * --------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	// Load custom config
	decl String:configFilename[256];
	GetConVarString(g_ConVars[ConVar_CustomConfig][ConVarHandle], configFilename, sizeof(configFilename));

	if (configFilename[0] != '\0')
	{
		AutoExecConfig(false, configFilename, NULL_STRING);
	}

	UpdateModeConVars();
}

/* OnClientPostAdminCheck()
 *
 * Called when a client is fully ingame.
 * --------------------------------------------------------------------- */
public OnClientPostAdminCheck(client)
{
	if (!IsClientSourceTV(client))
	{
		SDKHook(client, SDKHook_ShouldCollide, OnShouldCollide);

		SendProxy_Hook(client, "m_iTeamNum", Prop_Int, Hook_TeamNum);
	}
}

/* OnShouldCollide()
 *
 * Called when a player collides with another.
 * --------------------------------------------------------------------- */
public bool:OnShouldCollide(client, collisionGroup, contentsMask, bool:originalResult)
{
	// Set the result to true to enable collision on all players
	if (g_ConVars[ConVar_Mode][Value])
	{
		return true;
	}

	return originalResult;
}

/* OnEnterPlayerState()
 *
 * Called each time a player enter a new playerstate.
 * --------------------------------------------------------------------- */
public Action:OnEnterPlayerState(client, &playerState)
{
	return playerState == PlayerState_PickingClass && GetDesiredPlayerClass(client) != PlayerClass_None ? Plugin_Handled : Plugin_Continue;
}

/* OnPlayerResourceThinkPost()
 *
 * Switches all players team to allies on the scoreboard when FFA is enabled.
 * --------------------------------------------------------------------- */
public OnPlayerResourceThinkPost(entity)
{
	if (g_ConVars[ConVar_Mode][Value])
	{
		new Handle:playerArray = CreateArray();

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) > Team_Spectator)
			{
				PushArrayCell(playerArray, i);
			}
		}

		SortADTArrayCustom(playerArray, SortArray);

		for (new i = 0; i < GetArraySize(playerArray); i++)
		{
			new offset = GetArrayCell(playerArray, i) * 4;

			// If the player is on top-16, set the player's team as allies, otherwise axis
			SetEntData(entity, g_iOffset_Team + offset, i <= 16 ? Team_Allies : Team_Axis);

			// Set the player as dead (Hides all players from the minimap)
			SetEntData(entity, g_iOffset_Alive + offset, false);
		}

		CloseHandle(playerArray);
	}
}

/* HookFlagSound()
 *
 * Find a flag sound and disable it.
 * --------------------------------------------------------------------- */
public Action:HookFlagSound(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay)
{
	if(StrEqual(sample, "ambient/flag.wav"))
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/* Hook_HintText()
 *
 * Block team-attack "tutorial" messages from being shown to players.
 * --------------------------------------------------------------------- */
public Action:Hook_HintText(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	static const String:hintMessages[][] =
	{
		"#Hint_spotted_a_friend",
		"#Hint_careful_around_teammates",
		"#Hint_try_not_to_injure_teammates"
	};

	decl String:hintName[64];
	BfReadString(bf, hintName, sizeof(hintName));

	for (new i = 0; i < sizeof(hintMessages); i++)
	{
		if (StrEqual(hintName, hintMessages[i]))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/* Hook_TeamNum()
 *
 * Called when network property m_iTeamNum is going to be sent to all players.
 * --------------------------------------------------------------------- */
public Action:Hook_TeamNum(client, const String:propName[], &value, element)
{
	if (g_ConVars[ConVar_Mode][Value])
	{
		// Change the players team client-side if the player is alive
		if (IsPlayerAlive(client))
		{
			value = Team_Custom;

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

/* Hook_VGUIMenu()
 *
 * Called when a VGUI menu is being sent.
 * --------------------------------------------------------------------- */
public Action:Hook_VGUIMenu(UserMsg:msgId, Handle:bf, const players[], numPlayers, bool:reliable, bool:init)
{
	new client = players[0];

	if (g_ConVars[ConVar_Mode][Value] && IsClientInGame(client) && !IsClientSourceTV(client) && GetClientTeam(client) == Team_Unassigned)
	{
		decl String:buffer[64];
		BfReadString(bf, buffer, sizeof(buffer));

		if (StrEqual(buffer, "info"))
		{
			// Loop until the msg key is found
			while (BfGetNumBytesLeft(bf) != 0)
			{
				BfReadString(bf, buffer, sizeof(buffer));

				if (StrEqual(buffer, "msg"))
				{
					BfReadString(bf, buffer, sizeof(buffer));

					// Check if the menu is the MOTD panel
					if (StrEqual(buffer, "motd"))
					{
						CreateTimer(0.1, Timer_ShowNewMOTDPanel, EntIndexToEntRef(client), TIMER_FLAG_NO_MAPCHANGE);

						return Plugin_Handled;
					}

					break;
				}
			}
		}
	}

	return Plugin_Continue;
}

/* Timer_ShowNewMOTDPanel()
 *
 * Shows a new MOTD panel.
 * --------------------------------------------------------------------- */
public Action:Timer_ShowNewMOTDPanel(Handle:timer, any:client)
{
	// Make sure that the client is valid
	if ((client = EntRefToEntIndex(client)) != INVALID_ENT_REFERENCE)
	{
		static Handle:kv;

		if (!kv)
		{
			kv = CreateKeyValues("data");

			KvSetString(kv, "title", "MESSAGE OF THE DAY");
			KvSetString(kv, "type", "1");
			KvSetString(kv, "msg", "motd");
		}

		new randomTeam = GetRandomInt(0, 1) ? Team_Allies : Team_Axis;

		SetEntData(client, g_iOffset_TeamNum, randomTeam, _, true);

		ShowVGUIPanel(client, randomTeam == Team_Allies ? "class_us" : "class_ger");
		ShowVGUIPanel(client, "info", kv);
	}
}

/* Timer_RegenHealth()
 *
 * Heals a player for X amount of health every Y seconds.
 * --------------------------------------------------------------------- */
public Action:Timer_RegenHealth(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (g_bHealthRegen[i])
			{
				GiveHealth(i, g_ConVars[ConVar_RegenHP][Value]);
			}
			// If it has gone past the delay, start the health regeneration
			else if (g_fHealthRegenDelay[i] && g_fHealthRegenDelay[i] < GetGameTime())
			{
				g_bHealthRegen[i] = true;
				g_fHealthRegenDelay[i] = 0.0;
			}
		}
	}
}

/* SortArray()
 *
 * Returns -1 if index1 has more frags than index2, returns 1 otherwise.
 * --------------------------------------------------------------------- */
public SortArray(index1, index2, Handle:array, Handle:hndl)
{
	return GetClientFrags(GetArrayCell(array, index1)) > GetClientFrags(GetArrayCell(array, index2)) ? -1 : 1;
}