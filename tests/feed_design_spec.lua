local Loader = require("tests.helpers.loader")

describe("loot feed designs", function()
	local ns, Design, section

	before_each(function()
		ns = Loader.LoadAddon()
		Design = ns.Feed.Design
		section = {}
	end)

	it("scale every length of a design with the size, and size the icon by the row's height", function()
		local layout = Design.Layout(Design.LARGE, 16)
		assert.same({ 43, 9, 369 }, { layout.height, layout.gap, layout.width })
		assert.same({ shown = true, size = 100, pixels = 43, anchor = "row", point = "LEFT", x = 0, y = 0 }, layout.parts.icon)
		assert.same({ shown = true, fontSize = 16, width = 246, align = "LEFT", anchor = "icon", point = "RIGHT", x = 14, y = 0 },
			layout.parts.name)
		assert.same({ shown = true }, layout.parts.glow)
		Design.Set(section, "row", "height", 20)
		assert.equals(20, Design.Layout(Design.Current(section), 13).parts.icon.pixels)
		Design.Set(section, "icon", "size", 75)
		assert.equals(15, Design.Layout(Design.Current(section), 13).parts.icon.pixels)
	end)

	describe("the player's design", function()
		it("is the large design until the player changes it", function()
			assert.same(Design.LARGE, Design.Current(section))
			assert.are_not.equal(Design.LARGE, Design.Current(section))
			assert.same({}, section)
		end)

		it("keeps only the values that differ from its base", function()
			Design.Set(section, "name", "x", 50)
			Design.Set(section, "row", "height", 40)
			Design.Set(section, "icon", "shown", false)
			assert.same({ schema = 1, changes = { name = { x = 50 }, row = { height = 40 }, icon = { shown = false } } }, section)
			local design = Design.Current(section)
			assert.same({ 50, 40, false }, { design.parts.name.x, design.height, design.parts.icon.shown })
			assert.equals(13, design.parts.name.fontSize)
			Design.Set(section, "name", "x", 11)
			Design.Set(section, "row", "height", 35)
			Design.Set(section, "icon", "shown", true)
			assert.same({ schema = 1, changes = {} }, section)
		end)

		it("keeps numbers within their limits", function()
			assert.equals(100, Design.Set(section, "icon", "size", 500))
			assert.equals(8, Design.Set(section, "name", "fontSize", 1))
			assert.equals(0, Design.Set(section, "row", "gap", -5))
		end)

		it("refuses values a design cannot take", function()
			assert.error_matches(function() Design.Set(section, "name", "colour", 1) end, "design value name.colour cannot be 1")
			assert.error_matches(function() Design.Set(section, "tail", "x", 1) end, "design value tail.x cannot be 1")
			assert.error_matches(function() Design.Set(section, "row", "padding", 10) end, "row.padding cannot be 10")
			assert.error_matches(function() Design.Set(section, "name", "point", "MIDDLE") end, "name.point cannot be MIDDLE")
			assert.error_matches(function() Design.Set(section, "name", "align", "CENTER") end, "name.align cannot be CENTER")
			assert.error_matches(function() Design.Set(section, "glow", "anchor", "row") end, "glow.anchor cannot be row")
			assert.error_matches(function() Design.Set(section, "name", "anchor", "name") end, "name.anchor cannot be name")
		end)

		it("refuses an anchor that goes round in a loop", function()
			-- The amount is anchored to the name, the name to the icon.
			assert.error_matches(function() Design.Set(section, "icon", "anchor", "amount") end, "icon.anchor cannot be amount")
			assert.same({ "row" }, Design.Targets(Design.Current(section), "icon"))
			assert.same({ "row", "icon", "owned" }, Design.Targets(Design.Current(section), "name"))
			-- The icon's anchor can only be taken after the name's one.
			Design.Set(section, "name", "anchor", "row")
			Design.Set(section, "icon", "anchor", "name")
			local design = Design.Current(section)
			assert.same({ "name", "row" }, { design.parts.icon.anchor, design.parts.name.anchor })
		end)

		it("ignores saved changes it does not know, or of the wrong type", function()
			section.schema = 1
			section.changes = { name = { x = "far", colour = 3, point = "MIDDLE" }, tail = { x = 1 }, row = { parts = {} },
				icon = { anchor = "amount" }, owned = 7 }
			assert.same(Design.LARGE, Design.Current(section))
		end)

		it("drops changes saved under another schema", function()
			section.schema, section.base, section.changes = 0, "compact", { icon = { size = 24 } }
			assert.same(Design.COMPACT, Design.Current(section))
			Design.Set(section, "row", "gap", 5)
			assert.same({ schema = 1, base = "compact", changes = { row = { gap = 5 } } }, section)
		end)

		it("starts from another built-in design", function()
			section.base = "compact"
			assert.same(Design.COMPACT, Design.Current(section))
			Design.Set(section, "name", "fontSize", 14)
			assert.same({ schema = 1, base = "compact", changes = { name = { fontSize = 14 } } }, section)
		end)

		it("goes back to its built-in design on reset", function()
			section.base = "minimal"
			Design.Set(section, "amount", "x", 20)
			Design.Reset(section)
			assert.same(Design.MINIMAL, Design.Current(section))
			assert.equals("minimal", section.base)
		end)

		it("falls back to the large design when its base is unknown", function()
			section.base = "gone"
			assert.same(Design.LARGE, Design.Current(section))
		end)
	end)

	describe("anchors", function()
		it("attach a text by the side of its alignment, an icon inside the row or beside its element", function()
			local design = Design.Current(section)
			assert.same({ "LEFT", "LEFT", "LEFT", "BOTTOMRIGHT" }, { Design.OwnPoint(design, "icon"), Design.OwnPoint(design, "name"),
				Design.OwnPoint(design, "amount"), Design.OwnPoint(design, "owned") })
			design.parts.name.point, design.parts.name.align = "TOP", "RIGHT"
			assert.equals("TOPRIGHT", Design.OwnPoint(design, "name"))
			design.parts.icon.point = "CENTER"
			assert.equals("CENTER", Design.OwnPoint(design, "icon"))
			design.parts.icon.anchor, design.parts.icon.point = "owned", "TOPRIGHT"
			assert.equals("TOPLEFT", Design.OwnPoint(design, "icon"))
		end)
	end)

	describe("the row's box", function()
		it("keeps every part inside it, however the values are set", function()
			Design.Set(section, "icon", "size", 60)
			assert.equals(279, Design.Set(section, "icon", "x", 300))
			Design.Set(section, "name", "width", 400)
			local design = Design.Current(section)
			assert.same({ 60, 279 }, { design.parts.icon.size, design.parts.icon.x })
			-- As wide as the row.
			assert.equals(300, design.parts.name.width)
		end)

		it("shrinks the parts when the row gets smaller, and lets them grow back", function()
			Design.Set(section, "row", "height", 12)
			local design = Design.Current(section)
			assert.same({ 12, 12, 12 }, { Design.IconSize(design), design.parts.name.fontSize, design.parts.owned.fontSize })
			Design.Set(section, "row", "height", 20)
			assert.same({ 0, 8 }, { Design.Range(Design.Current(section), "owned", "y") })
			Design.Set(section, "row", "height", 35)
			assert.same(Design.LARGE, Design.Current(section))
		end)

		it("gives the whole numbers each value may take", function()
			local design = Design.Current(section)
			assert.same({ 0, 265 }, { Design.Range(design, "icon", "x") })
			assert.same({ -11, 11 }, { Design.Range(design, "name", "y") })
			-- A text keeps room for two digits up to the edge it grows to.
			assert.same({ -35, 253 }, { Design.Range(design, "name", "x") })
			assert.same({ -23, 265 }, { Design.Range(design, "owned", "x") })
			assert.same({ 12, 80 }, { Design.Range(design, "row", "height") })
			assert.same({ 20, 300 }, { Design.Range(design, "name", "width") })
			assert.same({ 20, 100 }, { Design.Range(design, "icon", "size") })
		end)

		it("leaves the built-in designs as they are", function()
			for _, name in ipairs(Design.ORDER) do
				local fitted = Design.Fit(Design.Current({ base = name }))
				assert.same(Design.BUILT_IN[name], fitted, name)
			end
		end)
	end)

	describe("text room", function()
		it("gives a text the width of its words, up to its maximum and the row's edge, less what follows it", function()
			Design.Set(section, "name", "width", 300)
			local rects = Design.Arrange(Design.Current(section), { name = 300, amount = 14 })
			-- The name starts at 46; the amount after it takes 6 + 14 of the 254 up to the edge.
			assert.same({ 46, 280, 234 }, { rects.name.left, rects.name.right, rects.name.width })
			assert.same({ 286, 300 }, { rects.amount.left, rects.amount.right })
			rects = Design.Arrange(Design.Current(section), { name = 70 })
			assert.same({ 70, 0 }, { rects.name.width, rects.amount.width })
		end)

		it("lets a right-aligned text grow to the left", function()
			Design.Set(section, "name", "anchor", "row")
			Design.Set(section, "name", "align", "RIGHT")
			local design = Design.Current(section)
			-- On the row's right edge.
			assert.equals(0, design.parts.name.x)
			local rects = Design.Arrange(design, { name = 100 })
			assert.same({ 200, 300 }, { rects.name.left, rects.name.right })
			assert.equals(200, Design.Arrange(design, { name = 900 }).name.width)
		end)
	end)

	describe("dragging a part", function()
		it("moves it by the pointer's distance, on the grid", function()
			local move = Design.Drag(section, "name", 1)
			move(5, -3)
			assert.same({ 17, -4 }, { Design.Current(section).parts.name.x, Design.Current(section).parts.name.y })
			move(0.9, 0.9)
			assert.same({ 11, 0 }, { Design.Current(section).parts.name.x, Design.Current(section).parts.name.y })
		end)

		it("turns screen pixels into design pixels at a bigger size", function()
			local move = Design.Drag(section, "icon", 2)
			move(10, 0)
			assert.equals(6, Design.Current(section).parts.icon.x)
		end)

		it("keeps the part inside the row, and saves where it stopped", function()
			Design.Drag(section, "owned", 1)(1000, -1000)
			assert.same({ x = 265, y = 0 }, section.changes.owned)
			Design.Drag(section, "icon", 1)(-50, 50)
			assert.is_nil(section.changes.icon)
		end)
	end)

	describe("in the loot feed", function()
		local module

		before_each(function()
			Loader.Start(ns)
			module = ns.Modules:Get("LootFeed")
		end)

		it("draws the layout the profile uses, saved for the whole account", function()
			Design.Set(module:DesignSection(), "row", "height", 40)
			module:Apply()
			assert.equals(40, module.feed.options.layout.height)
			assert.same({ row = { height = 40 } }, ns.Storage:GetGlobalSection("feedLayouts").Default.changes)
		end)

		it("draws the layout of each profile", function()
			ns.Feed.Layouts.Create("Raid", "compact")
			ns.Feed.Layouts.Use("Raid")
			assert.equals(24, module.feed.options.layout.height)
			ns.Profiles.Switch(ns.Profiles.Create("Other"))
			assert.equals(35, module.feed.options.layout.height)
			ns.Profiles.Switch("Default")
			assert.equals(24, module.feed.options.layout.height)
		end)
	end)
end)
