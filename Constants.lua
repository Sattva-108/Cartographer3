Cartographer3.SetConstants {
	CITIES = {
		["Darnassis"] = true,
		["TheExodar"] = true,
		["SilvermoonCity"] = true,
		["Undercity"] = true,
		["Ironforge"] = true,
		["Stormwind"] = true,
		["ThunderBluff"] = true,
		["Ogrimmar"] = true,
		["ShattrathCity"] = true,
		["Dalaran"] = true,
	},
	
	INDOOR_CITIES = {
		["Ironforge"] = true,
		["Undercity"] = true,
		["TheExodar"] = true,
	},
	
	CONTINENT_DATA = {
		{ -- Kalimdor
			x = -100,
			y = 100,
			yards = 36800.210572494,
			rect = { 0.2606, 0.6898, 0.0647, 0.9485 },
			minimapTextureCenterX = 34.5,
			minimapTextureCenterY = 30,
			minimapTextureOffsetX = 0,
			minimapTextureOffsetY = 0,
			minimapTextureBackground = "67ba43d493e62a8fad5de319e6d4cb05",
			extraMinimapTextureAreas = {
				AzuremystIsles = {
					minimapTextureCenterX = 67.5,
					minimapTextureCenterY = 49,
				}
			},
		},
		{ -- Eastern Kingdoms
			x = 100,
			y = 100,
			yards = 40741.175327834,
			rect = { 0.3526, 0.6132, 0.0142, 0.9657 },
			minimapTextureCenterX = 36.125,
			minimapTextureCenterY = 35.5,
			minimapTextureOffsetX = -0.01,
			minimapTextureOffsetY = -0.03,
			minimapTextureBackground = "67ba43d493e62a8fad5de319e6d4cb05",
			extraMinimapTextureAreas = {
				QuelThalas = {
					minimapTextureCenterX = 40.75,
					minimapTextureCenterY = 30.5,
				}
			}
		},
		{ -- Outland
			x = 0,
			y = -100,
			yards = 17463.987300595,
			rect = { 0.1022, 0.7971, 0.0453, 0.9830 },
			minimapTextureCenterX = 24,
			minimapTextureCenterY = 31,
			minimapTextureOffsetX = 0,
			minimapTextureOffsetY = 0,
			minimapTextureBackground = "1400fcdfe2ca0858409f60596de08065",
		},
		{ -- Northrend
			x = 0,
			y = 300,
			rect = { 0.066, 0.911, 0.028, 0.968 },
			yards = 17751.3962441049,
			minimapTextureCenterX = 31.5,
			minimapTextureCenterY = 22,
			minimapTextureOffsetX = -0.8,
			minimapTextureOffsetY = 1.2,
			minimapTextureBackground = "d922f6d7681bc0683c69d44591a0db4f",
		}
	},
	
	BATTLEGROUND_RECTS = {
		WarsongGulch = { 306/1002, 693/1002, 0, 1 },
		ArathiBasin = { 300/1002, 679/1002, 50/668, 512/668},
		AlteracValley = { 320/1002, 682/1002, 25/1002, 977/1002 },
		NetherstormArena = { 356/1002, 620/1002, 100/668, 568/668 },
	},
	
	BATTLEGROUND_LOCATION_OVERRIDES = {
		ScarletEnclave = {162, 138}
	},
	
	MINIMUM_ZOOM = 0.5,
	ZOOM_STEP = 0.75,
	ZOOM_TIME = 1,
	MANUAL_ZOOM_TIME = 0.25,
	
	DEFAULT_MAPFRAME_WIDTH = 450,
	DEFAULT_MAPFRAME_HEIGHT = 300,
	DEFAULT_ALTERNATE_MAPFRAME_WIDTH = 200,
	DEFAULT_ALTERNATE_MAPFRAME_HEIGHT = 200,
	MAPFRAME_MINRESIZE_WIDTH = 100,
	MAPFRAME_MINRESIZE_HEIGHT = 65,
	
	DEFAULT_ZOOM_TO_MINIMAP_TEXTURE = 50,
	
	DEFAULT_MAPVIEW_BACKGROUND_COLOR = { 0.2, 0.2, 0.2, 0.5 },
	
	YARDS_PER_PIXEL = 100,
	
	ITERATIVE_PROCESS_STEP_SECONDS = 1/300,
	
	FADE_TIME = 0.25,
	
	COORDINATE_SEPARATOR = ("%.1f"):format(1.2) == "1,2" and " x " or ", ",
	
	LIMITED_CAMERA_ZOOM = 7.5,
	
	NORMAL_STATUS_COLOR = { 1, 1, 1 },
	COMBAT_COLOR = { 0.8, 0, 0 },
	DEAD_COLOR = { 0.2, 0.2, 0.2 },
	INACTIVE_COLOR = { 0.5, 0.2, 0 },
	
	INSTANCE_ROTATIONS = {
		-- currently only 90*k degree rotations are supported since in-between cases causes texture bleeding.
		["Dire Maul"] = 180,
		["Shadowfang Keep"] = 90,
		["The Deadmines"] = 270,
		["Razorfen Kraul"] = 270,
		["Old Hillsbrad Foothills"] = 90,
		["The Black Morass"] = 90,
		["Hellfire Ramparts"] = 90,
		["Zul'Gurub"] = 90,
		["Zul'Farrak"] = 90,
		["Hyjal Summit"] = 90,
		["Black Temple"] = 270,
		["Zul'Aman"] = 90,
	},

	INSTANCE_FLOOR_SPLITS = {
		["Karazhan"] = {5, 140, 260},
		["Upper Blackrock Spire"] = {0},
	},
	
	ZONE_SORT = {
		-- Eastern Kingdoms
	    "Alterac",
	    "Arathi",
	    "BlastedLands",
	    "BurningSteppes",
	    "DeadwindPass",
	    "DunMorogh",
	    "Ghostlands",
	    "WesternPlaguelands",
	    "EasternPlaguelands",
	    "EversongWoods",
	    "Hilsbrad",
	    "Hinterlands",
	    "LochModan",
	    "Redridge",
	    "Elwynn",
	    "SearingGorge",
	    "Badlands",
	    "Silverpine",
	    "Stranglethorn",
	    "Duskwood",
	    "Sunwell",
	    "SwampOfSorrows",
	    "Tirisfal",
	    "Westfall",
	    "Wetlands",
		
		-- Kalimdor
	    "Ashenvale",
	    "Aszhara",
	    "AzuremystIsle",
	    "BloodmystIsle",
	    "Darkshore",
	    "Desolace",
	    "Durotar",
	    "Felwood",
	    "Moonglade",
	    "Mulgore",
	    "Silithus",
	    "Tanaris",
	    "Teldrassil",
	    "UngoroCrater",
	    "Winterspring",
	    "Barrens",
	    "StonetalonMountains",
	    "Dustwallow",
	    "ThousandNeedles",
	    "Feralas",
		
		-- Outland
	    "Netherstorm",
	    "TerokkarForest",
	    "Hellfire",
	    "Zangarmarsh",
	    "BladesEdgeMountains",
	    "Nagrand",
	    "ShadowmoonValley",
		
		-- Northrend
		"BoreanTundra",
		"CrystalsongForest",
		"Dragonblight",
		"GrizzlyHills",
		"HowlingFjord",
		"LakeWintergrasp",
		"TheStormPeaks",
		"IcecrownGlacier",
		"SholazarBasin",
		"ZulDrak",
	},
	
	SANE_INSTANCES = {
		AhnKahet = "Ahn'kahet: The Old Kingdom",
		AzjolNerub = "Azjol-Nerub",
		DrakTharonKeep = "Drak'Tharon Keep",
		GunDrak = "Gundrak",
		HallsofLightning = "Halls of Lightning",
		HallsofStone = "Halls of Stone",
		Naxxramas = "Naxxramas",
		TheCullingofStratholme = "The Culling of Stratholme",
		TheEyeOfEternity = "The Eye of Eternity",
		TheNexus = "The Nexus",
		TheObsidianSanctum = "The Obsidian Sanctum",
		TheOculus = "The Oculus",
		Ulduar = "Ulduar",
		UtgardeKeep = "Utgarde Keep",
		UtgardePinnacle = "Utgarde Pinnacle",
		VioletHold = "The Violet Hold",
		-- Cause Dalaran's multi-floored
		Dalaran = "Dalaran",
	},
	
	INSTANCE_LOCATION_OVERRIDES = {
		Dalaran = {-350, 31400, 200},
		Dalaran2 = {-350, 31150, 200},
	},
}