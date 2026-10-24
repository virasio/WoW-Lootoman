local _, ns = ...
local Bus, Compat, L, Modules, Storage = ns.Bus, ns.Compat, ns.L, ns.Modules, ns.Storage

-- The addon's page in the game options (techspec §7.1), built with Blizzard's
-- Settings API on Ready, so it looks like the game's own options. Controls
-- are proxy settings that read and write Storage; they are refreshed when the
-- value changes elsewhere or the profile changes.
--
-- Main page: a switch per module. Then a page per module, with the same
-- switch at the top and the module's own controls (BuildSettings), and the
-- pages other Settings files add with Panel.AddPage.
local Panel = {
	pages = {},
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

-- A checkbox bound to a boolean module setting, for BuildSettings. The variable
-- suffix keeps two checkboxes for the same setting apart.
function Panel.AddCheckbox(category, module, key, label, tooltip, suffix)
	local variable = ("LOOTOMAN_%s_%s%s"):format(module, key, suffix and ("_" .. suffix) or ""):upper()
	local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, label,
		Storage:GetDefault(module, key),
		function()
			return Storage:Get(module, key)
		end,
		function(value)
			Storage:Set(module, key, value)
		end)
	Panel.Track(setting, module, key)
	return Settings.CreateCheckbox(category, setting, tooltip)
end

-- builder(category) adds a page below the module pages.
function Panel.AddPage(builder)
	Panel.pages[#Panel.pages + 1] = builder
end

local function build()
	local category, layout = Settings.RegisterVerticalLayoutCategory("Lootoman")
	Panel.category = category

	local modules = Modules:List()
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Modules"]))
	for _, module in ipairs(modules) do
		Panel.AddCheckbox(category, module.name, "enabled", module.title, module.description, "list")
	end

	for _, module in ipairs(modules) do
		local page, pageLayout = Settings.RegisterVerticalLayoutSubcategory(category, module.title)
		Panel.AddCheckbox(page, module.name, "enabled", L["Enabled"], module.description)
		if module.BuildSettings then
			xpcall(function()
				module:BuildSettings(page, pageLayout)
			end, Compat.ReportError)
		end
	end

	for _, builder in ipairs(Panel.pages) do
		xpcall(function()
			builder(category)
		end, Compat.ReportError)
	end

	Settings.RegisterAddOnCategory(category)
end

Bus:On("Ready", Panel, build)

Bus:On("OpenSettings", Panel, function()
	if Panel.category then
		Settings.OpenToCategory(Panel.category:GetID())
	end
end)

Bus:On("SettingChanged", Panel, function(_, module, key)
	refresh(module, key)
end)

Bus:On("ProfileChanged", Panel, function()
	refresh()
end)
