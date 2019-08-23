#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo & Wend4r"

#define LogLR(%0) LogError("[" ... PLUGIN_NAME ... " ExWeapons] " ... %0)
#define CrashLR(%0) SetFailState("[" ... PLUGIN_NAME ... " ExWeapons] " ... %0)

int			g_iWeaponsStats[MAXPLAYERS+1][47],
			g_iWeaponsBlocksCount;

bool		g_bWeaponsBlocksAccess[47],
			g_bWeaponsBlocksAccessChat[47],
			g_bWeaponsCoeffActive;

float		g_flWeaponsCoeff[47];

char		g_sTableName[32],
			g_sPluginTitle[64],
			g_sWeaponsBlocksNames[47][64],
			g_sWeaponsBlocksCallCmds[47][64],
			g_sSteamID[MAXPLAYERS+1][32];
Database	g_hDatabase;

// levelsranks_exstats_weapons.sp
public Plugin myinfo = {name = "[LR] Module - ExStats Weapons", author = PLUGIN_AUTHOR, version = "v3.0 SR2"}
public void OnPluginStart()
{
	LoadTranslations("lr_module_exweapons.phrases");
	ConfigLoad();
}

public void LR_OnSettingsModuleUpdate()
{
	ConfigLoad();
}

public void OnAllPluginsLoaded()
{
	ConnectDatabase();
}

public void LR_OnDatabaseLoaded()
{
	ConnectDatabase();
}

void ConnectDatabase()
{
	if(!g_hDatabase)
	{
		g_hDatabase = LR_GetDatabase();
		LR_GetTableName(g_sTableName, 32);

		SQL_LockDatabase(g_hDatabase);

		char sQuery[2048], sQueryFast[256];

		FormatEx(sQuery, 2048, "CREATE TABLE IF NOT EXISTS `%s_weapons` (`steam` varchar(32) NOT NULL default '' PRIMARY KEY, `name` varchar(128) NOT NULL default '', `lastconnect` NUMERIC, `weapon_knife` NUMERIC, `weapon_taser` NUMERIC, `weapon_inferno` NUMERIC, `weapon_hegrenade` NUMERIC, `weapon_glock` NUMERIC, `weapon_hkp2000` NUMERIC, `weapon_tec9` NUMERIC, `weapon_usp_silencer` NUMERIC, `weapon_p250` NUMERIC, `weapon_cz75a` NUMERIC, `weapon_fiveseven` NUMERIC, `weapon_elite` NUMERIC, `weapon_revolver` NUMERIC, `weapon_deagle` NUMERIC, `weapon_negev` NUMERIC, `weapon_m249` NUMERIC, `weapon_mag7` NUMERIC, `weapon_sawedoff` NUMERIC, `weapon_nova` NUMERIC, `weapon_xm1014` NUMERIC, `weapon_bizon` NUMERIC, `weapon_mac10` NUMERIC, `weapon_ump45` NUMERIC, `weapon_mp9` NUMERIC, `weapon_mp7` NUMERIC, `weapon_p90` NUMERIC, `weapon_galilar` NUMERIC, `weapon_famas` NUMERIC, `weapon_ak47` NUMERIC, `weapon_m4a1` NUMERIC, `weapon_m4a1_silencer` NUMERIC, `weapon_aug` NUMERIC, `weapon_sg556` NUMERIC, `weapon_ssg08` NUMERIC, `weapon_awp` NUMERIC, `weapon_scar20` NUMERIC, `weapon_g3sg1` NUMERIC, `weapon_usp` NUMERIC, `weapon_p228` NUMERIC, `weapon_m3` NUMERIC, `weapon_tmp` NUMERIC, `weapon_mp5navy` NUMERIC, `weapon_galil` NUMERIC, `weapon_scout` NUMERIC, `weapon_sg550` NUMERIC, `weapon_sg552` NUMERIC, `weapon_mp5sd` NUMERIC)%s", g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET=utf8 COLLATE utf8_general_ci");

		if(!SQL_FastQuery(g_hDatabase, sQuery)) 
		{
			CrashLR("LR_OnDatabaseLoaded - could not create table");
		}

		FormatEx(sQueryFast, 256, "ALTER TABLE `%s_weapons` ADD COLUMN `lastconnect` NUMERIC default %d AFTER `name`;", g_sTableName, GetTime());
		SQL_FastQuery(g_hDatabase, sQueryFast);
		SQL_UnlockDatabase(g_hDatabase);

		g_hDatabase.SetCharset("utf8");

		char sSteamID[32];

		for(int i = 1; i != MaxClients; i++)
		{
			if(LR_GetClientStatus(i))
			{
				GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
				LR_OnPlayerLoaded(i, sSteamID);
			}
		}
	}
}

void ConfigLoad()
{
	char sPath[256];

	g_iWeaponsBlocksCount = 0;

	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/exstats_weapons.ini");
	KeyValues hLR_ExWeapons = new KeyValues("LR_ExStats_Weapons");

	if(!hLR_ExWeapons.ImportFromFile(sPath))
	{
		SetFailState("[%s ExWeapons] file is not found (%s)", PLUGIN_NAME, sPath);
	}

	hLR_ExWeapons.GotoFirstSubKey();

	hLR_ExWeapons.Rewind();

	if(hLR_ExWeapons.JumpToKey("WeaponsList"))
	{
		g_bWeaponsCoeffActive = view_as<bool>(hLR_ExWeapons.GetNum("weapon_coefficient", 1));

		hLR_ExWeapons.GotoFirstSubKey();
		do
		{
			hLR_ExWeapons.GetSectionName(g_sWeaponsBlocksNames[g_iWeaponsBlocksCount], 192);

			g_bWeaponsBlocksAccess[g_iWeaponsBlocksCount] = hLR_ExWeapons.GetNum("showtop", 0) == 0;
			g_bWeaponsBlocksAccessChat[g_iWeaponsBlocksCount] = hLR_ExWeapons.GetNum("chatcalloff", 0) == 0;
			hLR_ExWeapons.GetString("chatcall", g_sWeaponsBlocksCallCmds[g_iWeaponsBlocksCount], 64, "topknife");
			g_flWeaponsCoeff[g_iWeaponsBlocksCount++] = hLR_ExWeapons.GetFloat("coefficient", 1.0);
		}
		while(hLR_ExWeapons.GotoNextKey() && g_iWeaponsBlocksCount < 47);
	}
	else 
	{
		SetFailState("[" ... PLUGIN_NAME ... " ExWeapons] section WeaponsList is not found (%s)", sPath);
	}

	delete hLR_ExWeapons;
}

public void LR_OnPlayerKilled(Event hEvent, int& iExpGive)
{
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	char sBuffer[48], sClassname[64];

	static const char sWeaponClassname[][] = {"weapon_knife", "weapon_taser", "weapon_inferno", "weapon_hegrenade", "weapon_glock", "weapon_hkp2000", "weapon_tec9", "weapon_usp_silencer", "weapon_p250", "weapon_cz75a", "weapon_fiveseven", "weapon_elite", "weapon_revolver", "weapon_deagle", "weapon_negev", "weapon_m249", "weapon_mag7", "weapon_sawedoff", "weapon_nova", "weapon_xm1014", "weapon_bizon", "weapon_mac10", "weapon_ump45", "weapon_mp9", "weapon_mp7", "weapon_p90", "weapon_galilar", "weapon_famas", "weapon_ak47", "weapon_m4a1", "weapon_m4a1_silencer", "weapon_aug", "weapon_sg556", "weapon_ssg08", "weapon_awp", "weapon_scar20", "weapon_g3sg1", "weapon_usp", "weapon_p228", "weapon_m3", "weapon_tmp", "weapon_mp5navy", "weapon_galil", "weapon_scout", "weapon_sg550", "weapon_sg552", "weapon_mp5sd"};

	GetEventString(hEvent, "weapon", sBuffer, 64);
	FormatEx(sClassname, 64, "weapon_%s", sBuffer);

	if(sBuffer[0] == 'k' || sBuffer[2] == 'y')
	{
		sClassname = "weapon_knife";
	}

	// Get WeaponID
	for(int i = 0; i != 47; i++)
	{
		if(!strcmp(sClassname, sWeaponClassname[i]))
		{
			if(g_bWeaponsCoeffActive)
			{
				iExpGive = RoundToNearest(iExpGive * g_flWeaponsCoeff[i]);
			}

			g_iWeaponsStats[iAttacker][i]++;
			return;
		}
	}
}

public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(!strcmp(sArgs, "topkills", false) || !strcmp(sArgs, "!topkills", false))
	{
		TOPGeneral(iClient);
	}

	if(!strcmp(sArgs, "topweapons", false) || !strcmp(sArgs, "!topweapons", false))
	{
		TOPGeneralWeapon(iClient);
	}

	for(int i = 0; i != g_iWeaponsBlocksCount; i++)
	{
		if(g_bWeaponsBlocksAccess[i] && g_bWeaponsBlocksAccessChat[i])
		{
			if(!strcmp(sArgs, g_sWeaponsBlocksCallCmds[i], false))
			{
				PrintTopWeapons(iClient, i, g_sWeaponsBlocksNames[i]);
				break;
			}
		}
	}

	return Plugin_Continue;
}

public void LR_OnMenuCreatedTop(int iClient, Menu& hMenu)
{
	static char sText[64];

	FormatEx(sText, sizeof(sText), "%T", "TOPGeneral", iClient);
	hMenu.AddItem("topgeneral", sText);
}

public void LR_OnMenuItemSelectedTop(int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "topgeneral"))
	{
		TOPGeneral(iClient);
		LR_GetTitleMenu(g_sPluginTitle, 64);
	}
}

void TOPGeneral(int iClient)
{
	static char sText[128];

	Menu hMenu = new Menu(TOPGeneralHandler);

	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "TOPGeneral", iClient);

	FormatEx(sText, sizeof(sText), "%T", "TOPGeneralCount", iClient);
	hMenu.AddItem("0", sText);

	FormatEx(sText, sizeof(sText), "%T", "TOPGeneralWeapon", iClient);
	hMenu.AddItem("1", sText);

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TOPGeneralHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) {LR_MenuTopMenu(iClient);}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0: TOPGeneralCount(iClient);
				case 1: TOPGeneralWeapon(iClient);
			}
		}
	}
}

void TOPGeneralCount(int iClient)
{
	if(LR_GetClientStatus(iClient))
	{
		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "SELECT `name`, `kills` FROM `%s` WHERE `lastconnect` > 0 ORDER BY `kills` DESC LIMIT 10 OFFSET 0", g_sTableName);

		g_hDatabase.Query(SQL_TOPGeneralCount, sQuery, iClient);
	}
}

public void SQL_TOPGeneralCount(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs)
	{
		LogLR("SQL_TOPGeneralCount - error while working with data (%s)", sError);
		return;
	}

	int i;
	char sText[256], sName[24], sTemp[640];

	while(dbRs.HasResults && dbRs.FetchRow())
	{
		i++;
		dbRs.FetchString(0, sName, sizeof(sName));
		FormatEx(sText, sizeof(sText), "%T\n", "TOPList", iClient, i, dbRs.FetchInt(1), sName);
		
		if(strlen(sTemp) + strlen(sText) < 640)
		{
			Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText);
			sText = "\0";
		}
	}

	Menu hMenu = new Menu(TOPGeneralCountHandler);
	hMenu.SetTitle("%s | %T\n \n%s\n ", g_sPluginTitle, "TOPGeneralCount", iClient, sTemp);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem("", sText);

	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TOPGeneralCountHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: TOPGeneral(iClient);
	}
}

void TOPGeneralWeapon(int iClient)
{
	static char sBuffer[6], sText[192];

	Menu hMenu = new Menu(TOPGeneralWeaponHandler);

	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "TOPGeneralWeapon", iClient);

	for(int i = 0; i != g_iWeaponsBlocksCount; i++)
	{
		if(g_bWeaponsBlocksAccess[i])
		{
			FormatEx(sText, sizeof(sText), "%T", g_sWeaponsBlocksNames[i], iClient);
			FormatEx(sBuffer, sizeof(sBuffer), "%i", i);

			hMenu.AddItem(sBuffer, sText);
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int TOPGeneralWeaponHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) TOPGeneral(iClient);
		case MenuAction_Select:
		{
			char sInfo[6];

			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			int iWeaponId = StringToInt(sInfo);

			PrintTopWeapons(iClient, iWeaponId, g_sWeaponsBlocksNames[iWeaponId]);
		}
	}
}

void PrintTopWeapons(int iClient, int iWeaponId, char sWeaponClassname[64])
{
	if(LR_GetClientStatus(iClient))
	{
		static char sQuery[512];

		FormatEx(sQuery, sizeof(sQuery), "SELECT `name`, `%s` FROM `%s_weapons` WHERE `lastconnect` > 0 ORDER BY `%s` DESC LIMIT 10 OFFSET 0", sWeaponClassname, g_sTableName, sWeaponClassname);

		g_hDatabase.Query(SQL_PrintTopWeapons, sQuery, iClient << 8 | iWeaponId);
	}
}

public void SQL_PrintTopWeapons(Database db, DBResultSet dbRs, const char[] sError, int iData)
{
	if(!dbRs)
	{
		LogLR("SQL_PrintTopWeapons - error while working with data (%s)", sError);
		return;
	}

	int i;
	char sText[256], sName[24], sTemp[640];

	int iClient = iData >> 8;
	int iWeaponId = iData & 0xFF;

	while(dbRs.HasResults && dbRs.FetchRow())
	{
		dbRs.FetchString(0, sName, sizeof(sName));
		FormatEx(sText, sizeof(sText), "%T\n", "TOPList", iClient, ++i, dbRs.FetchInt(1), sName);
		
		if(strlen(sTemp) + strlen(sText) < 640)
		{
			Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText);
			sText = "\0";
		}
	}

	Menu hMenu = new Menu(PrintTopWeaponsHandler);

	hMenu.SetTitle("%s | %T\n \n%s\n ", g_sPluginTitle, g_sWeaponsBlocksNames[iWeaponId], iClient, sTemp);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem("", sText);

	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int PrintTopWeaponsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: TOPGeneralWeapon(iClient);
	}
}

void CreateDataPlayer(int iClient)
{
	if(!g_hDatabase)
	{
		LogLR("CreateDataPlayer - database is invalid");
		return;
	}

	if(LR_GetClientStatus(iClient))
	{
		static char sQuery[512], sSaveName[MAX_NAME_LENGTH * 2 + 1];

		g_hDatabase.Escape(GetFixNamePlayer(iClient), sSaveName, sizeof(sSaveName));
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `%s_weapons` (`steam`, `name`, `lastconnect`) VALUES ('%s', '%s', %d);", g_sTableName, g_sSteamID[iClient], sSaveName, GetTime());
		g_hDatabase.Query(CreateDataPlayer_Callback, sQuery, iClient);
	}
}

public void CreateDataPlayer_Callback(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs)
	{
		LogLR("CreateDataPlayer - %s", sError);
		return;
	}

	for(int i = 0; i != 47;)
	{
		g_iWeaponsStats[iClient][i++] = 0;
	}
}

public void LR_OnPlayerLoaded(int iClient, const char[] sSteamID)
{
	strcopy(g_sSteamID[iClient], 32, sSteamID);
	
	if(!g_hDatabase)
	{
		LogLR("LoadDataPlayer - database is invalid");
		return;
	}

	static char sQuery[1024];

	FormatEx(sQuery, sizeof(sQuery), "SELECT `weapon_knife`, `weapon_taser`, `weapon_inferno`, `weapon_hegrenade`, `weapon_glock`, `weapon_hkp2000`, `weapon_tec9`, `weapon_usp_silencer`, `weapon_p250`, `weapon_cz75a`, `weapon_fiveseven`, `weapon_elite`, `weapon_revolver`, `weapon_deagle`, `weapon_negev`, `weapon_m249`, `weapon_mag7`, `weapon_sawedoff`, `weapon_nova`, `weapon_xm1014`, `weapon_bizon`, `weapon_mac10`, `weapon_ump45`, `weapon_mp9`, `weapon_mp7`, `weapon_p90`, `weapon_galilar`, `weapon_famas`, `weapon_ak47`, `weapon_m4a1`, `weapon_m4a1_silencer`, `weapon_aug`, `weapon_sg556`, `weapon_ssg08`, `weapon_awp`, `weapon_scar20`, `weapon_g3sg1`, `weapon_usp`, `weapon_p228`, `weapon_m3`, `weapon_tmp`, `weapon_mp5navy`, `weapon_galil`, `weapon_scout`, `weapon_sg550`, `weapon_sg552`, `weapon_mp5sd` FROM `%s_weapons` WHERE `steam` = '%s';", g_sTableName, sSteamID);
	g_hDatabase.Query(LoadDataPlayer_Callback, sQuery, iClient);
}

public void LoadDataPlayer_Callback(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs)
	{
		LogLR("LoadDataPlayer - %s", sError);
		return;
	}

	if(dbRs.HasResults && dbRs.FetchRow())
	{
		for(int i = 0; i != 47;)
		{
			g_iWeaponsStats[iClient][i] = dbRs.FetchInt(i++);
		}
	}
	else 
	{
		CreateDataPlayer(iClient);
	}
}

public void LR_OnPlayerSaved(int iClient, Transaction& hQuery)
{
	static char sQuery[2048], sSaveName[MAX_NAME_LENGTH * 2 + 1];

	g_hDatabase.Escape(GetFixNamePlayer(iClient), sSaveName, sizeof(sSaveName));
	FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s_weapons` SET `name` = '%s', `lastconnect` = %d, `weapon_knife` = %d, `weapon_taser` = %d, `weapon_inferno` = %d, `weapon_hegrenade` = %d, `weapon_glock` = %d, `weapon_hkp2000` = %d, `weapon_tec9` = %d, `weapon_usp_silencer` = %d, `weapon_p250` = %d, `weapon_cz75a` = %d, `weapon_fiveseven` = %d, `weapon_elite` = %d, `weapon_revolver` = %d, `weapon_deagle` = %d, `weapon_negev` = %d, `weapon_m249` = %d, `weapon_mag7` = %d, `weapon_sawedoff` = %d, `weapon_nova` = %d, `weapon_xm1014` = %d, `weapon_bizon` = %d, `weapon_mac10` = %d, `weapon_ump45` = %d, `weapon_mp9` = %d, `weapon_mp7` = %d, `weapon_p90` = %d, `weapon_galilar` = %d, `weapon_famas` = %d, `weapon_ak47` = %d, `weapon_m4a1` = %d, `weapon_m4a1_silencer` = %d, `weapon_aug` = %d, `weapon_sg556` = %d, `weapon_ssg08` = %d, `weapon_awp` = %d, `weapon_scar20` = %d, `weapon_g3sg1` = %d, `weapon_usp` = %d, `weapon_p228` = %d, `weapon_m3` = %d, `weapon_tmp` = %d, `weapon_mp5navy` = %d, `weapon_galil` = %d, `weapon_scout` = %d, `weapon_sg550` = %d, `weapon_sg552` = %d, `weapon_mp5sd` = %d WHERE `steam` = '%s';", g_sTableName, sSaveName, GetTime(), g_iWeaponsStats[iClient][0], g_iWeaponsStats[iClient][1], g_iWeaponsStats[iClient][2], g_iWeaponsStats[iClient][3], g_iWeaponsStats[iClient][4], g_iWeaponsStats[iClient][5], g_iWeaponsStats[iClient][6], g_iWeaponsStats[iClient][7], g_iWeaponsStats[iClient][8], g_iWeaponsStats[iClient][9], g_iWeaponsStats[iClient][10], g_iWeaponsStats[iClient][11], g_iWeaponsStats[iClient][12], g_iWeaponsStats[iClient][13], g_iWeaponsStats[iClient][14], g_iWeaponsStats[iClient][15], g_iWeaponsStats[iClient][16], g_iWeaponsStats[iClient][17], g_iWeaponsStats[iClient][18], g_iWeaponsStats[iClient][19], g_iWeaponsStats[iClient][20], g_iWeaponsStats[iClient][21], g_iWeaponsStats[iClient][22], g_iWeaponsStats[iClient][23], g_iWeaponsStats[iClient][24], g_iWeaponsStats[iClient][25], g_iWeaponsStats[iClient][26], g_iWeaponsStats[iClient][27], g_iWeaponsStats[iClient][28], g_iWeaponsStats[iClient][29], g_iWeaponsStats[iClient][30], g_iWeaponsStats[iClient][31], g_iWeaponsStats[iClient][32], g_iWeaponsStats[iClient][33], g_iWeaponsStats[iClient][34], g_iWeaponsStats[iClient][35], g_iWeaponsStats[iClient][36], g_iWeaponsStats[iClient][37], g_iWeaponsStats[iClient][38], g_iWeaponsStats[iClient][39], g_iWeaponsStats[iClient][40], g_iWeaponsStats[iClient][41], g_iWeaponsStats[iClient][42], g_iWeaponsStats[iClient][43], g_iWeaponsStats[iClient][44], g_iWeaponsStats[iClient][45], g_iWeaponsStats[iClient][46], g_sSteamID[iClient]);

	hQuery.AddQuery(sQuery);
}

char[] GetFixNamePlayer(int iClient)
{
	static char sName[MAX_NAME_LENGTH * 2 + 1];

	GetClientName(iClient, sName, sizeof(sName));

	for(int i = 0, len = strlen(sName), CharBytes; i < len;)
	{
		if((CharBytes = GetCharBytes(sName[i])) >= 4)
		{
			len -= CharBytes;

			for(int u = i; u <= len; u++)
			{
				sName[u] = sName[u + CharBytes];
			}
		}
		else i += CharBytes;
	}
	return sName;
}