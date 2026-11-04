local Loader = require("tests.helpers.loader")

-- Currency bars on screen.
describe("currency bars", function()
	local ns, lib, Test, Bars, Sets

	-- Just enough of LibEditMode: the frames, their settings and buttons, and
	-- the callbacks a test fires.
	local function newLibEditMode()
		local fake = { frames = {}, settings = {}, buttons = {}, callbacks = {},
			SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2, Divider = "divider" } }
		function fake:AddFrame(frame, onMoved, default, name) self.frames[frame] = { onMoved = onMoved, default = default, name = name } end
		function fake:AddFrameSettings(frame, settings) self.settings[frame] = settings end
		function fake:AddFrameSettingsButtons(frame, buttons) self.buttons[frame] = buttons end
		function fake:RegisterCallback(event, callback)
			self.callbacks[event] = self.callbacks[event] or {}
			table.insert(self.callbacks[event], callback)
		end
		function fake:IsInEditMode() return self.editing == true end
		function fake:RefreshFrameSettings() end
		function fake.Fire(event, ...)
			fake.editing = event == "enter" or (event ~= "exit" and fake.editing)
			for _, callback in ipairs(fake.callbacks[event] or {}) do
				callback(...)
			end
		end
		return fake
	end

	local function slot(index)
		return Bars.slots[index]
	end

	-- What a bar shows: "count" per shown entry, and "»" when some are hidden.
	local function shown(index)
		local list = {}
		for _, button in ipairs(slot(index).buttons) do
			if button.shown and button.entry then
				list[#list + 1] = button.Count.text
			end
		end
		if slot(index).frame.More.shown then
			list[#list + 1] = "»"
		end
		return list
	end

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		Test.SetCurrency(3008, { name = "Valorstones", icon = 1, quantity = 500, max = 2000, backpack = 1 })
		Test.SetCurrency(3110, { name = "Gilded Crest", icon = 2, quantity = 20, max = 90, totalEarned = 90, capsTotalEarned = true })
		Test.SetCurrency(2815, { name = "Resonance Crystals", icon = 3, quantity = 4000, backpack = 2 })
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 4 } })
		Loader.Start(ns)
		Test.SetBags({ [0] = { size = 4, items = { [1] = { itemID = 2589, count = 7, name = "Linen Cloth", quality = 1 } } } })
		Bars = ns.Modules:Get("Bars")
		Sets = Bars.Sets
		lib.Fire("layout", "Modern")
	end)

	after_each(function()
		rawset(_G, "LibStub", nil)
	end)

	it("start with one bar of the backpack's currencies", function()
		assert.same({ "500 / 2000", "4000" }, shown(1))
		assert.is_true(slot(1).frame.shown)
		assert.equals("Currency bar 1", lib.frames[slot(1).frame].name)
	end)

	it("show currencies and bag items, a capped one with its cap, red at the cap", function()
		Sets.Get("Default").bars[1].entries = { { kind = "currency", id = 3110 }, { kind = "item", id = 2589 }, { kind = "currency", id = 3008 } }
		Sets.Changed("Default")
		assert.same({ "20", "7", "500 / 2000" }, shown(1))
		local buttons = slot(1).buttons
		assert.same({ 1, 0.13, 0.13 }, buttons[1].Count.color)
		assert.same({ 1, 1, 1 }, buttons[3].Count.color)
		Test.ChangeCurrency(3008, 1500)
		assert.same({ 1, 0.13, 0.13 }, buttons[3].Count.color)
		Test.SetBags({ [0] = { size = 4 } })
		assert.equals("0", buttons[2].Count.text)
	end)

	it("lay entries out from the left edge a gap apart, and hide what does not fit behind the arrow", function()
		local bar = Sets.Get("Default").bars[1]
		bar.entries = { { kind = "currency", id = 3008 }, { kind = "currency", id = 2815 }, { kind = "item", id = 2589 } }
		Sets.Changed("Default")
		-- 22 for the icon, 3, then the text at 7 pixels a letter.
		local buttons = slot(1).buttons
		assert.same({ 0, 95 + 6, 101 + 53 + 6 }, { buttons[1].x, buttons[2].x, buttons[3].x })
		bar.width = 160
		Sets.Changed("Default")
		assert.same({ "500 / 2000", "»" }, shown(1))
		slot(1).frame.More.scripts.OnClick(slot(1).frame.More)
		local menu = Loader.ui.contextMenu
		assert.same({ "|T3:0|t Resonance Crystals  4000", "|T4:0|t Linen Cloth  7" }, { menu.entries[1].text, menu.entries[2].text })
	end)

	it("move an entry dragged along the bar, outside Edit Mode", function()
		local bar = Sets.Get("Default").bars[1]
		local first = slot(1).buttons[1]
		first.scripts.OnDragStart(first)
		Loader.ui.cursor = { 150, 0 }
		first.scripts.OnDragStop(first)
		assert.same({ { kind = "currency", id = 2815 }, { kind = "currency", id = 3008 } }, bar.entries)
		assert.same({ "4000", "500 / 2000" }, shown(1))
		lib.Fire("enter")
		first = slot(1).buttons[1]
		first.scripts.OnDragStart(first)
		Loader.ui.cursor = { 500, 0 }
		first.scripts.OnDragStop(first)
		assert.same({ { kind = "currency", id = 2815 }, { kind = "currency", id = 3008 } }, bar.entries)
	end)

	it("keep their positions per Edit Mode layout in their set, and follow layouts that are copied or renamed", function()
		local frame = slot(1).frame
		lib.frames[frame].onMoved(frame, "Modern", "TOP", 10, -20)
		assert.same({ Modern = { point = "TOP", x = 10, y = -20 } }, Sets.Get("Default").bars[1].positions)
		assert.same({ "TOP", 10, -20 }, frame.points[1])
		lib.Fire("create", "Healer", nil, "Modern")
		lib.Fire("rename", "Modern", "Main")
		assert.same({ "Healer", "Main" }, (function()
			local names = {}
			for name in pairs(Sets.Get("Default").bars[1].positions) do
				names[#names + 1] = name
			end
			table.sort(names)
			return names
		end)())
	end)

	it("set width, gap and size in the Edit Mode dialog, and add and remove bars there", function()
		local frame = slot(1).frame
		local names = {}
		for _, setting in ipairs(lib.settings[frame]) do
			names[#names + 1] = setting.name
		end
		assert.same({ "Width", "Gap", "Size" }, names)
		lib.settings[frame][1].set("Modern", 455)
		assert.equals(460, Sets.Get("Default").bars[1].width)
		local buttons = lib.buttons[frame]
		assert.same({ "Edit bars", "New bar", "Remove this bar" }, { buttons[1].text, buttons[2].text, buttons[3].text })
		buttons[2].click()
		assert.equals(2, #Sets.Get("Default").bars)
		lib.Fire("enter")
		assert.same({ true, true }, { slot(2).frame.shown, slot(2).frame.Empty.shown })
		lib.buttons[slot(2).frame][3].click()
		assert.same({ 1, false }, { #Sets.Get("Default").bars, slot(2).frame.shown })
	end)

	it("set the width with the grip in Edit Mode", function()
		lib.Fire("enter")
		local grip = slot(1).frame.Grip
		assert.is_true(grip.shown)
		Loader.ui.cursor = { 100, 0 }
		grip.scripts.OnMouseDown(grip)
		Loader.ui.cursor = { 160, 0 }
		grip.scripts.OnUpdate(grip)
		grip.scripts.OnMouseUp(grip)
		assert.equals(360, Sets.Get("Default").bars[1].width)
	end)

	it("follow the set the profile uses, and hide with the module", function()
		Sets.Create("Raid")
		Sets.Get("Raid").bars[1].entries = { { kind = "item", id = 2589 } }
		Sets.Use("Raid")
		assert.same({ "7" }, shown(1))
		ns.Modules:SetEnabled("Bars", false)
		assert.is_false(slot(1).frame.shown)
	end)
end)
