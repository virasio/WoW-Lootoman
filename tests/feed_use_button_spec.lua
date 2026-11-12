local Loader = require("tests.helpers.loader")

-- The secure button that uses the stuck item with a right click.
describe("loot feed use button", function()
	local ns, ui, Test, model, feed, button

	local function options(extra)
		local Design = ns.Feed.Design
		local merged = { direction = "up", maxRows = 3, layout = Design.Layout(Design.LARGE, 13), opacity = 0.5 }
		for key, value in pairs(extra or {}) do
			merged[key] = value
		end
		return merged
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		ui, Test = Loader.ui, ns.Compat.Test
		model = ns.Feed.Model.New({ maxRows = 3, duration = 6, fade = 1, minQuality = 0, kinds = { item = true, money = true } }, 0)
		feed = ns.Feed.Frames.Create(model)
		feed:SetOptions(options())
		feed.useButton = ns.Feed.UseButton.Create(feed)
		button = feed.useButton.button
		-- Where the client put the feed: 300 wide, three rows high.
		feed.frame.GetLeft = function() return 100 end
		feed.frame.GetBottom = function() return 200 end
		feed.frame.GetRight = function() return 400 end
		feed.frame.GetTop = function() return 319 end
	end)

	local function stick(id, name, now)
		local row = model:Add({ kind = "item", id = id, name = name, link = "|Hitem:" .. id .. "|h", icon = id, amount = 1 }, now or 0)
		model:SetSticky(row, "container", now or 0)
		return row
	end

	it("lies over the first place, on the screen, and uses the stuck item with a right click", function()
		stick(77, "Clam")
		feed:Draw(7)
		assert.same({ true, true, ui.UIParent }, { button.protected, button.shown, button.parent })
		assert.same({ "item", "item:77" }, { button:GetAttribute("type2"), button:GetAttribute("item") })
		assert.same({ "BOTTOMLEFT", ui.UIParent, "BOTTOMLEFT", 100, 200 }, button.points[1])
		assert.same({ 300, 35 }, { button.width, button.height })
		ui.SecureClick(button, "RightButton", true)
		ui.SecureClick(button, "RightButton", false)
		assert.same({ "item:77" }, ui.used)
		-- A left click lets it go; with no stuck row the button hides.
		ui.SecureClick(button, "LeftButton", true)
		ui.SecureClick(button, "LeftButton", false)
		assert.same({}, model:Stuck())
		feed:Draw(7.1)
		assert.is_false(button.shown)
	end)

	it("follows the next stuck item, and the first place in each direction", function()
		stick(77, "Clam")
		stick(88, "Letter")
		feed:Draw(7)
		feed:Dismiss(model:Stuck()[1])
		feed:Draw(7.1)
		assert.equals("item:88", button:GetAttribute("item"))
		feed:SetOptions(options({ direction = "down" }))
		feed:Draw(7.2)
		assert.same({ "BOTTOMLEFT", ui.UIParent, "BOTTOMLEFT", 100, 284 }, button.points[1])
		local Design = ns.Feed.Design
		feed:SetOptions(options({ direction = "left", layout = Design.Layout(Design.ICONS, 13) }))
		feed:Draw(7.3)
		assert.same({ { "BOTTOMLEFT", ui.UIParent, "BOTTOMLEFT", 364, 200 }, 36, 36 }, { button.points[1], button.width, button.height })
	end)

	it("stays as the fight found it: a left click lets the row go and turns the use off; it catches up after", function()
		stick(77, "Clam")
		feed:Draw(7)
		Test.SetCombat(true)
		stick(88, "Letter", 7)
		ui.SecureClick(button, "LeftButton", false)
		feed:Draw(14)
		-- The letter is stuck now, but the button cannot change in the fight.
		assert.same({ true, "item:77" }, { button.shown, button:GetAttribute("item") })
		assert.is_nil(button:GetAttribute("type2"))
		ui.SecureClick(button, "RightButton", false)
		assert.same({}, ui.used)
		assert.same({}, ui.blocked)
		Test.SetCombat(false)
		assert.same({ "item", "item:88" }, { button:GetAttribute("type2"), button:GetAttribute("item") })
		-- With the feed turned off it hides; in a fight, once it is over.
		Test.SetCombat(true)
		feed.disabled = true
		feed:SyncUse()
		assert.is_true(button.shown)
		Test.SetCombat(false)
		assert.is_false(button.shown)
		assert.same({}, ui.blocked)
	end)
end)
