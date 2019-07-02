#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iColorsCSS[] = {0xFFFFFF, 0xFF0000, 0x00AD00, 0x00FF00, 0x99FF99, 0xFF4040, 0xCCCCCC, 0xFFBD6B, 0xFA8B00, 0x99CCFF, 0x3D46FF, 0xFA00FA},
		g_iPrefixColor[MAXPLAYERS+1],
		g_iNameColor[MAXPLAYERS+1],
		g_iTextColor[MAXPLAYERS+1],
		g_iCountPrivatePrefix,
		g_iTagStartColor,
		g_iTagEndColor,
		g_iColorRankPrefix[128],
		g_iColorRankName[128],
		g_iColorRankMessage[128];
bool		g_bChatOff[MAXPLAYERS+1],
		g_bPrivatePrefix[MAXPLAYERS+1],
		g_bNew[MAXPLAYERS+1],
		g_bColorOff,
		g_bColorForce;
char		g_sColors_Game[12][32],
		g_sSteamID[MAXPLAYERS+1],
		g_sSpecialPrefixClient[MAXPLAYERS+1][32],
		g_sColorsCS[][] = {"\x01", "\x03", "\x04"},
		g_sColorsCSGO[][] = {"\x01", "\x02", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E"},
		g_sMenuItemsCS[][] = {"Default", "Team", "Green"},
		g_sMenuItemsCSGO[][] = {"White", "Red", "Green", "Lime", "Lightgreen", "Lightred", "Gray", "Lightolive", "Olive", "Lightblue", "Blue", "Purple"},
		g_sPrefixTagStart[32],
		g_sPrefixTagEnd[32],
		g_sPrefixNames[128][64],
		g_sSpecialPrefixBlock[128][64],
		g_sSpecialPrefix[128][64],
		g_sPluginTitle[64];
Handle	g_hChat;
EngineVersion EngineGame;

public Plugin myinfo = {name = "[LR] Module - Chat", author = PLUGIN_AUTHOR, version = "v3.0 SR1"}
public void OnPluginStart()
{
	switch(EngineGame = GetEngineVersion())
	{
		case Engine_CSGO:
		{
			for(int i = 0; i < 12; i++)
			{
				FormatEx(g_sColors_Game[i], 32, "%s", g_sColorsCSGO[i]);
			}
		}

		case Engine_CSS:
		{
			for(int i = 0; i < 12; i++)
			{
				FormatEx(g_sColors_Game[i], 32, "\x07%06X", g_iColorsCSS[i]);
			}
		}

		case Engine_SourceSDK2006:
		{
			for(int i = 0; i < 3; i++)
			{
				FormatEx(g_sColors_Game[i], 32, "%s", g_sColorsCS[i]);
			}
		}

		default: SetFailState("[" ... PLUGIN_NAME ... " Chat] Plug-in works only on CS:GO, CS:S OB or v34");
	}

	g_hChat = RegClientCookie("LR_Chat", "LR_Chat", CookieAccess_Private);
	LoadTranslations("lr_module_chat.phrases");
	
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
	char sPath[256];
	BuildPath(Path_SM, sPath, sizeof(sPath), EngineGame == Engine_SourceSDK2006 ? "configs/levels_ranks/chat_old.ini" : "configs/levels_ranks/chat.ini");
	KeyValues hLR_Chat = new KeyValues("LR_Chat");
	if(!hLR_Chat.ImportFromFile(sPath) || !hLR_Chat.GotoFirstSubKey()) SetFailState("[" ... PLUGIN_NAME ... " Chat] file is not found (%s)", sPath);

	hLR_Chat.Rewind();

	if(hLR_Chat.JumpToKey("Prefixs_All"))
	{
		g_bColorOff = view_as<bool>(hLR_Chat.GetNum("color_off", 0));
		g_bColorForce = view_as<bool>(hLR_Chat.GetNum("color_force", 0));
		hLR_Chat.GetString("chat_tagstart", g_sPrefixTagStart, 32, "none");
		hLR_Chat.GetString("chat_tagend", g_sPrefixTagEnd, 32, "none");
		g_iTagStartColor = hLR_Chat.GetNum("color_tagstart", 0);
		g_iTagEndColor = hLR_Chat.GetNum("color_tagend", 0);

		Format(g_sPrefixTagStart, 32, "%s%s", g_sColors_Game[g_iTagStartColor], !strcmp(g_sPrefixTagStart, "none", false) ? "" : g_sPrefixTagStart);
		Format(g_sPrefixTagEnd, 32, "%s%s", g_sColors_Game[g_iTagEndColor], !strcmp(g_sPrefixTagEnd, "none", false) ? "" : g_sPrefixTagEnd);
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Chat] section Prefixs_All is not found (%s)", sPath);

	hLR_Chat.Rewind();

	if(hLR_Chat.JumpToKey("Prefixs_Private"))
	{
		g_iCountPrivatePrefix = 0;
		hLR_Chat.GotoFirstSubKey();

		do
		{
			hLR_Chat.GetSectionName(g_sSpecialPrefixBlock[g_iCountPrivatePrefix], 64);
			hLR_Chat.GetString("prefix", g_sSpecialPrefix[g_iCountPrivatePrefix], 64);
			g_iCountPrivatePrefix++;
		}
		while(hLR_Chat.GotoNextKey());
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Chat] section Prefixs_Private is not found (%s)", sPath);

	hLR_Chat.Rewind();

	if(hLR_Chat.JumpToKey("Prefixs"))
	{
		int iCount;
		hLR_Chat.GotoFirstSubKey();

		do
		{
			iCount++;
			hLR_Chat.GetString("prefix", g_sPrefixNames[iCount], 64);
			g_iColorRankPrefix[iCount] = hLR_Chat.GetNum("color_prefix", 0);
			g_iColorRankName[iCount] = hLR_Chat.GetNum("color_name", 0);
			g_iColorRankMessage[iCount] = hLR_Chat.GetNum("color_message", 0);
		}
		while(hLR_Chat.GotoNextKey());

		if(iCount != LR_GetCountLevels())
		{
			SetFailState("[" ... PLUGIN_NAME ... " Chat] the number of ranks does not match the specified number in the core (%s)", sPath);
		}
	}
	else SetFailState("[" ... PLUGIN_NAME ... " Chat] section Prefixs is not found (%s)", sPath);
	delete hLR_Chat;
	LR_GetTitleMenu(g_sPluginTitle, 64);
}

public void LR_OnMenuCreated(int iClient, Menu& hMenu)
{
	if(!(g_bColorForce && !g_bColorOff))
	{
		char sText[64];
		FormatEx(sText, 64, "%T", "Chat", iClient);
		hMenu.AddItem("ChatSCP", sText);
	}
}

public void LR_OnMenuItemSelected(int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "ChatSCP"))
	{
		ChatMenu(iClient);
	}
}

void ChatMenu(int iClient)
{
	char sText[128];
	Menu hMenu = new Menu(ChatMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Chat", iClient);
	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;

	FormatEx(sText, 128, "%T\n ", !g_bChatOff[iClient] ? "Chat_Off" : "Chat_On", iClient); hMenu.AddItem("", sText);
	FormatEx(sText, 128, "%T", "Prefix_Color", iClient); hMenu.AddItem("", sText, g_bColorForce ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	FormatEx(sText, 128, "%T", "Name_Color", iClient); hMenu.AddItem("", sText, g_bColorForce ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	FormatEx(sText, 128, "%T", "Text_Color", iClient); hMenu.AddItem("", sText, g_bColorForce ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int ChatMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) LR_MenuInventory(iClient);
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0:
				{
					g_bChatOff[iClient] = !g_bChatOff[iClient];
					ChatMenu(iClient);
				}
				case 1, 2, 3: ChatMenuSettings(iClient, 0, iSlot);
			}
		}
	}
}

void ChatMenuSettings(int iClient, int iList, int iType)
{
	char sBuffer[4], sText[128];
	Menu hMenu = new Menu(ChatMenuSettingsHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, iType == 1 ? "Prefix_Color" : iType == 2 ? "Name_Color" : "Text_Color", iClient);
	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;

	FormatEx(sBuffer, 4, "%i", iType);
	if(EngineGame == Engine_SourceSDK2006)
	{
		for(int i = 0; i < 3; i++)
		{
			FormatEx(sText, sizeof(sText), "%T", g_sMenuItemsCS[i], iClient); hMenu.AddItem(sBuffer, sText);
		}
	}
	else
	{
		for(int i = 0; i < 12; i++)
		{
			FormatEx(sText, sizeof(sText), "%T", g_sMenuItemsCSGO[i], iClient); hMenu.AddItem(sBuffer, sText);
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
				case 1: g_iPrefixColor[iClient] = iSlot;
				case 2: g_iNameColor[iClient] = iSlot;
				case 3: g_iTextColor[iClient] = iSlot;
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
	if(iClient && IsClientInGame(iClient))
	{
		int iRank = LR_GetClientInfo(iClient, ST_RANK);
		if(g_bColorForce)
		{
			g_iPrefixColor[iClient] = g_iColorRankPrefix[iRank];
			g_iNameColor[iClient] = g_iColorRankName[iRank];
			g_iTextColor[iClient] = g_iColorRankMessage[iRank];
		}

		if(!g_bChatOff[iClient])
		{
			Format(sName, MAXLENGTH_NAME, "%s%s%s%s%s %s%s", EngineGame == Engine_CSGO ? " \x01" : "\x01", !strcmp(g_sPrefixTagStart, "none", false) ? "" : g_sPrefixTagStart, g_sColors_Game[g_iPrefixColor[iClient]], g_bPrivatePrefix[iClient] ? g_sSpecialPrefixClient[iClient] : g_sPrefixNames[iRank], !strcmp(g_sPrefixTagEnd, "none", false) ? "" : g_sPrefixTagEnd, g_sColors_Game[g_iNameColor[iClient]], sName);
			Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sColors_Game[g_iTextColor[iClient]], sMessage);
			return Plugin_Changed;
		}
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
	if(iClient && IsClientInGame(iClient))
	{
		int iRank = LR_GetClientInfo(iClient, ST_RANK);
		if(g_bColorForce)
		{
			g_iPrefixColor[iClient] = g_iColorRankPrefix[iRank];
			g_iNameColor[iClient] = g_iColorRankName[iRank];
			g_iTextColor[iClient] = g_iColorRankMessage[iRank];
		}

		if(!g_bChatOff[iClient])
		{
			Format(sName, MAXLENGTH_NAME, "%s%s%s%s%s %s%s", EngineGame == Engine_CSGO ? " \x01" : "\x01", !strcmp(g_sPrefixTagStart, "none", false) ? "" : g_sPrefixTagStart, g_sColors_Game[g_iPrefixColor[iClient]], g_bPrivatePrefix[iClient] ? g_sSpecialPrefixClient[iClient] : g_sPrefixNames[iRank], !strcmp(g_sPrefixTagEnd, "none", false) ? "" : g_sPrefixTagEnd, g_sColors_Game[g_iNameColor[iClient]], sName);
			Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sColors_Game[g_iTextColor[iClient]], sMessage);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public void LR_OnPlayerLoaded(int iClient, const char[] sSteamID)
{
	strcopy(g_sSteamID[iClient], 32, sSteamID);
	if(!g_bNew[iClient])
	{
		int iRank = LR_GetClientInfo(iClient, ST_RANK);
		g_iPrefixColor[iClient] = g_iColorRankPrefix[iRank];
		g_iNameColor[iClient] = g_iColorRankName[iRank];
		g_iTextColor[iClient] = g_iColorRankMessage[iRank];
		g_bNew[iClient] = true;
	}

	int iFlagClient = GetUserFlagBits(iClient);
	for(int i = 0; i < g_iCountPrivatePrefix; i++)
	{
		if(!strcmp(g_sSpecialPrefixBlock[i], g_sSteamID[iClient], false) || (iFlagClient & ReadFlagString(g_sSpecialPrefixBlock[i])))
		{
			strcopy(g_sSpecialPrefixClient[iClient], 32, g_sSpecialPrefix[i]);
			g_bPrivatePrefix[iClient] = true;
			break;
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sBuffer[5][4], sCookie[20];
	GetClientCookie(iClient, g_hChat, sCookie, 16);
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
	g_bNew[iClient] = view_as<bool>(StringToInt(sBuffer[0]));
	g_bChatOff[iClient] = view_as<bool>(StringToInt(sBuffer[1]));
	g_iPrefixColor[iClient] = StringToInt(sBuffer[2]);
	g_iNameColor[iClient] = StringToInt(sBuffer[3]);
	g_iTextColor[iClient] = StringToInt(sBuffer[4]);
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[20];
		FormatEx(sBuffer, 20, "%i;%i;%i;%i;%i;", g_bNew[iClient], g_bChatOff[iClient], g_iPrefixColor[iClient], g_iNameColor[iClient], g_iTextColor[iClient]);
		SetClientCookie(iClient, g_hChat, sBuffer);		
	}
	g_bNew[iClient] = false;
	g_bPrivatePrefix[iClient] = false;
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