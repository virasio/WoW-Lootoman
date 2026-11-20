local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- The Ninja Rules window: the detection's rules and checks, in two tabs.
-- Classes: the client's classes in their colours on the left; for the chosen
-- class, which armor types (each up to a level, or at any level), weapon
-- types and primary stats count as its own, named by the game; what the class
-- cannot equip at all is greyed. Checks: the detection's switch (the same as
-- on the options page), each check, the strictness, the lowest quality judged,
-- friends and guild members spared, and the summary on leaving a group. The
-- rules are the account's (Core/NeedRules.lua), the checks the profile's.
-- /ltm ninja and the options page open it, also with the detection off;
-- it is built the first time it opens, out of combat; Escape closes it.
ns.Rolls = ns.Rolls or {}
local NinjaRules = {}
ns.Rolls.NinjaRules = NinjaRules

local Need = ns.Rules.Need

NinjaRules.NAME = "LootomanNinjaRules"
NinjaRules.WIDTH, NinjaRules.HEIGHT = 600, 470
NinjaRules.CLASSES, NinjaRules.CHECKS = 1, 2

local frame

local function data()
	return ns.Data.rolls
end

local function label(parent, text, font)
	local line = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	line:SetJustifyH("LEFT")
	line:SetText(text)
	return line
end

local function colored(classFile)
	local id
	for _, class in ipairs(data().classes) do
		if class[1] == classFile then
			id = class[2]
		end
	end
	return ns.Rolls.Panel.ClassName(id and Compat.GetClassName(id) or classFile, classFile)
end

-- A checkbox with its label at its right.
local function checkbox(parent, text, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check.label = label(parent, text)
	check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	check:SetScript("OnClick", onClick)
	return check
end

local function setEnabled(check, enabled)
	check:SetEnabled(enabled)
	check.label:SetAlpha(enabled and 1 or 0.4)
end

-- The tab of the classes.

local function classValue(part, key)
	return ns.NeedRules.Value(frame.class, part, key)
end

local function refreshClass()
	local class = frame.class
	for _, button in ipairs(frame.classButtons) do
		button.selected:SetShown(button.class == class)
	end
	for _, row in ipairs(frame.rows) do
		local can = Need.CanEquip(data(), class, row.part, row.key)
		local value = classValue(row.part, row.key)
		row.check:SetChecked(value ~= false)
		setEnabled(row.check, can)
		if row.level then
			row.level:SetText(type(value) == "number" and tostring(value) or "")
			row.level:SetEnabled(can and value ~= false)
			row.levelLabel:SetAlpha((can and value ~= false) and 1 or 0.4)
		end
	end
end

-- The value an armor type's box gives: true when empty, a level, or nil for
-- something that is no level.
local function levelOf(text)
	text = (text or ""):gsub("%s", "")
	if text == "" then
		return true
	end
	local level = tonumber(text)
	if level and level == math.floor(level) and level >= 1 and level <= data().maxLevel then
		return level
	end
	return nil
end

local function setRule(part, key, value)
	ns.NeedRules.Set(frame.class, part, key, value)
	refreshClass()
end

local function newRow(parent, part, key, text, withLevel)
	local row = { part = part, key = key }
	row.check = checkbox(parent, text, function(check)
		---@type boolean|number
		local value = check:GetChecked() == true
		if value and row.level then
			value = levelOf(row.level:GetText()) or true
		end
		setRule(part, key, value)
	end)
	if withLevel then
		row.levelLabel = label(parent, L["up to level"], "GameFontHighlightSmall")
		row.level = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		row.level:SetSize(32, 20)
		row.level:SetAutoFocus(false)
		row.level:SetNumeric(true)
		row.level:SetMaxLetters(2)
		local function commit(box)
			local value = levelOf(box:GetText())
			if value == nil then
				refreshClass()
			else
				setRule(part, key, value)
			end
			box:ClearFocus()
		end
		row.level:SetScript("OnEnterPressed", commit)
		row.level:SetScript("OnEditFocusLost", commit)
	end
	frame.rows[#frame.rows + 1] = row
	return row
end

local function buildClasses(tab)
	frame.classButtons, frame.rows = {}, {}
	for index, class in ipairs(data().classes) do
		local button = CreateFrame("Button", nil, tab)
		button:SetSize(130, 20)
		button:SetPoint("TOPLEFT", tab, "TOPLEFT", 8, -8 - (index - 1) * 22)
		button.class = class[1]
		button.selected = button:CreateTexture(nil, "BACKGROUND")
		button.selected:SetAllPoints(button)
		button.selected:SetColorTexture(1, 1, 1, 0.12)
		button.text = label(button, colored(class[1]))
		button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
		button:SetScript("OnClick", function()
			NinjaRules.SelectClass(class[1])
		end)
		frame.classButtons[index] = button
	end
	local x, y = 160, -8
	local function heading(text)
		local line = label(tab, text, "GameFontNormal")
		line:SetPoint("TOPLEFT", tab, "TOPLEFT", x, y)
		y = y - 22
		return line
	end
	frame.armorHeading = heading(L["Armor"])
	for _, key in ipairs(data().armor) do
		local withLevel = Need.ARMOR_TYPES[key] == true
		local row = newRow(tab, "armor", key, Compat.GetItemSubClassName(Need.ARMOR, key) or tostring(key), withLevel)
		row.check:SetPoint("TOPLEFT", tab, "TOPLEFT", x, y)
		if withLevel then
			row.levelLabel:SetPoint("LEFT", row.check, "LEFT", 140, 0)
			row.level:SetPoint("LEFT", row.levelLabel, "RIGHT", 8, 0)
		end
		y = y - 22
	end
	y = y - 6
	frame.weaponsHeading = heading(L["Weapons"])
	local columns = 3
	for index, key in ipairs(data().weapons) do
		local row = newRow(tab, "weapons", key, Compat.GetItemSubClassName(Need.WEAPON, key) or tostring(key))
		local column = (index - 1) % columns
		row.check:SetPoint("TOPLEFT", tab, "TOPLEFT", x + column * 140, y - math.floor((index - 1) / columns) * 22)
	end
	y = y - math.ceil(#data().weapons / columns) * 22 - 6
	frame.statsHeading = heading(L["Primary Stats"])
	for index, stat in ipairs(data().stats) do
		local row = newRow(tab, "stats", stat, Compat.GetGlobalString("ITEM_MOD_" .. stat .. "_SHORT") or stat)
		row.check:SetPoint("TOPLEFT", tab, "TOPLEFT", x + (index - 1) * 105, y)
	end
	frame.resetClass = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
	frame.resetClass:SetSize(130, 22)
	frame.resetClass:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -146, 6)
	frame.resetClass:SetText(L["Reset Class"])
	frame.resetClass:SetScript("OnClick", function()
		ns.NeedRules.Reset(frame.class)
		refreshClass()
	end)
	frame.resetAll = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
	frame.resetAll:SetSize(130, 22)
	frame.resetAll:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 6)
	frame.resetAll:SetText(L["Reset All"])
	frame.resetAll:SetScript("OnClick", function()
		ns.NeedRules.ResetAll()
		refreshClass()
	end)
end

-- The tab of the checks: the profile's settings of the module.

-- The checks: the setting, its label, its tooltip.
NinjaRules.CHECK_KEYS = {
	{ "ninja", L["Detect Ninja Looters"],
		L["Marks needs that look like ninja looting on the panels beside the game's roll frames, with the reasons in their tooltips."] },
	{ "checkArmor", L["Armor Types"], L["A need on an armor type the needer's class does not count as its own, or past the level it counts to."] },
	{ "checkWeapons", L["Weapon Types"], L["A need on a weapon type the needer's class does not count as its own."] },
	{ "checkStats", L["Primary Stats"], L["A need on an item with primary stats, none of which the needer's class counts as its own."] },
	{ "checkEverything", L["Needs Nearly Everything"], L["A player who needs nearly every item in the group."] },
	{ "checkBoE", L["BoE Items"], L["For a need on a BoE item that does not fit: whether the player greeded one that fits, or needs every BoE item."] },
	{ "checkLastTime", L["Last Time"], L["A mark the player had in the last group you were in with him, until he is fair in this one."] },
	{ "spareFriends", L["Never Mark Friends and Guild Members"], L["Friends and members of your guild are never marked."] },
	{ "summary", L["Show Suspicious Needs When Leaving a Group"],
		L["When you leave a group with marked needs, a window lists them, to excuse those the group agreed to."] },
}

local function refreshChecks()
	for _, check in ipairs(frame.checks) do
		check:SetChecked(Storage:Get("Rolls", check.key) == true)
		if check.key ~= "ninja" then
			setEnabled(check, Storage:Get("Rolls", "ninja") == true)
		end
	end
	for _, dropdown in ipairs(frame.dropdowns) do
		dropdown:GenerateMenu()
		dropdown:SetEnabled(Storage:Get("Rolls", "ninja") == true)
	end
end

local function dropdown(tab, key, choices, x, y, text)
	local caption = label(tab, text, "GameFontNormal")
	caption:SetPoint("TOPLEFT", tab, "TOPLEFT", x, y)
	local menu = CreateFrame("DropdownButton", nil, tab, "WowStyle1DropdownTemplate")
	menu:SetWidth(170)
	menu:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -4)
	menu:SetupMenu(function(_, root)
		for _, choice in ipairs(choices) do
			root:CreateRadio(choice[2], function()
				return Storage:Get("Rolls", key) == choice[1]
			end, function()
				Storage:Set("Rolls", key, choice[1])
			end, choice[1])
		end
	end)
	menu.key = key
	frame.dropdowns[#frame.dropdowns + 1] = menu
	return menu
end

local function buildChecks(tab)
	frame.checks, frame.dropdowns = {}, {}
	for index, entry in ipairs(NinjaRules.CHECK_KEYS) do
		local check = checkbox(tab, entry[2], function(button)
			Storage:Set("Rolls", button.key, button:GetChecked() == true)
			refreshChecks()
		end)
		check.key = entry[1]
		local indent = (entry[1] == "ninja") and 0 or 20
		check:SetPoint("TOPLEFT", tab, "TOPLEFT", 12 + indent, -10 - (index - 1) * 26 - (index > 1 and 8 or 0))
		check:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, entry[2])
			GameTooltip_AddNormalLine(GameTooltip, entry[3])
			GameTooltip:Show()
		end)
		check:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		frame.checks[index] = check
	end
	local presets = {}
	for _, name in ipairs(Need.PRESET_ORDER) do
		presets[#presets + 1] = { name, ({ lenient = L["Lenient"], normal = L["Normal"], strict = L["Strict"] })[name] }
	end
	dropdown(tab, "strictness", presets, 380, -40, L["Strictness"])
	local qualities = {}
	for _, quality in ipairs({ 2, 3, 4 }) do
		qualities[#qualities + 1] = { quality, Compat.GetGlobalString("ITEM_QUALITY" .. quality .. "_DESC") or tostring(quality) }
	end
	dropdown(tab, "minQuality", qualities, 380, -110, L["Lowest Quality Judged"])
end

function NinjaRules.ShowTab(id)
	frame.tab = id
	PanelTemplates_SetTab(frame, id)
	frame.classesTab:SetShown(id == NinjaRules.CLASSES)
	frame.checksTab:SetShown(id == NinjaRules.CHECKS)
	if id == NinjaRules.CLASSES then
		refreshClass()
	else
		refreshChecks()
	end
end

function NinjaRules.SelectClass(classFile)
	frame.class = classFile
	refreshClass()
end

local function build()
	frame = CreateFrame("Frame", NinjaRules.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(NinjaRules.WIDTH, NinjaRules.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Ninja Rules"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	table.insert(UISpecialFrames, NinjaRules.NAME)
	frame.inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	frame.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -58)
	frame.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
	local previous
	for id, text in ipairs({ L["Classes"], L["Checks"] }) do
		local tab = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate")
		tab:SetID(id)
		tab:SetText(text)
		if previous then
			tab:SetPoint("LEFT", previous, "RIGHT", 2, 0)
		else
			tab:SetPoint("BOTTOMLEFT", frame.inset, "TOPLEFT", 6, -1)
		end
		tab:SetScript("OnClick", function()
			NinjaRules.ShowTab(id)
		end)
		frame["tab" .. id] = tab
		previous = tab
	end
	PanelTemplates_SetNumTabs(frame, 2)
	frame.classesTab = CreateFrame("Frame", nil, frame.inset)
	frame.classesTab:SetAllPoints()
	frame.checksTab = CreateFrame("Frame", nil, frame.inset)
	frame.checksTab:SetAllPoints()
	frame.class = Compat.GetPlayerClass()
	if not data().canEquip[frame.class] then
		frame.class = data().classes[1][1]
	end
	buildClasses(frame.classesTab)
	buildChecks(frame.checksTab)
	NinjaRules.ShowTab(NinjaRules.CLASSES)
end

-- Opens the window; the first time, out of combat only.
function NinjaRules.Open(tab)
	if not frame then
		if Compat.InCombat() then
			ns.Print(L["The ninja rules open out of combat."])
			return false
		end
		build()
	end
	NinjaRules.ShowTab(tab or frame.tab or NinjaRules.CLASSES)
	frame:Show()
	return true
end

-- The window, for tests.
function NinjaRules.Frame()
	return frame
end

ns.Slash.Register("ninja", function()
	NinjaRules.Open()
end, L["/ltm ninja: open the ninja rules"])
