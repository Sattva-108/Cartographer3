local _G = _G

local Cartographer3 = _G.Cartographer3

Cartographer3.version = GetAddOnMetadata("Cartographer3", "Version")
Cartographer3.date = nil
do
	local timestamp = tonumber(GetAddOnMetadata("Cartographer3", "X-Timestamp"))
	if timestamp then
		Cartographer3.date = date("%B %d, %Y, %H:%M:%S", timestamp)
	end
end
do
	local rawVersion = Cartographer3.version:match("^3.0 v(.*)$")
	if not rawVersion then
		Cartographer3.versionType = "Development"
		Cartographer3.version = "3.0 Development"
	elseif rawVersion:match("%-%d+%-g%x+") then
		Cartographer3.versionType = "Alpha"
		Cartographer3.version = "3." .. rawVersion .. " Alpha"
	elseif not rawVersion:match("^[%d%-_%.]+$") then
		Cartographer3.versionType = "Beta"
		Cartographer3.version = "3." .. rawVersion .. " Beta"
	else
		Cartographer3.versionType = "Release"
		Cartographer3.version = "3." .. rawVersion
	end
end

local LibTourist = LibStub("LibTourist-3.0", true)
if not LibTourist then
	LoadAddOn("LibTourist-3.0")
	LibTourist = LibStub("LibTourist-3.0", true)
	if not LibTourist then
		message(("Cartographer3 requires the library %q and will not work without it."):format("LibTourist-3.0"))
		error(("Cartographer3 requires the library %q and will not work without it."):format("LibTourist-3.0"))
	end
end

local SetNormalFontObject = "SetNormalFontObject"

local BZ = LibStub("LibBabble-Zone-3.0"):GetLookupTable()

local db

Cartographer3.L = _G.Cartographer3_L
_G.Cartographer3_L = nil
local L = Cartographer3.L("Main")

BINDING_HEADER_CARTOGRAPHERTHREE = "Cartographer3"
BINDING_NAME_CARTOGRAPHERTHREE_TOGGLEMAP = L["Toggle map"]
BINDING_NAME_CARTOGRAPHERTHREE_OPENALTERNATEMAP = L["Open alternate map"]

local Cartographer3_Utils = Cartographer3.Utils

local BLIZZARD_MAP_WIDTH = 1002
local BLIZZARD_MAP_HEIGHT_TO_WIDTH_RATIO = 2/3
local BLIZZARD_MINIMAP_TILE_YARD_SIZE = 533 + 1/3

local Cartographer3_Data = Cartographer3.Data
-- TODO: Separate Data from Constants
Cartographer3_Data.CONTINENT_DATA = {}
Cartographer3_Data.ZONE_DATA = {}
Cartographer3_Data.LOCALIZED_ZONE_TO_TEXTURE = {}
Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE = {}
Cartographer3_Data.currentMapTextureWithoutLevel = GetMapInfo()
if GetCurrentMapDungeonLevel() > 1 then
	Cartographer3_Data.currentMapTexture = GetMapInfo() .. GetCurrentMapDungeonLevel()
else
	Cartographer3_Data.currentMapTexture = GetMapInfo()
end
Cartographer3_Data.currentContinentID = GetCurrentMapContinent()

local hijackWorldMap

function Cartographer3.SetConstants(data)
	local CONTINENT_DATA = Cartographer3_Data.CONTINENT_DATA
	Cartographer3.SetConstants = nil
	for k, v in pairs(data) do
		Cartographer3_Data[k] = v
	end
	for k, v in pairs(data.CONTINENT_DATA) do
		CONTINENT_DATA[k] = v
	end
	data.CONTINENT_DATA = CONTINENT_DATA
	
	-- minimap width in pixels / yards at closest radius * yards per pixel
	Cartographer3_Data.MAXIMUM_ZOOM = 140 / (133 + 1/3) * Cartographer3_Data.YARDS_PER_PIXEL
	
	-- able to see twice what the minimap can show
	if not Cartographer3_Data.DEFAULT_ZOOM_TO_MINIMAP_TEXTURE then
		Cartographer3_Data.DEFAULT_ZOOM_TO_MINIMAP_TEXTURE = Cartographer3_Data.MAXIMUM_ZOOM / 7
	end
	
	Cartographer3_Data.MAXIMUM_ZOOM = Cartographer3_Data.MAXIMUM_ZOOM * 4
end

function Cartographer3.SetOverlayData(data)
	Cartographer3.SetOverlayData = nil
	Cartographer3_Data.OVERLAY_DATA = data
end

function Cartographer3.SetTextureData(data)
	Cartographer3.SetTextureData = nil
	Cartographer3_Data.TEXTURE_DATA = data
end

function Cartographer3.SetInstanceTextureData(data)
	Cartographer3.SetInstanceTextureData = nil
	Cartographer3_Data.INSTANCE_TEXTURE_DATA = data
end

local mapHolder, mapFrame, scrollFrame, mapView

local WorldMapFrame = _G.WorldMapFrame

do
	local old_CloseSpecialWindows = _G.CloseSpecialWindows
	function _G.CloseSpecialWindows(...)
	    if not db.closeWithEscape or not mapHolder:IsShown() or not _G.debugstack():find("TOGGLEGAMEMENU") then
	        return old_CloseSpecialWindows(...)
	    end
		old_CloseSpecialWindows()
		mapHolder:Hide()
		return 1
	end
end

local battlegroundFrames = {}

local discoveredOverlays = {}
local undiscoveredOverlayTextures = {}

local function checkOverlays()
	Cartographer3_Utils.RemoveTimer(checkOverlays)
	local currentMapTexture = Cartographer3_Data.currentMapTexture
	
	local numOverlays = GetNumMapOverlays()
	if numOverlays == 0 and not hijackWorldMap then
		if Cartographer_Foglight and Cartographer_Foglight.hooks and Cartographer_Foglight.hooks.GetNumMapOverlays then
			numOverlays = Cartographer_Foglight.hooks.GetNumMapOverlays()
		end
	end
	local len = #currentMapTexture + 21 -- #([=[Interface\WorldMap\]=] .. currentMapTexture .. [=[\]=])
	for i = 1, numOverlays do
		local tname, tw, th, ofx, ofy = GetMapOverlayInfo(i)
		tname = tname:sub(len)
		if not discoveredOverlays[tname] then
			local num = tw + th * 1024 + ofx * 1048576 + ofy * 1073741824
			if num ~= 0 and num ~= 131200 and tname ~= "" and tname:lower() ~= "pixelfix" then
				discoveredOverlays[tname] = num
				for texture in pairs(undiscoveredOverlayTextures) do
					if texture.tName == tname then
						undiscoveredOverlayTextures[texture] = nil
						texture:SetVertexColor(1, 1, 1, 1)
					end
				end
				local OVERLAY_DATA__currentMapTexture = Cartographer3_Data.OVERLAY_DATA[currentMapTexture]
				if not OVERLAY_DATA__currentMapTexture then
					OVERLAY_DATA__currentMapTexture = {}
					Cartographer3_Data.OVERLAY_DATA[currentMapTexture] = OVERLAY_DATA__currentMapTexture
				end
				if OVERLAY_DATA__currentMapTexture[tname] ~= num then
					OVERLAY_DATA__currentMapTexture[tname] = num
					local Cartographer3_NewOverlaysDB = _G.Cartographer3_NewOverlaysDB
					if type(Cartographer3_NewOverlaysDB) ~= "table" then
						Cartographer3_NewOverlaysDB = {}
						_G.Cartographer3_NewOverlaysDB = Cartographer3_NewOverlaysDB
					end
					if not Cartographer3_NewOverlaysDB[currentMapTexture] then
						Cartographer3_NewOverlaysDB[currentMapTexture] = {}
					end
					Cartographer3_NewOverlaysDB[currentMapTexture][tname] = num
				end
			end
		end
	end
end

local instanceTextureFrames = {}

local function WORLD_MAP_UPDATE(event)
	local currentMapTextureWithoutLevel = GetMapInfo()
	local level = GetCurrentMapDungeonLevel()
	local currentMapTexture = currentMapTextureWithoutLevel
	if currentMapTextureWithoutLevel and level > 1 then
		currentMapTexture = currentMapTexture .. level
	end
	
	Cartographer3_Utils.AddTimer(checkOverlays, true)
	if Cartographer3_Data.currentMapTexture == currentMapTexture then
		return
	end
	Cartographer3_Data.currentContinentID = GetCurrentMapContinent()
	if not currentMapTexture then
		if Cartographer3_Data.currentContinentID == -1 then
			currentMapTexture = "Cosmic"
		else
			currentMapTexture = "World"
		end
		currentMapTextureWithoutLevel = currentMapTexture
	end
	Cartographer3_Data.currentMapTextureWithoutLevel = currentMapTextureWithoutLevel
	Cartographer3_Data.currentMapTexture = currentMapTexture
	Cartographer3_Data.currentZoneData = Cartographer3_Data.ZONE_DATA[currentMapTexture]
	Cartographer3_Data.currentContinentData = Cartographer3_Data.CONTINENT_DATA[Cartographer3_Data.currentContinentID]
	
	if hijackWorldMap then
		if Cartographer3_Data.currentZoneData then
			local scale = Cartographer3_Data.currentZoneData.fullWidth / BLIZZARD_MAP_WIDTH
			_G.WorldMapDetailFrame:SetScale(scale)
			_G.WorldMapButton:SetScale(scale)
			WorldMapFrame:SetScale(scale)
			_G.WorldMapPositioningGuide:SetScale(scale)
			_G.WorldMapDetailFrame:ClearAllPoints()
			_G.WorldMapDetailFrame:SetPoint("CENTER", mapView, "CENTER", Cartographer3_Data.currentZoneData.fullCenterX / scale, Cartographer3_Data.currentZoneData.fullCenterY / scale)
		elseif Cartographer3_Data.currentContinentData and Cartographer3_Data.currentContinentData.fullWidth then
			local scale = Cartographer3_Data.currentContinentData.fullWidth / BLIZZARD_MAP_WIDTH
			_G.WorldMapDetailFrame:SetScale(scale)
			_G.WorldMapButton:SetScale(scale)
			WorldMapFrame:SetScale(scale)
			_G.WorldMapPositioningGuide:SetScale(scale)
			_G.WorldMapDetailFrame:ClearAllPoints()
			_G.WorldMapDetailFrame:SetPoint("CENTER", mapView, "CENTER", Cartographer3_Data.currentContinentData.fullCenterX / scale, Cartographer3_Data.currentContinentData.fullCenterY / scale)
		else
			local battlegroundFrame = battlegroundFrames[currentMapTexture]
			if battlegroundFrame then
				local scale = battlegroundFrame.fullWidth / BLIZZARD_MAP_WIDTH
				_G.WorldMapDetailFrame:SetScale(scale)
				_G.WorldMapButton:SetScale(scale)
				WorldMapFrame:SetScale(scale)
				_G.WorldMapPositioningGuide:SetScale(scale)
				_G.WorldMapDetailFrame:ClearAllPoints()
				_G.WorldMapDetailFrame:SetPoint("CENTER", mapView, "CENTER", battlegroundFrame.fullCenterX / scale, battlegroundFrame.fullCenterY / scale)
			else
				local instanceFrame = instanceTextureFrames[currentMapTexture]
				if instanceFrame and instanceFrame.fullWidth then
					local scale = instanceFrame.fullWidth / BLIZZARD_MAP_WIDTH
					_G.WorldMapDetailFrame:SetScale(scale)
					_G.WorldMapButton:SetScale(scale)
					WorldMapFrame:SetScale(scale)
					_G.WorldMapPositioningGuide:SetScale(scale)
					_G.WorldMapDetailFrame:ClearAllPoints()
					_G.WorldMapDetailFrame:SetPoint("CENTER", mapView, "CENTER", instanceFrame.fullCenterX / scale, instanceFrame.fullCenterY / scale)
				end
			end
		end
	end
end
Cartographer3_Utils.AddEventListener("WORLD_MAP_UPDATE", WORLD_MAP_UPDATE)

Cartographer3_Utils.AddEventListener("ZONE_CHANGED_NEW_AREA", function(event)
	if not UnitOnTaxi("player") or not Cartographer3.Utils.IsMouseHovering(scrollFrame) then
		Cartographer3.Utils.ZoomToBestPlayerView()
	end
end)

Cartographer3_Data.instanceTextureFrames = instanceTextureFrames
Cartographer3_Data.instanceTop = 0
Cartographer3_Data.instanceLeft = 0
Cartographer3_Data.instanceBottom = 0
Cartographer3_Data.instanceRight = 0
Cartographer3_Data.instanceRows = 0

Cartographer3_Data.battlegroundFrames = battlegroundFrames

local zoneSearchData = {} -- data in here is split up by continent and then into a 10x10 grid of possible zones, in the order they should be searched (by city and then by area)
Cartographer3_Data.zoneSearchData = zoneSearchData

Cartographer3_Data.cameraX = 0
Cartographer3_Data.cameraY = 0
Cartographer3_Data.cameraZoom = 1

Cartographer3_Data.zoneID_mapping = {}

local function initializeContinentData()
	initializeContinentData = nil
	local continentNames = { GetMapContinents() }
	for i,v in ipairs(continentNames) do
		local data = Cartographer3_Data.CONTINENT_DATA[i]
		if not data then
			-- expansion we don't know about
			data = {
				x = 0,
				y = 375,
				rect = { 0, 1, 0, 1 },
				yards = 20000,
				minimapTextureCenterX = 0,
				minimapTextureCenterY = 0,
				minimapTextureOffsetX = 0,
				minimapTextureOffsetY = 0,
				minimapTextureBackground = "67ba43d493e62a8fad5de319e6d4cb05",
			}
			Cartographer3_Data.CONTINENT_DATA[i] = data
		end
		data.name = v
	end
	for continentID, data in ipairs(Cartographer3_Data.CONTINENT_DATA) do
		local currentContinentData = {}
		Cartographer3_Data.CONTINENT_DATA[continentID] = currentContinentData
		SetMapZoom(continentID)
		currentContinentData.texture = Cartographer3_Data.currentMapTexture
		Cartographer3_Data.CONTINENT_DATA[currentContinentData.texture] = currentContinentData
		currentContinentData.id = continentID
		
		currentContinentData.localizedName = data.name
		
		local continentCenter = data.x
		currentContinentData.fullCenterX = continentCenter
		
		local continentMiddle = data.y
		currentContinentData.fullCenterY = continentMiddle
		
		local continentWidth = data.yards / Cartographer3_Data.YARDS_PER_PIXEL
		currentContinentData.fullWidth = continentWidth
		
		local continentHeight = continentWidth * BLIZZARD_MAP_HEIGHT_TO_WIDTH_RATIO
		currentContinentData.fullHeight = continentHeight
		
		local rect = data.rect
		currentContinentData.visibleLeft = continentCenter + continentWidth * (rect[1] - 0.5)
		currentContinentData.visibleRight = continentCenter + continentWidth * (rect[2] - 0.5)
		currentContinentData.visibleTop = continentMiddle - continentHeight * (rect[3] - 0.5)
		currentContinentData.visibleBottom = continentMiddle - continentHeight * (rect[4] - 0.5)
		
		local zoneNames = { GetMapZones(continentID) }
		local zones = {}
		currentContinentData.zones = zones
		for _ = 1, #zoneNames do
			local x, y
			local name, fileName, texPctX, texPctY, texX, texY, scrollX, scrollY
			
			local finishTime = GetTime() + 0.1
			repeat
				if finishTime < GetTime() then
					fileName = nil
					break
				end
				x, y = math.random(), math.random()
				name, fileName, texPctX, texPctY, texX, texY, scrollX, scrollY = UpdateMapHighlight(x, y)
			until fileName and not zones[fileName]
			if not fileName then
				break
			end
			local zones_fileName = {}
			zones_fileName.continentID = continentID
			for i, n in ipairs(zoneNames) do
				if n == name then
					zones_fileName.id = i
				end
			end
			Cartographer3_Data.zoneID_mapping[continentID * 1000 + zones_fileName.id] = fileName
			zones_fileName.texture = fileName
			zones_fileName.localizedName = name
			Cartographer3_Data.ZONE_DATA[fileName] = zones_fileName
			zones[fileName] = zones_fileName
			Cartographer3_Data.LOCALIZED_ZONE_TO_TEXTURE[name] = fileName
			
			for x = scrollX, scrollX+texX, 0.0025 do
				for y = scrollY, scrollY+texY, 0.0025 do
					if UpdateMapHighlight(x, y) == name then
						if not zones_fileName.highlightLeft then
							zones_fileName.highlightLeft = x
							zones_fileName.highlightRight = x
							zones_fileName.highlightBottom = y
							zones_fileName.highlightTop = y
						else
							if x < zones_fileName.highlightLeft then
								zones_fileName.highlightLeft = x
							elseif x > zones_fileName.highlightRight then
								zones_fileName.highlightRight = x
							end
							if y < zones_fileName.highlightBottom then
								zones_fileName.highlightBottom = y
							elseif y > zones_fileName.highlightTop then
								zones_fileName.highlightTop = y
							end
						end
					end
				end
			end
			
			zones_fileName.highlightLeft = zones_fileName.highlightLeft-0.001
			zones_fileName.highlightRight = zones_fileName.highlightRight+0.001
			zones_fileName.highlightBottom = zones_fileName.highlightBottom-0.001
			zones_fileName.highlightTop = zones_fileName.highlightTop+0.001
			
			if fileName == "EversongWoods" or fileName == "Ghostlands" or fileName == "Sunwell" or fileName == "SilvermoonCity" then
				scrollX = scrollX - 0.00168
				scrollY = scrollY + 0.01
				zones_fileName.highlightLeft = zones_fileName.highlightLeft - 0.00168
				zones_fileName.highlightRight = zones_fileName.highlightRight - 0.00168
				zones_fileName.highlightBottom = zones_fileName.highlightBottom + 0.01
				zones_fileName.highlightTop = zones_fileName.highlightTop + 0.01
				
				zones_fileName.continentOffsetX = -0.00168 * continentWidth
				zones_fileName.continentOffsetY = -0.01 * continentHeight
			else
				zones_fileName.continentOffsetX = 0
				zones_fileName.continentOffsetY = 0
			end
			
			zones_fileName.fullWidth = texX * continentWidth
			zones_fileName.fullHeight = texY * continentHeight
			
			zones_fileName.fullCenterX = (scrollX - 0.5 + texX/2) * continentWidth + continentCenter

			zones_fileName.fullCenterY = (0.5 - scrollY - texY/2) * continentHeight + continentMiddle
			
			zones_fileName.highlightLeft = zones_fileName.highlightLeft * continentWidth - continentWidth/2 + continentCenter
			zones_fileName.highlightRight = zones_fileName.highlightRight * continentWidth - continentWidth/2 + continentCenter
			zones_fileName.highlightBottom, zones_fileName.highlightTop = 1 - zones_fileName.highlightTop, 1 - zones_fileName.highlightBottom
			zones_fileName.highlightBottom = zones_fileName.highlightBottom * continentHeight - continentHeight/2 + continentMiddle
			zones_fileName.highlightTop = zones_fileName.highlightTop * continentHeight - continentHeight/2 + continentMiddle
			
			if Cartographer3_Data.CITIES[fileName] then
				zones_fileName.visibleLeft = zones_fileName.fullCenterX - zones_fileName.fullWidth/2
				zones_fileName.visibleRight = zones_fileName.fullCenterX + zones_fileName.fullWidth/2
				zones_fileName.visibleBottom = zones_fileName.fullCenterY - zones_fileName.fullHeight/2
				zones_fileName.visibleTop = zones_fileName.fullCenterY + zones_fileName.fullHeight/2
			else
				zones_fileName.visibleLeft = math.max(zones_fileName.highlightLeft, zones_fileName.fullCenterX - zones_fileName.fullWidth/2)
				zones_fileName.visibleRight = math.min(zones_fileName.highlightRight, zones_fileName.fullCenterX + zones_fileName.fullWidth/2)
				zones_fileName.visibleBottom = math.max(zones_fileName.highlightBottom, zones_fileName.fullCenterY - zones_fileName.fullHeight/2)
				zones_fileName.visibleTop = math.min(zones_fileName.highlightTop, zones_fileName.fullCenterY + zones_fileName.fullHeight/2)
			end
		end
		
		currentContinentData.minimapTextureCenterX = data.minimapTextureCenterX
		currentContinentData.minimapTextureCenterY = data.minimapTextureCenterY
		currentContinentData.minimapTextureOffsetX = data.minimapTextureOffsetX
		currentContinentData.minimapTextureOffsetY = data.minimapTextureOffsetY
		currentContinentData.minimapTextureBackground = data.minimapTextureBackground
		local extraMinimapTextureAreas = {}
		currentContinentData.extraMinimapTextureAreas = extraMinimapTextureAreas
		if data.extraMinimapTextureAreas then
			for k,v in pairs(data.extraMinimapTextureAreas) do
				extraMinimapTextureAreas[#extraMinimapTextureAreas+1] = {
					k,
					v.minimapTextureCenterX,
					v.minimapTextureCenterY,
				}
			end
		end
		
		currentContinentData.rectLeft = rect[1]
		currentContinentData.rectRight = rect[2]
		currentContinentData.rectTop = rect[3]
		currentContinentData.rectBottom = rect[4]
	end
	SetMapToCurrentZone()
	
	local function zoneSearchData_func(alpha, bravo)
		if Cartographer3_Data.CITIES[bravo] then
			return false
		elseif Cartographer3_Data.CITIES[alpha] then
			return true
		end
		
		local zoneData_alpha = Cartographer3_Data.ZONE_DATA[alpha]
		local zoneData_bravo = Cartographer3_Data.ZONE_DATA[bravo]
		local area_alpha = (zoneData_alpha.highlightRight - zoneData_alpha.highlightLeft) * (zoneData_alpha.highlightTop - zoneData_alpha.highlightBottom)
		local area_bravo = (zoneData_bravo.highlightRight - zoneData_bravo.highlightLeft) * (zoneData_bravo.highlightTop - zoneData_bravo.highlightBottom)
		return area_alpha < area_bravo
	end
	for continentID, currentContinentData in ipairs(Cartographer3_Data.CONTINENT_DATA) do
		local t = {}
		zoneSearchData[continentID] = t
		local zones = currentContinentData.zones
		
		local continentLeft = currentContinentData.visibleLeft
		local continentWidth = currentContinentData.visibleRight - currentContinentData.visibleLeft
		local continentBottom = currentContinentData.visibleBottom
		local continentHeight = currentContinentData.visibleTop - currentContinentData.visibleBottom
		
		for fileName, zoneData in pairs(zones) do
			local zoneLeft = (zoneData.highlightLeft - continentLeft)/continentWidth
			local zoneRight = (zoneData.highlightRight - continentLeft)/continentWidth
			local zoneBottom = (zoneData.highlightBottom - continentBottom)/continentHeight
			local zoneTop = (zoneData.highlightTop - continentBottom)/continentHeight
			for x = 0, 9 do
				if zoneLeft < (x+1)/10 and zoneRight > x/10 then
					for y = 0, 9 do
						if zoneBottom < (y+1)/10 and zoneTop > y/10 then
							local num = x*10 + y
							local u = t[num]
							if not u then
								u = {}
								t[num] = u
							end
							u[#u+1] = fileName
						end
					end
				end
			end
		end
		for num = 0, 99 do
			if t[num] then
				table.sort(t[num], zoneSearchData_func)
			end
		end
	end
end

local mapTextures = {}
local function createMapTextures()
	createMapTextures = nil
	for continentID, currentContinentData in ipairs(Cartographer3_Data.CONTINENT_DATA) do
		local continentCenter = currentContinentData.fullCenterX
		local continentMiddle = currentContinentData.fullCenterY
		local continentWidth = currentContinentData.fullWidth
		local continentHeight = currentContinentData.fullHeight
		local continentTileSize = continentWidth * 256/BLIZZARD_MAP_WIDTH
		local rectLeft = currentContinentData.rectLeft
		local rectRight = currentContinentData.rectRight
		local rectTop = currentContinentData.rectTop
		local rectBottom = currentContinentData.rectBottom
		for i = 1, 12 do
			local good = true
			local left = currentContinentData.rectLeft*1002/1024 * 4 - ((i-1)%4)
			if left < 0 then
				left = 0
			elseif left >= 1 then
				good = false
			end
			local right = currentContinentData.rectRight*1002/1024 * 4 - ((i-1)%4)
			if right > 1 then
				right = 1
			elseif right <= 0 then
				good = false
			end
			local top = currentContinentData.rectTop*668/768 * 3 - math.floor((i-1) / 4)
			if top < 0 then
				top = 0
			elseif top >= 1 then
				good = false
			end
			local bottom =  currentContinentData.rectBottom*668/768 * 3 - math.floor((i-1) / 4)
			if bottom > 1 then
				bottom = 1
			elseif bottom <= 0 then
				good = false
			end
			
			if good then
				local x = ((i-1) % 4) * continentTileSize + continentCenter - continentWidth/2
				local y = -math.floor((i-1) / 4 + 1) * continentTileSize + continentMiddle + continentHeight/2
				local x1 = x + left * continentTileSize
				local x2 = x + right * continentTileSize
				local y1 = y + (1 - bottom) * continentTileSize
				local y2 = y + (1 - top) * continentTileSize
				
				local tex = mapView:CreateTexture(nil--[[mapView:GetName() .. "_MapTexture_" .. currentContinentData.texture .. i]], "BORDER")
				mapTextures[#mapTextures+1] = tex
				local mapFileName = currentContinentData.texture
				tex:SetTexture(([=[Interface\WorldMap\%s\%s%d]=]):format(mapFileName, mapFileName, i))
				tex:SetPoint("BOTTOMLEFT", mapView, "CENTER", x1, y1)
				tex:SetPoint("TOPRIGHT", mapView, "CENTER", x2, y2)
			
				tex:SetTexCoord(left, right, top, bottom)
			end
		end
		
		-- no longer use rect data
		currentContinentData.rectLeft = nil
		currentContinentData.rectRight = nil
		currentContinentData.rectTop = nil
		currentContinentData.rectBottom = nil
	end
end

local cos, sin, abs = cos, sin, math.abs

local totalPOIs = {}
local limitedSizePOIType = {}
local shownPOIs = {}
local poiTypeScales = {}
Cartographer3_Data.totalPOIs = totalPOIs
Cartographer3_Data.shownPOIs = shownPOIs
Cartographer3_Data.poiTypeScales = poiTypeScales
local function poi_Resize(this)
	if not db then
		return
	end
	local cameraZoom = Cartographer3_Data.cameraZoom
	local poiType = this.poiType
	if limitedSizePOIType[poiType] and cameraZoom < Cartographer3_Data.LIMITED_CAMERA_ZOOM then
		cameraZoom = Cartographer3_Data.LIMITED_CAMERA_ZOOM
	end
	local dbScale = db.pois[poiType]
	local size = dbScale * 20 / cameraZoom
	local total_size = size * poiTypeScales[poiType]
	this:SetWidth(total_size)
	this:SetHeight(total_size)
	
	if this.text then
		local a, _, b = this.text:GetFont()
		this.text:SetFont(a, 12 / cameraZoom, b)
		this.text:SetShadowOffset(0.8 / cameraZoom, -0.8 / cameraZoom)
	end
end
local function poi_OnShow(this)
	shownPOIs[this] = true
	this:Resize()
end
local function poi_OnHide(this)
	shownPOIs[this] = nil
end
local inPOI = nil
local function poi_OnEnter(this)
	inPOI = 0
end
local function poi_OnLeave(this)
	inPOI = 0
end
local function poi_OnClick(this, button)
	if button == "LeftButton" and this.OnClick then
		this:OnClick(button)
		return
	end
	mapView:GetScript("OnClick")(mapView, button)
end
local function poi_OnDoubleClick(this, button)
	if button == "LeftButton" and this.OnDoubleClick then
		this:OnDoubleClick(button)
		return
	end
	mapView:GetScript("OnDoubleClick")(mapView, button)
end
local function poi_OnDragStart(this)
	mapView:GetScript("OnDragStart")(mapView)
end
local function poi_OnDragStop(this)
	mapView:GetScript("OnDragStop")(mapView)
end
local function poi_OnMouseDown(this, button)
	mapView:GetScript("OnMouseDown")(mapView, button)
end
local function poi_OnMouseUp(this, button)
	mapView:GetScript("OnMouseUp")(mapView, button)
end

local tmp = {}
local function poi_sort(alpha, bravo)
	local alpha_name = alpha:GetName()
	local bravo_name = bravo:GetName()
	if not alpha_name then
		return false
	elseif not bravo_name then
		return true
	else
		return alpha_name < bravo_name
	end
end
local alreadySetOwner = false
function Cartographer3.UpdatePOITooltips(elapsed, currentTime)
	if not inPOI or inPOI > currentTime then
		return
	end
	inPOI = currentTime + 0.25
	if not alreadySetOwner then
		GameTooltip:SetOwner(mapHolder, "ANCHOR_CURSOR")
		alreadySetOwner = true
	end
	for poi in pairs(shownPOIs) do
		if Cartographer3_Utils.IsMouseHovering(poi) then
			tmp[#tmp+1] = poi
		end
	end
	GameTooltip:ClearLines()
	if #tmp == 0 then
		inPOI = nil
		alreadySetOwner = false
		GameTooltip:Hide()
	elseif #tmp == 1 then
		local poi = tmp[1]
		tmp[1] = nil
		poi:AddDataToFullTooltip()
		local px, py = Cartographer3_Utils.GetUnitUniverseCoordinate("player")
		if px and py then
			local points = poi:GetNumPoints()
			if points == 1 then
				local point, attachment, relpoint, ux, uy = poi:GetPoint()
				if point == "CENTER" and relpoint == "CENTER" and attachment == mapView then
					local zone, x, y = Cartographer3_Utils.ConvertUniverseCoordinateToZoneCoordinate(ux, uy)
					if zone and not instanceTextureFrames[zone] then
						local diffX, diffY = px - ux, py - uy
						local diff = (diffX*diffX + diffY*diffY)^0.5
						local yardDiff = diff * Cartographer3.Data.YARDS_PER_PIXEL
						if yardDiff >= 5 then
							GameTooltip:AddDoubleLine(L["Yards away:"], ("%.0f"):format(yardDiff))
						end
					end
				end
			end
		end
	else
		table.sort(tmp, poi_sort)
		for i, v in ipairs(tmp) do
			v:AddDataToTooltipLine()
			tmp[i] = nil
		end
	end
	GameTooltip:Show()
end

local poiTypes = {}
local poiTypeExampleFrames = {}
Cartographer3_Data.poiTypes = poiTypes
Cartographer3_Data.poiTypeExampleFrames = poiTypeExampleFrames

function Cartographer3.AddPOIType(id, localizedName, exampleFrame, scale, limitedSize)
	if db and db.pois and not db.pois[id] then
		db.pois[id] = 1
	end
	
	poiTypes[id] = localizedName
	poiTypeScales[id] = scale or 1
	poiTypeExampleFrames[id] = exampleFrame
	limitedSizePOIType[id] = limitedSize and true or nil
end

function Cartographer3.AddPOI(poi, poiType)
	if not poiTypes[poiType] then
		error(("Unknown POI Type: %s"):format(tostring(poiType)), 2)
	end
	poi.poiType = poiType
	totalPOIs[poi] = true
	if poi:IsShown() then
		shownPOIs[poi] = true
	end
	if not poi:IsObjectType("Button") then
		error("POI must be a Button", 3)
	end
	poi.Resize = poi_Resize
	poi:SetScript("OnShow", poi_OnShow)
	poi:SetScript("OnHide", poi_OnHide)
	poi:SetScript("OnEnter", poi_OnEnter)
	poi:SetScript("OnLeave", poi_OnLeave)
	poi:SetScript("OnClick", poi_OnClick)
	poi:SetScript("OnDoubleClick", poi_OnDoubleClick)
	poi:SetScript("OnDragStart", poi_OnDragStart)
	poi:SetScript("OnDragStop", poi_OnDragStop)
	poi:SetScript("OnMouseDown", poi_OnMouseDown)
	poi:SetScript("OnMouseUp", poi_OnMouseUp)
	poi:EnableMouse(true)
	poi:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	poi:RegisterForDrag("LeftButton")
	
	poi:Resize()
end

local loadBattlegrounds
do
	function loadBattlegrounds()
		local textures = {}
		for name in LibTourist:IterateBattlegrounds() do
			local texture = LibTourist:GetTexture(name)
			local battlegroundFrame = CreateFrame("Frame", mapView:GetName() .. "_BattlegroundFrame_" .. texture, mapView)
			battlegroundFrames[texture] = battlegroundFrame
			battlegroundFrame.texture = texture
			battlegroundFrame.localizedName = name
			textures[#textures+1] = texture
		end
		do
			local texture = "ScarletEnclave"
			local battlegroundFrame = CreateFrame("Frame", mapView:GetName() .. "_BattlegroundFrame_" .. texture, mapView)
			battlegroundFrames[texture] = battlegroundFrame
			battlegroundFrame.texture = texture
			battlegroundFrame.localizedName = BZ["Plaguelands: The Scarlet Enclave"]
			textures[#textures+1] = texture
		end
		table.sort(textures)
		local width = 30
		local battlegrounds_center = -200
		local battlegrounds_middle = 0
		local non_overridden_textures = 0
		for num, texture in ipairs(textures) do
			if not Cartographer3_Data.BATTLEGROUND_LOCATION_OVERRIDES[texture] then
				non_overridden_textures = non_overridden_textures + 1
			end
		end
		local current_pos_y = 0
		for num, texture in ipairs(textures) do
			local battlegroundFrame = battlegroundFrames[texture]
			
			local instanceTextureFrame = instanceTextureFrames[name]
			local x, y
			if Cartographer3_Data.BATTLEGROUND_LOCATION_OVERRIDES[texture] then
				x, y = unpack(Cartographer3_Data.BATTLEGROUND_LOCATION_OVERRIDES[texture])
			else
				x = battlegrounds_center + (0 - non_overridden_textures/2)*width
				y = battlegrounds_middle - (current_pos_y - non_overridden_textures/2)*width
				current_pos_y = current_pos_y + 1
			end
			battlegroundFrame.fullCenterX = x
			battlegroundFrame.fullCenterY = y
			battlegroundFrame:SetPoint("CENTER", mapView, "CENTER", x, y)
			
			battlegroundFrame.fullWidth = width
			battlegroundFrame.fullHeight = width*2/3
			battlegroundFrame:SetWidth(width)
			battlegroundFrame:SetHeight(width*2/3)
			for i = 1, 12 do
				local tile = battlegroundFrame:CreateTexture(nil, "BACKGROUND")
				tile:SetPoint("TOPLEFT", battlegroundFrame, "TOPLEFT", (i-1)%4 * 256/1002 * width, math.floor((i-1)/4) * -256/1002 * width)
				tile:SetPoint("BOTTOMRIGHT", battlegroundFrame, "TOPLEFT", (((i-1)%4)+1) * 256/1002 * width, math.floor((i-1)/4 + 1) * -256/1002 * width)
				tile:SetTexture(([=[Interface\WorldMap\%s\%s%d]=]):format(texture, texture, i))
			end
			
			local rect = Cartographer3_Data.BATTLEGROUND_RECTS[texture]
			if rect then
				battlegroundFrame.visibleLeft = x + width * (rect[1] - 0.5)
				battlegroundFrame.visibleRight = x + width * (rect[2] - 0.5)
				battlegroundFrame.visibleBottom = y + width*2/3 * (0.5 - rect[4])
				battlegroundFrame.visibleTop = y + width*2/3 * (0.5 - rect[3])
			end
		end
		loadBattlegrounds = nil
	end
end

local loadInstanceTextureSection, loadSaneInstanceSection
do
	local getSizes
	local function layout()
		if loadSaneInstanceSection or getSizes then
			return
		end
		local names = {}
		local widest = 0
		for name, instanceTextureFrame in pairs(instanceTextureFrames) do
			if not instanceTextureFrame.sane then
				local angle = Cartographer3_Data.INSTANCE_ROTATIONS[name] or 0
				angle = angle - 90
				local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = Cartographer3_Utils.RotateTexCoord(angle)
			
				local A, B = abs(cos(angle)), abs(sin(angle))
			
				local left, right, bottom, top
				for i, tex in ipairs(instanceTextureFrame) do
					tex.x, tex.y = Cartographer3_Utils.RotateCoordinate(angle, tex.x + tex.w/2, tex.y + tex.h/2)
					tex.w, tex.h = tex.w*A + tex.h*B, tex.w*B + tex.h*A
					tex:SetWidth(tex.w)
					tex:SetHeight(tex.h)
					tex:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
					local tex_left = tex.x - tex.w/2
					local tex_right = tex.x + tex.w/2
					local tex_bottom = tex.y - tex.h/2
					local tex_top = tex.y + tex.h/2
					if not left then
						left, right, bottom, top = tex_left, tex_right, tex_bottom, tex_top
					else
						if tex_left < left then
							left = tex_left
						elseif tex_right > right then
							right = tex_right
						end
						if tex_bottom < bottom then
							bottom = tex_bottom
						elseif tex_top > top then
							top = tex_top
						end
					end
				end
				local width = right - left
				local height = top - bottom
				local center = left + width/2
				local middle = bottom + height/2
				for i, tex in ipairs(instanceTextureFrame) do
					tex.x = tex.x - center
					tex.y = tex.y - middle
					tex:SetPoint("CENTER", instanceTextureFrame, "CENTER", tex.x, tex.y)
				end
				local full_width = width
				local full_height = height
				if width*2/3 < height then
					full_width = height * 3/2
				else
					full_height = width * 2/3
				end
				if full_width > widest then
					widest = full_width
				end
				instanceTextureFrame:SetWidth(full_width)
				instanceTextureFrame:SetHeight(full_height)
				instanceTextureFrame.fullWidth = full_width * 0.01
				instanceTextureFrame.fullHeight = full_height * 0.01
			end
			if not Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[name] then
				names[#names+1] = name
			end
		end
		Cartographer3_Data.INSTANCE_ROTATIONS = nil
		table.sort(names)
		local rows = math.ceil((#names)^0.5)
		for name, instanceTextureFrame in pairs(instanceTextureFrames) do
			if Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[name] then
				names[#names+1] = name
			end
		end
		local separation = 0.5
		separation = separation + 1
		local instances_center = 60000
		local instances_middle = 0
		for i, name in ipairs(names) do
			local instanceTextureFrame = instanceTextureFrames[name]
			local x, y
			if not Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[name] then
				local pos_x = (i-1) % rows
				local pos_y = math.floor((i-1) / rows)
				x = instances_center + (pos_x - rows/2)*widest*separation
				y = instances_middle - (pos_y - rows/2)*widest*2/3*separation
			else
				x, y = unpack(Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[name])
			end
			instanceTextureFrame.fullCenterX = x * 0.01
			instanceTextureFrame.fullCenterY = y * 0.01
			instanceTextureFrame:SetPoint("CENTER", mapView, "CENTER", x, y)
			instanceTextureFrames[#instanceTextureFrames+1] = instanceTextureFrame
			
			if not instanceTextureFrame.sane then
				local f = CreateFrame("Frame", nil, mapView)
				f:SetScale(instanceTextureFrame:GetScale())
				f:SetWidth(instanceTextureFrame:GetWidth())
				f:SetHeight(instanceTextureFrame:GetHeight())
				f:SetPoint("CENTER", mapView, "CENTER", x, y)
				local background = f:CreateTexture(nil--[[instanceTextureFrame:GetName() .. "_Background"]], "BACKGROUND")
				background:SetTexture(0, 0, 0)
				background:SetAllPoints(f)
			else
				instanceTextureFrame:Show()
				for _, tile in ipairs(instanceTextureFrame) do
					tile:Show()
				end
				instanceTextureFrame:SetAlpha(1)
			end
			instanceTextureFrame:SetParent(nil)
			instanceTextureFrame:SetParent(mapView)
		end
		Cartographer3_Data.instanceLeft = (instances_center - (rows + 1)/2*widest*separation) * 0.01
		Cartographer3_Data.instanceRight = (instances_center + (rows - 1)/2*widest*separation) * 0.01
		Cartographer3_Data.instanceBottom = (instances_middle - (rows - 1)/2*widest*2/3*separation) * 0.01
		Cartographer3_Data.instanceTop = (instances_middle + (rows + 1)/2*widest*2/3*separation) * 0.01
		Cartographer3_Data.instanceRows = rows
		Cartographer3_Utils.RemoveTimer(layout)
		layout = nil
		Cartographer3_Utils.CollectGarbageSoon()
		if IsInInstance() then
			Cartographer3.Utils.ZoomToBestPlayerView()
		end
		if hijackWorldMap then
			WorldMapFrame:SetParent(nil)
			WorldMapFrame:SetParent(mapView)
			_G.WorldMapDetailFrame:SetParent(nil)
			_G.WorldMapDetailFrame:SetParent(mapView)
			_G.WorldMapButton:SetParent(nil)
			_G.WorldMapButton:SetParent(mapView)
			_G.WorldMapPositioningGuide:SetParent(nil)
			_G.WorldMapPositioningGuide:SetParent(mapView)
		end
		for poi in pairs(totalPOIs) do
			local parent = poi:GetParent()
			poi:SetParent(nil)
			poi:SetParent(parent)
		end
	end
	function getSizes()
		local hasBad = false
		for name, instanceTextureFrame in pairs(instanceTextureFrames) do
			local good = true
			for i, tex in ipairs(instanceTextureFrame) do
				if not tex.w then
					local w = tex:GetWidth()
					if w == 0 then
						good = false
						break
					end
					tex.w = w
					tex.h = tex:GetHeight()
				end
			end
			if not good then
				hasBad = name
			end
		end
		if not hasBad then
			Cartographer3_Utils.RemoveTimer(getSizes)
			getSizes = nil
			
			Cartographer3_Utils.AddTimer(layout, true)
		end
	end
	
	local doneInstances = {}
	local workingInstance, workingInstancePosition
	local first = true
	function loadInstanceTextureSection()
		if first then
			first = false
			for name, data in pairs(Cartographer3_Data.INSTANCE_TEXTURE_DATA) do
				local instanceTextureFrame = CreateFrame("Frame", mapView:GetName() .. "_InstanceTextureFrame_" .. name:gsub("[ ']", ""), mapView)
				instanceTextureFrames[name] = instanceTextureFrame
				instanceTextureFrame.name = name
				instanceTextureFrame.localizedName = BZ[name]
				Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE[instanceTextureFrame.localizedName] = instanceTextureFrame
				instanceTextureFrame:SetScale(0.01)
				instanceTextureFrame:SetPoint("CENTER", mapView, "CENTER", 0, 0)
				instanceTextureFrame:SetWidth(1e-10)
				instanceTextureFrame:SetHeight(1e-10)
				instanceTextureFrame:Hide()
				instanceTextureFrame:SetAlpha(0)
			end
			return
		end	
		if not workingInstance then
			for name, data in pairs(Cartographer3_Data.INSTANCE_TEXTURE_DATA) do
				if not doneInstances[name] then
					workingInstance = name
				end
			end
			if not workingInstance then
				-- all done
				Cartographer3_Utils.RemoveTimer(loadInstanceTextureSection)
				loadInstanceTextureSection = nil
				Cartographer3_Data.INSTANCE_TEXTURE_DATA = nil
				Cartographer3_Utils.AddTimer(getSizes, true)
				return
			end
			workingInstancePosition = 0
		end
		
		local workingInstanceData = Cartographer3_Data.INSTANCE_TEXTURE_DATA[workingInstance]
		local instanceTextureFrame = instanceTextureFrames[workingInstance]
		
		local finish = GetTime() + Cartographer3_Data.ITERATIVE_PROCESS_STEP_SECONDS
		while GetTime() < finish do
			local offset = workingInstancePosition * 28
			if offset >= #workingInstanceData then
				workingInstancePosition = nil
				break
			end
			workingInstancePosition = workingInstancePosition + 1
			
			local texturePath = ("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"):format(workingInstanceData:byte(offset + 1, offset + 16))
			
			local x = Cartographer3_Utils.UnpackFloat(workingInstanceData:byte(offset + 17, offset + 20))
			local y = Cartographer3_Utils.UnpackFloat(workingInstanceData:byte(offset + 21, offset + 24))
			local z = Cartographer3_Utils.UnpackFloat(workingInstanceData:byte(offset + 25, offset + 28))
			
			local tex = instanceTextureFrame:CreateTexture(nil--[[minimapStyleTextureFrame:GetName() .. "_Texture" .. x .. "_" .. y .. "_" .. z]], "ARTWORK")
			instanceTextureFrame[#instanceTextureFrame+1] = tex
			tex:SetTexture(([=[textures\Minimap\%s]=]):format(texturePath))
			tex.x = x
			tex.y = y
			tex.z = z
			tex:SetWidth(0)
			tex:SetHeight(0)
		end
		if not workingInstancePosition then
			Cartographer3_Data.INSTANCE_TEXTURE_DATA[workingInstance] = nil
			doneInstances[workingInstance] = true
			workingInstance = nil
		end
	end
	
	local instancesToDo = {}
	local first = true
	function loadSaneInstanceSection()
		if first then
			first = false
			local sane_instances = Cartographer3_Data.SANE_INSTANCES
			Cartographer3_Data.SANE_INSTANCES = nil
			for filename, english in pairs(sane_instances) do
				local instanceTextureFrame = CreateFrame("Frame", mapView:GetName() .. "_InstanceTextureFrame_" .. filename, mapView)
				
				instanceTextureFrame.sane = true
				instanceTextureFrames[filename] = instanceTextureFrame
				instancesToDo[filename] = true
				instanceTextureFrame.name = filename
				instanceTextureFrame.localizedName = ("%s: %s"):format(BZ[english], _G["DUNGEON_FLOOR_" .. filename:upper() .. 1] or FLOOR_NUMBER:format(1))
			
				instanceTextureFrame:SetScale(0.01)
				instanceTextureFrame:SetPoint("CENTER", mapView, "CENTER", 0, 0)
				instanceTextureFrame:SetWidth(1e-10)
				instanceTextureFrame:SetHeight(1e-10)
				instanceTextureFrame:Hide()
				instanceTextureFrame:SetAlpha(0)
				
				local tex = instanceTextureFrame:CreateTexture(nil, "BACKGROUND")
				instanceTextureFrame[#instanceTextureFrame+1] = tex
				local levels = 1
				while levels < 9 do
					tex:SetTexture(([=[Interface\WorldMap\%s\%s%d_1]=]):format(filename, filename, levels+1))
					if not tex:GetTexture() then
						break
					end
					tex:SetTexture(nil)
					levels = levels + 1
				end
				
				instanceTextureFrame.levels = levels
				if levels == 1 then
					instanceTextureFrame.localizedName = BZ[english]
				end
				Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE[instanceTextureFrame.localizedName] = instanceTextureFrame
				
				for i = 2, levels do
					instanceTextureFrame = CreateFrame("Frame", mapView:GetName() .. "_InstanceTextureFrame_" .. filename .. i, mapView)

					instanceTextureFrame.sane = true
					instanceTextureFrames[filename .. i] = instanceTextureFrame
					instancesToDo[filename .. i] = true
					instanceTextureFrame.name = filename .. i
					instanceTextureFrame.localizedName = ("%s: %s"):format(BZ[english], _G["DUNGEON_FLOOR_" .. filename:upper() .. i] or FLOOR_NUMBER:format(i))
					Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE[instanceTextureFrame.localizedName] = instanceTextureFrame
					instanceTextureFrame:SetScale(0.01)
					instanceTextureFrame:SetPoint("CENTER", mapView, "CENTER", 0, 0)
					instanceTextureFrame:SetWidth(1e-10)
					instanceTextureFrame:SetHeight(1e-10)
					instanceTextureFrame:Hide()
					instanceTextureFrame:SetAlpha(0)
				end
			end
			return
		end
		local workingInstance = next(instancesToDo)
		if not workingInstance then
			-- all done
			Cartographer3_Utils.RemoveTimer(loadSaneInstanceSection)
			loadSaneInstanceSection = nil
			Cartographer3_Utils.AddTimer(layout, true)
			return
		end
		instancesToDo[workingInstance] = nil
		
		local instanceTextureFrame = instanceTextureFrames[workingInstance]
		
		local filename, level
		if workingInstance:match("%d+$") then
			filename, level = workingInstance:match("^(.*[^%d])(%d+)$")
			level = level+0
		else
			filename, level = workingInstance, 1
		end
		
		local width = 3000
		if Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[filename] then
			width = Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[filename][3]
		end
		instanceTextureFrame.fullWidth = width / 100
		instanceTextureFrame.fullHeight = width*2/3 / 100
		instanceTextureFrame:SetWidth(width)
		instanceTextureFrame:SetHeight(width*2/3)
		for i = 1, 12 do
			local tile = instanceTextureFrame[i] or instanceTextureFrame:CreateTexture(nil, "BACKGROUND")
			instanceTextureFrame[i] = tile
			tile:SetPoint("TOPLEFT", instanceTextureFrame, "TOPLEFT", (i-1)%4 * 256/1002 * width, math.floor((i-1)/4) * -256/1002 * width)
			tile:SetPoint("BOTTOMRIGHT", instanceTextureFrame, "TOPLEFT", (((i-1)%4)+1) * 256/1002 * width, math.floor((i-1)/4 + 1) * -256/1002 * width)
			tile:SetTexture(([=[Interface\WorldMap\%s\%s%d_%d]=]):format(filename, filename, level, i))
		end
	end
end

local minimapStyleTextureFrames = {}
local loadMinimapStyleTextureSection
do
	local doneContinents = {}
	local workingContinent, workingExtraArea, workingTextureDataPosition
	local first = true
	function loadMinimapStyleTextureSection()
		if first then
			first = false
			for i, currentContinentData in ipairs(Cartographer3_Data.CONTINENT_DATA) do
				local currentContinentData_texture = currentContinentData.texture
				minimapStyleTextureFrame = CreateFrame("Frame", mapView:GetName() .. "_MinimapStyleTextureFrame_" .. currentContinentData_texture, mapView)
				minimapStyleTextureFrames[currentContinentData_texture] = minimapStyleTextureFrame
				local offsetX = -currentContinentData.minimapTextureOffsetX + currentContinentData.fullCenterX
				local offsetY = currentContinentData.minimapTextureOffsetY + currentContinentData.fullCenterY
				minimapStyleTextureFrame:SetPoint("CENTER", mapView, "CENTER", offsetX, offsetY)
				minimapStyleTextureFrame:SetWidth(1e-10)
				minimapStyleTextureFrame:SetHeight(1e-10)
				if currentContinentData.minimapTextureBackground then
					local tex = minimapStyleTextureFrame:CreateTexture(nil--[[minimapStyleTextureFrame:GetName() .. "_Background"]], "BACKGROUND")
					tex:SetTexture(([=[textures\Minimap\%s]=]):format(currentContinentData.minimapTextureBackground))
					tex:SetPoint("BOTTOMLEFT", minimapStyleTextureFrame, "CENTER", currentContinentData.visibleLeft - offsetX, currentContinentData.visibleBottom - offsetY)
					tex:SetPoint("TOPRIGHT", minimapStyleTextureFrame, "CENTER", currentContinentData.visibleRight - offsetX, currentContinentData.visibleTop - offsetY)
				end
				minimapStyleTextureFrame:Hide()
				
			end
			return
		end
		if not workingContinent then
			if Cartographer3_Data.CONTINENT_DATA[Cartographer3_Data.currentMapTexture] then
				workingContinent = Cartographer3_Data.CONTINENT_DATA[Cartographer3_Data.currentMapTexture].id
			elseif Cartographer3_Data.currentZoneData then
				workingContinent = Cartographer3_Data.currentZoneData.continentID
			end
			
			local isDone
			if workingContinent then
				local continentTexture = Cartographer3_Data.CONTINENT_DATA[workingContinent].texture
				isDone = doneContinents[continentTexture]
			end	
			if isDone or not workingContinent then
				workingContinent = nil
				for continentID, currentContinentData in ipairs(Cartographer3_Data.CONTINENT_DATA) do
					if not doneContinents[currentContinentData.texture] then
						workingContinent = continentID
					end
				end
			end
			if not workingContinent then
				-- all done
				Cartographer3_Utils.RemoveTimer(loadMinimapStyleTextureSection)
				Cartographer3_Data.TEXTURE_DATA = nil
				loadMinimapStyleTextureSection = nil
				return
			end
		end
	
		local currentContinentData = Cartographer3_Data.CONTINENT_DATA[workingContinent]
		local currentContinentData_texture = currentContinentData.texture
		local minimapStyleTextureFrame = minimapStyleTextureFrames[currentContinentData_texture]
		
		local size = BLIZZARD_MINIMAP_TILE_YARD_SIZE / Cartographer3_Data.YARDS_PER_PIXEL
		local centerX, centerY
		
		local currentTextureData
		if not workingExtraArea then
			currentTextureData = Cartographer3_Data.TEXTURE_DATA[currentContinentData_texture]
			centerX, centerY = currentContinentData.minimapTextureCenterX, currentContinentData.minimapTextureCenterY
		else
			local extraMinimapTextureArea = currentContinentData.extraMinimapTextureAreas[workingExtraArea]
			currentTextureData = Cartographer3_Data.TEXTURE_DATA[extraMinimapTextureArea[1]]
			centerX, centerY = extraMinimapTextureArea[2], extraMinimapTextureArea[3]
		end
		
		if not currentTextureData then
			doneContinents[currentContinentData.texture] = true
			return
		end
		
		local finish = GetTime() + Cartographer3_Data.ITERATIVE_PROCESS_STEP_SECONDS
		while GetTime() < finish do
			local texturePath
			workingTextureDataPosition, texturePath = next(currentTextureData, workingTextureDataPosition)
			if not workingTextureDataPosition then
				break
			end
			local x, y = math.floor(workingTextureDataPosition / 100), workingTextureDataPosition % 100
			local chunk_num = math.floor(x - centerX) * 100 + math.floor(y - centerY) + 10000
			local tex = minimapStyleTextureFrame:CreateTexture(nil--[[minimapStyleTextureFrame:GetName() .. "_Texture" .. chunk_num]], "ARTWORK")
			minimapStyleTextureFrame[chunk_num] = tex
			tex:Hide()
			tex:SetTexture(([=[textures\Minimap\%s]=]):format(texturePath))
			tex:SetWidth(size)
			tex:SetHeight(size)
			tex:SetAlpha(1)
			tex:SetPoint("BOTTOMLEFT", minimapStyleTextureFrame, "CENTER", (x - centerX) * size, -(y - centerY) * size)
		end
		if not workingTextureDataPosition then
			Cartographer3_Data.TEXTURE_DATA[currentContinentData.texture] = nil
			doneContinents[currentContinentData.texture] = true
			if not workingExtraArea then
				workingExtraArea = 1
			else
				workingExtraArea = workingExtraArea + 1
			end
			
			if not currentContinentData.extraMinimapTextureAreas[workingExtraArea] then
				-- done continent
				workingContinent = nil
				workingExtraArea = nil
				-- no longer using minimap texture data, clear it, refresh the table
				currentContinentData.minimapTextureCenterX = nil
				currentContinentData.minimapTextureCenterY = nil
				currentContinentData.minimapTextureOffsetX = nil
				currentContinentData.minimapTextureOffsetY = nil
				currentContinentData.minimapTextureBackground = nil
				currentContinentData.extraMinimapTextureAreas = nil
			end
		end
	end
end

local zoneFrames = {}
local loadMapOverlayTextureSection
do
	local workingZone
	local doneZones = {}
	local first = true
	function loadMapOverlayTextureSection()
		if first then
			first = false
			
			local order = {}
			for zoneTexture in pairs(Cartographer3_Data.ZONE_DATA) do
				order[#order+1] = zoneTexture
			end
			
			local ZONE_SORT = Cartographer3_Data.ZONE_SORT
			Cartographer3_Data.ZONE_SORT = nil
			local reverse_zone_sort = {}
			for i, v in ipairs(ZONE_SORT) do
				reverse_zone_sort[v] = i
			end
			table.sort(order, function(alpha, bravo)
				if Cartographer3_Data.CITIES[alpha] then
					return false
				elseif Cartographer3_Data.CITIES[bravo] then
					return true
				elseif reverse_zone_sort[alpha] then
					if not reverse_zone_sort[bravo] then
						return true
					else
						return reverse_zone_sort[alpha] < reverse_zone_sort[bravo]
					end
				elseif reverse_zone_sort[bravo] then
					return false
				else
					return alpha > bravo
				end
			end)
			
			for _, zoneTexture in ipairs(order) do
				local zoneData = Cartographer3_Data.ZONE_DATA[zoneTexture]
				local zoneFrame = CreateFrame("Frame", mapView:GetName() .. "_ZoneFrame_" .. zoneTexture, mapView)
				zoneFrame.texture = zoneTexture
				zoneFrame:Hide()
				zoneFrame:SetAlpha(0)
				zoneFrame:SetWidth(BLIZZARD_MAP_WIDTH)
				zoneFrame:SetHeight(BLIZZARD_MAP_WIDTH * BLIZZARD_MAP_HEIGHT_TO_WIDTH_RATIO)
				zoneFrames[zoneTexture] = zoneFrame
				local scale = zoneData.fullWidth / BLIZZARD_MAP_WIDTH
				zoneFrame:SetScale(scale)
				zoneFrame:SetPoint("CENTER", mapView, "CENTER", zoneData.fullCenterX / scale, zoneData.fullCenterY / scale)
			end
			return
		end
		if not workingZone then
			if Cartographer3_Data.currentZoneData then
				workingZone = Cartographer3_Data.currentMapTexture
			end
			
			if not workingZone or doneZones[workingZone] then
				workingZone = nil
				for zoneTexture in pairs(Cartographer3_Data.ZONE_DATA) do
					if not doneZones[zoneTexture] then
						workingZone = zoneTexture
						break
					end
				end
				if not workingZone then
					-- all done
					Cartographer3_Utils.RemoveTimer(loadMapOverlayTextureSection)
					loadMapOverlayTextureSection = nil
					return
				end
			end
		end
		local zoneFrame = zoneFrames[workingZone]
		assert(zoneFrame)
		local overlayData = Cartographer3_Data.OVERLAY_DATA[workingZone]
		doneZones[workingZone] = true
		
		if overlayData then
			local visibleLeft, visibleRight, visibleBottom, visibleTop
			local finishTime = GetTime() + Cartographer3_Data.ITERATIVE_PROCESS_STEP_SECONDS
			for workingTName, num in pairs(overlayData) do
				local textureName = ([=[Interface\WorldMap\%s\%s]=]):format(workingZone, workingTName)
				local textureWidth = num % 1024
				local textureHeight = math.floor(num / 1024) % 1024
				local offsetX = math.floor(num / (1024*1024)) % 1024
				local offsetY = math.floor(num / (1024*1024*1024)) % 1024

				if textureName == [=[Interface\WorldMap\Tirisfal\BRIGHTWATERLAKE]=] then
					if offsetX == 587 then
						offsetX = 584
					end
				elseif textureName == [=[Interface\WorldMap\Silverpine\BERENSPERIL]=] then
					if offsetY == 417 then
						offsetY = 415
					end
				end

				local numTexturesWide = math.ceil(textureWidth / 256)
				local numTexturesTall = math.ceil(textureHeight / 256)

				for j = 1, numTexturesTall do
					local texturePixelHeight
					local textureFileHeight
					if j < numTexturesTall then
						texturePixelHeight = 256
						textureFileHeight = 256
					else
						texturePixelHeight = textureHeight % 256
						if texturePixelHeight == 0 then
							texturePixelHeight = 256
						end
						textureFileHeight = 16
						while textureFileHeight < texturePixelHeight do
							textureFileHeight = textureFileHeight * 2
						end
					end
					for k = 1, numTexturesWide do
						local texturePixelWidth
						local textureFileWidth
						if k < numTexturesWide then
							texturePixelWidth = 256
							textureFileWidth = 256
						else
							texturePixelWidth = textureWidth % 256
							if texturePixelWidth == 0 then
								texturePixelWidth = 256
							end
							textureFileWidth = 16
							while textureFileWidth < texturePixelWidth do
								textureFileWidth = textureFileWidth * 2
							end
						end

						local texture = zoneFrame:CreateTexture(nil--[[zoneFrame:GetName() .. "_Texture" .. (#zoneFrame+1)]], "ARTWORK")
						zoneFrame[#zoneFrame+1] = texture
						if not discoveredOverlays[workingTName] then
							undiscoveredOverlayTextures[texture] = true
							texture:SetVertexColor(unpack(db.unexploredColor))
						end
						texture.tName = workingTName
						texture:SetWidth(texturePixelWidth)
						texture:SetHeight(texturePixelHeight)
						texture:SetTexCoord(0, texturePixelWidth/textureFileWidth, 0, texturePixelHeight/textureFileHeight)
						texture:SetPoint("TOPLEFT", zoneFrame, "TOPLEFT", (offsetX + (256 * (k-1))), -(offsetY + (256 * (j - 1))))
						texture:SetTexture(textureName..(((j - 1) * numTexturesWide) + k))
						
						local left = (offsetX + (256 * (k-1))) - 1002/2
						local right = left + texturePixelWidth
						local top = -(offsetY + (256 * (j - 1))) + 668/2
						local bottom = top - texturePixelHeight
						
						if not visibleLeft then
							visibleLeft = left
							visibleRight = right
							visibleTop = top
							visibleBottom = bottom
						else
							if left < visibleLeft then
								visibleLeft = left
							end
							if right > visibleRight then
								visibleRight = right
							end
							if bottom < visibleBottom then
								visibleBottom = bottom
							end
							if top > visibleTop then
								visibleTop = top
							end
						end
						-- if discovered[tname] then
						-- 	texture:SetVertexColor(1.0,1.0,1.0)
						-- 	texture:SetAlpha(1.0)
						-- else
						-- 	texture:SetVertexColor(self.db.darkR, self.db.darkG, self.db.darkB)
						-- 	texture:SetAlpha(self.db.darkA)
						-- end
						texture:Show()
					end
				end
			end
			local zoneData = Cartographer3_Data.ZONE_DATA[workingZone]
			zoneData.visibleLeft = visibleLeft * zoneData.fullWidth / 1002 + zoneData.fullCenterX
			zoneData.visibleRight = visibleRight * zoneData.fullWidth / 1002 + zoneData.fullCenterX
			zoneData.visibleBottom = visibleBottom * zoneData.fullHeight / 668 + zoneData.fullCenterY
			zoneData.visibleTop = visibleTop * zoneData.fullHeight / 668 + zoneData.fullCenterY
			workingZone = nil
		elseif Cartographer3_Data.CITIES[workingZone] then
			for i = 1, 12 do
				local texture = zoneFrame:CreateTexture(nil--[[zoneFrame:GetName() .. "_Texture" .. (#zoneFrame+1)]], "ARTWORK")
				zoneFrame[#zoneFrame+1] = texture
				texture:SetWidth(256)
				texture:SetHeight(256)
				texture:SetTexture(([=[Interface\WorldMap\%s\%s%d]=]):format(workingZone, workingZone, i))
				texture:SetPoint("TOPLEFT", zoneFrame, "TOPLEFT", ((i - 1) % 4) * 256, -math.floor((i - 1) / 4) * 256)
			end
			workingZone = nil
		else
			workingZone = nil
		end
	end
end

local positionFontStrings = {}
local timeToUpdate = 0
function Cartographer3.UpdatePositionFontString(elapsed, currentTime)
	timeToUpdate = timeToUpdate - elapsed
	if timeToUpdate > 0 then
		return
	else
		timeToUpdate = 0.1
	end
	local cz, cx, cy
	if Cartographer3_Utils.IsMouseHovering(scrollFrame) then
		cz, cx, cy = Cartographer3_Utils.GetCursorZonePosition()
		if not cx then
			cx, cy = 0, 0
		end
	else
		cz, cx, cy = Cartographer3_Data.currentMapTexture, GetPlayerMapPosition("player")
	end
	
	local zoneData = Cartographer3_Data.ZONE_DATA[cz]
	local zoneName
	if zoneData then
		zoneName = zoneData.localizedName
	else
		local continentData = Cartographer3_Data.CONTINENT_DATA[cz]
		if continentData then
			zoneName = continentData.localizedName
		else
			local instanceTextureFrame = instanceTextureFrames[cz]
			if instanceTextureFrame then
				zoneName = instanceTextureFrame.localizedName
			else
				local battlegroundFrame = battlegroundFrames[cz]
				if battlegroundFrame then
					zoneName = battlegroundFrame.localizedName
				end
			end
		end
	end
	
	local zoneLevelMin, zoneLevelMax = 0, 0
	local zoneLevelColor_r, zoneLevelColor_g, zoneLevelColor_b = 1, 1, 1
	local zoneFactionColor_r, zoneFactionColor_g, zoneFactionColor_b = 1, 1, 1
	if zoneName then
		zoneLevelMin, zoneLevelMax = LibTourist:GetLevel(zoneName)
		local z = zoneName
		if zoneLevelMin == 0 and z:match(": ") then
			z = z:match("^(.*): ")
			zoneLevelMin, zoneLevelMax = LibTourist:GetLevel(z)
		end
		zoneLevelColor_r, zoneLevelColor_g, zoneLevelColor_b = LibTourist:GetLevelColor(z)
		zoneFactionColor_r, zoneFactionColor_g, zoneFactionColor_b = LibTourist:GetFactionColor(z)
	end
	if zoneLevelColor_r == 1 and zoneLevelColor_g == 1 and zoneLevelColor_b == 1 then
		zoneLevelColor_r = NORMAL_FONT_COLOR.r
		zoneLevelColor_g = NORMAL_FONT_COLOR.g
		zoneLevelColor_b = NORMAL_FONT_COLOR.b
	end
	if zoneFactionColor_r == 1 and zoneFactionColor_g == 1 and zoneFactionColor_b == 1 then
		zoneFactionColor_r = NORMAL_FONT_COLOR.r
		zoneFactionColor_g = NORMAL_FONT_COLOR.g
		zoneFactionColor_b = NORMAL_FONT_COLOR.b
	end
	
	local subzone
	if Cartographer3_Data.currentMapTexture == cz and (cx ~= 0 or cy ~= 0) then
		subzone = UpdateMapHighlight(cx, cy)
	end
	if zoneName then
		if subzone then
			positionFontStrings[1]:SetFormattedText("%s:", zoneName)
			positionFontStrings[2]:SetFormattedText(" %s", subzone)
		else
			positionFontStrings[1]:SetText(zoneName)
			positionFontStrings[2]:SetText("")
		end
		if zoneLevelMin == 0 then
			positionFontStrings[3]:SetText("")
		elseif zoneLevelMin == zoneLevelMax then
			positionFontStrings[3]:SetFormattedText(" [%d]", zoneLevelMin, zoneLevelMax)
		else
			positionFontStrings[3]:SetFormattedText(" [%d-%d]", zoneLevelMin, zoneLevelMax)
		end
		if cx ~= 0 or cy ~= 0 then
			positionFontStrings[4]:SetFormattedText(" (%.1f%s%.1f)", cx*100, Cartographer3_Data.COORDINATE_SEPARATOR, cy*100)
		else
			positionFontStrings[4]:SetText("")
		end
		for i = 1, 2 do
			positionFontStrings[i]:SetTextColor(
				zoneFactionColor_r,
				zoneFactionColor_g,
				zoneFactionColor_b
			)
		end
		positionFontStrings[3]:SetTextColor(
			zoneLevelColor_r,
			zoneLevelColor_g,
			zoneLevelColor_b
		)
	else
		for i, v in ipairs(positionFontStrings) do
			v:SetText("")
			v:SetTextColor(
				NORMAL_FONT_COLOR.r,
				NORMAL_FONT_COLOR.g,
				NORMAL_FONT_COLOR.b
			)
		end
	end
end

local moving, mouseDown = false, false
function Cartographer3.ShowUIOnHover(elapsed, currentTime)
	local alpha = mapFrame:GetAlpha()
	if db.alwaysShowBorder or moving or mouseDown or Cartographer3_Utils.IsMouseHovering(mapFrame) then
		if alpha == 1 then
			return
		end
		alpha = alpha + elapsed/Cartographer3_Data.FADE_TIME
		if alpha > 1 then
			alpha = 1
		end
	else
		if alpha == 0 then
			return
		end
		alpha = alpha - elapsed/Cartographer3_Data.FADE_TIME
		if alpha < 0 then
			alpha = 0
		end
	end
	mapFrame:SetAlpha(alpha)
end

function Cartographer3.FixViewIfMoving(elapsed, currentTime)
	if moving then
		Cartographer3.Utils.ReadjustCamera()
	end
end

local sizingPoint
function Cartographer3.ChangeCursorIfOnSide(elapsed, currentTime)
	if not mouseDown and mapHolder == GetMouseFocus() then
		local cx, cy = Cartographer3_Utils.GetScaledCursorPosition()
		local x, y, w, h = mapHolder:GetRect()
		local bottomSize = cy >= y and cy <= y + 10
		local topSize = cy <= y + h and cy >= y + h - 10
		local leftSize = cx >= x and cx <= x + 10
		local rightSize = cx <= x + w and cx >= x + w - 10
		
		sizingPoint = nil
		if topSize then
			sizingPoint = "TOP"
		elseif bottomSize then
			sizingPoint = "BOTTOM"
		end
		if leftSize then
			sizingPoint = (sizingPoint or '') .. "LEFT"
		elseif rightSize then
			sizingPoint = (sizingPoint or '') .. "RIGHT"
		end
		if sizingPoint then
			SetCursor([=[Interface\Cursor\Inspect]=])
		else
			SetCursor("POINT_CURSOR")
		end
	end
end

local dragStartX, dragStartY, dragging
function Cartographer3.DragMap(elapsed, currentTime)
	if dragging then
		local cursorX, cursorY = Cartographer3_Utils.GetCursorUniverseCoordinate()
		local diffX, diffY = dragStartX - cursorX, dragStartY - cursorY
		Cartographer3_Data.cameraX = Cartographer3_Data.cameraX + diffX
		Cartographer3_Data.cameraY = Cartographer3_Data.cameraY + diffY
		Cartographer3.Utils.ReadjustCamera()
	end
end

local lastShowMinimapStyle = 0
function Cartographer3.SwitchTextureStyleOnZoom(elapsed, currentTime)
	if Cartographer3_Data.cameraZoom > db.zoomToMinimapTexture then
		if lastShowMinimapStyle == 1 then
			return
		end
		
		Cartographer3_Utils.AddTimer(Cartographer3.ShowMinimapStyleTexturesWhenInsideView)
		
		lastShowMinimapStyle = lastShowMinimapStyle + elapsed/Cartographer3_Data.FADE_TIME
		if lastShowMinimapStyle >= 1 then
			lastShowMinimapStyle = 1
			for zoneTexture, zoneFrame in pairs(zoneFrames) do
				if not Cartographer3_Data.INDOOR_CITIES[zoneTexture] then
					zoneFrame:Hide()
					if zoneFrame:GetAlpha() == 1 then
						zoneFrame:SetAlpha(0.999)
					end
				end
			end
		end
		for _, minimapStyleTextureFrame in pairs(minimapStyleTextureFrames) do
			minimapStyleTextureFrame:Show()
			minimapStyleTextureFrame:SetAlpha(lastShowMinimapStyle)
		end
	else
		if lastShowMinimapStyle == 0 then
			return
		end
		
		lastShowMinimapStyle = lastShowMinimapStyle - elapsed/Cartographer3_Data.FADE_TIME
		if lastShowMinimapStyle <= 0 then
			lastShowMinimapStyle = 0
			for _, minimapStyleTextureFrame in pairs(minimapStyleTextureFrames) do
				minimapStyleTextureFrame:Hide()
			end
			Cartographer3_Utils.RemoveTimer(Cartographer3.ShowMinimapStyleTexturesWhenInsideView)
		end
		for _, minimapStyleTextureFrame in pairs(minimapStyleTextureFrames) do
			minimapStyleTextureFrame:SetAlpha(lastShowMinimapStyle)
		end
	end
end

local lastShownTextures = {}
local tmp = {}
function Cartographer3.ShowMinimapStyleTexturesWhenInsideView(elapsed, currentTime)
	lastShownTextures, tmp = tmp, lastShownTextures
	local currentContinentID
	for continentID, currentContinentData in ipairs(Cartographer3_Data.CONTINENT_DATA) do
		local continentLeft = currentContinentData.visibleLeft
		local continentRight = currentContinentData.visibleRight
		local continentBottom = currentContinentData.visibleBottom
		local continentTop = currentContinentData.visibleTop
		if Cartographer3_Data.cameraX >= continentLeft and Cartographer3_Data.cameraX <= continentRight and Cartographer3_Data.cameraY >= continentBottom and Cartographer3_Data.cameraY <= continentTop then
			currentContinentID = continentID
			break
		end 
	end
	if currentContinentID then
		local currentContinentData = Cartographer3_Data.CONTINENT_DATA[currentContinentID]
		local continentTexture = currentContinentData.texture
		local minimapStyleTextureFrame = minimapStyleTextureFrames[continentTexture]
		local center = Cartographer3_Data.cameraX - currentContinentData.fullCenterX
		local middle = currentContinentData.fullCenterY - Cartographer3_Data.cameraY
		center = center * Cartographer3_Data.YARDS_PER_PIXEL
		middle = middle * Cartographer3_Data.YARDS_PER_PIXEL
		center = math.floor(center / BLIZZARD_MINIMAP_TILE_YARD_SIZE)
		middle = math.ceil(middle / BLIZZARD_MINIMAP_TILE_YARD_SIZE)
		
		local x_len = math.ceil((scrollFrame:GetWidth()/Cartographer3_Data.cameraZoom * Cartographer3_Data.YARDS_PER_PIXEL / BLIZZARD_MINIMAP_TILE_YARD_SIZE) / 2) + 1
		local y_len = math.ceil((scrollFrame:GetHeight()/Cartographer3_Data.cameraZoom * Cartographer3_Data.YARDS_PER_PIXEL / BLIZZARD_MINIMAP_TILE_YARD_SIZE) / 2) + 1
		for i = center - x_len, center + x_len do
			for j = middle - y_len, middle + y_len do
				local tex = minimapStyleTextureFrame[i * 100 + j + 10000]
				if tex then
					tex:Show()
					lastShownTextures[tex] = true
					tmp[tex] = nil
				end
			end
		end
	end
	for tex in pairs(tmp) do
		tex:Hide()
		tmp[tex] = nil
	end
end

local lastZoneFrame
local currentZoneFrame
local recentShown = {}
function Cartographer3.ShowMapTexturesWhenHovering(elapsed, currentTime)
	local fade_difference = elapsed/Cartographer3_Data.FADE_TIME
	local cursorZone
	if Cartographer3_Utils.IsMouseHovering(scrollFrame) then
		cursorZone = Cartographer3_Utils.GetCursorZonePosition()
	else
		cursorZone = Cartographer3_Data.currentMapTexture
	end
	local zoneFrame = zoneFrames[cursorZone]
	if not zoneFrame then
		zoneFrame = instanceTextureFrames[cursorZone]
		if zoneFrame and zoneFrame.sane then
			zoneFrame = nil
		end
	end
	if zoneFrame then
		local alpha = zoneFrame:GetAlpha()
		if alpha < 1 or currentZoneFrame ~= zoneFrame then
			alpha = alpha + fade_difference
			if alpha >= 1 then
				alpha = 1
			end
			recentShown[zoneFrame] = true
			if currentZoneFrame ~= zoneFrame then
				if not currentZoneFrame or not Cartographer3_Data.CITIES[currentZoneFrame.texture] then
					lastZoneFrame = currentZoneFrame
				end
				currentZoneFrame = zoneFrame
			end
			currentZoneFrame:Show()
			currentZoneFrame:SetAlpha(alpha)
		end
	elseif currentZoneFrame then
		local alpha = currentZoneFrame:GetAlpha()
		if alpha < 1 then
			alpha = alpha + fade_difference
			if alpha >= 1 then
				alpha = 1
			end
			currentZoneFrame:Show()
			currentZoneFrame:SetAlpha(alpha)
		end
	end
	if lastZoneFrame then
		local alpha = lastZoneFrame:GetAlpha()
		if alpha < 1 then
			alpha = alpha + fade_difference
			if alpha >= 1 then
				alpha = 1
			end
			lastZoneFrame:Show()
			lastZoneFrame:SetAlpha(alpha)
		end
	end
	for frame in pairs(recentShown) do
		if frame ~= currentZoneFrame and frame ~= lastZoneFrame then
			local alpha = frame:GetAlpha()
			if alpha > 0 then
				alpha = alpha - fade_difference
				if alpha <= 0 then
					alpha = 0
					frame:Hide()
					recentShown[frame] = nil
				end
				frame:SetAlpha(alpha)
			end
		end
	end
end

do
	local currentBG = nil
	local currentInstance = nil
	local function SetCurrentInstance(value)
		if currentInstance == value then
			return
		end
		currentInstance = value
		if _G.Cartographer then
			_G.Cartographer:SetCurrentInstance(value and BZ[value] or nil)
		end
	end
	local old_GetMapInfo = _G.GetMapInfo
	function _G.GetMapInfo(...)
		if currentBG then
			return currentBG, 668, 768
		elseif currentInstance then
			local name = currentInstance
			if name:match("%d+$") then
				name = name:match("^(.*[^%d])%d+")
			end
			return name, 668, 768
		else
			return old_GetMapInfo(...)
		end
	end

	local old_SetMapZoom = _G.SetMapZoom
	function _G.SetMapZoom(...)
		currentBG = nil
		SetCurrentInstance(nil)
		old_SetMapZoom(...)
	end
	
	local old_GetCurrentMapDungeonLevel = _G.GetCurrentMapDungeonLevel
	function _G.GetCurrentMapDungeonLevel(...)
		if currentInstance then
			if currentInstance:match("%d+$") then
				return currentInstance:match("%d+$")+0
			end
			local texture = instanceTextureFrames[currentInstance]
			if texture.levels then
				return 1
			end
			return 0
		end
		return old_GetCurrentMapDungeonLevel(...)
	end
	
	local old_GetNumDungeonMapLevels = _G.GetNumDungeonMapLevels
	function _G.GetNumDungeonMapLevels(...)
		if currentInstance then
			currentInstance = currentInstance:match("^(.*[^%d])%d+$") or currentInstance
			local texture = instanceTextureFrames[currentInstance]
			return texture.levels ~= 1 and texture.levels or 0
		end
		return old_GetNumDungeonMapLevels(...)
	end
	
	local old_SetMapToCurrentZone = _G.SetMapToCurrentZone
	function _G.SetMapToCurrentZone(...)
		local zoneText = GetRealZoneText()
		if zoneText == BZ["Tempest Keep"] then
			zoneText = BZ["The Eye"]
		end
		
		currentBG = nil
		
		if IsInInstance() and Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE[zoneText] then
			Cartographer3.ShowInstance(Cartographer3_Data.LOCALIZED_INSTANCE_TO_TEXTURE[zoneText].name)
			return
		end
		
		SetCurrentInstance(nil)
		old_SetMapToCurrentZone(...)
	end
	
	local old_UpdateMapHighlight = _G.UpdateMapHighlight
	function _G.UpdateMapHighlight(...)
		if currentBG or currentInstance then
			return nil
		else
			return old_UpdateMapHighlight(...)
		end
	end
	
	local old_GetPlayerMapPosition = _G.GetPlayerMapPosition
	function _G.GetPlayerMapPosition(...)
		if currentBG or currentInstance then
			return 0, 0
		else
			return old_GetPlayerMapPosition(...)
		end
	end
	
	local old_GetCorpseMapPosition = _G.GetCorpseMapPosition
	function _G.GetCorpseMapPosition(...)
		if currentBG or currentInstance then
			return 0, 0
		else
			return old_GetCorpseMapPosition(...)
		end
	end
	
	local old_GetDeathReleasePosition = _G.GetDeathReleasePosition
	function _G.GetDeathReleasePosition(...)
		if currentBG or currentInstance then
			return 0, 0
		else
			return old_GetDeathReleasePosition(...)
		end
	end
	
	local old_GetNumBattlefieldFlagPositions = _G.GetNumBattlefieldFlagPositions
	function _G.GetNumBattlefieldFlagPositions(...)
		if currentBG or currentInstance then
			return 0
		else
			return old_GetNumBattlefieldFlagPositions(...)
		end
	end
	
	local old_GetNumMapLandmarks = _G.GetNumMapLandmarks
	function _G.GetNumMapLandmarks(...)
		if currentBG or currentInstance then
			return 0
		else
			return old_GetNumMapLandmarks(...)
		end
	end
	
	local old_GetNumMapOverlays = _G.GetNumMapOverlays
	function _G.GetNumMapOverlays(...)
		if currentBG or currentInstance then
			return 0
		else
			return old_GetNumMapOverlays(...)
		end
	end
	
	function Cartographer3.ShowBattleground(texture)
		if texture == "ScarletEnclave" then
			if GetRealZoneText() == BZ["Eastern Plaguelands"] then
				SetMapToCurrentZone()
				if old_GetMapInfo() == "ScarletEnclave" then
					return
				end
				SetCurrentInstance(nil)
				currentBG = texture
				old_SetMapZoom(0)
			end
		elseif battlegroundFrames[texture].localizedZone == GetRealZoneText() then
			SetMapToCurrentZone()
		else
			SetCurrentInstance(nil)
			currentBG = texture
			old_SetMapZoom(0)
		end
	end
	
	function Cartographer3.ShowInstance(name)
		currentBG = nil
		SetCurrentInstance(name)
		old_SetMapZoom(0)
	end
end

local lastToCurrentZone = true
function Cartographer3.ChangeCurrentMapOnZoneHover(elapsed, currentTime)
	if Cartographer3_Utils.IsMouseHovering(scrollFrame) then
		local cursorZone, cursorX, cursorY = Cartographer3_Utils.GetCursorZonePosition()
		if cursorZone == Cartographer3_Data.currentMapTexture then
			return
		end
		local zoneData = Cartographer3_Data.ZONE_DATA[cursorZone]
		if zoneData then
			SetMapZoom(zoneData.continentID, zoneData.id)
			lastToCurrentZone = false
		else
			local continentData = Cartographer3_Data.CONTINENT_DATA[cursorZone]
			if continentData then
				SetMapZoom(continentData.id)
				lastToCurrentZone = false
			else
				local battlegroundFrame = battlegroundFrames[cursorZone]
				if battlegroundFrame then
					Cartographer3.ShowBattleground(cursorZone)
					lastToCurrentZone = false
				else
					local instanceFrame = instanceTextureFrames[cursorZone]
					if instanceFrame then
						Cartographer3.ShowInstance(cursorZone)
						lastToCurrentZone = false
					elseif not lastToCurrentZone then
						SetMapToCurrentZone()
						lastToCurrentZone = true
					end
				end
			end
		end
	else
		if not lastToCurrentZone then
			SetMapToCurrentZone()
			lastToCurrentZone = true
		end
	end
end

local zoneSelectButton, zoomSliderButton

mapHolder = CreateFrame("Frame", "Cartographer_MapHolder", UIParent)
Cartographer3_Data.mapHolder = mapHolder
mapFrame = CreateFrame("Frame", "Cartographer_MapFrame", mapHolder)
Cartographer3_Data.mapFrame = mapFrame
scrollFrame = CreateFrame("ScrollFrame", mapHolder:GetName() .. "_ScrollFrame", mapHolder)
Cartographer3_Data.scrollFrame = scrollFrame
mapView = CreateFrame("Button", mapHolder:GetName() .. "_MapView", scrollFrame)
Cartographer3_Data.mapView = mapView

local rightClickMenuHandlers = {}
function Cartographer3.AddRightClickMenuHandler(func)
	rightClickMenuHandlers[func] = true
end

local function createMapHolder()
	createMapHolder = nil
	mapHolder:SetWidth(db[db.alternateMap and "alternateWidth" or "width"])
	mapHolder:SetHeight(db[db.alternateMap and "alternateHeight" or "height"])
	local position = db[db.alternateMap and "alternatePosition" or "position"]
	mapHolder:SetPoint(position[1], UIParent, position[1], position[2], position[3])
	mapHolder:EnableMouse(true)
	mapHolder:SetMovable(true)
	mapHolder:SetResizable(true)
	mapHolder:RegisterForDrag("LeftButton")
	mapHolder:SetMinResize(Cartographer3_Data.MAPFRAME_MINRESIZE_WIDTH, Cartographer3_Data.MAPFRAME_MINRESIZE_HEIGHT)
	mapHolder:SetScript("OnShow", function(this)
		if hijackWorldMap then
			WorldMapFrame:Show()
		end
		db.shown = true
		Cartographer3.Utils.ZoomToBestPlayerView()
	end)
	mapHolder:SetScript("OnHide", function(this)
		if hijackWorldMap then
			WorldMapFrame:Hide()
		end
		db.shown = false
		SetMapToCurrentZone()
		dragging = false
		Cartographer3.UpdatePOITooltips(0, GetTime())
	end)
	if not db.shown then
		mapHolder:Hide()
	end
	
	mapFrame:SetFrameLevel(mapHolder:GetFrameLevel()+2)
	mapFrame:SetAllPoints(mapHolder)
	
	mapFrame.bg = CreateFrame("Frame", mapFrame:GetName() .. "_Background", mapFrame)
	mapFrame.bg:SetAllPoints(mapFrame)
	mapFrame.bg:SetFrameLevel(mapHolder:GetFrameLevel())
	
	mapFrame.bg:SetBackdrop {
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = {
			left = 5,
			right = 6,
			top = 5,
			bottom = 6
		}
	}
	
	for i = 1, 4 do
		local positionFontString = mapHolder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		positionFontStrings[i] = positionFontString
		positionFontString:SetJustifyH("LEFT")
	end
	Cartographer3_Utils.AddTimer(Cartographer3.UpdatePositionFontString)
	Cartographer3_Utils.AddTimer(Cartographer3.FixViewIfMoving)
	Cartographer3_Utils.AddTimer(Cartographer3.ChangeCursorIfOnSide)
	mapHolder:SetScript("OnLeave", function(this)
		mouseDown = false
		SetCursor("POINT_CURSOR")
	end)
	
	mapHolder:SetScript("OnMouseDown", function(this, button)
		if button == "LeftButton" then
			mouseDown = true
		end
	end)
	mapHolder:SetScript("OnMouseUp", function(this, button)
		if button == "LeftButton" then
			mouseDown = false
		end
	end)
	mapHolder:SetScript("OnDragStart", function(this)
		moving = true
		if sizingPoint then
			SetCursor([=[Interface\Cursor\Inspect]=])
			this:StartSizing(sizingPoint)
		else
			SetCursor("POINT_CURSOR")
			this:StartMoving()
		end
	end)
	mapHolder:SetScript("OnDragStop", function(this)
		moving = false
		mouseDown = false
		SetCursor("POINT_CURSOR")
		this:StopMovingOrSizing()
		
		Cartographer3.Utils.ReadjustCamera()
		db[db.alterateMap and "alternateWidth" or "width"] = this:GetWidth()
		db[db.alterateMap and "alternateHeight" or "height"] = this:GetHeight()
		
		local width, height = GetScreenWidth(), GetScreenHeight()
		local uiscale = UIParent:GetEffectiveScale()
		local scale = this:GetEffectiveScale() / uiscale
		local x, y = this:GetCenter()
		x, y = x*scale, y*scale
		local point
		if x < width/3 then
			point = "LEFT"
			x = x - this:GetWidth()/2*scale
		elseif x < width*2/3 then	
			point = ""
			x = x - width/2
		else
			point = "RIGHT"
			x = x - width + this:GetWidth()/2*scale
		end
		if y < height/3 then
			point = "BOTTOM" .. point
			y = y - this:GetHeight()/2*scale
		elseif y < height*2/3 then
			if point == "" then
				point = "CENTER"
			end
			y = y - height/2
		else
			point = "TOP" .. point
			y = y - height + this:GetHeight()/2*scale
		end
		x, y = x/scale, y/scale
		this:ClearAllPoints()
		this:SetPoint(point, UIParent, point, x, y)
		local position = db[db.alternateMap and "alternatePosition" or "position"]
		position[1] = point
		position[2] = x
		position[3] = y
	end)
	Cartographer3_Utils.AddTimer(Cartographer3.ShowUIOnHover)
	mapHolder:SetClampedToScreen()
	mapHolder:SetClampRectInsets(10, -10, -10, 10)
	
	scrollFrame:SetScrollChild(mapView)
	scrollFrame:SetPoint("BOTTOMLEFT", mapHolder, "BOTTOMLEFT", 11, 10)
	scrollFrame:SetPoint("TOPRIGHT", mapHolder, "TOPRIGHT", -10, -30)
	mapView:SetWidth(10000)
	mapView:SetHeight(10000)
	Cartographer3.Utils.ReadjustCamera()
	mapView:EnableMouse(true)
	mapView:EnableMouseWheel(true)
	mapView:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mapView:SetScript("OnUpdate", _G.RequestBattlefieldPositions)
	
	positionFontStrings[1]:SetPoint("BOTTOMLEFT", scrollFrame, "TOPLEFT", 0, 5)
	for i = 2, #positionFontStrings do
		positionFontStrings[i]:SetPoint("LEFT", positionFontStrings[i-1], "RIGHT", 0, 0)
	end
	
	local bg = mapView:CreateTexture(nil--[[mapView:GetName() .. "_Background"]], "BACKGROUND")
	bg:SetTexture(unpack(Cartographer3_Data.DEFAULT_MAPVIEW_BACKGROUND_COLOR))
	bg:SetAllPoints(mapView)
	createMapTextures()
	mapView:RegisterForDrag("LeftButton")
	Cartographer3_Utils.AddTimer(loadMapOverlayTextureSection, true)
	loadMapOverlayTextureSection()
	Cartographer3_Utils.AddTimer(loadMinimapStyleTextureSection, true)
	loadMinimapStyleTextureSection()
	Cartographer3_Utils.AddTimer(loadInstanceTextureSection, true)
	loadInstanceTextureSection()
	Cartographer3_Utils.AddTimer(loadSaneInstanceSection, true)
	loadSaneInstanceSection()
	loadBattlegrounds()
	for zoneTexture, zoneFrame in pairs(zoneFrames) do
		if Cartographer3_Data.INDOOR_CITIES[zoneTexture] then
			local p = zoneFrame:GetParent()
			zoneFrame:SetParent(UIParent)
			zoneFrame:SetParent(p)
		end
	end
	Cartographer3_Utils.AddTimer(Cartographer3.DragMap)
	Cartographer3_Utils.AddTimer(Cartographer3.SwitchTextureStyleOnZoom)
	Cartographer3_Utils.AddTimer(Cartographer3.ShowMapTexturesWhenHovering)
	mapView:SetScript("OnMouseDown", function(this, button)
		if button == "LeftButton" then
			dragStartX, dragStartY = Cartographer3_Utils.GetCursorUniverseCoordinate()
		end
	end)
	mapView:SetScript("OnMouseUp", function(this, button)
		dragging = false
		if Cartographer3_Utils.IsMouseHovering(_G.WorldMapButton) then
			_G.WorldMapButton:GetScript("OnMouseUp")(_G.WorldMapButton, button)
		end
	end)
	mapView:SetScript("OnDragStart", function(this)
		dragging = true
		Cartographer3_Utils.MoveMap()
	end)
	mapView:SetScript("OnDragStop", function(this)
		dragging = false
	end)
	mapView:SetScript("OnDoubleClick", function(this, arg1)
		if arg1 == "LeftButton" then
			local zone = Cartographer3_Utils.GetCursorZonePosition()
			if zone then
				Cartographer3_Utils.ZoomToZone(zone)
			end
		end
	end)
	local data = { pois = {} }
	local dropdownFrame
	local first = true
	local function zoomFunc(self, zone)
		Cartographer3.Utils.ZoomToZone(zone)
	end
	local function dropdownFunc()
		if first then
			first = nil
			return
		end
		Cartographer3.ChangeCurrentMapOnZoneHover() -- this is done because right-click does a zoom out
		local separator = false
		local first = true
		local map = Cartographer3_Data.currentMapTextureWithoutLevel
		local instanceTextureFrame = instanceTextureFrames[map]
		if _G.UIDROPDOWNMENU_MENU_LEVEL == 1 and instanceTextureFrame and instanceTextureFrame.levels and instanceTextureFrame.levels > 1 then
			first = false
			separator = true
			
			local level = GetCurrentMapDungeonLevel()
			
			for i = 1, instanceTextureFrame.levels do
				if level ~= i then
					local info = UIDropDownMenu_CreateInfo()
					info.text = L["Zoom to %s"]:format(_G["DUNGEON_FLOOR_" .. map:upper() .. i] or FLOOR_NUMBER:format(i))
					info.func = zoomFunc
					info.arg1 = i == 1 and map or map .. i
					UIDropDownMenu_AddButton(info, 1)
				end
			end
		end
		
		for func in pairs(rightClickMenuHandlers) do
			local created = func(data, _G.UIDROPDOWNMENU_MENU_LEVEL, _G.UIDROPDOWNMENU_MENU_VALUE, not first)
			if created then
				first = false
			end
		end
	end
	mapView:SetScript("OnClick", function(this, arg1)
		if arg1 == "RightButton" then
			data.zoneTexture, data.zoneX, data.zoneY = Cartographer3_Utils.GetCursorZonePosition()
			if not data.zoneTexture then
				return
			end
			data.zoneData = Cartographer3_Data.ZONE_DATA[data.zoneTexture]
			data.continentData = Cartographer3_Data.CONTINENT_DATA[data.zoneTexture]
			data.battlegroundFrame = battlegroundFrames[data.zoneTexture]
			data.instanceFrame = instanceTextureFrames[data.zoneTexture]
			data.universeX, data.universeY = Cartographer3_Utils.GetCursorUniverseCoordinate()
			local pois = data.pois
			for i in ipairs(pois) do
				pois[i] = nil
			end
			for poi in pairs(shownPOIs) do
				if Cartographer3_Utils.IsMouseHovering(poi) then
					pois[#pois+1] = poi
				end
			end
			
			if not dropdownFrame then
				dropdownFrame = CreateFrame("Frame", this:GetName() .. "_Dropdown", this, "UIDropDownMenuTemplate")
				dropdownFrame.displayMode = "MENU"
				UIDropDownMenu_Initialize(dropdownFrame, dropdownFunc, "MENU", nil)
			end
			if DropDownList1:IsShown() then
				ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 0, 0, nil)
			end
			ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 0, 0, nil)
		end
	end)
	
	mapView:SetScript("OnMouseWheel", function(this, arg1)
		local cursorX, cursorY = Cartographer3_Utils.GetCursorUniverseCoordinate()
		local zoomIn = arg1 > 0
		local zoom = Cartographer3_Data.gradualCameraZoom or Cartographer3_Data.cameraZoom
		if zoomIn then
			zoom = zoom / Cartographer3_Data.ZOOM_STEP
			if zoom > Cartographer3_Data.MAXIMUM_ZOOM then
				zoom = Cartographer3_Data.MAXIMUM_ZOOM
			end
		else
			zoom = zoom * Cartographer3_Data.ZOOM_STEP
			if zoom < Cartographer3_Data.MINIMUM_ZOOM then
				zoom = Cartographer3_Data.MINIMUM_ZOOM
			end
		end
		if zoom == Cartographer3_Data.cameraZoom then
			Cartographer3_Utils.MoveMap()
		else
			if Cartographer3_Utils.GetMoveMapMessage() == 'player' then
				Cartographer3_Utils.MoveMap(
					nil,
					nil,
				    zoom,
					true,
					'player'
				)
			else
				local cursorX, cursorY = Cartographer3_Utils.GetCursorUniverseCoordinate()
			
				Cartographer3_Utils.MoveMap(
					(Cartographer3_Data.cameraX - cursorX) * Cartographer3_Data.cameraZoom / zoom + cursorX,
					(Cartographer3_Data.cameraY - cursorY) * Cartographer3_Data.cameraZoom / zoom + cursorY,
				    zoom,
					true
				)
			end
		end
	end)
	
	Cartographer3_Utils.AddTimer(Cartographer3.ChangeCurrentMapOnZoneHover)
	
	Cartographer3_Utils.AddTimer(Cartographer3.UpdatePOITooltips)
	
	local closeButton = CreateFrame("Button", mapFrame:GetName() .. "_CloseButton", mapFrame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -7, -9)
	closeButton:SetScript("OnClick", function(this)
		mapHolder:Hide()
	end)
	closeButton:GetNormalTexture():SetTexCoord(0.17, 0.8, 0.2, 0.8)
	closeButton:GetPushedTexture():SetTexCoord(0.17, 0.8, 0.2, 0.8)
	closeButton:GetHighlightTexture():SetTexCoord(0.17, 0.8, 0.2, 0.8)
	closeButton:SetWidth(22)
	closeButton:SetHeight(22)
	
--	positionFontString:SetPoint("RIGHT", closeButton, "LEFT", -3, 0)
	
	local button_num = 0
	local lastLeft, lastRight
	local function makeButton(text, side, clickFunc, check, initialChecked, tooltipText)
		button_num = button_num + 1
		local button = CreateFrame(check and "CheckButton" or "Button", mapFrame:GetName() .. "_Button" .. button_num, mapFrame)
		if side == "RIGHT" then
			if not lastRight then
				button:SetPoint("BOTTOMRIGHT", mapFrame, "BOTTOMRIGHT", -7, 9)
			else
				button:SetPoint("RIGHT", lastRight, "LEFT", -3, 0)
			end
			lastRight = button
		else
			if not lastLeft then
				button:SetPoint("BOTTOMLEFT", mapFrame, "BOTTOMLEFT", 8, 9)
			else
				button:SetPoint("LEFT", lastLeft, "RIGHT", 3, 0)
			end
			lastLeft = button
		end
		button:SetWidth(22)
		button:SetHeight(22)
		button:EnableMouse(true)
		button:SetText(text)
		button:RegisterForClicks("LeftButtonUp")
		
		local left = button:CreateTexture(nil--[[button:GetName() .. "Left"]], "BACKGROUND")
		left:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		left:SetWidth(12)
		left:SetHeight(22)
		left:SetTexCoord(0, 0.09375, 0, 0.6875)
		left:SetPoint("LEFT")
		local right = button:CreateTexture(nil--[[button:GetName() .. "Right"]], "BACKGROUND")
		right:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		right:SetWidth(12)
		right:SetHeight(22)
		right:SetTexCoord(0.53125, 0.625, 0, 0.6875)
		right:SetPoint("RIGHT")
		local middle = button:CreateTexture(nil--[[button:GetName() .. "Middle"]], "BACKGROUND")
		middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
		middle:SetPoint("LEFT", left, "RIGHT")
		middle:SetPoint("RIGHT", right, "LEFT")
		
		local highlight = button:CreateTexture(nil--[[button:GetName() .. "Highlight"]], "HIGHLIGHT")
		highlight:SetTexture([[Interface\Buttons\UI-Panel-Button-Highlight]])
		highlight:SetTexCoord(0, 0.625, 0, 0.6875)
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints()

		button:SetHighlightTexture(highlight)
		local function setDown(this)
			button:GetFontString():SetPoint("CENTER", 1.28, -1.28)
			left:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
			right:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
			middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Down]])
		end
		local function setUp(this)
			button:GetFontString():SetPoint("CENTER", 0, 0)
			left:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
			right:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
			middle:SetTexture([[Interface\Buttons\UI-Panel-Button-Up]])
		end
		button:SetScript("OnMouseDown", function(this)
			local checked = this.GetChecked and this:GetChecked()
			if checked then
				setUp(this)
			else
				setDown(this)
			end
		end)
		button:SetScript("OnMouseUp", function(this)
			local checked = this.GetChecked and this:GetChecked()
			if checked then
				setDown(this)
			else
				setUp(this)
			end
		end)
		button:SetScript("OnClick", function(this, button)
			if this.GetChecked then
				clickFunc(not not this:GetChecked())
				this:GetScript("OnMouseUp")(this)
			else
				clickFunc()
			end
		end)
		button:SetScript("OnEnter", function(this)
			GameTooltip:SetOwner(this, side == "RIGHT" and "ANCHOR_TOPRIGHT" or "ANCHOR_TOPLEFT")
			GameTooltip:SetText(tooltipText)
		end)
		button:SetScript("OnLeave", function(this)
			GameTooltip:Hide()
		end)
		button[SetNormalFontObject](button, GameFontNormal)
		button:SetText(text)
		button:SetPushedTextOffset(0, 0)
		if check and initialChecked then
			button:SetChecked(true)
			setDown(button)
		end
		return button
	end
	local openConfigButton = makeButton("C", "RIGHT", function()
		InterfaceOptionsFrame_OpenToCategory("Cartographer3")
	end, false, false, L["Open the configuration menu for Cartographer3"])
	local followPlayer = db.followPlayer
	local followPlayerButton = makeButton("P", "RIGHT", Cartographer3.SetFollowPlayer, true, followPlayer, L["Make the map follow the player POI as you move around"])
	Cartographer3.SetFollowPlayer(followPlayer)
	local zoomToZoneButton = makeButton("Z", "RIGHT", Cartographer3_Utils.ZoomToCurrentZone, false, false, L["Go to to your current zone"])
	zoneSelectButton = makeButton("G", "LEFT", Cartographer3.OpenGotoDropdownMenu, false, false, L["Go to a certain zone"])
	zoomSliderButton = makeButton("S", "RIGHT", Cartographer3.OpenZoomSlider, false, false, L["Set zoom level"])
	
	if hijackWorldMap then
		WorldMapTooltip:SetParent(mapHolder)
		WorldMapTooltip:SetFrameStrata("TOOLTIP")
		WorldMapFrame:SetParent(mapView)
		WorldMapFrame:SetAlpha(0)
		WorldMapFrame:SetScale(1e-5)
		if mapHolder:IsShown() then
			WorldMapFrame:Show()
		end
		_G.WorldMapDetailFrame:SetParent(mapView)
		_G.WorldMapButton:SetParent(mapView)
		_G.WorldMapPositioningGuide:SetParent(mapView)
		_G.WorldMapDetailFrame:Show()
		_G.WorldMapButton:Show()
		_G.WorldMapPositioningGuide:Show()
	end
end

local dropdownFrame
local gotoDropdownMenu

function Cartographer3.OpenGotoDropdownMenu()
	if not dropdownFrame then
		dropdownFrame = CreateFrame("Frame", mapHolder:GetName() .. "_Dropdown", mapHolder, "UIDropDownMenuTemplate")
	end
	if not gotoDropdownMenu then
		local function menuSort(alpha, bravo)
			return alpha.text < bravo.text
		end
		gotoDropdownMenu = {}
		local instanceSection = {
			text = L["Instances"],
			hasArrow = true,
			menuList = {},
		}
		gotoDropdownMenu[#gotoDropdownMenu+1] = instanceSection
		local instanceSection_menuList = instanceSection.menuList
		local citySection = {
			text = L["Cities"],
			hasArrow = true,
			menuList = {},
		}
		gotoDropdownMenu[#gotoDropdownMenu+1] = citySection
		local citySection_menuList = citySection.menuList
		local zoneSection = {
			text = L["Zones"],
			hasArrow = true,
			menuList = {},
		}
		gotoDropdownMenu[#gotoDropdownMenu+1] = zoneSection
		local zoneSection_menuList = zoneSection.menuList
		local battlegroundSection = {
			text = L["Battlegrounds"],
			hasArrow = true,
			menuList = {},
		}
		gotoDropdownMenu[#gotoDropdownMenu+1] = battlegroundSection
		local battlegroundSection_menuList = battlegroundSection.menuList
		for i, v in ipairs(Cartographer3_Data.CONTINENT_DATA) do
			local instances = {}
			for key, instanceTextureFrame in pairs(instanceTextureFrames) do
				local name = instanceTextureFrame.localizedName
				local continent = LibTourist:GetContinent(name)
				if continent == UNKNOWN and name:match(": ") then
					local n = name:match("^(.*): ")
					continent = LibTourist:GetContinent(n)
				end
				if continent == v.localizedName then
					local x = {
						text = name,
						func = function(self, zone)
							Cartographer3_Utils.ZoomToZone(zone)
						end,
						arg1 = key,
					}
					instances[#instances+1] = x
				end
			end
			table.sort(instances, menuSort)
			
			local battlegrounds = {}
			for name in LibTourist:IterateBattlegrounds() do
				if LibTourist:GetContinent(name) == v.localizedName then
					local x = {
						text = name,
						func = function(self, zone)
							Cartographer3_Utils.ZoomToZone(zone)
						end,
						arg1 = LibTourist:GetTexture(name),
					}
					battlegrounds[#battlegrounds+1] = x
				end
			end
			table.sort(battlegrounds, menuSort)
			
			local cities = {}
			local zones = {}
			for texture, zone in pairs(v.zones) do
				local x = {
					text = zone.localizedName,
					func = function(self, zone)
						Cartographer3_Utils.ZoomToZone(zone)
					end,
					arg1 = texture,
				}
				if Cartographer3_Data.CITIES[texture] then
					cities[#cities+1] = x
				else
					zones[#zones+1] = x
				end
			end
			table.sort(cities, menuSort)
			table.sort(zones, menuSort)
			
			instanceSection_menuList[#instanceSection_menuList+1] = {
				text = v.localizedName,
				hasArrow = true,
				func = function(self, zone)
					Cartographer3_Utils.ZoomToZone(zone)
				end,
				arg1 = v.texture,
				menuList = instances,
			}
			
			battlegroundSection_menuList[#battlegroundSection_menuList+1] = {
				text = v.localizedName,
				hasArrow = true,
				func = function(self, zone)
					Cartographer3_Utils.ZoomToZone(zone)
				end,
				arg1 = v.texture,
				menuList = battlegrounds,
			}
			
			citySection_menuList[#citySection_menuList+1] = {
				text = v.localizedName,
				hasArrow = true,
				func = function(self, zone)
					Cartographer3_Utils.ZoomToZone(zone)
				end,
				arg1 = v.texture,
				menuList = cities,
			}
			
			zoneSection_menuList[#zoneSection_menuList+1] = {
				text = v.localizedName,
				hasArrow = true,
				func = function(self, zone)
					Cartographer3_Utils.ZoomToZone(zone)
				end,
				arg1 = v.texture,
				menuList = zones,
			}
		end
		table.sort(instanceSection_menuList, menuSort)
		table.sort(battlegroundSection_menuList, menuSort)
		table.sort(citySection_menuList, menuSort)
		table.sort(zoneSection_menuList, menuSort)
		table.sort(gotoDropdownMenu, menuSort)
	end
	if DropDownList1:IsShown() and dropdownFrame.menuList == gotoDropdownMenu then
		CloseDropDownMenus()
	else
		EasyMenu(gotoDropdownMenu, dropdownFrame, zoneSelectButton, 0, 0, "MENU")
	end
end

local sliderFrame
function Cartographer3.OpenZoomSlider()
	if not sliderFrame then
		sliderFrame = CreateFrame("Frame", mapFrame:GetName() .. "_SliderFrame", mapFrame)
		Cartographer3_Data.sliderFrame = sliderFrame
		sliderFrame:Hide()
		
		sliderFrame:SetWidth(46)
		sliderFrame:SetHeight(170)
		sliderFrame:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
			tile = true,
			insets = {
				left = 5,
				right = 5,
				top = 5,
				bottom = 5
			},
			tileSize = 16,
			edgeSize = 16
		})
		sliderFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		sliderFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
		sliderFrame:EnableMouse(true)
		sliderFrame:Hide()
		sliderFrame:SetPoint("CENTER", UIParent, "CENTER")
		local slider = CreateFrame("Slider", sliderFrame:GetName() .. "_Slider", sliderFrame)
		sliderFrame.slider = slider
		slider:SetOrientation("VERTICAL")
		slider:SetMinMaxValues(0, 1)
		slider:SetValueStep(1e-10)
		slider:SetValue(0.5)
		slider:SetWidth(16)
		slider:SetHeight(128)
		slider:SetPoint("CENTER", sliderFrame, "CENTER", 0, 0)
		slider:SetBackdrop({
			bgFile = [[Interface\Buttons\UI-SliderBar-Background]],
			edgeFile = [[Interface\Buttons\UI-SliderBar-Border]],
			tile = true,
			edgeSize = 8,
			tileSize = 8,
			insets = {
				left = 3,
				right = 3,
				top = 3,
				bottom = 3
			}
		})
		slider:SetThumbTexture([[Interface\Buttons\UI-SliderBar-Button-Vertical]])
		
		local MAXIMUM_ZOOM_log = math.log(Cartographer3_Data.MAXIMUM_ZOOM)
		local MINIMUM_ZOOM_log = math.log(Cartographer3_Data.MINIMUM_ZOOM)
		local changing = false
		slider:SetScript("OnValueChanged", function(this)
			if changing then
				return
			end
			local value = (1 - this:GetValue()) * (MAXIMUM_ZOOM_log - MINIMUM_ZOOM_log) + MINIMUM_ZOOM_log
			Cartographer3_Utils.MoveMap(nil, nil, math.exp(value))
		end)
		local closeTime = 0
		sliderFrame:SetScript("OnShow", function(this)
			closeTime = GetTime() + 5
		end)
		sliderFrame:SetScript("OnUpdate", function(this)
			local currentTime = GetTime()
			if Cartographer3_Utils.IsMouseHovering(this) then
				closeTime = currentTime + 3
			end
			if currentTime > closeTime then
				this:Hide()
			end
		end)
		
		function slider:set(value)
			changing = true
			
			self:SetValue(-(value - MINIMUM_ZOOM_log)/(MAXIMUM_ZOOM_log - MINIMUM_ZOOM_log) + 1)
			
			changing = false
		end
	end
	if sliderFrame:IsShown() then
		sliderFrame:Hide()
	else
		sliderFrame:Show()
		sliderFrame:SetPoint("BOTTOMRIGHT", zoomSliderButton, "TOPRIGHT")
	end
end

local lastPlayerX, lastPlayerY = 0, 0
function Cartographer3.FollowPlayerIfMoved()
	if Cartographer3_Utils.GetMoveMapMessage() ~= 'player' and Cartographer3_Utils.IsMouseHovering(mapHolder) then
		return
	end
	local playerX, playerY = Cartographer3_Utils.GetUnitUniverseCoordinate("player")
	if not playerX or math.abs(lastPlayerX - playerX) < 1e-10 and math.abs(lastPlayerY - playerY) < 1e-10 then
		return
	end
	lastPlayerX, lastPlayerY = playerX, playerY
	Cartographer3_Utils.ZoomToPlayer()
end

function Cartographer3.SetFollowPlayer(follow)
	db.followPlayer = follow
	if follow then
		lastPlayerX, lastPlayerY = 0, 0
		Cartographer3_Utils.AddTimer(Cartographer3.FollowPlayerIfMoved)
		Cartographer3_Utils.ZoomToPlayer()
	else
		if Cartographer3_Utils.GetMoveMapMessage() == 'player' then
			Cartographer3_Utils.MoveMap()
		end
		Cartographer3_Utils.RemoveTimer(Cartographer3.FollowPlayerIfMoved)
	end
end

function Cartographer3.SetFrameStrata(value)
	mapHolder:SetFrameStrata(value)
	db.strata = value
end

function Cartographer3.SetOpacity(value)
	if value < 0.1 then
		value = 0.1
	elseif value > 1 then
		value = 1
	end
	mapHolder:SetAlpha(value)
	db.opacity = value
end

function Cartographer3.SetUnexploredColor(r, g, b, a)
	for texture in pairs(undiscoveredOverlayTextures) do
		texture:SetVertexColor(r, g, b, a)
	end
	db.unexploredColor[1] = r
	db.unexploredColor[2] = g
	db.unexploredColor[3] = b
	db.unexploredColor[4] = a
end

local defaults
local function PLAYER_LOGOUT(event)
	local function removeDefaults(t, d)
		for k, v in pairs(d) do
			if type(t[k]) == type(v) then
				if type(v) == "table" then
					removeDefaults(t[k], v)
					if next(t[k]) == nil then
						t[k] = nil
					end
				else
					if t[k] == v then
						t[k] = nil
					end
				end
			end
		end
	end
	removeDefaults(db, defaults)
	db.version = 1
end
Cartographer3_Utils.AddEventListener("PLAYER_LOGOUT", PLAYER_LOGOUT)

local function fixDefaults(t, d)
	for k, v in pairs(d) do
		if type(v) == "table" then
			if type(t[k]) ~= "table" then
				t[k] = {}
			end
			fixDefaults(t[k], v)
		elseif t[k] == nil then
			t[k] = v
		end
	end
end

local moduleDefaults = {}
local modules = {}
Cartographer3.modules = modules
function Cartographer3.NewModule(name, localizedName, localizedDesc, modDefaults)
	local t = { name = localizedName, desc = localizedDesc }
	Cartographer3[name] = t
	_G["Cartographer3_" .. name] = t -- add a global for easy checking from 3rd parties
	if defaults then
		defaults[name] = modDefaults
		if type(db[name]) ~= "table" then
			db[name] = {}
		end
		fixDefaults(db[name], modDefaults)
	else
		moduleDefaults[name] = modDefaults
	end
	Cartographer3.potentialModules[name] = nil
	modules[name] = t
	if db then
		local function ADDON_LOADED(event, addon)
			if addon ~= "Cartographer3_" .. name then
				return
			end
			Cartographer3.Utils.RemoveEventListener("ADDON_LOADED", ADDON_LOADED)
			if t.OnInitialize then
				t.OnInitialize()
				t.OnInitialize = nil
			end
		end
		Cartographer3.Utils.AddEventListener("ADDON_LOADED", ADDON_LOADED)
	end
	
	function t.IsEnabled()
		return not db[name].disabled
	end
	return t
end

Cartographer3.potentialModules = {}

local function ADDON_LOADED(event, addon)
	if addon ~= "Cartographer3" then
		return
	end
	Cartographer3_Utils.RemoveEventListener("ADDON_LOADED", ADDON_LOADED)
	ADDON_LOADED = nil
	defaults = {
		width = Cartographer3_Data.DEFAULT_MAPFRAME_WIDTH,
		height = Cartographer3_Data.DEFAULT_MAPFRAME_HEIGHT,
		position = { "CENTER", 0, 0 },
		alternateWidth = Cartographer3_Data.DEFAULT_ALTERNATE_MAPFRAME_WIDTH,
		alternateHeight = Cartographer3_Data.DEFAULT_ALTERNATE_MAPFRAME_HEIGHT,
		alternatePosition = { "BOTTOMRIGHT", 0, 0 },
		shown = true,
		followPlayer = true,
		zoomToMinimapTexture = Cartographer3_Data.DEFAULT_ZOOM_TO_MINIMAP_TEXTURE,
		strata = "FULLSCREEN",
		closeWithEscape = true,
		opacity = 1,
		unexploredColor = { 1, 1, 1, 1 },
		hijackWorldMap = true,
		pois = {},
		alternateMap = false,
		showGroupMemberNamesInBattlegrounds = true,
		groupMemberNamePosition = "RIGHT",
		alwaysShowBorder = false,
	}
	db = _G.Cartographer3DB
	if type(db) ~= "table" then
		db = { version = 1 }
		_G.Cartographer3DB = db
	end
	if not db.version then -- old AceDB stuff
		if type(db.profiles) == "table" then
			local global_profile = db.profiles.global
			db.profiles = nil
			db.profileKeys = nil
			if global_profile then
				for k, v in pairs(global_profile) do
					db[k] = v
				end
			end
			db.version = 1
		end
	end
	db.version = nil
	for name, d in pairs(moduleDefaults) do
		defaults[name] = d
		if type(db[name]) ~= "table" then
			db[name] = {}
		end
		moduleDefaults[name] = nil
	end
	fixDefaults(db, defaults)
	Cartographer3.db = db
	
	hijackWorldMap = db.hijackWorldMap
	Cartographer3.hijackingWorldMap = hijackWorldMap
	
	for id in pairs(poiTypes) do
		if not db.pois[id] then
			db.pois[id] = 1
		end
	end
	
	function Cartographer3.ToggleMap()
		if mapHolder:IsShown() then
			mapHolder:Hide()
		else
			mapHolder:Show()
		end
	end
	
	local function refixMap()
		local alternateMap = db.alternateMap
		
		mapHolder:SetWidth(db[alternateMap and "alternateWidth" or "width"])
		mapHolder:SetHeight(db[alternateMap and "alternateHeight" or "height"])
		local position = db[alternateMap and "alternatePosition" or "position"]
		mapHolder:ClearAllPoints()
		mapHolder:SetPoint(position[1], UIParent, position[1], position[2], position[3])
		
	end
	
	local function f()
		Cartographer3_Utils.RemoveTimer(f)
		Cartographer3.Utils.ReadjustCamera()
	end
	function Cartographer3.OpenAlternateMap()
		if not mapHolder:IsShown() then
			mapHolder:Show()
			return
		end
		
		db.alternateMap = not db.alternateMap
		
		local previousWidth, previousHeight = mapHolder:GetWidth(), mapHolder:GetHeight()
		
		refixMap()
		
		local width, height = mapHolder:GetWidth(), mapHolder:GetHeight()
		
		Cartographer3_Data.cameraZoom = Cartographer3_Data.cameraZoom * ((width * height) / (previousWidth * previousHeight))^0.5
		
		Cartographer3_Utils.AddTimer(f)
	end
	refixMap()
	
	if hijackWorldMap then
		if _G.ToggleWorldMap then
			_G.ToggleWorldMap = Cartographer3.ToggleMap
		else
			local old_ToggleFrame = _G.ToggleFrame
			function _G.ToggleFrame(...)
				if (...) == WorldMapFrame then
					return Cartographer3.ToggleMap()
				end
				return old_ToggleFrame(...)
			end
		end
		
		WorldMapTooltip:SetParent(UIParent)
		WorldMapTooltip:SetFrameStrata("TOOLTIP")
		local currentOwner, currentPoint
		local old_WorldMapTooltip_SetOwner = WorldMapTooltip.SetOwner
		function WorldMapTooltip.SetOwner(this, owner, point)
			-- do a SetOwner hack since if you set it to the owner inside the mapView, then there are scaling issues and it would be stuck inside the scroll child. This way, it gives the same effect as the author intended.
			currentOwner = owner
			currentPoint = point
			old_WorldMapTooltip_SetOwner(this, mapHolder, "ANCHOR_NONE")
			this:ClearAllPoints()
			if point == "ANCHOR_TOPRIGHT" then
				this:SetPoint("BOTTOMRIGHT", currentOwner, "TOPRIGHT")
			elseif point == "ANCHOR_RIGHT" then
				this:SetPoint("BOTTOMLEFT", currentOwner, "TOPRIGHT")
			elseif point == "ANCHOR_BOTTOMRIGHT" then
				this:SetPoint("TOPLEFT", currentOwner, "BOTTOMRIGHT")
			elseif point == "ANCHOR_TOPLEFT" then
				this:SetPoint("BOTTOMLEFT", currentOwner, "TOPLEFT")
			elseif point == "ANCHOR_LEFT" then
				this:SetPoint("BOTTOMRIGHT", currentOwner, "TOPLEFT")
			elseif point == "ANCHOR_BOTTOMLEFT" then
				this:SetPoint("TOPRIGHT", currentOwner, "BOTTOMLEFT")
			elseif point == "ANCHOR_CURSOR" then
				old_WorldMapTooltip_SetOwner(this, mapHolder, "ANCHOR_CURSOR")
			elseif point == "ANCHOR_PRESERVE" then
				this:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 80)
			end
		end
		function WorldMapTooltip.IsOwned(this, owner)
			return currentOwner == owner
		end
		local function HideWorldMapFrames(...)
			for i = 1, select('#', ...) do
				local v = select(i, ...)
				local name = v:GetName()
				if name and name:match("^WorldMap") then
					v:Hide()
					if v:GetObjectType() == "Texture" or v:GetObjectType("FontString") then
						v:SetParent(UIParent)
					else
						v:SetParent(nil)
					end
				end
			end
		end	
		UIPanelWindows["WorldMapFrame"] = nil
		WorldMapFrame:SetAttribute("UIPanelLayout-enabled", false)
		WorldMapFrame:SetFrameStrata("MEDIUM")
		WorldMapFrame:EnableMouse(nil)
		WorldMapFrame:EnableMouseWheel(nil)
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetWidth(1024)
		WorldMapFrame:SetHeight(768)
		HideWorldMapFrames(_G.WorldMapDetailFrame:GetRegions())
		HideWorldMapFrames(_G.WorldMapButton:GetChildren())
		_G.WorldMapButton:EnableMouse(false)
		_G.WorldMapButton:SetScript("OnUpdate", nil)
		function _G.WorldMapButton_OnClick()
			-- hopefully I don't destroy another addon's hooks here, but *shrug*
		end
		_G.WorldMapButton:SetScript("OnEvent", nil)
		_G.WorldMapButton:UnregisterAllEvents()
		WorldMapFrame:SetScript("OnShow", nil)
		WorldMapFrame:SetScript("OnHide", nil)
		WorldMapFrame:SetScript("OnEvent", nil)
		WorldMapFrame:UnregisterAllEvents()
		WorldMapFrame:SetScript("OnUpdate", nil)
		WorldMapFrame:SetScript("OnKeyDown", nil)
		_G.WorldMapDetailFrame:ClearAllPoints()
		_G.WorldMapButton:SetParent(_G.WorldMapDetailFrame)
		WorldMapFrame:SetPoint("CENTER", _G.WorldMapDetailFrame, "CENTER", 2, 17) -- get relatively in the same position
		function WorldMapFrame:GetScale()
			-- hack to make old CTMod code work
			return self:GetEffectiveScale()
		end
		_G.WorldMapPositioningGuide:SetPoint("CENTER", _G.WorldMapDetailFrame, "CENTER", 2, 17)
	else
		if not GetBindingKey("CARTOGRAPHERTHREE_TOGGLEMAP") and (not GetBindingAction("ALT-SHIFT-M") or GetBindingAction("ALT-SHIFT-M") == "") then
			SetBinding("ALT-SHIFT-M", "CARTOGRAPHERTHREE_TOGGLEMAP")
		end
	end
	if not GetBindingKey("CARTOGRAPHERTHREE_OPENALTERNATEMAP") and (not GetBindingAction("ALT-M") or GetBindingAction("ALT-M") == "") then
		SetBinding("ALT-M", "CARTOGRAPHERTHREE_OPENALTERNATEMAP")
	end
	
	Cartographer3.SetFrameStrata(db.strata)
	Cartographer3.SetOpacity(db.opacity)
	Cartographer3.SetUnexploredColor(unpack(db.unexploredColor))
	local Cartographer3_NewOverlaysDB = _G.Cartographer3_NewOverlaysDB
	if type(Cartographer3_NewOverlaysDB) == "table" then
		for zoneTexture, overlayData in pairs(Cartographer3_NewOverlaysDB) do
			if type(overlayData) ~= "table" then
				Cartographer3_NewOverlaysDB[zoneTexture] = {}
			end
			if not Cartographer3_Data.OVERLAY_DATA[zoneTexture] then
				Cartographer3_Data.OVERLAY_DATA[zoneTexture] = {}
			end
			for tname, num in pairs(overlayData) do
				if Cartographer3_Data.OVERLAY_DATA[zoneTexture][tname] == num then
					overlayData[tname] = nil -- it's been upgraded in the main addon
				else
					Cartographer3_Data.OVERLAY_DATA[zoneTexture][tname] = num
				end
			end
			if not next(overlayData) then
				Cartographer3_NewOverlaysDB[zoneTexture] = nil
			end
		end
		if not next(Cartographer3_NewOverlaysDB) then
			_G.Cartographer3_NewOverlaysDB = nil
		end
	end
	
	initializeContinentData()
	createMapHolder()
	
	for name, module in pairs(modules) do
		if module.OnInitialize then
			module.OnInitialize()
			module.OnInitialize = nil
		end
	end
	
	for poi in pairs(shownPOIs) do
		poi:Resize()
	end
	
	local loading_name
	local function call()
		LoadAddOn(loading_name)
	end
	local function errorhandler(err)
		return geterrorhandler()("Cartographer3: error loading module " .. tostring(loading_name) .. ": " .. tostring(err))
	end
	
	for i = 1, GetNumAddOns() do
		local name, _, notes, enabled, loadable = GetAddOnInfo(i)
		if name:match("^Cartographer3_") and IsAddOnLoadOnDemand(i) and enabled and loadable and not IsAddOnLoaded(i) then
			local short_name = name:match("^Cartographer3_(.*)")
			Cartographer3.potentialModules[short_name] = { GetAddOnMetadata(name, "X-Name") or name, GetAddOnMetadata(name, "Notes") }
			local disabled = db[short_name] and db[short_name].disabled
			if not disabled then
				loading_name = name
				xpcall(call, errorhandler)
			end
		end
	end
end
Cartographer3_Utils.AddEventListener("ADDON_LOADED", ADDON_LOADED)

local function UPDATE_PENDING_MAIL(event)
	Cartographer3_Utils.RemoveEventListener("UPDATE_PENDING_MAIL", UPDATE_PENDING_MAIL)
	UPDATE_PENDING_MAIL = nil
	local timeToRun = GetTime() + 1
	local function func(elapsed, currentTime)
		if currentTime < timeToRun then
			return
		end
		Cartographer3_Utils.RemoveTimer(func)
		func = nil
		Cartographer3_Utils.ZoomToCurrentZone()
		
		Cartographer3.Utils.SpamVersion("GUILD", nil, true)
		Cartographer3.Utils.SpamVersion("GROUP", nil, true)
	end
	Cartographer3_Utils.AddTimer(func)
end
Cartographer3_Utils.AddEventListener("UPDATE_PENDING_MAIL", UPDATE_PENDING_MAIL)

-- Version checking

local function getGroupChannel()
	local instance, kind = IsInInstance()
	if instance and kind == "pvp" then
		return "BATTLEGROUND"
	elseif GetNumRaidMembers() > 0 then
		return "RAID"
	elseif GetNumPartyMembers() > 0 then
		return "PARTY"
	else
		return nil
	end
end

local latestVersion = Cartographer3.versionType == "Development" and "Development" or nil

local function versionIsLessThan(alpha, bravo)
	local alpha_num = alpha:match("^(%d+)")
	local bravo_num = bravo:match("^(%d+)")
	if not bravo_num then
		return false
	end
	if not alpha_num then
		alpha_num = '0'
		alpha = ''
	end
	if alpha_num+0 < bravo_num+0 then
		return true
	elseif alpha_num+0 > bravo_num+0 then
		return false
	end
	return versionIsLessThan(alpha:sub(#alpha_num+2), bravo:sub(#bravo_num+2))
end

local commands = {}
function commands.VER(message, channel, sender)
	-- Version response
	
	local version = message:sub(4)
	local kind
	if version:match("Development") then
		kind = "Development"
	elseif version:match("Alpha") then
		kind = "Alpha"
	elseif version:match("Beta") then
		kind = "Beta"
	else
		kind = "Release"
	end
	
	if not latestVersion and kind == "Release" and version ~= Cartographer3.version and versionIsLessThan(Cartographer3.version, version) then
		latestVersion = version
		
		DEFAULT_CHAT_FRAME:AddMessage(("A new version of |cffffff7fCartographer3|r has been detected. You have |cffffff7f%s|r, %s has |cff7fff7f%s|r. You can upgrade at http://www.curse.com/downloads/details/12701/"):format(tostring(Cartographer3.version), tostring(sender), tostring(version)))
	end
end

function commands.RVE(message, channel, sender)
	-- Version request
	commands.VER(message, channel, sender)
	Cartographer3.Utils.SpamVersion(channel, sender)
end

Cartographer3.Utils.AddEventListener("CHAT_MSG_ADDON", function(event, prefix, message, channel, sender)
	if prefix ~= "CT3" then
		return
	end
	if channel == "PARTY" or channel == "BATTLEGROUND" or channel == "RAID" then
		channel = "GROUP"
	end
	local command = message:sub(1, 3)
	local func = commands[command]
	if func then
		func(message, channel, sender)
	end
end)

local hasParty = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
Cartographer3.Utils.AddEventListener("PARTY_MEMBERS_CHANGED", function(event)
	local old_hasParty = hasParty
	hasParty = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
	if hasParty and not old_hasParty then
		Cartographer3.Utils.SpamVersion("GROUP", nil, true)
	end
end)

function Cartographer3.EnableModule(name)
	if not Cartographer3.db[name] then
		Cartographer3.db[name] = {}
	end
	if not Cartographer3.db[name].disabled then
		return
	end
	Cartographer3.db[name].disabled = nil
	
	if Cartographer3.modules[name] then
		if Cartographer3.modules[name].Enable then
			Cartographer3.modules[name].Enable()
		end
	else
		LoadAddOn("Cartographer3_" .. name)
		Cartographer3_Utils.CollectGarbageSoon()
	end
end

function Cartographer3.DisableModule(name)
	if not Cartographer3.db[name] then
		Cartographer3.db[name] = {}
	end
	if Cartographer3.db[name].disabled then
		return
	end
	Cartographer3.db[name].disabled = true
	if Cartographer3.modules[name] and Cartographer3.modules[name].Disable then
		Cartographer3.modules[name].Disable()
	end
end