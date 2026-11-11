local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

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
		-- How often the dialog was rebuilt.
		function fake:RefreshFrameSettings() self.refreshed = (self.refreshed or 0) + 1 end
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

	it("count an item in the bags, the banks or both, side by side in their colours, and list where it is", function()
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 4, bank = 30, warband = 100 } })
		Test.state.capabilities["Enum.BankType.Account"] = true
		Sets.Get("Default").bars[1].entries = { { kind = "item", id = 2589 }, { kind = "item", id = 2589, count = "banks" },
			{ kind = "item", id = 2589, count = "all" } }
		Sets.Changed("Default")
		assert.same({ "7", "130", "137" }, shown(1))
		local buttons, colors = slot(1).buttons, Bars.BarFrame.COUNT_COLORS
		assert.same({ { 1, 1, 1 }, colors.banks, colors.all }, { buttons[1].Count.color, buttons[2].Count.color, buttons[3].Count.color })
		buttons[2].scripts.OnEnter(buttons[2])
		assert.same({ 2589, "Bags | 7", "Bank | 30", "Warband bank | 100" },
			{ Loader.ui.tooltip.item, Loader.ui.tooltip.lines[1], Loader.ui.tooltip.lines[2], Loader.ui.tooltip.lines[3] })
		-- The bank changes apart from the bags.
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 4, bank = 40, warband = 100 } })
		Test.FireEvent("PLAYERBANKSLOTS_CHANGED", 1)
		assert.same({ "7", "140", "147" }, shown(1))
		-- No warband bank on this client: no such line.
		Test.state.capabilities["Enum.BankType.Account"] = nil
		buttons[1].scripts.OnEnter(buttons[1])
		assert.same({ "Bags | 7", "Bank | 40", "Drag it along the bar to move it, or off the bar to take it off." }, Loader.ui.tooltip.lines)
	end)

	it("show a stack's most important member with a count above zero, and list them all on hover", function()
		local bar = Sets.Get("Default").bars[1]
		-- Most important first: the crest, then Valorstones.
		bar.entries = { { kind = "stack", showEmpty = false, members = { { kind = "currency", id = 3110 }, { kind = "currency", id = 3008 } } },
			{ kind = "currency", id = 2815 } }
		Test.SetCurrency(3110, { name = "Gilded Crest", icon = 2, quantity = 0, max = 90, totalEarned = 0, capsTotalEarned = true })
		Sets.Changed("Default")
		assert.same({ "500 / 2000", "4000" }, shown(1))
		local first = slot(1).buttons[1]
		first.scripts.OnEnter(first)
		assert.same({ "Valorstones", "|T2:0|t Gilded Crest | 0", "|T1:0|t Valorstones | 500 / 2000" },
			{ Loader.ui.tooltip.lines[1], Loader.ui.tooltip.lines[2], Loader.ui.tooltip.lines[3] })
		Test.ChangeCurrency(3110, 5)
		assert.same({ "5", "4000" }, shown(1))
		-- Every member at zero: the stack takes no room, or shows its least important member with Show when empty.
		Test.ChangeCurrency(3110, -5)
		Test.SetCurrency(3008, { name = "Valorstones", icon = 1, quantity = 0, max = 2000, backpack = 1 })
		Test.ChangeCurrency(3008, 0)
		assert.same({ "4000" }, shown(1))
		assert.equals(0, slot(1).buttons[1].x)
		bar.entries[1].showEmpty = true
		Sets.Changed("Default")
		assert.same({ "0 / 2000", "4000" }, shown(1))
		-- Its name in the overflow list and in the question: the shown member's.
		assert.equals("Stack: Valorstones", Bars.Describe(bar.entries[1]).name)
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

	it("move an entry dragged along the bar, outside Edit Mode, showing what moves and where it goes", function()
		local bar = Sets.Get("Default").bars[1]
		local first = slot(1).buttons[1]
		slot(1).frame.mouseOver = true
		first.scripts.OnDragStart(first)
		Loader.ui.cursor = { 150, 0 }
		-- A dimmed entry, a copy at the mouse, a line in the gap after the second entry.
		slot(1):FollowDrag()
		local ghost = Bars.BarFrame.Ghost()
		assert.same({ 0.35, true, "500 / 2000" }, { first.alpha, ghost.shown, ghost.Text.text })
		assert.same({ true, { "LEFT", slot(1).frame, "LEFT", 101 + 53 + 3 - 1, 0 } }, { slot(1).frame.Marker.shown, slot(1).frame.Marker.points[1] })
		first.scripts.OnDragStop(first)
		assert.same({ false, false }, { ghost.shown, slot(1).frame.Marker.shown })
		assert.same({ { kind = "currency", id = 2815 }, { kind = "currency", id = 3008 } }, bar.entries)
		assert.same({ "4000", "500 / 2000" }, shown(1))
		lib.Fire("enter")
		first = slot(1).buttons[1]
		first.scripts.OnDragStart(first)
		Loader.ui.cursor = { 500, 0 }
		first.scripts.OnDragStop(first)
		assert.same({ { kind = "currency", id = 2815 }, { kind = "currency", id = 3008 } }, bar.entries)
	end)

	it("take an entry dragged off the bar off it, after a question", function()
		local api = SettingsAPI.Install()
		local first = slot(1).buttons[1]
		first.scripts.OnDragStart(first)
		slot(1).frame.mouseOver = false
		slot(1):FollowDrag()
		assert.same({ 1, 0.13, 0.13 }, Bars.BarFrame.Ghost().Text.color)
		first.scripts.OnDragStop(first)
		assert.equals(1, #api.popups)
		assert.same({ "500 / 2000", "4000" }, shown(1))
		api.AcceptPopup()
		assert.same({ "4000" }, shown(1))
		assert.same({ { kind = "currency", id = 2815 } }, Sets.Get("Default").bars[1].entries)
	end)

	-- Drags an entry of the first bar off it, which asks.
	local function dragOff(position)
		local button = slot(1).buttons[position]
		button.scripts.OnDragStart(button)
		slot(1).frame.mouseOver = false
		button.scripts.OnDragStop(button)
	end

	it("change no bar in any way while that question is open", function()
		local api = SettingsAPI.Install()
		Bars.Editor.Open()
		dragOff(1)
		-- Not a second question, not a move, not a drop from the bags.
		dragOff(2)
		local second = slot(1).buttons[2]
		slot(1).frame.mouseOver = true
		second.scripts.OnDragStart(second)
		assert.is_false(Bars.BarFrame.Ghost().shown)
		Loader.ui.cursor = { 0, 0 }
		second.scripts.OnDragStop(second)
		Test.state.cursorItem = 2589
		slot(1).frame.scripts.OnReceiveDrag(slot(1).frame)
		assert.same({ 1, 2589 }, { #api.popups, Test.state.cursorItem })
		-- Not in the bar editor either.
		assert.is_false(Bars.Editor.Add(Bars.Editor.Bar(), { kind = "currency", id = 3110 }))
		Bars.Editor.Window().add.scripts.OnClick(Bars.Editor.Window().add)
		-- Not in Edit Mode: the width, the grip, the dialog's buttons.
		lib.Fire("enter")
		lib.refreshed = 0
		lib.settings[slot(1).frame][1].set("Modern", 600)
		-- The dialog shows the bar's own width again once it is done storing.
		assert.equals(0, lib.refreshed)
		Test.Advance(0.1)
		assert.equals(1, lib.refreshed)
		-- Moved in Edit Mode: back to its place, nothing kept.
		local frame = slot(1).frame
		lib.frames[frame].onMoved(frame, "Modern", "TOP", 10, -20)
		assert.same({ nil, { "BOTTOM", 0, 160 } }, { Sets.Get("Default").bars[1].positions.Modern, frame.points[1] })
		local grip = slot(1).frame.Grip
		Loader.ui.cursor = { 100, 0 }
		grip.scripts.OnMouseDown(grip)
		Loader.ui.cursor = { 160, 0 }
		grip.scripts.OnUpdate(grip)
		grip.scripts.OnMouseUp(grip)
		lib.buttons[slot(1).frame][2].click()
		lib.Fire("exit")
		local set = Sets.Get("Default")
		assert.same({ 1, 300, { "500 / 2000", "4000" } }, { #set.bars, set.bars[1].width, shown(1) })
		-- The answer takes off the entry asked about, and nothing else.
		api.AcceptPopup()
		assert.same({ { kind = "currency", id = 2815 } }, set.bars[1].entries)
		-- Answered, the bar changes again.
		Loader.ui.cursor = { 0, 0 }
		slot(1).frame.scripts.OnReceiveDrag(slot(1).frame)
		assert.same({ "7", "4000" }, shown(1))
	end)

	it("take off the entry asked about, wherever it stands by the answer, and nothing after a cancel", function()
		local api = SettingsAPI.Install()
		dragOff(2)
		-- The backpack's order changes under the question.
		Test.SetCurrency(3008, { name = "Valorstones", icon = 1, quantity = 500, max = 2000, backpack = 3 })
		api.AcceptPopup()
		assert.same({ { kind = "currency", id = 3008 } }, Sets.Get("Default").bars[1].entries)
		dragOff(1)
		api.CancelPopup()
		assert.same({ "500 / 2000" }, shown(1))
		dragOff(1)
		assert.equals(3, #api.popups)
	end)

	it("take off the entry asked about when the same item counts twice, or of two stacks", function()
		local api = SettingsAPI.Install()
		local bar = Sets.Get("Default").bars[1]
		bar.entries = { { kind = "item", id = 2589 }, { kind = "item", id = 2589, count = "banks" } }
		Sets.Changed("Default")
		dragOff(2)
		api.AcceptPopup()
		assert.same({ { kind = "item", id = 2589 } }, bar.entries)
		local first = { kind = "stack", showEmpty = false, members = { { kind = "currency", id = 3110 }, { kind = "currency", id = 3008 } } }
		bar.entries = { first, { kind = "stack", showEmpty = false, members = { { kind = "currency", id = 2815 }, { kind = "item", id = 2589 } } } }
		Sets.Changed("Default")
		dragOff(2)
		api.AcceptPopup()
		assert.same({ first }, bar.entries)
	end)

	it("keep the dragged entry when the bar is laid out again during the drag", function()
		local api = SettingsAPI.Install()
		local bar = Sets.Get("Default").bars[1]
		-- A stack at zero takes no room: the first button shows Resonance Crystals.
		Test.SetCurrency(3110, { name = "Gilded Crest", icon = 2, quantity = 0, max = 90, totalEarned = 0, capsTotalEarned = true })
		Test.SetCurrency(3008, { name = "Valorstones", icon = 1, quantity = 0, max = 2000, backpack = 1 })
		local stack = { kind = "stack", showEmpty = false, members = { { kind = "currency", id = 3110 }, { kind = "currency", id = 3008 } } }
		bar.entries = { stack, { kind = "currency", id = 2815 } }
		Sets.Changed("Default")
		local button = slot(1).buttons[1]
		button.scripts.OnDragStart(button)
		-- The stack shows again, and takes the first button.
		Test.ChangeCurrency(3110, 5)
		assert.equals(stack, button.entry)
		slot(1).frame.mouseOver = false
		button.scripts.OnDragStop(button)
		api.AcceptPopup()
		assert.same({ stack }, bar.entries)
	end)

	it("add an item dropped from the bags on the bar where it is dropped, also outside Edit Mode", function()
		Test.state.cursorItem = 2589
		-- Before the middle of the first entry.
		Loader.ui.cursor = { 20, 0 }
		slot(1).frame.scripts.OnReceiveDrag(slot(1).frame)
		assert.same({ "7", "500 / 2000", "4000" }, shown(1))
		assert.same({ "clear" }, Test.state.bagActions[#Test.state.bagActions])
	end)

	it("put an item dropped from the bags where it was dropped, also when it makes the bar overflow", function()
		local bar = Sets.Get("Default").bars[1]
		bar.width = 160
		Sets.Changed("Default")
		Test.state.cursorItem = 2589
		-- After the second entry; both fit until the item comes.
		Loader.ui.cursor = { 150, 0 }
		slot(1).frame.scripts.OnReceiveDrag(slot(1).frame)
		assert.same({ { kind = "currency", id = 3008 }, { kind = "currency", id = 2815 }, { kind = "item", id = 2589 } }, bar.entries)
	end)

	it("show money in coins, without an icon, and follow it", function()
		rawset(_G, "GetMoneyString", function(copper) return copper .. "c" end)
		Sets.Get("Default").bars[1].entries = { { kind = "money", id = 0 } }
		Test.SetMoney(12345)
		Sets.Changed("Default")
		local button = slot(1).buttons[1]
		assert.same({ "12345c", false }, { button.Count.text, button.Icon.shown })
		Test.SetMoney(20000)
		assert.equals("20000c", button.Count.text)
	end)

	it("count money's coin icons in its width", function()
		-- As the client writes it: a number, then its coin, 2 pixels after it.
		local coin = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
		rawset(_G, "GetMoneyString", function()
			return "1" .. coin:format("Gold") .. " 23" .. coin:format("Silver") .. " 45" .. coin:format("Copper")
		end)
		Sets.Get("Default").bars[1].entries = { { kind = "money", id = 0 }, { kind = "currency", id = 3008 } }
		Sets.Changed("Default")
		-- "1 23 45" at 7 pixels a letter, three coins 13 high (the font at size
		-- 22) with 2 pixels each, then the gap.
		assert.equals(49 + 3 * 15 + 6, slot(1).buttons[2].x)
	end)

	it("show a background of its opacity and the bags' coin-box border when asked", function()
		local bar = Sets.Get("Default").bars[1]
		local frame = slot(1).frame
		assert.same({ false, false }, { frame.Background.shown, frame.Border.Middle.shown })
		bar.background, bar.opacity, bar.border = true, 30, true
		Sets.Changed("Default")
		assert.same({ true, 0.3, true, "_common-coinbox-center" },
			{ frame.Background.shown, frame.Background.colorTexture[4], frame.Border.Middle.shown, frame.Border.Middle.atlas })
	end)

	it("fill from the right edge when asked, with the arrow on the left pointing left", function()
		local bar = Sets.Get("Default").bars[1]
		bar.entries = { { kind = "currency", id = 3008 }, { kind = "currency", id = 2815 }, { kind = "item", id = 2589 } }
		bar.direction = "left"
		bar.width = 160
		Sets.Changed("Default")
		local buttons = slot(1).buttons
		assert.same({ "RIGHT", slot(1).frame, "RIGHT", 0, 0 }, buttons[1].points[1])
		local more = slot(1).frame.More
		assert.same({ true, "«", "LEFT" }, { more.shown, more.Text.text, more.points[1][1] })
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
		assert.same({ "Width", "Gap", "Size", "Fill from", "Background", "Background opacity", "Border" }, names)
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

	it("do not rebuild the Edit Mode dialog for a change made in it, only for one from elsewhere", function()
		lib.Fire("enter")
		lib.refreshed = 0
		lib.settings[slot(1).frame][1].set("Modern", 455)
		assert.same({ 460, 0 }, { Sets.Get("Default").bars[1].width, lib.refreshed })
		Sets.Changed("Default")
		assert.equals(1, lib.refreshed)
	end)

	it("end the Edit Mode preview of the module turned off in Edit Mode", function()
		lib.Fire("enter")
		assert.is_true(slot(1).frame.Grip.shown)
		ns.Modules:SetEnabled("Bars", false)
		lib.Fire("exit")
		ns.Modules:SetEnabled("Bars", true)
		local frame = slot(1).frame
		assert.same({ false, false, false, false }, { slot(1).preview, frame.Grip.shown, frame.Background.shown, frame.Empty.shown })
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
