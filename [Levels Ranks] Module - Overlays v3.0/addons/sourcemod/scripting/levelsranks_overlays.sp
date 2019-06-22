#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

bool		g_bOffOverlay[MAXPLAYERS+1];
char		g_sOverlaysPath[128][256];
Handle	g_hOverlays = null;

public Plugin myinfo = {name = "[LR] Module - Overlays", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS, Engine_SourceSDK2006: {}
		default: SetFailState("[" ... PLUGIN_NAME ... " Overlays] Plug-in works only on CS:GO, CS:S & CS:S v34");
	}
}

public void OnPluginStart()
{
	g_hOverlays = RegClientCookie("LR_Overlays", "LR_Overlays", CookieAccess_Private);
	LoadTranslations("lr_module_overlays.phrases");

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
	char sPathDownload[256];
	File hFile = OpenFile("addons/sourcemod/configs/levels_ranks/downloads_overlays.ini", "r");
	if(!hFile) SetFailState("[" ... PLUGIN_NAME ... " Overlays] Unable to load (addons/sourcemod/configs/levels_ranks/downloads_overlays.ini)");

	while(hFile.ReadLine(sPathDownload, 256))
	{
		TrimString(sPathDownload);
		if(IsCharAlpha(sPathDownload[0]))
		{
			AddFileToDownloadsTable(sPathDownload);
		}
	}
	delete hFile;

	char sPath[PLATFORM_MAX_PATH];
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/overlays.ini");
	KeyValues hLR_Overlay = new KeyValues("LR_Overlays");

	if(!hLR_Overlay.ImportFromFile(sPath) || !hLR_Overlay.GotoFirstSubKey())
	{
		SetFailState("[" ... PLUGIN_NAME ... " Overlays] file is not found (%s)", sPath);
	}

	hLR_Overlay.Rewind();

	if(hLR_Overlay.JumpToKey("Overlays"))
	{
		int iOverlayCount = 0;
		hLR_Overlay.GotoFirstSubKey();

		do
		{
			hLR_Overlay.GetString("overlay", g_sOverlaysPath[iOverlayCount], 256);
			iOverlayCount++;
		}
		while(hLR_Overlay.GotoNextKey());

		if(iOverlayCount != LR_GetCountLevels())
		{
			SetFailState("[" ... PLUGIN_NAME ... " Overlays] the number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Overlays] section Overlays is not found (%s)", sPath);
	delete hLR_Overlay;
}

public void LR_OnMenuCreated(int iClient, Menu& hMenu)
{
	char sText[64];
	FormatEx(sText, 64, "%T", !g_bOffOverlay[iClient] ? "Overlay_MenuOff" : "Overlay_MenuOn", iClient);
	hMenu.AddItem("Overlays", sText);
}

public void LR_OnMenuItemSelected(int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Overlays"))
	{
		g_bOffOverlay[iClient] = !g_bOffOverlay[iClient];
		LR_MenuInventory(iClient);
	}
}

public void LR_OnLevelChanged(int iClient, int iNewLevel, bool bUp)
{
	if(!g_bOffOverlay[iClient])
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
	char sCookie[3];
	GetClientCookie(iClient, g_hOverlays, sCookie, 3);
	g_bOffOverlay[iClient] = view_as<bool>(StringToInt(sCookie));
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[3];
		FormatEx(sBuffer, 3, "%i", g_bOffOverlay[iClient]);
		SetClientCookie(iClient, g_hOverlays, sBuffer);		
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