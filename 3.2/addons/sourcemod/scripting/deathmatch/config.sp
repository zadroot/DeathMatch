/**
 * ---------------------------------------------------------------------
 *     ______            _____
 *    / ____/___  ____  / __(_)___ _
 *   / /   / __ \/ __ \/ /_/ / __ `/
 *  / /___/ /_/ / / / / __/ / /_/ /
 *  \____/\____/_/ /_/_/ /_/\__, /
 *                         /____/
 * ---------------------------------------------------------------------
*/

static const String:g_szSpawnPointTeams[][] = { "allies", "axis" };

/* LoadConfig()
*
* Loads the spawnpoint config for the current map.
 * --------------------------------------------------------------------- */
LoadConfig()
{
	g_iNumSpawnPoints[SpawnPointTeam_Allies] =
	g_iNumSpawnPoints[SpawnPointTeam_Axis]   = 0;

	decl String:mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));

	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/deathmatch/%s.cfg", mapName);

	if (FileExists(path))
	{
		new Handle:kv = CreateKeyValues("Spawns");

		FileToKeyValues(kv, path);

		for (new i; i < sizeof(g_szSpawnPointTeams); i++)
		{
			if (KvJumpToKey(kv, g_szSpawnPointTeams[i]))
			{
				KvGotoFirstSubKey(kv);

				do
				{
					new numSpawnPoints = g_iNumSpawnPoints[i];

					if (	KvGetVector(kv, "angles", g_vecSpawnPointAngles[i][numSpawnPoints])
					&&		KvGetVector(kv, "origin", g_vecSpawnPointOrigin[i][numSpawnPoints]))
					{
						g_iNumSpawnPoints[i]++;
					}
					else
					{
						LogError("Spawnpoint #%i for team %s is invalid!", g_iNumSpawnPoints[i], g_szSpawnPointTeams[i]);
					}
				}
				while (KvGotoNextKey(kv) && g_iNumSpawnPoints[i] < MAX_SPAWNPOINTS);
			}
			else
			{
				LogError("Missing spawnpoints for %s team!", g_szSpawnPointTeams[i]);
			}

			KvRewind(kv);
		}

		CloseHandle(kv);
	}
	else
	{
		LogError("Unable to read or open file: \"%s\"!", path);
	}
}

/* SaveConfig()
 *
 * Saves all the spawn point locations.
 * --------------------------------------------------------------------- */
SaveConfig()
{
	new Handle:kv = CreateKeyValues("Spawns");

	for (new i; i < sizeof(g_szSpawnPointTeams); i++)
	{
		if (KvJumpToKey(kv, g_szSpawnPointTeams[i], true))
		{
			KvGotoFirstSubKey(kv);

			new numSpawnPoints = g_iNumSpawnPoints[i];

			for (new x; x < numSpawnPoints; x++)
			{
				decl String:keyName[8];
				IntToString(x, keyName, sizeof(keyName));

				if (KvJumpToKey(kv, keyName, true))
				{
					KvSetVector(kv, "angles", g_vecSpawnPointAngles[i][x]);
					KvSetVector(kv, "origin", g_vecSpawnPointOrigin[i][x]);
				}

				KvGoBack(kv);
			}
		}

		KvRewind(kv);
	}

	decl String:mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));

	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/deathmatch/%s.cfg", mapName);

	if (!KeyValuesToFile(kv, path))
	{
		LogError("Failed to save spawn point file: \"%s\"!", path);
	}
}