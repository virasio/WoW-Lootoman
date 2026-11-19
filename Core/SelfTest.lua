local addonName, ns = ...
local Bus, Compat, Modules, Storage = ns.Bus, ns.Compat, ns.Modules, ns.Storage

-- /ltm debug selftest: calls Compat against the real client and
-- notes what the addon knows about itself, for bug reports, so it is not
-- translated. Every line goes into the journal; the chat gets only what
-- failed and the verdict.
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
		return Storage:IsReadOnly() or Compat.GetSaved("LootomanDB") == Storage.db, "LootomanDB is not the loaded table"
	end },
	{ "RegisterEvent", function()
		return Storage.db ~= nil and Storage.character ~= nil, "ADDON_LOADED or PLAYER_LOGIN was not received"
	end },
	{ "GetCVar", function()
		local value = Compat.GetCVar("autoLootDefault")
		return type(value) == "string", "autoLootDefault is " .. tostring(value)
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

-- Runs every check; the lines go into the saved diagnostics, and are
-- returned (a line from a timer may still come). With options.print the chat
-- gets the failed checks, if any, and the verdict; a check not available on
-- the client is no failure. With options.anonymous (the bug report) the
-- character is not named, only whether its profile is the default one.
function SelfTest.Run(options)
	local toChat = options and options.print
	local saved = ns.Diagnostics.StartSelfTest()
	local function say(text, failure)
		saved[#saved + 1] = text
		if failure and toChat then
			ns.Print(text)
		end
	end
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
			say("  " .. name .. ": FAILED, " .. tostring(ran and problem or ok), true)
		end
	end
	local scheduled, problem = pcall(Compat.After, 0, function()
		say("  After: OK")
	end)
	if not scheduled then
		failed = failed + 1
		say("  After: FAILED, " .. tostring(problem), true)
	end

	-- Each line is built under protection, so a broken call cannot stop the
	-- report; the line then shows the error instead.
	-- A builder may also say that its line belongs in the chat.
	local function report(build)
		local ok, text, show = pcall(build)
		say(ok and text or ("(" .. tostring(text) .. ")"), ok and show)
	end

	report(function()
		local version, build, _, interface = Compat.GetBuildInfo()
		return ("Client %s (%s), interface %s"):format(tostring(version), tostring(build), tostring(interface))
	end)
	report(function()
		return "Addon " .. tostring(Compat.GetAddOnMetadata(addonName, "Version"))
	end)
	report(function()
		if options and options.anonymous then
			return "Profile " .. (Storage:GetProfileName() == Storage.DEFAULT_PROFILE and "Default" or "not Default")
		end
		return ("Character %s, profile %s"):format(tostring(Storage.character), Storage:GetProfileName())
	end)
	local READ_ONLY = { newer = ", read-only (saved by a newer version)", failed = ", read-only (the upgrade failed)" }
	report(function()
		return ("Saved data: schema %s%s"):format(tostring(Storage.db.schema), READ_ONLY[Storage.readOnlyReason] or "")
	end)
	-- The client fills in [Game] and [Family] of these TOC fields: they show
	-- what a new client (WoW Forever) calls itself in TOC conditions, as its
	-- project number does in code.
	report(function()
		return ("Game %s, family %s, project %s; data set: %s; locale: %s"):format(
			tostring(Compat.GetAddOnMetadata(addonName, "X-Game")),
			tostring(Compat.GetAddOnMetadata(addonName, "X-Family")),
			tostring(Compat.GetProjectID()),
			ns.Data and ns.Data.set or "none", ns.Locales.current)
	end)
	-- Every Compat function against the client: what it needs, and what it
	-- can do without (Compat.NEEDS).
	report(function()
		local names = {}
		for name in pairs(Compat.NEEDS or {}) do
			names[#names + 1] = name
		end
		table.sort(names)
		local ready, missing, absent = 0, {}, {}
		for _, name in ipairs(names) do
			local need = Compat.NEEDS[name]
			local lacks, gone = {}, {}
			for _, path in ipairs(need) do
				if not Compat.Has(path) then
					lacks[#lacks + 1] = path
				end
			end
			for _, path in ipairs(need.optional or {}) do
				if not Compat.Has(path) then
					gone[#gone + 1] = path
				end
			end
			if #lacks == 0 then
				ready = ready + 1
			else
				missing[#missing + 1] = ("%s (%s)"):format(name, table.concat(lacks, ", "))
			end
			if #gone > 0 then
				absent[#absent + 1] = ("%s (%s)"):format(name, table.concat(gone, ", "))
			end
		end
		local line = ("Compat: %d of %d functions have what they need"):format(ready, #names)
		if #missing > 0 then
			line = line .. "; missing: " .. table.concat(missing, "; ")
		end
		if #absent > 0 then
			line = line .. "; not on this client: " .. table.concat(absent, "; ")
		end
		-- A function without what it needs is shown in the chat too.
		return line, #missing > 0
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

	say(failed == 0 and "All checks passed." or (failed .. " check(s) failed."), true)
	if toChat then
		ns.Print("The full report is in the bug report window.")
	end
	return saved, failed
end
