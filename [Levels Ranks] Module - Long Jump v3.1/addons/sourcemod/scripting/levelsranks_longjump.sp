#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Long Jump"
#define PLUGIN_AUTHOR "RoadSide Romeo & vadrozh"

int		g_iVelocityOffset_0 = -1,
		g_iVelocityOffset_1 = -1,
		g_iBaseVelocityOffset = -1,
		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
float		g_fLJCoef;
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_LongJump", "LR_LongJump", CookieAccess_Private);
	g_iVelocityOffset_0 = GetSendPropOffset("CBasePlayer", "m_vecVelocity[0]");
	g_iVelocityOffset_1 = GetSendPropOffset("CBasePlayer", "m_vecVelocity[1]");
	g_iBaseVelocityOffset = GetSendPropOffset("CBasePlayer", "m_vecBaseVelocity");

	LoadTranslations("lr_module_longjump.phrases");
	HookEvent("player_jump", PlayerJump);
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

public int GetSendPropOffset(const char[] sNetClass, const char[] sPropertyName)
{
	int iOffset = FindSendPropInfo(sNetClass, sPropertyName);
	if(iOffset == -1)
	{
		SetFailState(PLUGIN_NAME ... " : Fatal Error - Offset is not found \"%s::%s\"", sNetClass, sPropertyName);
	}

	return iOffset;
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/longjump.ini");
	KeyValues hLR = new KeyValues("LR_LongJump");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);
	g_fLJCoef = hLR.GetFloat("coef", 2.0);
	if(g_fLJCoef < 1.3)
	{
		g_fLJCoef = 2.0;
	}

	hLR.Close();
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "LJ_On" : "LJ_Off", iClient);
		hMenu.AddItem("LongJump", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "LJ_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("LongJump", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "LongJump"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public Action PlayerJump(Handle hEvent, const char[] sName, bool bDontBroadcast)
{ 
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if((g_iLevel <= LR_GetClientInfo(iClient, ST_RANK)) && !g_bActive[iClient])
	{
		float fVec[3];
		fVec[0] = GetEntDataFloat(iClient, g_iVelocityOffset_0) * 1.2 / g_fLJCoef;
		fVec[1] = GetEntDataFloat(iClient, g_iVelocityOffset_1) * 1.2 / g_fLJCoef;
		fVec[2] = 0.0;
		SetEntDataVector(iClient, g_iBaseVelocityOffset, fVec, true);
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