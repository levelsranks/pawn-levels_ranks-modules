#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define MINKILLS "250"
#define MAXPLACES "10"

int				  g_iLang[MAXPLAYERS+1];

static const char g_sItemName[] = "TopKDR",
				  g_sTransFrases[][] = {"TOP 10 | KDR", "TOP 10 | KDR", "TOP 10 | KDR"},

				  g_sSQL_SelectTop[] = "SELECT `name`, 1.0 * `kills` / `deaths` AS `kdr` FROM `%s` WHERE `kills` >= " ... MINKILLS ... " AND `lastconnect` ORDER BY `kdr` DESC LIMIT " ... MAXPLACES ... ";";

// levelsranks_top_kdr.sp
public Plugin myinfo = 
{
	name = "[LR] Module - TOP by KDR", 
	author = "Wend4r", 
	version = PLUGIN_VERSION, 
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
};

public void OnPluginStart()
{
	LoadTranslations("core.phrases");

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_MenuHook(LR_TopMenu, OnMenuCreatedTop, OnMenuItemSelectedTop);
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	int iOrigLang = GetClientLanguage(iClient);

	g_iLang[iClient] = iOrigLang == 22 ? 1 : iOrigLang == 30 ? 2 : 0;
}

public void OnMenuCreatedTop(LR_MenuType MenuType, int iClient, Menu hMenu)
{
	hMenu.AddItem(g_sItemName, g_sTransFrases[g_iLang[iClient]]);
}

public void OnMenuItemSelectedTop(LR_MenuType MenuType, int iClient, const char[] sInfo)
{
	if(StrEqual(sInfo, g_sItemName))
	{
		static char		sBuf[192];

		static Database hDatabase;

		if(!hDatabase)
		{
			hDatabase = LR_GetDatabase();

			LR_GetTableName(sBuf, 32);
			Format(sBuf, sizeof(sBuf), g_sSQL_SelectTop, sBuf);
		}

		hDatabase.Query(SQL_PrintTop, sBuf, iClient | (g_iLang[iClient] << 7));
	}
}

public void SQL_PrintTop(Database db, DBResultSet dbRs, const char[] sError, int iData)
{
	if(!dbRs)
	{
		LogError("SQL_Callback Error (%i): %s", iData, sError);
		return;
	}

	int iLang = iData >> 7;

	static char sName[32], sText[512];

	Format(sText, sizeof(sText), PLUGIN_NAME ... " | %s\n \n", g_sTransFrases[iLang]);
	for(int i; dbRs.HasResults && dbRs.FetchRow();)
	{
		dbRs.FetchString(0, sName, sizeof(sName));
		Format(sText, sizeof(sText), "%s %d - %.2f - %s\n", sText, ++i, dbRs.FetchFloat(1), sName);
	}

	strcopy(sText[strlen(sText)], 4, "\n ");

	int iClient = iData & 0x7F;

	Menu hMenu = new Menu(Menu_Callback);

	hMenu.SetTitle(sText);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_Callback(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	if(mAction == MenuAction_Select)
	{
		LR_ShowMenu(iClient, LR_TopMenu);
	}
	else if(mAction == MenuAction_End)
	{
		hMenu.Close();
	}
}