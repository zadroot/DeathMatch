/**
* Deathmatch plugin for Day of Defeat: Source by Root
*
* Description:
*   Deathmatch gameplay plugin for DoD:S similar to SOAP TF2DM by Lange, which based on original TF2 Deathmatch plugin by MikeJS.
*
* Version 1.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1 // Force strict semicolon mode.

// ====[ INCLUDES ]====================================================
#include <sourcemod>
#include <sdktools>
#include <dodhooks>
#include <sdkhooks>

// ====[ CONSTANTS ]===================================================
#define PLUGIN_NAME			"DoD:S Deathmatch"
#define PLUGIN_AUTHOR		"Root"
#define PLUGIN_VERSION		"1.0"
#define PLUGIN_CONTACT		"http://steamcommunity.com/id/zadroot/"

// ====[ VARIABLES ]===================================================
new	Handle:g_cConfig = INVALID_HANDLE,
	bool:FirstLoad;

//Regen-over-time
new	bool:g_bRegen[MAXPLAYERS+1],
	Handle:g_hRegenTimer[MAXPLAYERS+1] = INVALID_HANDLE,
	Handle:g_hRegenHP = INVALID_HANDLE,
	g_iRegenHP,
	Handle:g_hRegenTick = INVALID_HANDLE,
	Float:g_fRegenTick,
	Handle:g_hRegenDelay = INVALID_HANDLE,
	Float:g_fRegenDelay,
	Handle:g_hKillStartRegen = INVALID_HANDLE,
	bool:g_bKillStartRegen;

//Spawning
new	Handle:g_hPlayerRespawn,
	g_iDesiredPlayerClass,
	Handle:g_hSpawn = INVALID_HANDLE,
	Float:g_fSpawn,
	Handle:g_hSpawnPoints = INVALID_HANDLE,
	bool:g_bSpawnPoints,
	bool:g_bSpawnMap,
	Handle:g_hAxisSpawns = INVALID_HANDLE,
	Handle:g_hAlliSpawns = INVALID_HANDLE,
	Handle:g_hKv = INVALID_HANDLE;

//Kill Regens (hp+ammo)
new	g_iMaxClips1[MAXPLAYERS+1],
	g_iMaxClips2[MAXPLAYERS+1],
	g_iMaxHealth[MAXPLAYERS+1],
	Handle:g_hKillHeal = INVALID_HANDLE,
	g_iKillHeal,
	Handle:g_hKillAmmo = INVALID_HANDLE,
	bool:g_bKillAmmo,
	Handle:g_hShowHP = INVALID_HANDLE,
	bool:g_bShowHP;

//Equipment (pistols & grenades)
new	Handle:g_hPistols = INVALID_HANDLE,
	bool:g_bPistols,
	Handle:g_hGrenades = INVALID_HANDLE,
	bool:g_bGrenades;

// ====[ PLUGIN ]======================================================
public Plugin:myinfo =
{
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description		= "Team deathmatch gameplay for DoD:S",
	version			= PLUGIN_VERSION,
	url				= PLUGIN_CONTACT
};


/**
 * ----------------------------------------------------------------------
 *      ______                  __  _                  
 *	   / ____/__  ______  _____/ /_(_)____  ____  _____
 *	  / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
 *	 / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  ) 
 *	/_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/  
 *
 * ----------------------------------------------------------------------
 */

/* OnPluginStart()
 *
 * When the plugin starts up.
 * --------------------------------------------------------------------- */
public OnPluginStart()
{
	// Load translations for DM
	LoadTranslations("deathmatch.phrases");

	// Create convars
	CreateConVar("deathmatch_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	g_cConfig = CreateConVar("dm_customconfig", "", "Load a custom config when DM is loaded (sourcemod/sm_warmode_on or classlimit.cfg etc)", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hPistols = CreateConVar("dm_pistols", "1", "Give pistols to every class.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hGrenades = CreateConVar("dm_disablenades", "1", "Disable grenades & smoke.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hRegenHP = CreateConVar("dm_regenhp", "1", "Health added per regeneration tick. Set to 0 to disable.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0);
	g_hRegenTick = CreateConVar("dm_regentick", "0.3", "Delay between regeration ticks (in seconds).", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hRegenDelay = CreateConVar("dm_regendelay", "4.0", "Seconds after damage before regeneration.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hKillStartRegen = CreateConVar("dm_kill_start_regen", "1", "Start the heal-over-time regen immediately after a kill.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSpawn = CreateConVar("dm_spawn_delay", "3.0", "Spawn timer.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSpawnPoints = CreateConVar("dm_spawnpoints", "1", "Enable random spawns from configs/deathmatch.cfg", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hKillHeal = CreateConVar("dm_kill_heal_amount", "20", "Amount of HP to restore on kills.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 1.0);
	g_hKillAmmo = CreateConVar("dm_kill_ammo", "1", "Enable ammo restoration on kills.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hShowHP = CreateConVar("dm_showhp", "1", "Print killer's health to victim on death.", FCVAR_PLUGIN|FCVAR_NOTIFY);

	// Hook convar changes and events
	HookConVarChange(g_hPistols, handler_ConVarChange);
	HookConVarChange(g_hGrenades, handler_ConVarChange);
	HookConVarChange(g_hRegenHP, handler_ConVarChange);
	HookConVarChange(g_hRegenTick, handler_ConVarChange);
	HookConVarChange(g_hRegenDelay, handler_ConVarChange);
	HookConVarChange(g_hKillStartRegen, handler_ConVarChange);
	HookConVarChange(g_hSpawn, handler_ConVarChange);
	HookConVarChange(g_hSpawnPoints, handler_ConVarChange);
	HookConVarChange(g_hKillHeal, handler_ConVarChange);
	HookConVarChange(g_hKillAmmo, handler_ConVarChange);
	HookConVarChange(g_hShowHP, handler_ConVarChange);
	HookEvent("player_death", Event_player_death);
	HookEvent("player_hurt", Event_player_hurt);
	HookEvent("player_spawn", Event_player_spawn);
	HookEvent("dod_round_start", Event_round_start);
	HookEvent("dod_restart_round", Event_round_start);

	// Create/register client command
	RegAdminCmd("loc", Command_Loc, ADMFLAG_ROOT, "Shows client origin and angle vectors");

	// Add sound hook for removing flag sound
	AddAmbientSoundHook(AmbientSHook:HookFlagSound);

	// Create arrays for the spawning system
	g_hAxisSpawns = CreateArray();
	g_hAlliSpawns = CreateArray();

	// Crutch to fix some issues that appear when the plugin is loaded mid-round
	FirstLoad = true;

	// Respawn all players into DM spawns. This instance of LockMap() is needed for mid-round loads of DM
	LockMap();

	// Reset all player's regens. Used here for mid-round loading compatability
	ResetPlayers();

	// Create and exec configuration file in cfg/sourcemod folder
	AutoExecConfig(true, "plugin.deathmatch", "sourcemod");

	// Prepare SDK callback from dodhooks for spawning
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(LoadGameConfigFile("dodhooks"), SDKConf_Signature, "DODRespawn");

	if ((g_hPlayerRespawn = EndPrepSDKCall()) == INVALID_HANDLE)
	{
		SetFailState("Fatal Error: Unable to find signature \"DODRespawn\"!");
	}

	// Check player class for properly respawning
	if ((g_iDesiredPlayerClass = FindSendPropInfo("CDODPlayer", "m_iDesiredPlayerClass")) == -1)
	{
		SetFailState("Fatal Error: Unable to find offset \"m_iDesiredPlayerClass\"!");
	}
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
	// Kill everything, because fuck memory leaks
	for (new i = 0; i < MaxClients+1; i++)
	{
		if(g_hRegenTimer[i]!=INVALID_HANDLE)
		{
			KillTimer(g_hRegenTimer[i]);
			g_hRegenTimer[i] = INVALID_HANDLE;
		}
	}

	// Spawn system written by MikeJS
	ClearArray(g_hAxisSpawns);
	ClearArray(g_hAlliSpawns);

	for(new i=0;i<MAXPLAYERS;i++)
	{
		PushArrayCell(g_hAxisSpawns, CreateArray(6));
		PushArrayCell(g_hAlliSpawns, CreateArray(6));
	}

	g_bSpawnMap = false;

	if(g_hKv!=INVALID_HANDLE)
		CloseHandle(g_hKv);

	g_hKv = CreateKeyValues("Spawns");

	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "configs/deathmatch.cfg");

	if(FileExists(path))
	{
		FileToKeyValues(g_hKv, path);

		decl String:map[64];
		GetCurrentMap(map, sizeof(map));

		if(KvJumpToKey(g_hKv, map))
		{
			g_bSpawnMap = true;

			decl String:players[4], Float:vectors[6], Float:origin[3], Float:angles[3];
			new iplayers;

			do{
				KvGetSectionName(g_hKv, players, sizeof(players));
				iplayers = StringToInt(players);

				if(KvJumpToKey(g_hKv, "axis"))
				{
					KvGotoFirstSubKey(g_hKv);
					do{
						KvGetVector(g_hKv, "origin", origin);
						KvGetVector(g_hKv, "angles", angles);

						vectors[0] = origin[0];
						vectors[1] = origin[1];
						vectors[2] = origin[2];
						vectors[3] = angles[0];
						vectors[4] = angles[1];
						vectors[5] = angles[2];

						for(new i=iplayers;i<MAXPLAYERS;i++)
							PushArrayArray(GetArrayCell(g_hAxisSpawns, i), vectors);
					}while(KvGotoNextKey(g_hKv));

					KvGoBack(g_hKv);
					KvGoBack(g_hKv);
				}else{
					SetFailState("Axis spawns missing. Map: %s  Players: %i", map, iplayers);
				}
				if(KvJumpToKey(g_hKv, "allies"))
				{
					KvGotoFirstSubKey(g_hKv);
					do{
						KvGetVector(g_hKv, "origin", origin);
						KvGetVector(g_hKv, "angles", angles);

						vectors[0] = origin[0];
						vectors[1] = origin[1];
						vectors[2] = origin[2];
						vectors[3] = angles[0];
						vectors[4] = angles[1];
						vectors[5] = angles[2];

						for(new i=iplayers;i<MAXPLAYERS;i++)
							PushArrayArray(GetArrayCell(g_hAlliSpawns, i), vectors);
					}while(KvGotoNextKey(g_hKv));
				}else{
					SetFailState("Allies spawns missing. Map: %s  Players: %i", map, iplayers);
				}
			}while(KvGotoNextKey(g_hKv));
		}else{
			SetFailState("Map spawns missing. Map: %s", map);
		}
	}else{
		LogError("File Not Found: %s", path);
	}
	// End spawn system

	// Load the sound file played when a player is spawned
	PrecacheSound("UI/gift_drop.wav", true);

	// Precache flag sound to remove
	PrecacheSound("ambient/flag.wav", true);
}

/* OnMapEnd()
 *
 * When the map ends.
 * --------------------------------------------------------------------- */
public OnMapEnd()
{
	// Memory leaks: fuck 'em
	for (new i = 0; i < MAXPLAYERS+1; i++)
	{
		if(g_hRegenTimer[i]!=INVALID_HANDLE)
		{
			KillTimer(g_hRegenTimer[i]);
			g_hRegenTimer[i] = INVALID_HANDLE;
		}
	}
}

/* OnConfigsExecuted()
 *
 * When game configurations (e.g., map-specific configs) are executed.
 * --------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	// Get the values for internal global variables
	g_bPistols = GetConVarBool(g_hPistols);
	g_bGrenades = GetConVarBool(g_hGrenades);
	g_iRegenHP = GetConVarInt(g_hRegenHP);
	g_fRegenTick = GetConVarFloat(g_hRegenTick);
	g_fRegenDelay = GetConVarFloat(g_hRegenDelay);
	g_bKillStartRegen = GetConVarBool(g_hKillStartRegen);
	g_fSpawn = GetConVarFloat(g_hSpawn);
	g_bSpawnPoints = GetConVarBool(g_hSpawnPoints);
	g_iKillHeal = GetConVarInt(g_hKillHeal);
	g_bKillAmmo = GetConVarBool(g_hKillAmmo);
	g_bShowHP = GetConVarBool(g_hShowHP);

	// Load custom config
	decl String:configFilename[256];
	GetConVarString(g_cConfig, configFilename, sizeof(configFilename));
	ServerCommand("exec \"%s\"", configFilename);
}

/* OnClientConnected()
 *
 * When a client connects to the server.
 * --------------------------------------------------------------------- */
public OnClientConnected(client)
{
	// Set the client's slot regen timer handle to INVALID_HANDLE
	if(g_hRegenTimer[client]!=INVALID_HANDLE)
	{
		KillTimer(g_hRegenTimer[client]);
		g_hRegenTimer[client] = INVALID_HANDLE;
	}
}

/* OnClientDisconnect()
 *
 * When a client disconnects from the server.
 * --------------------------------------------------------------------- */
public OnClientDisconnect(client)
{
	// Set the client's slot regen timer handle to INVALID_HANDLE again because I really don't want to take any chances
	if(g_hRegenTimer[client]!=INVALID_HANDLE)
	{
		KillTimer(g_hRegenTimer[client]);
		g_hRegenTimer[client] = INVALID_HANDLE;
	}
}

/* handler_ConVarChange()
 *
 * Called when a convar's value is changed.
 * --------------------------------------------------------------------- */
public handler_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// When a cvar is changed during runtime, this is called and the corresponding internal variable is updated to reflect this change
	if (convar == g_hPistols){
		if(StringToInt(newValue) >= 1)
			g_bPistols = true;
		else if(StringToInt(newValue) <= 0)
			g_bPistols = false;
	}
	else if(convar == g_hGrenades){
		if(StringToInt(newValue) >= 1)
			g_bGrenades = true;
		else if(StringToInt(newValue) <= 0)
			g_bGrenades = false;
	}
	else if (convar == g_hRegenHP)
		g_iRegenHP = StringToInt(newValue);
	else if (convar == g_hRegenTick)
		g_fRegenTick = StringToFloat(newValue);
	else if (convar == g_hRegenDelay)
		g_fRegenDelay = StringToFloat(newValue);
	else if (convar == g_hKillStartRegen){
		if(StringToInt(newValue) >= 1)
			g_bKillStartRegen = true;
		else if(StringToInt(newValue) <= 0)
			g_bKillStartRegen = false;
	}
	else if (convar == g_hSpawn)
		g_fSpawn = StringToFloat(newValue);
	else if (convar == g_hSpawnPoints){
		if(StringToInt(newValue) >= 1)
			g_bSpawnPoints = true;
		else if(StringToInt(newValue) <= 0)
			g_bSpawnPoints = false;
	}
	else if (convar == g_hKillHeal)
		g_iKillHeal = StringToInt(newValue);
	else if (convar == g_hKillAmmo){
		if(StringToInt(newValue) >= 1)
			g_bKillAmmo = true;
		else if(StringToInt(newValue) <= 0)
			g_bKillAmmo = false;
	}
	else if (convar == g_hShowHP){
		if(StringToInt(newValue) >= 1)
			g_bShowHP = true;
		else if(StringToInt(newValue) <= 0)
			g_bShowHP = false;
	}
}


/**
 * ----------------------------------------------------------------------
 *	   _____                            _             
 *	  / ___/____  ____ __      ______  (_)____  ____ _
 *	  \__ \/ __ \/ __ `/ | /| / / __ \/ // __ \/ __ `/
 *	 ___/ / /_/ / /_/ /| |/ |/ / / / / // / / / /_/ / 
 *	/____/ .___/\__,_/ |__/|__/_/ /_/_//_/ /_/\__, /  
 *		/_/                                  /____/   
 * ----------------------------------------------------------------------
 */

/* RandomSpawn()
 *
 * Picks a spawn point at random from deathmatch.cfg, and teleports the player to it.
 * --------------------------------------------------------------------- */
public Action:RandomSpawn(Handle:timer, any:clientid)
{
	new client = GetClientOfUserId(clientid); // UserIDs are passed through timers instead of client indexes because it ensures that no mismatches can happen as UserIDs are unique

	if(!IsValidClient(client))
		return Plugin_Handled; // Client wasn't valid, so there's no point in trying to spawn it!

	if(IsPlayerAlive(client)) // Can't teleport a dead player
	{
		new Handle:array, size, Handle:spawns = CreateArray(), count = GetClientCount();
		decl Float:vectors[6], Float:origin[3], Float:angles[3];

		for(new i=0;i<=count;i++)
		{
			// Get the Allies spawns for this map
			array = GetArrayCell(g_hAlliSpawns, i);
			if(GetArraySize(array)!=0)
				size = PushArrayCell(spawns, array);
		}
		for(new i=0;i<=count;i++)
		{
			// Get the Axis spawns
			array = GetArrayCell(g_hAxisSpawns, i);
			if(GetArraySize(array)!=0)
				size = PushArrayCell(spawns, array);
		}

		array = GetArrayCell(spawns, GetRandomInt(0, GetArraySize(spawns)-1));
		size = GetArraySize(array);
		GetArrayArray(array, GetRandomInt(0, size-1), vectors); // Put the values from a random spawn in the config into a variable so it can be used
		CloseHandle(spawns); // Close the handle so there are no memory leaks

		// Put the spawn location (origin) and POV (angles) into something a bit easier to keep track of
		origin[0] = vectors[0];
		origin[1] = vectors[1];
		origin[2] = vectors[2];
		angles[0] = vectors[3];
		angles[1] = vectors[4];
		angles[2] = vectors[5];

		/* Below is how players are prevented from spawning within one another */

		new Handle:trace = TR_TraceHullFilterEx(origin, angles, Float:{-24.0, -24.0, 0.0}, Float:{24.0, 24.0, 82.0}, MASK_PLAYERSOLID, TraceEntityFilterPlayers);
		// The above line creates a 'box' at the spawn point to be used. This box is roughly the size of a player

		if(TR_DidHit(trace) && IsValidClient(TR_GetEntityIndex(trace)))
		{
			// The 'box' hit a player!
			CloseHandle(trace);
			CreateTimer(0.0, RandomSpawn, clientid, TIMER_FLAG_NO_MAPCHANGE); // Get a new spawn, because this one is occupied
			return Plugin_Handled;
		}else{
			// All clear
			TeleportEntity(client, origin, angles, NULL_VECTOR); // Teleport the player to their spawn point
			EmitAmbientSound("UI/gift_drop.wav", origin); // Make a sound at the spawn point
		}

		CloseHandle(trace); // Stops leaks dead
	}
	return Plugin_Continue;
}

public bool:TraceEntityFilterPlayers(entity, contentsMask)
{
	// Used by the 'box' method to filter out everything that isn't a player
	if (IsValidClient(entity))
		return true;
	else
		return false;
}

/* Respawn()
 *
 * Respawns a player on a delay.
 * --------------------------------------------------------------------- */
public Action:Respawn(Handle:timer, any:clientid)
{
	new client = GetClientOfUserId(clientid);

	if(!IsValidClient(client))
		return;

	DODRespawnPlayer(client);
}


/**
 * ----------------------------------------------------------------------
 *		____                      
 *	   / __ \___  ____ ____  ____ 
 *	  / /_/ / _ \/ __ `/ _ \/ __ \
 *	 / _, _/  __/ /_/ /  __/ / / /
 *	/_/ |_|\___/\__, /\___/_/ /_/ 
 *			   /____/             
 * ----------------------------------------------------------------------
 */

/* StartRegen()
 *
 * Starts regen-over-time on a player.
 * --------------------------------------------------------------------- */
public Action:StartRegen(Handle:timer, any:clientid)
{
	new client = GetClientOfUserId(clientid);

	if(g_hRegenTimer[client]!=INVALID_HANDLE)
	{
		KillTimer(g_hRegenTimer[client]);
		g_hRegenTimer[client] = INVALID_HANDLE;
	}

	if(!IsValidClient(client))
		return;

	g_bRegen[client] = true;
	Regen(INVALID_HANDLE, clientid);
}

/* Regen()
 *
 * Heals a player for X amount of health every Y seconds.
 * --------------------------------------------------------------------- */
public Action:Regen(Handle:timer, any:clientid)
{
	new client = GetClientOfUserId(clientid);

	if(g_hRegenTimer[client]!=INVALID_HANDLE)
	{
		KillTimer(g_hRegenTimer[client]);
		g_hRegenTimer[client] = INVALID_HANDLE;
	}

	if(!IsValidClient(client))
		return;

	if(g_bRegen[client] && IsPlayerAlive(client))
	{
		new health = GetClientHealth(client)+g_iRegenHP;
		if(health>g_iMaxHealth[client])
			health = g_iMaxHealth[client]; // If the regen would give the client more than their max hp, just set it to max
		SetEntProp(client, Prop_Send, "m_iHealth", health, 1);
		SetEntProp(client, Prop_Data, "m_iHealth", health, 1);

		g_hRegenTimer[client] = CreateTimer(g_fRegenTick, Regen, clientid); // Call this function again in g_fRegenTick seconds
	}
}

/* GetWeaponAmmo()
 *
 * Restock ammo on kill.
 * --------------------------------------------------------------------- */
GetWeaponAmmo(String:w[32])
{
	/* So the name of the weapon that's really equipped is passed to this function, where it is paired with a Amount value that is it's known clip size */
	if (StrEqual("weapon_spring",w) || StrEqual("weapon_k98_scoped",w) || StrEqual("weapon_k98",w)){
		return 5;
	}
	else if (StrEqual("weapon_colt",w)){
		return 7;
	}
	else if (StrEqual("weapon_p38",w) || StrEqual("weapon_garand",w)){
		return 8;
	}
	else if (StrEqual("weapon_bar",w)){
		return 20;
	}
	else if (StrEqual("weapon_thompson",w) || StrEqual("weapon_mp40",w) || StrEqual("weapon_mp44",w)){
		return 30;
	}
	else{
		return 1; // Haven't the foggiest idea what weapon they're holding, just give it 1 bullet and be done with it
	}
}


/**
 * ----------------------------------------------------------------------
 *		______                  __      
 *	   / ____/_   _____  ____  / /______
 *	  / __/  | | / / _ \/ __ \/ __/ ___/
 *	 / /___  | |/ /  __/ / / / /_(__  ) 
 *	/_____/  |___/\___/_/ /_/\__/____/  
 * 
 * ----------------------------------------------------------------------
 */

/* Event_player_death()
 *
 * Called when a player dies.
 * --------------------------------------------------------------------- */
public Action:Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new clientid = GetClientUserId(client);

	if(!IsValidClient(client))
		return;

	CreateTimer(g_fSpawn, Respawn, clientid, TIMER_FLAG_NO_MAPCHANGE);

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String:sWeapon[32];
	new iWeapon;

	if(IsValidEntity(attacker) && attacker > 0)
		GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));

	if(IsValidClient(attacker) && client != attacker)
	{
		if(g_bShowHP)
		{
			if(IsPlayerAlive(attacker))
				PrintToChat(client, "[DM] %t", "Health Remaining", GetClientHealth(attacker));
			else
				PrintToChat(client, "[DM] %t", "Attacker is dead");
		}

		// Heals a flat value
		if(g_iKillHeal > 0)
		{
			if((GetClientHealth(attacker) + g_iKillHeal) > g_iMaxHealth[attacker])
				SetEntProp(attacker, Prop_Data, "m_iHealth", g_iMaxHealth[attacker]);
			else
				SetEntProp(attacker, Prop_Data, "m_iHealth", GetClientHealth(attacker) + g_iKillHeal);
		}

		// Gives full ammo for primary and secondary weapon to the player who got the kill
		if(g_bKillAmmo)
		{
			// Check the primary weapon, and set its ammo
			if(g_iMaxClips1[attacker] > 0 && GetPlayerClass(attacker) != g_iDesiredPlayerClass)
				SetEntProp(GetPlayerWeaponSlot(attacker, 0), Prop_Send, "m_iClip1", g_iMaxClips1[attacker]);
			else if(StrEqual(sWeapon, "weapon_spring") || StrEqual(sWeapon, "weapon_k98_scoped") || StrEqual(sWeapon, "weapon_k98") || StrEqual(sWeapon, "weapon_garand") || StrEqual(sWeapon, "weapon_thompson") || StrEqual(sWeapon, "weapon_mp40") || StrEqual(sWeapon, "weapon_bar") || StrEqual(sWeapon, "weapon_mp44"))	{
				GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
				iWeapon = GetEntDataEnt2(attacker, FindSendPropInfo("CDODPlayer", "m_hActiveWeapon"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetWeaponAmmo(sWeapon));
			}
			// Check the secondary weapon, and set its ammo
			if(g_iMaxClips2[attacker] > 0)
				SetEntProp(GetPlayerWeaponSlot(attacker, 1), Prop_Send, "m_iClip1", g_iMaxClips2[attacker]);
			else if(StrEqual(sWeapon, "weapon_colt") || StrEqual(sWeapon, "weapon_p38"))	{
				GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
				iWeapon = GetEntDataEnt2(attacker, FindSendPropInfo("CDODPlayer", "m_hActiveWeapon"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetWeaponAmmo(sWeapon));
			}
		}
		// Give the killer regen-over-time if so configured
		if(g_bKillStartRegen && !g_bRegen[attacker])
			StartRegen(INVALID_HANDLE, attacker);
	}
}

/* Event_player_hurt()
 *
 * Called when a player is hurt.
 * --------------------------------------------------------------------- */
public Action:Event_player_hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new clientid = GetClientUserId(client);

	if(IsValidClient(attacker) && client!=attacker)
	{
		g_bRegen[client] = false;

		if(g_hRegenTimer[client]!=INVALID_HANDLE)
		{
			KillTimer(g_hRegenTimer[client]);
			g_hRegenTimer[client] = INVALID_HANDLE;
		}
		g_hRegenTimer[client] = CreateTimer(g_fRegenDelay, StartRegen, clientid);
	}
}

/* Event_player_spawn()
 *
 * Called when a player spawns.
 * --------------------------------------------------------------------- */
public Action:Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new clientid = GetClientUserId(client);

	if(g_bPistols)	// Checking if pistols are enabled, if TRUE = give pistols
	{
		CreateTimer(0.1, GivePistols, client);
	}

	if(g_bGrenades)	// Checking if nades are disabled, if TRUE = remove grenades
	{
		CreateTimer(0.1, RemoveGrenades, client);
	}

	if(g_hRegenTimer[client]!=INVALID_HANDLE)
	{
		KillTimer(g_hRegenTimer[client]);
		g_hRegenTimer[client] = INVALID_HANDLE;
	}
	g_hRegenTimer[client] = CreateTimer(0.1, StartRegen, clientid);

	if(!IsValidClient(client))
		return;

	if(g_bSpawnPoints && g_bSpawnMap) // Are random spawns on and does this map have spawns?
		CreateTimer(0.0, RandomSpawn, clientid, TIMER_FLAG_NO_MAPCHANGE);
	else{
		// Play a sound anyway, because sounds are cool
		decl Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);
		EmitAmbientSound("UI/gift_drop.wav", vecOrigin);
	}

	// Get the player's max health and store it in a global variable
	g_iMaxHealth[client] = GetClientHealth(client);

	// Crutch used when regenammo is on and it replaces a weapon that isn't equippable or has no ammo
	g_iMaxClips1[client] = -1;
	g_iMaxClips2[client] = -1;
}

/* Event_round_start()
 *
 * Called when a round starts.
 * --------------------------------------------------------------------- */
public Action:Event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = -1;
	static soundOffset;

	// Remove map objectives from hud
	SetNumControlPoints(0);

	// Remove flag model
	while ((entity = FindEntityByClassname(entity, "dod_control_point")) != -1)
	{
		AcceptEntityInput(entity, "HideModel");
	}

	// Remove flag sound
	while ((entity = FindEntityByClassname(entity, "ambient_generic")) != -1)
	{
		if (!soundOffset && (soundOffset = FindDataMapOffs(entity, "m_iszSound")) == -1)
		{
			LogError("Error: Unable to find datamap offset: \"m_iszSound\"!");
			return;
		}
		decl String:sound[64];
		GetEntDataString(entity, soundOffset, sound, sizeof(sound));

		if (StrEqual(sound, "ambient/flag.wav"))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
	LockMap();
}

/* GivePistols()
 *
 * Give pistols to everyone.
 * --------------------------------------------------------------------- */
public Action:GivePistols(Handle:timer, any:client)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	new team = GetClientTeam(client);
	new ammo_offset = FindSendPropOffs("CDODPlayer", "m_iAmmo");

	if (team == 2) // TEAM US
	{
		GivePlayerItem(client, "weapon_colt");
		SetEntData(client, ammo_offset+4, 14, _, true);
	}

	if (team == 3) // TEAM GER
	{
		GivePlayerItem(client, "weapon_p38");
		SetEntData(client, ammo_offset+8, 16, _, true);
	}
	return Plugin_Handled;
}

/* RemoveGrenades()
 *
 * Remove all grenades then replace smoke to melee weapon.
 * --------------------------------------------------------------------- */
public Action:RemoveGrenades(Handle:timer, any:client)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	new team = GetClientTeam(client);
	new class = GetEntProp(client, Prop_Send, "m_iPlayerClass");
	new smoke = GetPlayerWeaponSlot(client, 2);
	new nades = GetPlayerWeaponSlot(client, 3);

	// Checking if this is assault class
	if(class == 1)	// 1 = ASSAULT
	{
		if(smoke != -1)
		{
			RemovePlayerItem(client, smoke);
			AcceptEntityInput(smoke, "Kill");
		}

		if (team == 2) // TEAM US
		{
			GivePlayerItem(client, "weapon_amerknife");
		}

		if (team == 3) // TEAM GER
		{
			GivePlayerItem(client, "weapon_spade");
		}
	}

	if(nades != -1)
	{
		RemovePlayerItem(client, nades);
		AcceptEntityInput(nades, "Kill");
	}
	return Plugin_Handled;
}

/* HookFlagSound()
 *
 * Remove flag sound.
 * --------------------------------------------------------------------- */
public Action:HookFlagSound(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay)
{
	if(StrEqual(sample, "ambient/flag.wav"))
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/* Command_Loc()
 *
 * Show current player location.
 * --------------------------------------------------------------------- */
public Action:Command_Loc(client, args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	new Float:vec[3];
	new Float:ang[3];

	GetClientAbsOrigin(client, vec);
	GetClientEyeAngles(client, ang);

	PrintToChat(client,"origin	%.0f %.0f %.0f\nangles	0 %.0f 0",vec[0],vec[1],vec[2]+10,ang[1]);
	return Plugin_Handled;
}


/**
 * ----------------------------------------------------------------------
 *		__  ____           
 *	   /  |/  (_)__________
 *	  / /|_/ / // ___/ ___/
 *	 / /  / / /(__  ) /__  
 *	/_/  /_/_//____/\___/  
 *						   
 * ----------------------------------------------------------------------
 */

/* RespawnPlayer()
 *
 * Respawn a player.
 * --------------------------------------------------------------------- */
DODRespawnPlayer(client)
{
	if (GetEntData(client, g_iDesiredPlayerClass) != -1)
	{
		SDKCall(g_hPlayerRespawn, client);
	}
}

/* LockMap()
 *
 * Locks all objectives on the map and gets it ready for DM.
 * --------------------------------------------------------------------- */
LockMap()
{
	// List of entities to remove. This should remove all objectives on a map
	new String:entRemove[][] ={
									"dod_round_timer",
									"dod_capture_area",
									"dod_bomb_target",
									"dod_bomb_dispenser",
									"dod_bomb_dispenser_icon",
									"func_team_wall",
									"func_teamblocker"
									};

	for(new i = 0; i < sizeof(entRemove); i++)
	{
		new ent = MAXPLAYERS+1;

		while((ent = FindEntityByClassname2(ent, entRemove[i])) != -1)
		{
			if(IsValidEdict(ent))
			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill");
		}
	}
	ResetPlayers();
}

/* ResetPlayers()
 *
 * Can respawn or reset regen-over-time on all players.
 * --------------------------------------------------------------------- */
ResetPlayers()
{
	new id;

	if(FirstLoad == true){
		for (new i = 0; i < MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				id = GetClientUserId(i);
				CreateTimer(g_fSpawn, Respawn, id, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		FirstLoad = false;
	}else{
		for (new i = 0; i < MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				id = GetClientUserId(i);
				CreateTimer(0.1, StartRegen, id, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * --------------------------------------------------------------------- */
bool:IsValidClient(client)
{
	if (client < 1 || client > MaxClients)
		return false;

	if (!IsClientConnected(client))
		return false;
	return IsClientInGame(client);
}

/* FindEntityByClassname2()
 *
 * Finds entites, and won't error out when searching invalid entities.
 * --------------------------------------------------------------------- */
stock FindEntityByClassname2(startEnt, const String:classname[])
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;

	return FindEntityByClassname(startEnt, classname);
}

/* GetRealClientCount()
 *
 * Gets the number of clients connected to the game.
 * --------------------------------------------------------------------- */
stock GetRealClientCount()
{
	new clients = 0;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			clients++;
		}
	}
	return clients;
}
//1024 AAAAAAWWWWWWWW YYYYYYEEEEEEEEEAAAAAAAAAAAA