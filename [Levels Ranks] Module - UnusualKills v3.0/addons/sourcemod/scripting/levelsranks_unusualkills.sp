
#include <sourcemod>
#include <sdktools_gamerules>
#include <sdktools_functions>
#include <cstrike>

#pragma semicolon 1

#include <lvl_ranks>

#if SOURCEMOD_V_MINOR < 8
	#error Use the sourcemod 1.8+ for the right compile! Plugin may not work correctly!
#endif

#define PLUGIN_NAME "Levels Ranks Unusual Kills"
#define Crash(%0) SetFailState("[" ... PLUGIN_NAME ... "] " ... %0)

#define MAX_UKTYPES 9
#define UnusualKill_None 0
#define UnusualKill_OpenFrag (1 << 1)
#define UnusualKill_Penetrated (1 << 2)
#define UnusualKill_NoScope (1 << 3)
#define UnusualKill_Run (1 << 4)
#define UnusualKill_Jump (1 << 5)
#define UnusualKill_Flash (1 << 6)
#define UnusualKill_Ace (1 << 7)
#define UnusualKill_Smoke (1 << 8)
#define UnusualKill_Whirl (1 << 9)

#define SQL_CreateTable "CREATE TABLE IF NOT EXISTS `%s_unusualkills` (`SteamID` TEXT, `OP` NUMERIC, `Penetrated` NUMERIC, `NoScope` NUMERIC, `Run` NUMERIC, `Jump` NUMERIC, `Flash` NUMERIC, `Ace` NUMERIC, `Smoke` NUMERIC, `Whirl` NUMERIC)"
#define SQL_CreatePlayer "INSERT INTO `%s_unusualkills` (`SteamID`) VALUES ('%s');"
#define SQL_LoadPlayer "SELECT `OP`, `Penetrated`, `NoScope`, `Run`, `Jump`, `Flash`, `Ace`, `Smoke`, `Whirl` FROM `%s_unusualkills` WHERE `SteamID` = '%s';"
#define SQL_SavePlayer "UPDATE `%s_unusualkills` SET %s WHERE `SteamID` = '%s';"

#define RadiusSmoke 100.0

bool  	 g_bAllowKills,
		 g_bClientMoves[MAXPLAYERS+1],
		 g_bFly[MAXPLAYERS+1],
		 g_bMessages,
		 g_bOPKill,
		 g_bTimerAng[MAXPLAYERS+1][2];

int 	 g_iAceMinKills,
	 	 g_iCountKills[MAXPLAYERS+1],
		 g_iExp[MAX_UKTYPES],
		 g_iMaxSmokes,
		 g_iMinSmokes,
		 g_iMaxConf[2],
		 g_iMaxClients,
		 g_iSmokeEnt[64],
		 g_iUK[MAXPLAYERS+1][MAX_UKTYPES],
		 m_bIsScoped,
		 m_flFlashDuration,
		 m_vecOrigin;

float	 g_flMouseX[MAXPLAYERS+1],
	 	 g_flMinFlash,
		 g_flWhirl,
		 g_flWhirlTimer;

char  	 g_sTableName[32],
		 g_sProhibitedWeapons[50][24],
		 g_sNoZoomWeapons[16][24],
		 g_sSteamID[MAXPLAYERS+1][32];

static const char
		 g_sNameUK[][] = {"OP", "Penetrated", "NoScope", "Run", "Jump", "Flash", "Ace", "Smoke", "Whirl"};

EngineVersion
		 g_iEngine;

Database g_hDataBase;

// levelsranks_unusualkills.sp
public Plugin myinfo = 
{
	name = "[LR] Module - Unusual Kills", 
	author = "Wend4r", 
	version = PLUGIN_VERSION, 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public void OnPluginStart()
{
	LoadTranslations((g_iEngine = GetEngineVersion()) != Engine_SourceSDK2006 ? "lr_unusualkills.phrases" : "lr_unusualkills_old.phrases");

	m_bIsScoped = FindSendPropInfo("CCSPlayer", "m_bIsScoped");
	m_flFlashDuration = FindSendPropInfo("CCSPlayer", "m_flFlashDuration");
	m_vecOrigin = FindSendPropInfo("CBaseEntity", "m_vecOrigin");

	g_iMaxClients = GetMaxHumanPlayers()+1;

	LoadSettings();

	HookEvent("round_end", view_as<EventHook>(Round_Events));
	HookEvent("round_start", view_as<EventHook>(Round_Events));
	HookEvent("player_death", view_as<EventHook>(Death_Event) /*, EventHookMode_PostNoCopy*/);

	HookEvent("smokegrenade_detonate", view_as<EventHook>(Smoke_Events));
	HookEventEx("smokegrenade_expired", view_as<EventHook>(Smoke_Events));
}
public void OnAllPluginsLoaded()
{
	ConnectDatabase();

	for(int i = 1; i != g_iMaxClients; i++)
	{
		if(LR_GetClientStatus(i))
		{
			static char sSteamID[32];

			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
			LR_OnPlayerLoaded(i, sSteamID);
		}
	}
}

public void LR_OnDatabaseLoaded()
{
	ConnectDatabase();
}

public void LR_OnSettingsModuleUpdate()
{
	LoadSettings();
}

void ConnectDatabase()
{
	if(!g_hDataBase)
	{
		g_hDataBase = LR_GetDatabase();

		LR_GetTableName(g_sTableName, sizeof(g_sTableName));

		SQL_LockDatabase(g_hDataBase);

		bool bDBType = LR_GetDatabaseType();
		char sQuery[384];

		FormatEx(sQuery, sizeof(sQuery), SQL_CreateTable, g_sTableName, bDBType ? "AUTOINCREMENT" : "AUTO_INCREMENT");

		int iLenQuery = strlen(sQuery);
		FormatEx(sQuery[iLenQuery], sizeof(sQuery)-iLenQuery, bDBType ? ";" : " CHARSET = utf8 COLLATE utf8_general_ci;");

		g_hDataBase.Query(SQL_Callback, sQuery, -1);

		for(int i = 6; i != MAX_UKTYPES; i++)
		{
			FormatEx(sQuery, sizeof(sQuery), "ALTER TABLE `%s_unusualkills` ADD `%s` NUMERIC;", g_sTableName, g_sNameUK[i]);
			SQL_FastQuery(g_hDataBase, sQuery);
		}

		SQL_UnlockDatabase(g_hDataBase);

		g_hDataBase.SetCharset("utf8");
	}
}

void LoadSettings()
{
	static int  iType[23] = {-1, ...};
	static bool bELO, bNotELO;
	static char sPath[PLATFORM_MAX_PATH], sBuffer[512];
	static KeyValues hKv;

	if(!hKv)
	{
		hKv = new KeyValues("LR_UnusualKills");
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/UnusualKills.ini");

		bELO = !!LR_GetTypeStatistics();

		iType[0] = 6;
		iType[5] = 5;
		iType[9] = 4;
		iType[13] = 2;
		iType[14] = 0;
		iType[15] = 1;
		iType[17] = 3;
		iType[18] = 7;
		iType[22] = 8;
	}

	if(!hKv.ImportFromFile(sPath) || !hKv.GotoFirstSubKey())
		Crash("LoadSettings: %s - not found or damaged!", sPath);

	hKv.Rewind();

	if(hKv.JumpToKey("Settings"))
	{
		if(!!hKv.GetNum("UseFor_ELO", 0) || !bELO)
			bNotELO++;

		g_bMessages = LR_GetParamUsualMessage() == 1;

		hKv.GetString("ProhibitedWeapons", sBuffer, sizeof(sBuffer));
		g_iMaxConf[0] = ExplodeString(sBuffer, ",", g_sProhibitedWeapons, 50, 24);

		if(hKv.JumpToKey("TypeKills"))
		{
			hKv.GotoFirstSubKey();
			do
			{
				hKv.GetSectionName(sBuffer, 16);

				int iUKType = iType[sBuffer[0]-97];
				switch(iUKType)
				{
					case 2:
					{
						hKv.GetString("weapons", sBuffer, sizeof(sBuffer));
						g_iMaxConf[1] = ExplodeString(sBuffer, ",", g_sNoZoomWeapons, 16, 24);
					}
					case 5:
					{
						g_flMinFlash = hKv.GetFloat("degree") * 100;
					}
					case 6:
					{
						g_iAceMinKills = hKv.GetNum("minimum");
					}
					case 8:
					{
						g_flWhirl = float(hKv.GetNum("degrees"));
						g_flWhirlTimer = hKv.GetFloat("time");
					}
				}

				g_iExp[iUKType] = hKv.GetNum("exp");
			}
			while(hKv.GotoNextKey());
		}
	}
}

void Round_Events(Event hEvent, const char sName[8])
{
	static int iTeamCount[2];

	if(sName[6] == 'e')
	{
		for(int i = 1; i != g_iMaxClients; i++) 
		{
			if(LR_GetClientStatus(i) && IsClientInGame(i))
			{
				{
					int iTeamPL = GetClientTeam(i)-2;

					if(iTeamPL >= 0)
					{
						iTeamPL %= 1;

						if(g_iCountKills[i] >= iTeamCount[iTeamPL] && g_iAceMinKills <= iTeamCount[iTeamPL])
							UnusualKill(i, UnusualKill_Ace);
					}
				}
			}
			g_iCountKills[i] = 0;
		}
		return;
	}

	g_bAllowKills = LR_CheckCountPlayers();

	iTeamCount[0] = GetTeamClientCount(CS_TEAM_T);
	iTeamCount[1] = GetTeamClientCount(CS_TEAM_CT);

	g_bOPKill = false;
	g_iMinSmokes = 0;
	g_iMaxSmokes = 0;
}

void Death_Event(Event hEvent)
{
	if(g_bAllowKills)
	{
		int iClient = GetClientOfUserId(hEvent.GetInt("userid")),
			iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

		if(iClient && iAttacker && iClient != iAttacker)
		{

			if(LR_GetClientStatus(iClient) && LR_GetClientStatus(iAttacker))
			{
				int iUKTypes = UnusualKill_None;
				static char sWeapon[24];

				hEvent.GetString("weapon", sWeapon, sizeof(sWeapon));

				for(int i; i != g_iMaxConf[0];)
				{
					if(StrEqual(sWeapon, g_sProhibitedWeapons[i++]))
						return;
				}

				if(!g_bOPKill)
				{
					iUKTypes |= UnusualKill_OpenFrag;
					g_bOPKill++;
				}

				if(hEvent.GetBool("penetrated"))
					iUKTypes |= UnusualKill_Penetrated;

				if(g_iEngine == Engine_CSGO)
				{
					if(!GetEntData(iAttacker, m_bIsScoped))
					{
						for(int i2; i2 != g_iMaxConf[1];)
						{
							if(StrEqual(sWeapon, g_sNoZoomWeapons[i2++]))
							{
								iUKTypes |= UnusualKill_NoScope;
								break;
							}
						}
					}
				}

				if(g_bClientMoves[iAttacker]) 
					iUKTypes |= UnusualKill_Run;

				if(g_bFly[iAttacker])
					iUKTypes |= UnusualKill_Jump;


				if(g_flMinFlash < GetEntDataFloat(iAttacker, m_flFlashDuration))
					iUKTypes |= UnusualKill_Flash;

				for(int i3 = g_iMinSmokes; i3 != g_iMaxSmokes; i3++)
				{
					if(IsValidEntity(g_iSmokeEnt[i3]))
					{
						static float vecClient[3], 
									 vecAttacker[3], 
									 vecSmoke[3], 
									 flDistance[3];

						GetEntDataVector(iClient, m_vecOrigin, vecClient);
						GetEntDataVector(iAttacker, m_vecOrigin, vecAttacker);
						GetEntDataVector(g_iSmokeEnt[i3], m_vecOrigin, vecSmoke);

						vecClient[2] -= 64.0;

						flDistance[0] = GetVectorDistance(vecClient, vecSmoke);
						flDistance[1] = GetVectorDistance(vecAttacker, vecSmoke);
						flDistance[2] = GetVectorDistance(vecClient, vecAttacker);

						if((flDistance[0] + flDistance[1])*0.7 <= flDistance[2] + RadiusSmoke)
						{
							float flHalPerimeter = (flDistance[0]+flDistance[1]+flDistance[2])/2.0;

							if((2.0 * SquareRoot(flHalPerimeter*(flHalPerimeter-flDistance[0])*(flHalPerimeter-flDistance[1])*(flHalPerimeter-flDistance[2]))) / flDistance[2] < RadiusSmoke)
							{
								iUKTypes |= UnusualKill_Smoke;
								break;
							}
						}
					}
				}

				if(g_bTimerAng[iClient][1])
					iUKTypes |= UnusualKill_Whirl;

				if(iUKTypes)
				{
					UnusualKill(iAttacker, iUKTypes);
				}

				g_iCountKills[iAttacker]++;
			}
		}
	}
}
void Smoke_Events(Event hEvent, const char[] sName)
{
	if(sName[13] == 'd')
	{
		g_iSmokeEnt[g_iMaxSmokes++] = hEvent.GetInt("entityid");
		return;
	}

	if(++g_iMinSmokes == g_iMaxSmokes)
	{
		g_iMinSmokes = 0;
		g_iMaxSmokes = 0; 
	}
}

void UnusualKill(int iClient, int iUKTypes)
{
	char sQuery[256],
		 sTables[MAX_UKTYPES * 16];

	for(int iType; iType != MAX_UKTYPES; iType++)
	{
		if(iUKTypes & (1 << iType+1))
		{
			FormatEx(sTables, sizeof(sTables), "%s`%s` = %d, ", sTables, g_sNameUK[iType], ++g_iUK[iClient][iType]);
			if(g_iExp[iType])
			{
				LR_ChangeClientValue(iClient, g_iExp[iType]);

				if(g_bMessages)
				{
					static char sBuffer[8];

					FormatEx(sBuffer, sizeof(sBuffer), g_iExp[iType] > 0 ? "+%d" : "%d", g_iExp[iType]);
					LR_PrintToChat(iClient, "%T", g_sNameUK[iType], iClient, LR_GetClientInfo(iClient, ST_EXP), sBuffer);
				}
			}
			// break;
		}
	}

	sTables[strlen(sTables)-2] = '\0';
	FormatEx(sQuery, sizeof(sQuery), SQL_SavePlayer, g_sTableName, sTables, g_sSteamID[iClient]);
	g_hDataBase.Query(SQL_Callback, sQuery, -2);
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float flVel[3], const float flAngles[3])
{
	g_bFly[iClient] = !(GetEntityFlags(iClient) & FL_ONGROUND);
	g_flMouseX[iClient] = flAngles[1];
	g_bClientMoves[iClient] = (flVel[0] + flVel[1]) != 0.0;

	if(!g_bTimerAng[iClient][0] && !g_bTimerAng[iClient][1])
	{
		g_bTimerAng[iClient][0]++;
		CreateTimer(0.1, CheckAngX, iClient, TIMER_REPEAT);
	}
}
Action CheckAngX(Handle hTimer, int iClient)
{
	bool bStop;
	static int   iCount[MAXPLAYERS+1];
	static float flWhirl[MAXPLAYERS+1],
				 flDifferenceWhirl[MAXPLAYERS+1];

	if(LR_GetClientStatus(iClient))
	{
		if(iCount[iClient] != 5)
		{
			float flWhirlLocal = flWhirl[iClient];
			if(iCount[iClient]++)
			{
				float flDifference = flDifferenceWhirl[iClient] - g_flMouseX[iClient];
				flWhirl[iClient] = flDifference > 0.0 ? flDifference : -flDifference;
			}
			flDifferenceWhirl[iClient] = g_flMouseX[iClient];

			if(flWhirlLocal >= g_flWhirl)
			{
				g_bTimerAng[iClient][1]++;
				CreateTimer(g_flWhirlTimer, TurnOffWhirl, iClient);
				bStop++;
			}
		}
		else
		{
			bStop++;
		}
	}
	else
	{
		bStop++;
	}

	if(bStop)
	{
		flWhirl[iClient] = 0.0;
		iCount[iClient] = 0;
		g_bTimerAng[iClient][0] = false;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action TurnOffWhirl(Handle hTimer, int iClient)
{
	g_bTimerAng[iClient][1] = false;
}

public void LR_OnPlayerLoaded(int iClient, const char[] sAuth)
{
	static char sQuery[256];

	strcopy(g_sSteamID[iClient], 32, sAuth);

	FormatEx(sQuery, sizeof(sQuery), SQL_LoadPlayer, g_sTableName, g_sSteamID[iClient]);
	g_hDataBase.Query(SQL_Callback, sQuery, iClient);
}

void CreateDataPlayer(int iClient)
{
	static char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), SQL_CreatePlayer, g_sTableName, g_sSteamID[iClient]);
	g_hDataBase.Query(SQL_Callback, sQuery, -3);
}

public void SQL_Callback(Database db, DBResultSet dbRs, const char[] sError, int iIndex)
{
	// iIndex:
	// -1 - CreateData
	// -2 - SaveDataPlayer
	// -3 - CreateDataPlayer
	// any  - LR_OnPlayerLoaded - iClient

	if(!dbRs)
	{
		LogError("SQL_Callback: error when sending the request (%d) - %s", iIndex, sError);
		return;
	}

	if(iIndex > 0)
	{
		bool bCreateData;
		if(!(dbRs.HasResults && dbRs.FetchRow()))
		{
			CreateDataPlayer(iIndex);
			bCreateData++;
		}

		for(int i; i != MAX_UKTYPES; i++)
			g_iUK[iIndex][i] = bCreateData ? 0 : dbRs.FetchInt(i);
	}
}