/**
 * ---------------------------------------------------------------------
 *     ____  ________          __
 *    / __ \/ __/ __/_______  / /______
 *   / / / / /_/ /_/ ___/ _ \/ __/ ___/
 *  / /_/ / __/ __(__  )  __/ /_(__  )
 *  \____/_/ /_/ /____/\___/\__/____/
 *
 * ---------------------------------------------------------------------
*/

new	g_iOffset_Team,
	g_iOffset_Alive,
	g_iOffset_TeamNum,
	g_iOffset_Health,
	g_iOffset_Ammo,
	g_iOffset_Clip,
	g_iOffset_MyWeapons;

/* LoadOffsets()
 *
 * Load offsets.
 * --------------------------------------------------------------------- */
LoadOffsets()
{
	g_iOffset_Team      = FindSendPropOffsEx("CDODPlayerResource", "m_iTeam");
	g_iOffset_Alive     = FindSendPropOffsEx("CDODPlayerResource", "m_bAlive");
	g_iOffset_Health    = FindSendPropOffsEx("CBasePlayer",        "m_iHealth");
	g_iOffset_TeamNum   = FindSendPropOffsEx("CBaseEntity",        "m_iTeamNum");
	g_iOffset_Ammo      = FindSendPropOffsEx("CBasePlayer",        "m_iAmmo");
	g_iOffset_Clip      = FindSendPropOffsEx("CBaseCombatWeapon",  "m_iClip1");
	g_iOffset_MyWeapons = FindSendPropOffsEx("CBasePlayer",        "m_hMyWeapons");
}

/* FindSendPropOffsEx()
 *
 * Returns the offset of the specified network property.
 * --------------------------------------------------------------------- */
FindSendPropOffsEx(const String:serverClass[64], const String:propName[64])
{
	new offset = FindSendPropOffs(serverClass, propName);

	if (offset <= 0)
	{
		SetFailState("Unable to find offset: \"%s::%s\"!", serverClass, propName);
	}

	return offset;
}