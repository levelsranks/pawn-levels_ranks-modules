#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Skins"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRank[MAXPLAYERS+1],
		g_iSkinsChoose[MAXPLAYERS+1],
		g_iSkinsCount,
		g_iSkinsLevel[129];
char		g_sPluginTitle[64],
		g_sSkinsName[129][32],
		g_sSkinsModel[129][192];
Handle	g_hSkinsCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hSkinsCookie = RegClientCookie("LR_Skins", "LR_Skins", CookieAccess_Private);
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	LoadTranslations("lr_module_skins.phrases");
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
	LR_Hook(LR_OnLevelChangedPost, OnLevelChanged);
	LR_Hook(LR_OnPlayerLoaded, OnLoaded);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad() 
{
	char sPathDownload[256];
	File hFile = OpenFile("addons/sourcemod/configs/levels_ranks/downloads_skins.ini", "r");
	if(!hFile) SetFailState(PLUGIN_NAME ... " : Unable to load (addons/sourcemod/configs/levels_ranks/downloads_skins.ini)");
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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/skins.ini");
	KeyValues hLR = new KeyValues("LR_Skins");
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iSkinsCount = 1;
	hLR.GotoFirstSubKey();
	hLR.Rewind();

	do
	{
		hLR.GetSectionName(g_sSkinsName[g_iSkinsCount], sizeof(g_sSkinsName[]));
		hLR.GetString("skin", g_sSkinsModel[g_iSkinsCount], sizeof(g_sSkinsModel[]));
		PrecacheModel(g_sSkinsModel[g_iSkinsCount], true);
		g_iSkinsLevel[g_iSkinsCount] = hLR.GetNum("rank", 0);
		g_iSkinsCount++;
	}
	while(hLR.GotoNextKey());

	hLR.Close();
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient))
	{
		if(0 < g_iSkinsChoose[iClient] < g_iSkinsCount)
		{
			SetEntityModel(iClient, g_sSkinsModel[g_iSkinsChoose[iClient]]);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	FormatEx(sText, sizeof(sText), "%T", "Skins", iClient, g_iSkinsCount);
	hMenu.AddItem("Skins", sText);
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Skins"))
	{
		SkinsMenu(iClient, 0);
	}
}

public void SkinsMenu(int iClient, int iPos)
{
	char sText[96];
	Menu hMenu = new Menu(SkinsMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Skins", iClient);

	FormatEx(sText, sizeof(sText), "%T", "SkinsDefault", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	for(int i = 1; i < g_iSkinsCount; i++)
	{
		hMenu.AddItem(NULL_STRING, g_sSkinsName[i], (g_iRank[iClient] >= g_iSkinsLevel[i]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iPos, MENU_TIME_FOREVER);
}

public int SkinsMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				LR_ShowMenu(iClient, LR_SettingMenu);
			}
		}
		case MenuAction_Select:
		{
			SkinsMenu(iClient, GetMenuSelectionPosition());
			if(0 < (g_iSkinsChoose[iClient] = iSlot) < g_iSkinsCount && IsPlayerAlive(iClient))
			{
				SetEntityModel(iClient, g_sSkinsModel[g_iSkinsChoose[iClient]]);
			}
		}
	}
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	g_iRank[iClient] = iNewLevel;
	CheckSkin(iClient);
}

void OnLoaded(int iClient, int iAccountID)
{
	g_iRank[iClient] = LR_GetClientInfo(iClient, ST_RANK);
	CheckSkin(iClient);
}

void CheckSkin(int iClient)
{
	for(int i = 1; i < g_iSkinsCount; i++)
	{
		if(g_iSkinsChoose[iClient] == i)
		{	
			if(g_iRank[iClient] < g_iSkinsLevel[i])
			{
				g_iSkinsChoose[iClient] = 0;
				break;
			}
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sBuffer[4];
	GetClientCookie(iClient, g_hSkinsCookie, sBuffer, sizeof(sBuffer));
	g_iSkinsChoose[iClient] = StringToInt(sBuffer);
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[4];
		IntToString(g_iSkinsChoose[iClient], sBuffer, sizeof(sBuffer));
		SetClientCookie(iClient, g_hSkinsCookie, sBuffer);
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