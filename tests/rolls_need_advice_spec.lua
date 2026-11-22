local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local UI = require("tests.mocks.UI")

-- Whether to need (Modules/Rolls/NeedAdvice.lua): a line on the Loot Rolls
-- window's rows from Forever Leveling BiS or Pawn, and the note on the
-- options page.

local function link(id, name)
	return ("|cff1eff00|Hitem:%d::::::::40|h[%s]|h|r"):format(id, name)
end

local HELM, BOOTS, RING, WORN = link(100, "Mail Helm"), link(101, "Boots"), link(200, "Ring"), link(102, "Worn Belt")
local ITEMS = {
	[100] = { name = "Mail Helm", link = HELM, quality = 2, icon = 1001, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", stats = {} },
	[101] = { name = "Boots", link = BOOTS, quality = 2, icon = 1002, classID = 4, subclassID = 3, equipLoc = "INVTYPE_FEET", stats = {} },
	[200] = { name = "Ring", link = RING, quality = 3, icon = 1003, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", stats = {} },
}

local PAWN = { "PawnIsInitialized", "PawnCanItemHaveStats", "PawnGetItemData", "PawnIsItemAnUpgrade" }

local function uninstall()
	rawset(_G, "ForeverLevelingBiS_API", nil)
	for _, name in ipairs(PAWN) do
		rawset(_G, name, nil)
	end
end

describe("whether to need", function()
	local ns, Test, Advice, changed, loading

	-- Forever Leveling BiS's API version 2: a gain for the helm, a loss for
	-- the boots, 0 for what is worn, nothing for the ring.
	local function installLevelingBiS()
		rawset(_G, "ForeverLevelingBiS_API", {
			version = 2,
			GetGain = function(itemLink)
				if loading then
					return nil, true
				end
				return ({ [HELM] = 12.5, [BOOTS] = -4.1, [WORN] = 0 })[itemLink], false
			end,
			OnChanged = function(fn) changed = fn end,
		})
		Test.state.addons.ForeverLevelingBiS = true
	end

	-- Pawn: the helm an upgrade for its Protection scale, the boots not one.
	local function installPawn()
		rawset(_G, "PawnIsInitialized", true)
		rawset(_G, "PawnCanItemHaveStats", function() return true end)
		rawset(_G, "PawnGetItemData", function(itemLink) return { Link = not loading and itemLink or nil } end)
		rawset(_G, "PawnIsItemAnUpgrade", function(item)
			if item.Link == HELM then
				return { { LocalizedScaleName = "Protection", PercentUpgrade = 0.154 } }
			end
		end)
		Test.state.addons.Pawn = true
	end

	local function start(options)
		uninstall()
		changed, loading = nil, false
		SettingsAPI.Install()
		ns = Loader.LoadAddon(options or { gameType = "camelot", skip = {} })
		Test = ns.Compat.Test
		Test.SetItems(ITEMS)
		Loader.Start(ns)
		Advice = ns.Rolls.NeedAdvice
	end

	before_each(function()
		start()
	end)

	after_each(uninstall)

	it("takes the main spec's gain from Forever Leveling BiS: green for more, grey for less, nothing for what is worn", function()
		installLevelingBiS()
		assert.same({ "Main spec: +12.5 (Forever Leveling BiS)", "up" }, { Advice.Line(HELM) })
		assert.same({ "Main spec: -4.1 (Forever Leveling BiS)", "down" }, { Advice.Line(BOOTS) })
		assert.is_nil(Advice.Line(WORN))
		assert.is_nil(Advice.Line(RING))
	end)

	it("takes Pawn's best upgrade with its scale, or that it is not one", function()
		installPawn()
		assert.same({ "Upgrade: +15% (Pawn: Protection)", "up" }, { Advice.Line(HELM) })
		assert.same({ "Not an upgrade (Pawn)", "down" }, { Advice.Line(BOOTS) })
	end)

	it("goes by Forever Leveling BiS when both are installed, and says nothing with neither", function()
		assert.is_nil(Advice.Line(HELM))
		installPawn()
		installLevelingBiS()
		assert.equals("Main spec: +12.5 (Forever Leveling BiS)", (Advice.Line(HELM)))
	end)

	it("asks again for an item still loading: when Forever Leveling BiS says so, and after a moment", function()
		installLevelingBiS()
		local redrawn = 0
		ns.Rolls.LiveWindow.Redraw = function() redrawn = redrawn + 1 end
		loading = true
		assert.is_nil(Advice.Line(HELM))
		Test.Advance(Advice.WAIT)
		assert.equals(1, redrawn)
		changed()
		assert.equals(2, redrawn)
		-- Not for ever: a few times for an item that never comes.
		for _ = 1, Advice.TRIES + 2 do
			Advice.Line(HELM)
			Test.Advance(Advice.WAIT)
		end
		assert.equals(2 + Advice.TRIES - 1, redrawn)
	end)

	it("puts the line under the roll's state on a narrow row, the panel lower", function()
		local DropRow, Model = ns.Rolls.DropRow, ns.Rolls.Model
		local narrow = DropRow.New(UI.NewFake(Loader.ui.UIParent), "below")
		Test.SetLootDrop({ encounterID = 1, listID = 1, link = HELM, rolls = {} })
		DropRow.Draw(narrow, Model.DropView("1:1"))
		assert.same({ false, DropRow.BELOW_ITEM }, { narrow.item.advice:IsShown(), narrow.item:GetHeight() })
		installLevelingBiS()
		DropRow.Draw(narrow, Model.DropView("1:1"))
		assert.same({ true, "Main spec: +12.5 (Forever Leveling BiS)", Advice.COLORS.up },
			{ narrow.item.advice:IsShown(), narrow.item.advice:GetText(), narrow.item.advice.color })
		assert.equals(DropRow.BELOW_ITEM + DropRow.ADVICE, narrow.item:GetHeight())
		assert.same({ "TOPLEFT", narrow.frame, "TOPLEFT", DropRow.INDENT, -(DropRow.BELOW_ITEM + DropRow.ADVICE + 2) },
			narrow.panel.frame.points[#narrow.panel.frame.points])
		-- The history's wide rows have no line.
		local wide = DropRow.New(UI.NewFake(Loader.ui.UIParent))
		DropRow.Draw(wide, Model.DropView("1:1"))
		assert.is_false(wide.item.advice:IsShown())
	end)

	it("recommends Forever Leveling BiS on the options page, and says which is in use as the options open", function()
		local note = ns.SettingsPanel.main.needAdvice
		assert.equals("Advice on whether to need comes from Forever Leveling BiS or Pawn; Forever Leveling BiS is recommended. Neither is installed.",
			note:GetText())
		installPawn()
		ns.SettingsPanel.main.frame.OnRefresh()
		assert.matches("In use: Pawn%.$", note:GetText())
		installLevelingBiS()
		ns.SettingsPanel.main.frame.OnRefresh()
		assert.matches("In use: Forever Leveling BiS%.$", note:GetText())
	end)

	it("names only Pawn on retail, where Forever Leveling BiS is not", function()
		start({ skip = {} })
		local note = ns.SettingsPanel.main.needAdvice
		assert.equals("Advice on whether to need comes from Pawn, when installed.", note:GetText())
		installPawn()
		ns.SettingsPanel.main.frame.OnRefresh()
		assert.equals("Advice on whether to need comes from Pawn, now in use.", note:GetText())
	end)
end)
