/**
 * ---------------------------------------------------------------------
 *		__  __            __       
 *	   / / / /___  ____  / /_______
 *	  / /_/ / __ \/ __ \/ //_/ ___/
 *	 / __  / /_/ / /_/ / ,< (__  ) 
 *	/_/ /_/\____/\____/_/|_/____/  
 *
 * ---------------------------------------------------------------------
*/

/* LoadHooks()
 *
 * Load hooks.
 * --------------------------------------------------------------------- */
LoadHooks()
{
	HookUserMessage(GetUserMessageId("HintText"), Hook_HintText, true);
	HookUserMessage(GetUserMessageId("VGUIMenu"), Hook_VGUIMenu, true);
}

/* Timer_ShowNewMOTD()
 *
 * Displays a new MOTD panel, which doesn't show the team select menu after exit.
 * --------------------------------------------------------------------- */
public Action:Timer_ShowNewMOTD(Handle:timer, any:client)
{
	// Make sure that the client has not disconnected
	if ((client = EntRefToEntIndex(client)) != INVALID_ENT_REFERENCE)
	{
		new randomTeam = GetRandomTeam();

		SetTeamNum(client, randomTeam);

		ShowVGUIPanel(client, randomTeam == Team_Allies ? "class_us" : "class_ger", INVALID_HANDLE, true);

		ShowMOTDPanel(client, "Message Of The Day", "motd", MOTDPANEL_TYPE_INDEX);
	}
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

	decl String:message[64];
	BfReadString(bf, message, sizeof(message));

	for (new i = 0; i < sizeof(hintMessages); i++)
	{
		if (StrEqual(message, hintMessages[i]))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/* OnShouldCollide()
 *
 * Enables collision on all players.
 * --------------------------------------------------------------------- */
public bool:OnShouldCollide(client, collisionGroup, contentsMask, bool:originalResult)
{
	return true;
}

/* Hook_TeamNum()
 *
 * Change the m_iTeamNum property on players without changing them on the server.
 * --------------------------------------------------------------------- */
public Action:Hook_TeamNum(client, const String:propName[], &value, element)
{
	// If the player is alive, change the team
	if (IsPlayerAlive(client))
	{
		value = Team_Custom;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}