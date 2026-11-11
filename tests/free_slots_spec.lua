local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The free-slot bar.
describe("free-slot bar", function()
	local ns, api, lib, Test, module

	-- Just enough of LibEditMode to see what the bar registers.
	local function newLibEditMode()
		local fake = { frames = {}, settings = {}, buttons = {}, SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2, Divider = "divider" } }
		function fake:AddFrame(frame, _, default, name) self.frames[frame] = { default = default, name = name } end
		function fake:AddFrameSettings(frame, settings) self.settings[frame] = settings end
		function fake:AddFrameSettingsButtons(frame, buttons) self.buttons[frame] = buttons end
		function fake:RegisterCallback() end
		function fake:IsInEditMode() return false end
		return fake
	end

	-- General bags with this many free slots of 20, and a reagent bag with 5 of 10.
	local function bags(general)
		local items = {}
		for slot = 1, 20 - general do
			items[slot] = { itemID = 1, count = 1, name = "Filler", quality = 1 }
		end
		local reagents = {}
		for slot = 1, 5 do
			reagents[slot] = { itemID = 2, count = 1, name = "Herb", quality = 1 }
		end
		Test.SetBags({ [0] = { size = 20, items = items }, [5] = { size = 10, items = reagents } })
	end

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		Loader.Start(ns)
		module = ns.Modules:Get("FreeSlots")
		bags(7)
	end)

	after_each(function()
		rawset(_G, "LibStub", nil)
	end)

	it("shows the free slots in the template's format and colours, and follows the bags", function()
		assert.equals("|cff33ff3312|r|cffffffff (|r|cffffd1005|r|cffffffff) / |r|cffffffff7|r", module.frame.Label.text)
		bags(3)
		assert.matches("/ |r|cffffffff3|r$", module.frame.Label.text)
	end)

	it("follows its template, default colour and text size at once", function()
		module:Set("template", "{general}")
		module:Set("color", "ff808080")
		module:Set("size", 20)
		assert.equals("|cff8080807|r", module.frame.Label.text)
		assert.same({ 20, 28 }, { module.frame.Label.font[2], module.frame.height })
	end)

	it("sits above the bags, lets clicks through to what is under it, and still shows its tooltip", function()
		local frame = module.frame
		assert.same({ "HIGH", false, true }, { frame.strata, frame.mouseClicks, frame.mouseMotion })
		frame.scripts.OnEnter(frame)
		assert.same({ true, "Free slots" }, { Loader.ui.tooltip.shown, Loader.ui.tooltip.lines[1] })
	end)

	it("lists the free and total slots of each kind of bag the player has in its tooltip", function()
		assert.same({ "All bags: 12 free of 30", "General bags: 7 free of 20", "Reagent bag: 5 free of 10" }, module.TooltipLines())
	end)

	it("lists each bag family the player has, named by its bag's kind as the client gives it", function()
		ns.Data.BagFamilies = { { token = "herb", bit = 32, bag = 22250 }, { token = "mining", bit = 1024, bag = 38347 } }
		Test.SetItems({ [22250] = { name = "Herb Pouch", kind = { type = "Container", subType = "Herb Bag", classID = 1, subClassID = 2 } } })
		Test.SetBags({ [0] = { size = 20 }, [1] = { size = 12, family = 32, items = { [1] = { itemID = 2, count = 1, name = "Herb", quality = 1 } } } })
		assert.same({ "All bags: 31 free of 32", "General bags: 20 free of 20", "Profession bags: 11 free of 12", "Herb Bag: 11 free of 12" },
			module.TooltipLines())
	end)

	it("is placed with Edit Mode left of the bag buttons, with its settings in the dialog but the colour", function()
		local frame = module.frame
		assert.same({ "Free slots", { point = "BOTTOMRIGHT", x = -260, y = 52 } }, { lib.frames[frame].name, lib.frames[frame].default })
		local names = {}
		for _, setting in ipairs(lib.settings[frame]) do
			names[#names + 1] = setting.name
		end
		assert.same({ "Look", "Text size", "Also in broker panels" }, names)
		assert.equals("Edit the text", lib.buttons[frame][1].text)
	end)

	it("has a page with the text button, the colour swatch, the size and the broker switch", function()
		assert.same({ "checkbox:Enabled", "button:Text", "header:Look", "color:Default colour", "slider:Text size",
			"checkbox:Also in broker panels" }, api.Kinds(api.FindCategory("Free slots")))
	end)

	it("edits the text in a dialog, which gives a typed | back doubled", function()
		module:EditTemplate()
		local dialog = api.popups[#api.popups]
		assert.equals("{free||33ff33} ({reagent||ffd100}) / {general}", dialog.editBox.text)
		api.AcceptPopup("{free||ff0000} free")
		assert.same({ "{free|ff0000} free", "|cffff000012|r|cffffffff free|r" }, { module:Get("template"), module.frame.Label.text })
	end)

	it("takes from a profile text only a colour as AARRGGBB and a text the dialog can hold", function()
		assert.same({ true, false, false }, { module:Validate("color", "ff112233"), module:Validate("color", "112233"),
			module:Validate("template", ("x"):rep(201)) })
		-- Characters, as the dialog counts them: Cyrillic letters take two bytes.
		assert.same({ true, false }, { module:Validate("template", ("ж"):rep(200)), module:Validate("template", ("ж"):rep(201)) })
		assert.same({ true, false }, { module:Validate("size", 14), module:Validate("size", 40) })
	end)

	it("hides with the module", function()
		ns.Modules:SetEnabled("FreeSlots", false)
		assert.is_false(module.frame.shown)
		ns.Modules:SetEnabled("FreeSlots", true)
		assert.is_true(module.frame.shown)
	end)
end)
