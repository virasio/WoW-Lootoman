local _, ns = ...
local Bus, Compat, Storage = ns.Bus, ns.Compat, ns.Storage

-- User-facing features register here (techspec §3). Each module has an
-- "enabled" setting in the profile, and the registry turns modules on and off
-- to match it: on Ready, on a profile change and on a toggle, without /reload.
-- A disabled module has no listeners on the bus.
--
-- Modules change state only out of combat, because frames cannot be created
-- or reparented in combat; changes made in combat wait for its end.
--
--   local Feed = ns.Modules:Register({
--       name = "LootFeed",
--       title = <localized name>,
--       defaults = { enabled = true, rows = 5 },
--       OnEnable = function(self) self:OnEvent("CHAT_MSG_LOOT", ...) end,
--       OnDisable = function(self) hide frames (also after a failed OnEnable) end,
--       BuildSettings = function(self, category, layout) end,
--   })
local Modules = {
	list = {},
	byName = {},
}
ns.Modules = Modules

local ModuleMixin = {}

function ModuleMixin:Get(key)
	return Storage:Get(self.name, key)
end

function ModuleMixin:Set(key, value)
	Storage:Set(self.name, key, value)
end

function ModuleMixin:On(message, fn)
	Bus:On(message, self, fn)
end

function ModuleMixin:OnEvent(event, fn)
	Bus:OnEvent(event, self, fn)
end

function ModuleMixin:IsActive()
	return self.active
end

function Modules:Register(definition)
	local name = definition.name
	assert(type(name) == "string" and name ~= "", "a module needs a name")
	assert(not self.byName[name], ("module %s is already registered"):format(name))
	assert(type(definition.defaults) == "table" and type(definition.defaults.enabled) == "boolean",
		("module %s needs a boolean enabled default"):format(name))

	local module = setmetatable(definition, { __index = ModuleMixin })
	module.title = module.title or name
	module.active = false
	Storage:RegisterDefaults(name, module.defaults)
	self.list[#self.list + 1] = module
	self.byName[name] = module
	return module
end

function Modules:Get(name)
	return self.byName[name]
end

function Modules:List()
	local list = {}
	for index, module in ipairs(self.list) do
		list[index] = module
	end
	return list
end

function Modules:SetEnabled(name, enabled)
	Storage:Set(name, "enabled", enabled)
end

local function tearDown(module)
	xpcall(function()
		if module.OnDisable then
			module:OnDisable()
		end
	end, Compat.ReportError)
	Bus:OffAll(module)
end

-- A failing OnEnable is undone with OnDisable, so OnDisable must also handle a
-- module that started only halfway (frames not created yet, for example).
local function setActive(module, active)
	if active then
		local ok = xpcall(function()
			if module.OnEnable then
				module:OnEnable()
			end
		end, Compat.ReportError)
		if not ok then
			tearDown(module)
		end
		module.active = ok
	else
		tearDown(module)
		module.active = false
	end
	Bus:Send("ModuleToggled", module.name, module.active)
end

local MAX_PASSES = 10

local ready, applying, again = false, false, false

local function reconcile()
	for _, module in ipairs(Modules.list) do
		local wanted = Storage:Get(module.name, "enabled")
		if wanted ~= module.active then
			setActive(module, wanted)
		end
	end
end

function Modules:Apply()
	if not ready then
		return
	end
	if Compat.InCombat() then
		Bus:OnEvent("PLAYER_REGEN_ENABLED", Modules, function()
			Bus:OffEvent("PLAYER_REGEN_ENABLED", Modules)
			Modules:Apply()
		end)
		return
	end
	-- A module may change settings or the profile while it starts or stops,
	-- which calls Apply again. Finish the current pass, then run another.
	if applying then
		again = true
		return
	end
	applying = true
	local passes = 0
	repeat
		again = false
		passes = passes + 1
		local ok, err = pcall(reconcile)
		if not ok then
			Compat.ReportError(err)
		end
	until not again or passes >= MAX_PASSES
	applying = false
	if again then
		again = false
		Compat.ReportError(("Lootoman: modules kept changing their enabled setting; stopped after %d passes"):format(MAX_PASSES))
	end
end

Bus:On("Ready", Modules, function()
	ready = true
	Modules:Apply()
end)

Bus:On("ProfileChanged", Modules, function()
	Modules:Apply()
end)

Bus:On("SettingChanged", Modules, function(_, name, key)
	if key == "enabled" and Modules.byName[name] then
		Modules:Apply()
	end
end)
