local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("gathering highlights", function()
	local ns, Test, module, plate

	-- Made-up cursor file IDs.
	local CURSORS = { Mine = 1, UnableMine = 2, GatherHerbs = 3, UnableGatherHerbs = 4, PickLock = 5, UnablePickLock = 6, Quest = 7 }

	local function playerSettings()
		return { SoftTargetInteract = "0", SoftTargetInteractRange = "10", SoftTargetInteractArc = "2",
			SoftTargetInteractOnlyInRange = "1", SoftTargetIconGameObject = "0", nameplateGameObjectMaxDistance = "40",
			SoftTargetNameplateInteract = "0", SoftTargetIconInteract = "1" }
	end

	-- The soft target becomes this object (or unit), and the game says so.
	local function target(facts)
		Test.state.softInteract = facts
		Test.FireEvent("PLAYER_SOFT_INTERACT_CHANGED")
	end

	local function herb(extra)
		local facts = { isObject = true, isDead = false, cursor = 3, inReach = true, name = "Peacebloom", objectID = 1617 }
		for key, value in pairs(extra or {}) do
			facts[key] = value
		end
		return facts
	end

	local function lit()
		return module.lit and module.lit.kind or nil
	end

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.state.consoleVars = playerSettings()
		Test.state.cursorFiles = CURSORS
		Test.state.gatheringSkills = { herbs = true, ore = false }
		plate = _G.CreateFrame("Frame")
		Test.state.nameplates = { softinteract = plate }
		Loader.Start(ns)
		module = ns.Modules:Get("Highlights")
	end)

	it("exists only on WoW Forever", function()
		assert.is_nil(Loader.LoadAddon().Modules:Get("Highlights"))
		assert.is_true(module:IsActive())
	end)

	it("lights a herb in reach and switches the interact icon and the nameplate on for it", function()
		target(herb())
		assert.same({ "herbs", "ready", plate }, { lit(), module.lit.state, module.lit.plate })
		assert.same({ "1", "1" }, { Test.state.consoleVars.SoftTargetIconGameObject, Test.state.consoleVars.SoftTargetNameplateInteract })
		-- No herb leaf from the game over it meanwhile.
		assert.equals("0", Test.state.consoleVars.SoftTargetIconInteract)
		-- Another target that is nothing: the light and the nameplate go, the player's icons come back.
		target({ isObject = true, cursor = 99, name = "Signpost" })
		assert.same({ nil, "0", "1" }, { lit(), Test.state.consoleVars.SoftTargetNameplateInteract,
			Test.state.consoleVars.SoftTargetIconInteract })
		target(nil)
		assert.is_nil(lit())
	end)

	it("finds the soft target's plate when the game adds it under another name", function()
		Test.state.nameplates = {}
		target(herb())
		assert.same({ "herbs", nil }, { lit(), module.lit.plate })
		-- The plate the nameplate switch brought, as "nameplate3".
		local shown = _G.CreateFrame("Frame")
		Test.state.nameplates.nameplate3 = shown
		Test.state.softInteractUnit = "nameplate3"
		Test.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
		assert.equals(shown, module.lit.plate)
		Test.state.nameplates.nameplate3 = nil
		Test.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate3")
		assert.is_nil(module.lit.plate)
	end)

	it("shows how far and how usable the object is", function()
		target(herb({ inReach = false }))
		assert.equals("far", module.lit.state)
		target(herb({ cursor = 4 }))
		assert.equals("locked", module.lit.state)
		-- Without the reach check, an Unable cursor counts as out of reach.
		local unknownReach = herb({ cursor = 4 })
		unknownReach.inReach = nil
		target(unknownReach)
		assert.equals("far", module.lit.state)
	end)

	it("lights ore only with Mining, unless the player wants herbs and ore without the profession", function()
		target({ isObject = true, cursor = 1, inReach = true, name = "Copper Vein" })
		-- No sparkles, and no pickaxe from the game's interact icon either.
		assert.same({ nil, "0", "0" }, { lit(), Test.state.consoleVars.SoftTargetIconGameObject,
			Test.state.consoleVars.SoftTargetNameplateInteract })
		module:Set("gatherable", false)
		assert.equals("ore", lit())
		-- Herbs on, ore off: herbs for another character's Herbalism, no ore.
		Test.state.gatheringSkills = { herbs = false, ore = false }
		Test.FireEvent("SKILL_LINES_CHANGED")
		module:Set("ore", false)
		assert.is_nil(lit())
		target(herb())
		assert.equals("herbs", lit())
		-- An unknown skill lights.
		module:Set("gatherable", true)
		Test.state.gatheringSkills = {}
		Test.FireEvent("SPELLS_CHANGED")
		assert.equals("herbs", lit())
		-- Read at each decision: Herbalism the client learns of later, without an event, counts at the next target.
		Test.state.gatheringSkills = { herbs = false }
		target(herb())
		assert.is_nil(lit())
		Test.state.gatheringSkills = { herbs = true }
		target(herb())
		assert.equals("herbs", lit())
	end)

	it("applies each kind's switch at once", function()
		target(herb())
		module:Set("herbs", false)
		assert.is_nil(lit())
		target({ isObject = true, cursor = 7, name = "Wanted Poster" })
		assert.equals("quest", lit())
		module:Set("quest", false)
		assert.is_nil(lit())
		target({ isObject = true, cursor = 5, name = "Battered Chest" })
		assert.equals("chests", lit())
	end)

	it("greys out the profession option while herbs and ore are both off", function()
		local found
		for _, setting in ipairs(module.mainSettings) do
			if setting.key == "gatherable" then
				found = setting
			end
		end
		assert.is_true(found.enabledWhen())
		module:Set("herbs", false)
		module:Set("ore", false)
		assert.is_false(found.enabledWhen())
	end)

	it("never lights a creature or a corpse, and pauses soft targeting on a living unit", function()
		target(herb())
		target({ isObject = false, isDead = false, name = "Stormwind Guard" })
		assert.same({ nil, "0", "0" }, { lit(), Test.state.consoleVars.SoftTargetNameplateInteract, Test.state.consoleVars.SoftTargetInteract })
		-- Paused, the game has no soft target; the re-reading every few tenths of a
		-- second resumes it after three seconds without a position.
		Test.state.softInteract = nil
		Test.Advance(3)
		module.ticker.scripts.OnUpdate(module.ticker, 0.2)
		assert.equals("3", Test.state.consoleVars.SoftTargetInteract)
		target({ isObject = false, isDead = true, name = "Kobold Vermin" })
		assert.is_nil(lit())
	end)

	it("learns a looted object as a chest, also one the soft target never picked, but never from fishing", function()
		local windstone = { isObject = true, cursor = 99, name = "Windstone", objectID = 3658 }
		target(windstone)
		assert.is_nil(lit())
		-- Looted with fast autoloot while the soft target was on something else: only
		-- LOOT_READY comes while the loot is still there.
		target(nil)
		Test.state.lootSources = { 3658 }
		Test.FireEvent("LOOT_READY", true)
		Test.state.lootSources = {}
		Test.FireEvent("LOOT_CLOSED")
		target(windstone)
		assert.equals("chests", lit())
		assert.same({ [3658] = true }, Test.state.saved.LootomanDB.sections.lootContainers.values)
		-- A bobber looted is never learned.
		local bobber = { isObject = true, cursor = 98, name = "Fishing Bobber", objectID = 35591 }
		target(bobber)
		Test.state.loot.fishing = true
		Test.state.lootSources = { 35591 }
		Test.FireEvent("LOOT_OPENED")
		target(bobber)
		assert.is_nil(lit())
	end)

	it("reads the quest facts once per target and once a second, and again when a target, a plate or the quest log changes", function()
		local full = 0
		local get = ns.Compat.GetSoftInteract
		ns.Compat.GetSoftInteract = function(skipQuest)
			full = full + (skipQuest and 0 or 1)
			return get(skipQuest)
		end
		local function tick()
			Test.Advance(0.25)
			module.ticker.scripts.OnUpdate(module.ticker, 0.25)
		end
		local stone = { isObject = true, cursor = 99, name = "Odd Stone", objectID = 77, inReach = true, questObjective = true }
		target(stone)
		assert.same({ "quest", 1 }, { lit(), full })
		-- Ticks while it sparkles reuse them, and still read the rest; once a
		-- second they read them again, for a tooltip line that came late.
		for _ = 1, 3 do
			tick()
		end
		assert.same({ 1, "quest" }, { full, lit() })
		tick()
		assert.equals(2, full)
		Test.state.softInteract.inReach = false
		tick()
		assert.equals("far", module.lit.state)
		-- The quest log changes, in a burst: read once, a moment later; no longer a quest object.
		Test.state.softInteract.questObjective = nil
		full = 0
		for _ = 1, 5 do
			Test.FireEvent("QUEST_LOG_UPDATE")
		end
		Test.Advance(0.2)
		assert.same({ 1, nil }, { full, lit() })
		-- A plate that comes, a new target: read again.
		Test.state.softInteract.questObjective = true
		Test.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
		assert.same({ 2, "quest" }, { full, lit() })
		-- Another object under a tick, before the game said the target changed:
		-- its own facts, not the last one's.
		Test.state.softInteract = { isObject = true, cursor = 99, name = "Signpost", objectID = 78, inReach = true }
		tick()
		assert.same({ 3, nil }, { full, lit() })
		target(herb())
		assert.same({ 4, "herbs" }, { full, lit() })
	end)

	it("lights an object a quest's objective names at once, until the quest no longer wants it, and never learns it", function()
		Test.RunSlashCommand("LOOTOMAN", "debug on")
		Test.state.questObjectives = { "Waterlogged Saw: 0/1" }
		Test.FireEvent("QUEST_LOG_UPDATE")
		Test.Advance(0.2)
		local saw = { isObject = true, cursor = 99, name = "Waterlogged Saw", objectID = 4242, inReach = true }
		target(saw)
		assert.equals("quest", lit())
		assert.matches("Highlights: Waterlogged Saw (object 4242, cursor 99), quest by objective, ready", Test.state.printed[#Test.state.printed], 1, true)
		-- Looted: not a chest from then on.
		Test.state.lootSources = { 4242 }
		Test.FireEvent("LOOT_READY", true)
		Test.state.lootSources = {}
		assert.is_nil(Test.state.saved.LootomanDB.sections.lootContainers.values[4242])
		-- The objective is done: the saw no longer sparkles.
		Test.state.questObjectives = {}
		Test.FireEvent("QUEST_LOG_UPDATE")
		Test.Advance(0.2)
		target(saw)
		assert.is_nil(lit())
	end)

	it("says in the debug output when a lit object has no nameplate to draw on", function()
		Test.RunSlashCommand("LOOTOMAN", "debug on")
		Test.state.nameplates = {}
		target(herb())
		assert.matches("Highlights: Peacebloom %(object 1617, cursor 3%), herbs, ready, no nameplate",
			Test.state.printed[#Test.state.printed])
	end)

	it("tells each new target once in the debug output, with its object ID and cursor", function()
		Test.RunSlashCommand("LOOTOMAN", "debug on")
		target({ isObject = true, cursor = 99, name = "Windstone", objectID = 3658 })
		target({ isObject = true, cursor = 99, name = "Windstone", objectID = 3658 })
		local lines = {}
		for _, line in ipairs(Test.state.printed) do
			if line:find("Highlights: Windstone", 1, true) then
				lines[#lines + 1] = line
			end
		end
		assert.equals(1, #lines)
		assert.matches("Highlights: Windstone %(object 3658, cursor 99%), %-, other", lines[1])
	end)

	it("re-reads the target while it sparkles", function()
		target(herb())
		assert.is_true(module.ticker.shown)
		Test.state.softInteract.inReach = false
		module.ticker.scripts.OnUpdate(module.ticker, 0.1)
		assert.equals("ready", module.lit.state)
		module.ticker.scripts.OnUpdate(module.ticker, 0.1)
		assert.equals("far", module.lit.state)
		target(nil)
		assert.is_false(module.ticker.shown)
	end)

	it("lets everything go and gives the game settings back when turned off", function()
		target(herb())
		ns.Modules:SetEnabled("Highlights", false)
		assert.same({ false, nil }, { module:IsActive(), module.lit })
		assert.same(playerSettings(), Test.state.consoleVars)
		-- Targets mean nothing now.
		target(herb())
		assert.is_nil(module.lit)
	end)

	it("undoes a start that stops halfway", function()
		ns.Modules:SetEnabled("Highlights", false)
		local read = ns.Compat.GetSoftInteract
		ns.Compat.GetSoftInteract = function() error("broken soft target") end
		ns.Modules:SetEnabled("Highlights", true)
		assert.is_false(module:IsActive())
		assert.same(playerSettings(), Test.state.consoleVars)
		assert.matches("broken soft target", Test.state.errors[#Test.state.errors])
		ns.Compat.GetSoftInteract = read
	end)

	it("puts its switches in profile texts on WoW Forever, and retail leaves them out", function()
		module:Set("ore", false)
		assert.same({ ore = false }, ns.Share.Get("module:Highlights"))
		local retail = Loader.Start(Loader.LoadAddon())
		local text = retail.Share.PREFIX .. "2:" .. retail.Compat.Encode({ format = 2, collections = {},
			sections = { ["module:Highlights"] = { ore = false }, ["module:AutoLoot"] = { confirmBind = false } } })
		local read = retail.Share.Read(text)
		assert.same({ { "module:AutoLoot" }, 1 }, { read.names, read.skipped })
	end)

	it("reports to the self-test", function()
		Test.RunSlashCommand("LOOTOMAN", "selftest")
		local report
		for _, line in ipairs(Test.state.printed) do
			if line:find("SoftTargetInteract=", 1, true) then
				report = line
			end
		end
		assert.matches("SoftTargetInteract=3", report)
		-- The plain cursor names the fake client knows.
		assert.matches("cursors 4 of", report)
	end)
end)

describe("gathering highlights' sparkles", function()
	local ns, Test, module, Sparkles, plate

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.state.consoleVars = { SoftTargetInteract = "0", SoftTargetNameplateInteract = "0" }
		Test.state.cursorFiles = { GatherHerbs = 3 }
		Test.state.gatheringSkills = { herbs = true }
		plate = _G.CreateFrame("Frame")
		plate.UnitFrame = _G.CreateFrame("Frame", nil, plate)
		plate.UnitFrame.source = "Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua:120"
		plate.children = { plate.UnitFrame }
		function plate:GetChildren() return unpack(self.children) end
		Test.state.nameplates = { softinteract = plate }
		Loader.Start(ns)
		module, Sparkles = ns.Modules:Get("Highlights"), ns.Highlights.Sparkles
	end)

	local function target(facts)
		Test.state.softInteract = facts
		Test.FireEvent("PLAYER_SOFT_INTERACT_CHANGED")
	end

	local HERB = { isObject = true, isDead = false, cursor = 3, inReach = true, name = "Peacebloom" }

	it("are only small gold stars", function()
		local frame = Sparkles.Create()
		local textures = 0
		for _, star in ipairs(frame.stars) do
			textures = textures + 1
			assert.same({ [[Interface\Cooldown\star4]], { 1, 0.82, 0 } }, { star.texture, star.vertex })
		end
		assert.same({ 6, nil, nil }, { textures, frame.haze, frame.motes })
	end)

	it("hang on the object's nameplate, below it, with the plate's own frame hidden until they leave", function()
		assert.is_nil((Sparkles.Current()))
		target(HERB)
		local frame = Sparkles.Create()
		assert.same({ plate, "ready" }, { Sparkles.Current() })
		assert.same({ true, plate, { "CENTER", plate, "CENTER", 0, -45 } }, { frame.shown, frame.parent, frame.points[1] })
		assert.equals(0, plate.UnitFrame.alpha)
		-- The game's code shows the plate again: it stays hidden.
		plate.UnitFrame:SetAlpha(1)
		assert.equals(0, plate.UnitFrame.alpha)
		target(nil)
		assert.same({ false, 1 }, { frame.shown, plate.UnitFrame.alpha })
		-- Free again, the game's code may show it.
		plate.UnitFrame:SetAlpha(0.5)
		assert.equals(0.5, plate.UnitFrame.alpha)
	end)

	it("brighten in, and change state only once it has held", function()
		target(HERB)
		local frame = Sparkles.Create()
		frame.scripts.OnUpdate(frame, 0.1)
		assert.is_true(frame.level > 0 and frame.level < 1)
		frame.scripts.OnUpdate(frame, 0.2)
		assert.equals(1, frame.level)
		-- Out of reach for a moment only: no change.
		Sparkles.Show(plate, "far")
		frame.scripts.OnUpdate(frame, 0.1)
		Sparkles.Show(plate, "ready")
		frame.scripts.OnUpdate(frame, 0.1)
		assert.same({ "ready", 1 }, { frame.state, frame.level })
		-- Locked for long enough: faint.
		Sparkles.Show(plate, "locked")
		frame.scripts.OnUpdate(frame, 0.2)
		assert.equals("locked", frame.state)
		for _ = 1, 10 do
			frame.scripts.OnUpdate(frame, 0.1)
		end
		assert.equals(0.3, frame.level)
	end)

	it("show the object's icon and its name over the stars by default, at the plate's centre", function()
		Test.state.consoleVars.SoftTargetIconInteract = "1"
		target(HERB)
		local frame = Sparkles.Create()
		local label = frame.label
		-- A child of the stars' frame: it takes their brightness and fade.
		assert.same({ true, frame, { "CENTER", frame, "CENTER", 0, 45 } }, { label.shown, label.parent, label.points[1] })
		assert.same({ true, 3, { Sparkles.ICON, Sparkles.ICON } }, { label.icon.shown, label.icon.texture, { label.icon.width, label.icon.height } })
		assert.same({ true, "Peacebloom", { "Fonts\\FRIZQT__.TTF", 12, "OUTLINE" }, { 0, 0 } },
			{ label.name.shown, label.name.text, label.name.font, label.name.shadowOffset })
		assert.same({ 1, 1, 1 }, label.name.color)
		assert.same({ "BOTTOM", label.name, "TOP", 0, 4 }, label.icon.points[1])
		-- Fully opaque, whatever the stars' brightness.
		assert.same({ true, 1 }, { label.ignoresParentAlpha, label.alpha })
		assert.is_false(label.backdrop.shown)
		-- The game's own icon stays off over it.
		assert.equals("0", Test.state.consoleVars.SoftTargetIconInteract)
	end)

	it("keep the icon and the name at their own opacity, not the stars'", function()
		target(HERB)
		local frame = Sparkles.Create()
		module:Set("labelOpacity", 60)
		assert.equals(0.6, frame.label.alpha)
		module:Set("label", "icon")
		assert.equals(0.6, frame.label.alpha)
		-- Never quite gone; and the stars out of reach leave it as it is.
		module:Set("labelOpacity", 0)
		assert.equals(0.1, frame.label.alpha)
		Sparkles.Show(plate, "far", module:Look(), module:Stars())
		frame.scripts.OnUpdate(frame, 1)
		assert.equals(0.1, frame.label.alpha)
	end)

	it("light the stars at the player's intensity, out of reach and locked by the same share of it", function()
		target(HERB)
		local frame = Sparkles.Create()
		module:Set("intensity", 50)
		frame.scripts.OnUpdate(frame, 1)
		assert.equals(0.5, frame.alpha)
		Sparkles.Show(plate, "locked", module:Look(), module:Stars())
		for _ = 1, 10 do
			frame.scripts.OnUpdate(frame, 0.1)
		end
		assert.equals(0.15, frame.alpha)
		module:Set("intensity", 5)
		assert.equals(0.1, module:Intensity())
	end)

	it("tint the stars in the player's colour, gold by default", function()
		target(HERB)
		local frame = Sparkles.Create()
		local function colors()
			local seen = {}
			for _, star in ipairs(frame.stars) do
				seen[#seen + 1] = table.concat(star.vertex, ",")
			end
			return seen
		end
		local gold = table.concat({ 1, 209 / 255, 0 }, ",")
		assert.same({ gold, gold, gold, gold, gold, gold }, colors())
		module:Set("starColor", "33ccff")
		local blue = table.concat({ 0.2, 0.8, 1 }, ",")
		assert.same({ blue, blue, blue, blue, blue, blue }, colors())
		module:Set("starColor", "sky")
		assert.same({ gold, gold, gold, gold, gold, gold }, colors())
	end)

	it("show the icon alone at the centre, or nothing, as the player chooses", function()
		target(HERB)
		local label = Sparkles.Create().label
		module:Set("label", "icon")
		assert.same({ true, true, false }, { label.shown, label.icon.shown, label.name.shown })
		assert.same({ "CENTER", label, "CENTER", 0, 0 }, label.icon.points[1])
		module:Set("label", "none")
		assert.is_false(label.shown)
		module:Set("label", "name")
		assert.same({ true, true }, { label.shown, label.name.shown })
	end)

	it("write the name in the chosen size, colour and style", function()
		target(HERB)
		local name, backdrop = Sparkles.Create().label.name, Sparkles.Create().label.backdrop
		module:Set("textSize", 18)
		module:Set("textColor", "33ccff")
		assert.same({ 18, { 0.2, 0.8, 1 } }, { name.font[2], name.color })
		module:Set("textStyle", "shadow")
		assert.same({ "", { 1, -1 }, false }, { name.font[3], name.shadowOffset, backdrop.shown })
		module:Set("textStyle", "thick")
		assert.same({ "THICKOUTLINE", { 0, 0 } }, { name.font[3], name.shadowOffset })
		module:Set("textStyle", "backdrop")
		assert.same({ "", { 1, -1 }, true }, { name.font[3], name.shadowOffset, backdrop.shown })
		-- Around the text's own edges, whatever its width.
		assert.same({ { "TOPLEFT", name, "TOPLEFT", -4, 2 }, { "BOTTOMRIGHT", name, "BOTTOMRIGHT", 4, -2 } }, backdrop.points)
	end)

	it("fall back to the defaults for a size, colour or style a profile text brought that is not valid", function()
		target(HERB)
		local name = Sparkles.Create().label.name
		module:Set("textSize", 40)
		module:Set("textColor", "gold")
		module:Set("textStyle", "glitter")
		assert.same({ 24, { 1, 1, 1 }, "OUTLINE" }, { name.font[2], name.color, name.font[3] })
	end)

	it("show a name the client keeps secret, and the icon alone when there is no name", function()
		local secret = { secret = true }
		Test.state.softInteractName = secret
		target(HERB)
		local label = Sparkles.Create().label
		assert.same({ true, secret }, { label.name.shown, label.name.text })
		Test.state.softInteractName = ""
		target({ isObject = true, isDead = false, cursor = 3, inReach = true })
		assert.same({ true, true, false }, { label.shown, label.icon.shown, label.name.shown })
		assert.same({ "CENTER", label, "CENTER", 0, 0 }, label.icon.points[1])
	end)

	it("light an object whatever other addons draw on its plate: a nameplate addon's frames, another glow", function()
		-- A nameplate addon puts its own frames on every plate; another addon may light the object too.
		local nameplateAddon = _G.CreateFrame("Frame", nil, plate)
		local glow = _G.CreateFrame("Frame", nil, plate)
		plate.children = { plate.UnitFrame, nameplateAddon, glow }
		target(HERB)
		assert.equals("herbs", module.lit.kind)
		assert.equals(plate, (Sparkles.Current()))
		assert.equals("1", Test.state.consoleVars.SoftTargetNameplateInteract)
	end)
end)

describe("gathering highlights on the options page", function()
	it("is a switch with a checkbox for each kind and the profession option under it, on WoW Forever only", function()
		SettingsAPI.Install()
		local ns = Loader.Start(Loader.LoadAddon({ gameType = "camelot", skip = {} }))
		local texts = {}
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			texts[#texts + 1] = tostring(entry.text)
		end
		assert.is_truthy(table.concat(texts, "|"):find(
			"Highlight Lootable Objects|Intensity|Sparkle Color|What to Highlight|Quest Objects|Herbs|Chests|Ore|Only Herbs and Ore You Can Gather",
			1, true))
		-- The kinds two to a row, quest objects and chests on the left, herbs and ore on the right at the
		-- rows' control column, each in a cell of its own (the hover lights only the cell); the
		-- profession option a little apart.
		local page, rows, option = ns.SettingsPanel.main, {}, nil
		for _, entry in ipairs(page.items) do
			if entry.kind == "checkboxes" then
				rows[#rows + 1] = entry
			elseif entry.text == "Only Herbs and Ore You Can Gather" then
				option = entry
			end
		end
		assert.same({ 2, "Quest Objects|Herbs", "Chests|Ore" }, { #rows, rows[1].text, rows[2].text })
		local cells = rows[1].region.cells
		assert.same({ 48, cells[1], cells[2] }, { rows[1].indent, cells[1].checkbox.parent, cells[2].checkbox.parent })
		assert.same({ "TOPLEFT", rows[1].region, "TOPLEFT", ns.SettingsPanel.CONTROL_X - ns.SettingsPanel.LEFT - 48, 0 }, cells[2].points[1])
		assert.same({ 14, 48 }, { option.gap, option.indent })
		-- Clicking a cell's checkbox sets its kind; profile texts still check the kinds' values.
		local ore = rows[2].region.cells[2].checkbox
		ore.checked = false
		ore.scripts.OnClick(ore)
		assert.is_false(ns.Storage:Get("Highlights", "ore"))
		assert.is_true(ns.Modules:Get("Highlights"):Validate("chests", false))
		-- Above the object: the choice, and the name's three settings under it, greyed without the name.
		assert.is_truthy(table.concat(texts, "|"):find("Only Herbs and Ore You Can Gather|Above the Object|Opacity|Text Size|Text Color|Text Style",
			1, true))
		local kinds = {}
		for _, entry in ipairs(page.items) do
			local text = entry.text
			if text == "Intensity" or text == "Sparkle Color" or text == "What to Highlight" or text == "Above the Object"
				or text == "Opacity" or text == "Text Size" or text == "Text Color" or text == "Text Style" then
				kinds[#kinds + 1] = entry.kind .. "@" .. entry.indent .. "+" .. entry.gap
			end
		end
		-- The stars' settings right under the switch; what to highlight under its heading, and what shows
		-- above the object, a bigger gap before each.
		assert.same({ "slider@24+6", "color@24+6", "heading@24+16", "choice@24+16", "slider@48+6", "slider@48+6", "color@48+6",
			"choice@48+6" }, kinds)
		local function label(text)
			for _, entry in ipairs(page.items) do
				if entry.text == text then
					return entry.region.label
				end
			end
		end
		assert.equals("GameFontNormal", label("Text Size").fontObject)
		ns.Storage:Set("Highlights", "label", "icon")
		assert.same({ "GameFontNormal", "GameFontDisable", "GameFontDisable", "GameFontDisable" },
			{ label("Opacity").fontObject, label("Text Size").fontObject, label("Text Color").fontObject, label("Text Style").fontObject })
		ns.Storage:Set("Highlights", "label", "none")
		assert.equals("GameFontDisable", label("Opacity").fontObject)
		local defaults = ns.Modules:Get("Highlights").defaults
		assert.same({ 100, "ffd100", "name", 100, 12, "ffffff", "outline" }, { defaults.intensity, defaults.starColor, defaults.label,
			defaults.labelOpacity, defaults.textSize, defaults.textColor, defaults.textStyle })
		SettingsAPI.Install()
		ns = Loader.Start(Loader.LoadAddon({ skip = {} }))
		texts = {}
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			texts[#texts + 1] = tostring(entry.text)
		end
		assert.is_falsy(table.concat(texts, "|"):find("Highlight Lootable Objects", 1, true))
	end)
end)
