local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("Junk module", function()
	local ns, Junk, log

	-- A part that records its lifecycle and listens through the module.
	local function part(name)
		return {
			Enable = function()
				log[#log + 1] = "enable " .. name
				Junk.ListenEvent("MERCHANT_SHOW", function(event) log[#log + 1] = name .. " " .. event end)
				Junk.Listen("MarksChanged", function(message, itemID) log[#log + 1] = ("%s %s %s"):format(name, message, itemID) end)
			end,
			Disable = function()
				log[#log + 1] = "disable " .. name
			end,
		}
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Junk, log = ns.Modules:Get("Junk"), {}
	end)

	it("starts its parts in order and stops them in reverse", function()
		Junk.AddPart(part("first"))
		Junk.AddPart(part("second"))
		Loader.Start(ns)
		ns.Modules:SetEnabled("Junk", false)
		assert.same({ "enable first", "enable second", "disable second", "disable first" }, log)
	end)

	it("hands events and messages to every part that listens, while it is on", function()
		Junk.AddPart(part("first"))
		Junk.AddPart(part("second"))
		Loader.Start(ns)
		log = {}
		ns.Compat.Test.FireEvent("MERCHANT_SHOW")
		ns.Marks.Set(42, "junk")
		assert.same({ "first MERCHANT_SHOW", "second MERCHANT_SHOW", "first MarksChanged 42", "second MarksChanged 42" }, log)
		ns.Modules:SetEnabled("Junk", false)
		log = {}
		ns.Compat.Test.FireEvent("MERCHANT_SHOW")
		ns.Marks.Set(43, "junk")
		assert.same({}, log)
		assert.same({}, ns.Bus:GetEvents(Junk))
	end)

	it("stops the other parts when one fails to stop, and reports it", function()
		Junk.AddPart(part("first"))
		Junk.AddPart({ Enable = function() end, Disable = function() error("broken part") end })
		Loader.Start(ns)
		ns.Modules:SetEnabled("Junk", false)
		assert.same("disable first", log[#log])
		assert.matches("broken part", ns.Compat.Test.state.errors[1])
	end)

	it("has a switch on the main page after fast autoloot, the junk list's button under it, then its choices", function()
		SettingsAPI.Install()
		ns = Loader.Start(Loader.LoadAddon({ skip = {} }))
		local texts = {}
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			texts[#texts + 1] = tostring(entry.text)
		end
		assert.is_true(table.concat(texts, "|"):find("Enable Junk Management|Copy the QuestieDB Address|Set Up the Junk List|Loot Window Button|Style|Bag Window Button|At Merchants|Suggestions|Quest Done|Leftovers from Quests", 1, true) ~= nil)
		-- Fast autoloot's last item is the box of the game's Auto Loot settings.
		assert.is_true(table.concat(texts, "|"):find("Confirm Bind%-on%-Pickup Items when Alone||Enable Junk Management") ~= nil)
		local junk = ns.Modules:Get("Junk")
		assert.same({ "full", "large", "window", true }, { junk:Get("tossButton"), junk:Get("tossStyle"), junk:Get("selling"), junk:IsActive() })
		-- Turned off, everything under it is greyed out.
		local page = ns.SettingsPanel.main
		local function item(text)
			for _, entry in ipairs(page.items) do
				if entry.text == text then
					return entry.region
				end
			end
		end
		ns.Modules:SetEnabled("Junk", false)
		page:Refresh()
		assert.same({ false, false }, { item("Set Up the Junk List").enabled, ns.Modules:Get("Junk"):IsActive() })
	end)

	describe("the QuestieDB note", function()
		local function page(withQuestieDB)
			SettingsAPI.Install()
			ns = Loader.LoadAddon({ skip = {} })
			if withQuestieDB then
				rawset(_G, "LibQuestieDB", { RequireContract = function() return true end, Item = { relatedQuests = function() end } })
				ns.Compat.Test.state.addons.QuestieDB = true
			end
			Loader.Start(ns)
			local found = {}
			for _, entry in ipairs(ns.SettingsPanel.main.items) do
				if entry.text then
					found[entry.text] = entry
				end
			end
			return found
		end

		after_each(function()
			rawset(_G, "LibQuestieDB", nil)
		end)

		it("says under the switch that quests are better with QuestieDB, and copies its address", function()
			local items = page(false)
			assert.matches("better with QuestieDB", items["Enable Junk Management"].region.note.text)
			local copy = items["Copy the QuestieDB Address"]
			assert.is_true(copy.visible())
			copy.region.scripts.OnClick(copy.region)
			local dialog = rawget(_G, ns.SettingsPanel.COPY_NAME)
			assert.same({ true, "https://www.curseforge.com/wow/addons/questiedb" }, { dialog:IsShown(), dialog.box:GetText() })
			-- Typing changes nothing.
			dialog.box:SetText("x")
			dialog.box.scripts.OnTextChanged(dialog.box, true)
			assert.equals("https://www.curseforge.com/wow/addons/questiedb", dialog.box:GetText())
		end)

		it("is not there while QuestieDB works", function()
			local items = page(true)
			assert.is_nil(items["Enable Junk Management"].region.note)
			assert.is_false(items["Copy the QuestieDB Address"].visible())
		end)
	end)
end)

