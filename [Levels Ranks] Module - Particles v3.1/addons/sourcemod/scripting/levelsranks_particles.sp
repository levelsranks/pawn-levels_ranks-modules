#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Particles"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRank[MAXPLAYERS+1],
		g_iChoice[MAXPLAYERS+1],
		g_iParticle[MAXPLAYERS+1],
		g_iCount,
		g_iLevel;
bool		g_bActive[MAXPLAYERS+1];
char		g_sParticleName[128][64],
		g_sParticleMark[128][64],
		g_sPluginTitle[64];
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_Particle", "LR_Particle", CookieAccess_Private);
	LoadTranslations("lr_module_particles.phrases");
	HookEvent("player_team", Events);
	HookEvent("player_death", Events);
	HookEvent("player_spawn", Events);
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
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

public void OnMapStart() 
{
	char sPath[PLATFORM_MAX_PATH];
	Handle hBuffer = OpenFile("addons/sourcemod/configs/levels_ranks/particles_pcfpath.ini", "r");
	if(hBuffer == null) SetFailState("Unable to load addons/sourcemod/configs/levels_ranks/particles_pcfpath.ini");

	while(ReadFileLine(hBuffer, sPath, 192))
    {
        TrimString(sPath);
        if(sPath[0])
		{
			PrecacheGeneric(sPath, true);
		}
    }
	delete hBuffer;
	ConfigLoad();
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/particles.ini");
	KeyValues hLR = new KeyValues("LR_Particle");
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	hLR.GotoFirstSubKey();
	hLR.Rewind();

	if(hLR.JumpToKey("Particle"))
	{
		g_iCount = 0;
		g_iLevel = hLR.GetNum("rank", 0);
		hLR.GotoFirstSubKey();

		do
		{
			hLR.GetSectionName(g_sParticleName[g_iCount], sizeof(g_sParticleName[]));
			hLR.GetString("particle", g_sParticleMark[g_iCount], sizeof(g_sParticleMark[]));
			PrecacheModel(g_sParticleMark[g_iCount++], true);
		}
		while(hLR.GotoNextKey());
	}
	else SetFailState(PLUGIN_NAME ... " : Section Particle is not found (%s)", sPath);
	hLR.Close();
}

void OnLevelChanged(int iClient, int iNewLevel, int iOldLevel)
{
	g_iRank[iClient] = iNewLevel;
}

public void Events(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient))
	{
		g_iRank[iClient] = LR_GetClientInfo(iClient, ST_RANK);
		if(sEvName[7] == 's' && !g_bActive[iClient] && g_iRank[iClient] >= g_iLevel)
		{
			SetParticle(iClient);
		}
		else DeleteParticle(iClient);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(g_iRank[iClient] >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", "Particle_RankOpened", iClient);
		hMenu.AddItem("Particle", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Particle_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("Particle", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Particle"))
	{
		ParticleMenu(iClient, 0);
	}
}

public void ParticleMenu(int iClient, int iList)
{
	char sID[4], sText[192];
	Menu hMenu = new Menu(ParticleMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Particle_RankOpened", iClient);

	FormatEx(sText, sizeof(sText), "%T\n ", !g_bActive[iClient] ? "Particle_On" : "Particle_Off", iClient);
	hMenu.AddItem("-1", sText);

	for(int i; i < g_iCount; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sText, sizeof(sText), "%s", g_sParticleName[i]);
		hMenu.AddItem(sID, sText);
	}

	hMenu.ExitBackButton = true;
	hMenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int ParticleMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
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
					SetParticle(iClient);
				}
				else DeleteParticle(iClient);
				g_bActive[iClient] = !g_bActive[iClient];
			}
			else
			{
				g_iChoice[iClient] = StringToInt(sID);
				if(IsPlayerAlive(iClient) && !g_bActive[iClient]) SetParticle(iClient);
			}

			ParticleMenu(iClient, GetMenuSelectionPosition());
		}
	}
}

void SetParticle(int iClient)
{
	DeleteParticle(iClient);

	char sTargetName[32]; float fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	FormatEx(sTargetName, sizeof(sTargetName), "client%d", iClient);

	g_iParticle[iClient] = CreateEntityByName("info_particle_system");
	DispatchKeyValue(g_iParticle[iClient], "effect_name", g_sParticleMark[g_iChoice[iClient]]);

	if(DispatchSpawn(g_iParticle[iClient]))
	{
		ActivateEntity(g_iParticle[iClient]);
		AcceptEntityInput(g_iParticle[iClient], "Start");
		TeleportEntity(g_iParticle[iClient], fPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iClient, "targetname", sTargetName);
		SetVariantString(sTargetName);
		AcceptEntityInput(g_iParticle[iClient], "SetParent");
	}
	else g_iParticle[iClient] = 0;
}

void DeleteParticle(int iClient)
{
	if(g_iParticle[iClient] && IsValidEdict(g_iParticle[iClient]))
	{
		AcceptEntityInput(g_iParticle[iClient], "Kill");
	}
	g_iParticle[iClient] = 0;
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[8], sBuffer[2][4];
	GetClientCookie(iClient, g_hCookie, sCookie, sizeof(sCookie));
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
	g_iChoice[iClient] = StringToInt(sBuffer[0]);
	g_bActive[iClient] = view_as<bool>(StringToInt(sBuffer[1]));
}

public void OnClientDisconnect(int iClient)
{
	char sBuffer[8];
	Format(sBuffer, sizeof(sBuffer), "%i;%i;", g_iChoice[iClient], g_bActive[iClient]);
	SetClientCookie(iClient, g_hCookie, sBuffer);
	DeleteParticle(iClient);
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