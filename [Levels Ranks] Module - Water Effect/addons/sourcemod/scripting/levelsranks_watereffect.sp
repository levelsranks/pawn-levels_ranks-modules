#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "[LR] Module - Water Effect"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO & Vertigo™"

#define EFFECT		"water_splash_01_droplets"

int				g_iLevel;
bool			g_bActive[MAXPLAYERS+1];
Handle			g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = "3.1"};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_WaterEffect", "LR_WaterEffect", CookieAccess_Private);
	LoadTranslations("lr_module_watereffect.phrases");
	
	HookEvent("player_hurt", Event_OnPlayerHurt);
	
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
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/watereffect.ini");
	KeyValues hLR = new KeyValues("LR_WaterEffect");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (iAttacker && IsClientInGame(iAttacker) && !g_bActive[iAttacker] && LR_GetClientInfo(iAttacker, ST_RANK) >= g_iLevel)
	{
		SetVariantString("WaterSurfaceExplosion");
		AcceptEntityInput(GetClientOfUserId(event.GetInt("userid")), "DispatchEffect");
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "WE_On" : "WE_Off", iClient);
		hMenu.AddItem("WaterEffect", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "WE_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("WaterEffect", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "WaterEffect"))
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