local addonName, ns = ...
local Bus, Compat, Modules, Storage = ns.Bus, ns.Compat, ns.Modules, ns.Storage

-- /lootoman selftest (techspec §9): calls Compat against the real client and
-- prints what the addon knows about itself. The output is for bug reports, so
-- it is not translated.
local SelfTest = {}
ns.SelfTest = SelfTest

-- Each check returns true, or false and what went wrong.
local checks = {
	{ "Has", function()
		return Compat.Has("C_AddOns.GetAddOnMetadata") and not Compat.Has("C_LootomanMissing.Nothing"),
			"wrong answer for a known or a missing path"
	end },
	{ "GetCharacterKey", function()
		local key = Compat.GetCharacterKey()
		return type(key) == "string" and key:find("-", 2, true) ~= nil, "got " .. tostring(key)
	end },
	{ "InCombat", function()
		return type(Compat.InCombat()) == "boolean", "not a boolean"
	end },
	{ "IsSecret", function()
		return Compat.IsSecret(1) == false, "a plain number is reported as secret"
	end },
	{ "IsAddOnLoaded", function()
		return Compat.IsAddOnLoaded(addonName), "Lootoman is not reported as loaded"
	end },
	{ "GetAddOnMetadata", function()
		local title = Compat.GetAddOnMetadata(addonName, "Title")
		return title == "Lootoman", "Title is " .. tostring(title)
	end },
	{ "GetBuildInfo", function()
		local _, _, _, interface = Compat.GetBuildInfo()
		return type(interface) == "number", "no interface number"
	end },
	{ "GetSaved", function()
		return Storage.readOnly or Compat.GetSaved("LootomanDB") == Storage.db, "LootomanDB is not the loaded table"
	end },
	{ "RegisterEvent", function()
		return Storage.db ~= nil and Storage.character ~= nil, "ADDON_LOADED or PLAYER_LOGIN was not received"
	end },
}

function SelfTest.Run()
	local say = ns.Print
	say("Self-test")

	local failed = 0
	for _, check in ipairs(checks) do
		local name, fn = check[1], check[2]
		local ran, ok, problem = pcall(fn)
		if ran and ok then
			say("  " .. name .. ": OK")
		else
			failed = failed + 1
			say("  " .. name .. ": FAILED, " .. tostring(ran and problem or ok))
		end
	end
	Compat.After(0, function()
		say("  After: OK")
	end)

	local version, build, _, interface = Compat.GetBuildInfo()
	say(("Client %s (%s), interface %s; addon %s"):format(tostring(version), tostring(build), tostring(interface),
		tostring(Compat.GetAddOnMetadata(addonName, "Version"))))
	say(("Character %s, profile %s"):format(tostring(Storage.character), Storage:GetProfileName()))
	say(("Saved data: schema %s%s"):format(tostring(Storage.db.schema),
		Storage.readOnly and ", read-only (saved by a newer version)" or ""))
	say(("Data set: %s; locale: %s"):format(ns.Data and ns.Data.set or "none", ns.Locales.current))

	for _, module in ipairs(Modules:List()) do
		local events = Bus:GetEvents(module)
		say(("Module %s: %s, events: %s"):format(module.name, module:IsActive() and "on" or "off",
			#events > 0 and table.concat(events, ", ") or "none"))
	end

	say(failed == 0 and "All checks passed." or (failed .. " check(s) failed."))
end
