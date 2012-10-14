/**
 * ---------------------------------------------------------------------
 *	   ______
 *	  / ____/___  ____  _   __ _______________
 *	 / /   / __ \/ __ \| | / / __ `/ ___/ ___/
 *	/ /___/ /_/ / / / /| |/ / /_/ / /  (__  ) 
 *	\____/\____/_/ /_/ |___/\__,_/_/  /____/  
 *
 * ---------------------------------------------------------------------
*/

enum
{
	ConVar_Mode = 0,
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
	ConVar_CustomConfig,

	ConVar_Size
};

enum ValueType
{
	ValueType_Int = 0,
	ValueType_Bool,
	ValueType_Float,
	ValueType_String
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
	CreateConVar("deathmatch_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	AddConVar(ConVar_Mode,           ValueType_Bool,   CreateConVar("dm_mode",             "1",   "Set DeathMatch mode. 0 = Team Deathmatch (allies vs axis), 1 = Free For All (all vs all)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_Pistols,        ValueType_Bool,   CreateConVar("dm_pistols",          "1",   "Give pistols for Rifleman & Support classes.",                                             FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_Grenades,       ValueType_Bool,   CreateConVar("dm_grenades",         "0",   "Allow grenades & smoke in DM.",                                                            FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_KillAmmo,       ValueType_Bool,   CreateConVar("dm_kill_ammo",        "1",   "Enable ammo restoration on kills.",                                                        FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_KillHeal,       ValueType_Int,    CreateConVar("dm_kill_heal_amount", "20",  "Amount of HP to restore on kills.",                                                        FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 100.0));
	AddConVar(ConVar_KillStartRegen, ValueType_Bool,   CreateConVar("dm_kill_start_regen", "1",   "Start the heal-over-time regen immediately after a kill.",                                 FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_RegenHP,        ValueType_Bool,   CreateConVar("dm_regenhp",          "1",   "Health added per regeneration tick. Set to 0 to disable.",                                 FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0));
	AddConVar(ConVar_RegenTick,      ValueType_Float,  CreateConVar("dm_regentick",        "0.3", "Delay between regeration ticks (in seconds).",                                             FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0));
	AddConVar(ConVar_RegenDelay,     ValueType_Float,  CreateConVar("dm_regendelay",       "4.0", "Seconds after damage before regeneration.",                                                FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0));
	AddConVar(ConVar_SpawnDelay,     ValueType_Float,  CreateConVar("dm_spawn_delay",      "3.0", "Spawn timer.",                                                                             FCVAR_PLUGIN|FCVAR_NOTIFY, true, 1.0));
	AddConVar(ConVar_ShowHP,         ValueType_Bool,   CreateConVar("dm_showhp",           "1",   "Print killer's health to victim on death.",                                                FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0));
	AddConVar(ConVar_CustomConfig,   ValueType_String, CreateConVar("dm_customconfig",     "",    "Load a custom config when DM is loaded. (without .cfg!)",                                  FCVAR_PLUGIN));
}

/* AddConVar()
 *
 * Used to add a convar into the convar list.
 * --------------------------------------------------------------------- */
AddConVar(conVar, ValueType:type, Handle:conVarHandle)
{
	g_ConVars[conVar][ConVarHandle] = conVarHandle;
	g_ConVars[conVar][Type] = type;

	if (type != ValueType_String)
	{
		UpdateConVarValue(conVar);

		HookConVarChange(conVarHandle, OnConVarChange);
	}
}

/* UpdateConVarValue()
 *
 * Updates the internal convar values.
 * --------------------------------------------------------------------- */
UpdateConVarValue(conVar)
{
	switch (g_ConVars[conVar][Type])
	{
		case ValueType_Int:    g_ConVars[conVar][Value] = GetConVarInt(g_ConVars[conVar][ConVarHandle]);
		case ValueType_Bool:   g_ConVars[conVar][Value] = GetConVarBool(g_ConVars[conVar][ConVarHandle]);
		case ValueType_Float:  g_ConVars[conVar][Value] = GetConVarFloat(g_ConVars[conVar][ConVarHandle]);
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
	{
		conVarFriendlyFire = FindConVar("mp_friendlyfire");
	}

	if (!conVarFriendlyFireSafeZone)
	{
		conVarFriendlyFireSafeZone = FindConVar("dod_friendlyfiresafezone");
	}

	if (g_ConVars[ConVar_Mode][Value])
	{
		// It's FFA, enable friendlyfire!
		SetConVarBool(conVarFriendlyFire, true);
		SetConVarInt(conVarFriendlyFireSafeZone, 0);
	}
	else
	{
		// Nope it's TDM.
		SetConVarBool(conVarFriendlyFire, false);
		SetConVarInt(conVarFriendlyFireSafeZone, 100);
	}
}

/* OnConVarChange()
 *
 * Updates the stored convar value if the convar's value change.
 * --------------------------------------------------------------------- */
public OnConVarChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	for (new i = 0; i < ConVar_Size; i++)
	{
		if (conVar == g_ConVars[i][ConVarHandle])
		{
			UpdateConVarValue(i);

			if (i == ConVar_Mode)
			{
				UpdateModeConVars();

				// If the round is active, restart the round
				if (_:GameRules_GetRoundState() == DoDRoundState_RoundRunning)
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

					g_hRegenTimer = CreateTimer(g_ConVars[ConVar_RegenTick][Value], Timer_RegenHealth, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				}
			}

			break;
		}
	}
}