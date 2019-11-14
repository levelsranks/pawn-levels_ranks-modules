#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Medkit"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iMedkitPlayer[MAXPLAYERS+1],
		g_iMedkitCount,
		g_iMedkitHP,
		g_iMedkitMinHP,
		g_iMedkitMaxHP,
		g_iMedkitRank,
		m_iHealth;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LoadTranslations("lr_module_medkit.phrases");
		case Engine_SourceSDK2006: LoadTranslations("lr_module_medkit_old.phrases");
	}

	m_iHealth = FindSendPropInfo("CCSPlayer", "m_iHealth");
	HookEvent("round_start", Event_Medkit);
	ConfigLoad();
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	}

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/medkit.ini");
	KeyValues hLR = new KeyValues("LR_Medkit");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : file is not found (%s)", sPath);

	g_iMedkitRank = hLR.GetNum("rank", 0);
	g_iMedkitCount = hLR.GetNum("count", 1);
	g_iMedkitHP = hLR.GetNum("health", 30);
	g_iMedkitMinHP = hLR.GetNum("minhealth", 50);
	g_iMedkitMaxHP = hLR.GetNum("maxhealth", 100);

	hLR.Close();
}

public void Event_Medkit(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iMedkitPlayer[i] = g_iMedkitCount;
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iMedkitRank)
	{
		FormatEx(sText, sizeof(sText), "%T", "Medkit_ON", iClient);
		hMenu.AddItem("Medkit", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Medkit_OFF", iClient, g_iMedkitRank);
		hMenu.AddItem("Medkit", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Medkit"))
	{
		int iHealth;
		bool bDenied;

		if(GetClientTeam(iClient) < 2)
		{
			LR_PrintToChat(iClient, true, "%T", "InTeam", iClient);
			bDenied = true;
		}
		else
		{
			if(!IsPlayerAlive(iClient))
			{
				LR_PrintToChat(iClient, true, "%T", "Alive", iClient);
				bDenied = true;
			}
			else
			{
				if(g_iMedkitPlayer[iClient] < 1)
				{
					LR_PrintToChat(iClient, true, "%T", "Nothing", iClient);
					bDenied = true;
				}
				else
				{
					if((iHealth = GetEntData(iClient, m_iHealth)) > g_iMedkitMinHP)
					{
						LR_PrintToChat(iClient, true, "%T", "NoMedic", iClient);
						bDenied = true;
					}
				}
			}
		}

		if(!bDenied)
		{
			g_iMedkitPlayer[iClient]--;
			iHealth += g_iMedkitHP;
			SetEntData(iClient, m_iHealth, iHealth > g_iMedkitMaxHP ? g_iMedkitMaxHP : iHealth);
		}

		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}