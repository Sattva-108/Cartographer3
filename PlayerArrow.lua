local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

local math_cos, math_sin, math_pi = math.cos, math.sin, math.pi

Cartographer3.AddPOIType("Player", L["Player Arrow"], function()
	local exampleArrow = CreateFrame("Frame", nil, UIParent)
	local inner = exampleArrow:CreateTexture(nil--[[playerArrow:GetName() .. "_InnerTexture"]], "ARTWORK")
	inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\ArrowInner]])
	inner:SetAllPoints(exampleArrow)
	local _, playerClass = UnitClass("player")
	local classColor = RAID_CLASS_COLORS[playerClass]
	inner:SetVertexColor(classColor.r, classColor.g, classColor.b)
	local outer = exampleArrow:CreateTexture(nil--[[playerArrow:GetName() .. "_InnerTexture"]], "BORDER")
	outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\ArrowOuter]])
	outer:SetAllPoints(exampleArrow)
	
	local angle = 0
	local x_1 = math_cos(angle + math_pi*3/2)
	local y_1 = math_sin(angle + math_pi*3/2)
	local alpha = x_1 + 0.5
	local bravo = -y_1 + 0.5
	local charlie = -x_1 + 0.5
	local delta = y_1 + 0.5
	inner:SetTexCoord(
		alpha, bravo,
		bravo, charlie,
		delta, alpha,
		charlie, delta
	)
	outer:SetTexCoord(
		alpha, bravo,
		bravo, charlie,
		delta, alpha,
		charlie, delta
	)
	
	
	return exampleArrow
end, 2)

local playerArrow = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_PlayerArrow", mapView)
playerArrow:SetWidth(1)
playerArrow:SetHeight(1)
Cartographer3.AddPOI(playerArrow, "Player")
playerArrow:ClearAllPoints()
local inner = playerArrow:CreateTexture(nil--[[playerArrow:GetName() .. "_InnerTexture"]], "ARTWORK")
playerArrow.inner = inner
inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\ArrowInner]])
inner:SetAllPoints(playerArrow)
local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass]
inner:SetVertexColor(classColor.r, classColor.g, classColor.b)
local outer = playerArrow:CreateTexture(nil--[[playerArrow:GetName() .. "_InnerTexture"]], "BORDER")
playerArrow.outer = outer
outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\ArrowOuter]])
outer:SetAllPoints(playerArrow)
function playerArrow:AddDataToFullTooltip()
	Cartographer3.Utils.AddUnitDataToFullTooltip("player")
end
function playerArrow:AddDataToTooltipLine()
	Cartographer3.Utils.AddUnitDataToTooltipLine("player")
end

local lastAngle
local inCombat = false
local isDead = not not UnitIsDeadOrGhost("player")
local flashing = true
local nextPlayerArrowColorUpdate = 0
local nextSetParent = 0
function Cartographer3.MovePlayerArrow(elapsed, currentTime)
	local playerX, playerY = Cartographer3.Utils.GetUnitUniverseCoordinate("player")
	
	if not playerX then
		playerArrow:Hide()
		return
	end
	playerArrow:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", playerX, playerY)
	playerArrow:Show()
	local angle = Cartographer3.Utils.GetPlayerRotation()
	if angle ~= lastAngle then
		lastAngle = angle
		local x_1 = math_cos(angle + math_pi*3/2)
		local y_1 = math_sin(angle + math_pi*3/2)
		local alpha = x_1 + 0.5
		local bravo = -y_1 + 0.5
		local charlie = -x_1 + 0.5
		local delta = y_1 + 0.5
		playerArrow.inner:SetTexCoord(
			alpha, bravo,
			bravo, charlie,
			delta, alpha,
			charlie, delta
		)
		playerArrow.outer:SetTexCoord(
			alpha, bravo,
			bravo, charlie,
			delta, alpha,
			charlie, delta
		)
	end
	if currentTime > nextPlayerArrowColorUpdate then
		nextPlayerArrowColorUpdate = currentTime + 0.5
		flashing = not flashing
		if flashing then
			if inCombat then
				playerArrow.outer:SetVertexColor(unpack(Cartographer3_Data.COMBAT_COLOR))
			elseif isDead then
				playerArrow.outer:SetVertexColor(unpack(Cartographer3_Data.DEAD_COLOR))
			else
				playerArrow.outer:SetVertexColor(unpack(Cartographer3_Data.NORMAL_STATUS_COLOR))
			end
		else
			playerArrow.outer:SetVertexColor(unpack(Cartographer3_Data.NORMAL_STATUS_COLOR))
		end
	end
	if currentTime > nextSetParent then
		nextSetParent = currentTime + 30
		playerArrow:SetParent(nil)
		playerArrow:SetParent(Cartographer3_Data.mapView)
	end
end

Cartographer3.Utils.AddEventListener("PLAYER_REGEN_ENABLED", function(event)
	inCombat = false
end)

Cartographer3.Utils.AddEventListener("PLAYER_REGEN_DISABLED", function(event)
	inCombat = true
end)

local function PLAYER_DEAD(event)
	isDead = not not UnitIsDeadOrGhost("player")
end
Cartographer3.Utils.AddEventListener("PLAYER_DEAD", PLAYER_DEAD)
Cartographer3.Utils.AddEventListener("PLAYER_ALIVE", PLAYER_DEAD)
Cartographer3.Utils.AddEventListener("PLAYER_UNGHOST", PLAYER_DEAD)
PLAYER_DEAD = nil

Cartographer3.Utils.AddTimer(Cartographer3.MovePlayerArrow)
