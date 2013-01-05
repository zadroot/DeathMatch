/**
 * ---------------------------------------------------------------------
 *	    ______                  __
 *	   / ____/_   _____  ____  / /______
 *	  / __/  | | / / _ \/ __ \/ __/ ___/
 *	 / /___  | |/ /  __/ / / / /_(__  )
 *	/_____/  |___/\___/_/ /_/\__/____/
 *
 * ---------------------------------------------------------------------
*/

/* LoadEvents()
 *
 * Load events.
 * --------------------------------------------------------------------- */
LoadEvents()
{
	HookEvent("player_spawn",    Event_player_spawn);
	HookEvent("player_hurt",     Event_player_hurt);
	HookEvent("player_death",    Event_player_death);
	HookEvent("dod_round_start", Event_round_start, EventHookMode_PostNoCopy);
}

/* Event_player_spawn()
 *
 * Called when a player spawns.
 * --------------------------------------------------------------------- */
public Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team   = GetClientTeam(client), smoke, grenades;

	if (team > Team_Spectator)
	{
		new Handle:spawnPointsArray = CreateArray();

		if (g_ConVars[ConVar_Mode][Value])
		{
			// If FFA mode is active, get spawn points from both teams
			for (new i = 0; i < SpawnPointTeam_Size; i++)
			{
				for (new x = 0; x < g_iNumSpawnPoints[i]; x++)
				{
					if (TestSpawnPoint(g_vecSpawnPointOrigin[i][x]))
					{
						// Push team and spawn point index into the array as 16 bit ints
						PushArrayCell(spawnPointsArray, i|(x << 16));
					}
				}
			}
		}
		else
		{
			// If deathmatch mode is active, get team specific spawn points
			new spawnPointTeam = GetClientTeam(client) - 2;

			for (new x = 0; x < g_iNumSpawnPoints[spawnPointTeam]; x++)
			{
				if (TestSpawnPoint(g_vecSpawnPointOrigin[spawnPointTeam][x]))
				{
					// Push team and spawn point index into the array as 16 bit ints
					PushArrayCell(spawnPointsArray, spawnPointTeam|(x << 16));
				}
			}
		}

		if (g_ConVars[ConVar_Pistols][Value])
		{
			switch (GetPlayerClass(client))
			{
				case PlayerClass_Rifleman, PlayerClass_Support:
				{
					if (team == Team_Allies)
					{
						GivePlayerItem(client, "weapon_colt");
						SetEntData(client, g_iOffset_Ammo + AMMO_OFFSET_COLT, 14);
					}
					else
					{
						GivePlayerItem(client, "weapon_p38");
						SetEntData(client, g_iOffset_Ammo + AMMO_OFFSET_P38, 16);
					}
				}
			}
		}

		if (!g_ConVars[ConVar_Grenades][Value])
		{
			if ((grenades = GetPlayerWeaponSlot(client, 3)) != -1)
			{
				RemoveWeapon(client, grenades);
			}

			// If we want to disable all grenades we should replace smoke to melee weapon
			switch (GetPlayerClass(client))
			{
				case PlayerClass_Assault:
				{
					if ((smoke = GetPlayerWeaponSlot(client, 2)) != -1)
					{
						RemoveWeapon(client, smoke);
					}

					if (team == Team_Allies)
					{
						GivePlayerItem(client, "weapon_amerknife");
					}
					else
					{
						GivePlayerItem(client, "weapon_spade");
					}
				}
			}
		}

		new arraySize = GetArraySize(spawnPointsArray);

		// Array size should never be zero, but you never know
		if (arraySize)
		{
			new data = GetArrayCell(spawnPointsArray, GetRandomInt(0, arraySize - 1));

			// Get the team and spawn point index
			new spawnPointTeam = data & 0x0000FFFF;
			new spawnPointIndex = data >> 16;

			TeleportEntity(client, g_vecSpawnPointOrigin[spawnPointTeam][spawnPointIndex], g_vecSpawnPointAngles[spawnPointTeam][spawnPointIndex], NULL_VECTOR);
		}

		CloseHandle(spawnPointsArray);

		decl Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		if (g_ConVars[ConVar_SpawnSound][Value])
		{
			EmitAmbientSound("UI/gift_drop.wav", vecOrigin);
		}

		g_bHealthRegen[client] = false;
		g_fHealthRegenDelay[client] = 0.0;
	}
}

/* Event_player_hurt()
 *
 * Called when a player gets hurt.
 * --------------------------------------------------------------------- */
public Event_player_hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Add health regeneration delay
	g_bHealthRegen[client] = false;
	g_fHealthRegenDelay[client] = GetGameTime() + Float:g_ConVars[ConVar_RegenDelay][Value];
}

/* Event_player_death()
 *
 * Called when a player dies.
 * --------------------------------------------------------------------- */
public Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new clientUserId = GetEventInt(event, "userid");
	new client       = GetClientOfUserId(clientUserId);

	new attackerUserId = GetEventInt(event, "attacker");
	new attacker       = GetClientOfUserId(attackerUserId);

	CreateTimer(g_ConVars[ConVar_SpawnDelay][Value], Timer_Respawn, clientUserId, TIMER_FLAG_NO_MAPCHANGE);

	// Make sure that the attacker is valid
	if (attacker && attacker != client)
	{
		if (g_ConVars[ConVar_Mode][Value] && GetClientTeam(client) == GetClientTeam(attacker))
		{
			static fragsOffset;

			// Since m_iFrags is a datamap, we cannot obtain it without having the entity index
			if (!fragsOffset && (fragsOffset = FindDataMapOffs(client, "m_iFrags")) == -1)
			{
				LogError("Unable to find offset: \"m_iFrags\"!");
			}

			SetEntData(attacker, fragsOffset, GetEntData(attacker, fragsOffset) + 2);
		}

		new attackerHealth = GetEntData(attacker, g_iOffset_Health);

		if (g_ConVars[ConVar_ShowHP][Value])
		{
			if (IsPlayerAlive(attacker))
			{
				PrintToChat(client, "\x05[DM]\x01 %t", "Health Remaining", attackerHealth);
			}
			else
			{
				PrintToChat(client, "\x05[DM]\x01 %t", "Attacker is dead");
			}
		}

		if (g_ConVars[ConVar_KillStartRegen][Value])
		{
			g_bHealthRegen[attacker] = true;
			g_fHealthRegenDelay[attacker] = 0.0;
		}

		if (g_ConVars[ConVar_KillHeal][Value] > 0)
		{
			GiveHealth(attacker, g_ConVars[ConVar_KillHeal][Value]);
		}

		if (g_ConVars[ConVar_KillAmmo][Value])
		{
			CreateTimer(0.1, Timer_RefillClip, attackerUserId, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

/* Event_round_start()
 *
 * Called when a round starts.
 * --------------------------------------------------------------------- */
public Event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Remove map objectives from the HUD (DoD Hooks)
	SetNumControlPoints(0);

	new entity = -1;

	static const String:entRemove[][] =
	{
		"dod_round_timer",
		"dod_capture_area",
		"dod_bomb_target",
		"dod_bomb_dispenser_icon",
		"dod_scoring",
		"func_team_wall",
		"func_teamblocker"
	};

	// Loop through and delete all entities from the entity removal list
	for (new i = 0; i < sizeof(entRemove); i++)
	{
		while ((entity = FindEntityByClassname(entity, entRemove[i])) != -1)
		{
			AcceptEntityInput(entity, "Kill");
		}
	}

	// Server crashes if you remove a bomb dispenser, so we disable it instead
	if ((entity = FindEntityByClassname(entity, "dod_bomb_dispenser")) != -1)
	{
		AcceptEntityInput(entity, "Disable");
	}

	// Hide the flag model
	while ((entity = FindEntityByClassname(entity, "dod_control_point")) != -1)
	{
		AcceptEntityInput(entity, "HideModel");
	}
}

/* TestSpawnPoint()
 *
 * Returns true if the position is empty, false otherwise.
 * --------------------------------------------------------------------- */
bool:TestSpawnPoint(const Float:vecOrigin[3])
{
	TR_TraceHull(vecOrigin, vecOrigin, Float:{ -16.0, -16.0, 0.0 }, Float:{ 16.0, 16.0, 82.0 }, MASK_PLAYERSOLID);

	return !TR_DidHit();
}

/* Timer_RefillClip()
 *
 * Refills a player's the primary and pistol clip.
 * --------------------------------------------------------------------- */
public Action:Timer_RefillClip(Handle:timer, any:client)
{
	if ((client = GetClientOfUserId(client)) > 0)
	{
		// Make sure that the client is valid
		static const clipSizes[] =
		{
			7,   // Colt
			8,   // P38
			20,  // C96
			8,   // Garand
			5,   // K98
			5,   // K98 scoped
			15,  // M1 Carbine
			5,   // Spring
			30,  // Thompson
			32,  // MP40
			30,  // Stg44
			20,  // BAR
			150, // 30cal
			250, // MG42
			1,   // Bazooka
			1    // Panzerschreck
		};

		static const String:weaponNames[][] =
		{
			"colt",
			"p38",
			"c96",
			"garand",
			"k98",
			"k98_scoped",
			"m1carbine",
			"spring",
			"thompson",
			"mp40",
			"mp44",
			"bar",
			"30cal",
			"mg42",
			"bazooka",
			"pschreck"
		};

		new weaponsFound;

		// Loop through all the players weapons
		for (new i = 0; i < 48; i++)
		{
			new weapon = GetEntDataEnt2(client, g_iOffset_MyWeapons + (i * 4));

			if (weapon != -1)
			{
				decl String:className[64];
				GetEdictClassname(weapon, className, sizeof(className));

				// Remove 'weapon_' from the classname to improve performance
				if (ReplaceString(className, sizeof(className), "weapon_", NULL_STRING))
				{
					for (new x = 0; x < sizeof(weaponNames); x++)
					{
						if (StrEqual(className, weaponNames[x]))
						{
							SetEntData(weapon, g_iOffset_Clip, clipSizes[x], _, true);

							// We are only are going to refill the ammo on two weapons
							if (++weaponsFound >= 2) break;
						}
					}
				}
			}
		}
	}
}

/* Timer_Respawn()
 *
 * Respawns a player.
 * --------------------------------------------------------------------- */
public Action:Timer_Respawn(Handle:timer, any:client)
{
	// Make sure that the client is valid
	if ((client = GetClientOfUserId(client)) > 0 && GetPlayerClass(client) != PlayerClass_None)
	{
		RespawnPlayer(client, false);
	}
}