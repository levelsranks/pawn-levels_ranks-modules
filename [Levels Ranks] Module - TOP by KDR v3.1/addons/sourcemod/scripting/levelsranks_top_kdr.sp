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
				  g_sTransBack[][] = {"Back to Menu", "Назад в Меню", "Назад в Меню"},
				  g_sTransFrases[][] = {"TOP-10 by KDR", "TOP-10 по KDR", "TOP-10 за KDR"},

				  g_sSQL_SelectTop[] = "SELECT `name`, `kills`, `deaths` FROM `%.32s` WHERE `kills` >= " ... MINKILLS ... " ORDER by (`kills`/`deaths`) desc LIMIT " ... MAXPLACES ... ";";

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
		static Database hDatabase;
		static char     sBuf[192];

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
		Format(sText, sizeof(sText), "%s %d - %.2f - %s\n", sText, ++i, float(dbRs.FetchInt(1))/float(dbRs.FetchInt(2)), sName);
	}

	strcopy(sText[strlen(sText)], 4, "\n ");

	Menu hMenu = new Menu(Menu_Callback);

	hMenu.SetTitle(sText);

	hMenu.AddItem("", g_sTransBack[iLang]);

	hMenu.ExitButton = true;
	hMenu.Display(iData & 0x7f, MENU_TIME_FOREVER);
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