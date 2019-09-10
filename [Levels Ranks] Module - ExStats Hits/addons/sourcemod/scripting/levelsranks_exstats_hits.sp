
#include <sourcemod>
#include <lvl_ranks>

#pragma semicolon 1
#pragma newdecls required

#define Crash(%0) SetFailState("[" ... " ExHits] " ... %0)

#define SQL_CreateTable \
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
)%s"

#define SQL_CreatePlayer "INSERT INTO `%s_hits` (`SteamID`) VALUES ('%s');"

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
FROM `%s_hits` WHERE `SteamID` = '%s';"

#define SQL_SavePlayer \
"UPDATE `%s_hits` SET \
	`DmgHealth` = %d, \
    `DmgArmor` = %d, \
	%s \
WHERE `SteamID` = '%s';"

enum HitData
{
	HD_None = -1,
	HD_DmgHealth = 0,
	HD_DmgArmor,
	HD_HitHead,
	HD_HitChest,
	HD_HitBelly,
	HD_HitLeftArm,
	HD_HitRightArm,
	HD_HitLeftLeg,
	HD_HitRightLeg,
	HD_HitNeak,
	HD_HitAll
};

int 		g_iHits[MAXPLAYERS+1][HitData],
			g_iHitFlags[MAXPLAYERS+1],
			g_iMaxClients;

char		g_sTableName[32],
			g_sMenuTitle[64],
			g_sSteamID[MAXPLAYERS+1][32];

ArrayList   g_hCommands[2];
Database	g_hDatabase;

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
	LoadTranslations("lr_module_exhits.phrases");
	LoadTranslations("lr_core.phrases");

	LoadSettings();

	HookEvent("player_hurt", view_as<EventHook>(OnPlayerHurt));

	g_iMaxClients = GetMaxHumanPlayers()+1;
}

public void OnAllPluginsLoaded()
{
	ConnectDatabase();
}

public void LR_OnCoreIsReady()
{
	ConnectDatabase();
}

void ConnectDatabase()
{
	g_hDatabase = LR_GetDatabase();
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	// CreateTable
	SQL_LockDatabase(g_hDatabase);

	char sQuery[512];

	FormatEx(sQuery, sizeof(sQuery), SQL_CreateTable, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");

	g_hDatabase.Query(SQL_Callback, sQuery, -1);

	SQL_UnlockDatabase(g_hDatabase);
	g_hDatabase.SetCharset("utf8");

	char sSteamID[32];

	for(int i = 1; i != g_iMaxClients; i++)
	{
		if(LR_GetClientStatus(i))
		{
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
			LR_OnPlayerLoaded(i, sSteamID);
		}
	}
}

void LoadSettings()
{
	static char sPath[PLATFORM_MAX_PATH], sBuffer[2048];
	static KeyValues hKv;

	if(hKv)
	{
		delete g_hCommands[0];
		delete g_hCommands[1];
	}
	else
	{
		hKv = new KeyValues("LR_ExStats_Hits");
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/exstats_hits.ini");
	}

	g_hCommands[0] = new ArrayList(64);
	g_hCommands[1] = new ArrayList(64);

	if(!hKv.ImportFromFile(sPath))
	{
		Crash("LoadSettings: %s - not found or damaged!", sPath);
	}
	hKv.GotoFirstSubKey();

	LR_GetTitleMenu(g_sMenuTitle, sizeof(g_sMenuTitle));

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	hKv.GetString("lr_hits_commands", sBuffer, sizeof(sBuffer), "!hits");
	ExplodeInArray(sBuffer, 0);

	hKv.GetString("lr_dmg_commands", sBuffer, sizeof(sBuffer), "!dmg");
	ExplodeInArray(sBuffer, 1);
}

void ExplodeInArray(const char[] sText, int iArray)
{
	int  i = 0,
		 iLastSize = 0;

	for(int iLen = strlen(sText)+1; i != iLen;)
	{
		if(iLen == ++i || sText[i-1] == ';')
		{
			char sBuf[64];

			strcopy(sBuf, i-iLastSize, sText[iLastSize]);
			g_hCommands[iArray].PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		g_hCommands[iArray].PushString(sText);
	}
}

public void LR_OnPlayerLoaded(int iClient, const char[] sAuth)
{
	static char sQuery[256];

	strcopy(g_sSteamID[iClient], 32, sAuth);

	FormatEx(sQuery, sizeof(sQuery), SQL_LoadPlayer, g_sTableName, sAuth);
	g_hDatabase.Query(SQL_Callback, sQuery, iClient);
}

void OnPlayerHurt(Event hEvent)
{
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if(iAttacker && LR_CheckCountPlayers())
	{
		g_iHits[iAttacker][HD_DmgHealth] += hEvent.GetInt("dmg_health");
		g_iHits[iAttacker][HD_DmgArmor] += hEvent.GetInt("dmg_armor");

		int iHB = hEvent.GetInt("hitgroup")+1;

		if(1 < iHB < 11)
		{
			g_iHits[iAttacker][iHB]++;
			g_iHits[iAttacker][HD_HitAll]++;
			g_iHitFlags[iAttacker] |= (1 << iHB);
		}
	}
}

public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(LR_GetClientStatus(iClient))
	{
		if(g_hCommands[0].FindString(sArgs) != -1)
		{
			MenuShowInfo(iClient, true);
		}
		else if(g_hCommands[1].FindString(sArgs) != -1)
		{
			MenuShowInfo(iClient, false);
		}
	}
}

void MenuShowInfo(int iClient, bool bIsHits)
{
	int iAll = g_iHits[iClient][HD_HitAll];

	char sText[256];

	if(iAll)
	{
		static const char sTrans[][] = {"BackInDmg", "BackInHits", "BackToMainMenu"};

		Menu hMenu = new Menu(MenuShowInfo_Callback);

		if(bIsHits)
		{
			int	iHead = g_iHits[iClient][HD_HitHead],
				iChest = g_iHits[iClient][HD_HitChest],
				iBelly = g_iHits[iClient][HD_HitBelly],
				iLeftArm = g_iHits[iClient][HD_HitLeftArm],
				iRightArm = g_iHits[iClient][HD_HitRightArm],
				iLeftLeg = g_iHits[iClient][HD_HitLeftLeg],
				iRightLeg = g_iHits[iClient][HD_HitRightLeg];

			hMenu.SetTitle("%s | %T\n ", g_sMenuTitle, "HitsPlayer", iClient, iAll, iHead, 100*iHead/iAll, iChest, 100*iChest/iAll, iBelly, 100*iBelly/iAll, iLeftArm, 100*iLeftArm/iAll, iRightArm, 100*iRightArm/iAll, iLeftLeg, 100*iLeftLeg/iAll, iRightLeg, 100*iRightLeg/iAll);
		}
		else
		{
			int iHealth = g_iHits[iClient][HD_DmgHealth],
				iArmor = g_iHits[iClient][HD_DmgArmor];

			iAll = iHealth + iArmor;

			hMenu.SetTitle("%s | %T\n ", g_sMenuTitle, "DmgPlayer", iClient, iHealth, 100*iHealth/iAll, iArmor, 100*iArmor/iAll, float(iHealth) / g_iHits[iClient][HD_HitAll]);
		}

		FormatEx(sText, sizeof(sText), "%T\n", sTrans[!bIsHits], iClient);
		hMenu.AddItem(sTrans[bIsHits], sText);

		FormatEx(sText, sizeof(sText), "%T\n", sTrans[2], iClient);
		hMenu.AddItem(sTrans[2], sText);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
		hMenu.ExitButton = true;

		return;
	}

	LR_PrintToChat(iClient, "%T", "HitsNoData", iClient);
}

int MenuShowInfo_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{	
	switch(mAction)
	{
		case MenuAction_Select:
		{
			char sInfo[8];

			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			if(sInfo[4] == 'I')
			{
				MenuShowInfo(iClient, sInfo[6] != 'H');
				return;
			}

			FakeClientCommand(iClient, "sm_lvl");
		}
	}
}


public void LR_OnPlayerSaved(int iClient)
{
	int iFlags = g_iHitFlags[iClient];

	if(iFlags)
	{
		static const char sHitColumnName[][] = {"Head", "Chest", "Belly", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Neak"};

		char sQuery[256],
			 sColumns[128];

		for(any Type = HD_HitHead; Type != HitData; Type++)
		{
			if(iFlags & (1 << Type))
			{
				FormatEx(sColumns, sizeof(sColumns), "%s`%s` = %d, ", sColumns, sHitColumnName[Type-2], g_iHits[iClient][Type]);
			}
		}

		sColumns[strlen(sColumns)-2] = '\0';
		FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, g_sTableName, g_iHits[iClient][HD_DmgHealth], g_iHits[iClient][HD_DmgArmor], sColumns, g_sSteamID[iClient]);
		g_hDatabase.Query(SQL_Callback, sQuery, -2);

		g_iHitFlags[iClient] = 0;
	}
}

public void SQL_Callback(Database db, DBResultSet dbRs, const char[] sError, int iIndex)
{
	// iIndex:
	// iClient - LR_OnPlayerLoaded
	// -1 - CreateTable
	// -2 - SaveDataPlayer
	// -3 - CreateDataPlayer

	if(!dbRs)
	{
		LogError("SQL_Callback: error when sending the request (%d) - %s", iIndex, sError);
		return;
	}

	if(iIndex > 0)
	{
		bool bLoadData = true;

		if(!(dbRs.HasResults && dbRs.FetchRow()))
		{
			// CreateDataPlayer
			static char sQuery[128];

			FormatEx(sQuery, sizeof(sQuery), SQL_CreatePlayer, g_sTableName, g_sSteamID[iIndex]);
			g_hDatabase.Query(SQL_Callback, sQuery, -3);

			bLoadData = false;
		}

		for(int i = g_iHits[iIndex][HD_HitAll] = 0; i != view_as<int>(HitData)-1; i++)
		{
			g_iHits[iIndex][i] = bLoadData ? dbRs.FetchInt(i) : 0;

			if(i > 1)
			{
				g_iHits[iIndex][HD_HitAll] += g_iHits[iIndex][i];
			}
		}
	}
}