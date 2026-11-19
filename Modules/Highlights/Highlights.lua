local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- Gathering highlights, on WoW Forever: the object you are about to loot
-- sparkles. Herbs, ore, chests and quest objects, each with its own switch;
-- herbs and ore only when this character can gather them, unless the player
-- turns that off. One object at a time: the one the game's soft targeting
-- picks, which is the one the Interact key would use and the only one with a
-- place on screen (its nameplate). Lueur works the same way.
--
-- The module borrows the game settings soft targeting needs (GameSettings),
-- decides from the target's facts what it is (Rules.Objects) and whether it
-- lights it, and hangs the sparkles on its nameplate (Sparkles). Objects
-- looted are chests from then on (account section lootContainers), which
-- matters only for an object that is none of the other kinds.
--
-- Only WoW Forever's data offers it; on retail the module is not registered,
-- so it has no switch, no saved values and no part in profile texts.
if not (ns.Data and ns.Data.highlights) then
	return
end

ns.Highlights = ns.Highlights or {}
local GameSettings = ns.Highlights.GameSettings
local Objects = ns.Rules.Objects

local function eitherGathering()
	return Storage:Get("Highlights", "herbs") or Storage:Get("Highlights", "ore") or Storage:Get("Highlights", "skinning")
end

local function showsName()
	return Storage:Get("Highlights", "label") == "name"
end

local function showsLabel()
	return Storage:Get("Highlights", "label") ~= "none"
end

local Highlights = ns.Modules:Register({
	name = "Highlights",
	title = L["Gathering highlights"],
	switchLabel = L["Highlight Lootable Objects"],
	description = L["The object you are about to loot sparkles: the one your Interact key would use, within about 15 yards."],
	defaults = { enabled = true, herbs = true, ore = true, chests = true, quest = true, skinning = true, gatherable = true,
		intensity = 100, starColor = "ffd100", label = "name", labelOpacity = 100, textSize = 12, textColor = "ffffff", textStyle = "outline" },
	-- Right under the switch, how the stars look; then what to highlight, the
	-- kinds in two columns (quest objects and chests on the left, herbs and ore
	-- on the right; the rows fill from the left) over the profession option a
	-- little apart; then what shows above the object.
	mainSettings = {
		{ kind = "slider", key = "intensity", label = L["Intensity"], min = 10, max = 100, step = 10, format = L["%d %%"] },
		{ kind = "color", key = "starColor", label = L["Sparkle Color"] },
		{ kind = "heading", label = L["What to Highlight"], gap = 16 },
		{ kind = "checkboxes", level = 2, columns = 2, items = {
			{ kind = "checkbox", key = "quest", label = L["Quest Objects"] },
			{ kind = "checkbox", key = "herbs", label = L["Herbs"] },
			{ kind = "checkbox", key = "chests", label = L["Chests"], tooltip = L["Chests, crates and other containers you can loot."] },
			{ kind = "checkbox", key = "ore", label = L["Ore"] },
			{ kind = "checkbox", key = "skinning", label = L["Corpses to Skin"],
				tooltip = L["Corpses you can skin now: looted, or with no loot."] },
		} },
		{ kind = "checkbox", key = "gatherable", level = 2, label = L["Only What You Can Gather"], gap = 14,
			tooltip = L["Herbs need Herbalism, ore needs Mining and corpses need Skinning. Turn it off to see them anyway."],
			enabledWhen = eitherGathering },
		-- Above the object: nothing, its icon, or its icon and name; the name's
		-- size, colour and style only with the name.
		{ kind = "choice", key = "label", label = L["Above the Object"], gap = 16,
			tooltip = L["What shows above the sparkling object: its interaction icon, and its name under it."],
			choices = { { "none", L["Nothing"] }, { "icon", L["Icon"] }, { "name", L["Icon and name"] } } },
		{ kind = "slider", key = "labelOpacity", label = L["Opacity"], level = 2, min = 10, max = 100, step = 10, format = L["%d %%"],
			enabledWhen = showsLabel },
		{ kind = "slider", key = "textSize", label = L["Text Size"], level = 2, min = 8, max = 24, step = 1, enabledWhen = showsName },
		{ kind = "color", key = "textColor", label = L["Text Color"], level = 2, enabledWhen = showsName },
		{ kind = "choice", key = "textStyle", label = L["Text Style"], level = 2, enabledWhen = showsName,
			choices = { { "shadow", L["Shadow"] }, { "outline", L["Outline"] }, { "thick", L["Thick outline"] },
				{ "backdrop", L["Backdrop"] } } },
	},
})
ns.Highlights.Module = Highlights

-- The re-reading while something sparkles or soft targeting is paused.
Highlights.TICK = 0.2
-- How long the ticks may reuse a target's quest facts.
Highlights.QUEST_REFRESH = 1
Highlights.SECTION = "lootContainers"

-- The chests learned from looting: { [objectID] = true }.
function Highlights.Chests()
	local section = Storage:GetGlobalSection(Highlights.SECTION)
	section.schema = section.schema or 1
	if type(section.values) ~= "table" then
		section.values = {}
	end
	return section.values
end

-- What the module knows while it is on: the cursor files, the learned
-- chests and the quests' objectives (known), the nameplate units shown now
-- ({ ["nameplate3"] = true }), and the objects seen as quest objects this
-- session ({ [objectID] = true }), which looting does not make chests.
local known, plates, questObjects

-- The quests' objectives to collect or use, as Objects.Classify compares them.
local function readObjectives()
	if known then
		known.objectives = Objects.ObjectiveTexts(Compat.GetQuestObjectiveTexts())
	end
end

-- How the sparkles look: in reach, out of reach, or not usable yet (an
-- "Unable" cursor in reach). Without the reach check, an Unable cursor counts
-- as out of reach, as Lueur does.
function Highlights.State(facts, unable)
	if facts.inReach == false then
		return "far"
	end
	if unable then
		return facts.inReach == true and "locked" or "far"
	end
	return "ready"
end

-- What the label over a sparkling object shows (Sparkles.Label), from the
-- settings; a value out of range or unknown, as a profile text may bring,
-- falls back to the default.
Highlights.TEXT_SIZE = { min = 8, max = 24 }
Highlights.TEXT_COLOR = "ffffff"
Highlights.STAR_COLOR = "ffd100"
local STYLES = { shadow = true, outline = true, thick = true, backdrop = true }

-- A percentage setting from 10 to 100 in steps of 10, as 0.1 to 1.
local function share(value)
	return Storage.OnStep(tonumber(value) or 100, 10, 100, 10) / 100
end

-- How bright the stars are at most, 0.1 to 1.
function Highlights:Intensity()
	return share(self:Get("intensity"))
end

-- The stars' intensity and colour (Sparkles.Show).
function Highlights:Stars()
	return { intensity = self:Intensity(), color = { ns.Text.RGB(self:Get("starColor"), Highlights.STAR_COLOR) } }
end

function Highlights:Look()
	local mode = self:Get("label")
	if mode ~= "icon" and mode ~= "name" then
		return nil
	end
	local look = { icon = true, alpha = share(self:Get("labelOpacity")) }
	if mode == "name" then
		look.name, look.hasName = Compat.GetSoftInteractName()
		local size = Highlights.TEXT_SIZE
		look.size = Storage.OnStep(tonumber(self:Get("textSize")) or 12, size.min, size.max, 1)
		look.color = { ns.Text.RGB(self:Get("textColor"), Highlights.TEXT_COLOR) }
		local style = self:Get("textStyle")
		look.style = STYLES[style] and style or "outline"
	end
	return look
end

-- Whether a kind lights: its switch, and for herbs and ore the profession
-- while the player wants only those it can gather (an unknown skill lights).
-- The profession is read each time, as Lueur does: just after logging in the
-- client may not know it yet. The second value says why not.
function Highlights:Wants(kind)
	if not self:Get(kind) then
		return false, "kind off"
	end
	if (kind == "herbs" or kind == "ore" or kind == "skinning") and self:Get("gatherable")
		and Compat.GetGatheringSkills()[kind] == false then
		return false, "no profession"
	end
	return true
end

-- The last target told in the debug output, so each one is told once.
local told

-- The quest facts of the last target read in full, which the ticks reuse for
-- that target ({ key, at, questRelated, questObjective }): they change with
-- an event (a new target, a plate that comes or goes, the quest log), each of
-- which reads them again; a tooltip line that comes late is caught by the
-- read once every QUEST_REFRESH seconds.
local questFacts

-- Which object the facts are of: its object ID and name.
local function factsKey(facts)
	return tostring(facts.objectID) .. "|" .. tostring(facts.name)
end

-- "Highlights: <name> (object <id>, cursor <cursor>), <kind>, <state or why not>".
local function debug(facts, kind, state, why)
	local target = "no target"
	if facts then
		target = ("%s (object %s, cursor %s)"):format(tostring(facts.name or "?"), tostring(facts.objectID or "?"),
			tostring(facts.cursor or "none"))
	end
	local line = ("Highlights: %s, %s, %s"):format(target, tostring(kind or "-"), tostring(state or why or "-"))
	if line ~= told then
		told = line
		ns.Debug(line)
	end
end

-- Reads the soft target again and lights it or lets it go. A living unit
-- pauses soft targeting (safe self-cast, GameSettings). tick: the ticker's
-- re-reading, which keeps the quest facts of the last full read.
function Highlights:Evaluate(tick)
	if not self.active or not known then
		return
	end
	local facts
	local now = Compat.GetTime()
	if tick and questFacts and now - questFacts.at < Highlights.QUEST_REFRESH then
		facts = Compat.GetSoftInteract(true)
		if facts and factsKey(facts) == questFacts.key then
			facts.questRelated, facts.questObjective = questFacts.questRelated, questFacts.questObjective
		elseif facts then
			-- Another object before the game said so: its own facts.
			facts = nil
		end
	end
	if not facts then
		facts = Compat.GetSoftInteract()
		questFacts = facts and { key = factsKey(facts), at = now, questRelated = facts.questRelated,
			questObjective = facts.questObjective } or nil
	end
	if facts and facts.isLiving then
		GameSettings.Pause("unit")
	end
	local kind, extra, how = Objects.Classify(facts, known)
	if kind == "quest" and facts.objectID then
		questObjects[facts.objectID] = true
	end
	local lit, why, state = false, extra, nil
	if kind then
		lit, why = self:Wants(kind)
		if lit then
			state = Highlights.State(facts, extra)
		end
	end
	-- Other addons on an object's plate don't matter: a nameplate addon draws
	-- at most an icon there, and a player who runs another addon that lights
	-- objects sees both. On a corpse's plate a nameplate addon draws a whole
	-- unit plate, so the sparkles hide it (Sparkles).
	local plate = lit and Compat.GetSoftInteractPlate(plates) or nil
	GameSettings.Gate(lit)
	self.lit = lit and { kind = kind, state = state, plate = plate } or nil
	if ns.Highlights.Sparkles then
		if lit and plate then
			ns.Highlights.Sparkles.Show(plate, state, self:Look(), self:Stars(), kind == "skinning")
		else
			ns.Highlights.Sparkles.Hide()
		end
	end
	self.ticker:SetShown(lit or GameSettings.IsPaused())
	-- Lit, but nothing to draw on yet: the game gave no nameplate.
	debug(facts, how and kind .. " by " .. how or kind, state and (plate and state or state .. ", no nameplate"), why)
end

-- After looting game objects: chests from now on (Objects.Learn). Never from
-- fishing: the bobber is no chest.
function Highlights:Learn()
	if Compat.IsFishingLoot() then
		return
	end
	local learned = Objects.Learn(Highlights.Chests(), Compat.GetLootSourceObjects(), questObjects)
	if learned > 0 then
		ns.Debug(("Highlights: learned %d chest(s)"):format(learned))
	end
end

function Highlights:OnEnable()
	known = { cursors = Objects.CursorFiles(Compat.GetCursorFileID), chests = Highlights.Chests() }
	readObjectives()
	plates, questObjects = {}, {}
	told, questFacts = nil, nil
	if not self.ticker then
		self.ticker = CreateFrame("Frame")
		self.ticker.elapsed = 0
		self.ticker:SetScript("OnUpdate", function(ticker, elapsed)
			ticker.elapsed = ticker.elapsed + elapsed
			if ticker.elapsed >= Highlights.TICK then
				ticker.elapsed = 0
				GameSettings.CheckPause()
				self:Evaluate(true)
			end
		end)
	end
	self.ticker:Hide()
	if ns.Highlights.Sparkles then
		ns.Highlights.Sparkles.Create()
	end
	GameSettings.Start()
	local function evaluate()
		self:Evaluate()
	end
	self:OnEvent("PLAYER_SOFT_INTERACT_CHANGED", evaluate)
	-- The soft target's plate comes as any other, named "nameplate3" or so.
	self:OnEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
		if type(unit) == "string" and not Compat.IsSecret(unit) then
			plates[unit] = true
		end
		self:Evaluate()
	end)
	self:OnEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
		if type(unit) == "string" and not Compat.IsSecret(unit) then
			plates[unit] = nil
		end
		self:Evaluate()
	end)
	-- On the loot's first event: with fast autoloot (or the game's) the slots
	-- are taken before LOOT_OPENED, which may not come at all; LOOT_READY still
	-- has them, as the server clears a slot only later. Lueur learns on both.
	local function learn()
		self:Learn()
	end
	self:OnEvent("LOOT_READY", learn)
	self:OnEvent("LOOT_OPENED", learn)
	-- A profession learned or unlearned shows at once.
	local function professions()
		self:Evaluate()
	end
	self:OnEvent("SKILL_LINES_CHANGED", professions)
	self:OnEvent("SPELLS_CHANGED", professions)
	-- An object a quest wanted may be done with, or a new quest may want one.
	-- The event comes in bursts: one read, a tick later.
	self:OnEvent("QUEST_LOG_UPDATE", function()
		questFacts = nil
		if not self.questPending then
			self.questPending = true
			Compat.After(Highlights.TICK, function()
				self.questPending = false
				readObjectives()
				self:Evaluate()
			end)
		end
	end)
	self:On("SettingChanged", function(_, module)
		if module == self.name then
			self:Evaluate()
		end
	end)
	self.active = true
	self:Evaluate()
end

-- Also after a start that stopped halfway.
function Highlights:OnDisable()
	if self.ticker then
		self.ticker:Hide()
	end
	if ns.Highlights.Sparkles then
		ns.Highlights.Sparkles.Hide()
	end
	self.lit = nil
	GameSettings.Stop()
	known, plates, questFacts, questObjects = nil, nil, nil, nil
end

-- What the self-test reports: the client's functions and settings that
-- highlights need, and the cursor files it knows.
ns.SelfTest.AddReport(function()
	local functions = {}
	for _, name in ipairs({ "SetUnitCursorTexture", "UnitIsGameObject", "UnitIsInInteractRange", "C_NamePlate.GetNamePlateForUnit",
		"C_QuestLog.UnitIsRelatedToActiveQuest", "C_TooltipInfo.GetUnit" }) do
		functions[#functions + 1] = name .. (Compat.Has(name) and " yes" or " NO")
	end
	local settings = {}
	for _, wanted in ipairs(GameSettings.WANTED) do
		settings[#settings + 1] = wanted[1] .. "=" .. tostring(Compat.GetCVar(wanted[1]) or "unknown")
	end
	for _, gated in ipairs(GameSettings.GATED) do
		settings[#settings + 1] = gated[1] .. "=" .. tostring(Compat.GetCVar(gated[1]) or "unknown")
	end
	local cursors, total = 0, 0
	for name in pairs(Objects.CURSORS) do
		total = total + 1
		if Compat.GetCursorFileID(name) then
			cursors = cursors + 1
		end
	end
	local skill = Compat.GetGatheringSkills()
	return ("Highlights: %s; %s; cursors %d of %d; herbalism %s, mining %s, skinning %s"):format(table.concat(functions, ", "),
		table.concat(settings, ", "), cursors, total, tostring(skill.herbs), tostring(skill.ore), tostring(skill.skinning))
end)

-- /ltm debug target: what the highlights see in the soft target and why it
-- sparkles or not, and the game settings they hold. English, as all debug
-- output.
ns.Slash.RegisterDebug("target", function()
	local facts = Compat.GetSoftInteract()
	if not facts then
		ns.Print("debug target: no soft target.")
	else
		ns.Print(("debug target: %s (object %s, cursor %s); living %s, dead %s, in reach %s; quest related %s, objective %s")
			:format(tostring(facts.name or "?"), tostring(facts.objectID or "-"), tostring(facts.cursor or "none"),
			tostring(facts.isLiving), tostring(facts.isDead), tostring(facts.inReach), tostring(facts.questRelated),
			tostring(facts.questObjective)))
		local seen = known or { cursors = Objects.CursorFiles(Compat.GetCursorFileID), chests = Highlights.Chests(),
			objectives = Objects.ObjectiveTexts(Compat.GetQuestObjectiveTexts()) }
		local kind, extra, how = Objects.Classify(facts, seen)
		local line
		if not kind then
			line = ("not a kind that sparkles (%s)"):format(tostring(extra))
		elseif not Highlights:IsActive() then
			line = ("%s, but gathering highlights are off"):format(kind)
		else
			local wanted, why = Highlights:Wants(kind)
			line = wanted and ("%s%s: sparkles, %s"):format(kind, how and (" by " .. how) or "", Highlights.State(facts, extra))
				or ("%s, not lit: %s"):format(kind, tostring(why))
		end
		ns.Print("  Kind: " .. line)
	end
	local settings = {}
	for _, list in ipairs({ GameSettings.WANTED, GameSettings.GATED }) do
		for _, setting in ipairs(list) do
			settings[#settings + 1] = ("%s=%s%s"):format(setting[1], tostring(Compat.GetCVar(setting[1]) or "unknown"),
				GameSettings.Holds(setting[1]) and " (held)" or "")
		end
	end
	ns.Print("  Game settings: " .. table.concat(settings, ", "))
end, "/ltm debug target: what the gathering highlights see in the soft target, and the game settings they hold")
