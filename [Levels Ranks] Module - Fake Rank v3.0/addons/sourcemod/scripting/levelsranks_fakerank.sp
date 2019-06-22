#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo & Wend4r"

int		g_iRankPlayers[MAXPLAYERS],
		g_iRankConfig[128],
		g_iRankOffset;
bool		g_bUpdateRanks;

public Plugin myinfo = {name = "[LR] Module - FakeRank", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO) SetFailState("[" ... PLUGIN_NAME ... " Fake Rank] Plug-in works only on CS:GO");
	HookEvent("round_start", view_as<EventHook>(OnGameStart), EventHookMode_PostNoCopy);
	HookEvent("begin_new_match", view_as<EventHook>(OnGameStart), EventHookMode_PostNoCopy);
}

public void LR_OnCoreIsReady()
{
	ConfigLoad();
}

public void OnMapStart()
{
	ConfigLoad();
	g_iRankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
	SDKHook(FindEntityByClassname(-1, "cs_player_manager"), SDKHook_ThinkPost, OnThinkPost);
}

public void LR_OnSettingsModuleUpdate()
{
	ConfigLoad();
}

void ConfigLoad()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fakerank.ini");
	KeyValues hLR_FakeRank = new KeyValues("LR_FakeRank");

	if(!hLR_FakeRank.ImportFromFile(sPath) || !hLR_FakeRank.GotoFirstSubKey())
	{
		SetFailState("[" ... PLUGIN_NAME ... " FakeRank] file is not found (%s)", sPath);
	}

	hLR_FakeRank.Rewind();

	if(hLR_FakeRank.JumpToKey("FakeRank"))
	{
		int iFRCount = 0;
		hLR_FakeRank.GotoFirstSubKey();

		do
		{
			iFRCount++;
			g_iRankConfig[iFRCount] = hLR_FakeRank.GetNum("id", 0);
		}
		while(hLR_FakeRank.GotoNextKey());

		if(iFRCount != LR_GetCountLevels())
		{
			SetFailState("[" ... PLUGIN_NAME ... " FakeRank] the number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState("[" ... PLUGIN_NAME ... " FakeRank] section FakeRank is not found (%s)", sPath);
	delete hLR_FakeRank;
}

void OnGameStart()
{
	static bool bTimer;
	
	if((bTimer = !bTimer))
	{
		CreateTimer(0.5, view_as<Timer>(OnGameStart));
		return;
	}

	g_bUpdateRanks++;
}

void OnThinkPost(int iEnt)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(LR_GetClientStatus(i))
		{
			SetEntData(iEnt, g_iRankOffset + i*4, g_iRankConfig[g_iRankPlayers[i]]);
		}
	}

	if(g_bUpdateRanks)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(LR_GetClientStatus(i))
			{
				StartMessageOne("ServerRankRevealAll", i);
				EndMessage();
			}
		}
		g_bUpdateRanks = false;
	}
}

public void LR_OnLevelChanged(int iClient, int iNewLevel, bool bUp)
{
	g_iRankPlayers[iClient] = iNewLevel;
	g_bUpdateRanks++;
}

public void LR_OnPlayerLoaded(int iClient)
{
	g_iRankPlayers[iClient] = LR_GetClientInfo(iClient, ST_RANK);
	g_bUpdateRanks++;
}