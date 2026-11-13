local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The junk list window.
describe("junk list window", function()
	local ns, api, JunkList, Marks

	local function texts()
		local list = {}
		for index, line in ipairs(JunkList.Lines()) do
			list[index] = line.kind == "item" and ("  " .. line.text) or line.text
		end
		return list
	end

	local function rowFor(itemID)
		for _, entry in ipairs(JunkList.Page().rows) do
			if entry:IsShown() and entry.line and entry.line.itemID == itemID then
				return entry
			end
		end
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.Start(Loader.LoadAddon({ skip = {} }))
		JunkList, Marks = ns.JunkList, ns.Marks
		ns.Compat.Test.SetItems({
			[10] = { name = "Zebra Hide", link = "[Zebra Hide]", icon = 1010 },
			[20] = { name = "Apple", link = "[Apple]", icon = 1020 },
			[30] = { name = "Old Boot", link = "[Old Boot]", icon = 1030 },
		})
	end)

	local function mainButton()
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			if entry.text == "Set up the junk list" then
				return entry.region
			end
		end
	end

	it("is a window of its own, opened from the options' main page and from the sort windows, closed with Escape", function()
		assert.is_nil(api.FindCategory("Junk list"))
		assert.is_nil(JunkList.Page())
		local button = mainButton()
		button.scripts.OnClick(button)
		local frame = JunkList.Page().frame
		assert.same({ true, "Junk list", "LootomanJunkList" }, { frame.shown, frame.title, frame.name })
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(frame.shown)
		-- The sort window's own button opens it too.
		local grid = ns.Modules:Get("Junk").ItemGrid.Create({ name = "LootomanTestGrid", title = "Sort junk", kind = "toss" })
		assert.equals("Junk list", grid.listButton.text)
		grid.listButton.scripts.OnClick(grid.listButton)
		assert.is_true(frame.shown)
	end)

	it("opens only out of combat the first time", function()
		ns.Compat.Test.SetCombat(true)
		assert.is_false(JunkList.Open())
		assert.matches("out of combat", ns.Compat.Test.state.printed[#ns.Compat.Test.state.printed])
		ns.Compat.Test.SetCombat(false)
		assert.is_true(JunkList.Open())
	end)

	it("lists the items marked junk and not junk, each by name", function()
		assert.same({ "Marked as junk", "None", "Not junk", "None" }, texts())
		Marks.Set(10, "junk")
		Marks.Set(20, "junk")
		Marks.Set(30, "notJunk")
		Marks.Set(99, "junk")
		assert.same({ "Marked as junk", "  Item 99", "  [Apple]", "  [Zebra Hide]", "Not junk", "  [Old Boot]" }, texts())
	end)

	it("removes one mark, and clears them all after a question", function()
		Marks.Set(10, "junk")
		Marks.Set(30, "notJunk")
		JunkList.Open()
		local page = JunkList.Page()
		local zebra = rowFor(10)
		zebra.remove.scripts.OnClick(zebra.remove)
		assert.same({ { itemID = 30, mark = "notJunk" } }, Marks.List())
		assert.is_nil(rowFor(10))
		page.clear.scripts.OnClick(page.clear)
		assert.same({ { itemID = 30, mark = "notJunk" } }, Marks.List())
		api.AcceptPopup()
		assert.same({}, Marks.List())
		assert.is_false(page.clear:IsEnabled())
	end)

	it("clears nothing when the profile changed while the question was open", function()
		Marks.Set(10, "junk")
		JunkList.Open()
		local page = JunkList.Page()
		page.clear.scripts.OnClick(page.clear)
		ns.Profiles.Create("Alt")
		ns.Profiles.Switch("Alt")
		Marks.Set(20, "junk")
		api.AcceptPopup()
		assert.same({ { itemID = 20, mark = "junk" } }, Marks.List())
		ns.Profiles.Switch("Default")
		assert.same({ { itemID = 10, mark = "junk" } }, Marks.List())
	end)

	it("follows the profile", function()
		Marks.Set(10, "junk")
		JunkList.Open()
		ns.Profiles.Create("Alt")
		ns.Profiles.Switch("Alt")
		assert.is_nil(rowFor(10))
		ns.Profiles.Switch("Default")
		assert.is_not_nil(rowFor(10))
	end)
end)
