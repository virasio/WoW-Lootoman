local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- Fast autoloot works only while the game loots automatically. While fast
-- autoloot is on and the game's own Auto Loot is off, a box under the fast
-- autoloot block says in red that Auto Loot is off and that fast autoloot
-- needs it, and holds the game's Auto Loot settings: the checkbox and the
-- Auto Loot key, as on the game's Controls page, where an addon may change
-- them; else a button that opens that page. A grey line at the bottom says
-- these are the game's own settings and where it keeps them. Once Auto Loot is
-- on, the message says in white that all is set; the box stays until the
-- player leaves the page (closes the options or goes to another options page)
-- or turns the switch off.
local AutoLootBox = {}
ns.AutoLootBox = AutoLootBox

-- The game's choices for the key, as its Controls page offers them.
local KEYS = { { "ALT", ALT_KEY }, { "CTRL", CTRL_KEY }, { "SHIFT", SHIFT_KEY }, { "NONE", NONE_KEY } }

-- The box's height before it is first laid out; it then fits what it holds.
AutoLootBox.HEIGHT = 112

-- Where the game keeps these settings, in its own words: Options > Gameplay >
-- Controls.
local function path()
	return table.concat({ SETTINGS_TITLE, SETTING_GROUP_GAMEPLAY, CONTROLS_LABEL }, " > ")
end

-- The box's message and its font: while Auto Loot is off, that it is off and
-- that fast autoloot needs it; once it is on, that all is set. The same with
-- the checkbox or with the button.
function AutoLootBox.Message()
	if Compat.GetAutoLoot() then
		return L["All set. Next time this box will be hidden."], "GameFontHighlight"
	end
	return L["Auto Loot is off in the game. Fast Autoloot works only together with Auto Loot."], "GameFontRed"
end

-- The grey line at the bottom: these are the game's settings, and where.
function AutoLootBox.Where()
	return L["These are standard game settings. You can find them in %s."]:format(path())
end

-- Opens the game's Controls page at its Auto Loot setting.
function AutoLootBox.OpenGameSetting()
	local category = Settings.GetCategory(CONTROLS_LABEL)
	if category then
		Settings.OpenToCategory(category:GetID(), AUTO_LOOT_DEFAULT_TEXT)
	end
end

local function refused()
	ns.Print(L["The game's Auto Loot settings can be changed out of combat."])
end

-- The box on the options page (Panel.lua's MainPage), indented like the
-- module's settings.
function AutoLootBox.Build(page, indent, module)
	-- Shown as soon as the page shows Auto Loot off with the switch on, and
	-- kept once Auto Loot is turned on, until the page is shown anew (from a
	-- closed window or another options page) or the switch is turned off (by
	-- a click or with the profile).
	local shown = false
	page:OnOpen(function()
		shown = false
	end)
	page:OnRefresh(function()
		if not Storage:Get(module.name, "enabled") then
			shown = false
		elseif not Compat.GetAutoLoot() then
			shown = true
		end
	end)
	local box = page:AddBox("", AutoLootBox.HEIGHT, { indent = indent, headerFont = "GameFontRed", visible = function()
		return shown
	end })
	local item = page.items[#page.items]
	page.autoLootBox = box

	local row = CreateFrame("Frame", nil, box)
	row:SetHeight(28)
	box.check = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
	box.check:SetPoint("LEFT", row, "LEFT", 0, 0)
	box.check.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	box.check.label:SetPoint("LEFT", box.check, "RIGHT", 4, 0)
	box.check.label:SetText(AUTO_LOOT_DEFAULT_TEXT)
	box.check:SetScript("OnClick", function(button)
		if not Compat.SetAutoLoot(button:GetChecked() and true or false) then
			refused()
		end
		page:Refresh()
	end)

	local keyRow = CreateFrame("Frame", nil, box)
	keyRow:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -4)
	keyRow:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -4)
	keyRow:SetHeight(30)
	box.keyLabel = keyRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	box.keyLabel:SetPoint("LEFT", keyRow, "LEFT", 4, 0)
	box.key = page:NewDropdown(keyRow)
	box.key:SetPoint("LEFT", keyRow, "LEFT", ns.SettingsPanel.CONTROL_X - ns.SettingsPanel.LEFT - indent - 10, 0)
	box.key:SetupMenu(function(_, root)
		for _, choice in ipairs(KEYS) do
			root:CreateRadio(choice[2], function(value)
				return Compat.GetAutoLootKey() == value
			end, function(value)
				if not Compat.SetAutoLootKey(value) then
					refused()
				end
				page:Refresh()
			end, choice[1])
		end
	end)

	-- Where an addon may not change one of them.
	box.open = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	box.open:SetText(L["Open the Game's Setting"])
	box.open:SetSize(math.max(160, (box.open.GetTextWidth and box.open:GetTextWidth() or 0) + 24), 22)
	box.open:SetScript("OnClick", AutoLootBox.OpenGameSetting)

	box.where = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	box.where:SetJustifyH("LEFT")

	-- Whether an addon may change both settings: the checkbox and the key,
	-- else the button.
	local canSet = true

	-- Lays out what the box holds under a message of however many lines, the
	-- grey line last, and gives the box's height. The page calls it at every
	-- layout, once the box's width is known.
	item.measure = function()
		local top = 8 + math.ceil(box.header:GetStringHeight()) + 8
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -top)
		row:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -top)
		box.open:ClearAllPoints()
		box.open:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -top)
		local bottom = top + (canSet and 28 + 4 + 30 or 22) + 8
		box.where:ClearAllPoints()
		box.where:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -bottom)
		box.where:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -bottom)
		return bottom + math.ceil(box.where:GetStringHeight()) + 10
	end

	page:OnRefresh(function()
		canSet = Compat.CanSetAutoLoot() and Compat.CanSetAutoLootKey()
		local text, font = AutoLootBox.Message()
		box.header:SetFontObject(font)
		box.header:SetText(text)
		box.where:SetText(AutoLootBox.Where())
		row:SetShown(canSet)
		keyRow:SetShown(canSet)
		box.open:SetShown(not canSet)
		box.check:SetChecked(Compat.GetAutoLoot())
		-- As the game labels it: the key loots by hand while Auto Loot is on.
		box.keyLabel:SetText(Compat.GetAutoLoot() and LOOT_KEY_TEXT or AUTO_LOOT_KEY_TEXT)
		box.key:GenerateMenu()
	end)
end

-- Under the fast autoloot block's own settings.
local AutoLoot = ns.Modules:Get("AutoLoot")
if AutoLoot then
	AutoLoot.mainSettings = AutoLoot.mainSettings or {}
	table.insert(AutoLoot.mainSettings, { kind = "custom", build = AutoLootBox.Build })
end
