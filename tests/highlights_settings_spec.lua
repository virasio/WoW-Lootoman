local Loader = require("tests.helpers.loader")

describe("gathering highlights' game settings", function()
	local ns, Test, GameSettings

	-- The game settings as the player had them: soft targeting off, a short
	-- range, the nameplates of objects further than needed.
	local function playerSettings()
		return {
			SoftTargetInteract = "0",
			SoftTargetInteractRange = "10",
			SoftTargetInteractArc = "2",
			SoftTargetInteractOnlyInRange = "1",
			SoftTargetIconGameObject = "0",
			nameplateGameObjectMaxDistance = "40",
			SoftTargetNameplateInteract = "0",
		}
	end

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.state.consoleVars = playerSettings()
		Loader.Start(ns)
		GameSettings = ns.Highlights.GameSettings
		Test.state.cvarChanges = {}
	end)

	it("changes only the settings that differ, and remembers each one's old value and its own", function()
		GameSettings.Borrow()
		assert.same({ "SoftTargetInteract=3", "SoftTargetInteractRange=15", "SoftTargetInteractOnlyInRange=0", "SoftTargetIconGameObject=1" },
			Test.state.cvarChanges)
		local memory = Test.state.saved.LootomanDB.sections.highlightCVars
		assert.same({ 1, { old = "0", ours = "3" } }, { memory.schema, memory.values.SoftTargetInteract })
		-- Already far enough: the nameplates' distance is left alone.
		assert.is_nil(memory.values.nameplateGameObjectMaxDistance)
		assert.is_true(GameSettings.Holds("SoftTargetInteract"))
	end)

	it("skips a setting the client does not know", function()
		Test.state.consoleVars.SoftTargetInteractArc = nil
		Test.state.consoleVars.SoftTargetInteractOnlyInRange = nil
		GameSettings.Borrow()
		assert.is_nil(Test.state.saved.LootomanDB.sections.highlightCVars.values.SoftTargetInteractOnlyInRange)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
	end)

	it("gives back only what still holds its value, keeping what the player changed since", function()
		GameSettings.Borrow()
		-- The player turns the interact key off by hand meanwhile.
		Test.state.consoleVars.SoftTargetInteract = "1"
		GameSettings.GiveBack()
		local settings = Test.state.consoleVars
		assert.same({ "1", "10", "1", "0" }, { settings.SoftTargetInteract, settings.SoftTargetInteractRange,
			settings.SoftTargetInteractOnlyInRange, settings.SoftTargetIconGameObject })
		assert.same({}, Test.state.saved.LootomanDB.sections.highlightCVars.values)
	end)

	it("waits for the end of a fight", function()
		Test.SetCombat(true)
		GameSettings.Borrow()
		assert.same({}, Test.state.cvarChanges)
		Test.SetCombat(false)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		Test.SetCombat(true)
		GameSettings.GiveBack()
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		Test.SetCombat(false)
		assert.equals("0", Test.state.consoleVars.SoftTargetInteract)
	end)

	it("gives everything back at logout", function()
		GameSettings.Borrow()
		Test.FireEvent("PLAYER_LOGOUT")
		assert.same(playerSettings(), Test.state.consoleVars)
	end)

	it("gives back at the next start what a session left, while highlights are off", function()
		local saved = { LootomanDB = { schema = 3,
			profiles = { Default = { modules = { Highlights = { enabled = false } } } },
			sections = { highlightCVars = { schema = 1, values = { SoftTargetInteract = { old = "0", ours = "3" } } } } } }
		ns = Loader.LoadAddon({ gameType = "camelot" })
		ns.Compat.Test.state.consoleVars = { SoftTargetInteract = "3" }
		Loader.Start(ns, saved)
		assert.equals("0", ns.Compat.Test.state.consoleVars.SoftTargetInteract)
	end)
end)
