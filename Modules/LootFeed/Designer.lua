local _, ns = ...
local Compat, L = ns.Compat, ns.L
local Feed = ns.Feed

-- The row designer (plans/0.1.md, task 14, C40), in the spirit of Platynator's
-- nameplate designer: sample rows of every kind, drawn by the feed's own code
-- at the player's size, each in its box: the row's height and width. Click a
-- part to choose it, drag it to move it on the grid; a gold frame marks the
-- chosen part (for a text, the most room it may take), or the row when no part
-- is chosen. The inspector changes the
-- chosen one: what it is anchored to and where, its size, alignment and
-- offsets. Numbers have a slider and a field to type them in; both only go as
-- far as the row's box allows (Design.Range). A built-in design can be chosen
-- to start from, and Reset drops the player's changes to it. Every change is
-- saved in the profile and the feed follows at once.
--
-- The window is the player's own frame, built the first time it opens, never
-- in combat; Escape and its close button hide it.
local LootFeed = ns.Modules:Get("LootFeed")
local Design, Frames = Feed.Design, Feed.Frames

local Designer = {}
LootFeed.Designer = Designer

Designer.WIDTH = 760
Designer.HEIGHT = 580
Designer.PREVIEW_WIDTH = 440
-- The inspector's controls are this far apart; each one's label is nearer to
-- it than to the one before.
Designer.CONTROL_HEIGHT = 52

local NAMES = { large = L["Large"], compact = L["Compact"], minimal = L["Minimal"] }
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
	amount = TEXT_CONTROLS,
	owned = TEXT_CONTROLS,
}
-- A checkbox for shown, a dropdown for a choice, else a slider with a field.
local KINDS = { shown = "check", anchor = "choice", point = "choice", align = "choice" }
local CONTROL_COUNT = #TEXT_CONTROLS

local window
local selected = "row"
local drag

local function section()
	return LootFeed:DesignSection()
end

local function scale()
	return LootFeed:Get("size") / Design.BASE_SIZE
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

-- After any change: the preview, the inspector and the feed itself.
function Designer.Refresh()
	if not window then
		return
	end
	local layout = Design.Layout(Design.Current(section()), LootFeed:Get("size"))
	local options = { layout = layout, showOwned = LootFeed:Get("owned"), showGlow = LootFeed:Get("glow") }
	local top = 0
	for index, rowFrame in ipairs(window.rows) do
		Frames.ApplyLayout(rowFrame, layout)
		Frames.Fill(rowFrame, window.samples[index].row, options)
		rowFrame:ClearAllPoints()
		rowFrame:SetPoint("TOPLEFT", window.preview, "TOPLEFT", 12, -12 - top)
		rowFrame:Show()
		top = top + layout.height + layout.gap
		rowFrame.Box:SetAlpha(selected == "row" and 1 or 0.5)
		mark(rowFrame, layout)
		for part, hit in pairs(rowFrame.hits) do
			hit:SetShown(rowFrame[Frames.REGIONS[part]]:IsShown())
		end
	end
	Designer.UpdateInspector()
	window.designs:GenerateMenu()
	window.parts:GenerateMenu()
	if LootFeed:IsActive() then
		LootFeed:Apply()
	end
end

-- Changes one value of a part (from the inspector).
function Designer.Change(part, key, value)
	Design.Set(section(), part, key, value)
	Designer.Refresh()
end

function Designer.Select(part)
	selected = part
	Designer.Refresh()
end

function Designer.Choose(name)
	Design.Choose(section(), name)
	Designer.Refresh()
end

function Designer.Reset()
	Design.Reset(section())
	Designer.Refresh()
end

-- The inspector's title and controls for the chosen part, with its values.
function Designer.UpdateInspector()
	local design = Design.Current(section())
	local values = selected == "row" and design or design.parts[selected]
	window.inspectorTitle:SetText(TITLES[selected])
	window.updating = true
	for index, control in ipairs(window.controls) do
		local spec = CONTROLS[selected][index]
		local kind = spec and (KINDS[spec.key] or "number")
		control.spec, control.part, control.kind = spec, selected, kind
		control.value = spec and values[spec.key]
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
			control.choices = choices(spec.key, design, selected)
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
		Designer.Change(control.part, control.spec.key, value)
	else
		control.input:SetText(tostring(value))
	end
end

-- Dragging a part: the pointer's distance since the drag began, in screen
-- pixels, becomes design pixels at the player's size.
local function startDrag(part)
	Designer.Select(part)
	local x, y = GetCursorPosition()
	drag = { x = x, y = y, move = Design.Drag(section(), part, scale() * UIParent:GetEffectiveScale()) }
end

local function stopDrag()
	drag = nil
end

function Designer.OnUpdate()
	if drag then
		local x, y = GetCursorPosition()
		drag.move(x - drag.x, y - drag.y)
		Designer.Refresh()
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
		Designer.Select(part)
	end)
	hit:SetScript("OnDragStart", function()
		startDrag(part)
	end)
	hit:SetScript("OnDragStop", stopDrag)
	return hit
end

-- One line of the inspector: a label, and below it a checkbox, a dropdown or a
-- slider with a field; UpdateInspector shows the one the chosen part needs.
local function createControl(parent, index)
	local control = {}
	local y = -40 - (index - 1) * Designer.CONTROL_HEIGHT
	control.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	control.label:SetPoint("TOPLEFT", 12, y)

	control.check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	control.check:SetSize(26, 26)
	control.check:SetPoint("TOPLEFT", 8, y - 14)
	control.check:SetScript("OnClick", function(button)
		Designer.Change(control.part, control.spec.key, button:GetChecked() and true or false)
	end)

	control.slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
	control.slider:SetPoint("TOPLEFT", 12, y - 16)
	-- The template is 40 high with its bar in the middle; as high as the bar,
	-- it sits right under its label.
	control.slider:SetSize(180, 20)
	control.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not window.updating then
			Designer.Change(control.part, control.spec.key, math.floor(value + 0.5))
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
					Designer.Change(control.part, control.spec.key, value)
				end, choice[1])
			end
		end
	end)
	return control
end

local function build()
	local frame = CreateFrame("Frame", nil, UIParent, "DefaultPanelFlatTemplate")
	frame:SetSize(Designer.WIDTH, Designer.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetTitle(L["Loot feed design"])
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnUpdate", Designer.OnUpdate)
	frame:SetScript("OnHide", stopDrag)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	if RegisterGameMenuEscHandler then
		RegisterGameMenuEscHandler(GameMenuEscPriority.AddOn, function()
			if frame:IsShown() then
				frame:Hide()
				return true
			end
			return false
		end)
	end

	local startLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	startLabel:SetPoint("TOPLEFT", 20, -36)
	startLabel:SetText(L["Start from:"])
	frame.designs = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.designs:SetPoint("LEFT", startLabel, "RIGHT", 8, 0)
	frame.designs:SetWidth(150)
	frame.designs:SetupMenu(function(_, root)
		for _, name in ipairs(Design.ORDER) do
			root:CreateRadio(NAMES[name], function()
				return (section().base or "large") == name
			end, Designer.Choose, name)
		end
	end)
	local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	reset:SetPoint("LEFT", frame.designs, "RIGHT", 8, 0)
	reset:SetSize(100, 22)
	reset:SetText(L["Reset"])
	reset:SetScript("OnClick", Designer.Reset)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 14)
	hint:SetText(L["Click a part to choose it, drag it to move it."])

	frame.preview = CreateFrame("Frame", nil, frame)
	frame.preview:SetPoint("TOPLEFT", 16, -64)
	frame.preview:SetSize(Designer.PREVIEW_WIDTH, Designer.HEIGHT - 100)
	-- A wide row is cut off at the preview's edge.
	frame.preview:SetClipsChildren(true)
	local previewBackground = frame.preview:CreateTexture(nil, "BACKGROUND")
	previewBackground:SetAllPoints()
	previewBackground:SetColorTexture(0, 0, 0, 0.6)
	frame.preview:EnableMouse(true)
	frame.preview:SetScript("OnMouseDown", function()
		Designer.Select("row")
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
			Designer.Select("row")
		end)
		rowFrame.hits = {}
		for part in pairs(Frames.REGIONS) do
			rowFrame.hits[part] = createHit(rowFrame, part)
		end
		frame.rows[index] = rowFrame
	end

	local inspector = CreateFrame("Frame", nil, frame)
	inspector:SetPoint("TOPLEFT", frame.preview, "TOPRIGHT", 16, 0)
	inspector:SetPoint("BOTTOMRIGHT", -16, 36)
	local partLabel = inspector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	partLabel:SetPoint("TOPLEFT", 12, -2)
	partLabel:SetText(L["Part:"])
	frame.parts = CreateFrame("DropdownButton", nil, inspector, "WowStyle1DropdownTemplate")
	frame.parts:SetPoint("LEFT", partLabel, "RIGHT", 8, 0)
	frame.parts:SetWidth(150)
	frame.parts:SetupMenu(function(_, root)
		for _, part in ipairs(PART_ORDER) do
			root:CreateRadio(TITLES[part], function()
				return selected == part
			end, Designer.Select, part)
		end
	end)
	frame.inspectorTitle = inspector:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.inspectorTitle:SetPoint("TOPRIGHT", -12, -4)
	frame.controls = {}
	for index = 1, CONTROL_COUNT do
		frame.controls[index] = createControl(inspector, index)
	end
	return frame
end

-- Opens the designer; it is built the first time, which waits for the end of combat.
function Designer.Open()
	if not window then
		if Compat.InCombat() then
			ns.Print(L["The designer opens out of combat."])
			return false
		end
		window = build()
		Designer.window = window
	end
	window:Show()
	Designer.Refresh()
	return true
end

function Designer.Toggle()
	if window and window:IsShown() then
		window:Hide()
	else
		Designer.Open()
	end
end

ns.Slash.Register("design", Designer.Toggle, L["/lootoman design: open the loot feed's row designer"])
