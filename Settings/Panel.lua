local _, ns = ...
local Bus, Compat, L, Modules, Storage = ns.Bus, ns.Compat, ns.L, ns.Modules, ns.Storage

-- The addon's pages in the game options, built with Blizzard's
-- Settings API on Ready, so they look like the game's own options.
--
-- The main page is the addon's own frame (a canvas page), laid out the way a
-- player reads it: the title, what other Settings files put on top with
-- Panel.AddToMain (the profile), a divider, then every module's switch, a
-- checkbox with its label after it. Under a switch, indented: the module's
-- main settings (module.mainSettings), which can be changed only while the
-- module is on, and a Configure button that opens the module's own page, if it
-- has one (module.BuildSettings). The main page reads Storage again when it is
-- shown and whenever a value or the profile changes.
--
-- A module's page has the same switch on top and the module's own controls.
-- Its controls are proxy settings that read and write Storage; they are
-- refreshed when the value changes elsewhere or the profile changes.
local Panel = {
	mainBuilders = {},
}
ns.SettingsPanel = Panel

local tracked = {}

-- Keeps a setting's control in step with Storage. With module and key, it is
-- refreshed when that value changes; every setting is refreshed on a profile change.
function Panel.Track(setting, module, key)
	tracked[#tracked + 1] = { setting = setting, module = module, key = key }
end

local function refresh(module, key)
	for _, item in ipairs(tracked) do
		-- A locked setting is the one being changed; it updates its own control.
		if (module == nil or (item.module == module and item.key == key)) and not item.setting:IsLocked() then
			item.setting:NotifyUpdate()
		end
	end
end

-- A proxy setting bound to a module setting, named LOOTOMAN_<MODULE>_<KEY>.
-- convert, if given, turns a value from the control into the value to store.
local function register(category, module, key, label, varType, convert)
	local variable = ("LOOTOMAN_%s_%s"):format(module, key):upper()
	local setting = Settings.RegisterProxySetting(category, variable, varType, label,
		Storage:GetDefault(module, key),
		function()
			return Storage:Get(module, key)
		end,
		function(value)
			Storage:Set(module, key, convert and convert(value) or value)
		end)
	Panel.Track(setting, module, key)
	return setting
end

-- A checkbox bound to a boolean module setting, for BuildSettings.
function Panel.AddCheckbox(category, module, key, label, tooltip)
	local setting = register(category, module, key, label, Settings.VarType.Boolean)
	return Settings.CreateCheckbox(category, setting, tooltip)
end

-- A slider bound to a number module setting, from min to max in steps. format
-- shows the value next to the slider: a format string such as "%d s", or a
-- function(value) that returns the text.
function Panel.AddSlider(category, module, key, label, tooltip, min, max, step, format)
	assert(type(Storage:GetDefault(module, key)) == "number", ("%s.%s: a slider needs a number setting"):format(module, key))
	local setting = register(category, module, key, label, Settings.VarType.Number, function(value)
		return Storage.OnStep(value, min, max, step)
	end)
	local options = Settings.CreateSliderOptions(min, max, step)
	if format then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, type(format) == "function" and format
			or function(value)
				return format:format(value)
			end)
	end
	return Settings.CreateSlider(category, setting, options, tooltip)
end

-- A dropdown bound to a string or number module setting. choices lists
-- { value, label } pairs in the order shown; the default must be one of them.
-- offered(), when given, gives the choices to show now, of all the choices.
function Panel.AddDropdown(category, module, key, label, tooltip, choices, offered)
	local default = Storage:GetDefault(module, key)
	local found = false
	for _, choice in ipairs(choices) do
		found = found or choice[1] == default
	end
	assert(found, ("%s.%s: the default is not one of the choices"):format(module, key))
	local varType = type(default) == "number" and Settings.VarType.Number or Settings.VarType.String
	local setting = register(category, module, key, label, varType)
	local function options()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(offered and offered() or choices) do
			container:Add(choice[1], choice[2])
		end
		return container:GetData()
	end
	return Settings.CreateDropdown(category, setting, options, tooltip)
end

-- A button on a page, for BuildSettings(category, layout).
function Panel.AddButton(layout, label, buttonText, onClick, tooltip)
	local initializer = CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true)
	layout:AddInitializer(initializer)
	return initializer
end

-- A section header that starts a group of settings on a page.
function Panel.AddHeader(layout, label, tooltip)
	local initializer = CreateSettingsListSectionHeaderInitializer(label, tooltip)
	layout:AddInitializer(initializer)
	return initializer
end

-- A module's settings from the list the Edit Mode dialog also takes
-- (EditMode.Register): headers, checkboxes, sliders and dropdowns, in order.
-- A setting with a parent (the key of a checkbox before it) sits indented
-- under it, usable only while that one is on.
function Panel.AddSettings(category, layout, module, settings)
	local made = {}
	for _, setting in ipairs(settings) do
		local initializer
		if setting.kind == "header" then
			Panel.AddHeader(layout, setting.label, setting.tooltip)
		elseif setting.kind == "checkbox" then
			initializer = Panel.AddCheckbox(category, module, setting.key, setting.label, setting.tooltip)
		elseif setting.kind == "slider" then
			initializer = Panel.AddSlider(category, module, setting.key, setting.label, setting.tooltip,
				setting.min, setting.max, setting.step, setting.format)
		elseif setting.kind == "dropdown" then
			initializer = Panel.AddDropdown(category, module, setting.key, setting.label, setting.tooltip, setting.choices, setting.offered)
		else
			error(("%s: unknown setting kind %s"):format(module, tostring(setting.kind)))
		end
		if setting.key then
			made[setting.key] = initializer
		end
		local parent = setting.parent and made[setting.parent]
		if parent and initializer then
			initializer:SetParentInitializer(parent, function()
				return Storage:Get(module, setting.parent) == true
			end)
		end
	end
end

-- builder(page) adds controls to the top of the main page (MainPage below).
function Panel.AddToMain(builder)
	Panel.mainBuilders[#Panel.mainBuilders + 1] = builder
end

-- The main page's layout: everything starts this far from the left edge;
-- options under a switch start further in; a row's control starts at CONTROL_X.
Panel.LEFT = 20
Panel.INDENT = 24
Panel.CONTROL_X = 260
local GAP = 6

-- The main page, built from top to bottom: every Add puts an item under the
-- last one. An item can be hidden (options.visible): the page lays its items
-- out again whenever it refreshes. items lists what was added, in order, for
-- tests.
local MainPage = {}
MainPage.__index = MainPage

local function newMainPage()
	local frame = CreateFrame("Frame")
	frame:Hide()
	local page = setmetatable({ frame = frame, items = {}, refreshers = {} }, MainPage)
	-- The header of the options panel's own pages (Blizzard_SettingsList.xml).
	page.title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	page.title:SetJustifyH("LEFT")
	page.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
	page.title:SetText("Lootoman")
	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOP", frame, "TOP", 0, -50)
	page.top = -56
	-- The options panel calls it when it shows the page.
	function frame.OnRefresh()
		page:Refresh()
	end
	return page
end

-- Places every shown item under the one before it.
function MainPage:Layout()
	local y = self.top
	for _, item in ipairs(self.items) do
		local frame = item.frame
		local shown = item.visible == nil or item.visible()
		item.hidden = not shown
		if not shown then
			frame:Hide()
		elseif item.kind == "divider" then
			y = y - 12
			frame:ClearAllPoints()
			frame:SetPoint("TOP", self.frame, "TOP", 0, y)
			frame:Show()
			y = y - 6
		else
			y = y - item.gap
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", Panel.LEFT + item.indent, y)
			if item.wide then
				frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -Panel.LEFT, y)
				frame:SetHeight(item.height)
			end
			frame:Show()
			y = y - item.height
		end
	end
	self.y = y
end

-- Puts a region gap pixels under the last item, indent pixels further in.
-- options.frame is placed instead of the region when it holds the region; a
-- wide one reaches to the page's right edge; visible(), when given, says
-- whether it shows now.
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
		text = options.text,
		visible = options.visible,
	}
	self:Layout()
	return region
end

function MainPage:AddDivider()
	local divider = self.frame:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	return self:Add("divider", divider, 0, { gap = 0 })
end

-- update() runs whenever the page should show the stored values again.
function MainPage:OnRefresh(update)
	self.refreshers[#self.refreshers + 1] = update
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

local function setTextEnabled(text, isEnabled, font)
	text:SetFontObject(isEnabled and (font or "GameFontNormal") or "GameFontDisable")
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

-- A checkbox in the options panel's own style with its label after it, bound
-- to a boolean module setting; a click on the label toggles it too. With
-- requires, it can be changed only while that module is on; with enabledWhen,
-- only while that says so. It sits in a row of its own, as on the panel's list
-- pages: the template's hover background fills the checkbox's parent's
-- parent, so only that row lights up.
function MainPage:AddCheckbox(module, key, label, tooltip, indent, requires, enabledWhen)
	local row = CreateFrame("Frame", nil, self.frame)
	local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
	checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	text:SetText(label)
	checkbox.label = text
	checkbox:SetHitRectInsets(0, -(text:GetUnboundedStringWidth() + 4), 0, 0)
	checkbox:SetTooltipFunc(function()
		Settings.InitTooltip(label, tooltip)
	end)
	checkbox:SetScript("OnClick", function(button)
		Storage:Set(module, key, button:GetChecked() and true or false)
	end)
	self:OnRefresh(function()
		checkbox:SetChecked(Storage:Get(module, key))
		local isEnabled = enabled(requires, enabledWhen)
		checkbox:SetEnabled(isEnabled)
		setTextEnabled(text, isEnabled)
	end)
	return self:Add("checkbox", checkbox, 29, { indent = indent, text = label, frame = row, wide = true })
end

-- A choice of a module setting: its label, then a radio button for each
-- choice ({ value, label }), side by side or, with options.vertical, one under
-- another. options: indent, requires, enabledWhen, tooltip.
function MainPage:AddChoice(module, key, label, choices, options)
	options = options or {}
	local row = CreateFrame("Frame", nil, self.frame)
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
	text:SetText(label)
	addTooltip(row, label, options.tooltip)
	local radios = {}
	local x, y = Panel.CONTROL_X - Panel.LEFT - (options.indent or 0), 0
	for index, choice in ipairs(choices) do
		local radio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
		radio:SetPoint("TOPLEFT", row, "TOPLEFT", x, y - 4)
		radio.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		radio.label:SetPoint("LEFT", radio, "RIGHT", 5, 0)
		radio.label:SetText(choice[2])
		radio.value = choice[1]
		radio:SetHitRectInsets(0, -(radio.label:GetUnboundedStringWidth() + 5), 0, 0)
		radio:SetScript("OnClick", function()
			Storage:Set(module, key, choice[1])
		end)
		radios[index] = radio
		if options.vertical then
			y = y - 22
		else
			x = x + 26 + radio.label:GetUnboundedStringWidth() + 16
		end
	end
	row.radios = radios
	self:OnRefresh(function()
		local value = Storage:Get(module, key)
		local isEnabled = enabled(options.requires, options.enabledWhen)
		setTextEnabled(text, isEnabled)
		for _, radio in ipairs(radios) do
			radio:SetChecked(radio.value == value)
			radio:SetEnabled(isEnabled)
			setTextEnabled(radio.label, isEnabled, "GameFontHighlight")
		end
	end)
	local height = options.vertical and (#choices * 22 + 2) or 24
	return self:Add("choice", row, height, { indent = options.indent, text = label, wide = true })
end

-- A button with text, which runs onClick. options: indent, requires,
-- enabledWhen, tooltip.
function MainPage:AddButton(text, onClick, options)
	options = options or {}
	local button = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
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
	return self:Add("button", button, 22, { indent = options.indent, text = text, gap = options.gap or 4 })
end

-- A button that opens another options page.
function MainPage:AddPageButton(text, category, indent)
	return self:AddButton(text, function()
		Settings.OpenToCategory(category:GetID())
	end, { indent = indent, gap = 2 })
end

-- A row with a label on the left and a control (made by the caller, a child
-- of the row) at CONTROL_X. options: indent, height, tooltip, visible.
-- Returns the row; control is placed in it.
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
	return self:Add("row", row, options.height or 26, { indent = options.indent, text = label, wide = true, visible = options.visible })
end

-- A frame for a row's control: make the control a child of it, then AddRow.
function MainPage:NewRow()
	return CreateFrame("Frame", nil, self.frame)
end

-- A framed group with a header on top, height high in all: the caller puts
-- its content inside, under box.header. options: indent, visible, headerFont.
function MainPage:AddBox(header, height, options)
	options = options or {}
	local box = CreateFrame("Frame", nil, self.frame, "InsetFrameTemplate")
	box.header = box:CreateFontString(nil, "ARTWORK", options.headerFont or "GameFontNormal")
	box.header:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
	box.header:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, -8)
	box.header:SetJustifyH("LEFT")
	box.header:SetText(header)
	return self:Add("box", box, height, { indent = options.indent, text = header, wide = true, visible = options.visible, gap = 8 })
end

-- A module's block on the main page: its switch, or its title for a module
-- that has none (switchLabel = false); then what goes under it, indented:
-- the module's main settings, which can be changed only while it is on; and a
-- Configure button that opens the module's own page, if it has one.
-- A main setting is a checkbox, a choice (radio buttons), a button, or a
-- custom builder(page, indent, module), each with an optional enabledWhen().
local function addModule(page, category, module)
	local requires
	if module.switchLabel == false then
		local title = page.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		title:SetText(module.title)
		page:Add("title", title, 20, { text = module.title, gap = 10 })
	else
		page:AddCheckbox(module.name, "enabled", module.switchLabel or module.title, module.description, 0)
		requires = module.name
	end
	for _, setting in ipairs(module.mainSettings or {}) do
		local indent = Panel.INDENT * (setting.level or 1)
		if setting.kind == "checkbox" then
			page:AddCheckbox(module.name, setting.key, setting.label, setting.tooltip, indent, requires, setting.enabledWhen)
		elseif setting.kind == "choice" then
			page:AddChoice(module.name, setting.key, setting.label, setting.choices, { indent = indent, requires = requires,
				enabledWhen = setting.enabledWhen, vertical = setting.vertical, tooltip = setting.tooltip })
		elseif setting.kind == "button" then
			page:AddButton(setting.label, setting.click, { indent = indent, requires = requires, enabledWhen = setting.enabledWhen,
				tooltip = setting.tooltip })
		elseif setting.kind == "custom" then
			setting.build(page, indent, module)
		else
			error(("%s.%s: the main page takes checkboxes, choices, buttons and custom blocks"):format(module.name, tostring(setting.key)))
		end
	end
	if module.BuildSettings then
		local subpage, layout = Settings.RegisterVerticalLayoutSubcategory(category, module.title)
		Panel.AddCheckbox(subpage, module.name, "enabled", L["Enabled"], module.description)
		xpcall(function()
			module:BuildSettings(subpage, layout)
		end, Compat.ReportError)
		page:AddPageButton(L["Configure"], subpage, Panel.INDENT)
	end
end

local function build()
	local page = newMainPage()
	local category = Settings.RegisterCanvasLayoutCategory(page.frame, "Lootoman")
	page.category = category
	Panel.category, Panel.main = category, page

	for _, builder in ipairs(Panel.mainBuilders) do
		xpcall(function()
			builder(page)
		end, Compat.ReportError)
	end
	page:AddDivider()
	for _, module in ipairs(Modules:List()) do
		xpcall(function()
			addModule(page, category, module)
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

Bus:On("SettingChanged", Panel, function(_, module, key)
	refresh(module, key)
	if Panel.main then
		Panel.main:Refresh()
	end
end)

Bus:On("ProfileChanged", Panel, function()
	refresh()
	if Panel.main then
		Panel.main:Refresh()
	end
end)
