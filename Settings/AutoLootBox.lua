local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Fast autoloot works only while the game loots automatically. When the
-- game's own Auto Loot is off as the options page opens, a box under the fast
-- autoloot block says so in red and holds the game's Auto Loot settings: the
-- checkbox and the Auto Loot key, as on the game's Controls page, where an
-- addon may change them; else a button that opens that page. The box stays
-- until the page hides, also once Auto Loot is on: the player sees what
-- changed.
local AutoLootBox = {}
ns.AutoLootBox = AutoLootBox

-- The game's choices for the key, as its Controls page offers them.
local KEYS = { { "ALT", ALT_KEY }, { "CTRL", CTRL_KEY }, { "SHIFT", SHIFT_KEY }, { "NONE", NONE_KEY } }

-- The box's height before it is first laid out; it then fits what it holds.
AutoLootBox.HEIGHT = 112

local function keyName(key)
	for _, choice in ipairs(KEYS) do
		if choice[1] == key then
			return choice[2]
		end
	end
end

-- Where the game's setting is, in the game's own words: Options > Gameplay >
-- Controls > Auto Loot.
local function path()
	return table.concat({ SETTINGS_TITLE, SETTING_GROUP_GAMEPLAY, CONTROLS_LABEL, AUTO_LOOT_DEFAULT_TEXT }, " > ")
end

-- The box's header: where to turn Auto Loot on, and the key that loots
-- automatically while it is off.
function AutoLootBox.Header()
	local key = Compat.GetAutoLootKey()
	if key and key ~= "NONE" and keyName(key) then
		return L["Auto Loot is off in the game's settings. For the best experience, turn it on: %s, or hold %s while looting."]:format(path(), keyName(key))
	end
	return L["Auto Loot is off in the game's settings. For the best experience, turn it on: %s."]:format(path())
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
function AutoLootBox.Build(page, indent)
	-- Decided as the page opens; changes made in the box keep it.
	local shown = false
	page:OnOpen(function()
		shown = not Compat.GetAutoLoot()
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
	keyRow:SetHeight(28)
	box.keyLabel = keyRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	box.keyLabel:SetPoint("LEFT", keyRow, "LEFT", 4, 0)
	box.key = CreateFrame("DropdownButton", nil, keyRow, "WowStyle2DropdownTemplate")
	box.key:SetPoint("LEFT", keyRow, "LEFT", ns.SettingsPanel.CONTROL_X - ns.SettingsPanel.LEFT - indent - 10, 0)
	box.key:SetWidth(ns.SettingsPanel.DROPDOWN_WIDTH)
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
	box.open:SetText(L["Open the game's setting"])
	box.open:SetSize(math.max(160, (box.open.GetTextWidth and box.open:GetTextWidth() or 0) + 24), 22)
	box.open:SetScript("OnClick", AutoLootBox.OpenGameSetting)

	page:OnRefresh(function()
		local canSet = Compat.CanSetAutoLoot() and Compat.CanSetAutoLootKey()
		box.header:SetText(AutoLootBox.Header())
		-- The controls under the header, however many lines it takes; the box
		-- as high as what it holds.
		local top = 8 + math.ceil(box.header:GetStringHeight()) + 8
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -top)
		row:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -top)
		box.open:ClearAllPoints()
		box.open:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -top)
		item.height = top + (canSet and 28 + 4 + 28 or 22) + 10
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
