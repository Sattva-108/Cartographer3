local _G = _G
local Cartographer3 = _G.Cartographer3
local L = Cartographer3.L("Main")

local LibSimpleOptions = LibStub and LibStub("LibSimpleOptions-1.0", true)
if not LibSimpleOptions then
	LoadAddOn("LibSimpleOptions-1.0")
	LibSimpleOptions = LibStub and LibStub("LibSimpleOptions-1.0", true)
	if not LibSimpleOptions then
		message(("Cartographer3 requires the library %q and will not work without it."):format("LibSimpleOptions-1.0"))
		error(("Cartographer3 requires the library %q and will not work without it."):format("LibSimpleOptions-1.0"))
	end
end

LibSimpleOptions.AddOptionsPanel("Cartographer3", function(self)
	local title, subText = self:MakeTitleTextAndSubText("Cartographer3", L["These options allow you to configure Cartographer3"])
	
	local versionText = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	local format, height, website
	if Cartographer3.versionType == "Development" then
		format = "You are running %s from the source code repository. This is for |cffff7f7fdevelopers only|r. It is recommended in nearly all cases to instead use an alpha version from %s" -- no need for localization
		height = 40
		website = "http://wow.curseforge.com/projects/cartographer3/"
	elseif Cartographer3.versionType == "Alpha" then
		format = L["Version %s: This is for alpha testers wanting to try out new features and have possibly bad bugfixes |cffff7f7fbefore they are ready|r. It is recommended to instead use a beta or release version from %s"]
		height = 40
		website = "curse.com"
	elseif Cartographer3.versionType == "Beta" then
		format = L["Version %s: This is a beta version for those who want to test new features and bugfixes before they are potentially ready. It is recommended to use a release version from %s"]
		height = 40
		website = "curse.com"
	elseif Cartographer3.versionType == "Release" then
		format = L["Version %s. There may be more up-to-date versions on %s"]
		height = 20
		website = "curse.com"
	end
	versionText:SetText(format:format(Cartographer3.version, website))
	versionText:SetNonSpaceWrap(true)
	versionText:SetJustifyH("LEFT")
	versionText:SetJustifyV("TOP")
	versionText:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
	versionText:SetPoint("RIGHT", -32, 0)
--	versionText:SetHeight(height)
	
	local openReportIssueBox, openDonateBox
	do
		local url
		local function makeURLFrame()
			makeURLFrame = nil
			local function bumpFrameLevels(frame, amount)
				frame:SetFrameLevel(frame:GetFrameLevel()+amount)
				local children = newList(frame:GetChildren())
				for _,v in ipairs(children) do
					bumpFrameLevels(v, amount)
				end
				children = del(children)
			end
			-- some code borrowed from Prat here
			StaticPopupDialogs["CARTOGRAPHER3_SHOW_URL"] = {
				text = not IsMacClient() and L["Press Ctrl-C to copy, then Alt-Tab out of the game, open your favorite web browser, and paste the link into the address bar."] or L["Press Cmd-C to copy, then Cmd-Tab out of the game, open your favorite web browser, and paste the link into the address bar."],
				button2 = ACCEPT,
				hasEditBox = 1,
				hasWideEditBox = 1,
				showAlert = 1, -- HACK : it's the only way I found to make de StaticPopup have sufficient width to show WideEditBox :(

				OnShow = function()
					local editBox = _G[this:GetName() .. "WideEditBox"]
					editBox:SetText(url)
					editBox:SetFocus()
					editBox:HighlightText(0)
					editBox:SetScript("OnTextChanged", function() StaticPopup_EditBoxOnTextChanged() end)

					local button = _G[this:GetName() .. "Button2"]
					button:ClearAllPoints()
					button:SetWidth(200)
					button:SetPoint("CENTER", editBox, "CENTER", 0, -30)

					_G[this:GetName() .. "AlertIcon"]:Hide()  -- HACK : we hide the false AlertIcon
					this:SetFrameStrata("FULLSCREEN_DIALOG")
					this:SetFrameLevel(this:GetFrameLevel()+30)
				end,
				OnHide = function()
					local editBox = _G[this:GetName() .. "WideEditBox"]
					editBox:SetScript("OnTextChanged", nil)
					this:SetFrameStrata("DIALOG")
					this:SetFrameLevel(this:GetFrameLevel()-30)
				end,
				OnAccept = function() end,
				OnCancel = function() end,
				EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
				EditBoxOnTextChanged = function()
					this:SetText(url)
					this:SetFocus()
					this:HighlightText(0)
				end,
				timeout = 0,
				whileDead = 1,
				hideOnEscape = 1
			}
		end
		
		function openReportIssueBox()
			if makeURLFrame then
				makeURLFrame()
			end
		
			url = "http://wow.curseforge.com/projects/cartographer3/tickets/"

			StaticPopup_Show("CARTOGRAPHER3_SHOW_URL")
		end
		
		function openDonateBox()
			if makeURLFrame then
				makeURLFrame()
			end
			
			url = "https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=ckknight%40gmail%2ecom&item_name=Cartographer3"

			StaticPopup_Show("CARTOGRAPHER3_SHOW_URL")
		end
	end
	
	local reportButton = self:MakeButton(
		'name', L["Report Issue"],
		'description', L["Report a defect or a possible enhancement you see with Cartographer3."],
		'func', openReportIssueBox)
	reportButton:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -16)
	
	local donateButton = self:MakeButton(
		'name', L["Donate"],
		'description', L["Give a much-needed donation to ckknight, the author of Cartographer3."],
		'func', openDonateBox)
	donateButton:SetPoint("TOPRIGHT", versionText, "BOTTOMRIGHT", 0, -16)
	
	local zoomToMinimapTextureSlider = self:MakeSlider(
		'name', L["Texture Change Zoom"],
		'description', L["The amount to zoom in before the map changes from minimap-style textures to artwork.\n\nNote: Setting this too far may cause severe framerate issues."],
		'minText', L["Far"],
		'maxText', L["Near"],
		'minValue', 0,
		'maxValue', 120,
		'step', 1,
		'default', Cartographer3.Data.DEFAULT_ZOOM_TO_MINIMAP_TEXTURE,
		'current', Cartographer3.db.zoomToMinimapTexture,
		'setFunc', function(value)
			Cartographer3.db.zoomToMinimapTexture = value
		end)
	zoomToMinimapTextureSlider:SetPoint("TOPLEFT", reportButton, "BOTTOMLEFT", 0, -32)
	
	local strataDropDown = self:MakeDropDown(
		'name', L["Strata"],
		'description', L["What level on the interface the map will show up on. 'Fullscreen' is the highest possible level and 'Background' is the lowest."],
		'values', {
			"FULLSCREEN", L["Fullscreen"],
			"DIALOG", L["Dialog"],
			"HIGH", L["High"],
			"MEDIUM", L["Medium"],
			"LOW", L["Low"],
			"BACKGROUND", L["Background"]
		},
		'default', "FULLSCREEN",
		'current', Cartographer3.db.strata,
		'setFunc', function(value)
			Cartographer3.SetFrameStrata(value)
		end)
	strataDropDown:SetPoint("TOPRIGHT", donateButton, "BOTTOMRIGHT", 13, -28)
	
	local closeWithEscapeToggle = self:MakeToggle(
		'name', L["Close map with escape key"],
		'description', L["Set whether pressing the escape key will close the map or not."],
		'default', true,
		'current', Cartographer3.db.closeWithEscape,
		'setFunc', function(value)
			Cartographer3.db.closeWithEscape = value
		end)
	closeWithEscapeToggle:SetPoint("TOPLEFT", zoomToMinimapTextureSlider, "BOTTOMLEFT", 0, -24)
	
	local opacitySlider = self:MakeSlider(
		'name', L["Opacity"],
		'description', L["The opacity of the Cartographer3 map"],
		'minText', "10%",
		'maxText', "100%",
		'minValue', 0.1,
		'maxValue', 1,
		'step', 0.05,
		'default', 1,
		'current', Cartographer3.db.opacity,
		'setFunc', function(value)
			Cartographer3.SetOpacity(value)
		end,
		'currentTextFunc', function(value)
			return ("%.0f%%"):format(value * 100)
		end)
	opacitySlider:SetPoint("TOPLEFT", closeWithEscapeToggle, "BOTTOMLEFT", 0, -24)
	
	local unexploredColorPicker = self:MakeColorPicker(
		'name', L["Unexplored color"],
		'description', L["Set the color of unexplored areas on the Cartographer3 map. White shows everything and black obscures everything."],
		'hasAlpha', true,
		'defaultR', 1,
		'defaultG', 1,
		'defaultB', 1,
		'defaultA', 1,
		'getFunc', function()
			return unpack(Cartographer3.db.unexploredColor)
		end,
		'setFunc', function(r, g, b, a)
			Cartographer3.SetUnexploredColor(r, g, b, a)
		end)
	unexploredColorPicker:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -32)
	
	local alwaysShowBorderToggle = self:MakeToggle(
		'name', L["Always show border"],
		'description', L["Set whether the border should always show or whether it should fade out when not hovering over it."],
		'default', false,
		'current', Cartographer3.db.alwaysShowBorder,
		'setFunc', function(value)
			Cartographer3.db.alwaysShowBorder = value
		end)
	alwaysShowBorderToggle:SetPoint("TOPLEFT", unexploredColorPicker, "BOTTOMLEFT", 0, -16)
end)

LibSimpleOptions.AddSuboptionsPanel("Cartographer3", L["POIs"], function(self)
	local title, subText = self:MakeTitleTextAndSubText(L["POIs"], L["These are options to change how points of interest (POIs) look"])
	
	local scrollFrame, scrollChild = self:MakeScrollFrame()
	scrollFrame:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -16)
	scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -32, 16)
	
	local t = {}
	for id in pairs(Cartographer3.Data.poiTypes) do
		t[#t+1] = id
	end
	table.sort(t)
	local last
	for _, id in ipairs(t) do
		local localizedName = Cartographer3.Data.poiTypes[id]
		local exampleFrame = Cartographer3.Data.poiTypeExampleFrames[id]()
		Cartographer3.Data.poiTypeExampleFrames[id] = nil
		
		local function resize(value)
			local scale = Cartographer3.Data.poiTypeScales[id]
			exampleFrame:SetWidth(scale * 20 * value)
			exampleFrame:SetHeight(scale * 20 * value)
		end
		
		local sizeSlider = self:MakeSlider(
			'name', localizedName,
			'description', L["The size that %s appears on the map"]:format(localizedName),
			'minText', "25%",
			'maxText', "400%",
			'minValue', 0.25,
			'maxValue', 4,
			'step', 0.05,
			'default', 1,
			'current', Cartographer3.db.pois[id],
			'setFunc', function(value)
				Cartographer3.db.pois[id] = value
				for poi in pairs(Cartographer3.Data.shownPOIs) do
					poi:Resize()
				end
				resize(value)
			end,
			'currentTextFunc', function(value)
				return ("%.0f%%"):format(value * 100)
			end)
		
		sizeSlider:SetParent(scrollChild)
		if not last then
			sizeSlider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -24)
		else
			sizeSlider:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -32)
		end
		
		exampleFrame:SetParent(scrollChild)
		exampleFrame:SetPoint("CENTER", sizeSlider, "RIGHT", 100, 0)
		
		resize(Cartographer3.db.pois[id])
		
		last = sizeSlider
	end
end)

LibSimpleOptions.AddSuboptionsPanel("Cartographer3", L["Advanced"], function(self)
	local title, subText = self:MakeTitleTextAndSubText(L["Advanced"], L["These are advanced options for Cartographer3"])
	
	local okayFunc = function()
		if Cartographer3.db.hijackWorldMap ~= Cartographer3.hijackingWorldMap then
			ReloadUI()
		end
	end
	local hijackWorldMapToggle = self:MakeToggle(
		'name', L["Separate Cartographer3 from the World Map"],
		'description', L["Set whether to separate Cartographer3 from the World Map.\n\nNote: This will prevent most third-party addons from working properly.\n\nYou can set the keybinding to open and close Cartographer3 in the Keybindings menu.\n\nChanging this initiates a |cffff0000ReloadUI|r"],
		'default', false,
		'current', not Cartographer3.db.hijackWorldMap,
		'setFunc', function(value)
			Cartographer3.db.hijackWorldMap = not value
		end,
		'okayFunc', okayFunc,
		'cancelFunc', okayFunc,
		'defaultFunc', okayFunc)
	hijackWorldMapToggle:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -16)
end)

LibSimpleOptions.AddSuboptionsPanel("Cartographer3", L["Modules"], function(self)
	local title, subText = self:MakeTitleTextAndSubText(L["Modules"], L["Enable or disable the modules you want"])
	
	local scrollFrame, scrollChild = self:MakeScrollFrame()
	scrollFrame:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -16)
	scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -32, 16)
	
	local modules = {}
	for k in pairs(Cartographer3.modules) do
		modules[#modules+1] = k
	end
	for k in pairs(Cartographer3.potentialModules) do
		modules[#modules+1] = k
	end
	table.sort(modules, function(alpha, bravo)
		local alpha_name = Cartographer3.modules[alpha] and Cartographer3.modules[alpha].name or Cartographer3.potentialModules[alpha][1]
		local bravo_name = Cartographer3.modules[bravo] and Cartographer3.modules[bravo].name or Cartographer3.potentialModules[bravo][1]
		
		return alpha_name < bravo_name
	end)
	
	local last = nil
	
	for _, name in ipairs(modules) do
		local enableStatusToggle = self:MakeToggle(
			'name', Cartographer3.modules[name] and Cartographer3.modules[name].name or Cartographer3.potentialModules[name][1],
			'description', Cartographer3.modules[name] and Cartographer3.modules[name].desc or Cartographer3.potentialModules[name][2],
			'default', true,
			'getFunc', function()
				return not Cartographer3.db[name] or not Cartographer3.db[name].disabled
			end,
			'setFunc', function(value)
				if value then
					Cartographer3.EnableModule(name)
				else
					Cartographer3.DisableModule(name)
				end
			end)
		
		if not last then
			enableStatusToggle:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -16)
		else
			enableStatusToggle:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8)
		end
		
		last = enableStatusToggle
	end
end)

LibSimpleOptions.AddSlashCommand("Cartographer3", "/Cartographer3", "/Cart3", "/Carto3", "/Cartographer", "/Cart", "/Carto")