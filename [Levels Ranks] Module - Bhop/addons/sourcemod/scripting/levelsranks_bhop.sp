#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Bhop"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iRank[MAXPLAYERS+1],
		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Bhop", "LR_Bhop", CookieAccess_Private);
	LoadTranslations("lr_module_bhop.phrases");
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
	LR_Hook(LR_OnPlayerLoaded, OnLoadPlayer);
	LR_Hook(LR_OnLevelChangedPost, OnLevelChanged);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/bhop.ini");
	KeyValues hLR = new KeyValues("LR_Bhop");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

void OnLoadPlayer(int iClient, int iAccountID)
{
	g_iRank[iClient] = LR_GetClientInfo(iClient, ST_RANK);
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	g_iRank[iClient] = iNewLevel;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons)
{
	if(IsPlayerAlive(iClient) && iButtons & IN_JUMP && !g_bActive[iClient] && g_iRank[iClient] >= g_iLevel && !(GetEntityFlags(iClient) & FL_ONGROUND) && !(GetEntityMoveType(iClient) & MOVETYPE_LADDER))
	{
		iButtons &= ~IN_JUMP;
	}
}  

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "Bhop_On" : "Bhop_Off", iClient);
		hMenu.AddItem("Bhop", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Bhop_Closed", iClient, g_iLevel);
		hMenu.AddItem("Bhop", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Bhop"))
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