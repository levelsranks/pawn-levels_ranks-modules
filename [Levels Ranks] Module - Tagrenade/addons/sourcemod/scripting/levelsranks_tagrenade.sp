#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Tagrenade"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Tagrenade", "LR_Tagrenade", CookieAccess_Private);
	LoadTranslations("lr_module_tagrenade.phrases");
	HookEvent("player_spawn", PlayerSpawn);
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/tagrenade.ini");
	KeyValues hLR = new KeyValues("Tagrenade");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel && !GetEntProp(iClient, Prop_Data, "m_iAmmo", _, 22))
	{
		GivePlayerItem(iClient, "weapon_tagrenade");
	}
}

public Action CS_OnCSWeaponDrop(int iClient, int iWeapon)
{
	if(IsClientInGame(iClient) && GetClientHealth(iClient) < 1 && IsValidEdict(iWeapon))
	{
		char sClassname[32];
		GetEdictClassname(iWeapon, sClassname, 16);
		if(!strcmp(sClassname[7], "tagrenade")) AcceptEntityInput(iWeapon, "Kill");
	}
	
	return Plugin_Continue;
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "Tagrenade_On" : "Tagrenade_Off", iClient);
		hMenu.AddItem("Tagrenade", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Tagrenade_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("Tagrenade", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Tagrenade"))
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