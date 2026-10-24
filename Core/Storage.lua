local _, ns = ...
local Bus, Migrations = ns.Bus, ns.Migrations

-- Saved settings (techspec §5). LootomanDB, account-wide: profiles, the
-- profile of each character, account-wide settings. LootomanCharDB: data of
-- one character.
--
-- Modules register their defaults, and a profile stores only the values that
-- differ from them, so changed defaults reach every user. Values are booleans,
-- numbers or strings; structured data gets its own profile sections later.
local Storage = {
	DEFAULT_PROFILE = "Default",
	defaults = {},
	globalDefaults = {},
	-- True when the saved data comes from a newer version of the addon.
	readOnly = false,
}
ns.Storage = Storage

local VALUE_TYPES = { boolean = true, number = true, string = true }

local function checkDefaults(owner, defaults)
	for key, value in pairs(defaults) do
		assert(VALUE_TYPES[type(value)], ("%s.%s: a default must be a boolean, number or string"):format(owner, key))
	end
end

function Storage:RegisterDefaults(module, defaults)
	assert(not self.defaults[module], ("defaults for %s are already registered"):format(module))
	checkDefaults(module, defaults)
	self.defaults[module] = defaults
end

function Storage:RegisterGlobalDefaults(defaults)
	checkDefaults("global", defaults)
	for key, value in pairs(defaults) do
		assert(self.globalDefaults[key] == nil, ("global default %s is already registered"):format(key))
		self.globalDefaults[key] = value
	end
end

-- Called with the saved tables on ADDON_LOADED. Returns the tables to save.
-- Data from a newer version is returned untouched, and the addon works on
-- defaults in memory that are never saved.
function Storage:Load(account, character)
	local db, accountStatus = Migrations.Run(Migrations.account, account)
	local charDB, characterStatus = Migrations.Run(Migrations.character, character)
	self.readOnly = accountStatus == "newer" or characterStatus == "newer"
	if self.readOnly then
		self.db = Migrations.Run(Migrations.account, nil)
		self.charDB = Migrations.Run(Migrations.character, nil)
	else
		self.db, self.charDB = db, charDB
	end
	return db, charDB
end

-- The character key ("Name-Realm") is known from PLAYER_LOGIN.
function Storage:SetCharacter(key)
	self.character = key
end

-- The profile of the current character; Default if it has none, or if its
-- profile no longer exists.
function Storage:GetProfileName()
	local name = self.character and self.db.profileKeys[self.character]
	if name and self.db.profiles[name] then
		return name
	end
	return self.DEFAULT_PROFILE
end

function Storage:GetProfile()
	local profiles = self.db.profiles
	local name = self:GetProfileName()
	profiles[name] = profiles[name] or {}
	return profiles[name]
end

function Storage:GetDefault(module, key)
	local defaults = self.defaults[module]
	local default = defaults and defaults[key]
	assert(default ~= nil, ("unknown setting %s.%s"):format(tostring(module), tostring(key)))
	return default
end

function Storage:Get(module, key)
	local default = self:GetDefault(module, key)
	local modules = self:GetProfile().modules
	local value = modules and modules[module] and modules[module][key]
	-- A saved value of the wrong type (an old default type) is ignored.
	if type(value) ~= type(default) then
		return default
	end
	return value
end

function Storage:Set(module, key, value)
	local default = self:GetDefault(module, key)
	assert(type(value) == type(default), ("%s.%s must be a %s"):format(module, key, type(default)))
	local old = self:Get(module, key)
	local profile = self:GetProfile()
	if value == default then
		local values = profile.modules and profile.modules[module]
		if values then
			values[key] = nil
			if next(values) == nil then
				profile.modules[module] = nil
			end
			if next(profile.modules) == nil then
				profile.modules = nil
			end
		end
	else
		profile.modules = profile.modules or {}
		profile.modules[module] = profile.modules[module] or {}
		profile.modules[module][key] = value
	end
	if value ~= old then
		Bus:Send("SettingChanged", module, key, value)
	end
end

-- Account-wide settings outside profiles, such as debug output.
function Storage:GetGlobal(key)
	local default = self.globalDefaults[key]
	assert(default ~= nil, ("unknown global setting %s"):format(tostring(key)))
	local value = self.db.global[key]
	if type(value) ~= type(default) then
		return default
	end
	return value
end

function Storage:SetGlobal(key, value)
	local default = self.globalDefaults[key]
	assert(default ~= nil, ("unknown global setting %s"):format(tostring(key)))
	assert(type(value) == type(default), ("global %s must be a %s"):format(key, type(default)))
	local old = self:GetGlobal(key)
	if value == default then
		self.db.global[key] = nil
	else
		self.db.global[key] = value
	end
	if value ~= old then
		Bus:Send("GlobalSettingChanged", key, value)
	end
end
