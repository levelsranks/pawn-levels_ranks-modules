#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bOffTag[MAXPLAYERS+1];
char		g_sClanTags[128][16];
Handle	g_hTagRank = null;

public Plugin myinfo = {name = "[LR] Module - Tag", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LogMessage("[" ... PLUGIN_NAME ... " Tag] Successfully launched");
		default: SetFailState("[" ... PLUGIN_NAME ... " Tag] Plug-in works only on CS:GO & CS:S");
	}
}

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	g_hTagRank = RegClientCookie("LR_TagRank", "LR_TagRank", CookieAccess_Private);
	LoadTranslations("lr_module_tag.phrases");

	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient) && AreClientCookiesCached(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}
}

public void LR_OnCoreIsReady()
{
	ConfigLoad();
}

public void OnMapStart()
{
	ConfigLoad();
}

public void LR_OnSettingsModuleUpdate()
{
	ConfigLoad();
}

void ConfigLoad()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/tags.ini");
	KeyValues hLR_Tags = new KeyValues("LR_Tags");

	if(!hLR_Tags.ImportFromFile(sPath) || !hLR_Tags.GotoFirstSubKey())
	{
		SetFailState("[" ... PLUGIN_NAME ... " Tags] file is not found (%s)", sPath);
	}

	hLR_Tags.Rewind();

	if(hLR_Tags.JumpToKey("Tags"))
	{
		int iTagCount = 0;
		hLR_Tags.GotoFirstSubKey();

		do
		{
			hLR_Tags.GetString("tag", g_sClanTags[iTagCount], 16);
			iTagCount++;
		}
		while(hLR_Tags.GotoNextKey());

		if(iTagCount != LR_GetCountLevels())
		{
			SetFailState("[" ... PLUGIN_NAME ... " Tags] the number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Tags] section Tags is not found (%s)", sPath);
	delete hLR_Tags;
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && LR_GetClientStatus(iClient) && !g_bOffTag[iClient])
	{
		CS_SetClientClanTag(iClient, g_sClanTags[LR_GetClientInfo(iClient, ST_RANK) - 1]);
	}
}

public void LR_OnMenuCreated(int iClient, Menu& hMenu)
{
	char sText[64];
	FormatEx(sText, 64, "%T", !g_bOffTag[iClient] ? "TagRankOn" : "TagRankOff", iClient);
	hMenu.AddItem("RankTag", sText);
}

public void LR_OnMenuItemSelected(int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "RankTag"))
	{
		g_bOffTag[iClient] = !g_bOffTag[iClient];
		CS_SetClientClanTag(iClient, g_bOffTag[iClient] ? "" : g_sClanTags[LR_GetClientInfo(iClient, ST_RANK) - 1]);
		LR_MenuInventory(iClient);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sBuffer[3];
	GetClientCookie(iClient, g_hTagRank, sBuffer, 3);
	g_bOffTag[iClient] = view_as<bool>(StringToInt(sBuffer));
}

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[3];
		FormatEx(sBuffer, 3, "%i", g_bOffTag[iClient]);
		SetClientCookie(iClient, g_hTagRank, sBuffer);	
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