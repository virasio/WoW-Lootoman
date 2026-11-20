local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- Moving the game's roll frames in Edit Mode (Modules/Rolls/Mover.lua).

-- A stand-in for LibEditMode, as far as the mover uses it.
local function newLibEditMode()
	local lib = { frames = {}, callbacks = {}, editing = false }
	function lib:AddFrame(frame, callback, default, name)
		self.frames[frame] = { callback = callback, default = default, name = name }
	end
	function lib:RegisterCallback(event, callback)
		self.callbacks[event] = self.callbacks[event] or {}
		table.insert(self.callbacks[event], callback)
		if event == "layout" and self.layout then
			callback(self.layout, 1)
		end
	end
	function lib:IsInEditMode()
		return self.editing
	end
	function lib.Fire(event, ...)
		if event == "enter" or event == "exit" then
			lib.editing = event == "enter"
		end
		for _, callback in ipairs(lib.callbacks[event] or {}) do
			callback(...)
		end
	end
	function lib.SetLayout(name)
		lib.layout = name
		lib.Fire("layout", name, 1)
	end
	function lib.Drag(frame, point, x, y)
		frame:ClearAllPoints()
		frame:SetPoint(point, x, y)
		lib.frames[frame].callback(frame, lib.layout, point, x, y)
	end
	return lib
end

describe("moving the game's roll frames", function()
	local ns, Test, lib, Mover, frames, container

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		container = UI.NewFake(Loader.ui.UIParent)
		frames = {}
		for index = 1, 4 do
			frames[index] = UI.NewFake(Loader.ui.UIParent)
			frames[index]:Hide()
		end
		Test.state.gameRollFrames = frames
		Test.state.gameRollContainer = container
		Test.state.gameRollSlots = { { frame = frames[1], slot = 1 }, { frame = frames[2], slot = 2 } }
		Loader.Start(ns)
		lib.SetLayout("Modern")
		Mover = ns.Rolls.Mover
	end)

	after_each(function()
		rawset(_G, "LibStub", nil)
	end)

	it("leaves the game's place alone while the frames were never moved", function()
		assert.is_false(Mover.Moved())
		Test.LayOutGameRolls()
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[1])
		assert.equals("Loot Roll Frames", lib.frames[Mover.Frame()].name)
		-- Above the look-alikes (DIALOG), so Edit Mode's selection covers them.
		assert.equals("FULLSCREEN", Mover.Frame():GetFrameStrata())
	end)

	it("stands the frames on its place once moved, after each of the game's layouts, 100 apart, the panels with them", function()
		lib.Drag(Mover.Frame(), "BOTTOMLEFT", 300, 400)
		assert.is_true(Mover.Moved())
		Test.LayOutGameRolls()
		assert.same({ "CENTER", Mover.Frame(), "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
		assert.same({ "CENTER", Mover.Frame(), "BOTTOM", 0, 150 }, frames[2].points[#frames[2].points])
		-- The container itself is never touched.
		assert.same({}, container.points)
		-- The panel stands beside its frame, wherever that is.
		Test.StartRoll(7, { name = "Item", link = "|Hitem:100|h" })
		frames[1].rollID = 7
		frames[1]:Show()
		assert.equals(frames[1], ns.Rolls.Module.PanelOf(frames[1]).frame.points[1][2])
	end)

	it("keeps a place per Edit Mode layout, and gives the game its place back on a reset", function()
		lib.Drag(Mover.Frame(), "BOTTOMLEFT", 300, 400)
		lib.SetLayout("Classic")
		assert.is_false(Mover.Moved())
		lib.SetLayout("Modern")
		assert.is_true(Mover.Moved())
		-- Reset To Default saves the default place: the game's place again.
		lib.Drag(Mover.Frame(), Mover.DEFAULT.point, Mover.DEFAULT.x, Mover.DEFAULT.y)
		assert.is_false(Mover.Moved())
		lib.Fire("enter")
		lib.Fire("exit")
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
	end)

	it("shows the demo's look-alikes on its place in Edit Mode", function()
		lib.Fire("enter")
		assert.is_true(Mover.Frame():IsShown())
		local card = ns.Rolls.Demo.cards[1]
		assert.is_true(card.frame:IsShown())
		assert.same({ "CENTER", Mover.Frame(), "BOTTOM", 0, 50 }, card.frame.points[1])
		lib.Fire("exit")
		assert.same({ false, false }, { Mover.Frame():IsShown(), card.frame:IsShown() })
	end)

	it("gives the game its place back when the module is turned off", function()
		lib.Drag(Mover.Frame(), "BOTTOMLEFT", 300, 400)
		Test.LayOutGameRolls()
		ns.Modules:SetEnabled("Rolls", false)
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
		-- Off, the game's layouts are its own.
		Test.LayOutGameRolls()
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
	end)
end)
