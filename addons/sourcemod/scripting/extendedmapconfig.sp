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
	"mapconfig/general/",
	"mapconfig/gametype/",
	"mapconfig/maps/",
};

enum ConfigType{
	TYPE_GENERAL,
	TYPE_MAP,
	TYPE_GAMETYPE
}

public Plugin myinfo =
{
	name        = "Extended mapconfig package",
	author      = "Milo, Nek.'a 2x2",
	description = "Allows you to use seperate config files for each gametype and map.",
	version     = "1.0.1",
	url         = "http://sourcemod.corks.nl/"
};

public void OnConfigsExecuted()
{
	createConfigFiles();

	char name[PLATFORM_MAX_PATH];

	// General
	name = "all";
	execConfigFile(name, TYPE_GENERAL, "general");

	// Gametype
	GetCurrentMap(name, sizeof(name));
	GetMapDisplayName(name, name, sizeof(name));
	if (SplitString(name, "_", name, sizeof(name)) != -1) {
		execConfigFile(name, TYPE_GAMETYPE, "gametype");
	}

	// Map
	GetCurrentMap(name, sizeof(name));
	GetMapDisplayName(name, name, sizeof(name));
	execConfigFile(name, TYPE_MAP, "mapspecific");
}

void execConfigFile(const char[] name, ConfigType type, const char[] label = "")
{
	char configFilename[PLATFORM_MAX_PATH];
	getConfigFilename(configFilename, sizeof(configFilename), name, type);
	PrintToServer("Loading mapconfig: %s configfile (%s.cfg).", label, name);
	ServerCommand("exec \"%s\"", configFilename);
}

void createConfigFiles()
{
	for (int i = 1; i < sizeof(sFolder); i++)
	{
		createConfigDir(sFolder[i], sFolder[0]);
	}

	createConfigFile("all", TYPE_GENERAL, "All maps");

	createDefaultGametypeConfigs();
	createMapConfigs();
}

void createDefaultGametypeConfigs()
{
	createConfigFile("cs", TYPE_GAMETYPE, "Hostage maps");
	createConfigFile("de", TYPE_GAMETYPE, "Defuse maps");
	createConfigFile("as", TYPE_GAMETYPE, "Assasination maps");
	createConfigFile("es", TYPE_GAMETYPE, "Escape maps");
}

void createMapConfigs()
{
	char name[PLATFORM_MAX_PATH];
	ArrayList adtMaps = new ArrayList(16);
	int serial = -1;

	ReadMapList(adtMaps, serial, "allexistingmaps__", MAPLIST_FLAG_MAPSFOLDER | MAPLIST_FLAG_NO_DEFAULT);
	int mapcount = adtMaps.Length;

	for (int i = 0; i < mapcount; i++)
	{
		adtMaps.GetString(i, name, sizeof(name));
		createConfigFile(name, TYPE_MAP, name);
	}

	delete adtMaps;
}

// Determine the full path to a config file.
void getConfigFilename(char[] buffer, const int maxlen, const char[] filename, ConfigType type, const bool actualPath = false)
{
	Format(buffer, maxlen, "%s%s%s.cfg", (actualPath ? sFolder[ACTUAL] : ""),
	(type == TYPE_GENERAL ? sFolder[VISIBLE_GENERAL] : (type == TYPE_GAMETYPE ? sFolder[VISIBLE_GAMETYPE] : sFolder[VISIBLE_MAP])), filename);
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

void createConfigFile(const char[] filename, ConfigType type, const char[] label = "")
{
	char configFilename[PLATFORM_MAX_PATH];
	getConfigFilename(configFilename, sizeof(configFilename), filename, type, true);

	// If config already exists — do nothing
	if (FileExists(configFilename))
		return;

	// Try to open/create file
	File fileHandle = OpenFile(configFilename, "w+");
	if (fileHandle == null)
	{
		LogError("Failed to create config file: %s", configFilename);
		return;
	}

	// Use label or fallback to filename
	WriteFileLine(fileHandle, "// Configfile for: %s", strlen(label) > 0 ? label : filename);

	// Close the file
	delete fileHandle;
}