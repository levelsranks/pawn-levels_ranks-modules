#include <sourcemod>
#include <sdktools_gamerules>
#include <sdktools_functions>
#include <cstrike>

#pragma semicolon 1

#include <lvl_ranks>

#if SOURCEMOD_V_MINOR < 8
	#error Use the sourcemod 1.8+ for the right compile! Plugin may not work correctly!
#endif

#define Crash(%0) SetFailState("[Levels Ranks] Unusual Kills: " ... %0)

#define MAX_UKTYPES 9
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 1)
#define UnusualKill_Penetrated (1 << 2)
#define UnusualKill_NoScope (1 << 3)
#define UnusualKill_Run (1 << 4)
#define UnusualKill_Jump (1 << 5)
#define UnusualKill_Flash (1 << 6)
#define UnusualKill_Smoke (1 << 7)
#define UnusualKill_Whirl (1 << 8)
#define UnusualKill_LastClip (1 << 9)

#define SQL_CreateTable "\
CREATE TABLE IF NOT EXISTS `%s_unusualkills` \
(\
	`SteamID` varchar(32) NOT NULL PRIMARY KEY DEFAULT '', \
	`OP` int NOT NULL DEFAULT 0, \
	`Penetrated` int NOT NULL DEFAULT 0, \
	`NoScope` int NOT NULL DEFAULT 0, \
	`Run` int NOT NULL DEFAULT 0, \
	`Jump` int NOT NULL DEFAULT 0, \
	`Flash` int NOT NULL DEFAULT 0, \
	`Smoke` int NOT NULL DEFAULT 0, \
	`Whirl` int NOT NULL DEFAULT 0, \
	`LastClip` int NOT NULL DEFAULT 0\
)%s"
#define SQL_CreatePlayer "INSERT INTO `%s_unusualkills` (`SteamID`) VALUES ('%s');"
#define SQL_LoadPlayer "SELECT `OP`, `Penetrated`, `NoScope`, `Run`, `Jump`, `Flash`, `Smoke`, `Whirl`, `LastClip` FROM `%s_unusualkills` WHERE `SteamID` = '%s';"
#define SQL_SavePlayer "UPDATE `%s_unusualkills` SET %s WHERE `SteamID` = '%s';"

#define RadiusSmoke 100.0

enum ArrayListBuffer
{
	ArrayList:ChatCommands = 0,
	ArrayList:ProhibitedWeapons,
	ArrayList:NoScope_Weapons
};

bool  	  g_bMessages,
		  g_bOPKill,
		  g_bShowItem[MAX_UKTYPES];

int 	  g_iExp[MAX_UKTYPES],
		  g_iExpMode,
		  g_iMinSmokes,
		  g_iMaxClients,
		  g_iMouceX[MAXPLAYERS+1],
		  g_iWhirlInterval = 1,
		  g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		  g_iWhirl = 300,
		  m_bIsScoped,
		  m_iClip1,
		  m_hActiveWeapon,
		  m_flFlashDuration,
		  m_vecOrigin,
		  m_vecVelocity;

float	  g_flMinFlash = 5.0,
		  g_flMinLenVelocity = 100.0;

char  	  g_sTableName[32],
		  g_sMenuTitle[64],
		  g_sSteamID[MAXPLAYERS+1][32];

static const char
		  g_sNameUK[][] = {"OP", "Penetrated", "NoScope", "Run", "Jump", "Flash", "Smoke", "Whirl", "LastClip"};

EngineVersion
		  g_iEngine;

Database  g_hDataBase;

ArrayList g_hBuffer[ArrayListBuffer],
		  g_hSmokeEnt;

// levelsranks_unusualkills.sp
public Plugin myinfo = 
{
	name = "[LR] Module - Unusual Kills", 
	author = "Wend4r", 
	version = PLUGIN_VERSION ... " SR2", 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
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

	m_bIsScoped = FindSendPropInfo("CCSPlayer", "m_bIsScoped");
	m_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	m_hActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	m_flFlashDuration = FindSendPropInfo("CCSPlayer", "m_flFlashDuration");
	m_vecOrigin = FindSendPropInfo("CBaseEntity", "m_vecOrigin");
	m_vecVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");

	g_iMaxClients = GetMaxHumanPlayers()+1;

	g_hSmokeEnt = new ArrayList();

	LoadSettings();

	HookEvent("round_start", view_as<EventHook>(OnRoundStart));

	HookEvent("smokegrenade_detonate", view_as<EventHook>(OnSmokeEvent));
	HookEventEx("smokegrenade_expired", view_as<EventHook>(OnSmokeEvent));
}

public void OnAllPluginsLoaded()
{
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	SQL_LockDatabase((g_hDataBase = LR_GetDatabase()));

	char sQuery[512];

	FormatEx(sQuery, sizeof(sQuery), SQL_CreateTable, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");

	g_hDataBase.Query(SQL_Callback, sQuery, -1);

	for(int i = 6; i != MAX_UKTYPES;)
	{
		FormatEx(sQuery, sizeof(sQuery), "ALTER TABLE `%s_unusualkills` ADD `%s` int NOT NULL DEFAULT 0;", g_sTableName, g_sNameUK[i++]);
		SQL_FastQuery(g_hDataBase, sQuery);
	}

	FormatEx(sQuery, sizeof(sQuery), "ALTER TABLE `%s_unusualkills` DROP `ACE`;", g_sTableName);
	SQL_FastQuery(g_hDataBase, sQuery);

	SQL_UnlockDatabase(g_hDataBase);
	g_hDataBase.SetCharset("utf8");

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

public void LR_OnSettingsModuleUpdate()
{
	LoadSettings();
}

void LoadSettings()
{
	static int  iUKSymbolTypes[] = {127, 127, 127, 127, 127, 5, 127, 127, 127, 4, 127, 8, 127, 2, 0, 1, 127, 3, 6, 127, 127, 127, 7};

	static char sPath[PLATFORM_MAX_PATH], sBuffer[512];

	KeyValues hKv = new KeyValues("LR_UnusualKills");

	if(!sPath[0])
	{
		for(ArrayListBuffer i; i != ArrayListBuffer; i++)
		{
			g_hBuffer[i] = new ArrayList(64);
		}

		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/UnusualKills.ini");
	}

	if(!hKv.ImportFromFile(sPath))
	{
		Crash("LoadSettings: %s - not found!", sPath);
	}
	hKv.GotoFirstSubKey();

	hKv.Rewind();
	hKv.JumpToKey("Settings");	/**/

	g_iExpMode = hKv.GetNum("Exp_Mode", 1);
	g_bMessages = LR_GetParamUsualMessage() == 1;

	LR_GetTitleMenu(g_sMenuTitle, sizeof(g_sMenuTitle));

	hKv.GetString("ChatCommands", sBuffer, sizeof(sBuffer), "!uk,!ukstats,!unusualkills");
	ExplodeInArrayList(sBuffer, ChatCommands);

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer), "hegrenade,molotov,incgrenade");
	ExplodeInArrayList(sBuffer, ProhibitedWeapons);

	hKv.JumpToKey("TypeKills"); /**/

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
				continue;
			}
			case 2:
			{
				hKv.GetString("weapons", sBuffer, sizeof(sBuffer));
				ExplodeInArrayList(sBuffer, NoScope_Weapons);
			}
			case 3:
			{
				g_flMinLenVelocity = hKv.GetFloat("minspeed", 100.0);
			}
			case 5:
			{
				g_flMinFlash = hKv.GetFloat("degree") * 10.0;
			}
			case 7:
			{
				g_iWhirl = hKv.GetNum("whirl", 300);
				g_iWhirlInterval = hKv.GetNum("interval", 1);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
		g_bShowItem[iUKType] = view_as<bool>(hKv.GetNum("menu"));
	}
	while(hKv.GotoNextKey());

	delete hKv;
}

void ExplodeInArrayList(const char[] sText, ArrayListBuffer Array)
{
	int  iLastSize = 0;

	for(int i = 0, iLen = strlen(sText)+1; i != iLen;)
	{
		if(iLen == ++i || sText[i-1] == ',')
		{
			char sBuf[64];

			strcopy(sBuf, i-iLastSize, sText[iLastSize]);
			g_hBuffer[Array].PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		PrintToServer(sText);
		g_hBuffer[Array].PushString(sText);
	}
}

void OnRoundStart()
{
	g_bOPKill = false;
	g_hSmokeEnt.Clear();
	g_iMinSmokes = 0;
}

public void LR_OnPlayerKilled(Event hEvent, int& iExpGive)
{
	static char sWeapon[32];

	hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

	if(g_hBuffer[ProhibitedWeapons].FindString(sWeapon) == -1)
	{
		int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker")),
			iUKFlags = UnusualKill_None;

		static float vecVelocity[3];

		if(!g_bOPKill)
		{
			iUKFlags |= UnusualKill_OpenFrag;
			g_bOPKill = true;
		}

		if(hEvent.GetBool("penetrated"))
		{
			iUKFlags |= UnusualKill_Penetrated;
		}

		if(g_iEngine == Engine_CSGO && !GetEntData(iAttacker, m_bIsScoped) && g_hBuffer[NoScope_Weapons].FindString(sWeapon) != -1)
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

		if(g_flMinFlash < GetEntDataFloat(iAttacker, m_flFlashDuration))
		{
			iUKFlags |= UnusualKill_Flash;
		}

		for(int iClient = GetClientOfUserId(hEvent.GetInt("userid")), i = g_iMinSmokes, iSmokeEntity; i != g_hSmokeEnt.Length;)
		{
			if(IsValidEntity((iSmokeEntity = g_hSmokeEnt.Get(i++))))
			{
				static float vecClient[3], 
							 vecAttacker[3], 
							 vecSmoke[3],

							 flDistance,
							 flDistance2,
							 flDistance3;

				GetEntDataVector(iClient, m_vecOrigin, vecClient);
				GetEntDataVector(iAttacker, m_vecOrigin, vecAttacker);
				GetEntDataVector(iSmokeEntity, m_vecOrigin, vecSmoke);

				vecClient[2] -= 64.0;

				flDistance = GetVectorDistance(vecClient, vecSmoke);
				flDistance2 = GetVectorDistance(vecAttacker, vecSmoke);
				flDistance3 = GetVectorDistance(vecClient, vecAttacker);

				if((flDistance + flDistance2) * 0.7 <= flDistance3 + RadiusSmoke)
				{
					float flHalfPerimeter = (flDistance + flDistance2 + flDistance3) / 2.0;

					if((2.0 * SquareRoot(flHalfPerimeter * (flHalfPerimeter - flDistance) * (flHalfPerimeter - flDistance2) * (flHalfPerimeter - flDistance3))) / flDistance3 < RadiusSmoke)
					{
						iUKFlags |= UnusualKill_Smoke;
						break;
					}
				}
			}
		}

		if((g_iMouceX[iAttacker] < 0 ? -g_iMouceX[iAttacker] : g_iMouceX[iAttacker]) > g_iWhirl)
		{
			iUKFlags |= UnusualKill_Whirl;
		}

		if(!GetEntData(GetEntDataEnt2(iAttacker, m_hActiveWeapon), m_iClip1))
		{
			iUKFlags |= UnusualKill_LastClip;
		}

		if(iUKFlags)
		{
			char sBuffer[8],
				 sColumns[MAX_UKTYPES * 16],
				 sQuery[256];

			for(int iType = 0; iType != MAX_UKTYPES; iType++)
			{
				if(iUKFlags & (1 << iType + 1))
				{
					FormatEx(sColumns, sizeof(sColumns), "%s`%s` = %d, ", sColumns, g_sNameUK[iType], ++g_iUK[iAttacker][iType]);

					if(g_iExp[iType])
					{
						if(g_iExpMode == 1)
						{
							LR_ChangeClientValue(iAttacker, g_iExp[iType]);

							if(g_bMessages)
							{
								FormatEx(sBuffer, sizeof(sBuffer), g_iExp[iType] > 0 ? "+%d" : "%d", g_iExp[iType]);
								LR_PrintToChat(iAttacker, "%T", g_sNameUK[iType], iAttacker, LR_GetClientInfo(iAttacker, ST_EXP), sBuffer);
							}
						}
						else
						{
							iExpGive += g_iExp[iType];
						}
					}
					// break;
				}
			}

			sColumns[strlen(sColumns)-2] = '\0';

			FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, g_sTableName, sColumns, g_sSteamID[iAttacker]);
			g_hDataBase.Query(SQL_Callback, sQuery, -2);
		}
	}
}

void OnSmokeEvent(Event hEvent, const char[] sName)
{
	if(sName[13] == 'd')
	{
		g_hSmokeEnt.Push(hEvent.GetInt("entityid"));
		return;
	}

	if(++g_iMinSmokes == g_hSmokeEnt.Length)
	{
		g_hSmokeEnt.Clear();
		g_iMinSmokes = 0;
	}
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float flVel[3], const float flAngles[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	static int iInterval[MAXPLAYERS+1];

	if((g_iMouceX[iClient] += iMouse[0]) && iInterval[iClient] - GetTime() <= 0)
	{
		g_iMouceX[iClient] = 0;
		iInterval[iClient] = GetTime() + g_iWhirlInterval;
	}
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(g_hBuffer[ChatCommands].FindString(sArgs) != -1)
	{
		SetGlobalTransTarget(iClient);

		Menu hMenu = new Menu(MenuShowInfo_Callback);

		int iKills = LR_GetClientInfo(iClient, ST_KILLS);

		char sBuffer[512],
			 sTrans[48];

		if(iKills)
		{
			for(int i = 0; i != MAX_UKTYPES; i++)
			{
				if(g_bShowItem[i])
				{
					FormatEx(sTrans, sizeof(sTrans), "Menu_%s", g_sNameUK[i]);
					FormatEx(sBuffer, sizeof(sBuffer), "%s%t\n", sBuffer, sTrans, g_iUK[iClient][i], 100 * g_iUK[iClient][i] / iKills);
				}
			}
		}

		hMenu.SetTitle("%s | %t\n \n%s\n ", g_sMenuTitle, "UnusualKill", sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "%t", "BackToMainMenu");
		hMenu.AddItem("", sBuffer);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
		hMenu.ExitButton = true;
	}
}

int MenuShowInfo_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{	
	switch(mAction)
	{
		case MenuAction_Select:
		{
			FakeClientCommand(iClient, "sm_lvl");
		}
	}
}

public void LR_OnPlayerLoaded(int iClient, const char[] sAuth)
{
	static char sQuery[256];

	strcopy(g_sSteamID[iClient], 32, sAuth);

	FormatEx(sQuery, sizeof(sQuery), SQL_LoadPlayer, g_sTableName, sAuth);
	g_hDataBase.Query(SQL_Callback, sQuery, iClient);
}

public void SQL_Callback(Database db, DBResultSet dbRs, const char[] sError, int iIndex)
{
	// iIndex:
	// any (iClient) - LR_OnPlayerLoaded
	// -1 - CreateData
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
			static char sQuery[256];

			FormatEx(sQuery, sizeof(sQuery), SQL_CreatePlayer, g_sTableName, g_sSteamID[iIndex]);
			g_hDataBase.Query(SQL_Callback, sQuery, -3);

			bLoadData = false;
		}

		for(int i; i != MAX_UKTYPES; i++)
		{
			g_iUK[iIndex][i] = bLoadData ? dbRs.FetchInt(i) : 0;
		}
	}
}