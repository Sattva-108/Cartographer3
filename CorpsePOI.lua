local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

Cartographer3.AddPOIType("Corpse", L["Corpse"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local texture = poi:CreateTexture(nil, "BORDER")
	texture:SetAllPoints()
	texture:SetTexture([[Interface\Minimap\POIIcons]])
	texture:SetTexCoord(0.5, 0.5625, 0, 0.0625)
	return poi
end)

local corpsePOI, rezPOI

local function makePOIs()
	makePOIs = nil
	corpsePOI = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_Corpse", Cartographer3_Data.mapView)
	function corpsePOI:AddDataToFullTooltip()
		GameTooltip:SetText(CORPSE_RED)
	end
	corpsePOI.AddDataToTooltipLine = corpsePOI.AddDataToFullTooltip
	corpsePOI:SetWidth(1)
	corpsePOI:SetHeight(1)
	Cartographer3.AddPOI(corpsePOI, "Corpse")
	local texture = corpsePOI:CreateTexture(nil--[[corpsePOI:GetName() .. "_Texture"]], "BORDER")
	corpsePOI.texture = texture
	texture:SetAllPoints()
	texture:SetTexture([[Interface\Minimap\POIIcons]])
	texture:SetTexCoord(0.5, 0.5625, 0, 0.0625)
	
	rezPOI = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_DeathRelease", Cartographer3_Data.mapView)
	function rezPOI:AddDataToFullTooltip()
		GameTooltip:SetText(SPIRIT_HEALER_RELEASE_RED)
	end
	rezPOI.AddDataToTooltipLine = rezPOI.AddDataToFullTooltip
	rezPOI:SetWidth(1)
	rezPOI:SetHeight(1)
	Cartographer3.AddPOI(rezPOI, "Corpse")
	local texture = rezPOI:CreateTexture(nil--[[rezPOI:GetName() .. "_Texture"]], "BORDER")
	rezPOI.texture = texture
	texture:SetAllPoints()
	texture:SetTexture([[Interface\Minimap\POIIcons]])
	texture:SetTexCoord(0.5, 0.5625, 0, 0.0625)
end

local function positionCorpse()
	local x, y = GetCorpseMapPosition()
	local dead = UnitIsDeadOrGhost("player")
	if not dead or (x ~= 0 and y ~= 0) then
		Cartographer3.Utils.RemoveTimer(positionCorpse)
		
		if dead then
			if not corpsePOI then
				makePOIs()
			end

			local corpseX, corpseY = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(Cartographer3_Data.currentMapTexture, x, y)
			if not corpseX then
				corpsePOI:Hide()
			else
				corpsePOI:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", corpseX, corpseY)
				corpsePOI:Show()
			end

			local rezX, rezY = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(Cartographer3_Data.currentMapTexture, GetDeathReleasePosition())
			if not rezX then
				rezPOI:Hide()
			else
				rezPOI:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", rezX, rezY)
				rezPOI:Show()
			end
		else
			if corpsePOI then
				corpsePOI:Hide()
				rezPOI:Hide()
			end
		end
	end
end

local function PLAYER_DEAD(event)
	if UnitIsDeadOrGhost("player") then
		SetMapToCurrentZone()
	end
	Cartographer3.Utils.AddTimer(positionCorpse)
end
Cartographer3.Utils.AddEventListener("PLAYER_DEAD", PLAYER_DEAD)
Cartographer3.Utils.AddEventListener("PLAYER_ALIVE", PLAYER_DEAD)
Cartographer3.Utils.AddEventListener("PLAYER_UNGHOST", PLAYER_DEAD)
local function PLAYER_LOGIN()
	Cartographer3.Utils.RemoveEventListener("PLAYER_LOGIN", PLAYER_LOGIN)
	PLAYER_LOGIN = nil
	PLAYER_DEAD()
end
Cartographer3.Utils.AddEventListener("PLAYER_LOGIN", PLAYER_LOGIN)
