local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("gathering highlights", function()
	local ns, Test, module, plate

	-- Made-up cursor file IDs.
	local CURSORS = { Mine = 1, UnableMine = 2, GatherHerbs = 3, UnableGatherHerbs = 4, PickLock = 5, UnablePickLock = 6, Quest = 7 }

	local function playerSettings()
		return { SoftTargetInteract = "0", SoftTargetInteractRange = "10", SoftTargetInteractArc = "2",
			SoftTargetInteractOnlyInRange = "1", SoftTargetIconGameObject = "0", nameplateGameObjectMaxDistance = "40",
			SoftTargetNameplateInteract = "0" }
	end

	-- The soft target becomes this object (or unit), and the game says so.
	local function target(facts)
		Test.state.softInteract = facts
		Test.FireEvent("PLAYER_SOFT_INTERACT_CHANGED")
	end

	local function herb(extra)
		local facts = { isObject = true, isDead = false, cursor = 3, inReach = true, name = "Peacebloom", objectID = 1617 }
		for key, value in pairs(extra or {}) do
			facts[key] = value
		end
		return facts
	end

	local function lit()
		return module.lit and module.lit.kind or nil
	end

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.state.consoleVars = playerSettings()
		Test.state.cursorFiles = CURSORS
		Test.state.gatheringSkills = { herbs = true, ore = false }
		plate = _G.CreateFrame("Frame")
		Test.state.nameplates = { softinteract = plate }
		Loader.Start(ns)
		module = ns.Modules:Get("Highlights")
	end)

	it("exists only on WoW Forever", function()
		assert.is_nil(Loader.LoadAddon().Modules:Get("Highlights"))
		assert.is_true(module:IsActive())
	end)

	it("lights a herb in reach and switches the soft target's nameplate on for it", function()
		target(herb())
		assert.same({ "herbs", "ready", plate }, { lit(), module.lit.state, module.lit.plate })
		assert.equals("1", Test.state.consoleVars.SoftTargetNameplateInteract)
		-- Another target that is nothing: the light and the nameplate go.
		target({ isObject = true, cursor = 99, name = "Signpost" })
		assert.same({ nil, "0" }, { lit(), Test.state.consoleVars.SoftTargetNameplateInteract })
		target(nil)
		assert.is_nil(lit())
	end)

	it("shows how far and how usable the object is", function()
		target(herb({ inReach = false }))
		assert.equals("far", module.lit.state)
		target(herb({ cursor = 4 }))
		assert.equals("locked", module.lit.state)
		-- Without the reach check, an Unable cursor counts as out of reach.
		local unknownReach = herb({ cursor = 4 })
		unknownReach.inReach = nil
		target(unknownReach)
		assert.equals("far", module.lit.state)
	end)

	it("lights ore only with Mining, unless the player wants herbs and ore without the profession", function()
		target({ isObject = true, cursor = 1, inReach = true, name = "Copper Vein" })
		assert.is_nil(lit())
		module:Set("gatherable", false)
		assert.equals("ore", lit())
		-- Herbs on, ore off: herbs for another character's Herbalism, no ore.
		Test.state.gatheringSkills = { herbs = false, ore = false }
		Test.FireEvent("SKILL_LINES_CHANGED")
		module:Set("ore", false)
		assert.is_nil(lit())
		target(herb())
		assert.equals("herbs", lit())
		-- An unknown skill lights.
		module:Set("gatherable", true)
		Test.state.gatheringSkills = {}
		Test.FireEvent("SPELLS_CHANGED")
		assert.equals("herbs", lit())
	end)

	it("applies each kind's switch at once", function()
		target(herb())
		module:Set("herbs", false)
		assert.is_nil(lit())
		target({ isObject = true, cursor = 7, name = "Wanted Poster" })
		assert.equals("quest", lit())
		module:Set("quest", false)
		assert.is_nil(lit())
		target({ isObject = true, cursor = 5, name = "Battered Chest" })
		assert.equals("chests", lit())
	end)

	it("greys out the profession option while herbs and ore are both off", function()
		local found
		for _, setting in ipairs(module.mainSettings) do
			if setting.key == "gatherable" then
				found = setting
			end
		end
		assert.is_true(found.enabledWhen())
		module:Set("herbs", false)
		module:Set("ore", false)
		assert.is_false(found.enabledWhen())
	end)

	it("never lights a creature or a corpse, and pauses soft targeting on a living unit", function()
		target(herb())
		target({ isObject = false, isDead = false, name = "Stormwind Guard" })
		assert.same({ nil, "0", "0" }, { lit(), Test.state.consoleVars.SoftTargetNameplateInteract, Test.state.consoleVars.SoftTargetInteract })
		-- Paused, the game has no soft target; the re-reading every few tenths of a
		-- second resumes it after three seconds without a position.
		Test.state.softInteract = nil
		Test.Advance(3)
		module.ticker.scripts.OnUpdate(module.ticker, 0.2)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		target({ isObject = false, isDead = true, name = "Kobold Vermin" })
		assert.is_nil(lit())
	end)

	it("learns a looted object that showed as none of the kinds as a chest, but never from fishing", function()
		local barrel = { isObject = true, cursor = 99, name = "Barrel of Milk", objectID = 3658 }
		target(barrel)
		assert.is_nil(lit())
		Test.state.lootSources = { 3658 }
		Test.FireEvent("LOOT_OPENED")
		target(nil)
		target(barrel)
		assert.equals("chests", lit())
		assert.same({ [3658] = true }, Test.state.saved.LootomanDB.sections.lootContainers.values)
		-- A bobber looted is never learned.
		local bobber = { isObject = true, cursor = 98, name = "Fishing Bobber", objectID = 35591 }
		target(bobber)
		Test.state.loot.fishing = true
		Test.state.lootSources = { 35591 }
		Test.FireEvent("LOOT_OPENED")
		target(bobber)
		assert.is_nil(lit())
	end)

	it("re-reads the target while it sparkles", function()
		target(herb())
		assert.is_true(module.ticker.shown)
		Test.state.softInteract.inReach = false
		module.ticker.scripts.OnUpdate(module.ticker, 0.1)
		assert.equals("ready", module.lit.state)
		module.ticker.scripts.OnUpdate(module.ticker, 0.1)
		assert.equals("far", module.lit.state)
		target(nil)
		assert.is_false(module.ticker.shown)
	end)

	it("lets everything go and gives the game settings back when turned off", function()
		target(herb())
		ns.Modules:SetEnabled("Highlights", false)
		assert.same({ false, nil }, { module:IsActive(), module.lit })
		assert.same(playerSettings(), Test.state.consoleVars)
		-- Targets mean nothing now.
		target(herb())
		assert.is_nil(module.lit)
	end)

	it("undoes a start that stops halfway", function()
		ns.Modules:SetEnabled("Highlights", false)
		local read = ns.Compat.GetSoftInteract
		ns.Compat.GetSoftInteract = function() error("broken soft target") end
		ns.Modules:SetEnabled("Highlights", true)
		assert.is_false(module:IsActive())
		assert.same(playerSettings(), Test.state.consoleVars)
		assert.matches("broken soft target", Test.state.errors[#Test.state.errors])
		ns.Compat.GetSoftInteract = read
	end)

	it("puts its switches in profile texts on WoW Forever, and retail leaves them out", function()
		module:Set("ore", false)
		assert.same({ ore = false }, ns.Share.Get("module:Highlights"))
		local retail = Loader.Start(Loader.LoadAddon())
		local text = retail.Share.PREFIX .. "2:" .. retail.Compat.Encode({ format = 2, collections = {},
			sections = { ["module:Highlights"] = { ore = false }, ["module:AutoLoot"] = { confirmBind = false } } })
		local read = retail.Share.Read(text)
		assert.same({ { "module:AutoLoot" }, 1 }, { read.names, read.skipped })
	end)

	it("reports to the self-test", function()
		Test.RunSlashCommand("LOOTOMAN", "selftest")
		local report
		for _, line in ipairs(Test.state.printed) do
			if line:find("SoftTargetInteract=", 1, true) then
				report = line
			end
		end
		assert.matches("SoftTargetInteract=3", report)
		-- The plain cursor names the fake client knows.
		assert.matches("cursors 4 of", report)
	end)
end)

describe("gathering highlights on the options page", function()
	it("is a switch with a checkbox for each kind and the profession option under it, on WoW Forever only", function()
		SettingsAPI.Install()
		local ns = Loader.Start(Loader.LoadAddon({ gameType = "camelot", skip = {} }))
		local texts = {}
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			texts[#texts + 1] = tostring(entry.text)
		end
		assert.is_truthy(table.concat(texts, "|"):find(
			"Highlight lootable objects|Herbs|Ore|Chests|Quest objects|Only herbs and ore you can gather", 1, true))
		SettingsAPI.Install()
		ns = Loader.Start(Loader.LoadAddon({ skip = {} }))
		texts = {}
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			texts[#texts + 1] = tostring(entry.text)
		end
		assert.is_falsy(table.concat(texts, "|"):find("Highlight lootable objects", 1, true))
	end)
end)
