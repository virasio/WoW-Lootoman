local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local UI = require("tests.mocks.UI")

-- The Ninja Rules window (Modules/Rolls/NinjaRules.lua) and its place on the options page.

describe("the ninja rules window", function()
	local ns, Test, Window, frame

	before_each(function()
		SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Test = ns.Compat.Test
		Loader.Start(ns)
		Window = ns.Rolls.NinjaRules
	end)

	local function open()
		Test.RunSlashCommand("LOOTOMAN", "ninja")
		frame = Window.Frame()
		return frame
	end

	local function row(part, key)
		for _, each in ipairs(frame.rows) do
			if each.part == part and each.key == key then
				return each
			end
		end
	end

	local function click(check, checked)
		check:SetChecked(checked)
		check.scripts.OnClick(check)
	end

	it("opens with /ltm ninja on the character's class, with every class of the client", function()
		open()
		assert.same({ true, "Ninja Rules", "LootomanNinjaRules", "WARRIOR" }, { frame.shown, frame.title, frame.name, frame.class })
		assert.equals(9, #frame.classButtons)
		assert.is_true(frame.classesTab:IsShown())
		assert.is_false(frame.checksTab:IsShown())
		-- Both tabs scroll; the Reset buttons stay outside the scrolled rules.
		assert.equals("ScrollFrameTemplate", frame.classesContent.scroll.template)
		assert.equals("ScrollFrameTemplate", frame.checksContent.scroll.template)
		assert.equals(frame.classesContent, frame.rows[1].check:GetParent())
		assert.equals(frame.classesTab, frame.resetClass:GetParent())
		-- The weapons in two columns, their labels cut short at the column's width.
		local weapons = {}
		for _, each in ipairs(frame.rows) do
			if each.part == "weapons" then
				weapons[#weapons + 1] = each
			end
		end
		assert.same({ 8, 218, 8 }, { weapons[1].check.points[1][4], weapons[2].check.points[1][4], weapons[3].check.points[1][4] })
		assert.equals(178, weapons[1].check.label.width)
	end)

	it("ticks what counts as the class's own, its level beside an armor type, and greys what it cannot equip", function()
		open()
		assert.same({ false, true }, { row("armor", 1).check:GetChecked(), row("armor", 1).check:IsEnabled() })
		assert.same({ true, "40" }, { row("armor", 2).check:GetChecked(), row("armor", 2).level:GetText() })
		assert.same({ true, "" }, { row("armor", 4).check:GetChecked(), row("armor", 4).level:GetText() })
		assert.same({ false, false }, { row("weapons", 19).check:GetChecked(), row("weapons", 19).check:IsEnabled() })
		assert.same({ true, false }, { row("stats", "STRENGTH").check:GetChecked(), row("stats", "INTELLECT").check:GetChecked() })
		Window.SelectClass("MAGE")
		assert.is_false(row("armor", 4).check:IsEnabled())
		assert.is_true(row("armor", 1).check:GetChecked())
	end)

	it("keeps a tick and a level, an empty box for any level, and refuses a level that is none", function()
		open()
		click(row("armor", 1).check, true)
		assert.is_true(ns.NeedRules.Value("WARRIOR", "armor", 1))
		local leather = row("armor", 2).level
		leather:SetText("30")
		leather.scripts.OnEnterPressed(leather)
		assert.equals(30, ns.NeedRules.Value("WARRIOR", "armor", 2))
		leather:SetText("")
		leather.scripts.OnEditFocusLost(leather)
		assert.is_true(ns.NeedRules.Value("WARRIOR", "armor", 2))
		leather:SetText("99")
		leather.scripts.OnEnterPressed(leather)
		assert.is_true(ns.NeedRules.Value("WARRIOR", "armor", 2))
		assert.equals("", leather:GetText())
		-- Unticked, its box is greyed.
		click(row("armor", 2).check, false)
		assert.is_false(row("armor", 2).level:IsEnabled())
		click(row("weapons", 15).check, false)
		assert.is_false(ns.NeedRules.Value("WARRIOR", "weapons", 15))
	end)

	it("resets the class, and every class", function()
		open()
		click(row("armor", 1).check, true)
		Window.SelectClass("MAGE")
		click(row("stats", "AGILITY").check, true)
		frame.resetClass.scripts.OnClick(frame.resetClass)
		assert.is_false(ns.NeedRules.IsChanged("MAGE"))
		assert.is_true(ns.NeedRules.IsChanged("WARRIOR"))
		frame.resetAll.scripts.OnClick(frame.resetAll)
		assert.equals(0, ns.NeedRules.ChangedCount())
	end)

	it("sets the checks in their tab, for the profile, the detection's switch the same as the options page's", function()
		open()
		frame.tab2.scripts.OnClick(frame.tab2)
		assert.is_true(frame.checksTab:IsShown())
		local checks = frame.checks
		assert.same({ "ninja", false, false }, { checks[1].key, checks[1]:GetChecked(), checks[2]:IsEnabled() })
		click(checks[1], true)
		assert.is_true(ns.Storage:Get("Rolls", "ninja"))
		assert.is_true(checks[2]:IsEnabled())
		click(checks[2], false)
		assert.is_false(ns.Storage:Get("Rolls", "checkArmor"))
		local root = UI.OpenMenu(frame.dropdowns[1])
		assert.same({ "Lenient", "Normal", "Strict" }, { root.entries[1].text, root.entries[2].text, root.entries[3].text })
		assert.is_true(root.entries[2].isSelected())
		root.entries[3].setSelected()
		assert.equals("strict", ns.Storage:Get("Rolls", "strictness"))
		root = UI.OpenMenu(frame.dropdowns[2])
		root.entries[2].setSelected()
		assert.equals(3, ns.Storage:Get("Rolls", "minQuality"))
		-- The options page's checkbox and button.
		local page = ns.SettingsPanel.main
		page:Refresh()
		local found
		for _, item in ipairs(page.items) do
			if item.text == "Detect Ninja Looters" then
				found = item
			end
		end
		assert.is_true(found.region:GetChecked())
		assert.is_true(page.ninjaRules:IsEnabled())
	end)

	it("opens from the options page's button, closes with Escape, and opens the first time only out of combat", function()
		local page = ns.SettingsPanel.main
		page.ninjaRules.scripts.OnClick(page.ninjaRules)
		assert.is_true(Window.Frame().shown)
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(Window.Frame().shown)
		SettingsAPI.Install()
		local fresh = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Loader.Start(fresh)
		fresh.Compat.Test.SetCombat(true)
		assert.is_false(fresh.Rolls.NinjaRules.Open())
		assert.matches("out of combat", fresh.Compat.Test.state.printed[#fresh.Compat.Test.state.printed])
	end)

	it("lists /ltm ninja in the help", function()
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "help")
		local found = false
		for _, line in ipairs(Test.state.printed) do
			found = found or line:find("/ltm ninja: open the ninja rules", 1, true) ~= nil
		end
		assert.is_true(found)
	end)
end)
