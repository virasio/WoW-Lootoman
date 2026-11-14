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
-- looted that showed as none of the kinds are chests from then on (account
-- section lootContainers).
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
	return Storage:Get("Highlights", "herbs") or Storage:Get("Highlights", "ore")
end

local Highlights = ns.Modules:Register({
	name = "Highlights",
	title = L["Gathering highlights"],
	switchLabel = L["Highlight lootable objects"],
	description = L["The object you are about to loot sparkles: the one your Interact key would use, within about 15 yards."],
	defaults = { enabled = true, herbs = true, ore = true, chests = true, quest = true, gatherable = true },
	-- The kinds in two columns, quest objects and chests on the left, herbs and
	-- ore on the right, over the profession option a little apart. The rows
	-- fill from the left.
	mainSettings = {
		{ kind = "checkboxes", columns = 2, items = {
			{ kind = "checkbox", key = "quest", label = L["Quest objects"] },
			{ kind = "checkbox", key = "herbs", label = L["Herbs"] },
			{ kind = "checkbox", key = "chests", label = L["Chests"], tooltip = L["Chests, crates and other containers you can loot."] },
			{ kind = "checkbox", key = "ore", label = L["Ore"] },
		} },
		{ kind = "checkbox", key = "gatherable", label = L["Only herbs and ore you can gather"], gap = 14,
			tooltip = L["Herbs need Herbalism and ore needs Mining. Turn it off to see them anyway."], enabledWhen = eitherGathering },
	},
})
ns.Highlights.Module = Highlights

-- The re-reading while something sparkles or soft targeting is paused.
Highlights.TICK = 0.2
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

-- What the module knows while it is on: the cursor files, Herbalism and
-- Mining, the objects the soft target showed as none of the kinds, and the
-- nameplate units shown now ({ ["nameplate3"] = true }).
local known, skills, others, plates

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

-- Whether a kind lights: its switch, and for herbs and ore the profession
-- while the player wants only those it can gather (an unknown skill lights).
-- The second value says why not.
function Highlights:Wants(kind)
	if not self:Get(kind) then
		return false, "kind off"
	end
	if (kind == "herbs" or kind == "ore") and self:Get("gatherable") and skills[kind] == false then
		return false, "no profession"
	end
	return true
end

-- The last target told in the debug output, so each one is told once.
local told

local function debug(facts, kind, state, why)
	local line = ("Highlights: %s, %s, %s"):format(facts and tostring(facts.name or facts.objectID or "?") or "no target",
		tostring(kind or "-"), tostring(state or why or "-"))
	if line ~= told then
		told = line
		ns.Debug(line)
	end
end

-- Reads the soft target again and lights it or lets it go. A living unit
-- pauses soft targeting (safe self-cast, GameSettings).
function Highlights:Evaluate()
	if not self.active or not known then
		return
	end
	local facts = Compat.GetSoftInteract()
	if facts and facts.isLiving then
		GameSettings.Pause("unit")
	end
	local kind, extra = Objects.Classify(facts, known)
	if not kind and extra == "other" and facts and facts.objectID then
		others[facts.objectID] = true
	end
	local lit, why, state = false, extra, nil
	if kind then
		lit, why = self:Wants(kind)
		if lit then
			state = Highlights.State(facts, extra)
		end
	end
	local plate = lit and Compat.GetSoftInteractPlate(plates) or nil
	if lit and ns.Highlights.Sparkles and ns.Highlights.Sparkles.Taken(plate) then
		lit, why, state = false, "another addon", nil
	end
	GameSettings.Gate(lit)
	self.lit = lit and { kind = kind, state = state, plate = plate } or nil
	if ns.Highlights.Sparkles then
		if lit and plate then
			ns.Highlights.Sparkles.Show(plate, state)
		else
			ns.Highlights.Sparkles.Hide()
		end
	end
	self.ticker:SetShown(lit or GameSettings.IsPaused())
	debug(facts, kind, state, why)
end

-- After looting a game object: the ones that showed as none of the kinds are
-- chests from now on. Never from fishing.
function Highlights:Learn()
	if Compat.IsFishingLoot() then
		return
	end
	local learned = Objects.Learn(Highlights.Chests(), Compat.GetLootSourceObjects(), others)
	if learned > 0 then
		ns.Debug(("Highlights: learned %d chest(s)"):format(learned))
	end
end

function Highlights:OnEnable()
	known = { cursors = Objects.CursorFiles(Compat.GetCursorFileID), chests = Highlights.Chests() }
	skills = Compat.GetGatheringSkills()
	others, plates = {}, {}
	told = nil
	if not self.ticker then
		self.ticker = CreateFrame("Frame")
		self.ticker.elapsed = 0
		self.ticker:SetScript("OnUpdate", function(ticker, elapsed)
			ticker.elapsed = ticker.elapsed + elapsed
			if ticker.elapsed >= Highlights.TICK then
				ticker.elapsed = 0
				GameSettings.CheckPause()
				self:Evaluate()
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
	self:OnEvent("LOOT_OPENED", function()
		self:Learn()
	end)
	local function professions()
		skills = Compat.GetGatheringSkills()
		self:Evaluate()
	end
	self:OnEvent("SKILL_LINES_CHANGED", professions)
	self:OnEvent("SPELLS_CHANGED", professions)
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
	known, skills, others, plates = nil, nil, nil, nil
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
	for _, name in ipairs(GameSettings.GATED) do
		settings[#settings + 1] = name .. "=" .. tostring(Compat.GetCVar(name) or "unknown")
	end
	local cursors, total = 0, 0
	for name in pairs(Objects.CURSORS) do
		total = total + 1
		if Compat.GetCursorFileID(name) then
			cursors = cursors + 1
		end
	end
	local skill = Compat.GetGatheringSkills()
	return ("Highlights: %s; %s; cursors %d of %d; herbalism %s, mining %s"):format(table.concat(functions, ", "),
		table.concat(settings, ", "), cursors, total, tostring(skill.herbs), tostring(skill.ore))
end)
