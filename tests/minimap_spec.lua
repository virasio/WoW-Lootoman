local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local UI = require("tests.mocks.UI")

describe("minimap icon", function()
	local ns, Test, Icon, button, compartment, opened, minimap

	local function start(saved)
		SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		minimap = UI.NewFake(Loader.ui.UIParent)
		minimap:SetSize(198, 198)
		function minimap:GetCenter() return 500, 400 end
		function minimap:GetEffectiveScale() return 1 end
		rawset(_G, "Minimap", minimap)
		Loader.Start(ns, saved)
		Icon = ns.MinimapIcon
		button = Icon.Button()
		opened = 0
		ns.Bus:On("OpenSettings", "test", function() opened = opened + 1 end)
	end

	local function point()
		local where = button.points[#button.points]
		return { where[1], where[2], math.floor(where[4] + 0.5), math.floor(where[5] + 0.5) }
	end

	before_each(function()
		compartment = nil
		start()
	end)

	after_each(function()
		rawset(_G, "Minimap", nil)
		rawset(_G, "GetMinimapShape", nil)
		rawset(_G, "AddonCompartmentFrame", nil)
	end)

	it("is a named button on the minimap's edge, bottom left at first, shown", function()
		assert.same({ "LootomanMinimapButton", minimap, 31, true }, { button.name, button.parent, button:GetWidth(), button:IsShown() })
		-- 225°: half the minimap's 198 and 5 beyond, down and to the left.
		assert.same({ "CENTER", minimap, -74, -74 }, point())
		assert.same({ "Interface\\AddOns\\Lootoman\\Art\\Icon", 136430 }, { button.icon.texture, button.border.texture })
	end)

	it("shows the picture the addon list shows, a texture in the addon's folder", function()
		local toc = assert(io.open("Lootoman.toc", "rb"))
		local icon = toc:read("*a"):match("\n## IconTexture: ([^\r\n]+)")
		toc:close()
		assert.equals(Icon.TEXTURE, icon)
		local file = icon:match("^Interface\\AddOns\\Lootoman\\(.+)$"):gsub("\\", "/") .. ".tga"
		assert.equals("Art/Icon.tga", file)
		local texture = assert(io.open(file, "rb"))
		-- An uncompressed 32-bit TGA of 64 by 64, as the game reads it.
		local header = texture:read(18)
		texture:close()
		assert.same({ 2, 64, 64, 32 }, { header:byte(3), header:byte(13) + header:byte(14) * 256,
			header:byte(15) + header:byte(16) * 256, header:byte(17) })
	end)

	it("goes round the edge as it is dragged, and keeps its angle for the character", function()
		button.scripts.OnDragStart(button)
		-- The cursor straight above the minimap's centre: 90°.
		Loader.ui.cursor = { 500, 700 }
		button.scripts.OnUpdate(button, 0.01)
		button.scripts.OnDragStop(button)
		assert.same({ "CENTER", minimap, 0, 104 }, point())
		local saved = Test.state.saved.LootomanCharDB.sections.minimap
		assert.same({ 90, true }, { saved.angle, saved.shown })
		-- After a /reload the icon is where it was.
		start({ LootomanDB = Test.state.saved.LootomanDB, LootomanCharDB = Test.state.saved.LootomanCharDB })
		assert.same({ "CENTER", minimap, 0, 104 }, point())
		assert.is_nil(ns.Storage:GetProfile().minimap)
	end)

	it("follows a square minimap's edge when a minimap addon says so", function()
		rawset(_G, "GetMinimapShape", function() return "SQUARE" end)
		Icon.Update()
		-- Towards the square's corner, past the circle.
		assert.same({ "CENTER", minimap, -97, -97 }, point())
	end)

	it("shows and hides with the checkbox at the top of the options page, for this character", function()
		local page = ns.SettingsPanel.main
		local check = page.minimap
		assert.same({ "Show the Minimap Icon", "GameFontHighlightSmall", { "TOPRIGHT", page.frame, "TOPRIGHT", -26, -16 } },
			{ check.label.text, check.label.fontObject, check.points[1] })
		page:Refresh()
		assert.is_true(check:GetChecked())
		check:SetChecked(false)
		check.scripts.OnClick(check)
		assert.same({ false, false }, { button:IsShown(), Test.state.saved.LootomanCharDB.sections.minimap.shown })
		Icon.SetShown(true)
		page:Refresh()
		assert.same({ true, true }, { button:IsShown(), check:GetChecked() })
	end)

	it("tells its clicks in its tooltip", function()
		button.scripts.OnEnter(button)
		assert.same({ "Lootoman @project-version@", "Click: options", "Right-click: menu", "Drag: move" }, Loader.ui.tooltip.lines)
	end)

	it("opens the options on a click and a menu on a right click", function()
		button.scripts.OnClick(button, "LeftButton")
		assert.equals(1, opened)
		button.scripts.OnClick(button, "RightButton")
		local entries = Loader.ui.contextMenu.entries
		assert.same({ "Options", "Loot Feed Look", "Junk", "Ninja Rules", "Bug Report" },
			{ entries[1].text, entries[2].text, entries[3].text, entries[4].text, entries[5].text })
		assert.is_true(entries[3].enabled)
		entries[1].callback()
		assert.equals(2, opened)
		entries[2].callback()
		assert.is_true(ns.Modules:Get("LootFeed").LookWindow.window.shown)
		local junk = 0
		ns.Bus:On("OpenJunkWindow", "test", function() junk = junk + 1 end)
		entries[3].callback()
		assert.equals(1, junk)
		entries[5].callback()
		assert.is_true(ns.BugReportWindow.Frame().shown)
		-- The loot rolls' ninja rules; the demo is no player's entry.
		assert.is_true(entries[4].enabled)
		assert.same({}, entries[4].entries)
		entries[4].callback()
		assert.is_true(ns.Rolls.NinjaRules.Frame().shown)
		-- Junk is greyed while junk management is off, the ninja rules while the loot rolls are.
		ns.Modules:SetEnabled("Junk", false)
		ns.Modules:SetEnabled("Rolls", false)
		button.scripts.OnClick(button, "RightButton")
		assert.is_false(Loader.ui.contextMenu.entries[3].enabled)
		assert.is_false(Loader.ui.contextMenu.entries[4].enabled)
	end)

	it("has an entry in the addon compartment where the client has one, also with the icon hidden", function()
		assert.is_nil(Icon.compartment)
		rawset(_G, "AddonCompartmentFrame", { RegisterAddon = function(_, data) compartment = data end })
		start()
		Icon.SetShown(false)
		assert.same({ "Lootoman", "Interface\\AddOns\\Lootoman\\Art\\Icon", true }, { compartment.text, compartment.icon, Icon.compartment })
		compartment.func(nil, { buttonName = "LeftButton" })
		assert.equals(1, opened)
		compartment.func(nil, { buttonName = "RightButton" })
		assert.equals("Options", Loader.ui.contextMenu.entries[1].text)
		local owner = UI.NewFake(Loader.ui.UIParent)
		compartment.funcOnEnter(owner)
		assert.equals("Click: options", Loader.ui.tooltip.lines[2])
	end)
end)
