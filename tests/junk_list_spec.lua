local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The junk list page in the options.
describe("junk list page", function()
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

	it("is a page of its own under the Junk page, opened from a button there", function()
		local page = api.FindCategory("Junk list")
		assert.equals(api.FindCategory("Junk"), page:GetParentCategory())
		assert.equals(JunkList.Page().frame, page.frame)
		local button = api.FindButton(api.FindCategory("Junk"), "Junk list")
		button.onClick()
		assert.equals(page:GetID(), api.opened)
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
		local page = JunkList.Page()
		-- What the options panel does when it shows the page.
		page.frame:Show()
		page.frame.OnRefresh()
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
		local page = JunkList.Page()
		page.frame:Show()
		page.frame.OnRefresh()
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
		JunkList.Page().frame:Show()
		ns.Profiles.Create("Alt")
		ns.Profiles.Switch("Alt")
		assert.is_nil(rowFor(10))
		ns.Profiles.Switch("Default")
		assert.is_not_nil(rowFor(10))
	end)
end)
