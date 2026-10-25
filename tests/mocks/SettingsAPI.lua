-- A small stand-in for Blizzard's Settings API and StaticPopup, enough to build
-- the settings panel in tests. It records what was registered, and its
-- settings behave like Blizzard's (Blizzard_Setting.lua): SetValue locks the
-- setting while the setter runs, NotifyUpdate re-reads the value.

local SettingsAPI = {}

function SettingsAPI.Install()
	local api = { categories = {}, settings = {}, addOnCategories = {}, popups = {} }

	local function newCategory(name, parent)
		local category = { name = name, parent = parent, id = #api.categories + 1, initializers = {} }
		function category:GetID()
			return self.id
		end
		function category:GetParentCategory()
			return self.parent
		end
		local layout = {}
		function layout:AddInitializer(initializer)
			category.initializers[#category.initializers + 1] = initializer
		end
		api.categories[#api.categories + 1] = category
		return category, layout
	end

	local function addInitializer(category, initializer)
		category.initializers[#category.initializers + 1] = initializer
		return initializer
	end

	local Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		CannotDefault = nil,
	}

	function Settings.RegisterVerticalLayoutCategory(name)
		return newCategory(name)
	end

	function Settings.RegisterVerticalLayoutSubcategory(parent, name)
		return newCategory(name, parent)
	end

	-- A page that is the addon's own frame; Blizzard calls frame:OnRefresh()
	-- when it shows the page.
	function Settings.RegisterCanvasLayoutCategory(frame, name)
		local category, layout = newCategory(name)
		category.frame = frame
		return category, layout
	end

	-- The options panel's tooltip (SettingsTooltip): its lines.
	local settingsTooltip = { lines = {} }
	function settingsTooltip:SetOwner(owner)
		self.owner, self.lines = owner, {}
	end
	function settingsTooltip:Show() self.shown = true end
	function settingsTooltip:Hide() self.shown = false end
	api.tooltip = settingsTooltip
	rawset(_G, "SettingsTooltip", settingsTooltip)
	function Settings.InitTooltip(name, text)
		settingsTooltip.lines = { name, text }
	end

	function Settings.RegisterAddOnCategory(category)
		api.addOnCategories[#api.addOnCategories + 1] = category
	end

	function Settings.OpenToCategory(id)
		api.opened = id
	end

	function Settings.RegisterProxySetting(category, variable, varType, name, default, getValue, setValue)
		assert(not api.settings[variable], "duplicate setting variable " .. variable)
		assert(default == nil or type(default) == varType, variable .. ": default does not match the type")
		local setting = { variable = variable, name = name, default = default, category = category, notified = 0 }
		function setting:GetValue()
			return getValue()
		end
		function setting:SetValue(value)
			assert(type(value) == varType, variable .. ": value does not match the type")
			self.locked = true
			setValue(value)
			self.locked = false
		end
		function setting:IsLocked()
			return self.locked == true
		end
		function setting:NotifyUpdate()
			self.notified = self.notified + 1
		end
		api.settings[variable] = setting
		return setting
	end

	function Settings.CreateCheckbox(category, setting, tooltip)
		return addInitializer(category, { kind = "checkbox", setting = setting, tooltip = tooltip })
	end

	function Settings.CreateDropdown(category, setting, options, tooltip)
		return addInitializer(category, { kind = "dropdown", setting = setting, options = options, tooltip = tooltip })
	end

	function Settings.CreateControlTextContainer()
		local container = { data = {} }
		function container:Add(value, label, tooltip)
			local data = { value = value, label = label, text = label, tooltip = tooltip }
			self.data[#self.data + 1] = data
			return data
		end
		function container:GetData()
			return self.data
		end
		return container
	end

	-- Like Blizzard_Settings.lua: steps = (max - min) / rate.
	function Settings.CreateSliderOptions(minValue, maxValue, rate)
		local options = { minValue = minValue, maxValue = maxValue, steps = (maxValue - minValue) / rate, formatters = {} }
		function options:SetLabelFormatter(labelType, formatter)
			self.formatters[labelType] = formatter
		end
		return options
	end

	function Settings.CreateSlider(category, setting, options, tooltip)
		return addInitializer(category, { kind = "slider", setting = setting, options = options, tooltip = tooltip })
	end

	rawset(_G, "Settings", Settings)
	-- EnumUtil.MakeEnum("Left", "Right", "Top", "Min", "Max") in MinimalSlider.lua.
	rawset(_G, "MinimalSliderWithSteppersMixin", { Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } })
	rawset(_G, "CANCEL", "Cancel")

	-- EventRegistry (CallbackRegistry): an owner's callback gets (owner, ...).
	local callbacks = {}
	rawset(_G, "EventRegistry", {
		RegisterCallback = function(_, event, callback, owner)
			callbacks[event] = callbacks[event] or {}
			table.insert(callbacks[event], { callback, owner })
		end,
		TriggerEvent = function(_, event, ...)
			for _, entry in ipairs(callbacks[event] or {}) do
				entry[1](entry[2], ...)
			end
		end,
	})

	-- The options window: the header's Defaults button, shown on every page
	-- (Blizzard_SettingsPanel.lua), and the page being shown.
	local defaults = { shown = true, hooks = {} }
	function defaults:Show()
		self.shown = true
		for _, hook in ipairs(self.hooks.OnShow or {}) do
			hook(self)
		end
	end
	function defaults:Hide() self.shown = false end
	function defaults:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end
	function defaults:HookScript(script, hook)
		self.hooks[script] = self.hooks[script] or {}
		table.insert(self.hooks[script], hook)
	end
	api.defaultsButton = defaults
	local panel = { list = { Header = { DefaultsButton = defaults } } }
	function panel:GetSettingsList() return self.list end
	function panel:GetCurrentCategory() return self.current end
	rawset(_G, "SettingsPanel", panel)
	rawset(_G, "CreateSettingsListSectionHeaderInitializer", function(name, tooltip)
		return { kind = "header", name = name, tooltip = tooltip }
	end)
	rawset(_G, "CreateSettingsButtonInitializer", function(name, buttonText, onClick, tooltip)
		return { kind = "button", name = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip }
	end)
	-- Blizzard's menu API (Blizzard_Menu), as far as a dropdown's menu uses it.
	rawset(_G, "MenuConstants", { VerticalGridDirection = 2 })
	rawset(_G, "MenuVariants", { GearButtonAnchor = "gear anchor", CancelButtonAnchor = "cancel anchor" })
	local function attach(kind)
		return function(parent)
			local button = { kind = kind }
			parent.attached[#parent.attached + 1] = button
			return button
		end
	end
	rawset(_G, "MenuTemplates", {
		AttachAutoHideGearButton = attach("gear"),
		AttachAutoHideCancelButton = attach("cancel"),
		SetUtilityButtonTooltipText = function(button, text) button.tooltip = text end,
		SetUtilityButtonAnchor = function(button, anchor, relativeTo) button.anchor = { anchor, relativeTo } end,
		SetUtilityButtonClickHandler = function(button, handler) button.click = handler end,
	})
	rawset(_G, "CreateAtlasMarkup", function(atlas) return "|A:" .. atlas .. "|a" end)
	rawset(_G, "GameTooltip_SetTitle", function(tooltip, text) tooltip[#tooltip + 1] = text end)
	rawset(_G, "GameTooltip_AddNormalLine", function(tooltip, text) tooltip[#tooltip + 1] = text end)
	rawset(_G, "StaticPopup_Show", function(which, _, _, data)
		local editBox = { text = "" }
		function editBox:SetText(text)
			self.text = text
		end
		function editBox:GetText()
			return self.text
		end
		function editBox:HighlightText() end
		local dialog = { which = which, data = data, editBox = editBox }
		function dialog:GetEditBox()
			return self.editBox
		end
		api.popups[#api.popups + 1] = dialog
		return dialog
	end)

	-- Test helpers.

	function api.FindCategory(name)
		for _, category in ipairs(api.categories) do
			if category.name == name then
				return category
			end
		end
	end

	function api.FindButton(category, name)
		for _, initializer in ipairs(category.initializers) do
			if initializer.kind == "button" and initializer.name == name then
				return initializer
			end
		end
	end

	function api.Kinds(category)
		local kinds = {}
		for index, initializer in ipairs(category.initializers) do
			kinds[index] = initializer.kind .. ":" .. (initializer.name or initializer.setting.name)
		end
		return kinds
	end

	-- A menu description (Blizzard_Menu's ElementMenuDescription) that records
	-- what is built into it.
	local function newDescription(kind, text)
		local description = { kind = kind, text = text, entries = {}, initializers = {} }
		local function add(entry)
			description.entries[#description.entries + 1] = entry
			return entry
		end
		function description:CreateRadio(radioText, isSelected, setSelected, data)
			local radio = add(newDescription("radio", radioText))
			radio.isSelected, radio.setSelected, radio.data = isSelected, setSelected, data
			return radio
		end
		function description:CreateButton(buttonText, callback)
			local button = add(newDescription("button", buttonText))
			button.callback = callback
			return button
		end
		function description:CreateDivider()
			return add(newDescription("divider"))
		end
		function description:SetGridMode(direction, columns) self.grid = { direction, columns } end
		function description:DeactivateSubmenu() self.submenuDeactivated = true end
		function description:ForceOpenSubmenu() self.submenuOpened = true end
		function description:AddInitializer(initializer) self.initializers[#self.initializers + 1] = initializer end
		function description:SetTooltip(fn) self.tooltip = fn end
		-- Test helpers: the tooltip's lines, and what shows on hover.
		function description:TooltipLines()
			local lines = {}
			self.tooltip(lines, self)
			return lines
		end
		function description:Hover()
			local button, menu = { attached = {} }, { closed = false }
			function menu:Close() self.closed = true end
			for _, initializer in ipairs(self.initializers) do
				initializer(button, self, menu)
			end
			return button.attached, menu
		end
		return description
	end

	-- The menu of a dropdown (DropdownButton:SetupMenu) as it opens.
	function api.OpenMenu(dropdown)
		local root = newDescription("root")
		dropdown.menu(dropdown, root)
		return root
	end

	-- What the options window does when the player picks a page (SelectCategory).
	function api.SelectCategory(category)
		panel.current = category
		_G.EventRegistry:TriggerEvent("Settings.CategoryChanged", category)
	end

	-- Accepts the last dialog, typing text into it if it has an edit box.
	function api.AcceptPopup(text)
		local dialog = assert(api.popups[#api.popups], "no dialog is shown")
		if dialog.which == "GENERIC_INPUT_BOX" then
			dialog.data.callback(text or dialog.editBox:GetText())
		else
			dialog.data.callback()
		end
	end

	return api
end

return SettingsAPI
