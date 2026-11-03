local Loader = require("tests.helpers.loader")

describe("junk", function()
	local ns, Marks, Junk, changes

	local GRAY = { itemID = 100, quality = 0 }
	local WHITE = { itemID = 200, quality = 1 }
	local GREEN = { itemID = 300, quality = 2 }
	local UNLOADED = { itemID = 400 }

	local function decide(item)
		local decision = Junk.Decide(item)
		return { decision.junk, decision.reason }
	end

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon())
		Marks, Junk = ns.Marks, ns.Rules.Junk
		changes = {}
		ns.Bus:On("MarksChanged", "test", function(_, itemID, mark) changes[#changes + 1] = { itemID, mark } end)
	end)

	it("is every gray item, and nothing else unless marked", function()
		assert.same({ true, "gray" }, decide(GRAY))
		assert.same({ false }, decide(WHITE))
		assert.same({ false }, decide(UNLOADED))
	end)

	it("takes in items marked junk, of any quality, and leaves out gray items marked not junk", function()
		Marks.Set(GREEN.itemID, "junk")
		Marks.Set(UNLOADED.itemID, "junk")
		Marks.Set(GRAY.itemID, "notJunk")
		assert.same({ true, "marked" }, decide(GREEN))
		assert.same({ true, "marked" }, decide(UNLOADED))
		assert.same({ false, "notJunk" }, decide(GRAY))
		-- "Not junk" means nothing for an item that is not gray.
		Marks.Set(WHITE.itemID, "notJunk")
		assert.same({ false }, decide(WHITE))
	end)

	it("follows a drag into the junk section and out of it", function()
		Junk.MarkJunk(GREEN)
		Junk.MarkNotJunk(GRAY)
		assert.same({ "junk", "notJunk" }, { Marks.Get(GREEN.itemID), Marks.Get(GRAY.itemID) })
		Junk.MarkNotJunk(GREEN)
		Junk.MarkJunk(GRAY)
		assert.same({ nil, nil }, { Marks.Get(GREEN.itemID), Marks.Get(GRAY.itemID) })
		assert.same({ true, false }, { Junk.Decide(GRAY).junk, Junk.Decide(GREEN).junk })
		assert.same({ { 300, "junk" }, { 100, "notJunk" }, { 300 }, { 100 } }, changes)
	end)

	describe("marks", function()
		it("are listed by item ID, and announced only when they change", function()
			Marks.Set(300, "junk")
			Marks.Set(100, "notJunk")
			Marks.Set(300, "junk")
			assert.same({ { itemID = 100, mark = "notJunk" }, { itemID = 300, mark = "junk" } }, Marks.List())
			assert.same({ { 300, "junk" }, { 100, "notJunk" } }, changes)
		end)

		it("are cleared all at once", function()
			Marks.Clear()
			Marks.Set(300, "junk")
			Marks.Set(100, "notJunk")
			Marks.Clear()
			assert.same({}, Marks.List())
			assert.same({ { 300, "junk" }, { 100, "notJunk" }, {} }, changes)
		end)

		it("belong to the profile", function()
			Marks.Set(300, "junk")
			ns.Profiles.Create("Alt")
			ns.Profiles.Switch("Alt")
			assert.same({}, Marks.List())
			Marks.Set(100, "junk")
			ns.Profiles.Switch("Default")
			assert.same({ { itemID = 300, mark = "junk" } }, Marks.List())
		end)

		it("ignore saved values that are not marks, and refuse to set them", function()
			ns.Storage:GetSection("marks")[500] = "keep forever"
			ns.Storage:GetSection("marks").oops = "junk"
			assert.same({ nil, {} }, { Marks.Get(500), Marks.List() })
			assert.has_error(function() Marks.Set(500, "keep forever") end)
			assert.has_error(function() Marks.Set("500", "junk") end)
		end)
	end)
end)
