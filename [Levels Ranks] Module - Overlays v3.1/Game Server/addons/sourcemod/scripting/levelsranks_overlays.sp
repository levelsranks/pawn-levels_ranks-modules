#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Overlays"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bActive[MAXPLAYERS+1],
		g_bAccess;
char		g_sOverlaysPath[128][256];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Overlays", "LR_Overlays", CookieAccess_Private);
	LoadTranslations("lr_module_overlays.phrases");

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
	LR_Hook(LR_OnLevelChangedPost, OnLevelChanged);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	ConfigLoad();
}

void ConfigLoad()
{
	char sPathDownload[256];
	File hFile = OpenFile("addons/sourcemod/configs/levels_ranks/downloads_overlays.ini", "r");
	if(!hFile) SetFailState(PLUGIN_NAME ... " : Unable to load (addons/sourcemod/configs/levels_ranks/downloads_overlays.ini)");
	while(hFile.ReadLine(sPathDownload, sizeof(sPathDownload)))
	{
		TrimString(sPathDownload);
		if(sPathDownload[0])
		{
			AddFileToDownloadsTable(sPathDownload);
		}
	}

	hFile.Close();

	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/overlays.ini");
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
	KeyValues hLR = new KeyValues("LR_Overlays");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Overlays"))
	{
		g_bAccess = view_as<bool>(hLR.GetNum("access", 0));

		hLR.GotoFirstSubKey();
		int iOverlayCount;

		do
		{
			hLR.GetString("overlay", g_sOverlaysPath[iOverlayCount], 256);
			iOverlayCount++;
		}
		while(hLR.GotoNextKey());

		if(iOverlayCount != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Overlays is not found (%s)", sPath);
	hLR.Close();
}

void LR_OnMenuCreated(LR_MenuType OnMenuCreated, int iClient, Menu hMenu)
{
	char sText[64];
	FormatEx(sText, sizeof(sText), "%T", (!g_bActive[iClient] || !g_bAccess) ? "Overlay_MenuOff" : "Overlay_MenuOn", iClient);
	hMenu.AddItem("Overlays", sText, g_bAccess ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuCreated, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Overlays"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	if(!g_bActive[iClient] || !g_bAccess)
	{
		ClientCommand(iClient, "r_screenoverlay %s", g_sOverlaysPath[iNewLevel - 1]);
		CreateTimer(3.0, DeleteOverlay, GetClientUserId(iClient));
	}
}

public Action DeleteOverlay(Handle hTimer, any iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if(iClient && IsClientInGame(iClient))
	{
		ClientCommand(iClient, "r_screenoverlay off");
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