local Loader = require("tests.helpers.loader")

-- Forever Leveling BiS and Pawn in the four states an integration can be in
-- (Integrations/ForeverLevelingBiS.lua, Integrations/Pawn.lua).

local LINK = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"

local function report(ns, name)
	for _, line in ipairs((ns.SelfTest.Run())) do
		local found = line:match(name .. ": .*")
		if found then
			return found
		end
	end
end

describe("Forever Leveling BiS", function()
	local ns, Test, FLB, changed

	-- Its API version 2, as its API.md describes it.
	local function install(options)
		options = options or {}
		rawset(_G, "ForeverLevelingBiS_API", {
			version = options.version or 2,
			GetGain = function(link)
				if options.fails then
					error("GetGain: broken")
				end
				return ({ [LINK] = 12.5, loading = nil })[link], link == "loading"
			end,
			OnChanged = function(fn) changed = fn end,
		})
		Test.state.addons.ForeverLevelingBiS = true
	end

	before_each(function()
		rawset(_G, "ForeverLevelingBiS_API", nil)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Loader.Start(ns)
		FLB = ns.Integrations.ForeverLevelingBiS
	end)

	after_each(function()
		rawset(_G, "ForeverLevelingBiS_API", nil)
	end)

	it("is off when it is not installed", function()
		assert.same({ "missing", nil }, { FLB.State(), FLB.Gain(LINK) })
		assert.equals("Forever Leveling BiS: not installed", report(ns, "Forever Leveling BiS"))
	end)

	it("is off when it is loaded without its API, or an older one", function()
		Test.state.addons.ForeverLevelingBiS = true
		assert.equals("noApi", FLB.State())
		install({ version = 1 })
		assert.same({ "noApi", nil }, { FLB.State(), FLB.Gain(LINK) })
	end)

	it("gives what an item gains, whether it is still loading, and tells when its answers change", function()
		install()
		assert.same({ "working", 12.5, false }, { FLB.State(), FLB.Gain(LINK) })
		assert.same({ nil, true }, { FLB.Gain("loading") })
		local heard = 0
		FLB.OnChanged(function() heard = heard + 1 end)
		changed()
		assert.equals(1, heard)
		assert.equals("Forever Leveling BiS: working", report(ns, "Forever Leveling BiS"))
	end)

	it("turns off after its API raises an error, and the self-test says so", function()
		install({ fails = true })
		assert.is_nil(FLB.Gain(LINK))
		assert.equals("failed", FLB.State())
		assert.matches("off after an error: .*GetGain: broken", report(ns, "Forever Leveling BiS"))
	end)
end)

describe("Pawn", function()
	local ns, Test, Pawn

	-- Pawn 2.14.8's functions, as far as the advice uses them.
	local function install(options)
		options = options or {}
		rawset(_G, "PawnIsInitialized", options.initialized ~= false)
		rawset(_G, "PawnCanItemHaveStats", function(link) return link ~= "potion" end)
		rawset(_G, "PawnGetItemData", function(link)
			if options.fails then
				error("PawnGetItemData: broken")
			end
			return { Link = link ~= "loading" and link or nil }
		end)
		rawset(_G, "PawnIsItemAnUpgrade", function(item)
			if item.Link == LINK then
				return { { LocalizedScaleName = "Fury", PercentUpgrade = 0.15 }, { LocalizedScaleName = "Arms", PercentUpgrade = 0.05 } }
			end
		end)
		Test.state.addons.Pawn = true
	end

	local function uninstall()
		for _, name in ipairs({ "PawnIsInitialized", "PawnCanItemHaveStats", "PawnGetItemData", "PawnIsItemAnUpgrade" }) do
			rawset(_G, name, nil)
		end
	end

	before_each(function()
		uninstall()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Loader.Start(ns)
		Pawn = ns.Integrations.Pawn
	end)

	after_each(uninstall)

	it("is off when it is not installed", function()
		assert.same({ "missing", nil }, { Pawn.State(), Pawn.Upgrade(LINK) })
		assert.equals("Pawn: not installed", report(ns, "Pawn"))
	end)

	it("is off when it is loaded without its functions, or not ready yet", function()
		Test.state.addons.Pawn = true
		assert.equals("noApi", Pawn.State())
		install({ initialized = false })
		assert.same({ "noApi", nil }, { Pawn.State(), Pawn.Upgrade(LINK) })
	end)

	it("gives the best upgrade and its scale, false for one that is not, and waits for an item loading", function()
		install()
		assert.same({ "working", 0.15, "Fury" }, { Pawn.State(), Pawn.Upgrade(LINK) })
		assert.is_false(Pawn.Upgrade("|Hitem:200|h[Ring]|h"))
		assert.same({ nil, true }, { Pawn.Upgrade("loading") })
		assert.is_nil(Pawn.Upgrade("potion"))
		assert.equals("Pawn: working", report(ns, "Pawn"))
	end)

	it("turns off after its API raises an error, and the self-test says so", function()
		install({ fails = true })
		assert.is_nil(Pawn.Upgrade(LINK))
		assert.equals("failed", Pawn.State())
		assert.matches("off after an error: .*PawnGetItemData: broken", report(ns, "Pawn"))
	end)
end)
