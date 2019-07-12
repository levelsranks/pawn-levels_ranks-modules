#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo & Wend4r"

int			m_iCompetitiveRanking;

KeyValues	g_hKv;

public Plugin myinfo = {name = "[LR] Module - FakeRank", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION ... " SR1"}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO) 
	{
		SetFailState("[" ... PLUGIN_NAME ... " Fake Rank] This plugin works only on CS:GO");
	}

	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	LoadSettings();
}

public void LR_OnSettingsModuleUpdate()
{
	LoadSettings();
}

void LoadSettings()
{
	static char sPath[PLATFORM_MAX_PATH];

	if(!g_hKv)
	{
		g_hKv = new KeyValues("LR_FakeRank");
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fakerank.ini");
	}

	if(!g_hKv.ImportFromFile(sPath))
	{
		SetFailState("[" ... PLUGIN_NAME ... " Fake Rank] File \"%s\" is not found", sPath);
	}
	g_hKv.GotoFirstSubKey();

	g_hKv.Rewind();
	if(!g_hKv.JumpToKey("FakeRank", false))
	{
		SetFailState("[" ... PLUGIN_NAME ... " Fake Rank] \"%s\" -> \"FakeRank\" - selection is not found", sPath);
	}
}

public void OnMapStart()
{
	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);
}

void OnThinkPost(int iEnt)
{
	for(int i = 1; i != MaxClients; i++)
	{
		if(LR_GetClientStatus(i))
		{
			static char sRank[12];	// Max Value Rank - 4294967296 (uint32)

			IntToString(LR_GetClientInfo(i, ST_RANK), sRank, 12);
			SetEntData(iEnt, m_iCompetitiveRanking + i*4, g_hKv.GetNum(sRank));
		}
	}
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS+1];

	if(iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}