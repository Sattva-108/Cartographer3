local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data
local L = Cartographer3.L("Main")

Cartographer3.AddPOIType("Flag", L["Flag"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local texture = poi:CreateTexture(nil, "BORDER")
	texture:SetAllPoints()
	texture:SetTexture([[Interface\WorldStateFrame\AllianceFlag]])
	return poi
end)

local flags = {}

local function makeFlag()
	local flag = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_Flag" .. (#flags + 1), Cartographer3_Data.mapView)
	flags[#flags+1] = flag
	function flag:AddDataToFullTooltip()
		local name = L["Flag"]
		if self.token == "AllianceFlag" then
			name = GetSpellInfo(23335) -- Silverwing Flag
		elseif self.token == "HordeFlag" then
			name = GetSpellInfo(23333) -- Warsong Flag
		end
		GameTooltip:SetText(name)
	end
	flag.AddDataToTooltipLine = flag.AddDataToFullTooltip
	
	flag:SetWidth(1)
	flag:SetHeight(1)
	Cartographer3.AddPOI(flag, "Flag")
	local texture = flag:CreateTexture(nil--[[flag:GetName() .. "_Texture"]], "BORDER")
	flag.texture = texture
	texture:SetAllPoints()
	return flag
end

local nextTime = 0
Cartographer3.Utils.AddTimer(function(elapsed, currentTime)
	if nextTime > currentTime then
		return
	end
	nextTime = currentTime + 0.1
	local numFlags = 1 or GetNumBattlefieldFlagPositions()
	for i = 1, numFlags do
		local flag = flags[i] or makeFlag()
		local x, y, token = GetBattlefieldFlagPosition(i)
		
		local flagX, flagY = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(Cartographer3_Data.currentMapTexture, x, y)
		if flagX then
			flag:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", flagX, flagY)
			flag:Show()
			flag.texture:SetTexture(([=[Interface\WorldStateFrame\%s]=]):format(token))
			flag.token = token
			flag:SetParent(nil)
			flag:SetParent(Cartographer3_Data.mapView)
		else
			flag:Hide()
		end
	end
	for i = numFlags+1, #flags do
		flags[i]:Hide()
	end
end)
