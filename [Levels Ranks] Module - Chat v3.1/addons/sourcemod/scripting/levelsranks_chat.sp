#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Chat"
#define PLUGIN_AUTHOR "RoadSide Romeo"

////////////////////////////////////////////////////////////////////////////////////////////////////
// Identify colors
int				g_iColors_CSSOB[] = {0xFFFFFF, 0xFF0000, 0x00AD00, 0x00FF00, 0x99FF99, 0xFF4040, 0xCCCCCC, 0xFFBD6B, 0xFA8B00, 0x99CCFF, 0x3D46FF, 0xFA00FA};
char				g_sColors_CSOLD[][] = {"\x01", "\x03", "\x04"},
				g_sColors_CSGO[][] = {"\x03", "\x01", "\x02", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E"};
char				g_sMenuItems_CSOLD[][] = {"Default", "Team", "Green"},
				g_sMenuItems_OTHER[][] = {"Team", "White", "Red", "Green", "Lime", "Lightgreen", "Lightred", "Gray", "Lightolive", "Olive", "Lightblue", "Blue", "Purple"};
char				g_sReadyColors[13][32];

////////////////////////////////////////////////////////////////////////////////////////////////////
// Config - section Prefixs_All
int				g_iSettings_MainTagStartColor,
				g_iSettings_MainTagEndColor;
bool				g_bSettings_MainForce,
				g_bSettings_MainFullAccess,
				g_bSettings_MainTagPrefixColor;
char				g_sSettings_MainTagStart[32],
				g_sSettings_MainTagEnd[32];

////////////////////////////////////////////////////////////////////////////////////////////////////
// Config - section Prefixs_Private
int				g_iSettings_SpecCount,
				g_iSettings_SpecColor_Prefix[129],
				g_iSettings_SpecColor_Name[129],
				g_iSettings_SpecColor_Message[129];
bool				g_bSettings_SpecColorForce;
char				g_sSettings_SpecPrefix[129][64],
				g_sSettings_SpecAuth[129][32];

////////////////////////////////////////////////////////////////////////////////////////////////////
// Config - section Prefixs
int				g_iSettings_PlayerColor_Prefix[129],
				g_iSettings_PlayerColor_Name[129],
				g_iSettings_PlayerColor_Message[129];
char				g_sSettings_Prefix[129][64];

////////////////////////////////////////////////////////////////////////////////////////////////////
// Personally
int				g_iRank[MAXPLAYERS+1],
				g_iPlayer_ColorPrefix[MAXPLAYERS+1],
				g_iPlayer_ColorName[MAXPLAYERS+1],
				g_iPlayer_ColorMessage[MAXPLAYERS+1];
bool				g_bPlayer_NotNewbee[MAXPLAYERS+1],
				g_bPlayer_PrefixSpecial[MAXPLAYERS+1],
				g_bPlayer_ClearChat[MAXPLAYERS+1];
char				g_sPlayerPrefix[MAXPLAYERS+1][64],
				g_sSteamID[MAXPLAYERS+1][32];

////////////////////////////////////////////////////////////////////////////////////////////////////

char				g_sPluginTitle[64];
Handle			g_hChat;
EngineVersion	EngineGame;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	switch(EngineGame = GetEngineVersion())
	{
		case Engine_CSGO:
		{
			for(int i = 0; i < 13; i++)
			{
				FormatEx(g_sReadyColors[i], sizeof(g_sReadyColors[]), "%s", g_sColors_CSGO[i]);
			}
		}

		case Engine_CSS:
		{
			for(int i = 0; i < 13; i++)
			{
				if(!i)
				{
					FormatEx(g_sReadyColors[i], sizeof(g_sReadyColors[]), "{TEAM}");
				}
				else FormatEx(g_sReadyColors[i], sizeof(g_sReadyColors[]), "\x07%06X", g_iColors_CSSOB[i]);
			}
		}

		case Engine_SourceSDK2006:
		{
			for(int i = 0; i < 3; i++)
			{
				FormatEx(g_sReadyColors[i], sizeof(g_sReadyColors[]), "%s", g_sColors_CSOLD[i]);
			}
		}
		default: SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO, CS:S OB or v34");
	}

	g_hChat = RegClientCookie("LR_Chat", "LR_Chat", CookieAccess_Private);
	LoadTranslations("lr_module_chat.phrases");

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_Hook(LR_OnPlayerLoaded, OnPlayerLoaded);
	LR_Hook(LR_OnLevelChangedPost, OnLevelChanged);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), EngineGame == Engine_SourceSDK2006 ? "configs/levels_ranks/chat_old.ini" : "configs/levels_ranks/chat.ini");
	KeyValues hLR = new KeyValues("LR_Chat");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Prefixs_All"))
	{
		g_bSettings_MainFullAccess = view_as<bool>(hLR.GetNum("color_off", 0));
		g_bSettings_MainForce = view_as<bool>(hLR.GetNum("color_force", 0));
		hLR.GetString("chat_tagstart", g_sSettings_MainTagStart, sizeof(g_sSettings_MainTagStart), "");
		hLR.GetString("chat_tagend", g_sSettings_MainTagEnd, sizeof(g_sSettings_MainTagEnd), "");

		g_bSettings_MainTagPrefixColor = view_as<bool>(hLR.GetNum("color_tagprefix", 1));
		g_iSettings_MainTagStartColor = hLR.GetNum("color_tagstart", 0);
		g_iSettings_MainTagEndColor = hLR.GetNum("color_tagend", 0);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Prefixs_All is not found (%s)", sPath);

	hLR.Rewind();

	if(hLR.JumpToKey("Prefixs_Private"))
	{
		g_bSettings_SpecColorForce = view_as<bool>(hLR.GetNum("color_private_force", 1));

		g_iSettings_SpecCount = 0;
		if(hLR.GotoFirstSubKey())
		{
			do
			{
				hLR.GetSectionName(g_sSettings_SpecAuth[g_iSettings_SpecCount], sizeof(g_sSettings_SpecAuth[]));
				hLR.GetString("prefix", g_sSettings_SpecPrefix[g_iSettings_SpecCount], sizeof(g_sSettings_SpecPrefix[]));
				g_iSettings_SpecColor_Prefix[g_iSettings_SpecCount] = hLR.GetNum("color_prefix", 0);
				g_iSettings_SpecColor_Name[g_iSettings_SpecCount] = hLR.GetNum("color_name", 0);
				g_iSettings_SpecColor_Message[g_iSettings_SpecCount++] = hLR.GetNum("color_message", 0);
			}
			while(hLR.GotoNextKey());
		}
	}
	else SetFailState(PLUGIN_NAME ... " : Section Prefixs_Private is not found (%s)", sPath);

	hLR.Rewind();

	if(hLR.JumpToKey("Prefixs"))
	{
		if(hLR.GotoFirstSubKey())
		{
			int iCount;
			do
			{
				iCount++;
				hLR.GetString("prefix", g_sSettings_Prefix[iCount], sizeof(g_sSettings_Prefix[]));
				g_iSettings_PlayerColor_Prefix[iCount] = hLR.GetNum("color_prefix", 0);
				g_iSettings_PlayerColor_Name[iCount] = hLR.GetNum("color_name", 0);
				g_iSettings_PlayerColor_Message[iCount] = hLR.GetNum("color_message", 0);
			}
			while(hLR.GotoNextKey());
			if(iCount != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState(PLUGIN_NAME ... " : Section Prefixs is not found (%s)", sPath);
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnPlayerLoaded(iClient, GetSteamAccountID(iClient));
		}
	}

	hLR.Close();
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	if(!((g_bSettings_MainForce || (g_bPlayer_PrefixSpecial[iClient] && g_bSettings_SpecColorForce)) && !g_bSettings_MainFullAccess))
	{
		char sText[64];
		FormatEx(sText, sizeof(sText), "%T", "Chat", iClient);
		hMenu.AddItem("ChatPrefix", sText);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "ChatPrefix"))
	{
		ChatMenu(iClient);
	}
}

void ChatMenu(int iClient)
{
	char sText[128];
	Menu hMenu = new Menu(ChatMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Chat", iClient);

	FormatEx(sText, sizeof(sText), "%T\n ", !g_bPlayer_ClearChat[iClient] ? "Chat_Off" : "Chat_On", iClient); hMenu.AddItem(NULL_STRING, sText);

	int iShow = (g_bSettings_MainForce || (g_bPlayer_PrefixSpecial[iClient] && g_bSettings_SpecColorForce)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
	FormatEx(sText, sizeof(sText), "%T", "Prefix_Color", iClient); hMenu.AddItem(NULL_STRING, sText, iShow);
	FormatEx(sText, sizeof(sText), "%T", "Name_Color", iClient); hMenu.AddItem(NULL_STRING, sText, iShow);
	FormatEx(sText, sizeof(sText), "%T", "Text_Color", iClient); hMenu.AddItem(NULL_STRING, sText, iShow);

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int ChatMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) LR_ShowMenu(iClient, LR_SettingMenu);
		case MenuAction_Select:
		{
			if(!iSlot)
			{
				g_bPlayer_ClearChat[iClient] = !g_bPlayer_ClearChat[iClient];
				ChatMenu(iClient);
				return;
			}
			ChatMenuSettings(iClient, 0, iSlot);
		}
	}
}

void ChatMenuSettings(int iClient, int iList, int iType)
{
	char sBuffer[4], sText[128];
	Menu hMenu = new Menu(ChatMenuSettingsHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, iType == 1 ? "Prefix_Color" : iType == 2 ? "Name_Color" : "Text_Color", iClient);
	hMenu.ExitBackButton = true;

	IntToString(iType, sBuffer, sizeof(sBuffer));
	if(EngineGame == Engine_SourceSDK2006)
	{
		for(int i = 0; i < 3; i++)
		{
			FormatEx(sText, sizeof(sText), "%T", g_sMenuItems_CSOLD[i], iClient); hMenu.AddItem(sBuffer, sText);
		}
	}
	else
	{
		for(int i = 0; i < 13; i++)
		{
			FormatEx(sText, sizeof(sText), "%T", g_sMenuItems_OTHER[i], iClient); hMenu.AddItem(sBuffer, sText);
		}
	}
	hMenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int ChatMenuSettingsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) ChatMenu(iClient);
		case MenuAction_Select:
		{
			char sInfo[4];
			hMenu.GetItem(iSlot, sInfo, 4);
			int iType = StringToInt(sInfo);

			switch(iType)
			{
				case 1: g_iPlayer_ColorPrefix[iClient] = iSlot;
				case 2: g_iPlayer_ColorName[iClient] = iSlot;
				case 3: g_iPlayer_ColorMessage[iClient] = iSlot;
			}

			ChatMenuSettings(iClient, GetMenuSelectionPosition(), iType);
		}
	}
}

#pragma newdecls optional
#undef REQUIRE_PLUGIN
#include <scp>
#define REQUIRE_PLUGIN
#pragma newdecls required

public Action OnChatMessage(int& iClient, Handle hRecipients, char[] sName, char[] sMessage)
{
	if(iClient && IsClientInGame(iClient) && !g_bPlayer_ClearChat[iClient])
	{
		char sBufferStartTag[32], sBufferEndTag[32];
		FormatEx(sBufferStartTag, sizeof(sBufferStartTag), "%s%s", g_sReadyColors[ g_bSettings_MainTagPrefixColor ? g_iPlayer_ColorPrefix[iClient] : g_iSettings_MainTagStartColor ], g_sSettings_MainTagStart);
		FormatEx(sBufferEndTag, sizeof(sBufferEndTag), "%s%s", g_sReadyColors[ g_bSettings_MainTagPrefixColor ? g_iPlayer_ColorPrefix[iClient] : g_iSettings_MainTagEndColor ], g_sSettings_MainTagEnd);

		Format(sName, MAXLENGTH_NAME, "%s%s%s%s%s %s%s", EngineGame == Engine_CSGO ? " \x01" : "\x01", sBufferStartTag, g_sReadyColors[g_iPlayer_ColorPrefix[iClient]], g_sPlayerPrefix[iClient], sBufferEndTag, g_sReadyColors[g_iPlayer_ColorName[iClient]], sName);
		Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sReadyColors[g_iPlayer_ColorMessage[iClient]], sMessage);

		if(EngineGame == Engine_CSS)
		{
			char sColor[16];
			static const int iColors[] = {0xFFFFFF, 0xCCCCCC, 0xFF4040, 0x99CCFF};

			FormatEx(sColor, sizeof(sColor), "\x07%06X", iColors[GetClientTeam(iClient)]);
			ReplaceString(sName, MAXLENGTH_NAME, "{TEAM}", sColor);
			ReplaceString(sMessage, MAXLENGTH_MESSAGE, "{TEAM}", sColor);
		}

		return Plugin_Changed;
	}
	return Plugin_Continue;
}

#undef MAXLENGTH_NAME
#undef MAXLENGTH_MESSAGE
#undef REQUIRE_PLUGIN
#include <chat-processor>
#define REQUIRE_PLUGIN

public Action CP_OnChatMessage(int& iClient, ArrayList hRecipients, char[] sFlagstring, char[] sName, char[] sMessage, bool& bProcessColors, bool& bRemoveColors)
{
	if(iClient && IsClientInGame(iClient) && !g_bPlayer_ClearChat[iClient])
	{
		char sBufferStartTag[32], sBufferEndTag[32];
		FormatEx(sBufferStartTag, sizeof(sBufferStartTag), "%s%s", g_sReadyColors[ g_bSettings_MainTagPrefixColor ? g_iPlayer_ColorPrefix[iClient] : g_iSettings_MainTagStartColor ], g_sSettings_MainTagStart);
		FormatEx(sBufferEndTag, sizeof(sBufferEndTag), "%s%s", g_sReadyColors[ g_bSettings_MainTagPrefixColor ? g_iPlayer_ColorPrefix[iClient] : g_iSettings_MainTagEndColor ], g_sSettings_MainTagEnd);

		Format(sName, MAXLENGTH_NAME, "%s%s%s%s%s %s%s", EngineGame == Engine_CSGO ? " \x01" : "\x01", sBufferStartTag, g_sReadyColors[g_iPlayer_ColorPrefix[iClient]], g_sPlayerPrefix[iClient], sBufferEndTag, g_sReadyColors[g_iPlayer_ColorName[iClient]], sName);
		Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sReadyColors[g_iPlayer_ColorMessage[iClient]], sMessage);

		if(EngineGame == Engine_CSS)
		{
			char sColor[16];
			static const int iColors[] = {0xFFFFFF, 0xCCCCCC, 0xFF4040, 0x99CCFF};

			FormatEx(sColor, sizeof(sColor), "\x07%06X", iColors[GetClientTeam(iClient)]);
			ReplaceString(sName, MAXLENGTH_NAME, "{TEAM}", sColor);
			ReplaceString(sMessage, MAXLENGTH_MESSAGE, "{TEAM}", sColor);
		}

		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void CheckSpecialPrefix(int iClient)
{
	int		iCount,
			iFlagClient = GetUserFlagBits(iClient);

	g_bPlayer_PrefixSpecial[iClient] = false;
	for(; iCount != g_iSettings_SpecCount; iCount++)
	{
		if(g_sSettings_SpecAuth[iCount][5] == '_')
		{
			if((g_bPlayer_PrefixSpecial[iClient] = !strcmp(g_sSettings_SpecAuth[iCount], g_sSteamID[iClient], false))) break;
		}
		else if((g_bPlayer_PrefixSpecial[iClient] = ((iFlagClient & ReadFlagString(g_sSettings_SpecAuth[iCount])) == ReadFlagString(g_sSettings_SpecAuth[iCount])))) break;
	}

	if(g_bSettings_MainForce)
	{
		g_iPlayer_ColorPrefix[iClient] = g_bPlayer_PrefixSpecial[iClient] ? g_iSettings_SpecColor_Prefix[iCount] : g_iSettings_PlayerColor_Prefix[g_iRank[iClient]];
		g_iPlayer_ColorName[iClient] = g_bPlayer_PrefixSpecial[iClient] ? g_iSettings_SpecColor_Name[iCount] : g_iSettings_PlayerColor_Name[g_iRank[iClient]];
		g_iPlayer_ColorMessage[iClient] = g_bPlayer_PrefixSpecial[iClient] ? g_iSettings_SpecColor_Message[iCount] : g_iSettings_PlayerColor_Message[g_iRank[iClient]];
	}
	else
	{
		if(g_bPlayer_PrefixSpecial[iClient] && (g_bSettings_SpecColorForce || !g_bPlayer_NotNewbee[iClient]))
		{
			g_iPlayer_ColorPrefix[iClient] = g_iSettings_SpecColor_Prefix[iCount];
			g_iPlayer_ColorName[iClient] = g_iSettings_SpecColor_Name[iCount];
			g_iPlayer_ColorMessage[iClient] = g_iSettings_SpecColor_Message[iCount];
			g_bPlayer_NotNewbee[iClient] = true;
		}
		else if(!g_bPlayer_NotNewbee[iClient])
		{
			g_iPlayer_ColorPrefix[iClient] = g_iSettings_PlayerColor_Prefix[g_iRank[iClient]];
			g_iPlayer_ColorName[iClient] = g_iSettings_PlayerColor_Name[g_iRank[iClient]];
			g_iPlayer_ColorMessage[iClient] = g_iSettings_PlayerColor_Message[g_iRank[iClient]];
			g_bPlayer_NotNewbee[iClient] = true;
		}
	}

	FormatEx(g_sPlayerPrefix[iClient], sizeof(g_sPlayerPrefix[]), "%s", g_bPlayer_PrefixSpecial[iClient] ? g_sSettings_SpecPrefix[iCount] : g_sSettings_Prefix[g_iRank[iClient]]);
}

void OnPlayerLoaded(int iClient, int iAccountID)
{
	g_iRank[iClient] = LR_GetClientInfo(iClient, ST_RANK);
	FormatEx(g_sSteamID[iClient], sizeof(g_sSteamID[]), "STEAM_%i:%i:%i", EngineGame == Engine_CSGO, iAccountID & 1, iAccountID >>> 1);
	CheckSpecialPrefix(iClient);
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	g_iRank[iClient] = iNewLevel;
	CheckSpecialPrefix(iClient);
}

public void OnClientCookiesCached(int iClient)
{
	char sBuffer[5][4], sCookie[20];
	GetClientCookie(iClient, g_hChat, sCookie, 16);
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));

	g_bPlayer_NotNewbee[iClient] = view_as<bool>(StringToInt(sBuffer[0]));
	g_bPlayer_ClearChat[iClient] = view_as<bool>(StringToInt(sBuffer[1]));
	g_iPlayer_ColorPrefix[iClient] = StringToInt(sBuffer[2]);
	g_iPlayer_ColorName[iClient] = StringToInt(sBuffer[3]);
	g_iPlayer_ColorMessage[iClient] = StringToInt(sBuffer[4]);
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[20];
		FormatEx(sBuffer, 20, "%i;%i;%i;%i;%i;", g_bPlayer_NotNewbee[iClient], g_bPlayer_ClearChat[iClient], g_iPlayer_ColorPrefix[iClient], g_iPlayer_ColorName[iClient], g_iPlayer_ColorMessage[iClient]);
		SetClientCookie(iClient, g_hChat, sBuffer);
	}

	g_sPlayerPrefix[iClient] = NULL_STRING;
	g_bPlayer_NotNewbee[iClient] = false;
	g_bPlayer_ClearChat[iClient] = false;
	g_iPlayer_ColorPrefix[iClient] = 0;
	g_iPlayer_ColorName[iClient] = 0;
	g_iPlayer_ColorMessage[iClient] = 0;
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