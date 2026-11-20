local _, ns = ...
local Bus, Compat, Modules, Storage, Text = ns.Bus, ns.Compat, ns.Modules, ns.Storage, ns.Text

-- The addon's page in the game options, registered with Blizzard's Settings
-- API on Ready. It has no subpages: what does not fit is in the addon's own
-- windows (a feed look's, the junk list).
--
-- The page is the addon's own frame (a canvas page), laid out the way a
-- player reads it: the title, what other Settings files put on top with
-- Panel.AddToMain (the profile), a divider, then every module's block: its
-- switch, a checkbox with its label after it, or its title for a module
-- without one. Under it, indented: the module's main settings
-- (module.mainSettings), which can be changed only while the module is on,
-- and notes: short texts that say more about the switch or setting above.
-- The page reads Storage again when it is shown and whenever a value or the
-- profile changes.
local Panel = {
	mainBuilders = {},
}
ns.SettingsPanel = Panel

-- builder(page) adds controls to the top of the main page (MainPage below).
function Panel.AddToMain(builder)
	Panel.mainBuilders[#Panel.mainBuilders + 1] = builder
end

-- The main page's layout: everything starts this far from the left edge;
-- options under a switch start further in; a row's control starts at CONTROL_X.
Panel.LEFT = 20
Panel.INDENT = 24
Panel.CONTROL_X = 260
-- A checkbox's size (SettingsCheckboxTemplate), and where its label starts,
-- after it and a little room.
Panel.CHECKBOX_WIDTH = 30
Panel.CHECKBOX_HEIGHT = 29
Panel.LABEL_X = 34
-- The room the page's scroll bar takes on the right.
Panel.SCROLL_BAR = 26
-- The size of the page's dropdowns but the profile's: room for the longest
-- choice, in Russian too.
Panel.DROPDOWN_WIDTH = 260
Panel.DROPDOWN_HEIGHT = 30
local GAP = 6

-- The main page, built from top to bottom: every Add puts an item under the
-- last one. An item can be hidden (options.visible): the page lays its items
-- out again whenever it refreshes. items lists what was added, in order, for
-- tests. The title and the head under it (the profile and its divider) stay
-- on top; everything under them is in body, which scrolls when the page is
-- taller than the panel. page.area says where the next items go: "head" or
-- "body" (the default).
local MainPage = {}
MainPage.__index = MainPage

local function newMainPage()
	local frame = CreateFrame("Frame")
	frame:Hide()
	local page = setmetatable({ frame = frame, items = {}, refreshers = {}, openers = {} }, MainPage)
	-- The header of the options panel's own pages (Blizzard_SettingsList.xml).
	page.title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	page.title:SetJustifyH("LEFT")
	page.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
	page.title:SetText("Lootoman")
	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOP", frame, "TOP", 0, -50)
	-- Under the head, the scrolling part (placed by Layout); its bar sits in
	-- the room on the right.
	page.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	page.body = CreateFrame("Frame", nil, page.scroll)
	page.body:SetSize(1, 1)
	page.scroll:SetScrollChild(page.body)
	-- A wrapped text's height depends on the width: lay out again when it changes.
	page.scroll:SetScript("OnSizeChanged", function(_, width)
		if width ~= page.width then
			page.width = width
			page.body:SetWidth(width)
			page:Layout()
		end
	end)
	page.top = -56
	page.area = "body"
	-- The options panel calls it whenever it shows the page: as the window
	-- opens on it, and as the player comes back from another options page.
	function frame.OnRefresh()
		for _, open in ipairs(page.openers) do
			xpcall(open, Compat.ReportError)
		end
		page:Refresh()
	end
	return page
end

-- The frame the next items are made in: the page itself for the head, the
-- scrolling body for the rest.
function MainPage:Area()
	return self.area == "head" and self.frame or self.body
end

-- Places the shown items of one area under each other in container, from y
-- down; returns where they end.
local function place(page, area, container, y)
	for _, item in ipairs(page.items) do
		if item.area == area then
			local frame = item.frame
			local shown = item.visible == nil or item.visible()
			item.hidden = not shown
			if not shown then
				frame:Hide()
			elseif item.kind == "divider" then
				y = y - 12
				frame:ClearAllPoints()
				frame:SetPoint("TOP", container, "TOP", 0, y)
				frame:Show()
				y = y - 6
			else
				y = y - item.gap
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", container, "TOPLEFT", Panel.LEFT + item.indent, y)
				if item.wide then
					frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", -Panel.LEFT, y)
					-- Once its width is known, an item that wraps text measures itself.
					if item.measure then
						item.height = item.measure()
					end
					frame:SetHeight(item.height)
				end
				frame:Show()
				y = y - item.height
			end
		end
	end
	return y
end

-- Places every shown item under the one before it: the head under the
-- title, the scrolling part under the head, the body's items in it.
function MainPage:Layout()
	local head = place(self, "head", self.frame, self.top)
	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, head)
	self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -Panel.SCROLL_BAR, 4)
	self.head = head
	local y = place(self, "body", self.body, 0)
	self.y = y
	-- As tall as what it holds, and a little room at the bottom.
	self.body:SetHeight(-y + 12)
end

-- Puts a region gap pixels under the last item, indent pixels further in.
-- options.frame is placed instead of the region when it holds the region; a
-- wide one reaches to the page's right edge, and measure(), when given, gives
-- its height at each layout; visible(), when given, says whether it shows now.
function MainPage:Add(kind, region, height, options)
	options = options or {}
	self.items[#self.items + 1] = {
		kind = kind,
		region = region,
		frame = options.frame or region,
		height = height,
		gap = options.gap or GAP,
		indent = options.indent or 0,
		wide = options.wide,
		measure = options.measure,
		text = options.text,
		visible = options.visible,
		area = self.area,
	}
	self:Layout()
	return region
end

function MainPage:AddDivider()
	local divider = self:Area():CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	return self:Add("divider", divider, 0, { gap = 0 })
end

-- update() runs whenever the page should show the stored values again.
function MainPage:OnRefresh(update)
	self.refreshers[#self.refreshers + 1] = update
end

-- open() runs whenever the options window shows the page (it was closed, or
-- on another page), before the page refreshes.
function MainPage:OnOpen(open)
	self.openers[#self.openers + 1] = open
end

function MainPage:Refresh()
	for _, update in ipairs(self.refreshers) do
		xpcall(update, Compat.ReportError)
	end
	self:Layout()
end

-- Whether a control can be changed now: while its module is on (requires),
-- and while its own condition holds (enabledWhen).
local function enabled(requires, enabledWhen)
	return (requires == nil or Storage:Get(requires, "enabled")) and (enabledWhen == nil or enabledWhen())
end

local function setTextEnabled(text, isEnabled, font, disabledFont)
	text:SetFontObject(isEnabled and (font or "GameFontNormal") or (disabledFont or "GameFontDisable"))
end

-- A tooltip in the options panel's own style while the pointer is over a frame.
local function addTooltip(frame, title, text)
	if not text then
		return
	end
	frame:HookScript("OnEnter", function(owner)
		SettingsTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		Settings.InitTooltip(title, text)
		SettingsTooltip:Show()
	end)
	frame:HookScript("OnLeave", function()
		SettingsTooltip:Hide()
	end)
end

-- A checkbox in the options panel's own style with its label after it, in
-- parent, bound to a boolean module setting; with a note, a short white text
-- under the label that says more. With requires, it can be changed only while
-- that module is on; with enabledWhen, only while that says so.
-- The template's hover background fills the checkbox's parent, from 10 pixels
-- left of it to 5 pixels short of its right edge (HoverBackgroundTemplate):
-- only the parent lights up, the note with it. The checkbox's hit rect covers
-- the same: the label, the note and the empty space light up and toggle it.
local function newCheckbox(page, parent, module, key, label, tooltip, requires, enabledWhen, note)
	local row = parent
	local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
	checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", checkbox, "RIGHT", Panel.LABEL_X - Panel.CHECKBOX_WIDTH, 0)
	text:SetText(label)
	checkbox.label = text
	if note then
		checkbox.note = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		checkbox.note:SetJustifyH("LEFT")
		checkbox.note:SetPoint("TOPLEFT", row, "TOPLEFT", Panel.LABEL_X, -Panel.CHECKBOX_HEIGHT)
		checkbox.note:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -Panel.CHECKBOX_HEIGHT)
		checkbox.note:SetText(note)
	end
	local function fitHitRect()
		local width, height = row:GetWidth() or 0, row:GetHeight() or 0
		checkbox:SetHitRectInsets(-10, math.min(0, Panel.CHECKBOX_WIDTH + 5 - width), 0, math.min(0, Panel.CHECKBOX_HEIGHT - height))
	end
	row:SetScript("OnSizeChanged", fitHitRect)
	fitHitRect()
	checkbox:SetTooltipFunc(function()
		Settings.InitTooltip(label, tooltip)
	end)
	checkbox:SetScript("OnClick", function(button)
		Storage:Set(module, key, button:GetChecked() and true or false)
	end)
	page:OnRefresh(function()
		checkbox:SetChecked(Storage:Get(module, key))
		local isEnabled = enabled(requires, enabledWhen)
		checkbox:SetEnabled(isEnabled)
		setTextEnabled(text, isEnabled)
		if checkbox.note then
			setTextEnabled(checkbox.note, isEnabled, "GameFontHighlightSmall", "GameFontDisableSmall")
		end
	end)
	return checkbox
end

-- A checkbox (newCheckbox) in a row of its own, as on the panel's list pages;
-- gap, the room above it, for a group of its own; note, a text under it. The
-- row is as tall as the checkbox and the note's lines, measured again at each
-- layout.
function MainPage:AddCheckbox(module, key, label, tooltip, indent, requires, enabledWhen, gap, note)
	local row = CreateFrame("Frame", nil, self:Area())
	local checkbox = newCheckbox(self, row, module, key, label, tooltip, requires, enabledWhen, note)
	local measure
	if checkbox.note then
		measure = function()
			return Panel.CHECKBOX_HEIGHT + math.ceil(checkbox.note:GetStringHeight()) + 4
		end
	end
	return self:Add("checkbox", checkbox, Panel.CHECKBOX_HEIGHT, { indent = indent, text = label, frame = row, wide = true, gap = gap,
		measure = measure })
end

-- Checkboxes side by side, columns of them to a row: the first at the left,
-- the next at the rows' control column (CONTROL_X), each in a cell of its own
-- so only its cell lights up. items: { { key, label, tooltip }, … }; options:
-- indent, requires, enabledWhen, columns (2). Each row is one item, its text
-- the labels joined by "|".
function MainPage:AddCheckboxes(module, items, options)
	options = options or {}
	local columns = options.columns or 2
	local indent = options.indent or 0
	local column = Panel.CONTROL_X - Panel.LEFT - indent
	for first = 1, #items, columns do
		local row = CreateFrame("Frame", nil, self:Area())
		row.cells = {}
		local labels = {}
		for index = 0, columns - 1 do
			local item = items[first + index]
			if item then
				local cell = CreateFrame("Frame", nil, row)
				cell:SetPoint("TOPLEFT", row, "TOPLEFT", index * column, 0)
				if index < columns - 1 then
					cell:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", (index + 1) * column, 0)
				else
					cell:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
				end
				cell.checkbox = newCheckbox(self, cell, module, item.key, item.label, item.tooltip, options.requires, options.enabledWhen)
				row.cells[#row.cells + 1] = cell
				labels[#labels + 1] = item.label
			end
		end
		self:Add("checkboxes", row, 29, { indent = indent, text = table.concat(labels, "|"), wide = true })
	end
end

-- A dropdown for the page, as the Edit Mode dialogs show them (the feed look's
-- is in both); only the profile's has the options panel's own style.
function MainPage:NewDropdown(parent)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dropdown:SetSize(Panel.DROPDOWN_WIDTH, Panel.DROPDOWN_HEIGHT)
	return dropdown
end

-- A choice of a module setting: its label, then a dropdown (NewDropdown)
-- with a radio for each choice ({ value, label }). options: indent, gap,
-- requires, enabledWhen, tooltip. Returns the dropdown.
function MainPage:AddChoice(module, key, label, choices, options)
	options = options or {}
	local row = self:NewRow()
	local dropdown = self:NewDropdown(row)
	dropdown:SetupMenu(function(_, root)
		for _, choice in ipairs(choices) do
			root:CreateRadio(choice[2], function(value)
				return Storage:Get(module, key) == value
			end, function(value)
				Storage:Set(module, key, value)
			end, choice[1])
		end
	end)
	self:AddRow(label, dropdown, { indent = options.indent, gap = options.gap, height = Panel.DROPDOWN_HEIGHT, tooltip = options.tooltip,
		kind = "choice" })
	self:OnRefresh(function()
		local isEnabled = enabled(options.requires, options.enabledWhen)
		setTextEnabled(row.label, isEnabled)
		dropdown:SetEnabled(isEnabled)
		dropdown:GenerateMenu()
	end)
	return dropdown
end

-- The value after a slider, as wide as "100 %", so it does not jump while
-- it changes.
Panel.SLIDER_VALUE_WIDTH = 48

-- The game's slider with steppers for a number setting, in row, with its
-- value after it; labelOf() gives the label to grey with it. spec: min, max,
-- step and format (a format string or a function of the value; "%d" by
-- default). A value out of range or off a step shows as the nearest one.
-- options: requires, enabledWhen. Returns the slider and its value.
local function newSlider(page, row, module, key, spec, options, labelOf)
	local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(Panel.DROPDOWN_WIDTH - 50, 20)
	local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	value:SetWidth(Panel.SLIDER_VALUE_WIDTH)
	value:SetJustifyH("LEFT")
	slider.valueLabel = value
	-- Showing the stored value moves the slider too: not a change of the player's.
	local updating = false
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, number)
		if not updating then
			Storage:Set(module, key, Storage.OnStep(number, spec.min, spec.max, spec.step))
		end
	end, slider)
	local format = spec.format or "%d"
	page:OnRefresh(function()
		local current = Storage.OnStep(tonumber(Storage:Get(module, key)) or spec.min, spec.min, spec.max, spec.step)
		local isEnabled = enabled(options.requires, options.enabledWhen)
		updating = true
		slider:Init(current, spec.min, spec.max, math.floor((spec.max - spec.min) / spec.step + 0.5))
		updating = false
		slider:SetEnabled(isEnabled)
		value:SetText(type(format) == "function" and format(current) or format:format(current))
		setTextEnabled(labelOf(), isEnabled)
		setTextEnabled(value, isEnabled, "GameFontHighlight")
	end)
	return slider, value
end

-- The game's colour swatch for a colour setting kept as "rrggbb", in row;
-- labelOf() gives the label to grey with it. A click opens the game's colour
-- picker; each colour picked is saved at once, and Cancel puts the one before
-- back. options: requires, enabledWhen. Returns the swatch.
local function newColor(page, row, module, key, options, labelOf)
	local swatch = CreateFrame("Button", nil, row, "ColorSwatchTemplate")
	local function save(r, g, b)
		Storage:Set(module, key, Text.Hex(r, g, b))
	end
	swatch:SetScript("OnClick", function()
		if not ColorPickerFrame then
			return
		end
		local r, g, b = Text.RGB(Storage:Get(module, key))
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r,
			g = g,
			b = b,
			swatchFunc = function()
				save(ColorPickerFrame:GetColorRGB())
			end,
			cancelFunc = function(previous)
				save(previous.r, previous.g, previous.b)
			end,
		})
	end)
	page:OnRefresh(function()
		local isEnabled = enabled(options.requires, options.enabledWhen)
		swatch:SetColorRGB(Text.RGB(Storage:Get(module, key)))
		swatch:SetEnabled(isEnabled)
		swatch:SetAlpha(isEnabled and 1 or 0.4)
		setTextEnabled(labelOf(), isEnabled)
	end)
	return swatch
end

-- A number setting on a row of its own: its label, then a slider (newSlider)
-- at the control column. options: indent, gap, requires, enabledWhen,
-- tooltip. Returns the slider.
function MainPage:AddSlider(module, key, label, spec, options)
	options = options or {}
	local row = self:NewRow()
	local slider = newSlider(self, row, module, key, spec, options, function()
		return row.label
	end)
	self:AddRow(label, slider, { indent = options.indent, gap = options.gap, height = Panel.DROPDOWN_HEIGHT, tooltip = options.tooltip,
		kind = "slider" })
	return slider
end

-- A colour setting on a row of its own: its label, then a swatch (newColor)
-- at the control column. options: indent, gap, requires, enabledWhen,
-- tooltip. Returns the swatch.
function MainPage:AddColor(module, key, label, options)
	options = options or {}
	local row = self:NewRow()
	local swatch = newColor(self, row, module, key, options, function()
		return row.label
	end)
	self:AddRow(label, swatch, { indent = options.indent, gap = options.gap, height = 26, tooltip = options.tooltip, kind = "color" })
	return swatch
end

-- A heading over a group of a module's settings, in the font of the
-- checkboxes' labels, greyed with its module (requires). options: indent,
-- gap, requires.
function MainPage:AddHeading(text, options)
	options = options or {}
	local heading = self:Area():CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heading:SetJustifyH("LEFT")
	heading:SetText(text)
	if options.requires then
		self:OnRefresh(function()
			setTextEnabled(heading, enabled(options.requires))
		end)
	end
	return self:Add("heading", heading, 18, { indent = options.indent, text = text, gap = options.gap })
end

-- A button with text, which runs onClick. options: indent, requires,
-- enabledWhen, tooltip.
function MainPage:AddButton(text, onClick, options)
	options = options or {}
	local button = CreateFrame("Button", nil, self:Area(), "UIPanelButtonTemplate")
	button:SetText(text)
	-- As wide as its text, and at least as wide as the options' own buttons.
	button:SetSize(math.max(120, (button.GetTextWidth and button:GetTextWidth() or 0) + 24), 22)
	button:SetScript("OnClick", onClick)
	addTooltip(button, text, options.tooltip)
	if options.requires or options.enabledWhen then
		self:OnRefresh(function()
			button:SetEnabled(enabled(options.requires, options.enabledWhen))
		end)
	end
	return self:Add("button", button, 22, { indent = options.indent, text = text, gap = options.gap or 4,
		visible = options.visible })
end

-- A row with a label on the left and a control (made by the caller, a child
-- of the row) at CONTROL_X. options: indent, gap, height, tooltip, visible, and
-- kind for the page's list of items ("row" by default). Returns the row;
-- control is placed in it.
function MainPage:AddRow(label, control, options)
	options = options or {}
	local row = control:GetParent()
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", row, "LEFT", 0, 0)
	text:SetText(label)
	row.label = text
	control:ClearAllPoints()
	control:SetPoint("LEFT", row, "LEFT", Panel.CONTROL_X - Panel.LEFT - (options.indent or 0), 0)
	addTooltip(control, label, options.tooltip)
	return self:Add(options.kind or "row", row, options.height or 26, { indent = options.indent, text = label, wide = true,
		visible = options.visible, gap = options.gap })
end

-- A frame for a row's control: make the control a child of it, then AddRow.
function MainPage:NewRow()
	return CreateFrame("Frame", nil, self:Area())
end

-- A framed group with a header on top, height high in all: the caller puts
-- its content inside, under box.header. options: indent, visible, headerFont.
function MainPage:AddBox(header, height, options)
	options = options or {}
	local box = CreateFrame("Frame", nil, self:Area(), "InsetFrameTemplate")
	box.header = box:CreateFontString(nil, "ARTWORK", options.headerFont or "GameFontNormal")
	box.header:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
	box.header:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -8)
	box.header:SetJustifyH("LEFT")
	box.header:SetText(header)
	return self:Add("box", box, height, { indent = options.indent, text = header, wide = true, visible = options.visible, gap = 8 })
end

-- A button on a module's switch row, at the control column (switchButton =
-- { label, tooltip, onClick } or, for a secure macro, { label, tooltip,
-- macro, preClick }), enabled while the module is on. A macro button is
-- the game's secure action button: on the player's click the game runs the
-- macro itself (a slash command of its own, untainted). It can only be made
-- and changed out of combat: made in a fight, the page goes without it.
local function addSwitchButton(page, check, module)
	local spec = module.switchButton
	if spec.macro and Compat.InCombat() then
		return
	end
	local row = check:GetParent()
	local button = CreateFrame("Button", nil, row, spec.macro and "SecureActionButtonTemplate, UIPanelButtonTemplate" or "UIPanelButtonTemplate")
	button:SetSize(120, 22)
	button:SetPoint("TOPLEFT", row, "TOPLEFT", Panel.CONTROL_X - Panel.LEFT, -1)
	-- Above the checkbox's hit area, which spans the row.
	button:SetFrameLevel(check:GetFrameLevel() + 2)
	button:SetText(spec.label)
	if spec.macro then
		button:RegisterForClicks("AnyUp", "AnyDown")
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", spec.macro)
		if spec.preClick then
			button:HookScript("PreClick", spec.preClick)
		end
	else
		button:SetScript("OnClick", spec.onClick)
	end
	addTooltip(button, spec.label, spec.tooltip)
	page:OnRefresh(function()
		if not Compat.InCombat() then
			button:SetEnabled(Storage:Get(module.name, "enabled") == true)
		end
	end)
	page.switchButtons = page.switchButtons or {}
	page.switchButtons[module.name] = button
end

-- A module's block on the main page: its switch (with switchNote, a text
-- under it, or a function that gives it or nil as the page is built), or its title for a module that has none (switchLabel = false);
-- then what goes under it, indented: the module's main settings, which can be
-- changed only while it is on. A main setting is a heading (label) over a
-- group of them, a checkbox (with note), checkboxes in columns (items,
-- columns), a choice (a dropdown), a slider (min, max, step, format), a
-- colour, a button (shown only while visible() says so, when given), or a
-- custom builder(page, indent, module), each with an optional enabledWhen()
-- and gap, the room above it.
local function addModule(page, module)
	local requires
	if module.switchLabel == false then
		local title = page:Area():CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		title:SetText(module.title)
		page:Add("title", title, 20, { text = module.title, gap = 10 })
	else
		local note = module.switchNote
		if type(note) == "function" then
			note = note()
		end
		local switch = page:AddCheckbox(module.name, "enabled", module.switchLabel or module.title, module.description, 0, nil, nil, nil, note)
		requires = module.name
		if module.switchButton then
			addSwitchButton(page, switch, module)
		end
	end
	for _, setting in ipairs(module.mainSettings or {}) do
		local indent = Panel.INDENT * (setting.level or 1)
		if setting.kind == "heading" then
			page:AddHeading(setting.label, { indent = indent, gap = setting.gap, requires = requires })
		elseif setting.kind == "checkbox" then
			page:AddCheckbox(module.name, setting.key, setting.label, setting.tooltip, indent, requires, setting.enabledWhen, setting.gap,
				setting.note)
		elseif setting.kind == "checkboxes" then
			page:AddCheckboxes(module.name, setting.items, { indent = indent, requires = requires, enabledWhen = setting.enabledWhen,
				columns = setting.columns })
		elseif setting.kind == "choice" then
			page:AddChoice(module.name, setting.key, setting.label, setting.choices, { indent = indent, gap = setting.gap,
				requires = requires, enabledWhen = setting.enabledWhen, tooltip = setting.tooltip })
		elseif setting.kind == "slider" then
			page:AddSlider(module.name, setting.key, setting.label, setting, { indent = indent, gap = setting.gap, requires = requires,
				enabledWhen = setting.enabledWhen, tooltip = setting.tooltip })
		elseif setting.kind == "color" then
			page:AddColor(module.name, setting.key, setting.label, { indent = indent, gap = setting.gap, requires = requires,
				enabledWhen = setting.enabledWhen, tooltip = setting.tooltip })
		elseif setting.kind == "button" then
			page:AddButton(setting.label, setting.click, { indent = indent, requires = requires, enabledWhen = setting.enabledWhen,
				tooltip = setting.tooltip, visible = setting.visible, gap = setting.gap })
		elseif setting.kind == "custom" then
			setting.build(page, indent, module)
		else
			error(("%s.%s: the main page takes headings, checkboxes, choices, sliders, colours, buttons and custom blocks"):format(module.name, tostring(setting.key)))
		end
	end
end

local function build()
	local page = newMainPage()
	local category = Settings.RegisterCanvasLayoutCategory(page.frame, "Lootoman")
	page.category = category
	Panel.category, Panel.main = category, page

	-- The profile and its divider stay on top; the modules scroll under them.
	page.area = "head"
	for _, builder in ipairs(Panel.mainBuilders) do
		xpcall(function()
			builder(page)
		end, Compat.ReportError)
	end
	page:AddDivider()
	page.area = "body"
	for _, module in ipairs(Modules:List()) do
		xpcall(function()
			addModule(page, module)
		end, Compat.ReportError)
	end

	Settings.RegisterAddOnCategory(category)
	page:Refresh()
end

Bus:On("Ready", Panel, build)

Bus:On("OpenSettings", Panel, function()
	if Panel.category then
		Settings.OpenToCategory(Panel.category:GetID())
	end
end)

Bus:On("SettingChanged", Panel, function()
	if Panel.main then
		Panel.main:Refresh()
	end
end)

Bus:On("ProfileChanged", Panel, function()
	if Panel.main then
		Panel.main:Refresh()
	end
end)
