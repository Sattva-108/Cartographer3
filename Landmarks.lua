local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

Cartographer3.AddPOIType("Landmark", L["Landmark"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local texture = poi:CreateTexture(nil, "BORDER")
	texture:SetAllPoints(poi)
	texture:SetTexture([=[Interface\Minimap\POIIcons]=])
	texture:SetTexCoord(
		(5 % 16) / 16,
		((5 % 16) + 1) / 16,
		math.floor(5 / 16) / 16,
		(math.floor(5 / 16) + 1) / 16)
	return poi
end)

local battlegroundHalfways = {
	{ -- Horde
		[11] = 242.5, -- tower
		[13] = 242.5, -- graveyard
		[19] = 62.5, -- mine
		[24] = 62.5, -- lumber mill
		[29] = 62.5, -- blacksmith
		[34] = 62.5, -- farm
		[39] = 62.5, -- stables
	},
	{ -- Alliance
		[3] = 242.5, -- graveyard
		[8] = 242.5, -- tower
		[17] = 62.5, -- mine
		[22] = 62.5, -- lumber mill
		[27] = 62.5, -- blacksmith
		[32] = 62.5, -- farm
		[37] = 62.5, -- stables
	}
}
local battlegroundFulls = {
	{ -- Horde
		[1] = true, -- mine
		[9] = true, -- tower
		[12] = true, -- graveyard
		[20] = true, -- mine
		[25] = true, -- limber mill
		[30] = true, -- blacksmith
		[35] = true, -- farm
		[40] = true, -- stables
	},
	{ -- Alliance
		[2] = true, -- mine
		[10] = true, -- tower
		[14] = true, -- graveyard
		[18] = true, -- mine
		[23] = true, -- lumber mill
		[28] = true, -- blacksmith
		[33] = true, -- farm
		[38] = true, -- stables
	}
}

local timerData = {}
local timerDataIsHorde = {}

local pois = {}

local proportion = 0.75

local function poi_OnSizeChanged(self)
	self.timer:Update()
end

local function timer_Update(self)
	local poi = self.poi
	local size = poi:GetHeight()
	if self.percent == 0 then
		self:Hide()
		self.bg:Hide()
	else
		self:Show()
		self.bg:Show()
		self:SetPoint("TOPLEFT", poi, "CENTER", -size * proportion, size * proportion)
		self:SetPoint("BOTTOMRIGHT", poi, "CENTER", (-size + size*2*self.percent) * proportion, -size * proportion)
		self.bg:SetPoint("TOPLEFT", self, "TOPRIGHT")
		self.bg:SetPoint("BOTTOMRIGHT", poi, "CENTER", size * proportion, -size * proportion)
	end
end

local function poi_AddDataToFullTooltip(self)
	GameTooltip:SetText(self.name)
	if self.description then
		GameTooltip:AddLine(self.description, nil, nil, nil, true)
	end
	local secondsLeft = self.timer.secondsLeft
	if secondsLeft and secondsLeft > 0 then
		GameTooltip:AddLine(("%d:%02d"):format(secondsLeft / 60, secondsLeft % 60), nil, nil, nil, true)
	end
end

local function poi_AddDataToTooltipLine(self)
	local text = self.name
	if self.description then
		text = text .. " - " .. self.description
	end
	local secondsLeft = self.timer.secondsLeft
	if secondsLeft and secondsLeft > 0 then
		text = text .. " - " .. ("%d:%02d"):format(secondsLeft / 60, secondsLeft % 60)
	end
	GameTooltip:AddLine(text)
end

local function makePoi()
	local poi = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_Poi" .. (#pois + 1), Cartographer3_Data.mapView)
	pois[#pois+1] = poi
	poi:SetWidth(1)
	poi:SetHeight(1)
	Cartographer3.AddPOI(poi, "Landmark")
	poi.AddDataToFullTooltip = poi_AddDataToFullTooltip
	poi.AddDataToTooltipLine = poi_AddDataToTooltipLine

	local texture = poi:CreateTexture(nil--[[poi:GetName() .. "_Texture"]], "BORDER")
	poi.texture = texture
	texture:SetAllPoints(poi)
	texture:SetTexture([=[Interface\Minimap\POIIcons]=])
	
	local timer = poi:CreateTexture(nil--[[poi:GetName() .. "_Timer"]], "BACKGROUND")
	poi.timer = timer
	timer.poi = poi
	timer:SetTexture(1, 1, 1, 0.5)
	timer:SetWidth(0)
	timer.percent = 0
	timer.Update = timer_Update
	
	local timer_bg = poi:CreateTexture(nil--[[poi:GetName() .. "_TimerBackground"]], "BACKGROUND")
	timer.bg = timer_bg
	timer_bg:SetTexture(0, 0, 0, 0.5)
	
	timer:Hide()
	timer_bg:Hide()
	
	poi:SetScript("OnSizeChanged", poi_OnSizeChanged)
	
	return poi
end

local function updateTimers(elapsed, currentTime)
	for zone, timerData_zone in pairs(timerData) do
		for id, time in pairs(timerData_zone) do
			timerData_zone[id] = time + elapsed
		end
	end
	
	local zone = Cartographer3_Data.currentMapTexture
	local timerData_zone = timerData[zone]
	if not timerData_zone then
		return
	end
	for i, poi in ipairs(pois) do
		local timerMax = poi.timerMax
		if timerMax then
			local time = timerData_zone[poi.id]
			if time then
				if time > timerMax then
					time = timerMax
				end
				poi.timer.percent = time / timerMax
				poi.timer.secondsLeft = timerMax - time
			end
		end
		poi.timer:Update()
	end
end

local tmp = {}
local function f()
	Cartographer3.Utils.RemoveTimer(f)
	
	local numPois = GetNumMapLandmarks()
	
	local zone = Cartographer3_Data.currentMapTexture
	if not zone then
		Cartographer3.Utils.AddTimer(f)
		return
	end
	for i = 1, numPois do
		local poi = pois[i] or makePoi()
		
		local halfwayTime = nil
		local isFull = false
		local isHorde = false
		
		local name, description, textureIndex, x, y = GetMapLandmarkInfo(i)
		
		local id = math.floor(x * 10000 + 0.5) + math.floor(y * 100 + 0.5)
		tmp[id] = true
		
		if textureIndex ~= 15 then
			poi.texture:SetTexCoord(
				(textureIndex % 16) / 16,
				((textureIndex % 16) + 1) / 16,
				math.floor(textureIndex / 16) / 16,
				(math.floor(textureIndex / 16) + 1) / 16)
		
			local poiX, poiY = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(zone, x, y)
			poi:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", poiX, poiY)
			poi.name = name
			poi.textureIndex = textureIndex
			poi.description = description
			poi.id = id
			poi:Show()
			local inInstance, kind = IsInInstance()
			if inInstance and kind == "pvp" then
				if battlegroundHalfways[1][textureIndex] then
					halfwayTime = battlegroundHalfways[1][textureIndex]
					poi.timer:SetTexture(1, 0, 0, 0.5)
					isHorde = true
				elseif battlegroundHalfways[2][textureIndex] then
					halfwayTime = battlegroundHalfways[2][textureIndex]
					poi.timer:SetTexture(0, 0, 1, 0.5)
				elseif battlegroundFulls[1][textureIndex] then
					poi.timer:SetTexture(1, 0, 0, 0.5)
					isFull = true
					isHorde = true
				elseif battlegroundFulls[2][textureIndex] then
					poi.timer:SetTexture(0, 0, 1, 0.5)
					isFull = true
				end
			end
		else
			poi:Hide()
		end	
		poi.timer.percent = 0
		poi.timer.secondsLeft = nil
		if halfwayTime then
			poi.timerMax = halfwayTime
			if not timerData[zone] then
				timerData[zone] = {}
			end
			if not timerDataIsHorde[zone] then
				timerDataIsHorde[zone] = {}
			end
			if not timerData[zone][id] then
				timerData[zone][id] = 0
			elseif isHorde ~= timerDataIsHorde[zone][id] then
				timerData[zone][id] = 0
			end
			timerDataIsHorde[zone][id] = isHorde
		else
			poi.timerMax = nil
			if timerData[zone] then
				timerData[zone][id] = nil
			end
			if isFull then
				poi.timer.percent = 1
				if not timerDataIsHorde[zone] then
					timerDataIsHorde[zone] = {}
				end
				timerDataIsHorde[zone][id] = isHorde
			else
				if timerDataIsHorde[zone] then
					timerDataIsHorde[zone][id] = nil
				end
			end
		end	
		poi.timer:Update()
	end
	if timerData[zone] then
		for id in pairs(timerData[zone]) do
			if not tmp[id] then
				timerData[zone][id] = nil
			end
		end
	end
	if timerDataIsHorde[zone] then
		for id in pairs(timerDataIsHorde[zone]) do
			if not tmp[id] then
				timerDataIsHorde[zone][id] = nil
			end
		end
	end
	for id in pairs(tmp) do
		tmp[id] = nil
	end
	for i = numPois+1, #pois do
		pois[i]:Hide()
	end
	
	updateTimers(0, currentTime)
end

Cartographer3.Utils.AddEventListener("WORLD_MAP_UPDATE", function(event)
	Cartographer3.Utils.AddTimer(f, true) -- have to run even if closed, otherwise battleground timers won't work right
end)

Cartographer3.Utils.AddTimer(updateTimers, true)
