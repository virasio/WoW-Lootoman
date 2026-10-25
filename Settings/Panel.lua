local _, ns = ...
local Bus, Compat, L, Modules, Storage = ns.Bus, ns.Compat, ns.L, ns.Modules, ns.Storage

-- The addon's pages in the game options (techspec §7.1), built with Blizzard's
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
function Panel.AddDropdown(category, module, key, label, tooltip, choices)
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
		for _, choice in ipairs(choices) do
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
function Panel.AddSettings(category, layout, module, settings)
	for _, setting in ipairs(settings) do
		if setting.kind == "header" then
			Panel.AddHeader(layout, setting.label, setting.tooltip)
		elseif setting.kind == "checkbox" then
			Panel.AddCheckbox(category, module, setting.key, setting.label, setting.tooltip)
		elseif setting.kind == "slider" then
			Panel.AddSlider(category, module, setting.key, setting.label, setting.tooltip,
				setting.min, setting.max, setting.step, setting.format)
		elseif setting.kind == "dropdown" then
			Panel.AddDropdown(category, module, setting.key, setting.label, setting.tooltip, setting.choices)
		else
			error(("%s: unknown setting kind %s"):format(module, tostring(setting.kind)))
		end
	end
end

-- builder(page) adds controls to the top of the main page (MainPage below).
function Panel.AddToMain(builder)
	Panel.mainBuilders[#Panel.mainBuilders + 1] = builder
end

-- The main page's layout: everything starts this far from the left edge;
-- options under a switch start further in.
Panel.LEFT = 20
Panel.INDENT = 24
local GAP = 6

-- The main page, built from top to bottom: every Add puts a region under the
-- last one. items lists what was added, in order, for tests.
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
	page.y = -56
	-- The options panel calls it when it shows the page.
	function frame.OnRefresh()
		page:Refresh()
	end
	return page
end

-- Puts a region gap pixels under the last one, indent pixels further in.
-- options.frame is placed instead of the region when it holds the region; a
-- wide one reaches to the page's right edge.
function MainPage:Add(kind, region, height, options)
	options = options or {}
	local indent = options.indent or 0
	local frame = options.frame or region
	self.y = self.y - (options.gap or GAP)
	frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", Panel.LEFT + indent, self.y)
	if options.wide then
		frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -Panel.LEFT, self.y)
		frame:SetHeight(height)
	end
	self.y = self.y - height
	self.items[#self.items + 1] = { kind = kind, region = region, text = options.text, indent = indent }
	return region
end

function MainPage:AddDivider()
	local divider = self.frame:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	self.y = self.y - 12
	divider:SetPoint("TOP", self.frame, "TOP", 0, self.y)
	self.y = self.y - 6
	self.items[#self.items + 1] = { kind = "divider", region = divider, indent = 0 }
	return divider
end

-- update() runs whenever the page should show the stored values again.
function MainPage:OnRefresh(update)
	self.refreshers[#self.refreshers + 1] = update
end

function MainPage:Refresh()
	for _, update in ipairs(self.refreshers) do
		xpcall(update, Compat.ReportError)
	end
end

-- A checkbox in the options panel's own style with its label after it, bound
-- to a boolean module setting; a click on the label toggles it too. With
-- requires, it can be changed only while that module is on. It sits in a row
-- of its own, as on the panel's list pages: the template's hover background
-- fills the checkbox's parent's parent, so only that row lights up.
function MainPage:AddCheckbox(module, key, label, tooltip, indent, requires)
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
		local enabled = requires == nil or Storage:Get(requires, "enabled")
		checkbox:SetEnabled(enabled)
		text:SetFontObject(enabled and "GameFontNormal" or "GameFontDisable")
	end)
	return self:Add("checkbox", checkbox, 29, { indent = indent, text = label, frame = row, wide = true })
end

-- A button that opens another options page.
function MainPage:AddPageButton(text, category, indent)
	local button = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
	button:SetSize(120, 22)
	button:SetText(text)
	button:SetScript("OnClick", function()
		Settings.OpenToCategory(category:GetID())
	end)
	return self:Add("button", button, 22, { indent = indent, text = text, gap = 2 })
end

-- A module's switch on the main page, what goes under it, and its own page.
local function addModule(page, category, module)
	page:AddCheckbox(module.name, "enabled", module.switchLabel or module.title, module.description, 0)
	for _, setting in ipairs(module.mainSettings or {}) do
		assert(setting.kind == "checkbox", ("%s.%s: the main page takes only checkboxes"):format(module.name, setting.key))
		page:AddCheckbox(module.name, setting.key, setting.label, setting.tooltip, Panel.INDENT, module.name)
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
