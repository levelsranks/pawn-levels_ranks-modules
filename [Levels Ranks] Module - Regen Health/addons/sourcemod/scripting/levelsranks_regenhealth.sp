#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Regen Health"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iLevel,
		g_iRHHealth,
		g_iRHMaxHealth;
bool		g_bActive[MAXPLAYERS+1];
float		g_fRHTime;
Handle	g_hCookie,
		g_hRHTimer[MAXPLAYERS+1];

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_RegenHealth", "LR_RegenHealth", CookieAccess_Private);
	LoadTranslations("lr_module_regenhealth.phrases");
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/regenhealth.ini");
	KeyValues hLR = new KeyValues("LR_RegenHealth");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);
	g_fRHTime = hLR.GetFloat("time", 1.0);
	g_iRHMaxHealth = hLR.GetNum("maxhealth", 125);
	g_iRHHealth = hLR.GetNum("health", 5);
	hLR.Close();

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(g_hRHTimer[iClient] != null)
		{
			KillTimer(g_hRHTimer[iClient]);
			g_hRHTimer[iClient] = null;
		}

		if(IsClientInGame(iClient))
		{
			g_hRHTimer[iClient] = CreateTimer(g_fRHTime, TimerRegen, GetClientUserId(iClient), TIMER_REPEAT);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "RH_On" : "RH_Off", iClient);
		hMenu.AddItem("RegenHealth", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "RH_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("RegenHealth", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RegenHealth"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if(iClient && IsClientInGame(iClient))
	{
		g_hRHTimer[iClient] = CreateTimer(g_fRHTime, TimerRegen, GetClientUserId(iClient), TIMER_REPEAT);
	}
}

public Action TimerRegen(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(iClient && IsClientInGame(iClient) && GetClientTeam(iClient) > 1 && IsPlayerAlive(iClient) && !g_bActive[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel))
	{
		int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth") + g_iRHHealth;
		if(iHealth > g_iRHMaxHealth)
		{
			iHealth = g_iRHMaxHealth;
		}

		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
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
	if(g_hRHTimer[iClient] != null)
	{
		KillTimer(g_hRHTimer[iClient]);
		g_hRHTimer[iClient] = null;
	}

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