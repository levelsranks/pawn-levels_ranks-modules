#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Vampirism"
#define PLUGIN_AUTHOR "RoadSide Romeo & Kaneki"

int		g_iLevel,
		g_iHealth,
		g_iHealthMax;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Vampirism", "LR_Vampirism", CookieAccess_Private);
	LoadTranslations("lr_module_vampirism.phrases");
	HookEvent("player_hurt", PlayerHurt);
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/vampirism.ini");
	KeyValues hLR = new KeyValues("LR_Vampirism");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);
	g_iHealth = hLR.GetNum("health", 10);
	g_iHealthMax = hLR.GetNum("maxhealth", 100);

	hLR.Close();
}

public void PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(iClient && IsPlayerAlive(iClient) && !g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{  
        int iRandom = GetRandomInt(1, 5);
        if(iRandom == 3)
		{
	        int iHealth = GetClientHealth(iClient) + g_iHealth;
	
	        if(iHealth > g_iHealthMax)
	        {
		        iHealth = g_iHealthMax;
	        }

	        SetEntityHealth(iClient, iHealth);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "Vamp_On" : "Vamp_Off", iClient);
		hMenu.AddItem("Vamp", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "AG_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("Vamp", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Vamp"))
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