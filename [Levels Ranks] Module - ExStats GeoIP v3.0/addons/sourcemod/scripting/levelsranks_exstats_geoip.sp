#pragma semicolon 1
#include <sourcemod>
#include <geoipcity>
#pragma newdecls required
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

#define LogLR(%0) LogError("[" ... PLUGIN_NAME ... " ExGeoIP] " ... %0)
#define CrashLR(%0) SetFailState("[" ... PLUGIN_NAME ... " ExGeoIP] " ... %0)

char			g_sTableName[32],
			g_sSteamID[MAXPLAYERS+1][32];
Database	g_hDatabase = null;

public Plugin myinfo = {name = "[LR] Module - ExStats GeoIP", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public void OnAllPluginsLoaded()
{
	ConnectDatabase();
}

public void LR_OnDatabaseLoaded()
{
	ConnectDatabase();
}

void ConnectDatabase()
{
	if(!g_hDatabase)
	{
		char sQuery[2048], sQueryFast[256];
		g_hDatabase = LR_GetDatabase();
		LR_GetTableName(g_sTableName, 32);

		SQL_LockDatabase(g_hDatabase);
		if(!LR_GetDatabaseType()) FormatEx(sQuery, 2048, "CREATE TABLE IF NOT EXISTS `%s_geoip` (`steam` varchar(32) NOT NULL default '' PRIMARY KEY, `lastconnect` NUMERIC, `clientip` varchar(128) NOT NULL default '', `country` varchar(128) NOT NULL default '', `region` varchar(128) NOT NULL default '', `city` varchar(128) NOT NULL default '', `country_code` varchar(8) NOT NULL default '') CHARSET=utf8 COLLATE utf8_general_ci", g_sTableName);
		else CrashLR("LR_OnDatabaseLoaded - not MySQL");
		if(!SQL_FastQuery(g_hDatabase, sQuery)) CrashLR("LR_OnDatabaseLoaded - could not create table");

		FormatEx(sQueryFast, 256, "ALTER TABLE `%s_geoip` ADD COLUMN `lastconnect` NUMERIC default %d AFTER `steam`;", g_sTableName, GetTime());
		SQL_FastQuery(g_hDatabase, sQueryFast);

		FormatEx(sQueryFast, 256, "ALTER TABLE `%s_geoip` ADD COLUMN `country_code` varchar(8) NOT NULL default '' AFTER `city`;", g_sTableName);
		SQL_FastQuery(g_hDatabase, sQueryFast);

		SQL_UnlockDatabase(g_hDatabase);
		g_hDatabase.SetCharset("utf8");

		for(int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if(IsClientInGame(iClient))
			{
				LoadDataPlayer(iClient);
			}
		}
	}
}

void CreateDataPlayer(int iClient)
{
	if(!g_hDatabase)
	{
		LogLR("CreateDataPlayer - database is invalid");
		return;
	}

	if(LR_GetClientStatus(iClient))
	{
		char sQuery[512], sIp[64], sCity[45], sRegion[45], sCountry[45], sCountryCode[3], sCountryCodeThird[4], sBuffer[4][45], sBufferEscaped[4][91];

		GetClientIP(iClient, sIp, sizeof(sIp));
		GeoipGetRecord(sIp, sCity, sRegion, sCountry, sCountryCode, sCountryCodeThird);
		strcopy(sBuffer[0], sizeof(sBuffer[]), sCity);
		strcopy(sBuffer[1], sizeof(sBuffer[]), sRegion);
		strcopy(sBuffer[2], sizeof(sBuffer[]), sCountry);
		strcopy(sBuffer[3], sizeof(sBuffer[]), sCountryCode);

		for(int i = 0; i < 4; i++)
		{
			if(!strlen(sBuffer[i]))
			{
				strcopy(sBufferEscaped[i], sizeof(sBufferEscaped[]), "NULL");
			}
			else
			{
				g_hDatabase.Escape(sBuffer[i], sBufferEscaped[i], sizeof(sBufferEscaped[]));
				Format(sBufferEscaped[i], sizeof(sBufferEscaped[]), "%s", sBufferEscaped[i]);
			}
		}

		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `%s_geoip` (`steam`, `lastconnect`, `clientip`, `country`, `region`, `city`, `country_code`) VALUES ('%s', %d, '%s', '%s', '%s', '%s', '%s');", g_sTableName, g_sSteamID[iClient], GetTime(), sIp, sBufferEscaped[2], sBufferEscaped[1], sBufferEscaped[0], sBufferEscaped[3]);
		g_hDatabase.Query(CreateDataPlayer_Callback, sQuery, iClient);
	}
}

public void CreateDataPlayer_Callback(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs)
	{
		LogLR("CreateDataPlayer - %s", sError);
		return;
	}
}

public void LR_OnPlayerLoaded(int iClient, const char[] sSteamID)
{
	strcopy(g_sSteamID[iClient], 32, sSteamID);
	LoadDataPlayer(iClient);
}

void LoadDataPlayer(int iClient)
{
	if(!g_hDatabase)
	{
		LogLR("LoadDataPlayer - database is invalid");
		return;
	}

	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `%s_geoip` WHERE `steam` = '%s';", g_sTableName, g_sSteamID[iClient]);
	g_hDatabase.Query(LoadDataPlayer_Callback, sQuery, iClient);
}

public void LoadDataPlayer_Callback(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs)
	{
		LogLR("LoadDataPlayer - %s", sError);
		return;
	}
	
	if(!(dbRs.HasResults && dbRs.FetchRow()))
	{
		CreateDataPlayer(iClient);
	}
}

public void LR_OnPlayerSaved(int iClient, Transaction& hQuery)
{
	char sQuery[2048], sIp[64], sCity[45], sRegion[45], sCountry[45], sCountryCode[3], sCountryCodeThird[4], sBuffer[4][45], sBufferEscaped[4][91];

	GetClientIP(iClient, sIp, sizeof(sIp));
	GeoipGetRecord(sIp, sCity, sRegion, sCountry, sCountryCode, sCountryCodeThird);
	strcopy(sBuffer[0], sizeof(sBuffer[]), sCity);
	strcopy(sBuffer[1], sizeof(sBuffer[]), sRegion);
	strcopy(sBuffer[2], sizeof(sBuffer[]), sCountry);
	strcopy(sBuffer[3], sizeof(sBuffer[]), sCountryCode);

	for(int i = 0; i < 4; i++)
	{
		if(!strlen(sBuffer[i]))
		{
			strcopy(sBufferEscaped[i], sizeof(sBufferEscaped[]), "NULL");
		}
		else
		{
			g_hDatabase.Escape(sBuffer[i], sBufferEscaped[i], sizeof(sBufferEscaped[]));
			Format(sBufferEscaped[i], sizeof(sBufferEscaped[]), "%s", sBufferEscaped[i]);
		}
	}

	FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s_geoip` SET `lastconnect` = %d, `clientip` = '%s', `country` = '%s', `region` = '%s', `city` = '%s', `country_code` = '%s' WHERE `steam` = '%s';", g_sTableName, GetTime(), sIp, sBufferEscaped[2], sBufferEscaped[1], sBufferEscaped[0], sBufferEscaped[3], g_sSteamID[iClient]);
	hQuery.AddQuery(sQuery);
}