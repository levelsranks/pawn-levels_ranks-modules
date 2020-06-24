#pragma semicolon 1

#include <sourcemod>
#include <sdktools_gamerules>
#include <sdktools_functions>
#include <cstrike>

#if SOURCEMOD_V_MINOR < 10
	#error This plugin can only compile on SourceMod 1.10.
#endif

#pragma newdecls required
#pragma tabsize 4

#include <lvl_ranks>

#define SPPP_COMPILER 1

#if !SPPP_COMPILER
	#define decl static
#endif

#define MAX_UKTYPES 9
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 0)
#define UnusualKill_Penetrated (1 << 1)
#define UnusualKill_NoScope (1 << 2)
#define UnusualKill_Run (1 << 3)
#define UnusualKill_Jump (1 << 4)
#define UnusualKill_Flash (1 << 5)
#define UnusualKill_Smoke (1 << 6)
#define UnusualKill_Whirl (1 << 7)
#define UnusualKill_LastClip (1 << 8)

static const char g_sSQL_CREATE_TABLE[] = \
"CREATE TABLE IF NOT EXISTS `%s_unusualkills` \
(\
	`SteamID` varchar(22) PRIMARY KEY, \
	`OP` int NOT NULL DEFAULT 0, \
	`Penetrated` int NOT NULL DEFAULT 0, \
	`NoScope` int NOT NULL DEFAULT 0, \
	`Run` int NOT NULL DEFAULT 0, \
	`Jump` int NOT NULL DEFAULT 0, \
	`Flash` int NOT NULL DEFAULT 0, \
	`Smoke` int NOT NULL DEFAULT 0, \
	`Whirl` int NOT NULL DEFAULT 0, \
	`LastClip` int NOT NULL DEFAULT 0\
)%s";

#define SQL_CREATE_DATA "INSERT INTO `%s_unusualkills` (`SteamID`) VALUES ('%s');"

#define SQL_LOAD_DATA \
"SELECT \
	`OP`, \
	`Penetrated`, \
	`NoScope`, \
	`Run`, \
	`Jump`, \
	`Flash`, \
	`Smoke`, \
	`Whirl`, \
	`LastClip` \
FROM `%s_unusualkills` WHERE `SteamID` = '%s';"

#define SQL_SAVE_DATA "UPDATE `%s_unusualkills` SET %s WHERE `SteamID` = '%s';"

#define SQL_UPDATE_RESET_DATA \
"UPDATE `%s_unusualkills` SET \
	`OP` = 0, \
	`Penetrated` = 0, \
	`NoScope` = 0, \
	`Run` = 0, \
	`Jump` = 0, \
	`Flash` = 0, \
	`Smoke` = 0, \
	`Whirl` = 0, \
	`LastClip` = 0 \
WHERE \
	`SteamID` = '%s';"

#define SQL_PRINT_TOP \
"SELECT \
	`name`, \
	`%s` \
FROM \
	`%s`, \
	`%s_unusualkills` \
WHERE \
	`steam` = `SteamID` AND \
	`lastconnect` \
ORDER BY \
	`%s` \
DESC LIMIT 10;"

bool              g_bMessages,
                  g_bOPKill,
                  g_bShowItem[MAX_UKTYPES];

int               g_iAccountID[MAXPLAYERS + 1],
                  g_iExp[MAX_UKTYPES],
                  g_iExpMode,
                  g_iWhirlInterval = 2,
                  g_iUK[MAXPLAYERS + 1][MAX_UKTYPES],
                  m_iClip1,
                  m_hActiveWeapon,
                  m_vecVelocity;

float             g_flRotation[MAXPLAYERS + 1],
                  g_flMinLenVelocity = 100.0,
                  g_flWhirl = 200.0;

char              g_sTableName[32],
                  g_sMenuTitle[64];

static const char g_sNameUK[][] = {"OP", "Penetrated", "NoScope", "Run", "Jump", "Flash", "Smoke", "Whirl", "LastClip"};

EngineVersion     g_iEngine;

Database          g_hDatabase;

ArrayList         g_hProhibitedWeapons;

// levelsranks_unusualkills.sp
public Plugin myinfo = 
{
	name = "[LR] Module - Unusual Kills",
	author = "Wend4r",
	version = PLUGIN_VERSION ... " SR2",
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
};

public void OnPluginStart()
{
	LoadTranslations("core.phrases");

	if((g_iEngine = GetEngineVersion()) == Engine_SourceSDK2006)
	{
		LoadTranslations("lr_unusualkills_old.phrases");
		LoadTranslations("lr_core_old.phrases");
	}
	else
	{
		LoadTranslations("lr_unusualkills.phrases");
		LoadTranslations("lr_core.phrases");
	}

	LoadTranslations("lr_unusualkills_menu.phrases");

	m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	m_hActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	m_vecVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	LR_Hook(LR_OnResetPlayerStats, OnResetPlayerStats);
	LR_Hook(LR_OnDatabaseCleanup, OnDatabaseCleanup);

	LR_MenuHook(LR_TopMenu, LR_OnMenuCreated, OnMenuItemSelected);
	LR_MenuHook(LR_MyStatsSecondary, LR_OnMenuCreated, OnMenuItemSelected);

	LoadSettings();

	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);

	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	decl char sQuery[512];

	FormatEx(sQuery, sizeof(sQuery), g_sSQL_CREATE_TABLE, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");
	(g_hDatabase = LR_GetDatabase()).Query(SQL_Callback, sQuery, _, DBPrio_High);
}

void LoadSettings()
{
	static int  iUKSymbolTypes[] = {127, 127, 127, 127, 127, 5, 127, 127, 127, 4, 127, 8, 127, 2, 0, 1, 127, 3, 6, 127, 127, 127, 7};

	static char sPath[PLATFORM_MAX_PATH];

	decl char   sBuffer[512];

	KeyValues hKv = new KeyValues("LR_UnusualKills");

	if(sPath[0])
	{
		g_hProhibitedWeapons.Clear();
	}
	else
	{
		g_hProhibitedWeapons = new ArrayList(64);

		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/UnusualKills.ini");
	}

	if(!hKv.ImportFromFile(sPath))
	{
		SetFailState("%s - not found!", sPath);
	}
	hKv.GotoFirstSubKey();

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	LR_Hook(LR_OnPlayerKilledPre + view_as<LR_HookType>((g_iExpMode = hKv.GetNum("Exp_Mode", 1)) == 1), view_as<LR_HookCB>(OnPlayerKilled));

	g_bMessages = LR_GetSettingsValue(LR_ShowUsualMessage) == 1;

	LR_GetTitleMenu(g_sMenuTitle, sizeof(g_sMenuTitle));

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer), "hegrenade,molotov,incgrenade");
	ExplodeInArrayList(sBuffer, g_hProhibitedWeapons);

	hKv.JumpToKey("TypeKills");	/**/

	hKv.GotoFirstSubKey();
	do
	{
		hKv.GetSectionName(sBuffer, 32);

		int iUKType = iUKSymbolTypes[(sBuffer[0] | 32) - 97];

		switch(iUKType)
		{
			case 127:
			{
				LogError("%s: \"LR_UnusualKills\" -> \"Settings\" -> \"TypeKills\" -> \"%s\" - invalid selection", sPath, sBuffer);
			}

			case 3:
			{
				g_flMinLenVelocity = hKv.GetFloat("minspeed", 100.0);
			}

			case 7:
			{
				g_flWhirl = hKv.GetFloat("whirl", 200.0);
				g_iWhirlInterval = hKv.GetNum("interval", 2);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
		g_bShowItem[iUKType] = hKv.GetNum("menu") != 0;
	}
	while(hKv.GotoNextKey());

	hKv.Close();
}

void ExplodeInArrayList(const char[] sText, ArrayList hArray)
{
	int iLastSize = 0;

	decl char sBuf[64];

	for(int i = 0, iLen = strlen(sText) + 1; i != iLen;)
	{
		if(iLen == ++i || sText[i - 1] == ',')
		{
			strcopy(sBuf, i - iLastSize, sText[iLastSize]);
			hArray.PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		hArray.PushString(sText);
	}
}

void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_bOPKill = false;
}

void OnPlayerKilled(Event hEvent, int& iExpGive)
{
	if(LR_CheckCountPlayers())
	{
		decl char sWeapon[32];

		hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

		if(g_hProhibitedWeapons.FindString(sWeapon) == -1 && sWeapon[0] != 'k' && sWeapon[2] != 'y')
		{
			int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker")),
				iActiveWeapon = GetEntDataEnt2(iAttacker, m_hActiveWeapon),
				iUKFlags = UnusualKill_None;

			decl float vecVelocity[3];

			if(!g_bOPKill)
			{
				iUKFlags |= UnusualKill_OpenFrag;
				g_bOPKill = true;
			}

			if(hEvent.GetBool("penetrated"))
			{
				iUKFlags |= UnusualKill_Penetrated;
			}

			if(hEvent.GetBool("noscope"))
			{
				iUKFlags |= UnusualKill_NoScope;
			}

			GetEntDataVector(iAttacker, m_vecVelocity, vecVelocity);

			if(vecVelocity[2])
			{
				iUKFlags |= UnusualKill_Jump;
				vecVelocity[2] = 0.0;
			}

			if(GetVectorDistance(NULL_VECTOR, vecVelocity) > g_flMinLenVelocity)
			{
				iUKFlags |= UnusualKill_Run;
			}

			if(hEvent.GetBool("attackerblind"))
			{
				iUKFlags |= UnusualKill_Flash;
			}

			if(hEvent.GetBool("thrusmoke"))
			{
				iUKFlags |= UnusualKill_Smoke;
			}

			if((g_flRotation[iAttacker] < 0.0 ? -g_flRotation[iAttacker] : g_flRotation[iAttacker]) > g_flWhirl)
			{
				iUKFlags |= UnusualKill_Whirl;
			}

			if(iActiveWeapon != -1 && GetEntData(iActiveWeapon, m_iClip1) == 1)
			{
				iUKFlags |= UnusualKill_LastClip;
			}

			if(iUKFlags)
			{
				char sBuffer[8],
					 sColumns[MAX_UKTYPES * 18],
					 sQuery[64 + MAX_UKTYPES * 18];

				for(int iType = 0; iType != MAX_UKTYPES; iType++)
				{
					if(iUKFlags & (1 << iType))
					{
						FormatEx(sColumns[strlen(sColumns)], sizeof(sColumns), "`%s` = %d, ", g_sNameUK[iType], ++g_iUK[iAttacker][iType]);

						if(g_iExp[iType])
						{
							if(g_iExpMode == 1)
							{
								if(g_bMessages && LR_ChangeClientValue(iAttacker, g_iExp[iType]))
								{
									FormatEx(sBuffer, sizeof(sBuffer), g_iExp[iType] > 0 ? "+%d" : "%d", g_iExp[iType]);
									LR_PrintToChat(iAttacker, true, "%T", g_sNameUK[iType], iAttacker, LR_GetClientInfo(iAttacker, ST_EXP), sBuffer);
								}
							}
							else
							{
								iExpGive += g_iExp[iType];
							}
						}
					}
				}

				if(sColumns[0])
				{
					sColumns[strlen(sColumns) - 2] = '\0';

					FormatEx(sQuery, sizeof(sQuery), SQL_SAVE_DATA, g_sTableName, sColumns, GetSteamID2(g_iAccountID[iAttacker]));
					g_hDatabase.Query(SQL_Callback, sQuery, -4);
				}
			}
		}
	}
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float flVel[3], const float flAngles[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	static int iInterval[MAXPLAYERS + 1];

	if(IsPlayerAlive(iClient) && (g_flRotation[iClient] += iMouse[0] / 50.0) && iInterval[iClient] - GetTime() < 1)
	{
		g_flRotation[iClient] = 0.0;
		iInterval[iClient] = GetTime() + g_iWhirlInterval;
	}
}

static const char g_sMenuStatsItem[] = "unusualkills_stats",
                  g_sMenuTopItem[] = "unusualkills_top";

void LR_OnMenuCreated(LR_MenuType MenuType, int iClient, Menu hMenu)
{
	decl char sText[64];

	if(MenuType == LR_TopMenu)
	{
		FormatEx(sText, sizeof(sText), "%T", "MenuTop_UnusualKills", iClient);
		hMenu.AddItem(g_sMenuTopItem, sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "MenuItem_MyStatsSecondary", iClient);
		hMenu.AddItem(g_sMenuStatsItem, sText);
	}
}

void OnMenuItemSelected(LR_MenuType MenuType, int iClient, const char[] sInfo)
{
	if(MenuType == LR_TopMenu)
	{
		if(!strcmp(sInfo, g_sMenuTopItem))
		{
			MenuShowTops(iClient);
		}
	}
	else if(!strcmp(sInfo, g_sMenuStatsItem))
	{
		MenuShowInfo(iClient);
	}
}

void MenuShowTops(int iClient, int iSlot = 0)
{
	Menu hMenu = new Menu(MenuShowTops_Callback, MenuAction_Select);

	decl char sText[96], sTrans[32];

	hMenu.SetTitle("%s | %T\n ", g_sMenuTitle, "MenuTop_UnusualKills", iClient);

	for(int i = 0; i != MAX_UKTYPES; i++)
	{
		if(g_bShowItem[i])
		{
			FormatEx(sTrans, sizeof(sTrans), "MenuTop_%s", g_sNameUK[i]);
			FormatEx(sText, sizeof(sText), "%T", sTrans, iClient);

			sTrans[0] = i;
			sTrans[1] = '\0';

			hMenu.AddItem(sTrans, sText);
		}
	}

	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iSlot, MENU_TIME_FOREVER);
}

int MenuShowTops_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_Select:
		{
			decl char sInfo[2], sQuery[512];

			hMenu.GetItem(iSlot, sInfo, sizeof(sInfo));

			FormatEx(sQuery, sizeof(sQuery), SQL_PRINT_TOP, g_sNameUK[sInfo[0]], g_sTableName, g_sTableName, g_sNameUK[sInfo[0]]);
			g_hDatabase.Query(SQL_Callback, sQuery, GetClientUserId(iClient) << 4 | sInfo[0] + 1);
		}

		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				LR_ShowMenu(iClient, LR_TopMenu);
			}
		}

		case MenuAction_End:
		{
			hMenu.Close();
		}
	}
}

void MenuShowInfo(int iClient)
{
	Menu hMenu = new Menu(MenuShowInfo_Callback, MenuAction_Select);

	int iKills = LR_GetClientInfo(iClient, ST_KILLS);

	char sText[768];

	decl char sTrans[48];

	if(!iKills)
	{
		iKills = 1;
	}

	for(int i = 0; i != MAX_UKTYPES; i++)
	{
		if(g_bShowItem[i])
		{
			FormatEx(sTrans, sizeof(sTrans), "MenuItem_%s", g_sNameUK[i]);
			FormatEx(sText, sizeof(sText), "%s%T\n", sText, sTrans, iClient, g_iUK[iClient][i], RoundToCeil(100.0 / iKills * g_iUK[iClient][i]));
		}
	}

	hMenu.SetTitle("%s | %T\n \n%s\n ", g_sMenuTitle, "UnusualKills", iClient, sText);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
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

void LoadDataPlayer(int iClient, int iAccountID)
{
	decl char sQuery[256];

	FormatEx(sQuery, sizeof(sQuery), SQL_LOAD_DATA, g_sTableName, GetSteamID2(g_iAccountID[iClient] = iAccountID));
	g_hDatabase.Query(SQL_Callback, sQuery, GetClientUserId(iClient) << 4);
}

void OnResetPlayerStats(int iClient, int iAccountID)
{
	decl char sQuery[384];

	if(iClient)
	{
		for(int i = 0; i != MAX_UKTYPES;)
		{
			g_iUK[iClient][i++] = 0;
		}
	}

	FormatEx(sQuery, sizeof(sQuery), SQL_UPDATE_RESET_DATA, g_sTableName, GetSteamID2(iAccountID));
	g_hDatabase.Query(SQL_Callback, sQuery, -2);
}

void OnDatabaseCleanup(LR_CleanupType CleanupType, Transaction hTransaction)
{
	if(CleanupType == LR_AllData || CleanupType == LR_StatsData)
	{
		decl char sQuery[512];

		FormatEx(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS `%s_unusualkills`;", g_sTableName);
		hTransaction.AddQuery(sQuery);

		FormatEx(sQuery, sizeof(sQuery), g_sSQL_CREATE_TABLE, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");
		g_hDatabase.Query(SQL_Callback, sQuery, -3);
	}
}

public void SQL_Callback(Database hDatabase, DBResultSet hResult, const char[] sError, int iData)
{
	if(iData)		// Others
	{
		if(!hResult)
		{
			LogError("SQL_Callback: error when sending the request (%d) - %s", iData, sError);
			return;
		}

		int iClient = GetClientOfUserId(iData >> 4);

		if(iClient)
		{
			if(iData &= 0xF)
			{
				Menu hMenu = new Menu(MenuShowTop_Callback, MenuAction_Select);

				char sText[768], sName[32], sTrans[48];

				if(hResult.RowCount)
				{
					for(int j = 0; hResult.FetchRow();)
					{
						hResult.FetchString(0, sName, sizeof(sName));
						FormatEx(sText[strlen(sText)], 64, "%T\n", "MenuTop_Open", iClient, ++j, hResult.FetchInt(1), sName);
					}

					sText[strlen(sText)] = ' ';
				}
				else
				{
					FormatEx(sText[strlen(sText)], 16, "%T\n", "NoData", iClient);
				}

				FormatEx(sTrans, sizeof(sTrans), "MenuTop_%s", g_sNameUK[iData - 1]);
				hMenu.SetTitle("%s | %T\n \n%s", g_sMenuTitle, sTrans, iClient, sText);

				FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
				hMenu.AddItem(NULL_STRING, sText);

				hMenu.Display(iClient, MENU_TIME_FOREVER);

				return;
			}

			if(hResult.HasResults && hResult.FetchRow())
			{
				for(int i = 0; i != MAX_UKTYPES; i++)
				{
					g_iUK[iClient][i] = hResult.FetchInt(i);
				}
			}
			else
			{
				decl char sQuery[256];

				FormatEx(sQuery, sizeof(sQuery), SQL_CREATE_DATA, g_sTableName, GetSteamID2(g_iAccountID[iClient]));
				g_hDatabase.Query(SQL_Callback, sQuery, -5, DBPrio_High);

				for(int i = 0; i != MAX_UKTYPES; i++)
				{
					g_iUK[iClient][i] = 0;
				}
			}
		}
	}
	else		// CreateTable
	{
		for(int i = MaxClients + 1; --i;)
		{
			if(LR_GetClientStatus(i))
			{
				LoadDataPlayer(i, GetSteamAccountID(i));
			}
		}

		LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	}
}

int MenuShowTop_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	if(mAction == MenuAction_Select)
	{
		MenuShowTops(iClient, iSlot / 6 * 6);
	}
	else if(mAction == MenuAction_End)
	{
		hMenu.Close();
	}
}

char[] GetSteamID2(int iAccountID)
{
	static char sSteamID2[22] = "STEAM_";

	if(!sSteamID2[6])
	{
		sSteamID2[6] = '0' + view_as<int>(g_iEngine == Engine_CSGO);
		sSteamID2[7] = ':';
	}

	FormatEx(sSteamID2[8], 14, "%i:%i", iAccountID & 1, iAccountID >>> 1);

	return sSteamID2;
}