local _G = _G
local Cartographer3 = _G.Cartographer3
local Cartographer3_Data = Cartographer3.Data

local L = Cartographer3.L("Main")

local LibGuildPositions = LibStub and LibStub("LibGuildPositions-1.0", true)
if not LibGuildPositions then
	-- TODO: put a message or something?
	return
end

Cartographer3.AddPOIType("Guild", L["Guild"], function()
	local poi = CreateFrame("Frame", nil, UIParent)
	local outer = poi:CreateTexture(nil, "BORDER")
	outer:SetAllPoints()
	outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\GuildOuter]])
	local inner = poi:CreateTexture(nil, "ARTWORK")
	inner:SetAllPoints()
	inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\GuildInner]])
	local warriorColor = RAID_CLASS_COLORS["WARRIOR"]
	inner:SetVertexColor(warriorColor.r, warriorColor.g, warriorColor.b)
	return poi
end)

local guildPOIs = {}

local guildieNameToClass = setmetatable({}, {__index=function(self, name)
	for i = 1, GetNumGuildMembers() do
		local n, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
		if n == name then
			self[name] = class
			return class
		end
	end
	self[name] = "UNKNOWN"
	return "UNKNOWN"
end})

local function guildMemberPOI_AddDataToFullTooltip(self)
	local name = self.name
	GameTooltip:AddDoubleLine(L["Guild:"], name)
	
	local LibGuild = LibStub("LibGuild-1.0", true)
	if not LibGuild then
		return
	end
	local class, eclass = LibGuild:GetClass(name)
	local classColor = RAID_CLASS_COLORS[eclass]
	if classColor then
		GameTooltip:AddDoubleLine(L["Class:"], class, nil, nil, nil, classColor.r, classColor.g, classColor.b)
	else
		GameTooltip:AddDoubleLine(L["Class:"], class)
	end
	local level = LibGuild:GetLevel(name)
	local difficultyColor = GetQuestDifficultyColor(level)
	if difficultyColor then
		GameTooltip:AddDoubleLine(L["Level:"], level, nil, nil, nil, difficultyColor.r, difficultyColor.g, difficultyColor.b)
	else
		GameTooltip:AddDoubleLine(L["Level:"], level)
	end
	
	local guildRank, guildRankNum = LibGuild:GetRank(name), LibGuild:GetRankIndex(name)
	local guildName, playerGuildRank, playerGuildRankNum = GetGuildInfo('player')
	
	GameTooltip:AddDoubleLine(L["Guild:"], ("<%s>"):format(guildName), nil, nil, nil, 0, 1, 0)
	
	local rankDiff = playerGuildRankNum - guildRankNum
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
	
	GameTooltip:AddDoubleLine(L["Rank:"], guildRank, nil, nil, nil, r, g, b)
	
	local note, officerNote = LibGuild:GetNote(name), LibGuild:GetOfficerNote(name)
	
	if note then
		GameTooltip:AddDoubleLine(L["Note:"], note)
	end

	if officerNote then
		GameTooltip:AddDoubleLine(L["Officer's Note:"], officerNote)
	end
end

local tmp = {}
local function guildMemberPOI_AddDataToTooltipLine(self)
	local name = self.name
	
	tmp[#tmp+1] = name
	local LibGuild = LibStub("LibGuild-1.0", true)
	if not LibGuild then
		GameTooltip:AddLine(text)
		return
	end
	tmp[#tmp+1] = " - |cff"
	local level = LibGuild:GetLevel(name)
	local difficultyColor = GetQuestDifficultyColor(level)
	if difficultyColor then
		tmp[#tmp+1] = ("%02x%02x%02x"):format(difficultyColor.r * 255, difficultyColor.g * 255, difficultyColor.b * 255)
	else
		tmp[#tmp+1] = "ffffff"
	end
	tmp[#tmp+1] = level
	tmp[#tmp+1] = "|r |cff"
	local class, eclass = LibGuild:GetClass(name)
	local classColor = RAID_CLASS_COLORS[eclass]
	if classColor then
		tmp[#tmp+1] = ("%02x%02x%02x"):format(classColor.r * 255, classColor.g * 255, classColor.b * 255)
	else
		tmp[#tmp+1] = "cccccc"
	end
	tmp[#tmp+1] = class
	tmp[#tmp+1] = "|r"
	local gname = LibGuild:GetGuildName()
	tmp[#tmp+1] = " - |cff00ff00<"
	tmp[#tmp+1] = gname
	tmp[#tmp+1] = ">|r"
	local text = table.concat(tmp, "")
	for i = 1, #tmp do
		tmp[i] = nil
	end
	GameTooltip:AddLine(text)
end

local guildMemberNum = 0
function Cartographer3:ShowGuildMember(event, name, x, y, zone)
	local gx, gy = Cartographer3.Utils.ConvertZoneCoordinateToUniverseCoordinate(zone, x, y)
	if gx then
		local poi = guildPOIs[name]
		if not poi then
			poi = table.remove(guildPOIs)
			if not poi then
				guildMemberNum = guildMemberNum + 1
				poi = CreateFrame("Button", Cartographer3_Data.mapView:GetName() .. "_GuildMember" .. guildMemberNum, Cartographer3_Data.mapView)
				poi.AddDataToFullTooltip = guildMemberPOI_AddDataToFullTooltip
				poi.AddDataToTooltipLine = guildMemberPOI_AddDataToTooltipLine
				poi:SetWidth(1)
				poi:SetHeight(1)
				Cartographer3.AddPOI(poi, "Guild")
				local outer = poi:CreateTexture(nil--[[poi:GetName() .. "_OuterTexture"]], "BORDER")
				poi.outer = outer
				outer:SetAllPoints()
				outer:SetTexture([[Interface\AddOns\Cartographer3\Artwork\GuildOuter]])
				local inner = poi:CreateTexture(nil--[[poi:GetName() .. "_InnerTexture"]], "ARTWORK")
				poi.inner = inner
				inner:SetAllPoints()
				inner:SetTexture([[Interface\AddOns\Cartographer3\Artwork\GuildInner]])
			end
			guildPOIs[name] = poi
			poi.name = name
			
			local class = guildieNameToClass[name]
			local classColor = RAID_CLASS_COLORS[class]
			if classColor then
				poi.inner:SetVertexColor(classColor.r, classColor.g, classColor.b)
			else
				poi.inner:SetVertexColor(0.8, 0.8, 0.8)
			end
		end
	
		poi:SetPoint("CENTER", gx, gy)
		poi:Show()
	else
		local poi = guildPOIs[name]
		if poi then
			guildPOIs[name] = nil
			guildPOIs[#guildPOIs] = poi
			poi.name = nil
			poi:Hide()
		end
	end
end

LibGuildPositions.RegisterCallback(Cartographer3, "Position", "ShowGuildMember")
LibGuildPositions.RegisterCallback(Cartographer3, "Clear", "ShowGuildMember")
