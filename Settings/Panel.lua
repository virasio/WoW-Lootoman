local _, ns = ...
local Bus, Compat, Modules, Storage = ns.Bus, ns.Compat, ns.Modules, ns.Storage

-- The addon's page in the game options, registered with Blizzard's Settings
-- API on Ready. It has no subpages: what does not fit is in the addon's own
-- windows (a feed look's, the junk list).
--
-- The page is the addon's own frame (a canvas page), laid out the way a
-- player reads it: the title, what other Settings files put on top with
-- Panel.AddToMain (the profile), a divider, then every module's block: its
-- switch, a checkbox with its label after it, or its title for a module
-- without one. Under it, indented: the module's main settings
-- (module.mainSettings), which can be changed only while the module is on.
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
-- The width of a choice's dropdown: room for the longest choice, in Russian too.
Panel.DROPDOWN_WIDTH = 260
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

-- A choice of a module setting: its label, then a dropdown in the options
-- panel's own style with a radio for each choice ({ value, label }).
-- options: indent, requires, enabledWhen, tooltip. Returns the dropdown.
function MainPage:AddChoice(module, key, label, choices, options)
	options = options or {}
	local row = self:NewRow()
	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle2DropdownTemplate")
	dropdown:SetWidth(Panel.DROPDOWN_WIDTH)
	dropdown:SetupMenu(function(_, root)
		for _, choice in ipairs(choices) do
			root:CreateRadio(choice[2], function(value)
				return Storage:Get(module, key) == value
			end, function(value)
				Storage:Set(module, key, value)
			end, choice[1])
		end
	end)
	self:AddRow(label, dropdown, { indent = options.indent, height = 28, tooltip = options.tooltip, kind = "choice" })
	self:OnRefresh(function()
		local isEnabled = enabled(options.requires, options.enabledWhen)
		setTextEnabled(row.label, isEnabled)
		dropdown:SetEnabled(isEnabled)
		dropdown:GenerateMenu()
	end)
	return dropdown
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

-- A row with a label on the left and a control (made by the caller, a child
-- of the row) at CONTROL_X. options: indent, height, tooltip, visible, and
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
		visible = options.visible })
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
-- the module's main settings, which can be changed only while it is on.
-- A main setting is a checkbox, a choice (a dropdown), a button, or a
-- custom builder(page, indent, module), each with an optional enabledWhen().
local function addModule(page, module)
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
				enabledWhen = setting.enabledWhen, tooltip = setting.tooltip })
		elseif setting.kind == "button" then
			page:AddButton(setting.label, setting.click, { indent = indent, requires = requires, enabledWhen = setting.enabledWhen,
				tooltip = setting.tooltip })
		elseif setting.kind == "custom" then
			setting.build(page, indent, module)
		else
			error(("%s.%s: the main page takes checkboxes, choices, buttons and custom blocks"):format(module.name, tostring(setting.key)))
		end
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
