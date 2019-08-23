#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iCalibrationCorrectiveValue[MAXPLAYERS+1],
		g_iCalibrationMode,
		g_iCalibrationPoints,
		g_iCalibrationCountKills;
Handle	g_hCalibration;

public Plugin myinfo = {name = "[LR] Module - Calibration", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnPluginStart()
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_calibration.phrases");
		case Engine_SourceSDK2006: LoadTranslations("lr_module_calibration_old.phrases");
		default: SetFailState("[" ... PLUGIN_NAME ... " Calibration] Plug-in works only on CS:GO, CS:S & CS:S v34");
	}

	g_hCalibration = RegClientCookie("LR_Calibration", "LR_Calibration", CookieAccess_Private);
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			if(AreClientCookiesCached(iClient))
			{
				OnClientCookiesCached(iClient);
			}
		}
	}

	ConfigLoad();
}

public void LR_OnSettingsModuleUpdate()
{
	ConfigLoad();
}

public void LR_OnCoreIsReady()
{
	if(!LR_GetTypeStatistics()) SetFailState("[" ... PLUGIN_NAME ... " Calibration] Plug-in works only on Rating Mode");
}

void ConfigLoad()
{
	char sPath[256];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/calibration.ini");
	KeyValues hLR_Calibration = new KeyValues("LR_Calibration");

	if(!hLR_Calibration.ImportFromFile(sPath) || !hLR_Calibration.GotoFirstSubKey())
	{
		SetFailState("[%s Calibration] file is not found (%s)", PLUGIN_NAME, sPath);
	}

	hLR_Calibration.Rewind();

	if(hLR_Calibration.JumpToKey("Calibration_Settings"))
	{
		g_iCalibrationMode = hLR_Calibration.GetNum("calibration_mode", 1);
		g_iCalibrationPoints = hLR_Calibration.GetNum("calibration_points", 20);
		g_iCalibrationCountKills = hLR_Calibration.GetNum("calibration_countkills", 20);
		if(g_iCalibrationCountKills < 5 || g_iCalibrationCountKills > 50)
		{
			g_iCalibrationCountKills = 20;
		}
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Calibration] section Calibration_Settings is not found (%s)", sPath);
	delete hLR_Calibration;
}

public void LR_OnPlayerKilled(Event hEvent, int& iExpGive, int iExpVictim, int iExpAttacker)
{
	int	iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker")),
		iClient = GetClientOfUserId(GetEventInt(hEvent, "userid")),
		iCorrectiveValue = g_iCalibrationPoints;

	if(g_iCalibrationMode)
	{
		int iValue = (iExpVictim - iExpAttacker) / 2;
		iCorrectiveValue = RoundToNearest(float(iValue > 0 ? iValue : 50) / (g_iCalibrationMode == 1 ? g_iCalibrationCountKills : 1));
	}

	SetCorrectiveValue(iAttacker, iCorrectiveValue);
	SetCorrectiveValue(iClient, -iCorrectiveValue);
}

void SetCorrectiveValue(int iClient, int iValue)
{
	int iKD = LR_GetClientInfo(iClient, ST_KILLS) + LR_GetClientInfo(iClient, ST_DEATHS) + 1;
	if(iKD <= g_iCalibrationCountKills)
	{
		g_iCalibrationCorrectiveValue[iClient] += iValue;

		if(iKD < g_iCalibrationCountKills)
		{
			LR_PrintToChat(iClient, "%T", "CalibrationStatus", iClient, g_iCalibrationCountKills - iKD);
		}
		else
		{
			char sBuffer[16];
			FormatEx(sBuffer, 16, g_iCalibrationCorrectiveValue[iClient] > 0 ? "+%d" : "%d", g_iCalibrationCorrectiveValue[iClient]);
			LR_ChangeClientValue(iClient, g_iCalibrationCorrectiveValue[iClient]);
			LR_PrintToChat(iClient, "%T", "CalibrationStatusFinished", iClient, LR_GetClientInfo(iClient, ST_EXP), sBuffer);
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[8];
	GetClientCookie(iClient, g_hCalibration, sCookie, 8);
	g_iCalibrationCorrectiveValue[iClient] = StringToInt(sCookie);
}

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[8];
		FormatEx(sBuffer, 8, "%i", g_iCalibrationCorrectiveValue[iClient]);
		SetClientCookie(iClient, g_hCalibration, sBuffer);		
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