#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

int			g_iType, m_iCompetitiveRanking;

KeyValues	g_hConfig;

public Plugin myinfo =
{
	name = "[LR] Module - FakeRank",
	author = "Wend4r",
	version = PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorSize)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(sError, iErrorSize, "This plugin works only on CS:GO.");

		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	m_iCompetitiveRanking = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

	LoadSettings();

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	LR_Hook(LR_OnSettingsModuleUpdate, LoadSettings);
}

void LoadSettings()
{
	static char sPath[PLATFORM_MAX_PATH];

	if(g_hConfig)
	{
		g_hConfig.Close();
	}
	else
	{
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fakerank.ini");
	}

	g_hConfig = new KeyValues("LR_FakeRank");

	if(!g_hConfig.ImportFromFile(sPath))
	{
		SetFailState("%s - is not found", sPath);
	}

	g_hConfig.GotoFirstSubKey();

	switch(g_hConfig.GetNum("Type"))
	{
		case 0:
		{
			g_iType = 0;
		}
		case 1:
		{
			g_iType = 50;
		}
		case 2:
		{
			g_iType = 70;
		}
	}

	g_hConfig.Rewind();
	g_hConfig.JumpToKey("FakeRank");
}

public void OnMapStart()
{
	static char sBuffer[256], sRank[12];

	for(int i = LR_GetRankNames().Length + 1, iIndex; i != 1;)
	{
		IntToString(--i, sRank, 12);

		if((iIndex = g_hConfig.GetNum(sRank) + g_iType) > 18)
		{
			FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", iIndex);
			AddFileToDownloadsTable(sBuffer);
		}
	}

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);
}

void OnThinkPost(int iEnt)
{
	static char sRank[12];

	for(int i = MaxClients + 1; --i;)
	{
		if(LR_GetClientStatus(i))
		{
			IntToString(LR_GetClientInfo(i, ST_RANK), sRank, 12);
			SetEntData(iEnt, m_iCompetitiveRanking + i*4, g_hConfig.GetNum(sRank) + g_iType);
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