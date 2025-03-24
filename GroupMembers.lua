local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

local LibSimpleOptions = LibStub("LibSimpleOptions-1.0")

Cartographer3.AddPOIType("Group", L["Group"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local outer = poi:CreateTexture(nil, "BORDER")
	outer:SetAllPoints()
	outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\PartyOuter]])
	local inner = poi:CreateTexture(nil, "ARTWORK")
	inner:SetAllPoints()
	inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\PartyInner]])
	local warriorColor = RAID_CLASS_COLORS["WARRIOR"]
	inner:SetVertexColor(warriorColor.r, warriorColor.g, warriorColor.b)
	return poi
end)

local groupPOIs = {}

local function groupMemberPOI_AddDataToFullTooltip(self)
	Cartographer3.Utils.AddUnitDataToFullTooltip(self.unit)
end
local function groupMemberPOI_AddDataToTooltipLine(self)
	Cartographer3.Utils.AddUnitDataToTooltipLine(self.unit)
end

local OPPOSITE_POSITION = {
	LEFT = "RIGHT",
	RIGHT = "LEFT",
	TOP = "BOTTOM",
	BOTTOM = "TOP",
}

local nextGroupMemberColorUpdate = 0
local flashing = true
local nextTime = 0
function Cartographer3.ShowGroupMembers(elapsed, currentTime)
	if nextTime > currentTime then
		return
	end
	nextTime = currentTime + 0.1
	local prefix, amount = "raid", GetNumRaidMembers()
	local playerRaidID = 0
	if amount == 0 then
		prefix, amount = "party", GetNumPartyMembers()
	else
		playerRaidID = UnitInRaid("player") + 1
	end
	local inBG = select(2, IsInInstance()) == "pvp"
	local showTexts = inBG and Cartographer3.db.showGroupMemberNamesInBattlegrounds
	for i = 1, amount do
		local poi = groupPOIs[i]
		if not poi then
			poi = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_GroupMember" .. i, Cartographer3_Data.mapView)
			groupPOIs[i] = poi
			poi.AddDataToFullTooltip = groupMemberPOI_AddDataToFullTooltip
			poi.AddDataToTooltipLine = groupMemberPOI_AddDataToTooltipLine
			poi:SetWidth(1)
			poi:SetHeight(1)
			Cartographer3.AddPOI(poi, "Group")
			local outer = poi:CreateTexture(nil--[[poi:GetName() .. "_OuterTexture"]], "BORDER")
			poi.outer = outer
			outer:SetAllPoints()
			outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\PartyOuter]])
			local inner = poi:CreateTexture(nil--[[poi:GetName() .. "_InnerTexture"]], "ARTWORK")
			poi.inner = inner
			inner:SetAllPoints()
			inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\PartyInner]])
			local texture = poi:CreateTexture(nil--[[poi:GetName() .. "_Text"]], "OVERLAY")
			poi.texture = texture
			texture:SetAllPoints()
			texture:SetVertexColor(0, 0, 0)
			
			local text = poi:CreateFontString(nil--[[poi:GetName() .. "_Text"]], "ARTWORK", "GameFontNormal")
			poi.text = text
			local side = Cartographer3.db.groupMemberNamePosition
			text:SetPoint(OPPOSITE_POSITION[side], poi, side)
		end
		if i ~= playerRaidID then
			local unit = prefix .. i
			poi.unit = unit
			local x, y = Cartographer3.Utils.GetUnitUniverseCoordinate(unit)
			if not x then
				poi:Hide()
			else
				poi:Show()
			
				poi:SetPoint("CENTER", Cartographer3_Data.mapView, "CENTER", x, y)
			end
			local name = UnitName(unit)
			
			if showTexts then
				poi.text:SetText(name)
				local _, class = UnitClass(unit)
				local classColor = RAID_CLASS_COLORS[class]
				if classColor then
					poi.text:SetTextColor(classColor.r, classColor.g, classColor.b)
				else
					poi.text:SetTextColor(0.8, 0.8, 0.8)
				end
			else
				poi.text:SetText(nil)
			end
		else
			poi:Hide()
		end
	end
	for i = amount+1, #groupPOIs do
		local poi = groupPOIs[i]
		poi:Hide()
	end
	if currentTime > nextGroupMemberColorUpdate then
		nextGroupMemberColorUpdate = currentTime + 0.5
		flashing = not flashing
		for i = 1, amount do
			local poi = groupPOIs[i]
			if poi:IsShown() then
				local poi_inner = poi.inner
				local poi_outer = poi.outer
				local unit = poi.unit
				if prefix == "raid" then
					local _, _, subgroup = GetRaidRosterInfo(i)
					poi.texture:SetTexture([[Interface\AddOns\Cartographer3\Artwork\Group]] .. subgroup)
					poi.texture:Show()
				else
					poi.texture:Hide()
				end
				if flashing then
					if UnitAffectingCombat(unit) then
						poi_outer:SetVertexColor(unpack(Cartographer3_Data.COMBAT_COLOR))
					elseif UnitIsDeadOrGhost(unit) then
						poi_outer:SetVertexColor(unpack(Cartographer3_Data.DEAD_COLOR))
					elseif PlayerIsPVPInactive(unit) then
						poi_outer:SetVertexColor(unpack(Cartographer3_Data.INACTIVE_COLOR))
					else
						poi_outer:SetVertexColor(unpack(Cartographer3_Data.NORMAL_STATUS_COLOR))
					end
				else
					poi_outer:SetVertexColor(unpack(Cartographer3_Data.NORMAL_STATUS_COLOR))
				end
				if not done then
					local _, class = UnitClass(unit)
					local classColor = RAID_CLASS_COLORS[class]
					if classColor then
						poi_inner:SetVertexColor(classColor.r, classColor.g, classColor.b)
					else
						poi_inner:SetVertexColor(0.7, 0.7, 0.7)
					end
				end
			end
		end
	end
end
Cartographer3.Utils.AddTimer(Cartographer3.ShowGroupMembers)

do
	local getAFKUnits
	do
		local units = {}
		function getAFKUnits(pois)
			for i in ipairs(units) do
				units[i] = nil
			end
			
			for i, poi in ipairs(pois) do
				local unit = poi.unit
				if unit and PlayerIsPVPInactive(unit) then
					units[#units+1] = unit
				end
			end
			
			return units
		end
	end
	
	local function reportAll(self, units)
		for i, unit in ipairs(units) do
			ReportPlayerIsPVPAFK(unit)
		end
	end
	
	local function reportUnit(self, unit)
		ReportPlayerIsPVPAFK(unit)
	end
	
	Cartographer3.AddRightClickMenuHandler(function(data, level, value, needSeparator)
		if select(2, IsInInstance()) ~= "pvp" then
			return
		end
		
		local units = getAFKUnits(data.pois)
		
		if #units == 0 then
			-- no point in showing the menu, then
			return
		end
		
		if level == 1 then
			if needSeparator then
				local info = UIDropDownMenu_CreateInfo()
				info.text = " "
				info.isTitle = true
				UIDropDownMenu_AddButton(info, level)
			end
			local info = UIDropDownMenu_CreateInfo()
			info.text = L["Report AFK"]
			info.hasArrow = true
			info.value = "report_pvp_afk"
			UIDropDownMenu_AddButton(info, level)
			return true
		elseif level == 2 then
			if value == "report_pvp_afk" then
				if needSeparator then
					local info = UIDropDownMenu_CreateInfo()
					info.text = " "
					info.isTitle = true
					UIDropDownMenu_AddButton(info, level)
				end
				for _, unit in ipairs(units) do
					local info = UIDropDownMenu_CreateInfo()
					local _, class = UnitClass(unit)
					local classColor = RAID_CLASS_COLORS[class]
					local name = UnitName(unit)
					if classColor then
						name = ("|cff%02x%02x%02x%s|r"):format(classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
					end
					local unitLevel = UnitLevel(unit)
					local levelColor = GetQuestDifficultyColor(unitLevel)
					if levelColor then
						name = ("[|cff%02x%02x%02x%d|r] %s"):format(levelColor.r * 255, levelColor.g * 255, levelColor.b * 255, unitLevel, name)
					end
					info.text = name
					info.func = reportUnit
					info.arg1 = unit
					UIDropDownMenu_AddButton(info, level)
				end
				
				local info = UIDropDownMenu_CreateInfo()
				info.text = " "
				info.isTitle = true
				UIDropDownMenu_AddButton(info, level)
				
				if #units > 1 then
					local info = UIDropDownMenu_CreateInfo()
					info.text = PVP_REPORT_AFK_ALL
					info.func = reportAll
					info.arg1 = units
					UIDropDownMenu_AddButton(info, level)
				end
				return true
			end
		end
	end)
end

LibSimpleOptions.AddSuboptionsPanel("Cartographer3", L["Group Members"], function(self)
	local title, subText = self:MakeTitleTextAndSubText(L["Group Members"], L["These options allow you to configure the group member points of interest (POIs)."])
	
	local showNamesInBattlegroundsToggle = self:MakeToggle(
		'name', L["Show names in battlegrounds"],
		'description', L["Set whether you want your group members' names to show when in battlegrounds."],
		'default', true,
		'current', Cartographer3.db.showGroupMemberNamesInBattlegrounds,
		'setFunc', function(value)
			Cartographer3.db.showGroupMemberNamesInBattlegrounds = value
		end)
	showNamesInBattlegroundsToggle:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -24)
	
	local namePositionDropDown = self:MakeDropDown(
		'name', L["Name position"],
		'description', L["Set the position which the name shows on."],
		'values', {
			"LEFT", L["Left"],
			"RIGHT", L["Right"],
			"TOP", L["Top"],
			"BOTTOM", L["Bottom"]
		},
		'default', "RIGHT",
		'current', Cartographer3.db.groupMemberNamePosition,
		'setFunc', function(value)
			Cartographer3.db.groupMemberNamePosition = value
			for i, poi in ipairs(groupPOIs) do
				poi.text:ClearAllPoints()
				poi.text:SetPoint(OPPOSITE_POSITION[value], poi, value)
			end
		end)
	
	namePositionDropDown:SetPoint("TOPLEFT", showNamesInBattlegroundsToggle, "BOTTOMLEFT", 0, -24)
end)
