/**
 * ---------------------------------------------------------------------
 *	   ______                                          __    
 *	  / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *	 / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *	/ /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  )
 *	\____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/
 *
 * ---------------------------------------------------------------------
*/

/* LoadCommands()
 *
 * Load commands.
 * --------------------------------------------------------------------- */
LoadCommands()
{
	RegAdminCmd("sm_addsp", Command_AddSpawnPoint, ADMFLAG_ROOT, "Adds a spawn point.");
	RegAdminCmd("sm_savesp", Command_SaveSpawnPoints, ADMFLAG_ROOT, "Save all spawn points.");

	RegConsoleCmd("jointeam", Command_JoinTeam);
}

/* Command_JoinTeam()
 *
 * Called when a player tries to join a team.
 * --------------------------------------------------------------------- */
public Action:Command_JoinTeam(client, args)
{
	// If FFA mode is active, block the command
	if (g_ConVars[ConVar_Mode][Value])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/* Command_AddSpawnPoint()
 *
 * Adds a spawn point.
 * --------------------------------------------------------------------- */
public Action:Command_AddSpawnPoint(client, numArgs)
{
	if (client && IsPlayerAlive(client))
	{
		if (numArgs >= 1)
		{
			decl String:arg[16];
			GetCmdArg(1, arg, sizeof(arg));

			new spawnPointTeam = -1;

			if (StrEqual(arg, "allies", false))
			{
				spawnPointTeam = SpawnPointTeam_Allies;

				ReplyToCommand(client, "[DM] %t", "Spawn created", g_iNumSpawnPoints[spawnPointTeam], arg);
			}
			else if (StrEqual(arg, "axis", false))
			{
				spawnPointTeam = SpawnPointTeam_Axis;

				ReplyToCommand(client, "[DM] %t", "Spawn created", g_iNumSpawnPoints[spawnPointTeam], arg);
			}

			if (spawnPointTeam != -1)
			{
				if (g_iNumSpawnPoints[spawnPointTeam] >= MAX_SPAWNPOINTS)
				{
					ReplyToCommand(client, "[DM] %t", "Cannot add", MAX_SPAWNPOINTS);

					return Plugin_Handled;
				}

				// Since the array index of our new spawnpoint will be number of spawn points - 1, we make an increment after the value has been returned
				new numSpawnPoints = g_iNumSpawnPoints[spawnPointTeam]++;

				GetClientEyeAngles(client, g_vecSpawnPointAngles[spawnPointTeam][numSpawnPoints]);
				GetClientAbsOrigin(client, g_vecSpawnPointOrigin[spawnPointTeam][numSpawnPoints]);

				// Set X axis to 0
				g_vecSpawnPointAngles[spawnPointTeam][numSpawnPoints][0] = 0.0;

				// Elevate spawn point 10 units
				g_vecSpawnPointOrigin[spawnPointTeam][numSpawnPoints][2] += 10.0;

				return Plugin_Handled;
			}
		}

		ReplyToCommand(client, "[DM] %t", "Usage");
	}

	return Plugin_Handled;
}

/* Command_SaveSpawnPoints()
 *
 * Saves all spawn points.
 * --------------------------------------------------------------------- */
public Action:Command_SaveSpawnPoints(client, numArgs)
{
	decl String:mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	ReplyToCommand(client, "[DM] %t", "Spawnpoints saved", mapName);

	SaveConfig();

	return Plugin_Handled;
}