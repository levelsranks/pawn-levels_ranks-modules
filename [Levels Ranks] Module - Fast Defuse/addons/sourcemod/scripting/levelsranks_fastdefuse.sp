#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Fast Defuse"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iLevel,
		m_flDefuseCountDown,
		m_iProgressBarDuration;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	m_flDefuseCountDown = FindSendPropInfo("CPlantedC4", "m_flDefuseCountDown");
	m_iProgressBarDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration");

	g_hCookie = RegClientCookie("LR_FastDefuse", "LR_FastDefuse", CookieAccess_Private);
	LoadTranslations("lr_module_fastdefuse.phrases");
	HookEvent("bomb_begindefuse", PlayerBeginDefuse);
	ConfigLoad();

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad() 
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/fastdefuse.ini");
	KeyValues hLR = new KeyValues("LR_FastDefuse");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

public void PlayerBeginDefuse(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel && !g_bActive[iClient])
	{
		RequestFrame(OnRequestFrame, iClient);
	}
}

public void OnRequestFrame(any iClient)
{
	if(IsClientInGame(iClient))
	{
		int iBombEntity = FindEntityByClassname(-1, "planted_c4");
		if(iBombEntity > 0)
		{
			float fGameTime = GetGameTime();
			float fCountDown = GetEntDataFloat(iBombEntity, m_flDefuseCountDown) - fGameTime;
			fCountDown -= fCountDown;
			//fCountDown -= fCountDown / 100.0 * float(100);
			SetEntDataFloat(iBombEntity, m_flDefuseCountDown, fGameTime + fCountDown, true);
			SetEntData(iClient, m_iProgressBarDuration, RoundToCeil(fCountDown));
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "FD_On" : "FD_Off", iClient);
		hMenu.AddItem("FastDefuse", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "FD_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("FastDefuse", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "FastDefuse"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hCookie, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hCookie, sCookie);
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