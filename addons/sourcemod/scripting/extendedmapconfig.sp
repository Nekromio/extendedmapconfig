#pragma semicolon 1
#pragma newdecls required

enum{
	ACTUAL,
	VISIBLE,
	VISIBLE_GENERAL,
	VISIBLE_GAMETYPE,
	VISIBLE_MAP
}

static const char sFolder[][] = 
{
	"cfg/",
	"mapconfig/",
	"mapconfig/pre/",
	"mapconfig/pre/general/",
	"mapconfig/pre/gametype/",
	"mapconfig/pre/maps/",
	"mapconfig/post/",
	"mapconfig/post/general/",
	"mapconfig/post/gametype/",
	"mapconfig/post/maps/"
};

enum ConfigType{
	TYPE_GENERAL,
	TYPE_MAP,
	TYPE_GAMETYPE
}

public Plugin myinfo =
{
	name        = "[Refork] Extended mapconfig package",
	author      = "Milo (original), Nek.'a 2x2 (refork)",
	description = "Allows you to use separate config files for each game type and map. Before and after the card change",
	version     = "1.0.3",
	url         = "ggwp.site | vk.com/nekromio | t.me/sourcepwn "
};

public void OnPluginStart()
{
	AddCommandListener(Command_ChangeMap, "changelevel");
	AddCommandListener(Command_ChangeMap, "sm_map");
}

Action Command_ChangeMap(int client, const char[] command, int argc)
{
	char mapName[64];
	GetCmdArg(1, mapName, sizeof(mapName));
	execPreConfigs(mapName);
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	createConfigFiles();

	char name[PLATFORM_MAX_PATH];

	// General
	name = "all";
	execConfigFile(name, TYPE_GENERAL/* , "general" */);

	// Gametype
	GetCurrentMap(name, sizeof(name));
	GetMapDisplayName(name, name, sizeof(name));
	if (SplitString(name, "_", name, sizeof(name)) != -1) {
		execConfigFile(name, TYPE_GAMETYPE/* , "gametype" */);
	}

	// Map
	GetCurrentMap(name, sizeof(name));
	GetMapDisplayName(name, name, sizeof(name));
	execConfigFile(name, TYPE_MAP/* , "mapspecific" */);
}

void execConfigFile(const char[] name, ConfigType type/* , const char[] label = "" */)
{
	char configFilename[PLATFORM_MAX_PATH];
	getConfigFilename(configFilename, sizeof(configFilename), name, type);
	ServerCommand("exec \"%s\"", configFilename);
}

void createConfigFiles()
{
	for (int i = 1; i < sizeof(sFolder); i++)
	{
		createConfigDir(sFolder[i], sFolder[0]);
	}

	createConfigFile("all", TYPE_GENERAL, "All maps", false);
	createDefaultGametypeConfigs(false);
	createMapConfigs(false);

	createConfigFile("all", TYPE_GENERAL, "All maps", true);
	createDefaultGametypeConfigs(true);
	createMapConfigs(true);
}

void createDefaultGametypeConfigs(bool isPre)
{
	createConfigFile("cs", TYPE_GAMETYPE, "Hostage maps", isPre);
	createConfigFile("de", TYPE_GAMETYPE, "Defuse maps", isPre);
	createConfigFile("as", TYPE_GAMETYPE, "Assasination maps", isPre);
	createConfigFile("es", TYPE_GAMETYPE, "Escape maps", isPre);
}

void createMapConfigs(bool isPre)
{
	char name[PLATFORM_MAX_PATH];
	ArrayList adtMaps = new ArrayList(ByteCountToCells(256));
	int serial = -1;

	ReadMapList(adtMaps, serial, "allexistingmaps__", MAPLIST_FLAG_MAPSFOLDER | MAPLIST_FLAG_NO_DEFAULT);
	int mapcount = adtMaps.Length;

	for (int i = 0; i < mapcount; i++)
	{
		adtMaps.GetString(i, name, sizeof(name));
		createConfigFile(name, TYPE_MAP, name, isPre);
	}

	delete adtMaps;
}

void getConfigFilename(char[] buffer, int maxlen, const char[] filename, ConfigType type, bool actualPath = false, bool isPre = false)
{
	char basePath[32];
	char typePath[32];

	if (isPre)
	{
		strcopy(basePath, sizeof(basePath), "mapconfig/pre/");
	}
	else
	{
		strcopy(basePath, sizeof(basePath), "mapconfig/post/");
	}

	switch (type)
	{
		case TYPE_GENERAL:  strcopy(typePath, sizeof(typePath), "general/");
		case TYPE_GAMETYPE: strcopy(typePath, sizeof(typePath), "gametype/");
		case TYPE_MAP:      strcopy(typePath, sizeof(typePath), "maps/");
		default:            strcopy(typePath, sizeof(typePath), "");
	}

	Format(buffer, maxlen, "%s%s%s%s.cfg", (actualPath ? "cfg/" : ""), basePath, typePath, filename);
}

void createConfigDir(const char[] filename, const char[] prefix = "")
{
	char dirname[PLATFORM_MAX_PATH];
	Format(dirname, sizeof(dirname), "%s%s", prefix, filename);
	CreateDirectory(
		dirname,  
		FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC + 
		FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC + 
		FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC
	);
}

void createConfigFile(const char[] filename, ConfigType type, const char[] label = "", bool isPre = false)
{
	if (strlen(filename) == 0)
	{
		LogError("Attempted to create config file with empty name (type: %d)", type);
		return;
	}

	char fullPath[PLATFORM_MAX_PATH];
	getConfigFilename(fullPath, sizeof(fullPath), filename, type, true, isPre);

	char dirPath[PLATFORM_MAX_PATH];
	strcopy(dirPath, sizeof(dirPath), fullPath);
	int pos = FindCharInString(dirPath, '/', true);
	if (pos != -1)
	{
		dirPath[pos] = '\0';
		CreateDirectory(dirPath,
			FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC +
			FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC +
			FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC);
	}

	if (FileExists(fullPath))
		return;

	File fileHandle = OpenFile(fullPath, "w+");
	if (fileHandle == null)
	{
		LogError("Failed to create config file: %s", fullPath);
		return;
	}

	WriteFileLine(fileHandle, "// Configfile for: %s", strlen(label) > 0 ? label : filename);
	delete fileHandle;
}

void execPreConfigs(const char[] mapName)
{
	char buffer[PLATFORM_MAX_PATH];

	// General
	getConfigFilename(buffer, sizeof(buffer), "all", TYPE_GENERAL, false, true);
	ServerCommand("exec \"%s\"", buffer);

	// Gametype
	char prefix[PLATFORM_MAX_PATH];
	strcopy(prefix, sizeof(prefix), mapName);
	if (SplitString(prefix, "_", prefix, sizeof(prefix)) != -1)
	{
		getConfigFilename(buffer, sizeof(buffer), prefix, TYPE_GAMETYPE, false, true);
		//LogMessage("[MapConfig] Executing gametype pre-config for prefix '%s': %s", prefix, buffer);
		ServerCommand("exec \"%s\"", buffer);
	}
	else
	{
		//LogMessage("[MapConfig] No gametype prefix found in map name: %s", mapName);
	}

	// Map
	getConfigFilename(buffer, sizeof(buffer), mapName, TYPE_MAP, false, true);
	ServerCommand("exec \"%s\"", buffer);
}