
#pragma semicolon 1

#include <sourcemod>

#if SOURCEMOD_V_MINOR < 10
	#error This plugin can only compile on SourceMod 1.10.
#endif

#pragma newdecls required

#include <lvl_ranks>

#define SQL_CreatePlayer "INSERT INTO `%s_hits` (`SteamID`) VALUES ('STEAM_%i:%i:%i');"

#define SQL_LoadPlayer \
"SELECT \
	`DmgHealth`, \
	`DmgArmor`, \
	`Head`, \
	`Chest`, \
	`Belly`, \
	`LeftArm`, \
	`RightArm`, \
	`LeftLeg`, \
	`RightLeg`, \
	`Neak` \
FROM \
	`%s_hits` \
WHERE \
	`SteamID` = 'STEAM_%i:%i:%i';"

#define SQL_SavePlayer \
"UPDATE `%s_hits` SET \
	`DmgHealth` = %d, \
	`DmgArmor` = %d, \
	%s \
WHERE \
	`SteamID` = 'STEAM_%i:%i:%i';"

#define SQL_UpdateResetData \
"UPDATE `%s_hits` SET \
	`DmgHealth` = 0, \
	`DmgArmor` = 0, \
	`Head` = 0, \
	`Chest` = 0, \
	`Belly` = 0, \
	`LeftArm` = 0, \
	`RightArm` = 0, \
	`LeftLeg` = 0, \
	`RightLeg` = 0, \
	`Neak` = 0 \
WHERE \
	`SteamID` = 'STEAM_%i:%i:%i';"

#define HitData 11

#define HD_None -1
#define HD_DmgHealth 0
#define HD_DmgArmor 1
#define HD_HitHead 2
#define HD_HitChest 3
#define HD_HitBelly 4
#define HD_HitLeftArm 5
#define HD_HitRightArm 6
#define HD_HitLeftLeg 7
#define HD_HitRightLeg 8
#define HD_HitNeak 9
#define HD_HitAll 10

int 		g_iHits[MAXPLAYERS+1][HitData],
			g_iHitFlags[MAXPLAYERS+1],
			g_iAccountID[MAXPLAYERS+1];

char		g_sTableName[32],
			g_sMenuTitle[64];

static const char g_sSQL_CreateTable[] = \
"CREATE TABLE IF NOT EXISTS `%s_hits` \
(\
	`SteamID` varchar(32) NOT NULL PRIMARY KEY DEFAULT '', \
	`DmgHealth` int NOT NULL DEFAULT 0, \
	`DmgArmor` int NOT NULL DEFAULT 0, \
	`Head` int NOT NULL DEFAULT 0, \
	`Chest` int NOT NULL DEFAULT 0, \
	`Belly` int NOT NULL DEFAULT 0, \
	`LeftArm` int NOT NULL DEFAULT 0, \
	`RightArm` int NOT NULL DEFAULT 0, \
	`LeftLeg` int NOT NULL DEFAULT 0, \
	`RightLeg` int NOT NULL DEFAULT 0, \
	`Neak` int NOT NULL DEFAULT 0\
)%s";

Database	g_hDatabase;

EngineVersion g_iEngine;

// levelsranks_exstats_hits.sp
public Plugin myinfo =
{
	name = "[LR] Module - ExStats Hits", 
	author = "Wend4r", 
	version = PLUGIN_VERSION,
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
	LoadTranslations("core.phrases");
	LoadTranslations((g_iEngine = GetEngineVersion()) == Engine_SourceSDK2006 ? "lr_core_old.phrases" : "lr_core.phrases");
	LoadTranslations("lr_module_exhits.phrases");

	HookEvent("player_hurt", view_as<EventHook>(OnPlayerHurt));

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	LoadSettings();

	LR_Hook(LR_OnSettingsModuleUpdate, LoadSettings);
	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnPlayerSaved, SaveDataPlayer);
	LR_Hook(LR_OnResetPlayerStats, OnResetPlayerStats);
	LR_Hook(LR_OnDatabaseCleanup, OnDatabaseCleanup);

	LR_MenuHook(LR_MyStatsSecondary, OnCreatedMenu, OnSelectMenu);

	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	char sQuery[512];

	FormatEx(sQuery, sizeof(sQuery), g_sSQL_CreateTable, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");
	(g_hDatabase = LR_GetDatabase()).Query(SQL_Callback, sQuery, -1, DBPrio_High);
}

void LoadSettings()
{
	LR_GetTitleMenu(g_sMenuTitle, sizeof(g_sMenuTitle));
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	static char sQuery[256];

	g_iAccountID[iClient] = iAccountID;

	FormatEx(sQuery, sizeof(sQuery), SQL_LoadPlayer, g_sTableName, g_iEngine == Engine_CSGO, iAccountID & 1, iAccountID >>> 1);
	g_hDatabase.Query(SQL_Callback, sQuery, GetClientUserId(iClient));
}

void OnPlayerHurt(Event hEvent)
{
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if(iAttacker && LR_CheckCountPlayers())
	{
		g_iHits[iAttacker][HD_DmgHealth] += hEvent.GetInt("dmg_health");
		g_iHits[iAttacker][HD_DmgArmor] += hEvent.GetInt("dmg_armor");

		int iHB = hEvent.GetInt("hitgroup") + 1;

		if(1 < iHB < 11)
		{
			g_iHits[iAttacker][iHB]++;
			g_iHits[iAttacker][HD_HitAll]++;
			g_iHitFlags[iAttacker] |= (1 << iHB);
		}
	}
}

void OnCreatedMenu(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	static char sText[64];

	FormatEx(sText, sizeof(sText), "%T", "HitsPlayer", iClient);
	hMenu.AddItem("hits_stats", sText);

	FormatEx(sText, sizeof(sText), "%T", "DmgPlayer", iClient);
	hMenu.AddItem("dmg_stats", sText);
}

void OnSelectMenu(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "hits_stats"))
	{
		MenuShowInfo(iClient, true);
	}
	else if(!strcmp(sInfo, "dmg_stats"))
	{
		MenuShowInfo(iClient, false);
	}
}

void MenuShowInfo(int iClient, bool bIsHits)
{
	int iAll = g_iHits[iClient][HD_HitAll];

	char sText[256];

	Menu hMenu = new Menu(MenuShowInfo_Callback);

	if(iAll)
	{
		if(bIsHits)
		{
			int	iHead = g_iHits[iClient][HD_HitHead],
				iChest = g_iHits[iClient][HD_HitChest],
				iBelly = g_iHits[iClient][HD_HitBelly],
				iLeftArm = g_iHits[iClient][HD_HitLeftArm],
				iRightArm = g_iHits[iClient][HD_HitRightArm],
				iLeftLeg = g_iHits[iClient][HD_HitLeftLeg],
				iRightLeg = g_iHits[iClient][HD_HitRightLeg];

			hMenu.SetTitle("%s | %T\n ", g_sMenuTitle, "HitsPlayer_Title", iClient, iAll, iHead, RoundToCeil(100.0 * iHead / iAll), iChest, RoundToCeil(100.0 * iChest / iAll), iBelly, RoundToCeil(100.0 * iBelly / iAll), iLeftArm, RoundToCeil(100.0 * iLeftArm / iAll), iRightArm, RoundToCeil(100.0 * iRightArm / iAll), iLeftLeg, RoundToCeil(100.0 * iLeftLeg / iAll), iRightLeg, RoundToCeil(100.0 * iRightLeg / iAll));
		}
		else
		{
			int iHealth = g_iHits[iClient][HD_DmgHealth],
				iArmor = g_iHits[iClient][HD_DmgArmor];

			iAll = iHealth + iArmor;

			hMenu.SetTitle("%s | %T\n ", g_sMenuTitle, "DmgPlayer_Title", iClient, iHealth, RoundToCeil(100.0 * iHealth / iAll), iArmor, RoundToCeil(100.0 * iArmor / iAll), float(iHealth) / g_iHits[iClient][HD_HitAll]);
		}

	}
	else
	{
		hMenu.SetTitle("%s | %T\n \n%T\n ", g_sMenuTitle, bIsHits ? "HitsPlayer" : "DmgPlayer", iClient, "NoData", iClient);
	}

	FormatEx(sText, sizeof(sText), "%T\n", "Back", iClient);
	hMenu.AddItem("Back", sText);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
	hMenu.ExitButton = true;
}

int MenuShowInfo_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	if(mAction == MenuAction_Select)
	{
		LR_ShowMenu(iClient, LR_MyStatsSecondary);
	}
	else if(mAction == MenuAction_End)
	{
		hMenu.Close();
	}
}

void SaveDataPlayer(int iClient, Transaction hTransaction)
{
	int iFlags = g_iHitFlags[iClient];

	if(iFlags)
	{
		static const char sHitColumnName[][] = {"Head", "Chest", "Belly", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Neak"};

		char sQuery[256],
			 sColumns[128];

		for(int Type = HD_HitHead; Type != HitData; Type++)
		{
			if(iFlags & (1 << Type))
			{
				FormatEx(sColumns, sizeof(sColumns), "%s`%s` = %d, ", sColumns, sHitColumnName[Type - 2], g_iHits[iClient][Type]);
			}
		}

		sColumns[strlen(sColumns) - 2] = '\0';
		FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, g_sTableName, g_iHits[iClient][HD_DmgHealth], g_iHits[iClient][HD_DmgArmor], sColumns, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1);
		hTransaction.AddQuery(sQuery);

		g_iHitFlags[iClient] = 0;
	}
}

void OnResetPlayerStats(int iClient, int iAccountID)
{
	if(iClient)
	{
		for(int i = 0; i != HitData;)
		{
			g_iHits[iClient][i++] = 0;
		}
	}

	static char sQuery[256];

	FormatEx(sQuery, sizeof(sQuery), SQL_UpdateResetData, g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1);
	g_hDatabase.Query(SQL_Callback, sQuery, -2);
}

void OnDatabaseCleanup(LR_CleanupType CleanupType, Transaction hTransaction)
{
	static char sQuery[512];

	if(CleanupType == LR_AllData || CleanupType == LR_StatsData)
	{
		FormatEx(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS `%s_hits`;", g_sTableName);
		hTransaction.AddQuery(sQuery);

		FormatEx(sQuery, sizeof(sQuery), g_sSQL_CreateTable, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");
		hTransaction.AddQuery(sQuery);
	}
}

public void SQL_Callback(Database db, DBResultSet dbRs, const char[] sError, int iIndex)
{
	if(!dbRs)
	{
		LogError("SQL_Callback: error when sending the request (%d) - %s", iIndex, sError);
	}

	if(iIndex == -1)
	{
		g_hDatabase.SetCharset("utf8");

		g_iEngine = GetEngineVersion();

		for(int i = MaxClients + 1; --i;)
		{
			if(LR_GetClientStatus(i))
			{
				LoadDataPlayer(i, GetSteamAccountID(i));
			}
		}
	}
	else if(iIndex > 0)
	{
		int iClient = GetClientOfUserId(iIndex);

		if(iClient)
		{
			bool bLoadData = true;

			if(!(dbRs.HasResults && dbRs.FetchRow()))
			{
				static char sQuery[128];

				FormatEx(sQuery, sizeof(sQuery), SQL_CreatePlayer, g_sTableName, g_iEngine == Engine_CSGO, g_iAccountID[iClient] & 1, g_iAccountID[iClient] >>> 1);
				g_hDatabase.Query(SQL_Callback, sQuery);

				bLoadData = false;
			}

			for(int i = g_iHits[iClient][HD_HitAll] = 0; i != HD_HitAll; i++)
			{
				g_iHits[iClient][i] = bLoadData ? dbRs.FetchInt(i) : 0;

				if(i > 1)
				{
					g_iHits[iClient][HD_HitAll] += g_iHits[iClient][i];
				}
			}
		}
	}
}