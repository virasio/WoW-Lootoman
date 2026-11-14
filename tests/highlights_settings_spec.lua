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
		-- With highlights off, so only these calls change the settings.
		Loader.Start(ns, { LootomanDB = { schema = 3, profiles = { Default = { modules = { Highlights = { enabled = false } } } } } })
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

	it("switches the soft target's nameplate on only for what sparkles, and never off for a player who keeps it on", function()
		local settings = Test.state.consoleVars
		GameSettings.Gate(true)
		assert.equals("1", settings.SoftTargetNameplateInteract)
		GameSettings.Gate(false)
		assert.same({ "0", nil }, { settings.SoftTargetNameplateInteract,
			Test.state.saved.LootomanDB.sections.highlightCVars.values.SoftTargetNameplateInteract })
		-- In a fight it stays as the fight found it.
		GameSettings.Gate(true)
		Test.SetCombat(true)
		GameSettings.Gate(false)
		assert.equals("1", settings.SoftTargetNameplateInteract)
		Test.SetCombat(false)
		-- Given back with the rest.
		GameSettings.GiveBack()
		assert.equals("0", settings.SoftTargetNameplateInteract)
		-- The player's own nameplates stay on.
		settings.SoftTargetNameplateInteract = "1"
		GameSettings.Gate(true)
		GameSettings.Gate(false)
		assert.equals("1", settings.SoftTargetNameplateInteract)
	end)

	it("pauses soft targeting on a living unit until the player moves away, when it turned it on itself", function()
		GameSettings.Start()
		Test.state.position = { 10, 10 }
		assert.is_true(GameSettings.Pause("unit"))
		assert.same({ "0", true }, { Test.state.consoleVars.SoftTargetInteract, Test.state.saved.LootomanDB.sections.highlightCVars.paused })
		-- Three yards away: still paused; five: on again.
		Test.state.position = { 13, 10 }
		GameSettings.CheckPause()
		assert.is_true(GameSettings.IsPaused())
		Test.state.position = { 13, 14 }
		GameSettings.CheckPause()
		assert.same({ false, "3" }, { GameSettings.IsPaused(), Test.state.consoleVars.SoftTargetInteract })
		-- Without a position, three seconds.
		Test.state.position = nil
		GameSettings.Pause("unit")
		Test.Advance(2)
		GameSettings.CheckPause()
		assert.is_true(GameSettings.IsPaused())
		Test.Advance(1)
		GameSettings.CheckPause()
		assert.is_false(GameSettings.IsPaused())
	end)

	it("pauses as a fight begins, when the client still takes it, until the fight ends", function()
		GameSettings.Start()
		Test.FireEvent("PLAYER_REGEN_DISABLED")
		assert.equals("0", Test.state.consoleVars.SoftTargetInteract)
		-- A living unit in the fight changes nothing; neither does moving.
		Test.state.combat = true
		GameSettings.Pause("unit")
		GameSettings.CheckPause()
		assert.equals("0", Test.state.consoleVars.SoftTargetInteract)
		Test.SetCombat(false)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		-- Already in the lockdown: no pause.
		Test.SetCombat(true)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		Test.SetCombat(false)
		-- After Stop the fights mean nothing.
		GameSettings.Stop()
		Test.state.consoleVars.SoftTargetInteract = "3"
		Test.FireEvent("PLAYER_REGEN_DISABLED")
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
	end)

	it("never pauses the player's own soft targeting, and gives back the player's value from a pause", function()
		Test.state.consoleVars.SoftTargetInteract = "2"
		GameSettings.Start()
		assert.same({ "3", false }, { Test.state.consoleVars.SoftTargetInteract, GameSettings.Pause("unit") })
		GameSettings.Stop()
		assert.equals("2", Test.state.consoleVars.SoftTargetInteract)
		-- Off before: a pause, then highlights stop; it stays off.
		Test.state.consoleVars.SoftTargetInteract = "0"
		GameSettings.Start()
		GameSettings.Pause("unit")
		GameSettings.Stop()
		assert.same({ "0", {} }, { Test.state.consoleVars.SoftTargetInteract,
			Test.state.saved.LootomanDB.sections.highlightCVars.values })
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
