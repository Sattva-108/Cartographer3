local _G = _G
local Cartographer3 = {}
_G.Cartographer3 = Cartographer3

Cartographer3.Utils = {}
local Cartographer3_Data = {}
Cartographer3.Data = Cartographer3_Data
local Cartographer3_Data_mapHolder
local Cartographer3_Data_scrollFrame
local Cartographer3_Data_mapView
local Cartographer3_Data_ZONE_DATA
local Cartographer3_Data_CONTINENT_DATA
local L = Cartographer3_L("Main")

local math_pi_div_2 = math.pi/2
local math_pi_times_2 = math.pi*2

function Cartographer3.Utils.GetPlayerRotation()
	return (-PlayerArrowEffectFrame:GetFacing() - math_pi_div_2) % math_pi_times_2
end

function Cartographer3.Utils.IsMouseHovering(frame)
	if not frame or not frame:IsVisible() then
		return false
	end
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	x, y = x/scale, y/scale
	
	local left, bottom, width, height = frame:GetRect()
	
	return left and bottom and width and height and x >= left and y >= bottom and x <= left+width and y <= bottom+height
end

do
	local frame = CreateFrame("Frame", nil, UIParent)
	
	local timers = {}
	local timers_whenNotShownAlso = {}
	function Cartographer3.Utils.AddTimer(func, whenNotShownAlso)
		timers[func] = true
		if whenNotShownAlso then
			timers_whenNotShownAlso[func] = true
		end
	end

	function Cartographer3.Utils.RemoveTimer(func)
		timers[func] = nil
		timers_whenNotShownAlso[func] = nil
	end
	
	local tmp = {}
	local UpdateWorldMapArrowFrames = _G.UpdateWorldMapArrowFrames
	function Cartographer3.Utils.OnUpdate(this, elapsed)
		local currentTime = GetTime()
		local mapHolder_shown = Cartographer3_Data_mapHolder:IsShown()
		UpdateWorldMapArrowFrames()
		for func in pairs(timers) do
			tmp[func] = true
		end
		for func in pairs(tmp) do
			if timers[func] and (mapHolder_shown or timers_whenNotShownAlso[func]) then
				func(elapsed, currentTime)
			end
			tmp[func] = nil
		end
	end
	
	local events = {}
	function Cartographer3.Utils.AddEventListener(event, func)
		if not events[event] then
			frame:RegisterEvent(event)
			events[event] = {}
		end
		table.insert(events[event], func)
	end
	
	function Cartographer3.Utils.RemoveEventListener(event, func)
		local events_event = events[event]
		if events_event then
			for i = #events_event, 1, -1 do
				local v = events_event[i]
				if v == func then
					table.remove(events_event, i)
				end
			end
			if not events_event[1] then
				frame:UnregisterEvent(event)
				events[event] = nil
			end
		end
	end
	
	local tmps = {}
	function Cartographer3.Utils.OnEvent(this, event, ...)
		local events_event = events[event]
		local tmp = next(tmps) or {}
		tmps[tmp] = nil
		for i, func in ipairs(events_event) do
			tmp[i] = func
		end
		for i = 1, #tmp do
			local func = tmp[i]
			tmp[i] = nil
			func(event, ...)
		end
		tmps[tmp] = true
	end
	frame:SetScript("OnEvent", Cartographer3.Utils.OnEvent)
	local function f(event, name)
		if name ~= "Cartographer3" then
			return
		end
		Cartographer3.Utils.RemoveEventListener("ADDON_LOADED", f)
		f = nil
		frame:SetScript("OnUpdate", function()
			frame:SetScript("OnUpdate", Cartographer3.Utils.OnUpdate)
		end)
	end
	Cartographer3.Utils.AddEventListener("ADDON_LOADED", f)
end

function Cartographer3.Utils.ZoomToCurrentZone()
	SetMapToCurrentZone()
	Cartographer3.Utils.ZoomToZone(Cartographer3_Data.currentMapTexture)
end

function Cartographer3.Utils.ZoomToZone(texture)
	local data = Cartographer3_Data_CONTINENT_DATA[texture] or Cartographer3_Data_ZONE_DATA[texture] or Cartographer3_Data.instanceTextureFrames[texture] or Cartographer3_Data.battlegroundFrames[texture]
	if data and data.fullCenterX then
		if data.visibleLeft then
			Cartographer3.Utils.MoveMap(
				(data.visibleLeft + data.visibleRight) / 2,
				(data.visibleBottom + data.visibleTop) / 2,
				math.min(
					Cartographer3_Data_scrollFrame:GetWidth() / (data.visibleRight - data.visibleLeft),
					Cartographer3_Data_scrollFrame:GetHeight() / (data.visibleTop - data.visibleBottom)
				)
			)
		else
			Cartographer3.Utils.MoveMap(
				data.fullCenterX,
				data.fullCenterY,
				math.min(
					Cartographer3_Data_scrollFrame:GetWidth() / data.fullWidth,
					Cartographer3_Data_scrollFrame:GetHeight() / data.fullHeight
				)
			)
		end
	end
end

function Cartographer3.Utils.GetScaledCursorPosition()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	return x/scale, y/scale
end

local cos, sin = _G.cos, _G.sin
function Cartographer3.Utils.RotateCoordinate(angle, x, y)
	local A = cos(angle)
	local B = sin(angle)
	return x * A - y * B, x * B + y * A
end

function Cartographer3.Utils.RotateTexCoord(angle)
	local A = cos(angle)
	local B = sin(angle)
	local ULx, ULy = -0.5 * A - -0.5 * B, -0.5 * B + -0.5 * A
	local LLx, LLy = -0.5 * A - 0.5 * B, -0.5 * B + 0.5 * A
	local URx, URy = 0.5 * A - -0.5 * B, 0.5 * B + -0.5 * A
	local LRx, LRy = 0.5 * A - 0.5 * B, 0.5 * B + 0.5 * A
	return ULx+0.5, ULy+0.5, LLx+0.5, LLy+0.5, URx+0.5, URy+0.5, LRx+0.5, LRy+0.5
end

function Cartographer3.Utils.UnpackFloat(D, C, B, A)
	local negative = A >= 128 and -1 or 1
	local exponent = 2*(A%128) + math.floor(B/128) - 127
	local mantissa = 1 + (65536*(B%128) + 256*C + D) / 2^23
	return negative * 2^exponent * mantissa
end

do
	local function f()
		if InCombatLockdown() then
			return
		end
		Cartographer3.Utils.RemoveTimer(f)
		collectgarbage('collect')
	end
	function Cartographer3.Utils.CollectGarbageSoon()
		Cartographer3.Utils.AddTimer(f, true)
	end
end

function Cartographer3.Utils.ConvertUniverseCoordinateToZoneCoordinate(x, y)
	for texture, instanceTextureFrame in pairs(Cartographer3_Data.instanceTextureFrames) do
		if instanceTextureFrame.fullCenterX and Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[texture] then
			local frame_center = instanceTextureFrame.fullCenterX
			local frame_middle = instanceTextureFrame.fullCenterY
			local frame_width = instanceTextureFrame.fullWidth
			local frame_height = instanceTextureFrame.fullHeight

			local x_coord = (x - frame_center) / frame_width + 0.5
			local y_coord = 0.5 - (y - frame_middle) / frame_height
			if x_coord >= 0 and x_coord <= 1 and y_coord >= 0 and y_coord <= 1 then
				return texture, x_coord, y_coord
			end
		end
	end
	
	for continentID, currentContinentData in ipairs(Cartographer3_Data_CONTINENT_DATA) do
		local continentLeft = currentContinentData.visibleLeft
		local continentRight = currentContinentData.visibleRight
		local continentBottom = currentContinentData.visibleBottom
		local continentTop = currentContinentData.visibleTop
		if x >= continentLeft and x <= continentRight and y >= continentBottom and y <= continentTop then
			local x_grid = math.floor((x - continentLeft) / (continentRight - continentLeft) * 10)
			local y_grid = math.floor((y - continentBottom) / (continentTop - continentBottom) * 10)
			local num = x_grid*10 + y_grid
			local searchData = Cartographer3_Data.zoneSearchData[continentID][num]
			local bestZone
			if searchData then
				for _, zoneTexture in ipairs(searchData) do
					local zoneData = Cartographer3_Data_ZONE_DATA[zoneTexture]
			
					if x >= zoneData.highlightLeft and x <= zoneData.highlightRight and y >= zoneData.highlightBottom and y <= zoneData.highlightTop then
						bestZone = zoneTexture
						break
					end
				end
			end
		
			if bestZone then
				local zoneData = currentContinentData.zones[bestZone]
				return bestZone,
					(x - zoneData.fullCenterX) / zoneData.fullWidth + 0.5,
					0.5 - (y - zoneData.fullCenterY) / zoneData.fullHeight
			else
				return currentContinentData.texture,
					(x - currentContinentData.fullCenterX) / currentContinentData.fullWidth + 0.5,
					0.5 - (y - currentContinentData.fullCenterY) / currentContinentData.fullHeight
			end
		end
	end
	
	local instanceLeft = Cartographer3_Data.instanceLeft
	local instanceRight = Cartographer3_Data.instanceRight
	local instanceBottom = Cartographer3_Data.instanceBottom
	local instanceTop = Cartographer3_Data.instanceTop
	
	if x > instanceLeft and x < instanceRight and y > instanceBottom and y < instanceTop then
		local instanceRows = Cartographer3_Data.instanceRows
		local instance_column = math.floor((x - instanceLeft) / (instanceRight - instanceLeft) * instanceRows)
		local instance_row = math.floor((y - instanceTop) / (instanceBottom - instanceTop) * instanceRows)
		local instance_id = instance_column + instance_row * instanceRows + 1
		local instanceTextureFrame = Cartographer3_Data.instanceTextureFrames[instance_id]
		if instanceTextureFrame then
			local frame_center = instanceTextureFrame.fullCenterX
			local frame_middle = instanceTextureFrame.fullCenterY
			local frame_width = instanceTextureFrame.fullWidth
			local frame_height = instanceTextureFrame.fullHeight
			
			local x_coord = (x - frame_center) / frame_width + 0.5
			local y_coord = (y - frame_middle) / frame_height + 0.5
			if x_coord >= 0 and x_coord <= 1 and y_coord >= 0 and y_coord <= 1 then
				return instanceTextureFrame.name, x_coord, y_coord
			end
		end
	end
	
	for texture, battlegroundFrame in pairs(Cartographer3_Data.battlegroundFrames) do
		local frame_center = battlegroundFrame.fullCenterX
		local frame_middle = battlegroundFrame.fullCenterY
		local frame_width = battlegroundFrame.fullWidth
		local frame_height = battlegroundFrame.fullHeight
	
		local x_coord = (x - frame_center) / frame_width + 0.5
		local y_coord = 0.5 - (y - frame_middle) / frame_height
		if x_coord >= 0 and x_coord <= 1 and y_coord >= 0 and y_coord <= 1 then
			return texture, x_coord, y_coord
		end
	end
	
	return nil, nil, nil
end

function Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(zone, x, y)
	if (x == 0 and y == 0) or not x then
		return nil, nil
	end
	local data = Cartographer3_Data_ZONE_DATA[zone] or Cartographer3_Data.instanceTextureFrames[zone] or Cartographer3_Data.battlegroundFrames[zone]
	if data and data.fullCenterX then
		y = 1 - y
		x = (x - 1/2) * data.fullWidth + data.fullCenterX
		y = (y - 1/2) * data.fullHeight + data.fullCenterY
		return x, y
	end
	data = Cartographer3_Data_CONTINENT_DATA[zone]
	if data then
		y = 1 - y
		x = (x - 1/2) * data.fullWidth + data.fullCenterX
		y = (y - 1/2) * data.fullHeight + data.fullCenterY
		
		local zone_z, zone_x, zone_y = Cartographer3.Utils.ConvertUniverseCoordinateToZoneCoordinate(x, y)
		local zoneData = Cartographer3_Data_ZONE_DATA[zone_z]
		if zoneData then
			-- This is done because Quel'Thalas' position is further northeast than it actually is.
			return x + zoneData.continentOffsetX, y + zoneData.continentOffsetY
		end
		
		return x, y
	end
	
	return nil, nil
end

function Cartographer3.Utils.GetCursorUniverseCoordinate()
	local cursorX, cursorY = GetCursorPosition()
	local mapScale = Cartographer3_Data_mapView:GetEffectiveScale()
	cursorX, cursorY = cursorX/mapScale, cursorY/mapScale
	local mapX, mapY, mapW, mapH = Cartographer3_Data_mapView:GetRect()
	
	cursorX, cursorY = cursorX - mapX - mapW/2, cursorY - mapY - mapH/2
	return cursorX, cursorY
end

do
	local cx, cy
	local function _getCursorZonePosition(cx, cy)
		local zoneData = Cartographer3_Data.currentZoneData
		if zoneData then
			local centerX = zoneData.fullCenterX
			local centerY = zoneData.fullCenterY
			local width = zoneData.fullWidth
			local height = zoneData.fullHeight
			local left = centerX - width/2
			local bottom = centerY - height/2
			if cx >= left and cy >= bottom and cx <= left+width and cy <= bottom+height then
				for texture, instanceTextureFrame in pairs(Cartographer3_Data.instanceTextureFrames) do
					if instanceTextureFrame.fullCenterX and Cartographer3_Data.INSTANCE_LOCATION_OVERRIDES[texture] then
						local frame_center = instanceTextureFrame.fullCenterX
						local frame_middle = instanceTextureFrame.fullCenterY
						local frame_width = instanceTextureFrame.fullWidth
						local frame_height = instanceTextureFrame.fullHeight

						local x_coord = (cx - frame_center) / frame_width + 0.5
						local y_coord = 0.5 - (cy - frame_middle) / frame_height
						if x_coord >= 0 and x_coord <= 1 and y_coord >= 0 and y_coord <= 1 then
							return texture, x_coord, y_coord
						end
					end
				end
				
				local zx, zy = (cx - left) / width, 1 - (cy - bottom) / height
				if not Cartographer3_Data.CITIES[Cartographer3_Data.currentMapTextureWithoutLevel] then
					local name = UpdateMapHighlight(zx, zy)
					local fileName = Cartographer3_Data.LOCALIZED_ZONE_TO_TEXTURE[name]
					if fileName then
						zoneData = Cartographer3_Data_ZONE_DATA[fileName]
						if zoneData then
							centerX = zoneData.fullCenterX
							centerY = zoneData.fullCenterY
							width = zoneData.fullWidth
							height = zoneData.fullHeight
							left = centerX - width/2
							bottom = centerY - height/2
							if cx >= left and cy >= bottom and cx <= left+width and cy <= bottom+height then
								local zx, zy = (cx - left) / width, 1 - (cy - bottom) / height
								return fileName, zx, zy
							end
						end
					end
				end
				return Cartographer3_Data.currentMapTexture, zx, zy
			end
		end
		return Cartographer3.Utils.ConvertUniverseCoordinateToZoneCoordinate(cx, cy)
	end
	local ret_zz, ret_zx, ret_zy
	function Cartographer3.Utils.GetCursorZonePosition()
		local cx, cy = Cartographer3.Utils.GetCursorUniverseCoordinate()
		if last_cx == cx and last_cy == cy then
			return ret_zz, ret_zx, ret_zy
		end
		ret_zz, ret_zx, ret_zy = _getCursorZonePosition(cx, cy)
		return ret_zz, ret_zx, ret_zy
	end
end

local lastPlayerX, lastPlayerY
local function f()
	Cartographer3.Utils.RemoveTimer(f)
	f = nil
	local function g()
		local x, y = GetPlayerMapPosition("player")
		if x ~= 0 and y ~= 0 then
			lastPlayerX, lastPlayerY = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(Cartographer3_Data.currentMapTexture, x, y)
		end
	end
	Cartographer3.Utils.AddTimer(g, true)
	SetMapToCurrentZone()
	g()
	g = nil
end
Cartographer3.Utils.AddTimer(f, true)
function Cartographer3.Utils.GetUnitUniverseCoordinate(unit)
	local x, y = GetPlayerMapPosition(unit)
	if x == 0 and y == 0 then
		if unit == "player" and not IsInInstance() then
			return lastPlayerX, lastPlayerY
		end
		return nil, nil
	end
	return Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(Cartographer3_Data.currentMapTexture, x, y)
end

function Cartographer3.Utils.AddUnitDataToFullTooltip(unit)
	local title
	if unit == "player" then
		title = L["Player:"]
	elseif unit:match("^party") then
		title = L["Party:"]
	elseif unit:match("^raid") then
		title = L["Raid:"]
	end
	local name, realm = UnitName(unit)
	if realm and realm ~= "" then
		name = name .. "-" .. realm
	end
	GameTooltip:AddDoubleLine(title, name)
	
	local className, classEnglish = UnitClass(unit)
	local classColor = RAID_CLASS_COLORS[classEnglish]
	GameTooltip:AddDoubleLine(L["Class:"], className, nil, nil, nil, classColor.r, classColor.g, classColor.b)
	
	local level = UnitLevel(unit)
	local levelColor = GetQuestDifficultyColor(level)
	GameTooltip:AddDoubleLine(L["Level:"], level, nil, nil, nil, levelColor.r, levelColor.g, levelColor.b)
	
	GameTooltip:AddDoubleLine(L["Race:"], UnitRace(unit))
	
	if unit:match("^raid") then
		id = unit:sub(5)+0
		local _, _, subgroup = GetRaidRosterInfo(id)
		if subgroup then
			GameTooltip:AddDoubleLine(L["Group:"], subgroup)
		end
	end
	
	local guildName, guildRank, guildRankNum = GetGuildInfo(unit)
	if not guildName then
		local LibGuild = LibStub and LibStub("LibGuild-1.0", true)
		if LibGuild and LibGuild:HasMember(name) then
			guildName = LibGuild:GetGuildName()
			guildRank = LibGuild:GetRank(name)
			guildRankNum = LibGuild:GetRankIndex(name)
		end
	end
	if guildName then
		local playerGuildName, playerGuildRank, playerGuildRankNum = GetGuildInfo('player')
		local r, g, b = 1, 1, 0
		if playerGuildName == guildName then
			r, g, b = 0, 1, 0
		end
		
		GameTooltip:AddDoubleLine(L["Guild:"], ("<%s>"):format(guildName), nil, nil, nil, r, g, b)
		
		if playerGuildName == guildName then
			local rankDiff = guildRankNum - playerGuildRankNum
			if rankDiff >= 2 then
				r, g, b = 0, 1, 0
			elseif rankDiff == 1 then
				r, g, b = 0.5, 1, 0
			elseif rankDiff == 0 then
				r, g, b = 1, 1, 0
			elseif rankDiff == -1 then
				r, g, b = 1, 0.5, 0
			else
				r, g, b = 1, 0, 0
			end
		end
		GameTooltip:AddDoubleLine(L["Rank:"], guildRank, nil, nil, nil, r, g, b)
		
		if playerGuildName == guildName then
			local LibGuild = LibStub and LibStub("LibGuild-1.0", true)
			if LibGuild then
				local note, officerNote = LibGuild:GetNote(name), LibGuild:GetOfficerNote(name)

				if note then
					GameTooltip:AddDoubleLine(L["Note:"], note)
				end

				if officerNote then
					GameTooltip:AddDoubleLine(L["Officer's Note:"], officerNote)
				end
			end
		end
	end
	
	if UnitIsDeadOrGhost(unit) then
		GameTooltip:AddDoubleLine(L["Health:"], UnitIsGhost(unit) and L["Ghost"] or L["Dead"], nil, nil, nil, 0.5, 0.5, 0.5)
	else
		local health, max = UnitHealth(unit), UnitHealthMax(unit)
		local hp = health / max
		local r, g, b
		if hp < 0.5 then
			r, g, b = 1, hp * 2, 0
		else
			r, g, b = (1 - hp) * 2, 1, 0
		end
		
		GameTooltip:AddDoubleLine(L["Health:"], ("%.1f%%"):format(hp * 100), nil, nil, nil, r, g, b)
	end
end

do
	local tmp = {}
	function Cartographer3.Utils.AddUnitDataToTooltipLine(unit)
		local name, realm = UnitName(unit)
		local _, class = UnitClass(unit)
		local classColor = RAID_CLASS_COLORS[class]
		tmp[#tmp+1] = "|cff"
		tmp[#tmp+1] = ("%02x"):format(classColor.r*255)
		tmp[#tmp+1] = ("%02x"):format(classColor.g*255)
		tmp[#tmp+1] = ("%02x"):format(classColor.b*255)
		tmp[#tmp+1] = name
		tmp[#tmp+1] = "|r"
		if realm and realm ~= "" then
			tmp[#tmp+1] = "-"
			tmp[#tmp+1] = realm
		end
	
		tmp[#tmp+1] = " "
	
		local level = UnitLevel(unit)
		local levelColor = GetQuestDifficultyColor(level)
	
		tmp[#tmp+1] = "|cff"
		tmp[#tmp+1] = ("%02x"):format(levelColor.r*255)
		tmp[#tmp+1] = ("%02x"):format(levelColor.g*255)
		tmp[#tmp+1] = ("%02x"):format(levelColor.b*255)
		tmp[#tmp+1] = level
		tmp[#tmp+1] = "|r"
		
		if unit:match("^raid") then
			id = unit:sub(5)+0
			local _, _, subgroup = GetRaidRosterInfo(id)
			if subgroup then
				tmp[#tmp+1] = " "
				tmp[#tmp+1] = L["Group_acronym"]
				tmp[#tmp+1] = subgroup
			end
		end
		
		tmp[#tmp+1] = " "
		
		if UnitIsDeadOrGhost(unit) then
			tmp[#tmp+1] = "|cff7f7f7f"
			if UnitIsGhost(unit) then
				tmp[#tmp+1] = L["Ghost"]
			else
				tmp[#tmp+1] = L["Dead"]
			end
			tmp[#tmp+1] = "|r"
		else
			local health, max = UnitHealth(unit), UnitHealthMax(unit)
			local hp = health / max
			tmp[#tmp+1] = "|cff"
			if hp < 0.5 then
				tmp[#tmp+1] = "ff"
				tmp[#tmp+1] = ("%02x"):format(hp * 2 * 255)
			else
				tmp[#tmp+1] = ("%02x"):format((1 - hp) * 2 * 255)
				tmp[#tmp+1] = "ff"
			end
			tmp[#tmp+1] = "00"
		
			tmp[#tmp+1] = math.floor(hp * 1000 + 0.5) / 10
			tmp[#tmp+1] = "%|r"
		end
		
		if UnitAffectingCombat(unit) then
			tmp[#tmp+1] = " "
			tmp[#tmp+1] = "|cffff0000"
			tmp[#tmp+1] = L["In combat"]
			tmp[#tmp+1] = "|r"
		end
	
		local s = table.concat(tmp)
		for i = 1, #tmp do
			tmp[i] = nil
		end
		GameTooltip:AddLine(s)
	end
end

do
	local startGradualCameraX, startGradualCameraY, startGradualCameraZoom
	local gradual_isManual
	local gradual_message
	function Cartographer3.Utils.GetMoveMapMessage()
		return gradual_message
	end
	function Cartographer3.Utils.MoveMap(x, y, zoom, isManual, message)
		if x or y then
			if not x or not y then
				x = x or Cartographer3_Data.cameraX
				y = y or Cartographer3_Data.cameraY
			end
		elseif zoom then
			x = Cartographer3_Data.gradualCameraX
			y = Cartographer3_Data.gradualCameraY
		end
		if Cartographer3_Data.sliderFrame and zoom then
			Cartographer3_Data.sliderFrame.slider:set(math.log(zoom))
		end
		startGradualCameraX = Cartographer3_Data.cameraX
		startGradualCameraY = Cartographer3_Data.cameraY
		startGradualCameraZoom = Cartographer3_Data.cameraZoom
		Cartographer3_Data.gradualCameraX = x
		Cartographer3_Data.gradualCameraY = y
		Cartographer3_Data.gradualCameraZoom = zoom
		gradual_isManual = isManual
		gradual_message = message
		if not isManual then
			if zoom then
				local zoom_diff = math.abs(Cartographer3_Data.cameraZoom/Cartographer3_Data.gradualCameraZoom - 1)
				if zoom_diff < 0.01 then
					Cartographer3_Data.cameraZoom = zoom
					Cartographer3_Data.gradualCameraZoom = nil
				elseif zoom_diff < 0.2 then
					if zoom < Cartographer3_Data.gradualCameraZoom then
						startGradualCameraZoom = zoom * 1.2
					else
						startGradualCameraZoom = zoom / 1.2
					end
				end
			end
			if x then
				local x_diff = Cartographer3_Data.cameraX - x
				local y_diff = Cartographer3_Data.cameraY - y
				local x_y_diff = (x_diff^2 + y_diff^2)^0.5
				if x_y_diff < 1e-5 then
					Cartographer3_Data.cameraX = x
					Cartographer3_Data.gradualCameraX = nil
					Cartographer3_Data.cameraY = y
					Cartographer3_Data.gradualCameraY = nil
				elseif x_y_diff < 1 then
					local angle = math.atan2(y_diff, x_diff)
					startGradualCameraX = x + math.cos(angle)
					startGradualCameraY = y + math.sin(angle)
				end
			end
		end
	end

	local function graduallyMove(elapsed, currentTime)
		if not Cartographer3_Data.gradualCameraZoom and not Cartographer3_Data.gradualCameraX and not Cartographer3_Data.gradualCameraY then
			return
		end
	
		local zoomTime = gradual_isManual and Cartographer3_Data.MANUAL_ZOOM_TIME or Cartographer3_Data.ZOOM_TIME
	
		local previousCameraZoom = Cartographer3_Data.cameraZoom
		if Cartographer3_Data.gradualCameraZoom then
			Cartographer3_Data.cameraZoom = Cartographer3_Data.cameraZoom * (Cartographer3_Data.gradualCameraZoom / startGradualCameraZoom) ^ (elapsed / zoomTime)
		
			if (Cartographer3_Data.gradualCameraZoom < Cartographer3_Data.cameraZoom) == (Cartographer3_Data.gradualCameraZoom > startGradualCameraZoom) then
				Cartographer3_Data.cameraZoom = Cartographer3_Data.gradualCameraZoom
			end
		end
	
		if Cartographer3_Data.gradualCameraX then
			if Cartographer3_Data.gradualCameraZoom then
				local initialCursorX = (startGradualCameraZoom * startGradualCameraX - Cartographer3_Data.gradualCameraZoom * Cartographer3_Data.gradualCameraX) / (startGradualCameraZoom - Cartographer3_Data.gradualCameraZoom)
				Cartographer3_Data.cameraX = (Cartographer3_Data.cameraX - initialCursorX) * previousCameraZoom / Cartographer3_Data.cameraZoom + initialCursorX
			else
				Cartographer3_Data.cameraX = Cartographer3_Data.cameraX + (Cartographer3_Data.gradualCameraX - startGradualCameraX) * (elapsed / zoomTime)
			end
		
			if (Cartographer3_Data.gradualCameraX < Cartographer3_Data.cameraX) == (Cartographer3_Data.gradualCameraX > startGradualCameraX) then
				Cartographer3_Data.cameraX = Cartographer3_Data.gradualCameraX
				Cartographer3_Data.gradualCameraX = nil
			end
		end
	
		if Cartographer3_Data.gradualCameraY then
			if Cartographer3_Data.gradualCameraZoom then
				local initialCursorY = (startGradualCameraZoom * startGradualCameraY - Cartographer3_Data.gradualCameraZoom * Cartographer3_Data.gradualCameraY) / (startGradualCameraZoom - Cartographer3_Data.gradualCameraZoom)
				Cartographer3_Data.cameraY = (Cartographer3_Data.cameraY - initialCursorY) * previousCameraZoom / Cartographer3_Data.cameraZoom + initialCursorY
			else
				Cartographer3_Data.cameraY = Cartographer3_Data.cameraY + (Cartographer3_Data.gradualCameraY - startGradualCameraY) * (elapsed / zoomTime)
			end
		
			if (Cartographer3_Data.gradualCameraY < Cartographer3_Data.cameraY) == (Cartographer3_Data.gradualCameraY > startGradualCameraY) then
				Cartographer3_Data.cameraY = Cartographer3_Data.gradualCameraY
				Cartographer3_Data.gradualCameraY = nil
			end
		end
	
		if Cartographer3_Data.gradualCameraZoom == Cartographer3_Data.cameraZoom then
			Cartographer3_Data.gradualCameraZoom = nil
		end
	
		Cartographer3.Utils.ReadjustCamera()
	end
	Cartographer3.Utils.AddTimer(graduallyMove)
end

function Cartographer3.Utils.ZoomToPlayer()
	if Cartographer3.Utils.GetMoveMapMessage() == 'player' and not Cartographer3_Data.gradualCameraX and not Cartographer3_Data.gradualCameraY then
		local playerX, playerY = Cartographer3.Utils.GetUnitUniverseCoordinate("player")
		if not playerX then
			return Cartographer3.Utils.ZoomToCurrentZone()
		end
		Cartographer3_Data.cameraX, Cartographer3_Data.cameraY = playerX, playerY
		Cartographer3.Utils.ReadjustCamera()
		return
	end
	SetMapToCurrentZone()
	local playerX, playerY = Cartographer3.Utils.GetUnitUniverseCoordinate("player")
	if not playerX then
		return Cartographer3.Utils.ZoomToCurrentZone()
	end
	Cartographer3.Utils.MoveMap(playerX, playerY, Cartographer3_Data.gradualCameraZoom, nil, 'player')
end

function Cartographer3.Utils.ZoomToBestPlayerView()
	SetMapToCurrentZone()
	if Cartographer3.db.followPlayer then
		Cartographer3.Utils.ZoomToPlayer()
	else
		local x, y = Cartographer3_Data.cameraX, Cartographer3_Data.cameraY
		local z = Cartographer3.Utils.ConvertUniverseCoordinateToZoneCoordinate(Cartographer3_Data.cameraX, Cartographer3_Data.cameraY)
		if z ~= Cartographer3_Data.currentMapTexture then
			local zoneData = Cartographer3_Data.ZONE_DATA[Cartographer3_Data.currentMapTexture]
			if not zoneData or x < (zoneData.fullCenterX - zoneData.fullWidth/2) or x > (zoneData.fullCenterX + zoneData.fullWidth/2) or y < (zoneData.fullCenterY - zoneData.fullHeight/2) or y > (zoneData.fullCenterY + zoneData.fullHeight/2) then
				Cartographer3.Utils.ZoomToZone(Cartographer3_Data.currentMapTexture)
			end
		end
	end
end

function Cartographer3.Utils.ReadjustCamera()
	local previousScale = Cartographer3_Data_mapView:GetScale()
	if previousScale ~= Cartographer3_Data.cameraZoom then
		if Cartographer3_Data.cameraZoom < Cartographer3_Data.MINIMUM_ZOOM then
			Cartographer3_Data.cameraZoom = Cartographer3_Data.MINIMUM_ZOOM
		elseif Cartographer3_Data.cameraZoom > Cartographer3_Data.MAXIMUM_ZOOM then
			Cartographer3_Data.cameraZoom = Cartographer3_Data.MAXIMUM_ZOOM
		end
		Cartographer3_Data_mapView:SetScale(Cartographer3_Data.cameraZoom)
		
		for poi, scale in pairs(Cartographer3_Data.shownPOIs) do
			poi:Resize()
		end
	end
	Cartographer3_Data_scrollFrame:SetHorizontalScroll(-(Cartographer3_Data_mapView:GetWidth() - Cartographer3_Data_scrollFrame:GetWidth()/Cartographer3_Data.cameraZoom) / 2 - Cartographer3_Data.cameraX)
	Cartographer3_Data_scrollFrame:SetVerticalScroll((Cartographer3_Data_mapView:GetHeight() - Cartographer3_Data_scrollFrame:GetHeight()/Cartographer3_Data.cameraZoom) / 2 - Cartographer3_Data.cameraY)
end

function Cartographer3.Utils.ConvertCIDAndZIDToMapTexture(continentID, zoneID)
	return Cartographer3_Data.zoneID_mapping[continentID * 1000 + zoneID]
end

do
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
	
	local spamTime = {}
	function Cartographer3.Utils.SpamVersion(channel, target, withRequest)
		if channel == "PARTY" or channel == "RAID" or channel == "BATTLEGROUND" then
			channel = "GROUP"
		end
		local now = GetTime()
		if channel == "WHISPER" then
			if spamTime[target] and spamTime[target] > now then
				return
			end
			spamTime[target] = now + 300
		else
			if spamTime[channel] and spamTime[channel] > now then
				return
			end
			spamTime[channel] = now + 300
			target = nil
			if channel == "GROUP" then
				channel = getGroupChannel()
				if not channel then
					spamTime["GROUP"] = nil
					return
				end
			elseif channel == "GUILD" then
				if not IsInGuild() then
					spamTime["GUILD"] = nil
					return
				end
			else
				return
			end
		end
		SendAddonMessage("CT3", (withRequest and "RVE" or "VER") .. Cartographer3.version, channel, target)
	end
end


local function ADDON_LOADED(event, name)
	if name ~= "Cartographer3" then
		return
	end
	Cartographer3.Utils.RemoveEventListener("ADDON_LOADED", ADDON_LOADED)
	ADDON_LOADED = nil
	
	Cartographer3_Data_mapHolder = Cartographer3_Data.mapHolder
	Cartographer3_Data_scrollFrame = Cartographer3_Data.scrollFrame
	Cartographer3_Data_mapView = Cartographer3_Data.mapView
	Cartographer3_Data_ZONE_DATA = Cartographer3_Data.ZONE_DATA
	Cartographer3_Data_CONTINENT_DATA = Cartographer3_Data.CONTINENT_DATA
end
Cartographer3.Utils.AddEventListener("ADDON_LOADED", ADDON_LOADED)
