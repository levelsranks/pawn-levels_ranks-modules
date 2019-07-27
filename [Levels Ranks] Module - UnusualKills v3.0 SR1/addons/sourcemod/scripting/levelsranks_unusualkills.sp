
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

#define Weapons_Prohibited 0
#define Weapons_NoZoom 1

#define MAX_UKTYPES 8
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 1)
#define UnusualKill_Penetrated (1 << 2)
#define UnusualKill_NoScope (1 << 3)
#define UnusualKill_Run (1 << 4)
#define UnusualKill_Jump (1 << 5)
#define UnusualKill_Flash (1 << 6)
#define UnusualKill_Smoke (1 << 7)
#define UnusualKill_Whirl (1 << 8)

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
	`Whirl` int NOT NULL DEFAULT 0\
)%s"
#define SQL_CreatePlayer "INSERT INTO `%s_unusualkills` (`SteamID`) VALUES ('%s');"
#define SQL_LoadPlayer "SELECT `OP`, `Penetrated`, `NoScope`, `Run`, `Jump`, `Flash`, `Smoke`, `Whirl` FROM `%s_unusualkills` WHERE `SteamID` = '%s';"
#define SQL_SavePlayer "UPDATE `%s_unusualkills` SET %s WHERE `SteamID` = '%s';"

#define RadiusSmoke 100.0

bool  	  g_bMessages,
		  g_bOPKill,
		  g_bTimerMouse[MAXPLAYERS+1];

int 	  g_iExp[MAX_UKTYPES],
		  g_iExpMode,
		  g_iMinSmokes,
		  g_iMaxClients,
		  g_iMouceX[MAXPLAYERS+1],
		  g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		  g_iWhirl = 300,
		  m_bIsScoped,
		  m_flFlashDuration,
		  m_vecOrigin,
		  m_vecVelocity;

float	  g_flMinFlash = 5.0,
		  g_flMinLenVelocity = 100.0,
		  g_flWhirlTimer = 1.5;

char  	  g_sTableName[32],
		  g_sSteamID[MAXPLAYERS+1][32];

static const char
		  g_sNameUK[][] = {"OP", "Penetrated", "NoScope", "Run", "Jump", "Flash", "Smoke", "Whirl"};

EngineVersion
		  g_iEngine;

Database  g_hDataBase;

ArrayList g_hWeapons[2],
		  g_hSmokeEnt;

// levelsranks_unusualkills.sp
public Plugin myinfo = 
{
	name = "[LR] Module - Unusual Kills", 
	author = "Wend4r", 
	version = PLUGIN_VERSION ... " SR1", 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
	LoadTranslations((g_iEngine = GetEngineVersion()) != Engine_SourceSDK2006 ? "lr_unusualkills.phrases" : "lr_unusualkills_old.phrases");

	m_bIsScoped = FindSendPropInfo("CCSPlayer", "m_bIsScoped");
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
	g_hDataBase = LR_GetDatabase();
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	SQL_LockDatabase(g_hDataBase);

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), SQL_CreateTable, g_sTableName, LR_GetDatabaseType() ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");

	g_hDataBase.Query(SQL_Callback, sQuery, -1);

	for(int i = 6; i != MAX_UKTYPES; i++)
	{
		FormatEx(sQuery, sizeof(sQuery), "ALTER TABLE `%s_unusualkills` ADD `%s` int NOT NULL DEFAULT 0;", g_sTableName, g_sNameUK[i]);
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
	static int  iType[] = {127, 127, 127, 127, 127, 5, 127, 127, 127, 4, 127, 127, 127, 2, 0, 1, 127, 3, 6, 127, 127, 127, 7};
	static char sPath[PLATFORM_MAX_PATH], sBuffer[512];
	static KeyValues hKv;

	if(!hKv)
	{
		hKv = new KeyValues("LR_UnusualKills");

		g_hWeapons[Weapons_Prohibited] = new ArrayList(64);
		g_hWeapons[Weapons_NoZoom] = new ArrayList(64);

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

	hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer));
	ExplodeInArrayList(sBuffer, Weapons_Prohibited);

	hKv.JumpToKey("TypeKills"); /**/

	hKv.GotoFirstSubKey();
	do
	{
		hKv.GetSectionName(sBuffer, 32);

		int iUKType = iType[(sBuffer[0] | 32) - 97];
		switch(iUKType)
		{
			case 127:
			{
				LogError("%s: \"LR_UnusualKills\" -> \"Settings\" -> \"TypeKills\" -> \"%s\" - invalid selection", sPath, sBuffer);
				return;
			}
			case 2:
			{
				hKv.GetString("weapons", sBuffer, sizeof(sBuffer));
				ExplodeInArrayList(sBuffer, Weapons_NoZoom);
			}
			case 3:
			{
				g_flMinLenVelocity = hKv.GetFloat("minspeed", 100.0);
			}
			case 5:
			{
				g_flMinFlash = hKv.GetFloat("degree") * 100.0;
			}
			case 7:
			{
				g_iWhirl = hKv.GetNum("whirl", 300);
				g_flWhirlTimer = hKv.GetFloat("time", 1.5);
			}
		}

		g_iExp[iUKType] = g_iExpMode ? hKv.GetNum("exp") : 0;
	}
	while(hKv.GotoNextKey());
}

void ExplodeInArrayList(const char[] sText, int iArray)
{
	int  iLastSize = 0;

	for(int i = 0, iLen = strlen(sText)+1; i != iLen;)
	{
		if(iLen == ++i || sText[i-1] == ',')
		{
			char sBuf[64];

			strcopy(sBuf, i-iLastSize, sText[iLastSize]);
			g_hWeapons[iArray].PushString(sBuf);

			iLastSize = i;
		}
	}

	if(!iLastSize)
	{
		PrintToServer(sText);
		g_hWeapons[iArray].PushString(sText);
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
	static char sWeapon[24];

	hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

	if(g_hWeapons[Weapons_Prohibited].FindString(sWeapon) == -1)
	{
		int iClient = GetClientOfUserId(hEvent.GetInt("userid")),
			iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

		int iUKFlags = UnusualKill_None;

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

		if(g_iEngine == Engine_CSGO && !GetEntData(iAttacker, m_bIsScoped) && g_hWeapons[Weapons_NoZoom].FindString(sWeapon) != -1)
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

		for(int i = g_iMinSmokes, iSmokeEntity; i != g_hSmokeEnt.Length;)
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
	g_iMouceX[iClient] += iMouse[0];

	if(!g_bTimerMouse[iClient])
	{
		CreateTimer(g_flWhirlTimer, ResetMouseX, iClient);
	}
}

Action ResetMouseX(Handle hTimer, int iClient)
{
	g_iMouceX[iClient] = 0;
	g_bTimerMouse[iClient] = false;
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