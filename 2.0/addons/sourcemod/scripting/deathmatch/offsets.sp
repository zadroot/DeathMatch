/**
 * ---------------------------------------------------------------------
 *	   ____  ________          __      
 *	  / __ \/ __/ __/_______  / /______
 *	 / / / / /_/ /_/ ___/ _ \/ __/ ___/
 *	/ /_/ / __/ __(__  )  __/ /_(__  ) 
 *	\____/_/ /_/ /____/\___/\__/____/  
 *
 * ---------------------------------------------------------------------
*/

new g_iOffset_Team;
new g_iOffset_Alive;
new g_iOffset_TeamNum;
new g_iOffset_Health;
new g_iOffset_Ammo;
new g_iOffset_Clip;
new g_iOffset_MyWeapons;

/* LoadOffsets()
 *
 * Load offsets.
 * --------------------------------------------------------------------- */
LoadOffsets()
{
	g_iOffset_Team      = GetSendPropOffset("CDODPlayerResource", "m_iTeam");
	g_iOffset_Alive     = GetSendPropOffset("CDODPlayerResource", "m_bAlive");
	g_iOffset_TeamNum   = GetSendPropOffset("CBaseEntity",        "m_iTeamNum");
	g_iOffset_Health    = GetSendPropOffset("CBasePlayer",        "m_iHealth");
	g_iOffset_Ammo      = GetSendPropOffset("CBasePlayer",        "m_iAmmo");
	g_iOffset_Clip      = GetSendPropOffset("CBaseCombatWeapon",  "m_iClip1");
	g_iOffset_MyWeapons = GetSendPropOffset("CBasePlayer",        "m_hMyWeapons");
}

/* GetSendPropOffset()
 *
 * Returns the offset of the specified network property.
 * --------------------------------------------------------------------- */
GetSendPropOffset(const String:serverClass[64], const String:propName[64])
{
	new offset = FindSendPropOffs(serverClass, propName);

	if (!offset)
	{
		SetFailState("Fatal Error: Unable to find offset: \"%s::%s\"!", serverClass, propName);
	}

	return offset;
}