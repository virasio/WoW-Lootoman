local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- The Ninja Rules window: the detection's rules and checks, in two tabs.
-- Classes: the client's classes in their colours on the left; for the chosen
-- class, which armor types (each up to a level, or at any level), weapon
-- types and primary stats count as its own, named by the game; what the class
-- cannot equip at all is greyed. Checks: each check, the strictness, the
-- lowest quality judged,
-- friends and guild members spared, and the summary on leaving a group. The
-- rules are the account's (Core/NeedRules.lua), the checks the profile's.
-- The detection's own switch is on the options page only. /ltm ninja, the
-- minimap menu and the options page's button open the window while the
-- detection is on; off, the first two ask to turn it on. It is built the
-- first time it opens, out of combat; Escape closes it.
ns.Rolls = ns.Rolls or {}
local NinjaRules = {}
ns.Rolls.NinjaRules = NinjaRules

local Need = ns.Rules.Need

NinjaRules.NAME = "LootomanNinjaRules"
-- The inset inside is 620 by 452. Classes: the class list at the left (up
-- to 13 classes of 22 pixels: 294), the rules in a scrolled area right of it
-- (442 by 408: armor 8 rows, weapons 8 rows of two columns of 210, stats 2
-- rows of two, about 520 high), the Reset buttons under it. Checks: nine
-- checkboxes and two dropdowns, scrolled too (586 by 440).
NinjaRules.WIDTH, NinjaRules.HEIGHT = 640, 520
NinjaRules.ROW = 24
NinjaRules.COLUMN = 210
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

-- A checkbox with its label at its right, cut short at width rather than
-- running into what stands beside it.
local function checkbox(parent, text, onClick, width)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check.label = label(parent, text)
	check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	if width then
		check.label:SetWidth(width)
		check.label:SetWordWrap(false)
	end
	check:SetScript("OnClick", onClick)
	return check
end

-- A scrolled area in a tab, between the given insets: its content frame,
-- whose height the caller sets once it is filled.
local function scrolled(tab, left, top, right, bottom)
	local scroll = CreateFrame("ScrollFrame", nil, tab, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", tab, "TOPLEFT", left, -top)
	scroll:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -right, bottom)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(NinjaRules.WIDTH - 20 - left - right - 12, 1)
	scroll:SetScrollChild(content)
	content.scroll = scroll
	return content
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

local function newRow(parent, part, key, text, withLevel, width)
	local row = { part = part, key = key }
	row.check = checkbox(parent, text, function(check)
		---@type boolean|number
		local value = check:GetChecked() == true
		if value and row.level then
			value = levelOf(row.level:GetText()) or true
		end
		setRule(part, key, value)
	end, width)
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
	local content = scrolled(tab, 150, 6, 28, 38)
	frame.classesContent = content
	local x, y = 8, -4
	local function heading(text)
		local line = label(content, text, "GameFontNormal")
		line:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
		y = y - 22
		return line
	end
	frame.armorHeading = heading(L["Armor"])
	for _, key in ipairs(data().armor) do
		local withLevel = Need.ARMOR_TYPES[key] == true
		local row = newRow(content, "armor", key, Compat.GetItemSubClassName(Need.ARMOR, key) or tostring(key), withLevel, 120)
		row.check:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
		if withLevel then
			row.levelLabel:SetPoint("LEFT", row.check, "LEFT", 160, 0)
			row.level:SetPoint("LEFT", row.levelLabel, "RIGHT", 8, 0)
		end
		y = y - NinjaRules.ROW
	end
	-- Two columns, each label cut at the column's width.
	local function grid(part, keys, name)
		for index, key in ipairs(keys) do
			local row = newRow(content, part, key, name(key), false, NinjaRules.COLUMN - 32)
			local column = (index - 1) % 2
			row.check:SetPoint("TOPLEFT", content, "TOPLEFT", x + column * NinjaRules.COLUMN, y - math.floor((index - 1) / 2) * NinjaRules.ROW)
		end
		y = y - math.ceil(#keys / 2) * NinjaRules.ROW
	end
	y = y - 8
	frame.weaponsHeading = heading(L["Weapons"])
	grid("weapons", data().weapons, function(key)
		return Compat.GetItemSubClassName(Need.WEAPON, key) or tostring(key)
	end)
	y = y - 8
	frame.statsHeading = heading(L["Primary Stats"])
	grid("stats", data().stats, function(stat)
		return Compat.GetGlobalString("ITEM_MOD_" .. stat .. "_SHORT") or stat
	end)
	content:SetHeight(-y + 8)
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
		setEnabled(check, Storage:Get("Rolls", "ninja") == true)
	end
	for _, dropdown in ipairs(frame.dropdowns) do
		dropdown:GenerateMenu()
		dropdown:SetEnabled(Storage:Get("Rolls", "ninja") == true)
	end
end

local function dropdown(parent, key, choices, x, y, text)
	local caption = label(parent, text, "GameFontNormal")
	caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local menu = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
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
	local content = scrolled(tab, 6, 6, 28, 6)
	frame.checksContent = content
	local y = -6
	for index, entry in ipairs(NinjaRules.CHECK_KEYS) do
		local check = checkbox(content, entry[2], function(button)
			Storage:Set("Rolls", button.key, button:GetChecked() == true)
			refreshChecks()
		end, 520)
		check.key = entry[1]
		check:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
		y = y - 26
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
	-- The strictness and the quality under the checkboxes, side by side.
	local presets = {}
	for _, name in ipairs(Need.PRESET_ORDER) do
		presets[#presets + 1] = { name, ({ lenient = L["Lenient"], normal = L["Normal"], strict = L["Strict"] })[name] }
	end
	y = y - 12
	dropdown(content, "strictness", presets, 28, y, L["Strictness"])
	local qualities = {}
	for _, quality in ipairs({ 2, 3, 4 }) do
		qualities[#qualities + 1] = { quality, Compat.GetGlobalString("ITEM_QUALITY" .. quality .. "_DESC") or tostring(quality) }
	end
	dropdown(content, "minQuality", qualities, 260, y, L["Lowest Quality Judged"])
	content:SetHeight(-y + 60)
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

-- Opens the window while the detection is on; else asks to turn on what is
-- off: the loot rolls, or their detection.
function NinjaRules.OpenOrAsk()
	local rolls = ns.Modules:Get("Rolls")
	if not (rolls and rolls:IsActive()) then
		ns.TurnOn.Ask(L["Show Who Rolled What"])
	elseif not Storage:Get("Rolls", "ninja") then
		ns.TurnOn.Ask(L["Detect Ninja Looters"])
	else
		NinjaRules.Open()
	end
end

ns.Slash.Register("ninja", NinjaRules.OpenOrAsk, L["/ltm ninja: open the ninja rules"])
