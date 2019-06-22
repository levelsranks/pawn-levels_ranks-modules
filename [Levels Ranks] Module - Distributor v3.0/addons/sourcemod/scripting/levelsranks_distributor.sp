#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iDistributorValue,
		g_iDistributorTime;
Handle	g_hTimerGiver[MAXPLAYERS + 1];

public Plugin myinfo = {name = "[LR] Module - Distributor", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnPluginStart()
{
	EngineVersion EngineGame;
	switch(EngineGame = GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: LoadTranslations(EngineGame == Engine_SourceSDK2006 ? "lr_module_distributor_old.phrases" : "lr_module_distributor.phrases");
		default: SetFailState("[" ... PLUGIN_NAME ... " Distributor] Plug-in works only on CS:GO, CS:S OB or v34");
	}
}

public void OnMapStart() 
{
	ConfigLoad();
}

public void LR_OnSettingsModuleUpdate() 
{
	ConfigLoad();
}

void ConfigLoad()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/distributor.ini");
	KeyValues hLR_Distributor = new KeyValues("LR_Distributor");

	if(!hLR_Distributor.ImportFromFile(sPath) || !hLR_Distributor.GotoFirstSubKey())
	{
		SetFailState("[" ... PLUGIN_NAME ... " Distributor] file is not found (%s)", sPath);
	}

	hLR_Distributor.Rewind();

	if(hLR_Distributor.JumpToKey("Settings"))
	{
		g_iDistributorValue = hLR_Distributor.GetNum("value", 1);
		g_iDistributorTime = hLR_Distributor.GetNum("time", 50);
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Distributor] section Settings is not found (%s)", sPath);
	delete hLR_Distributor;
}

public void OnClientPutInServer(int iClient)
{
	if(!LR_GetTypeStatistics() && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
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
		LR_PrintToChat(iClient, "%T", "Distributor", iClient, LR_GetClientInfo(iClient, ST_EXP), g_iDistributorValue);
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