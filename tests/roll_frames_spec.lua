local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- Moving the game's roll frames in Edit Mode (Modules/RollFrames/RollFrames.lua).

-- A stand-in for LibEditMode, as far as the mover uses it.
local function newLibEditMode()
	local lib = { frames = {}, callbacks = {}, editing = false }
	-- Each frame gets its selection, as the library makes it: a child of the
	-- frame whose click picks the frame.
	lib.frameSelections = {}
	function lib:AddFrame(frame, callback, default, name)
		self.frames[frame] = { callback = callback, default = default, name = name }
		local selection = UI.NewFake(frame)
		selection:SetScript("OnMouseDown", function(picked) picked.picked = true end)
		self.frameSelections[frame] = selection
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
	local ns, Test, lib, RollFrames, frames, container

	local function start(saved)
		ns = Loader.LoadAddon({ gameType = "camelot", debug = true, skip = saved and saved.settings and {} or nil })
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
		RollFrames = ns.RollFrames
	end

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		start()
		-- On by default.
		assert.is_true(RollFrames:IsActive())
	end)

	after_each(function()
		rawset(_G, "LibStub", nil)
	end)

	it("leaves the game's place alone while the frames were never moved", function()
		assert.is_false(RollFrames.Moved())
		Test.LayOutGameRolls()
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[1])
		assert.equals("Loot Roll Frames", lib.frames[RollFrames.frame].name)
	end)

	it("stands the frames on its place once moved, after each of the game's layouts, 100 apart, the panels with them", function()
		lib.Drag(RollFrames.frame, "BOTTOMLEFT", 300, 400)
		assert.is_true(RollFrames.Moved())
		Test.LayOutGameRolls()
		assert.same({ "CENTER", RollFrames.frame, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
		assert.same({ "CENTER", RollFrames.frame, "BOTTOM", 0, 150 }, frames[2].points[#frames[2].points])
		-- The container itself is never touched.
		assert.same({}, container.points)
		-- The panel stands beside its frame, wherever that is.
		Test.StartRoll(7, { name = "Item", link = "|Hitem:100|h" })
		frames[1].rollID = 7
		frames[1]:Show()
		assert.equals(frames[1], ns.Rolls.Module.PanelOf(frames[1]).frame.points[1][2])
	end)

	it("keeps a place per Edit Mode layout, and gives the game its place back on a reset", function()
		lib.Drag(RollFrames.frame, "BOTTOMLEFT", 300, 400)
		lib.SetLayout("Classic")
		assert.is_false(RollFrames.Moved())
		lib.SetLayout("Modern")
		assert.is_true(RollFrames.Moved())
		-- Reset To Default saves the default place: the game's place again.
		lib.Drag(RollFrames.frame, RollFrames.DEFAULT.point, RollFrames.DEFAULT.x, RollFrames.DEFAULT.y)
		assert.is_false(RollFrames.Moved())
		lib.Fire("enter")
		lib.Fire("exit")
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
	end)

	it("shows look-alikes on its place in Edit Mode, with the loot rolls' panels beside them under the selection", function()
		lib.Fire("enter")
		assert.is_true(RollFrames.frame:IsShown())
		local card = RollFrames.Cards()[1]
		assert.same({ true, "CENTER", RollFrames.frame }, { card.frame:IsShown(), card.frame.points[1][1], card.frame.points[1][2] })
		-- The selection reaches over the panels at the frames' right. Its
		-- template fixes it at MEDIUM, frame level 1000: the look-alikes and the
		-- panels stand on MEDIUM too, lower, under it; the selection is the library's own.
		local selection = lib.frameSelections[RollFrames.frame]
		assert.same({ "BOTTOMRIGHT", RollFrames.frame, "BOTTOMRIGHT", 194, 0 }, selection.points[2])
		assert.same({ "MEDIUM", 100 }, { card.frame:GetFrameStrata(), card.frame:GetFrameLevel() })
		assert.equals("MEDIUM", selection:GetFrameStrata())
		local panel = nil
		for _, frame in ipairs(Loader.ui.frames) do
			if frame.points[1] and frame.points[1][2] == card.frame and frame.points[1][3] == "RIGHT" then
				panel = frame
			end
		end
		assert.is_true(panel ~= nil and panel:IsShown())
		assert.same({ "MEDIUM", 100 }, { panel:GetFrameStrata(), panel:GetFrameLevel() })
		-- The demo's own look-alikes and panels stay on DIALOG, as the game's frames.
		Test.SetItems({ [100] = { name = "Tracker's Pants", link = "|cff1eff00|Hitem:100|h[Tracker's Pants]|h|r", quality = 2 } })
		ns.Rolls.Demo.Start("dung", { 100 })
		assert.equals("DIALOG", ns.Rolls.Demo.cards[1].frame:GetFrameStrata())
		lib.Fire("exit")
		assert.same({ false, false, false }, { RollFrames.frame:IsShown(), card.frame:IsShown(), panel:IsShown() })
	end)

	it("works only while the loot rolls are tracked", function()
		ns.Modules:SetEnabled("Rolls", false)
		assert.same({ false, true }, { RollFrames:IsActive(), ns.Storage:Get("RollFrames", "enabled") })
		lib.Fire("enter")
		assert.is_nil(RollFrames.Cards()[1])
		lib.Fire("exit")
		ns.Modules:SetEnabled("Rolls", true)
		assert.is_true(RollFrames:IsActive())
	end)

	it("shows no panels in Edit Mode while Show Who Rolled What is off, the selection over the look-alikes only", function()
		ns.Storage:Set("Rolls", "panels", false)
		lib.Fire("enter")
		local card = RollFrames.Cards()[1]
		assert.is_true(card.frame:IsShown())
		local selection = lib.frameSelections[RollFrames.frame]
		assert.same({ "BOTTOMRIGHT", RollFrames.frame, "BOTTOMRIGHT", 0, 0 }, selection.points[2])
		for _, frame in ipairs(Loader.ui.frames) do
			local anchored = frame.points[1] and frame.points[1][2] == card.frame and frame.points[1][3] == "RIGHT"
			assert.is_falsy(anchored and frame:IsShown())
		end
	end)

	it("gives the game its place back when turned off, and leaves its layouts alone then", function()
		lib.Drag(RollFrames.frame, "BOTTOMLEFT", 300, 400)
		Test.LayOutGameRolls()
		ns.Modules:SetEnabled("RollFrames", false)
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
		Test.LayOutGameRolls()
		assert.same({ "CENTER", container, "BOTTOM", 0, 50 }, frames[1].points[#frames[1].points])
		-- Off, nothing in Edit Mode.
		lib.Fire("enter")
		assert.is_false(RollFrames.frame:IsShown())
	end)

	it("shows worn gear on the look-alikes for an item the game has not loaded", function()
		Test.state.worn = { [7] = "|cff1eff00|Hitem:100|h[Tracker's Pants]|h|r" }
		Test.SetItems({ [100] = { name = "Tracker's Pants", link = "|cff1eff00|Hitem:100|h[Tracker's Pants]|h|r", quality = 2 } })
		lib.Fire("enter")
		assert.equals("Tracker's Pants", RollFrames.Cards()[2].frame.name:GetText())
	end)

	it("picks its frame as Edit Mode opens, after the Edit button's click", function()
		ns.EditMode.PickWhenOpen(RollFrames.frame)
		local selection = lib.frameSelections[RollFrames.frame]
		assert.is_nil(selection.picked)
		lib.Fire("enter")
		assert.is_true(selection.picked)
	end)
end)

describe("the Edit button beside the roll frames' checkbox", function()
	it("is a secure button running the game's /editmode, enabled while moving is allowed", function()
		local SettingsAPI = require("tests.mocks.SettingsAPI")
		SettingsAPI.Install()
		local ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Loader.Start(ns)
		local page = ns.SettingsPanel.main
		local button = page.switchButtons.RollFrames
		assert.same({ "SecureActionButtonTemplate, UIPanelButtonTemplate", "macro", "/editmode", "Edit" },
			{ button.template, button:GetAttribute("type"), button:GetAttribute("macrotext"), button.text })
		-- Right after the checkbox's label: on the checkbox itself, since the
		-- client refuses to anchor a protected button to a font string (the UI
		-- mock refuses it too). Enabled while moving is allowed, which it is by default.
		local check
		for _, item in ipairs(page.items) do
			if item.text == "Move the Loot Roll Frames in Edit Mode" then
				check = item.region
			end
		end
		assert.same({ "LEFT", check, "RIGHT", 4 + check.label:GetStringWidth() + 12, 0 }, button.points[1])
		assert.equals(282, button.points[1][4])
		page:Refresh()
		assert.is_true(button:IsEnabled())
		ns.Modules:SetEnabled("RollFrames", false)
		page:Refresh()
		assert.is_false(button:IsEnabled())
		-- The note under the checkbox says where Edit Mode is; the checkbox
		-- stands in the loot rolls' block, after the panels' option, greyed
		-- while the game's frames are hidden and while the loot rolls are off.
		local at, panels, ninja
		for index, item in ipairs(page.items) do
			if item.text == "Move the Loot Roll Frames in Edit Mode" then
				at = index
			elseif item.text == "Show Who Rolled What" then
				panels = index
			elseif item.text == "Detect Ninja Looters" then
				ninja = index
			end
		end
		assert.same({ panels + 1, ninja - 1, 24 }, { at, at, page.items[at].indent })
		assert.matches("Edit Mode", page.items[at].region.note:GetText())
		ns.Modules:SetEnabled("RollFrames", true)
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		page:Refresh()
		assert.same({ false, false }, { check.enabled, button:IsEnabled() })
		ns.Storage:Set("Rolls", "hideGameFrames", false)
		ns.Modules:SetEnabled("Rolls", false)
		page:Refresh()
		assert.same({ false, false }, { check.enabled, button:IsEnabled() })
	end)
end)
