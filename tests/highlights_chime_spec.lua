local Loader = require("tests.helpers.loader")

-- The highlights' chime for one character, on one object
-- (Modules/Highlights/Highlights.lua).

describe("the highlights' chime", function()
	local ns, Test, module

	local function target(facts)
		Test.state.softInteract = facts
		Test.FireEvent("PLAYER_SOFT_INTERACT_CHANGED")
	end

	local function herb(objectID)
		return { isObject = true, isDead = false, cursor = 3, inReach = true, name = "A herb", objectID = objectID }
	end

	local function start(character)
		ns = Loader.LoadAddon({ gameType = "camelot", debug = true })
		Test = ns.Compat.Test
		Test.state.consoleVars = { SoftTargetInteract = "0", SoftTargetIconGameObject = "0", SoftTargetNameplateInteract = "0",
			SoftTargetIconInteract = "1" }
		Test.state.cursorFiles = { GatherHerbs = 3, UnableGatherHerbs = 4 }
		Test.state.gatheringSkills = { herbs = true, ore = false }
		Test.state.nameplates = { softinteract = _G.CreateFrame("Frame") }
		Test.state.character = character
		module = ns.Modules:Get("Highlights")
		-- The test character stands for the one it is meant for.
		module.CHIME.key = module.Hash("Tester-Realm")
		Loader.Start(ns)
	end

	local function sounds()
		return Test.state.sounds or {}
	end

	it("plays for that character as the object starts to sparkle, once, and again only after a while", function()
		start("Tester-Realm")
		local object = next(module.CHIME.objects)
		target(herb(object))
		assert.same({ { module.CHIME.file, "Master" } }, sounds())
		-- Still lit, re-read by the ticker: no second chime.
		module:Evaluate(true)
		target(herb(1617))
		target(herb(object))
		assert.equals(1, #sounds())
		Test.Advance(module.CHIME.wait)
		target(herb(1617))
		target(herb(object))
		assert.equals(2, #sounds())
	end)

	it("plays for nobody else, and never on an object that does not sparkle", function()
		start("Someone-Else")
		target(herb(176589))
		assert.same({}, sounds())
		start("Tester-Realm")
		ns.Storage:Set("Highlights", "herbs", false)
		target(herb(176589))
		assert.same({}, sounds())
	end)

	it("keeps the character as a number (a djb2 hash of its key), not as a name", function()
		start("Tester-Realm")
		assert.equals(2342020826, module.Hash("Tester-Realm"))
		assert.same({ [176589] = true }, module.CHIME.objects)
		local file = assert(io.open("Modules/Highlights/Highlights.lua"))
		local source = file:read("*a")
		file:close()
		assert.is_truthy(source:find("CHIME = { key = %d+,"))
	end)
end)
