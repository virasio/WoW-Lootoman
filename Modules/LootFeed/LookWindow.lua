local _, ns = ...
local Bus, Compat, L, NameMenu, Storage = ns.Bus, ns.Compat, ns.L, ns.NameMenu, ns.Storage
local Feed = ns.Feed

-- The feed look window: everything about one feed look (Looks.lua) in one
-- window, opened from Edit in a look's menu (LookMenu.lua), or with
-- /lootoman design for the profile's look. On the left, sample rows of every
-- kind, drawn by the feed's own code in the look's design and size, each in
-- its box. On the right, two tabs:
-- - Feed: the look's settings in their groups (Looks.Settings), scrolled.
-- - Row design: the look's view, rows or icons, and the chosen part, in the
--   spirit of Platynator's nameplate designer: what it is anchored to and
--   where, its size, alignment and offsets. Numbers have a slider and a field
--   to type them in; both only go as far as the row's box allows
--   (Design.Range). An Icons look lists only what it lets the player change:
--   the icon's size and the gap between icons (as the row), the amount and the
--   owned count; its samples stand side by side.
-- Click a part in the samples to choose it, which brings up the Row design
-- tab; drag it to move it on the grid. A gold frame marks the chosen part (for
-- a text, the most room it may take), or the row when no part is chosen.
-- Every change is saved in the look, and the feed follows at once when the
-- profile uses it.
--
-- The window edits the look it was opened for, whichever look the profile
-- uses: that is chosen in the look menus. Reset returns the look to its
-- defaults; Share opens the dialog of look texts with this look ticked.
--
-- The window is the player's own frame, built the first time it opens, never
-- in combat; Escape and its close button hide it.
local LootFeed = ns.Modules:Get("LootFeed")
local Design, Frames, Looks, LookMenu = Feed.Design, Feed.Frames, Feed.Looks, Feed.LookMenu

local LookWindow = {}
Feed.LookWindow = LookWindow
LootFeed.LookWindow = LookWindow

LookWindow.WIDTH = 900
LookWindow.HEIGHT = 640
LookWindow.PREVIEW_WIDTH = 440
-- The inspector's controls are this far apart; each one's label is nearer to
-- it than to the one before.
LookWindow.CONTROL_HEIGHT = 46
-- The window's global name, for UISpecialFrames.
LookWindow.NAME = "LootomanLookWindow"
-- The tabs.
LookWindow.FEED, LookWindow.DESIGN = 1, 2

local TITLES = { row = L["Row"], icon = L["Icon"], name = L["Name"], amount = L["Amount"], owned = L["Owned count"] }
local PART_ORDER = { "row", "icon", "name", "amount", "owned" }
local POINT_NAMES = {
	TOPLEFT = L["Top left"],
	TOP = L["Top"],
	TOPRIGHT = L["Top right"],
	LEFT = L["Left"],
	CENTER = L["Center"],
	RIGHT = L["Right"],
	BOTTOMLEFT = L["Bottom left"],
	BOTTOM = L["Bottom"],
	BOTTOMRIGHT = L["Bottom right"],
}
local ALIGN_NAMES = { LEFT = L["Left"], RIGHT = L["Right"] }
local COUNT_NAMES = { all = L["Bags and bank"], bags = L["Bags only"] }

local TEXT_CONTROLS = {
	{ key = "shown", label = L["Shown"] },
	{ key = "anchor", label = L["Anchor to"] },
	{ key = "point", label = L["Anchor point"] },
	{ key = "align", label = L["Text alignment"] },
	{ key = "fontSize", label = L["Text size"] },
	{ key = "width", label = L["Maximum width"] },
	{ key = "x", label = L["Horizontal offset"] },
	{ key = "y", label = L["Vertical offset"] },
}

-- What the inspector shows for each part, in order.
local CONTROLS = {
	row = {
		{ key = "height", label = L["Row height"] },
		{ key = "width", label = L["Width"] },
		{ key = "gap", label = L["Gap between rows"] },
	},
	icon = {
		{ key = "shown", label = L["Shown"] },
		{ key = "anchor", label = L["Anchor to"] },
		{ key = "point", label = L["Anchor point"] },
		{ key = "size", label = L["Size, percent of the row height"] },
		{ key = "x", label = L["Horizontal offset"] },
		{ key = "y", label = L["Vertical offset"] },
	},
	name = TEXT_CONTROLS,
	amount = {},
	owned = {},
}
-- The amount and the owned count also have a background of their own; the
-- owned count also says what it counts.
local COUNTS = { key = "count", label = L["Counts"] }
for _, part in ipairs({ "amount", "owned" }) do
	for index, control in ipairs(TEXT_CONTROLS) do
		CONTROLS[part][index] = control
	end
	table.insert(CONTROLS[part], { key = "background", label = L["Background"] })
	table.insert(CONTROLS[part], { key = "opacity", label = L["Background opacity"] })
end
table.insert(CONTROLS.owned, 2, COUNTS)
-- An Icons layout's parts and controls: the rest of it is fixed (Design.lua).
-- The amount and the owned count sit on the icon, each set alike.
local ICON_PARTS = { "row", "amount", "owned" }
local ON_THE_ICON = {
	{ key = "shown", label = L["Shown"] },
	{ key = "point", label = L["Anchor point"] },
	{ key = "align", label = L["Text alignment"] },
	{ key = "fontSize", label = L["Text size"] },
	{ key = "x", label = L["Horizontal offset"] },
	{ key = "y", label = L["Vertical offset"] },
	{ key = "background", label = L["Background"] },
	{ key = "opacity", label = L["Background opacity"] },
}
local ICON_CONTROLS = {
	row = {
		{ key = "height", label = L["Icon size"] },
		{ key = "gap", label = L["Gap between icons"] },
	},
	amount = ON_THE_ICON,
	owned = { ON_THE_ICON[1], COUNTS },
}
for index = 2, #ON_THE_ICON do
	table.insert(ICON_CONTROLS.owned, ON_THE_ICON[index])
end
-- A checkbox for a switch, a dropdown for a choice, else a slider with a field.
local KINDS = { shown = "check", background = "check", anchor = "choice", point = "choice", align = "choice", count = "choice" }
local CONTROL_COUNT = 0
for _, list in pairs(CONTROLS) do
	CONTROL_COUNT = math.max(CONTROL_COUNT, #list)
end

local function isIcons(design)
	return Design.View(design) == "icons"
end

-- The parts a design lists, in order, and their controls.
local function partsOf(design)
	return isIcons(design) and ICON_PARTS or PART_ORDER
end

local function controlsOf(design)
	return isIcons(design) and ICON_CONTROLS or CONTROLS
end

-- An Icons layout's row is its icon.
local function titleOf(design, part)
	return isIcons(design) and part == "row" and TITLES.icon or TITLES[part]
end

local window
local selected = "row"
local drag
-- The look the window edits.
local edited = Looks.DEFAULT

local function section()
	return Looks.Get(edited) or Looks.Get(Looks.DEFAULT)
end

local function scale()
	return Looks.Value(edited, "size") / Design.BASE_SIZE
end

-- The choices of a dropdown control for a part, as { value, text }.
local function choices(key, design, part)
	local list = {}
	if key == "anchor" then
		for _, element in ipairs(Design.Targets(design, part)) do
			list[#list + 1] = { element, TITLES[element] }
		end
	elseif key == "point" then
		for _, point in ipairs(Design.POINTS) do
			list[#list + 1] = { point, POINT_NAMES[point] }
		end
	elseif key == "count" then
		for _, count in ipairs(Design.COUNTS) do
			list[#list + 1] = { count, COUNT_NAMES[count] }
		end
	else
		for _, align in ipairs(Design.ALIGNS) do
			list[#list + 1] = { align, ALIGN_NAMES[align] }
		end
	end
	return list
end

-- The gold frame in a row: around the row or the chosen icon, and around the
-- most a chosen text may take, from the side it grows from: its maximum width,
-- as far as the row allows. Hidden where the chosen part is not shown.
local function mark(rowFrame, layout)
	local frame = rowFrame.Selected
	frame:ClearAllPoints()
	if selected == "row" then
		frame:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", -2, 2)
		frame:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", 2, -2)
		frame:Show()
		return
	end
	local region = rowFrame[Frames.REGIONS[selected]]
	frame:SetShown(region:IsShown())
	if Design.TEXTS[selected] then
		local side = layout.parts[selected].align
		local outward = side == "LEFT" and -2 or 2
		local width = Design.Arrange(layout, { [selected] = math.huge })[selected].width
		frame:SetPoint("TOP" .. side, region, "TOP" .. side, outward, 2)
		frame:SetPoint("BOTTOM" .. side, region, "BOTTOM" .. side, outward, -2)
		frame:SetWidth(width + 4)
	else
		frame:SetPoint("TOPLEFT", region, "TOPLEFT", -2, 2)
		frame:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 2, -2)
	end
end

-- Whether a part's hit area is there: an Icons layout's name cannot be
-- changed, and its icon stands for the row.
local function hittable(design, part)
	return not isIcons(design) or part ~= "name"
end

-- What clicking or dragging a part chooses: an Icons layout's icon is its row.
local function partOf(part)
	if part == "icon" and isIcons(Design.Current(section())) then
		return "row"
	end
	return part
end

-- After any change: the title, the preview and both tabs. A look deleted
-- meanwhile closes the window.
function LookWindow.Refresh()
	if not window then
		return
	end
	if not Looks.Get(edited) then
		window:Hide()
		return
	end
	window:SetTitle(L["Feed look: %s"]:format(Looks.DisplayName(edited)))
	local design = Design.Current(section())
	if not controlsOf(design)[selected] then
		selected = "row"
	end
	local layout = Design.Layout(design, Looks.Value(edited, "size"))
	local options = { layout = layout, showOwned = design.parts.owned.shown, showGlow = Looks.Value(edited, "glow") }
	-- Rows one under another; icons side by side, wrapping at the preview's edge.
	local left, top = 0, 0
	local room = LookWindow.PREVIEW_WIDTH - 24
	for index, rowFrame in ipairs(window.rows) do
		Frames.ApplyLayout(rowFrame, layout)
		local sample = window.samples[index]
		Frames.Fill(rowFrame, sample.row, options, sample.stuck and { waiting = sample.waiting } or nil)
		if isIcons(design) and left > 0 and left + layout.width > room then
			left, top = 0, top + layout.height + layout.gap
		end
		rowFrame:ClearAllPoints()
		rowFrame:SetPoint("TOPLEFT", window.preview, "TOPLEFT", 12 + left, -12 - top)
		rowFrame:Show()
		if isIcons(design) then
			left = left + layout.width + layout.gap
		else
			top = top + layout.height + layout.gap
		end
		rowFrame.Box:SetAlpha(selected == "row" and 1 or 0.5)
		mark(rowFrame, layout)
		for part, hit in pairs(rowFrame.hits) do
			hit:SetShown(rowFrame[Frames.REGIONS[part]]:IsShown() and hittable(design, part))
		end
	end
	LookWindow.UpdateInspector()
	window.parts:GenerateMenu()
	window.view:GenerateMenu()
	LookWindow.UpdateFeed()
end

-- Changes one value of a part (from the inspector).
function LookWindow.Change(part, key, value)
	Looks.SetDesign(edited, part, key, value)
	LookWindow.Refresh()
end

-- Chooses a part, on the Row design tab.
function LookWindow.Select(part)
	selected = part
	LookWindow.ShowTab(LookWindow.DESIGN)
	LookWindow.Refresh()
end

-- Changes one of the look's settings (from the Feed tab).
function LookWindow.Set(key, value)
	Looks.Set(edited, key, value)
	LookWindow.Refresh()
end

-- The look back to its defaults, after a confirmation.
function LookWindow.Reset()
	LookMenu.Reset(edited)
end

-- The look turned into the other view, after a confirmation: its design
-- starts afresh.
function LookWindow.SetView(view)
	if view == Looks.View(edited) then
		return
	end
	local name = edited
	local text = view == "icons" and L["Make look “%s” a look of icons? Its row design starts afresh."]
		or L["Make look “%s” a look of rows? Its row design starts afresh."]
	NameMenu.Confirm(text, Looks.DisplayName(name), L["Change"], function()
		Looks.SetView(name, view)
	end)
end

-- Shows a tab: the Feed tab's settings or the Row design tab's inspector.
function LookWindow.ShowTab(id)
	if not window then
		return
	end
	window.tab = id
	PanelTemplates_SetTab(window, id)
	window.feedTab:SetShown(id == LookWindow.FEED)
	window.designTab:SetShown(id == LookWindow.DESIGN)
end

-- The inspector's title and controls for the chosen part, with its values.
function LookWindow.UpdateInspector()
	local design = Design.Current(section())
	local values = selected == "row" and design or design.parts[selected]
	window.inspectorTitle:SetText(titleOf(design, selected))
	window.updating = true
	for index, control in ipairs(window.controls) do
		local spec = controlsOf(design)[selected][index]
		local kind = spec and (KINDS[spec.key] or "number")
		control.spec, control.part, control.kind = spec, selected, kind
		control.value = spec and values[spec.key]
		-- Before the dropdown is shown: showing it builds its menu from them.
		control.choices = kind == "choice" and choices(spec.key, design, selected) or nil
		control.label:SetShown(spec ~= nil)
		control.check:SetShown(kind == "check")
		control.slider:SetShown(kind == "number")
		control.input:SetShown(kind == "number")
		control.choice:SetShown(kind == "choice")
		if spec then
			control.label:SetText(spec.label)
		end
		if kind == "check" then
			control.check:SetChecked(control.value)
		elseif kind == "number" then
			control.low, control.high = Design.Range(design, selected, spec.key)
			control.slider:Init(control.value, control.low, control.high, math.max(1, control.high - control.low))
			control.input:SetText(tostring(control.value))
		elseif kind == "choice" then
			control.choice:GenerateMenu()
		end
	end
	window.updating = false
end

-- A number typed into a control's field: taken within its range, or the value
-- shown before when it is not a number.
local function enter(control, text)
	local value = tonumber(text)
	if control.kind ~= "number" or not value then
		control.input:SetText(tostring(control.value or ""))
		return
	end
	value = math.min(math.max(math.floor(value + 0.5), control.low), control.high)
	if value ~= control.value then
		LookWindow.Change(control.part, control.spec.key, value)
	else
		control.input:SetText(tostring(value))
	end
end

-- Dragging a part: the pointer's distance since the drag began, in screen
-- pixels, becomes design pixels at the player's size.
local function startDrag(part)
	LookWindow.Select(part)
	local x, y = GetCursorPosition()
	drag = { x = x, y = y, move = Looks.Drag(edited, part, scale() * UIParent:GetEffectiveScale()) }
end

local function stopDrag()
	drag = nil
end

function LookWindow.OnUpdate()
	if drag then
		local x, y = GetCursorPosition()
		drag.move(x - drag.x, y - drag.y)
		LookWindow.Refresh()
	end
end

-- A gold frame, the mark of the chosen part; mark() places it.
local function createBorder(parent)
	local border = CreateFrame("Frame", nil, parent)
	border:SetFrameLevel(parent:GetFrameLevel() + 6)
	local edges = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
	for index, ends in ipairs(edges) do
		local edge = border:CreateTexture(nil, "OVERLAY")
		edge:SetColorTexture(1, 0.82, 0, 1)
		edge:SetPoint(ends[1])
		edge:SetPoint(ends[2])
		if index <= 2 then
			edge:SetHeight(2)
		else
			edge:SetWidth(2)
		end
	end
	border:Hide()
	return border
end

local function createHit(rowFrame, part)
	local hit = CreateFrame("Button", nil, rowFrame)
	hit:SetAllPoints(rowFrame[Frames.REGIONS[part]])
	hit:SetFrameLevel(rowFrame:GetFrameLevel() + 5)
	hit:RegisterForDrag("LeftButton")
	hit.Highlight = hit:CreateTexture(nil, "HIGHLIGHT")
	hit.Highlight:SetAllPoints()
	hit.Highlight:SetColorTexture(1, 1, 1, 0.15)
	hit:SetScript("OnClick", function()
		LookWindow.Select(partOf(part))
	end)
	hit:SetScript("OnDragStart", function()
		-- An Icons layout's icon stays where it is.
		if partOf(part) == part then
			startDrag(part)
		else
			LookWindow.Select(partOf(part))
		end
	end)
	hit:SetScript("OnDragStop", stopDrag)
	return hit
end

-- One line of the inspector: a label, and below it a checkbox, a dropdown or a
-- slider with a field; UpdateInspector shows the one the chosen part needs.
local function createControl(parent, index)
	local control = {}
	local y = -64 - (index - 1) * LookWindow.CONTROL_HEIGHT
	control.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	control.label:SetPoint("TOPLEFT", 12, y)

	control.check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	control.check:SetSize(26, 26)
	control.check:SetPoint("TOPLEFT", 8, y - 14)
	control.check:SetScript("OnClick", function(button)
		LookWindow.Change(control.part, control.spec.key, button:GetChecked() and true or false)
	end)

	control.slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
	control.slider:SetPoint("TOPLEFT", 12, y - 16)
	-- The template is 40 high with its bar in the middle; as high as the bar,
	-- it sits right under its label.
	control.slider:SetSize(180, 20)
	control.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not window.updating then
			LookWindow.Change(control.part, control.spec.key, math.floor(value + 0.5))
		end
	end, control)
	control.input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	control.input:SetSize(44, 20)
	control.input:SetPoint("LEFT", control.slider, "RIGHT", 14, 0)
	control.input:SetAutoFocus(false)
	control.input:SetMaxLetters(5)
	control.input:SetScript("OnEnterPressed", function(input)
		enter(control, input:GetText())
		input:ClearFocus()
	end)
	control.input:SetScript("OnEscapePressed", function(input)
		input:SetText(tostring(control.value or ""))
		input:ClearFocus()
	end)
	control.input:SetScript("OnEditFocusLost", function(input)
		input:HighlightText(0, 0)
		enter(control, input:GetText())
	end)

	control.choice = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	control.choice:SetPoint("TOPLEFT", 12, y - 16)
	control.choice:SetWidth(180)
	control.choice:SetupMenu(function(_, root)
		if control.kind == "choice" then
			for _, choice in ipairs(control.choices) do
				root:CreateRadio(choice[2], function(value)
					return control.value == value
				end, function(value)
					LookWindow.Change(control.part, control.spec.key, value)
				end, choice[1])
			end
		end
	end)
	return control
end


-- The Feed tab: one control per setting of the look, in its groups, laid
-- out from the top: a header, a checkbox with its label, or a label over a
-- slider (with the value beside it) or a dropdown. A setting with a parent
-- sits indented under it and can be changed only while the parent is on.
local SETTING_HEIGHT = { header = 30, checkbox = 28, slider = 46, dropdown = 50 }
local INDENT = 20

-- The choices a dropdown setting offers now: the directions follow the view.
local function settingChoices(key)
	for _, setting in ipairs(Looks.Settings(Looks.View(edited))) do
		if setting.key == key then
			return setting.choices or {}
		end
	end
	return {}
end

local function formatValue(setting, value)
	local format = setting.format or "%d"
	return format:format(value)
end

local function createSetting(parent, setting, y)
	local control = { setting = setting }
	local x = setting.parent and INDENT or 0
	if setting.kind == "header" then
		control.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		control.text:SetPoint("TOPLEFT", x, y - 6)
		control.text:SetText(setting.label)
		control.update = function() end
		return control
	end
	control.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if setting.kind == "checkbox" then
		control.check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		control.check:SetSize(26, 26)
		control.check:SetPoint("TOPLEFT", x, y)
		control.label:SetPoint("LEFT", control.check, "RIGHT", 4, 0)
		control.check:SetScript("OnClick", function(button)
			LookWindow.Set(setting.key, button:GetChecked() and true or false)
		end)
	elseif setting.kind == "slider" then
		control.label:SetPoint("TOPLEFT", x + 4, y)
		control.slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
		control.slider:SetPoint("TOPLEFT", x + 4, y - 16)
		control.slider:SetSize(220, 20)
		control.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		control.value:SetPoint("LEFT", control.slider, "RIGHT", 12, 0)
		control.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
			if not window.updating then
				LookWindow.Set(setting.key, Storage.OnStep(value, setting.min, setting.max, setting.step))
			end
		end, control)
	else
		control.label:SetPoint("TOPLEFT", x + 4, y)
		control.choice = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		control.choice:SetPoint("TOPLEFT", x + 4, y - 16)
		control.choice:SetWidth(220)
		control.choice:SetupMenu(function(_, root)
			for _, choice in ipairs(settingChoices(setting.key)) do
				root:CreateRadio(choice[2], function(value)
					return Looks.Value(edited, setting.key) == value
				end, function(value)
					LookWindow.Set(setting.key, value)
				end, choice[1])
			end
		end)
	end
	control.label:SetText(setting.label)
	control.update = function()
		local value = Looks.Value(edited, setting.key)
		local enabled = not setting.parent or Looks.Value(edited, setting.parent) == true
		control.label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
		if control.check then
			control.check:SetChecked(value)
			control.check:SetEnabled(enabled)
		elseif control.slider then
			control.slider:Init(value, setting.min, setting.max, math.floor((setting.max - setting.min) / setting.step + 0.5))
			control.slider:SetEnabled(enabled)
			control.value:SetText(formatValue(setting, value))
		else
			control.choice:SetEnabled(enabled)
			control.choice:GenerateMenu()
		end
	end
	return control
end

-- The Feed tab's controls, made once: the settings do not change, only
-- the directions a dropdown offers.
local function buildFeedTab(tab)
	local scroll = CreateFrame("ScrollFrame", nil, tab, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LookWindow.WIDTH - LookWindow.PREVIEW_WIDTH - 90, 10)
	scroll:SetScrollChild(content)
	local controls, y = {}, -4
	for _, setting in ipairs(Looks.Settings("icons")) do
		controls[#controls + 1] = createSetting(content, setting, y)
		y = y - SETTING_HEIGHT[setting.kind]
	end
	content:SetHeight(-y + 10)
	return controls
end

-- The Feed tab's values, from the look.
function LookWindow.UpdateFeed()
	window.updating = true
	for _, control in ipairs(window.settings) do
		control.update()
	end
	window.updating = false
end

local function build()
	local frame = CreateFrame("Frame", LookWindow.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:SetSize(LookWindow.WIDTH, LookWindow.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnUpdate", LookWindow.OnUpdate)
	frame:SetScript("OnHide", stopDrag)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows: Blizzard's secure
	-- code hides the frames named in UISpecialFrames. (Registering a handler
	-- with RegisterGameMenuEscHandler would re-sort Blizzard's list from
	-- Lootoman's code and taint the game menu, which then cannot stop a cast.)
	table.insert(UISpecialFrames, LookWindow.NAME)

	frame.reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reset:SetPoint("TOPLEFT", 20, -32)
	frame.reset:SetSize(100, 22)
	frame.reset:SetText(L["Reset"])
	frame.reset:SetScript("OnClick", function()
		LookWindow.Reset()
	end)
	frame.share = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.share:SetPoint("LEFT", frame.reset, "RIGHT", 8, 0)
	frame.share:SetSize(100, 22)
	frame.share:SetText(L["Share"])
	frame.share:SetEnabled(Compat.CanEncode())
	frame.share:SetScript("OnClick", function()
		Bus:Send("OpenShareDialog", "looks", edited)
	end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 14)
	hint:SetText(L["Click a part to choose it, drag it to move it."])

	frame.preview = CreateFrame("Frame", nil, frame)
	frame.preview:SetPoint("TOPLEFT", 16, -64)
	frame.preview:SetSize(LookWindow.PREVIEW_WIDTH, LookWindow.HEIGHT - 100)
	-- A wide row is cut off at the preview's edge.
	frame.preview:SetClipsChildren(true)
	local previewBackground = frame.preview:CreateTexture(nil, "BACKGROUND")
	previewBackground:SetAllPoints()
	previewBackground:SetColorTexture(0, 0, 0, 0.6)
	frame.preview:EnableMouse(true)
	frame.preview:SetScript("OnMouseDown", function()
		LookWindow.Select("row")
	end)
	frame.samples = Frames.PreviewRows()
	frame.rows = {}
	for index = 1, #frame.samples do
		local rowFrame = Frames.CreateRow(frame.preview)
		-- The row's box: the space its parts are placed in.
		rowFrame.Box = rowFrame:CreateTexture(nil, "BACKGROUND")
		rowFrame.Box:SetAllPoints()
		rowFrame.Box:SetColorTexture(1, 1, 1, 0.12)
		rowFrame.Selected = createBorder(rowFrame)
		-- A click on the row's free space chooses the row; the feed's rows only
		-- take the mouse for tooltips.
		rowFrame:SetMouseClickEnabled(true)
		rowFrame:SetScript("OnMouseDown", function()
			LookWindow.Select("row")
		end)
		rowFrame.hits = {}
		for part in pairs(Frames.REGIONS) do
			rowFrame.hits[part] = createHit(rowFrame, part)
		end
		frame.rows[index] = rowFrame
	end

	-- The tabs, over the right side.
	for id, text in ipairs({ L["Feed"], L["Row design"] }) do
		local tab = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate")
		tab:SetID(id)
		tab:SetText(text)
		tab:SetPoint("BOTTOMLEFT", frame.preview, "TOPRIGHT", 16 + (id - 1) * 120, 2)
		tab:SetScript("OnClick", function()
			LookWindow.ShowTab(id)
		end)
		frame["tab" .. id] = tab
	end
	PanelTemplates_SetNumTabs(frame, 2)

	frame.feedTab = CreateFrame("Frame", nil, frame)
	frame.feedTab:SetPoint("TOPLEFT", frame.preview, "TOPRIGHT", 16, 0)
	frame.feedTab:SetPoint("BOTTOMRIGHT", -16, 36)
	frame.settings = buildFeedTab(frame.feedTab)

	local inspector = CreateFrame("Frame", nil, frame)
	inspector:SetPoint("TOPLEFT", frame.preview, "TOPRIGHT", 16, 0)
	inspector:SetPoint("BOTTOMRIGHT", -16, 36)
	frame.designTab = inspector
	local viewLabel = inspector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	viewLabel:SetPoint("TOPLEFT", 12, -2)
	viewLabel:SetText(L["View:"])
	frame.view = CreateFrame("DropdownButton", nil, inspector, "WowStyle1DropdownTemplate")
	frame.view:SetPoint("LEFT", viewLabel, "RIGHT", 8, 0)
	frame.view:SetWidth(120)
	frame.view:SetupMenu(function(_, root)
		for _, view in ipairs({ { "rows", L["Rows"] }, { "icons", L["Icons"] } }) do
			root:CreateRadio(view[2], function(value)
				return Looks.View(edited) == value
			end, LookWindow.SetView, view[1])
		end
	end)
	local partLabel = inspector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	partLabel:SetPoint("LEFT", frame.view, "RIGHT", 16, 0)
	partLabel:SetText(L["Part:"])
	frame.parts = CreateFrame("DropdownButton", nil, inspector, "WowStyle1DropdownTemplate")
	frame.parts:SetPoint("LEFT", partLabel, "RIGHT", 8, 0)
	frame.parts:SetWidth(130)
	frame.parts:SetupMenu(function(_, root)
		local design = Design.Current(section())
		for _, part in ipairs(partsOf(design)) do
			root:CreateRadio(titleOf(design, part), function()
				return selected == part
			end, LookWindow.Select, part)
		end
	end)
	frame.inspectorTitle = inspector:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.inspectorTitle:SetPoint("TOPRIGHT", -12, -36)
	frame.controls = {}
	for index = 1, CONTROL_COUNT do
		frame.controls[index] = createControl(inspector, index)
	end

	-- The look changes elsewhere too: in a menu, an import, a rename.
	local function refreshShown()
		if frame:IsShown() then
			LookWindow.Refresh()
		end
	end
	Bus:On("FeedLookChanged", LookWindow, function(_, name)
		if name == edited then
			refreshShown()
		end
	end)
	Bus:On("FeedLookRenamed", LookWindow, function(_, old, new)
		if old == edited then
			edited = new
			refreshShown()
		end
	end)
	frame.tab = LookWindow.FEED
	return frame
end

-- Opens the window on a look (the profile's, without one); it is built the
-- first time, which waits for the end of combat.
function LookWindow.Open(name)
	if not window then
		if Compat.InCombat() then
			ns.Print(L["The look window opens out of combat."])
			return false
		end
		window = build()
		LookWindow.window = window
	end
	edited = Looks.Get(name) and name or Looks.Current()
	window:Show()
	LookWindow.ShowTab(window.tab)
	LookWindow.Refresh()
	return true
end

-- The look the window edits.
function LookWindow.Edited()
	return edited
end

function LookWindow.Toggle()
	if window and window:IsShown() then
		window:Hide()
	else
		LookWindow.Open()
	end
end

ns.Slash.Register("design", LookWindow.Toggle, L["/lootoman design: open the window of the loot feed's look"])
