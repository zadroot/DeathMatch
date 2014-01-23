/**
 * ---------------------------------------------------------------------
 *      __  ____
 *     /  |/  (_)__________
 *    / /|_/ / // ___/ ___/
 *   / /  / / /(__  ) /__
 *  /_/  /_/_//____/\___/
 *
 * ---------------------------------------------------------------------
*/

/* GiveHealth()
 *
 * Gives a player a specified amount of health.
 * --------------------------------------------------------------------- */
GiveHealth(client, amount)
{
	new health = GetClientHealth(client) + amount;

	// If the regen would give the client more than their max hp, just set it to max and disable health regeneration
	if (health > 100)
	{
		health = 100;

		g_bHealthRegen[client] = false;
	}

	// Faster than SetEntityHealth(client, health);
	SetEntData(client, g_iOffset_Health, health, _, true);
}

/* RemoveWeapon()
 *
 * Removes a players weapon.
 * --------------------------------------------------------------------- */
RemoveWeapon(client, weapon)
{
	RemovePlayerItem(client, weapon);
	AcceptEntityInput(weapon, "Kill");
}