/**
 * ---------------------------------------------------------------------
 *     ______
 *    / ____/___  ____  _   __ _______________
 *   / /   / __ \/ __ \| | / / __ `/ ___/ ___/
 *  / /___/ /_/ / / / /| |/ / /_/ / /  (__  )
 *  \____/\____/_/ /_/ |___/\__,_/_/  /____/
 *
 * ---------------------------------------------------------------------
*/

enum
{
	ConVar_Mode,
	ConVar_Pistols,
	ConVar_Grenades,
	ConVar_KillAmmo,
	ConVar_KillHeal,
	ConVar_KillStartRegen,
	ConVar_RegenHP,
	ConVar_RegenTick,
	ConVar_RegenDelay,
	ConVar_SpawnDelay,
	ConVar_ShowHP,
	ConVar_SpawnSound,
	ConVar_LockObjectives,

	ConVar_Size
};

enum ValueType
{
	ValueType_Int,
	ValueType_Bool,
	ValueType_Float
};

enum ConVar
{
	Handle:ConVarHandle,	// Handle of the convar
	ValueType:Type,			// Type of value (int, bool, float)
	any:Value				// The value
};

new g_ConVars[ConVar_Size][ConVar];

/* LoadConVars()
 *
 * Initialze cvars for plugin.
 * --------------------------------------------------------------------- */
LoadConVars()
{
	// Create convars
	CreateConVar("deathmatch_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	AddConVar(ConVar_Mode,           ValueType_Bool,   CreateConVar("dm_mode",             "1",   "Sets the DeathMatch mode:\n0 = Team DeathMatch\n1 = Free For All", FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_Pistols,        ValueType_Bool,   CreateConVar("dm_pistols",          "1",   "Whether or not give pistols for Rifleman and Support classes",     FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_Grenades,       ValueType_Bool,   CreateConVar("dm_grenades",         "0",   "Whether or not smoke, rifle and frag grenades should be allowed",  FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_KillAmmo,       ValueType_Bool,   CreateConVar("dm_kill_ammo",        "1",   "Enable or disable ammo restoration on kills",                      FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_KillHeal,       ValueType_Int,    CreateConVar("dm_kill_heal_amount", "20",  "Amount of health to restore on kills",                             FCVAR_PLUGIN, true, 0.0, true, 100.0));
	AddConVar(ConVar_KillStartRegen, ValueType_Bool,   CreateConVar("dm_kill_start_regen", "1",   "Start health regeneration immediately after a kill",               FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_RegenHP,        ValueType_Bool,   CreateConVar("dm_regen_hp",         "2",   "Health added per regeneration tick.\nSet to 0 to disable",         FCVAR_PLUGIN, true, 0.0));
	AddConVar(ConVar_RegenTick,      ValueType_Float,  CreateConVar("dm_regen_tick",       "0.5", "Delay between regeration ticks (in seconds)",                      FCVAR_PLUGIN, true, 0.0));
	AddConVar(ConVar_RegenDelay,     ValueType_Float,  CreateConVar("dm_regen_delay",      "4.0", "Delay after hurt before regeneration",                             FCVAR_PLUGIN, true, 0.0));
	AddConVar(ConVar_SpawnDelay,     ValueType_Float,  CreateConVar("dm_spawn_delay",      "2.0", "Number of seconds to wait before respawning a player",             FCVAR_PLUGIN, true, 1.0));
	AddConVar(ConVar_ShowHP,         ValueType_Bool,   CreateConVar("dm_showhp",           "1",   "Print killer's health on death",                                   FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_SpawnSound,     ValueType_Bool,   CreateConVar("dm_spawnsound",       "1",   "Enable or disable respawning sound",                               FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ConVar_LockObjectives, ValueType_Bool,   CreateConVar("dm_lockobjectives",   "1",   "Whether or not disable all objectives on a map (TDM only!)",       FCVAR_PLUGIN, true, 0.0, true, 1.0));
}

/* AddConVar()
 *
 * Used to add a convar into the convar list.
 * --------------------------------------------------------------------- */
AddConVar(conVar, ValueType:type, Handle:conVarHandle)
{
	g_ConVars[conVar][ConVarHandle] = conVarHandle;
	g_ConVars[conVar][Type] = type;

	UpdateConVarValue(conVar);

	HookConVarChange(conVarHandle, OnConVarChange);
}

/* UpdateConVarValue()
 *
 * Updates the internal convar values.
 * --------------------------------------------------------------------- */
UpdateConVarValue(conVar)
{
	switch (g_ConVars[conVar][Type])
	{
		case ValueType_Int:   g_ConVars[conVar][Value] = GetConVarInt(g_ConVars[conVar][ConVarHandle]);
		case ValueType_Bool:  g_ConVars[conVar][Value] = GetConVarBool(g_ConVars[conVar][ConVarHandle]);
		case ValueType_Float: g_ConVars[conVar][Value] = GetConVarFloat(g_ConVars[conVar][ConVarHandle]);
	}
}

/* UpdateModeConVars()
 *
 * Updates the friendly fire convars depending on which mode is active.
 * --------------------------------------------------------------------- */
UpdateModeConVars()
{
	static Handle:conVarFriendlyFire;
	static Handle:conVarFriendlyFireSafeZone;

	if (!conVarFriendlyFire)
		conVarFriendlyFire = FindConVar("mp_friendlyfire");

	if (!conVarFriendlyFireSafeZone)
		conVarFriendlyFireSafeZone = FindConVar("dod_friendlyfiresafezone");

	if (g_ConVars[ConVar_Mode][Value])
	{
		// It's FFA, enable friendlyfire!
		SetConVarBool(conVarFriendlyFire, true);
		SetConVarInt(conVarFriendlyFireSafeZone, false);

		// Workaround collision
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				SDKHook(i, SDKHook_ShouldCollide, OnShouldCollide);
			}
		}
	}
	else
	{
		// Nope it's TDM.
		SetConVarBool(conVarFriendlyFire, false);
		SetConVarInt(conVarFriendlyFireSafeZone, 100);

		// Just unhook collision on all players and done with it
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_ShouldCollide, OnShouldCollide);
			}
		}
	}
}

/* OnConVarChange()
 *
 * Updates the stored convar value if the convar's value change.
 * --------------------------------------------------------------------- */
public OnConVarChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	for (new i; i < ConVar_Size; i++)
	{
		if (conVar == g_ConVars[i][ConVarHandle])
		{
			UpdateConVarValue(i);

			if (i == ConVar_Mode)
			{
				UpdateModeConVars();

				// If the round is active, restart the round
				if (_:GameRules_GetRoundState() != DoDRoundState_Restart)
				{
					SetRoundState(DoDRoundState_Restart);
				}
			}
			else if (i == ConVar_RegenTick)
			{
				// If the convar changed while the regen timer is active, recreate the timer
				if (g_hRegenTimer)
				{
					CloseHandle(g_hRegenTimer);

					g_hRegenTimer = CreateTimer(g_ConVars[ConVar_RegenTick][Value], Timer_RegenHealth, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				}
			}

			break;
		}
	}
}