#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Tag"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bActive[MAXPLAYERS+1],
		g_bAccess;
char		g_sClanTags[128][16];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_TagRank", "LR_TagRank", CookieAccess_Private);
	CreateTimer(1.0, TimerRepeat, _, TIMER_REPEAT);
	LoadTranslations("lr_module_tag.phrases");
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
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/tags.ini");
	KeyValues hLR = new KeyValues("LR_Tags");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Tags"))
	{
		g_bAccess = view_as<bool>(hLR.GetNum("access", 0));

		hLR.GotoFirstSubKey();
		int iTagCount;

		do
		{
			hLR.GetString("tag", g_sClanTags[iTagCount], 16);
			iTagCount++;
		}
		while(hLR.GotoNextKey());

		if(iTagCount != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Tags is not found (%s)", sPath);
	hLR.Close();
}

public Action TimerRepeat(Handle hTimer)
{
	int iRank;
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		iRank = LR_GetClientInfo(iClient, ST_RANK);
		if(IsClientInGame(iClient) && (!g_bActive[iClient] || !g_bAccess) && iRank)
		{
			CS_SetClientClanTag(iClient, g_sClanTags[iRank - 1]);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuCreated, int iClient, Menu hMenu)
{
	if(g_bAccess)
	{
		char sText[64];
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "TagRankOn" : "TagRankOff", iClient);
		hMenu.AddItem("RankTag", sText);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuCreated, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RankTag"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		CS_SetClientClanTag(iClient, g_bActive[iClient] ? NULL_STRING : g_sClanTags[LR_GetClientInfo(iClient, ST_RANK) - 1]);
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
	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}