#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Distributor"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iDistributorValue,
		g_iDistributorTime;
Handle	g_hTimerGiver[MAXPLAYERS + 1];

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_distributor.phrases");
		case Engine_SourceSDK2006: LoadTranslations("lr_module_distributor_old.phrases");
	}
	ConfigLoad();
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/distributor.ini");
	KeyValues hLR = new KeyValues("LR_Distributor");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iDistributorValue = hLR.GetNum("value", 1);
	g_iDistributorTime = hLR.GetNum("time", 50);

	hLR.Close();
}

public void OnClientPutInServer(int iClient)
{
	if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		g_hTimerGiver[iClient] = CreateTimer(float(g_iDistributorTime), TimerGiver, GetClientUserId(iClient), TIMER_REPEAT);
	}
}

public Action TimerGiver(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(LR_CheckCountPlayers() && LR_GetClientStatus(iClient) && GetClientTeam(iClient) > 1)
	{
		LR_ChangeClientValue(iClient, g_iDistributorValue);
		LR_PrintToChat(iClient, true, "%T", "Distributor", iClient, LR_GetClientInfo(iClient, ST_EXP), g_iDistributorValue);
	}
}

public void OnClientDisconnect(int iClient)
{
	if(g_hTimerGiver[iClient] != null)
	{
		KillTimer(g_hTimerGiver[iClient]);
		g_hTimerGiver[iClient] = null;
	}
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}