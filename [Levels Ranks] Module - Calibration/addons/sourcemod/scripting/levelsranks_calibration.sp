#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Calibration"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iCalibrationCorrectiveValue[MAXPLAYERS+1],
		g_iCalibrationMode,
		g_iCalibrationPoints,
		g_iCalibrationCountKills;
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_calibration.phrases");
		case Engine_SourceSDK2006: LoadTranslations("lr_module_calibration_old.phrases");
	}

	g_hCookie = RegClientCookie("LR_Calibration", "LR_Calibration", CookieAccess_Private);
	ConfigLoad();

	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}
}

public void LR_OnCoreIsReady()
{
	if(!LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 1 or 2 ]");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_Hook(LR_OnPlayerKilledPre, view_as<LR_HookCB>(LR_OnPlayerKilled));
}

void ConfigLoad()
{
	static char sPath[256];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/calibration.ini");
	KeyValues hLR = new KeyValues("LR_Calibration");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iCalibrationMode = hLR.GetNum("calibration_mode", 1);
	g_iCalibrationPoints = hLR.GetNum("calibration_points", 20);
	g_iCalibrationCountKills = hLR.GetNum("calibration_countkills", 20);

	if(g_iCalibrationCountKills < 5 || g_iCalibrationCountKills > 50)
	{
		g_iCalibrationCountKills = 20;
	}

	hLR.Close();
}

public void LR_OnPlayerKilled(Event hEvent, int& iExpGive, int iExpVictim, int iExpAttacker)
{
	if(LR_CheckCountPlayers())
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
}

void SetCorrectiveValue(int iClient, int iValue)
{
	int iKD = LR_GetClientInfo(iClient, ST_KILLS) + LR_GetClientInfo(iClient, ST_DEATHS) + 1;

	if(iKD <= g_iCalibrationCountKills)
	{
		int iNumber = iValue + g_iCalibrationCorrectiveValue[iClient];
		g_iCalibrationCorrectiveValue[iClient] = (iKD == 1 ? 0 : iNumber);

		if(iKD < g_iCalibrationCountKills)
		{
			LR_PrintToChat(iClient, true, "%T", "CalibrationStatus", iClient, g_iCalibrationCountKills - iKD);
		}
		else
		{
			char sBuffer[16];
			FormatEx(sBuffer, sizeof(sBuffer), g_iCalibrationCorrectiveValue[iClient] > 0 ? "+%d" : "%d", g_iCalibrationCorrectiveValue[iClient]);
			LR_ChangeClientValue(iClient, g_iCalibrationCorrectiveValue[iClient]);
			LR_PrintToChat(iClient, true, "%T", "CalibrationStatusFinished", iClient, LR_GetClientInfo(iClient, ST_EXP), sBuffer);
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[8];
	GetClientCookie(iClient, g_hCookie, sCookie, sizeof(sCookie));
	g_iCalibrationCorrectiveValue[iClient] = StringToInt(sCookie);
}

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[8];
		IntToString(g_iCalibrationCorrectiveValue[iClient], sBuffer, sizeof(sBuffer));
		SetClientCookie(iClient, g_hCookie, sBuffer);		
	}
}

public void OnPluginEnd()
{
	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}