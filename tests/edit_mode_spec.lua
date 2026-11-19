local Loader = require("tests.helpers.loader")

-- A stand-in for LibEditMode 18: it records frames and settings, and fires
-- its callbacks like the library (a "layout" callback runs at once when the
-- layout is already known).
local function newLibEditMode()
	local lib = { frames = {}, settings = {}, callbacks = {}, refreshed = 0, editing = false }
	lib.SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 }
	function lib:AddFrame(frame, callback, default, name)
		self.frames[frame] = { callback = callback, default = default, name = name }
	end
	function lib:AddFrameSettings(frame, settings)
		assert(self.frames[frame], "frame must be registered")
		self.settings[frame] = settings
	end
	function lib:AddFrameSettingsButtons(frame, buttons)
		assert(self.frames[frame], "frame must be registered")
		self.buttons = self.buttons or {}
		self.buttons[frame] = buttons
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
	function lib:RefreshFrameSettings()
		self.refreshed = self.refreshed + 1
	end
	-- Test helpers.
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
	-- What the library does when the player drops a frame.
	function lib.Drag(frame, point, x, y)
		frame:ClearAllPoints()
		frame:SetPoint(point, x, y)
		lib.frames[frame].callback(frame, lib.layout, point, x, y)
	end
	-- The library's own dialog (lib.internal.dialog), made with the first frame.
	local reset = { shown = true }
	function reset:SetShown(shown) self.shown = shown end
	lib.internal = { dialog = { Settings = { ResetButton = reset }, laidOut = 0 } }
	function lib.internal.dialog:Update(selection) self.selection, self.shown = selection, true end
	function lib.internal.dialog:Hide() self.shown = false end
	function lib.internal.dialog:Layout() self.laidOut = self.laidOut + 1 end
	-- Each frame's selection, which the player clicks to pick the frame.
	lib.frameSelections = {}
	local addFrame = lib.AddFrame
	function lib:AddFrame(frame, ...)
		addFrame(self, frame, ...)
		local selection = { parent = frame, scripts = {} }
		function selection:HookScript(name, fn) self.scripts[name] = fn end
		function selection:ShowSelected(selected) self.selected, self.isSelected = selected, true end
		function selection:ShowHighlighted() self.isSelected = false end
		self.frameSelections[frame] = selection
	end
	return lib
end

local function newFrame()
	local frame = { shown = true }
	function frame:ClearAllPoints() self.point = nil end
	function frame:SetPoint(point, x, y) self.point = { point, x, y } end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:SetMovable(movable) self.movable = movable end
	return frame
end

describe("Edit Mode", function()
	local ns, lib, module, frame, previews

	local SETTINGS = {
		{ kind = "slider", key = "rows", label = "Rows", tooltip = "How many rows.", min = 1, max = 20, step = 1, format = "%d rows" },
		{ kind = "slider", key = "fade", label = "Fade-out", min = 0.2, max = 3, step = 0.1 },
		{ kind = "dropdown", key = "direction", label = "Direction", choices = { { "up", "Up" }, { "down", "Down" } } },
		{ kind = "checkbox", key = "money", label = "Money" },
		{ kind = "dropdown", key = "look", label = "Look", generator = function(_, root) root.built = true end },
	}

	local function saved()
		return ns.Storage:GetSection("positions").TestFeed
	end

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		ns = Loader.LoadAddon()
		previews = {}
		module = ns.Modules:Register({
			name = "TestFeed",
			title = "Test feed",
			defaults = { enabled = true, rows = 8, fade = 1, direction = "up", money = true, look = "Default" },
			OnEnable = function(self)
				if not self.frame then
					self.frame = newFrame()
					ns.EditMode.Register(self, self.frame, {
						default = { point = "CENTER", x = 250, y = 0 },
						settings = SETTINGS,
						onEditMode = function(active) previews[#previews + 1] = active end,
					})
				end
				self.frame:Show()
			end,
			OnDisable = function(self)
				if self.frame then
					self.frame:Hide()
				end
			end,
		})
		Loader.Start(ns)
		frame = module.frame
	end)

	it("registers the frame under the module title, at its default position until the layout is known", function()
		assert.equals("Test feed", lib.frames[frame].name)
		assert.same({ point = "CENTER", x = 250, y = 0 }, lib.frames[frame].default)
		assert.same({ "CENTER", 250, 0 }, frame.point)
	end)

	it("keeps a dragged position per layout, in the profile", function()
		lib.SetLayout("Modern")
		lib.Drag(frame, "TOPLEFT", 10, -20)
		assert.same({ Modern = { point = "TOPLEFT", x = 10, y = -20 } }, saved())
		lib.SetLayout("Classic")
		assert.same({ "CENTER", 250, 0 }, frame.point)
		lib.SetLayout("Modern")
		assert.same({ "TOPLEFT", 10, -20 }, frame.point)
	end)

	it("uses the layout that is already known when a frame registers later", function()
		lib.SetLayout("Modern")
		lib.Drag(frame, "TOPLEFT", 10, -20)
		local other = newFrame()
		ns.EditMode.Register(module, other, { key = "TestFeed", default = { point = "CENTER", x = 0, y = 0 } })
		assert.same({ "TOPLEFT", 10, -20 }, other.point)
	end)

	it("moves the frame to the new profile's position when the profile changes", function()
		lib.SetLayout("Modern")
		lib.Drag(frame, "TOPLEFT", 10, -20)
		ns.Profiles.Switch(ns.Profiles.Create("Other"))
		assert.same({ "CENTER", 250, 0 }, frame.point)
		ns.Profiles.Switch("Default")
		assert.same({ "TOPLEFT", 10, -20 }, frame.point)
	end)

	it("follows a renamed layout and a copied one, in every profile, and forgets a deleted one", function()
		lib.SetLayout("Modern")
		lib.Drag(frame, "TOPLEFT", 10, -20)
		ns.Storage.db.profiles.Other = { sections = { positions = { TestFeed = { Modern = { point = "TOP", x = 1, y = 2 } } } } }
		lib.Fire("rename", "Modern", "Mine", 3)
		assert.same({ Mine = { point = "TOPLEFT", x = 10, y = -20 } }, saved())
		assert.same({ Mine = { point = "TOP", x = 1, y = 2 } }, ns.Storage.db.profiles.Other.sections.positions.TestFeed)
		lib.Fire("create", "Copy", 4, "Mine")
		assert.same({ point = "TOPLEFT", x = 10, y = -20 }, saved().Copy)
		lib.Fire("delete", "Copy")
		assert.is_nil(saved().Copy)
		lib.SetLayout("Mine")
		assert.same({ "TOPLEFT", 10, -20 }, frame.point)
	end)

	it("shows module settings in the Edit Mode dialog, bound to the profile", function()
		local rows, fade, direction, money = unpack(lib.settings[frame])
		assert.same({ 2, "Rows", "How many rows.", 8, 1, 20, 1 },
			{ rows.kind, rows.name, rows.desc, rows.default, rows.minValue, rows.maxValue, rows.valueStep })
		assert.equals("12 rows", rows.formatter(12))
		rows.set("Modern", 12)
		assert.equals(12, ns.Storage:Get("TestFeed", "rows"))
		assert.equals(12, rows.get("Modern"))
		fade.set("Modern", 0.1 + 0.2)
		assert.equals(0.3, ns.Storage:Get("TestFeed", "fade"))
		assert.equals(0, direction.kind)
		-- Built when the menu opens.
		assert.same({ { value = "up", text = "Up" }, { value = "down", text = "Down" } }, direction.values())
		direction.set("Modern", "down")
		assert.equals("down", ns.Storage:Get("TestFeed", "direction"))
		assert.equals(1, money.kind)
		money.set("Modern", false)
		assert.is_false(ns.Storage:Get("TestFeed", "money"))
		-- A dropdown with a menu of its own hands it on; the menu stores what it chooses.
		local look = lib.settings[frame][5]
		assert.same({ 0, "Look", SETTINGS[5].generator }, { look.kind, look.name, look.generator })
		assert.is_nil(look.values)
	end)

	it("refreshes an open Edit Mode dialog when a setting changes elsewhere", function()
		ns.Storage:Set("TestFeed", "rows", 3)
		assert.equals(0, lib.refreshed)
		lib.Fire("enter")
		ns.Storage:Set("TestFeed", "rows", 4)
		assert.equals(1, lib.refreshed)
	end)

	it("does not rebuild the dialog for a change made in it, so a dragged slider stays", function()
		local rows, _, direction, money = unpack(lib.settings[frame])
		lib.Fire("enter")
		rows.set("Modern", 5)
		direction.set("Modern", "down")
		money.set("Modern", false)
		assert.same({ 0, 5 }, { lib.refreshed, ns.Storage:Get("TestFeed", "rows") })
		ns.Storage:Set("TestFeed", "rows", 6)
		assert.equals(1, lib.refreshed)
	end)

	it("asks an active module for a preview while Edit Mode is on", function()
		lib.Fire("enter")
		lib.Fire("exit")
		assert.same({ true, false }, previews)
		ns.Modules:SetEnabled("TestFeed", false)
		lib.Fire("enter")
		assert.same({ true, false }, previews)
		ns.Modules:SetEnabled("TestFeed", true)
		assert.same({ true, false, true }, previews)
	end)

	it("shows a header as a divider with its title, and leaves it out where LibEditMode has no dividers", function()
		local grouped = { { kind = "header", label = "Shown" }, { kind = "checkbox", key = "money", label = "Money" } }
		local other = newFrame()
		ns.EditMode.Register(module, other, { key = "Other", default = { point = "CENTER", x = 0, y = 0 }, settings = grouped })
		assert.same({ "Money" }, { lib.settings[other][1].name })
		lib.SettingType.Divider = "divider"
		local third = newFrame()
		ns.EditMode.Register(module, third, { key = "Third", default = { point = "CENTER", x = 0, y = 0 }, settings = grouped })
		assert.same({ { kind = "divider", name = "Shown" }, "Money" }, { lib.settings[third][1], lib.settings[third][2].name })
	end)

	it("rejects an unknown setting kind", function()
		assert.error_matches(function()
			ns.EditMode.Register(module, newFrame(), { default = { point = "CENTER", x = 0, y = 0 },
				settings = { { kind = "radio", key = "rows", label = "Rows" } } })
		end, "TestFeed.rows: unknown Edit Mode setting kind radio")
	end)
	it("hides the dialog's Reset To Default button for a frame that asks, and only while the dialog shows it", function()
		local other = newFrame()
		local quiet = newFrame()
		ns.EditMode.Register(module, quiet, { default = { point = "CENTER", x = 0, y = 0 }, noReset = true })
		local dialog = lib.internal.dialog
		dialog:Update({ parent = quiet })
		assert.same({ false, 1 }, { dialog.Settings.ResetButton.shown, dialog.laidOut })
		dialog:Update({ parent = other })
		assert.is_true(dialog.Settings.ResetButton.shown)
		-- A second frame that asks hooks the dialog once.
		ns.EditMode.Register(module, newFrame(), { default = { point = "CENTER", x = 0, y = 0 }, noReset = true })
		dialog:Update({ parent = quiet })
		assert.equals(2, dialog.laidOut)
	end)

	it("opens a frame's own window instead of the dialog, the frame picked and movable still", function()
		local opened, closed = 0, 0
		local own = newFrame()
		ns.EditMode.Register(module, own, { default = { point = "CENTER", x = 0, y = 0 }, window = function() opened = opened + 1 end,
			closeWindow = function() closed = closed + 1 end })
		local dialog, selection = lib.internal.dialog, lib.frameSelections[own]
		-- The library shows the dialog as the frame is clicked; the click opens the window.
		dialog:Update(selection)
		selection.scripts.OnMouseDown(selection)
		assert.same({ false, true, true, 1 }, { dialog.shown, selection.selected, own.movable, opened })
		-- A click on the picked frame opens it again; not in a fight.
		selection.scripts.OnMouseDown(selection)
		ns.Compat.Test.SetCombat(true)
		selection.scripts.OnMouseDown(selection)
		assert.equals(2, opened)
		ns.Compat.Test.SetCombat(false)
		-- The library highlights the frame on the way to picking it, more than once: the
		-- window stays. Another frame or system picked leaves it highlighted: the window
		-- closes, once.
		lib.editing = true
		selection:ShowHighlighted()
		selection:ShowSelected(true)
		ns.Compat.Test.Advance(0)
		assert.equals(0, closed)
		selection:ShowHighlighted()
		selection:ShowHighlighted()
		ns.Compat.Test.Advance(0)
		assert.equals(1, closed)
		-- Other frames keep the dialog.
		dialog:Update({ parent = newFrame() })
		assert.is_true(dialog.shown)
	end)

	it("puts a frame back at its default place in the layout in use, and only there", function()
		lib.SetLayout("Modern")
		lib.Drag(frame, "TOPLEFT", 10, -20)
		lib.SetLayout("Classic")
		lib.Drag(frame, "TOPLEFT", 30, -40)
		assert.is_true(ns.EditMode.ResetPosition(frame))
		assert.same({ "CENTER", 250, 0 }, frame.point)
		assert.same({ Modern = { point = "TOPLEFT", x = 10, y = -20 } }, saved())
		assert.is_false(ns.EditMode.ResetPosition(newFrame()))
	end)

	it("tells the self-test the library's version and whether the dialog's reset button is there", function()
		local function line()
			local found
			for _, text in ipairs(ns.Compat.Test.state.printed) do
				found = text:match("Edit Mode: .*") or found
			end
			return found
		end
		ns.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		-- The fake LibStub gives no version.
		assert.equals("Edit Mode: LibEditMode nil; dialog found, reset button found, hooked yes", line())
		-- An update of the library that moved its dialog.
		lib.internal = nil
		ns.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		assert.equals("Edit Mode: LibEditMode nil; dialog NOT found, reset button NOT found, hooked yes", line())
	end)
end)

describe("Edit Mode without LibEditMode", function()
	it("leaves the frame where the module put it", function()
		rawset(_G, "LibStub", nil)
		local ns = Loader.LoadAddon()
		Loader.Start(ns)
		local module = ns.Modules:Register({ name = "TestFeed", defaults = { enabled = true } })
		local frame = newFrame()
		frame:SetPoint("TOP", 0, -120)
		assert.is_false(ns.EditMode.Register(module, frame, { default = { point = "CENTER", x = 0, y = 0 } }))
		assert.same({ "TOP", 0, -120 }, frame.point)
	end)

	it("tells the self-test so", function()
		rawset(_G, "LibStub", nil)
		local ns = Loader.LoadAddon()
		Loader.Start(ns)
		ns.Compat.Test.RunSlashCommand("LOOTOMAN", "debug selftest")
		assert.matches("Edit Mode: LibEditMode not found", table.concat(ns.Compat.Test.state.printed, "\n"))
	end)
end)
