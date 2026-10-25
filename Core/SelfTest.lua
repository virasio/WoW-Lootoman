local addonName, ns = ...
local Bus, Compat, Modules, Storage = ns.Bus, ns.Compat, ns.Modules, ns.Storage

-- /lootoman selftest (techspec §9): calls Compat against the real client and
-- prints what the addon knows about itself. The output is for bug reports, so
-- it is not translated.
local SelfTest = {}
ns.SelfTest = SelfTest

-- Each check returns true, false and what went wrong, or nil and why the
-- client cannot have it (not a failure: the addon turns that feature off).
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
	{ "Encode", function()
		if not Compat.CanEncode() then
			return nil, "no C_EncodingUtil, so Import and Share are off"
		end
		local value = Compat.Decode(Compat.Encode({ check = { 1, "two" } }))
		return type(value) == "table" and type(value.check) == "table" and value.check[2] == "two",
			"a text did not read back"
	end },
}

-- Lines that other parts add to the report (providers, modules): each builder
-- returns a line of text.
local reports = {}

function SelfTest.AddReport(build)
	reports[#reports + 1] = build
end

function SelfTest.Run()
	local say = ns.Print
	say("Self-test")

	local failed = 0
	for _, check in ipairs(checks) do
		local name, fn = check[1], check[2]
		local ran, ok, problem = pcall(fn)
		if ran and ok then
			say("  " .. name .. ": OK")
		elseif ran and ok == nil then
			say("  " .. name .. ": not available, " .. tostring(problem))
		else
			failed = failed + 1
			say("  " .. name .. ": FAILED, " .. tostring(ran and problem or ok))
		end
	end
	local scheduled, problem = pcall(Compat.After, 0, function()
		say("  After: OK")
	end)
	if not scheduled then
		failed = failed + 1
		say("  After: FAILED, " .. tostring(problem))
	end

	-- Each line is built under protection, so a broken call cannot stop the
	-- report; the line then shows the error instead.
	local function report(build)
		local ok, text = pcall(build)
		say(ok and text or ("(" .. tostring(text) .. ")"))
	end

	report(function()
		local version, build, _, interface = Compat.GetBuildInfo()
		return ("Client %s (%s), interface %s"):format(tostring(version), tostring(build), tostring(interface))
	end)
	report(function()
		return "Addon " .. tostring(Compat.GetAddOnMetadata(addonName, "Version"))
	end)
	report(function()
		return ("Character %s, profile %s"):format(tostring(Storage.character), Storage:GetProfileName())
	end)
	report(function()
		return ("Saved data: schema %s%s"):format(tostring(Storage.db.schema),
			Storage.readOnly and ", read-only (saved by a newer version)" or "")
	end)
	report(function()
		return ("Data set: %s; locale: %s"):format(ns.Data and ns.Data.set or "none", ns.Locales.current)
	end)
	for _, build in ipairs(reports) do
		report(build)
	end
	for _, module in ipairs(Modules:List()) do
		report(function()
			local events = Bus:GetEvents(module)
			return ("Module %s: %s, events: %s"):format(module.name, module:IsActive() and "on" or "off",
				#events > 0 and table.concat(events, ", ") or "none")
		end)
	end

	say(failed == 0 and "All checks passed." or (failed .. " check(s) failed."))
end
