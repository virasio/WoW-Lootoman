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

	describe("row look", function()
		it("shows an item with its quality colour, border and count", function()
			local look = Frames.Describe({ kind = "item", name = "Blade", icon = 1, quality = 4, amount = 3 })
			assert.same({ icon = 1, label = "Blade", labelColor = { 0.64, 0.21, 0.93 }, amount = "×3",
				amountColor = { 1, 1, 1 }, border = { 0.64, 0.21, 0.93 } }, look)
			assert.is_nil(Frames.Describe({ kind = "item", name = "Blade", quality = 4, amount = 1 }).amount)
		end)

		it("marks an item that did not fit", function()
			local look = Frames.Describe({ kind = "skipped", name = "Hearthstone", quality = 1, amount = 1 })
			assert.same({ "No room in bags", { 1, 0.13, 0.13 } }, { look.amount, look.amountColor })
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

		it("uses its own phrase for a faction name the client declined", function()
			assert.equals("Штормграда reputation", Frames.Describe({ kind = "reputation", name = "Штормграда", declined = true, amount = 5 }).label)
		end)
	end)

	describe("feed", function()
		local model, feed

		before_each(function()
			model = newModel()
			feed = Frames.Create(model)
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
			assert.same({ "100 copper@0", "Experience@30" }, layout())
			assert.same({ "BOTTOMLEFT", feed.frame, "BOTTOMLEFT", 0, 30 }, frameWith("Experience").points[1])
			feed:SetOptions({ direction = "down", maxRows = 3 })
			assert.same({ "TOPLEFT", feed.frame, "TOPLEFT", 0, -30 }, frameWith("Experience").points[1])
			assert.same({ "TOPLEFT", feed.frame, "TOPLEFT", 0, 0 }, frameWith("100 copper").points[1])
			assert.equals(88, feed.frame.height)
		end)

		it("slides the rows to their new places when the oldest one leaves", function()
			model:Add({ kind = "money", amount = 100 }, 0)
			model:Add({ kind = "xp", amount = 50 }, 3)
			feed:Draw(6.99)
			assert.same({ "100 copper@0", "Experience@30" }, layout())
			feed:Draw(7)
			assert.same({ "Experience@28" }, layout())
			feed:Draw(7.05)
			assert.same({ "Experience@18" }, layout())
			feed:Draw(7.15)
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
			feed:SetOptions({ direction = "up", maxRows = 2 })
			for id = 1, 3 do
				model:Add({ kind = "item", id = id, name = "Item " .. id, amount = 1 }, 0)
			end
			feed:Draw(0.1)
			assert.same({ "Item 1@-30", "Item 2@0", "Item 3@30" }, layout())
		end)

		it("shows sample rows in Edit Mode, also with no loot", function()
			feed:SetPreview(true)
			assert.is_true(feed.frame.shown)
			feed:Draw(0)
			assert.same({ "Experience@0", "123456 copper@30" }, layout())
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
	end)
end)
