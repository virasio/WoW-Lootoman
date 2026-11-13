local Loader = require("tests.helpers.loader")

describe("loot feed model", function()
	local Model

	local ALL = { item = true, currency = true, money = true, reputation = true, xp = true }

	local function new(options)
		local merged = { maxRows = 3, duration = 6, fade = 1, minQuality = 0, kinds = ALL }
		for key, value in pairs(options or {}) do
			merged[key] = value
		end
		return Model.New(merged, 0)
	end

	local function item(id, amount, quality)
		return { kind = "item", id = id, link = "|Hitem:" .. id .. "|h[" .. id .. "]|h", name = tostring(id), amount = amount or 1, quality = quality or 1 }
	end

	-- What is drawn: "name×amount@alpha", newest first.
	local function drawn(model, now)
		local list = {}
		for index, view in ipairs(model:Visible(now)) do
			list[index] = ("%s×%s@%.2f"):format(view.row.name or view.row.kind, tostring(view.row.amount), view.alpha)
		end
		return list
	end

	before_each(function()
		Model = Loader.LoadAddon().Feed.Model
	end)

	it("shows new rows first", function()
		local model = new()
		model:Add(item(1), 0)
		model:Add(item(2), 1)
		assert.same({ "2×1@1.00", "1×1@1.00" }, drawn(model, 1))
	end)

	describe("merging", function()
		it("adds a repeated item to its row, restarts the timer and moves the row to the top", function()
			local model = new()
			model:Add(item(1, 2), 0)
			model:Add(item(2), 1)
			model:Add(item(1, 3), 5)
			assert.same({ "1×5@1.00", "2×1@1.00" }, drawn(model, 5))
			assert.same({ "1×5@1.00" }, drawn(model, 10.5))
		end)

		it("merges the same currency with its newest total, money, experience and faction", function()
			local model = new({ maxRows = 10 })
			model:Add({ kind = "currency", id = 3008, name = "Valorstones", amount = 5, total = 15 }, 0)
			model:Add({ kind = "currency", id = 3008, name = "Valorstones", amount = 2, total = 17 }, 1)
			model:Add({ kind = "money", amount = 150 }, 1)
			model:Add({ kind = "money", amount = 20 }, 2)
			model:Add({ kind = "xp", amount = 100 }, 2)
			model:Add({ kind = "xp", amount = 50 }, 3)
			model:Add({ kind = "reputation", name = "Stormwind", amount = 250 }, 3)
			model:Add({ kind = "reputation", name = "Stormwind", amount = -10 }, 4)
			model:Add({ kind = "reputation", name = "Darnassus" }, 4)
			model:Add({ kind = "reputation", name = "Darnassus" }, 5)
			assert.same({ "Darnassus×nil@1.00", "Stormwind×240@1.00", "xp×150@1.00", "money×170@1.00", "Valorstones×7@1.00" },
				drawn(model, 5))
			assert.equals(17, model:Visible(5)[5].row.total)
		end)

		it("takes the details of an item the client had not loaded the first time", function()
			local model = new()
			model:Add({ kind = "item", id = 1, link = "|Hitem:1|h[1]|h", name = "1", amount = 1 }, 0)
			model:Add({ kind = "item", id = 1, link = "|Hitem:1|h[1]|h", name = "1", amount = 2, icon = 134400, quality = 3 }, 1)
			model:Add({ kind = "item", id = 1, link = "|Hitem:1|h[1]|h", name = "1", amount = 1 }, 2)
			local row = model:Visible(2)[1].row
			assert.same({ 4, 134400, 3 }, { row.amount, row.icon, row.quality })
		end)

		it("keeps different items apart, and starts a new row once the old one has faded out", function()
			local model = new()
			model:Add(item(1), 0)
			model:Add(item(2), 0)
			model:Add(item(1), 7)
			assert.same({ "1×1@1.00" }, drawn(model, 7))
		end)
	end)

	describe("timing", function()
		it("shows a row, fades it out and removes it", function()
			local model = new()
			model:Add(item(1), 0)
			assert.same({ "1×1@1.00" }, drawn(model, 6))
			assert.same({ "1×1@0.50" }, drawn(model, 6.5))
			assert.is_false(model:Update(6.9))
			assert.is_true(model:Update(7))
			assert.same({}, drawn(model, 7))
		end)

		it("stops every timer while hovered", function()
			local model = new()
			model:Add(item(1), 0)
			model:SetHover(true, 5)
			assert.is_false(model:Update(100))
			assert.same({ "1×1@1.00" }, drawn(model, 100))
			model:Add(item(2), 50)
			model:SetHover(false, 105)
			assert.same({ "2×1@1.00", "1×1@1.00" }, drawn(model, 105.9))
			assert.same({ "2×1@1.00", "1×1@0.50" }, drawn(model, 106.5))
		end)
	end)

	describe("filters", function()
		it("drop items below the minimum quality, but keep items of unknown quality", function()
			local model = new({ minQuality = 2 })
			assert.is_nil(model:Add(item(1, 1, 1), 0))
			assert.is_not_nil(model:Add(item(2, 1, 2), 0))
			assert.is_not_nil(model:Add({ kind = "item", id = 3, name = "3", amount = 1 }, 0))
			assert.is_not_nil(model:Add({ kind = "currency", id = 1, name = "Coins", amount = 1, quality = 1 }, 0))
		end)

		it("drop kinds that are turned off", function()
			local model = new({ kinds = { item = false, currency = true, money = true, reputation = true, xp = false } })
			assert.is_nil(model:Add({ kind = "xp", amount = 10 }, 0))
			assert.is_nil(model:Add(item(1), 0))
			assert.is_not_nil(model:Add({ kind = "money", amount = 10 }, 0))
		end)
	end)

	describe("a full feed", function()
		it("fades the oldest rows out at once, quickly, when there are too many", function()
			local model = new({ fade = 2 })
			for id = 1, 4 do
				model:Add(item(id), 0)
			end
			assert.same({ "4×1@1.00", "3×1@1.00", "2×1@1.00", "1×1@0.80" }, drawn(model, 0.1))
			assert.is_true(model:Update(Model.PUSH_FADE))
			assert.same({ "4×1@1.00", "3×1@1.00", "2×1@1.00" }, drawn(model, Model.PUSH_FADE))
		end)

		it("pushes rows out when the limit shrinks", function()
			local model = new({ maxRows = 3 })
			for id = 1, 3 do
				model:Add(item(id), 0)
			end
			model:SetOptions({ maxRows = 1, duration = 6, fade = 1, minQuality = 0, kinds = ALL }, 1)
			model:Update(1 + Model.PUSH_FADE)
			assert.same({ "3×1@1.00" }, drawn(model, 1 + Model.PUSH_FADE))
		end)
	end)

	describe("sticky rows", function()
		local function stuck(model, now)
			local views = model:Visible(now)
			local last = views[#views]
			return last and last.stuck and { last.row.name, last.waiting } or nil
		end

		it("stick in the first slot when their time is up, while the others fade from the second", function()
			local model = new()
			model:SetSticky(model:Add(item(1), 0), "quest", 0)
			model:Add(item(2), 1)
			-- Its time is up at 6: it stays, the anchor edge's row.
			assert.same({ "2×1@1.00", "1×1@1.00" }, drawn(model, 6.5))
			assert.same({ "1", 0 }, stuck(model, 6.5))
			assert.same({ "1×1@1.00" }, drawn(model, 20))
			model:Update(20)
			assert.equals(1, #model.rows)
		end)

		it("wait under the first one, and take the slot in turn when it is let go", function()
			local model = new()
			local first = model:Add(item(1), 0)
			model:SetSticky(first, "quest", 0)
			local second = model:Add(item(2), 1)
			model:SetSticky(second, "recipe", 1)
			assert.same({ "1×1@1.00" }, drawn(model, 10))
			assert.same({ "1", 1 }, stuck(model, 10))
			assert.same({ first, second }, model:Stuck())
			model:Release(first)
			assert.same({ "2", 0 }, stuck(model, 10))
			model:Release(second)
			assert.same({}, drawn(model, 10))
		end)

		it("keep the first slot when the feed is full: a sticky row sticks, the oldest of the others fade", function()
			local model = new()
			model:SetSticky(model:Add(item(1), 0), "quest", 0)
			for id = 2, 4 do
				model:Add(item(id), 1)
			end
			-- Two rows fit after the stuck one, so 2 fades out quickly.
			assert.same({ "4×1@1.00", "3×1@1.00", "2×1@0.50", "1×1@1.00" }, drawn(model, 1.25))
			assert.same({ "4×1@1.00", "3×1@1.00", "1×1@1.00" }, drawn(model, 2))
		end)

		it("stick in the order they came when a full feed pushes several out", function()
			local model = new()
			local first = model:Add(item(1), 0)
			model:SetSticky(first, "quest", 0)
			local second = model:Add(item(2), 0)
			model:SetSticky(second, "quest", 0)
			for id = 3, 6 do
				model:Add(item(id), 1)
			end
			assert.same({ first, second }, model:Stuck())
		end)

		it("adds a stuck item looted again to its row, in place", function()
			local model = new()
			local quest = model:Add(item(1, 2), 0)
			model:SetSticky(quest, "container", 0)
			model:Add(item(2), 7)
			assert.equals(quest, model:Add(item(1, 3), 8))
			assert.same({ "2×1@1.00", "1×5@1.00" }, drawn(model, 8))
			assert.is_true(quest.stuck)
		end)

		it("goes at once when it is no longer usable, and a row not stuck yet just fades as usual", function()
			local model = new()
			local quest = model:Add(item(1), 0)
			model:SetSticky(quest, "quest", 0)
			local later = model:Add(item(2), 1)
			model:SetSticky(later, "recipe", 1)
			assert.same({ "1", 0 }, stuck(model, 6.5))
			model:SetSticky(quest, nil, 6.5)
			model:SetSticky(later, nil, 6.5)
			assert.same({ "2×1@1.00" }, drawn(model, 6.5))
			assert.same({}, drawn(model, 8.5))
		end)

		it("lets an unstuck row fade out from its time being up, and sticks it again if it is kept before it is gone", function()
			local model = new()
			local quest = model:Add(item(1), 0)
			model:SetSticky(quest, "quest", 0)
			model:Add(item(2), 6)
			assert.same({ "1", 0 }, stuck(model, 7))
			model:Unstick(quest, 7)
			assert.same({ {}, nil }, { model:Stuck(), quest.sticky })
			-- Halfway through its fade, after the newer row.
			assert.same({ "2×1@1.00", "1×1@0.50" }, drawn(model, 7.5))
			model:SetSticky(quest, "quest", 7.5)
			model:Update(7.6)
			assert.same({ "1", 0 }, stuck(model, 7.6))
			assert.same({ "2×1@1.00", "1×1@1.00" }, drawn(model, 9))
			model:Unstick(quest, 9)
			model:Update(10)
			assert.same({ "2×1@1.00" }, drawn(model, 10))
		end)

		it("does not count the time the pointer is over the feed, and keeps a stuck row while it waits", function()
			local model = new()
			model:SetSticky(model:Add(item(1), 0), "quest", 0)
			model:SetHover(true, 7)
			model:SetHover(false, 100)
			assert.same({ "1×1@1.00" }, drawn(model, 200))
		end)
	end)
end)
