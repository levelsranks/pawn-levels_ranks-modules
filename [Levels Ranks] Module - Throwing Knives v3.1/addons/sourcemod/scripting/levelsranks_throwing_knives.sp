#pragma semicolon 1
#include <throwing_knives_core>

#pragma newdecls required
#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Throwing Knives"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iTKCount,
		g_iTKLevel[64],
		g_iTKnivesCount[64];

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	HookEvent("player_spawn", PlayerSpawn);
	ConfigLoad();
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	}
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/throwing_knives.ini");
	KeyValues hLR = new KeyValues("LR_ThrowingKnives");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Settings"))
	{
		g_iTKCount = 0;
		hLR.GotoFirstSubKey();

		do
		{
			g_iTKnivesCount[g_iTKCount] = hLR.GetNum("count", 1);
			g_iTKLevel[g_iTKCount] = hLR.GetNum("level", 0);
			g_iTKCount++;
		}
		while(hLR.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);
	hLR.Close();
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && IsClientInGame(iClient))
	{
		int iRank = LR_GetClientInfo(iClient, ST_RANK);
		TKC_SetClientKnives(iClient, 0, false);

		for(int i = g_iTKCount - 1; i >= 0; i--)
		{
			if(iRank >= g_iTKLevel[i])
			{
				TKC_SetClientKnives(iClient, g_iTKnivesCount[i], false);
				break;
			}
		}
	}
}