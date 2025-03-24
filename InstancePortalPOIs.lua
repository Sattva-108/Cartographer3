local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

local LibTourist = LibStub and LibStub("LibTourist-3.0")
if not LibTourist.GetEntrancePortalLocation then
	error("Cartographer3 requires at least LibTourist-3.0 r78144")
end

Cartographer3.AddPOIType("InstancePortal", L["Instance Portal"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local texture = poi:CreateTexture(nil, "BORDER")
	texture:SetAllPoints(poi)
	texture:SetTexture([=[Interface\AddOns\Cartographer3\Artwork\Portal]=])
	texture:SetVertexColor(0, 0, 1)
	return poi
end, 1, true)

local BZR = LibStub("LibBabble-Zone-3.0"):GetReverseLookupTable()

local pois = {}

local function poi_AddDataToFullTooltip(self)
	local zone = self.instance
	local faction_r, faction_g, faction_b = LibTourist:GetFactionColor(zone)
	local levelMin, levelMax = LibTourist:GetLevel(zone)
	local level_r, level_g, level_b = LibTourist:GetLevelColor(zone)
	GameTooltip:SetText(zone, faction_r, faction_g, faction_b)
	local factionName
	if LibTourist:IsAlliance(zone) then
		factionName = FACTION_ALLIANCE
	elseif LibTourist:IsHorde(zone) then
		factionName = FACTION_HORDE
	else
		factionName = L["Contested"]
	end
	GameTooltip:AddDoubleLine(L["Faction:"], factionName, nil, nil, nil, faction_r, faction_g, faction_b)
	if levelMin ~= 0 then
		local text
		if levelMin == levelMax then
			text = ("[%d]"):format(levelMin)
		else
			text = ("[%d-%d]"):format(levelMin, levelMax)
		end
		GameTooltip:AddDoubleLine(L["Level range:"], text, nil, nil, nil, level_r, level_g, level_b)
	end
	local groupSize = LibTourist:GetInstanceGroupSize(zone)
	if groupSize ~= 0 then
		GameTooltip:AddDoubleLine(L["Group size:"], groupSize, nil, nil, nil, 1, 1, 1)
	end
end

local t = {}
local function poi_AddDataToTooltipLine(self)
	local zone = self.instance
	local faction_r, faction_g, faction_b = LibTourist:GetFactionColor(zone)
	local levelMin, levelMax = LibTourist:GetLevel(zone)
	local level_r, level_g, level_b = LibTourist:GetLevelColor(zone)
	t[#t+1] = "|cff"
	t[#t+1] = ("%02x"):format(faction_r * 255)
	t[#t+1] = ("%02x"):format(faction_g * 255)
	t[#t+1] = ("%02x"):format(faction_b * 255)
	t[#t+1] = zone
	t[#t+1] = "|r"
	if levelMin ~= 0 then
		t[#t+1] = " "
		t[#t+1] = "|cff"
		t[#t+1] = ("%02x"):format(level_r * 255)
		t[#t+1] = ("%02x"):format(level_g * 255)
		t[#t+1] = ("%02x"):format(level_b * 255)
		t[#t+1] = "["
		t[#t+1] = levelMin
		if levelMin ~= levelMax then
			t[#t+1] = "-"
			t[#t+1] = levelMax
		end
		t[#t+1] = "]"
		t[#t+1] = "|r"
	end
	local groupSize = LibTourist:GetInstanceGroupSize(zone)
	if groupSize ~= 0 then
		t[#t+1] = " "
		t[#t+1] = L["%d-man"]:format(groupSize)
	end
	GameTooltip:AddLine(table.concat(t))
	for i = 1, #t do
		t[i] = nil
	end
end

local function makePoi(instance)
	local englishInstance = BZR[instance]
	local poi = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_Poi_" .. englishInstance:gsub("%A", "_"), Cartographer3_Data.mapView)
	pois[poi] = true
	poi.instance = instance
	poi.englishInstance = englishInstance
	poi.name = L["%s Entrance"]:format(instance)
	poi:SetWidth(1)
	poi:SetHeight(1)
	poi.AddDataToFullTooltip = poi_AddDataToFullTooltip
	poi.AddDataToTooltipLine = poi_AddDataToTooltipLine
	Cartographer3.AddPOI(poi, "InstancePortal")
	
	local texture = poi:CreateTexture(nil--[[poi:GetName() .. "_Texture"]], "BORDER")
	poi.texture = texture
	texture:SetAllPoints(poi)
	texture:SetTexture([=[Interface\AddOns\Cartographer3\Artwork\Portal]=])
	
	return poi
end

local function f()
	Cartographer3.Utils.RemoveTimer(f)
	for instance in LibTourist:IterateInstances() do
		local zone, x, y = LibTourist:GetEntrancePortalLocation(instance)
		if zone then
			local texture = LibTourist:GetTexture(zone)
			local ux, uy = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(texture, x/100, y/100)
			if ux and uy then
				poi = makePoi(instance)
				poi:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", ux, uy)
				local groupSize = LibTourist:GetInstanceGroupSize(instance)
				if groupSize and groupSize > 5 then
					-- raid instance
					poi.texture:SetVertexColor(0, 1, 0)
				else
					-- party instance
					poi.texture:SetVertexColor(0, 0, 1)
				end
			end
		end
	end
end
Cartographer3.Utils.AddTimer(f)

local function zoomFunc(self, zone)
	Cartographer3.Utils.ZoomToZone(zone)
end
Cartographer3.AddRightClickMenuHandler(function(data, level, value, needSeparator)
	if level ~= 1 then
		return
	end
	local first = true
	for i, v in ipairs(data.pois) do
		if pois[v] then
			if first then
				if needSeparator then
					local info = UIDropDownMenu_CreateInfo()
					info.text = " "
					info.isTitle = true
					UIDropDownMenu_AddButton(info, level)
				end
				first = false
			end
			local info = UIDropDownMenu_CreateInfo()
			info.text = L["Zoom to %s"]:format(v.instance)
			info.func = zoomFunc
			info.arg1 = v.englishInstance
			UIDropDownMenu_AddButton(info, level)
		end
	end
	return not first
end)
