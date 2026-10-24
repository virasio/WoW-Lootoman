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
		function container:Add(value, label)
			self.data[#self.data + 1] = { value = value, label = label }
		end
		function container:GetData()
			return self.data
		end
		return container
	end

	rawset(_G, "Settings", Settings)
	rawset(_G, "CANCEL", "Cancel")
	rawset(_G, "CreateSettingsListSectionHeaderInitializer", function(name)
		return { kind = "header", name = name }
	end)
	rawset(_G, "CreateSettingsButtonInitializer", function(name, buttonText, onClick, tooltip)
		return { kind = "button", name = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip }
	end)
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
