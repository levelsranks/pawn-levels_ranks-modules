#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Neon"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iLevel,
		g_iNeonCount,
		g_iRank[MAXPLAYERS+1],
		g_iNeon[MAXPLAYERS+1],
		g_iNeonChoose[MAXPLAYERS+1];
bool		g_bActive[MAXPLAYERS+1];
char		g_sNeonName[64][32],
		g_sNeonColor[64][96],
		g_sPluginTitle[64];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Neons", "LR_Neons", CookieAccess_Private);
	LoadTranslations("lr_module_neon.phrases");
	HookEvent("player_spawn", Event_Neon);
	HookEvent("player_death", Event_Neon);
	HookEvent("player_team", Event_Neon);

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
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/neons.ini");
	KeyValues hLR = new KeyValues("LR_Neons");
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Settings"))
	{
		g_iLevel = hLR.GetNum("rank", 0);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);

	hLR.Rewind();

	if(hLR.JumpToKey("Colors"))
	{
		g_iNeonCount = 0;
		hLR.GotoFirstSubKey();

		do
		{
			hLR.GetSectionName(g_sNeonName[g_iNeonCount], 32);
			hLR.GetString("color", g_sNeonColor[g_iNeonCount], 96);
			g_iNeonCount++;
		}
		while(hLR.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section Colors is not found (%s)", sPath);
	hLR.Close();
}

public void Event_Neon(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient))
	{
		g_iRank[iClient] = LR_GetClientInfo(iClient, ST_RANK);
		if(sEvName[7] == 's' && !g_bActive[iClient] && g_iRank[iClient] >= g_iLevel)
		{
			SetClientNeon(iClient);
		}
		else RemoveNeon(iClient);
	}
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	g_iRank[iClient] = iNewLevel;
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(g_iRank[iClient] >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", "Neon_RankOpened", iClient);
		hMenu.AddItem("Neons", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Neon_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("Neons", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Neons"))
	{
		NeonsMenu(iClient, 0);
	}
}

public void NeonsMenu(int iClient, int iList)
{
	char sID[4], sText[192];
	Menu hMenu = new Menu(NeonsMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Neon_RankOpened", iClient);

	FormatEx(sText, sizeof(sText), "%T\n ", !g_bActive[iClient] ? "Neon_On" : "Neon_Off", iClient);
	hMenu.AddItem("-1", sText);

	for(int i = 0; i < g_iNeonCount; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sText, sizeof(sText), "%s", g_sNeonName[i]);
		hMenu.AddItem(sID, sText);
	}

	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int NeonsMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
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
			char sID[4];
			hMenu.GetItem(iSlot, sID, sizeof(sID));

			if(StringToInt(sID) == -1)
			{
				if(g_bActive[iClient] && IsPlayerAlive(iClient))
				{
					SetClientNeon(iClient);
				}
				else RemoveNeon(iClient);
				g_bActive[iClient] = !g_bActive[iClient];
			}
			else
			{
				g_iNeonChoose[iClient] = StringToInt(sID);
				if(IsPlayerAlive(iClient) && !g_bActive[iClient]) SetClientNeon(iClient);
			}

			NeonsMenu(iClient, GetMenuSelectionPosition());
		}
	}
}

void SetClientNeon(int iClient)
{
	RemoveNeon(iClient);

	float fClientOrigin[3], fPos[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	fPos[0] = fClientOrigin[0];
	fPos[1] = fClientOrigin[1];
	fPos[2] = fClientOrigin[2] + 30;

	g_iNeon[iClient] = CreateEntityByName("light_dynamic");
	DispatchKeyValue(g_iNeon[iClient], "brightness", "5");

	char str_color[25]; 
	Format(str_color, 25, "%s", g_sNeonColor[g_iNeonChoose[iClient]]);
	DispatchKeyValue(g_iNeon[iClient], "_light", str_color);
	DispatchKeyValue(g_iNeon[iClient], "spotlight_radius", "75");
	DispatchKeyValue(g_iNeon[iClient], "distance", "200");
	DispatchKeyValue(g_iNeon[iClient], "style", "0");
	SetEntPropEnt(g_iNeon[iClient], Prop_Send, "m_hOwnerEntity", iClient);

	if(DispatchSpawn(g_iNeon[iClient]))
	{
		AcceptEntityInput(g_iNeon[iClient], "TurnOn"); TeleportEntity(g_iNeon[iClient], fPos, NULL_VECTOR, NULL_VECTOR); SetVariantString("!activator");
		AcceptEntityInput(g_iNeon[iClient], "SetParent", iClient, g_iNeon[iClient], 0); SDKHook(g_iNeon[iClient], SDKHook_SetTransmit, Hook_Hide);
	}
	else g_iNeon[iClient] = 0;
}

public Action Hook_Hide(int iNeon, int iClient)
{
	int iOwner = GetEntPropEnt(iNeon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1 && GetClientTeam(iOwner) != GetClientTeam(iClient))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void RemoveNeon(int iClient)
{
	if(g_iNeon[iClient] && IsValidEdict(g_iNeon[iClient])) RemoveEntity(g_iNeon[iClient]);
	g_iNeon[iClient] = 0;
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[8], sBuffer[2][4];
	GetClientCookie(iClient, g_hCookie, sCookie, 8);
	ExplodeString(sCookie, ";", sBuffer, 2, 4);

	g_iNeonChoose[iClient] = StringToInt(sBuffer[0]);
	g_bActive[iClient] = view_as<bool>(StringToInt(sBuffer[1]));

	if(g_iNeonChoose[iClient] == -1) g_iNeonChoose[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
	char sBuffer[8];
	FormatEx(sBuffer, 8, "%i;%i;", g_iNeonChoose[iClient], g_bActive[iClient]);
	SetClientCookie(iClient, g_hCookie, sBuffer);

	RemoveNeon(iClient);
	g_iNeonChoose[iClient] = 0;
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
