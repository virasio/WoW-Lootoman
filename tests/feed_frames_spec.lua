local Loader = require("tests.helpers.loader")

describe("loot feed frames", function()
	local ns, Frames, Model, tooltip

	local ALL = { item = true, currency = true, money = true, reputation = true, xp = true }
	local LINK = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r"

	local function newModel(options)
		local merged = { maxRows = 3, duration = 6, fade = 1, minQuality = 0, kinds = ALL }
		for key, value in pairs(options or {}) do
			merged[key] = value
		end
		return Model.New(merged, 0)
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Frames, Model = ns.Feed.Frames, ns.Feed.Model
		tooltip = Loader.ui.tooltip
	end)

	-- Feed options with the "Large" design at the default size: rows 35 high
	-- with a gap of 7, so 42 apart.
	local function options(extra)
		local Design = ns.Feed.Design
		local merged = { direction = "up", maxRows = 3, layout = Design.Layout(Design.LARGE, 13), opacity = 0.5 }
		for key, value in pairs(extra or {}) do
			merged[key] = value
		end
		return merged
	end

	describe("row look", function()
		it("shows an item with its quality colour, the loot roll's quality border and its count", function()
			local look = Frames.Describe({ kind = "item", name = "Blade", icon = 1, quality = 4, amount = 3 })
			assert.same({ icon = 1, label = "Blade", labelColor = { 0.64, 0.21, 0.93 }, amount = "×3",
				amountColor = { 1, 1, 1 }, border = "loottoast-itemborder-4" }, look)
			assert.is_nil(Frames.Describe({ kind = "item", name = "Blade", quality = 4, amount = 1 }).amount)
			assert.equals("loottoast-itemborder-white", Frames.Describe({ kind = "item", name = "Rag", quality = 0 }).border)
		end)

		it("gives rare and better items a glow in their quality colour, when asked", function()
			assert.equals("bags-glow-3", Frames.Describe({ kind = "item", name = "Ring", quality = 3 }, { showGlow = true }).glow)
			assert.is_nil(Frames.Describe({ kind = "item", name = "Cloth", quality = 2 }, { showGlow = true }).glow)
			assert.is_nil(Frames.Describe({ kind = "item", name = "Ring", quality = 3 }).glow)
		end)

		it("shows how many of an item the player owns, or a currency's total, when asked", function()
			ns.Compat.Test.SetItems({ [2589] = { name = "Linen Cloth", owned = 42 } })
			local owned = { showOwned = true }
			assert.equals(42, Frames.Describe({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth" }, owned).owned)
			assert.equals(120, Frames.Describe({ kind = "currency", name = "Valorstones", total = 120 }, owned).owned)
			assert.is_nil(Frames.Describe({ kind = "item", id = 7, name = "Gone" }, owned).owned)
			assert.is_nil(Frames.Describe({ kind = "money", amount = 5 }, owned).owned)
			assert.is_nil(Frames.Describe({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth" }).owned)
		end)

		it("shows a currency with its count and no border", function()
			local look = Frames.Describe({ kind = "currency", name = "Valorstones", quality = 4, amount = 5 })
			assert.same({ "×5", nil }, { look.amount, look.border })
		end)

		it("shows money with the game's coin text", function()
			local look = Frames.Describe({ kind = "money", amount = 12345 })
			assert.equals("12345 copper", look.label)
			assert.matches("coin", look.icon)
		end)

		it("shows experience and reputation changes with their sign and colour", function()
			assert.same({ "Experience", "+150", { 0.1, 1, 0.1 } }, (function(look) return { look.label, look.amount, look.amountColor } end)(
				Frames.Describe({ kind = "xp", amount = 150 })))
			local gain = Frames.Describe({ kind = "reputation", name = "Stormwind", amount = 250 })
			assert.same({ "Reputation with Stormwind", "+250" }, { gain.label, gain.amount })
			local loss = Frames.Describe({ kind = "reputation", name = "Defias Brotherhood", amount = -10 })
			assert.same({ "-10", { 1, 0.13, 0.13 } }, { loss.amount, loss.amountColor })
			assert.is_nil(Frames.Describe({ kind = "reputation", name = "Darnassus" }).amount)
		end)

		it("shortens the amounts on icons: no times sign and no plus, thousands short, money as a number and a coin", function()
			local Design = ns.Feed.Design
			local icons = { layout = Design.Layout(Design.ICONS, 13) }
			assert.same({ "1.23K", { 1, 1, 1 } }, { Frames.Describe({ kind = "item", name = "Cloth", quality = 1, amount = 1234 }, icons).amount,
				Frames.Describe({ kind = "item", name = "Cloth", quality = 1, amount = 1234 }, icons).amountColor })
			assert.equals("5", Frames.Describe({ kind = "currency", name = "Crest", amount = 5 }, icons).amount)
			assert.same({ "12.34K", { 0.1, 1, 0.1 } }, { Frames.Describe({ kind = "xp", amount = 12345 }, icons).amount,
				Frames.Describe({ kind = "xp", amount = 12345 }, icons).amountColor })
			assert.same({ "-250", { 1, 0.13, 0.13 } }, { Frames.Describe({ kind = "reputation", name = "Stormwind", amount = -250 }, icons).amount,
				Frames.Describe({ kind = "reputation", name = "Stormwind", amount = -250 }, icons).amountColor })
			local money = Frames.Describe({ kind = "money", amount = 10245 }, icons)
			assert.same({ "1.02|A:coin-gold|a", "10245 copper" }, { money.amount, money.label })
			assert.equals("78|A:coin-copper|a", Frames.Describe({ kind = "money", amount = 78 }, icons).amount)
			-- The client's decimal point.
			ns.Compat.Test.state.globalStrings.DECIMAL_SEPERATOR = ","
			assert.equals("1,23|A:coin-silver|a", Frames.Describe({ kind = "money", amount = 123 }, icons).amount)
			-- Rows keep the long form.
			assert.equals("+12345", Frames.Describe({ kind = "xp", amount = 12345 }, { layout = Design.Layout(Design.LARGE, 13) }).amount)
		end)

		it("uses its own phrase for a faction name the client declined", function()
			assert.equals("Штормграда reputation", Frames.Describe({ kind = "reputation", name = "Штормграда", declined = true, amount = 5 }).label)
		end)
	end)

	describe("feed", function()
		local model, feed

		before_each(function()
			model = newModel()
			feed = Frames.Create(model)
			feed:SetOptions(options())
		end)

		-- The frame showing a label.
		local function frameWith(label)
			for _, rowFrame in pairs(feed.frameOf) do
				if rowFrame.Label.text == label then
					return rowFrame
				end
			end
		end

		-- "label@distance from the anchor edge" for the rows on screen, from the edge.
		local function layout()
			local list = {}
			for _, rowFrame in pairs(feed.frameOf) do
				if rowFrame.shown then
					list[#list + 1] = rowFrame
				end
			end
			table.sort(list, function(a, b) return a.offset < b.offset end)
			for index, rowFrame in ipairs(list) do
				list[index] = rowFrame.Label.text .. "@" .. rowFrame.offset
			end
			return list
		end

		it("keeps the oldest row at the anchor edge and stacks new rows away from it", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			model:Add({ kind = "xp", amount = 50 }, 0)
			feed:Draw(1)
			assert.same({ "100 copper@0", "Experience@42" }, layout())
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 42 }, frameWith("Experience").points[1])
			feed:SetOptions(options({ direction = "down" }))
			assert.same({ "TOPLEFT", feed.frame, "TOPLEFT", 0, -42 }, frameWith("Experience").points[1])
			assert.same({ "TOPLEFT", feed.frame, "TOPLEFT", 0, 0 }, frameWith("100 copper").points[1])
			assert.equals(119, feed.frame.height)
		end)

		it("fills sideways with icons: the oldest at the left or the right edge, the new ones beside it", function()
			local icons = ns.Feed.Design.Layout(ns.Feed.Design.ICONS, 13)
			feed:SetOptions(options({ direction = "right", layout = icons }))
			model:Add({ kind = "money", amount = 100 }, 0)
			model:Add({ kind = "xp", amount = 50 }, 0)
			feed:Draw(1)
			-- Icons 36 wide, 4 apart: three of them make the strip.
			assert.same({ "100 copper@0", "Experience@40" }, layout())
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 40, 0 }, frameWith("Experience").points[1])
			assert.same({ 116, 36 }, { feed.frame.width, feed.frame.height })
			feed:SetOptions(options({ direction = "left", layout = icons }))
			assert.same({ "BOTTOMRIGHT", feed.frame, "BOTTOMRIGHT", -40, 0 }, frameWith("Experience").points[1])
			assert.same({ "BOTTOMRIGHT", feed.frame, "BOTTOMRIGHT", 0, 0 }, frameWith("100 copper").points[1])
		end)

		it("puts warnings in lines above a sideways strip, which keeps its places", function()
			feed:SetOptions(options({ direction = "right", layout = ns.Feed.Design.Layout(ns.Feed.Design.ICONS, 13) }))
			feed:SetWarnings({ "Free bag slots: 2", "No free reagent bag slots" })
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Draw(1)
			assert.same({ "100 copper@0" }, layout())
			-- Lines as high as their text and a little room, the first one nearest to the strip.
			local first, second = feed.warningLines[1], feed.warningLines[2]
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 36 }, first.points[1])
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 55 }, second.points[1])
			assert.same({ 116, 19 }, { first.width, first.height })
			-- The background spans the strip and the lines, evenly behind icons.
			local background = feed.frame.Background
			assert.same({ 124, 82 }, { background.width, background.height })
			assert.same({ 0.5, 0.5 }, { background.gradient[2].a, background.gradient[3].a })
			feed:SetOptions(options({ direction = "left", layout = ns.Feed.Design.Layout(ns.Feed.Design.ICONS, 13) }))
			assert.same({ "BOTTOMRIGHT", feed.frame, "BOTTOMRIGHT", 0, 36 }, first.points[1])
		end)

		it("shows warnings as bag icons with the free slots in an Icons layout filling up or down", function()
			local Design = ns.Feed.Design
			feed:SetOptions(options({ layout = Design.Layout(Design.ICONS, 13) }))
			feed:SetWarnings({ { text = "Free bag slots: 2", count = 2 }, { text = "No free reagent bag slots", count = 0 } })
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Draw(1)
			-- The icons take the first places, 40 apart, and the row comes after them.
			local first, second = feed.warningIcons[1], feed.warningIcons[2]
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 0 }, first.points[1])
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 40 }, second.points[1])
			assert.same({ "2", "0", { 1, 0.25, 0.25 } }, { first.Count.text, second.Count.text, first.Count.color })
			assert.same({ "100 copper@80" }, layout())
			assert.is_nil(feed.warningLines[1])
			first.scripts.OnEnter(first)
			assert.same({ true, "Free bag slots: 2" }, { tooltip.shown, tooltip.lines[1] })
			-- Sideways they are lines again; with rows too.
			feed:SetOptions(options({ direction = "right", layout = Design.Layout(Design.ICONS, 13) }))
			assert.same({ false, true, "Free bag slots: 2" }, { first.shown, feed.warningLines[1].shown, feed.warningLines[1].Text.text })
			feed:SetOptions(options())
			assert.same({ false, true }, { first.shown, feed.warningLines[1].shown })
			feed:SetWarnings({})
			assert.is_false(feed.warningLines[1].shown)
		end)

		it("puts the stuck row in the first place, before the warnings, with its marks and its clicks", function()
			feed:SetWarnings({ "Free bag slots: 2" })
			local quest = model:Add({ kind = "item", id = 1, name = "Letter", link = LINK, icon = 1, amount = 1 }, 0)
			model:SetSticky(quest, "quest", 0)
			local clam = model:Add({ kind = "item", id = 2, name = "Clam", link = LINK, icon = 2, amount = 1 }, 0)
			model:SetSticky(clam, "container", 0)
			model:Add({ kind = "money", amount = 100 }, 6.5)
			feed:Draw(6.5)
			-- The letter stuck first: its place is the first, the warning's the next.
			assert.same({ "Letter@0", "100 copper@84" }, layout())
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 42 }, feed.warningLines[1].points[1])
			local letter = frameWith("Letter")
			assert.same({ true, false, true, "+1", true }, { letter.QuestMark.shown, letter.Pin.shown, letter.Waiting.shown,
				letter.Waiting.text, letter.mouseClicks })
			assert.is_false(frameWith("100 copper").mouseClicks)
			letter.scripts.OnEnter(letter)
			assert.equals("Left-click: dismiss. Right-click: use.", tooltip.lines[#tooltip.lines])
			-- A left click lets it go; the clam takes the place, with a pin.
			local dismissed
			feed.onDismiss = function(row) dismissed = row end
			letter.scripts.OnMouseUp(letter, "LeftButton")
			assert.equals(quest, dismissed)
			feed:Draw(6.6)
			assert.same({ "Clam@0", "100 copper@84" }, layout())
			local clamFrame = frameWith("Clam")
			assert.same({ false, true, false }, { clamFrame.QuestMark.shown, clamFrame.Pin.shown, clamFrame.Waiting.shown })
			-- A right click is not the row's.
			clamFrame.scripts.OnMouseUp(clamFrame, "RightButton")
			assert.equals(quest, dismissed)
			-- With no stuck row, the warning goes back to the first place.
			feed:Dismiss(clam)
			feed:Draw(6.7)
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 0 }, feed.warningLines[1].points[1])
		end)

		it("puts warnings at the anchor edge, the rows after them, and stays shown for them", function()
			feed:SetWarnings({ "Free bag slots: 2" })
			assert.is_true(feed.frame.shown)
			local warning = feed.warningLines[1]
			assert.same({ "Free bag slots: 2", { "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 0 } }, { warning.Text.text, warning.points[1] })
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Draw(1)
			assert.same({ "100 copper@42" }, layout())
			feed:SetOptions(options({ direction = "down" }))
			assert.same({ "TOPLEFT", feed.frame, "TOPLEFT", 0, 0 }, warning.points[1])
			-- With the rows gone, the warning keeps the feed shown.
			feed:Draw(100)
			assert.same({ {}, true }, { layout(), feed.frame.shown })
			feed:SetWarnings({})
			assert.is_false(warning.shown)
			feed:Draw(101)
			assert.is_false(feed.frame.shown)
		end)

		it("slides the rows to their new places when the oldest one leaves", function()
			-- 100 pixels a second, and draws 1/8 s apart, so every step is exact.
			Frames.SLIDE_TIME = 0.42
			model:Add({ kind = "money", amount = 100 }, 0)
			model:Add({ kind = "xp", amount = 50 }, 3)
			feed:Draw(6.875)
			assert.same({ "100 copper@0", "Experience@42" }, layout())
			feed:Draw(7)
			assert.same({ "Experience@29.5" }, layout())
			feed:Draw(7.25)
			assert.same({ "Experience@4.5" }, layout())
			feed:Draw(7.5)
			assert.same({ "Experience@0" }, layout())
		end)

		it("hides itself and frees every row frame when the rows are gone", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Wake()
			feed:Draw(1)
			assert.is_true(feed.frame.shown)
			feed:Draw(7)
			assert.same({}, layout())
			assert.is_false(feed.frame.shown)
			assert.equals(Frames.POOL, #feed.free)
		end)

		it("fades new rows in", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Draw(0)
			assert.equals(0, frameWith("100 copper").alpha)
			feed:Draw(Frames.FADE_IN / 2)
			assert.equals(0.5, frameWith("100 copper").alpha)
			feed:Draw(1)
			assert.equals(1, frameWith("100 copper").alpha)
		end)

		it("pauses the model and stays while the pointer is over it", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			feed:Wake()
			feed.frame.mouseOver = true
			feed:Draw(1)
			feed:Draw(50)
			assert.same({ "100 copper@0" }, layout())
			assert.is_true(feed.frame.shown)
		end)

		it("slides rows pushed out of a full feed past the anchor edge", function()
			model = newModel({ maxRows = 2 })
			feed = Frames.Create(model)
			feed:SetOptions(options({ maxRows = 2 }))
			for id = 1, 3 do
				model:Add({ kind = "item", id = id, name = "Item " .. id, amount = 1 }, 0)
			end
			feed:Draw(0.1)
			assert.same({ "Item 1@-42", "Item 2@0", "Item 3@42" }, layout())
		end)

		it("lays rows out by the design, scaled by the size", function()
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", amount = 2, quality = 1 }, 0)
			feed:SetOptions(options({ layout = ns.Feed.Design.Layout(ns.Feed.Design.LARGE, 16) }))
			feed:Draw(1)
			local row = frameWith("Linen Cloth")
			assert.same({ 369, 43 }, { row.width, row.height })
			assert.same({ 43, 43 }, { row.Icon.width, row.Icon.height })
			assert.same({ 53, 53 }, { row.IconBorder.width, row.IconBorder.height })
			assert.equals(16, row.Label.font[2])
			assert.equals(15, row.Owned.font[2])
			assert.equals(369, feed.frame.width)
		end)

		it("puts the amount right after the name, which takes the width of its text", function()
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", amount = 2, quality = 1 }, 0)
			feed:Draw(1)
			local row = frameWith("Linen Cloth")
			assert.equals(77, row.Label.width)
			assert.same({ "LEFT", row.Label, "RIGHT", 6, 0 }, row.Amount.points[1])
			assert.equals("×2", row.Amount.text)
		end)

		it("shortens a long name so the amount after it stays inside the row", function()
			local Design = ns.Feed.Design
			local section = {}
			Design.Set(section, "name", "width", 400)
			local long = ("x"):rep(50)
			model:Add({ kind = "item", id = 1, name = long, amount = 3, quality = 1 }, 0)
			feed:SetOptions(options({ layout = Design.Layout(Design.Current(section), 13) }))
			feed:Draw(1)
			-- 300 wide, the name starts at 46, the amount takes 6 + 14.
			assert.equals(234, frameWith(long).Label.width)
		end)

		it("anchors every part to its element's point, and aligns the texts", function()
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", icon = 1, amount = 1, quality = 1 }, 0)
			feed:Draw(1)
			local row = frameWith("Linen Cloth")
			assert.same({ "LEFT", row, "LEFT", 0, 0 }, row.Icon.points[1])
			assert.same({ "LEFT", row.Icon, "RIGHT", 11, 0 }, row.Label.points[1])
			assert.same({ "BOTTOMRIGHT", row.Icon, "BOTTOMRIGHT", -4, 3 }, row.Owned.points[1])
			assert.same({ "LEFT", "RIGHT" }, { row.Label.justify, row.Owned.justify })

			local Design = ns.Feed.Design
			local section = {}
			Design.Set(section, "name", "anchor", "row")
			Design.Set(section, "name", "align", "RIGHT")
			feed:SetOptions(options({ layout = Design.Layout(Design.Current(section), 13) }))
			feed:Draw(1)
			assert.same({ "RIGHT", row, "RIGHT", 0, 0 }, row.Label.points[1])
			assert.same({ "RIGHT", 77 }, { row.Label.justify, row.Label.width })
		end)

		it("shows the owned count without an icon when it is not on the icon", function()
			ns.Compat.Test.SetItems({ [2589] = { name = "Linen Cloth", owned = 42 } })
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", amount = 1, quality = 1 }, 0)
			local Design = ns.Feed.Design
			local section = {}
			Design.Set(section, "icon", "shown", false)
			feed:SetOptions(options({ showOwned = true, layout = Design.Layout(Design.Current(section), 13) }))
			feed:Draw(1)
			assert.is_false(frameWith("Linen Cloth").Owned.shown)
			Design.Set(section, "owned", "anchor", "row")
			feed:SetOptions(options({ showOwned = true, layout = Design.Layout(Design.Current(section), 13) }))
			feed:Draw(1)
			assert.same({ true, "42" }, { frameWith("Linen Cloth").Owned.shown, frameWith("Linen Cloth").Owned.text })
		end)

		it("draws the amount's own background when the design asks, with its opacity", function()
			local Design = ns.Feed.Design
			local design = Design.Current({ schema = Design.SCHEMA, base = "icons", changes = { amount = { background = true, opacity = 30 } } })
			local rowFrame = Frames.CreateRow(nil)
			local withBackground = { layout = Design.Layout(design, 13) }
			Frames.ApplyLayout(rowFrame, withBackground.layout)
			Frames.Fill(rowFrame, { kind = "item", name = "Cloth", quality = 1, amount = 20 }, withBackground)
			assert.same({ true, 0.3 }, { rowFrame.AmountBackground.shown, rowFrame.AmountBackground.colorTexture[4] })
			-- No amount, no background.
			Frames.Fill(rowFrame, { kind = "item", name = "Cloth", quality = 1, amount = 1 }, withBackground)
			assert.is_false(rowFrame.AmountBackground.shown)
			Frames.Fill(rowFrame, { kind = "item", name = "Cloth", quality = 1, amount = 20 }, { layout = Design.Layout(Design.ICONS, 13) })
			assert.is_false(rowFrame.AmountBackground.shown)
		end)

		it("shows the owned count and the glow, and hides them when turned off", function()
			ns.Compat.Test.SetItems({ [2589] = { name = "Linen Cloth", owned = 42 } })
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", icon = 1, amount = 1, quality = 4 }, 0)
			feed:SetOptions(options({ showOwned = true, showGlow = true }))
			feed:Draw(1)
			local row = frameWith("Linen Cloth")
			assert.same({ true, "42", true, "bags-glow-4" }, { row.Owned.shown, row.Owned.text, row.Glow.shown, row.Glow.atlas })
			assert.same({ true, "loottoast-itemborder-4" }, { row.IconBorder.shown, row.IconBorder.atlas })
			feed:SetOptions(options({ showOwned = false, showGlow = false }))
			feed:Draw(1)
			assert.same({ false, false }, { row.Owned.shown, row.Glow.shown })
		end)

		it("reads owned counts again when asked", function()
			ns.Compat.Test.SetItems({ [2589] = { name = "Linen Cloth", owned = 0 } })
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", icon = 1, amount = 1, quality = 1 }, 0)
			feed:SetOptions(options({ showOwned = true }))
			feed:Draw(1)
			assert.is_false(frameWith("Linen Cloth").Owned.shown)
			ns.Compat.Test.SetItems({ [2589] = { name = "Linen Cloth", owned = 5 } })
			feed:RefreshOwned()
			feed:Draw(1)
			assert.same({ true, "5" }, { frameWith("Linen Cloth").Owned.shown, frameWith("Linen Cloth").Owned.text })
		end)

		it("spans one background over the rows on screen, fading to the right", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			model:Add({ kind = "xp", amount = 50 }, 0)
			feed:Draw(1)
			local background = feed.frame.Background
			assert.is_true(background.shown)
			assert.same({ 314, 91 }, { background.width, background.height })
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", -7, -7 }, background.points[1])
			assert.same({ "HORIZONTAL", 0.5, 0 }, { background.gradient[1], background.gradient[2].a, background.gradient[3].a })
			feed:Draw(7)
			assert.is_false(background.shown)
		end)

		it("shows sample rows in Edit Mode, also with no loot", function()
			feed:SetPreview(true)
			assert.is_true(feed.frame.shown)
			feed:Draw(0)
			assert.same({ "123456 copper@0", "Sample rare item@42", "Sample item@84" }, layout())
			feed:SetOptions(options({ maxRows = 8 }))
			feed:Draw(0)
			assert.equals(6, #layout())
			assert.is_true(feed.frame.PreviewBackground.shown)
			feed:SetPreview(false)
			assert.is_false(feed.frame.shown)
		end)

		it("shows an item's or currency's tooltip over its row", function()
			model:Add({ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", amount = 1 }, 0)
			model:Add({ kind = "currency", id = 3008, name = "Valorstones", amount = 1 }, 0)
			feed:Draw(1)
			local item = frameWith("Linen Cloth")
			item.scripts.OnEnter(item)
			assert.same({ LINK, true }, { tooltip.link, tooltip.shown })
			item.scripts.OnLeave(item)
			assert.is_false(tooltip.shown)
			local currency = frameWith("Valorstones")
			currency.scripts.OnEnter(currency)
			assert.equals(3008, tooltip.currency)
		end)

		it("shows money, experience and reputation in full in a tooltip, as an icon cannot", function()
			feed:SetOptions(options({ maxRows = 3 }))
			model:Add({ kind = "money", amount = 10245 }, 0)
			model:Add({ kind = "xp", amount = 12345 }, 0)
			model:Add({ kind = "reputation", name = "Stormwind", amount = -250 }, 0)
			feed:Draw(1)
			local function hover(label)
				local rowFrame = frameWith(label)
				rowFrame.scripts.OnEnter(rowFrame)
				return { tooltip.shown, unpack(tooltip.lines) }
			end
			assert.same({ true, "Money", "10245 copper" }, hover("10245 copper"))
			assert.same({ true, "Experience", "+12,345" }, hover("Experience"))
			assert.same({ true, "Reputation with Stormwind", "-250" }, hover("Reputation with Stormwind"))
		end)
	end)
end)
