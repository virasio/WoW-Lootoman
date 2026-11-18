local _, ns = ...
local Text = ns.Text

-- What kind of object the game's soft interact target is, for gathering
-- highlights: herbs, ore, chests or a quest object, and whether it can be used
-- right now. Pure rules over the facts Compat.GetSoftInteract reads, so they
-- can be tested without the game.
--
-- The kind comes first from the cursor the game would show over the object.
-- The cursor names are those the WoW Forever client knows, as Lueur's author
-- read them from it; an "Unable" cursor means the object can't be used yet (a
-- lock, too little skill). A chest often shows a lever's cursor instead of a
-- loot cursor (also Lueur's finding), so chests are also known by words in
-- their names and by the objects looted from before.
--
-- A quest object is one the game says a quest wants (the quest flag, or a
-- quest line in its tooltip), or one whose name an unfinished objective of a
-- quest in the log holds: many objects to pick up for a quest have neither
-- the flag nor the line, and only the generic Interact cursor, as Lueur's
-- author found.
ns.Rules = ns.Rules or {}
local Objects = {}
ns.Rules.Objects = Objects

Objects.KINDS = { "herbs", "ore", "chests", "quest" }

-- The game's cursor files (Interface\Cursor\<name>) and what they mark.
-- "bobber" and "service" (a mailbox, a vendor) are never highlighted.
Objects.CURSORS = {
	Mine = "ore",
	GatherHerbs = "herbs",
	PickLock = "chests", LootAll = "chests", Pickup = "chests",
	Quest = "quest", QuestRepeatable = "quest", QuestTurnIn = "quest", QuestInteract = "quest",
	CampaignQuest = "quest", CampaignQuestTurnIn = "quest", LegendaryQuest = "quest", LegendaryQuestTurnIn = "quest",
	Important = "quest", ImportantTurnIn = "quest", Recurring = "quest", Recurringturnin = "quest",
	Wrapper = "quest", Wrapperturnin = "quest",
	Fishing = "bobber", FishingCursor = "bobber",
	Mail = "service", Speak = "service", Buy = "service", Trainer = "service", Taxi = "service",
	Innkeeper = "service", Repair = "service", RepairNPC = "service", Stablemaster = "service",
}

-- When the client gives the cursor as a path or an atlas name
-- ("Cursor_Crosshair_UnableMine_64") instead of a file ID: the first word found
-- wins, so "questinteract" is a quest object.
Objects.KEYWORDS = {
	{ "gather", "herbs" }, { "mine", "ore" },
	{ "quest", "quest" }, { "important", "quest" }, { "recurring", "quest" }, { "wrapper", "quest" },
	{ "lootall", "chests" }, { "pickup", "chests" }, { "picklock", "chests" },
	{ "fishing", "bobber" },
	{ "mail", "service" }, { "speak", "service" }, { "buy", "service" }, { "trainer", "service" },
	{ "taxi", "service" }, { "innkeeper", "service" }, { "repair", "service" }, { "stable", "service" },
}

-- Words a chest's name starts or ends with, in the client languages
-- Lootoman speaks. Both lists are checked: a name in one language does not
-- contain the other's words.
Objects.CHEST_WORDS = {
	"chest", "coffer", "strongbox", "crate", "cache", "footlocker",
	"сундук", "ларец", "ящик", "тайник",
}

-- The cursor file IDs the client knows: { [fileID] = { kind, unable } }, each
-- name with and without "Unable"; getFileID(name) is Compat.GetCursorFileID.
function Objects.CursorFiles(getFileID)
	local files = {}
	for name, kind in pairs(Objects.CURSORS) do
		for _, prefix in ipairs({ "", "Unable" }) do
			local id = getFileID(prefix .. name)
			if id then
				files[id] = { kind = kind, unable = prefix ~= "" }
			end
		end
	end
	return files
end

-- The kind a cursor marks, and whether it is an "Unable" one.
local function fromCursor(cursor, files)
	if type(cursor) == "number" then
		local file = files and files[cursor]
		if file then
			return file.kind, file.unable
		end
		return nil, false
	end
	if type(cursor) ~= "string" then
		return nil, false
	end
	local name = cursor:lower()
	local unable = name:find("unable", 1, true) ~= nil
	for _, keyword in ipairs(Objects.KEYWORDS) do
		if name:find(keyword[1], 1, true) then
			return keyword[2], unable
		end
	end
	return nil, unable
end

-- A name or an objective as they are compared: regardless of case, without
-- a counter ("0/8"), and without the spaces, colons and dashes around the rest.
function Objects.Plain(text)
	local plain = Text.FoldCase(text):gsub("\194\160", " "):gsub("%d+%s*/%s*%d+", "")
	return (plain:gsub("^[%s:%-]+", ""):gsub("[%s:%-]+$", ""))
end

-- Objectives' texts (Compat.GetQuestObjectiveTexts) as Classify compares them,
-- those of fewer than four letters left out.
function Objects.ObjectiveTexts(texts)
	local list = {}
	for _, text in ipairs(texts or {}) do
		if type(text) == "string" then
			local plain = Objects.Plain(text)
			if Text.Length(plain) >= 4 then
				list[#list + 1] = plain
			end
		end
	end
	return list
end

-- Whether one of the objectives (ObjectiveTexts) wants an object of this
-- name: the objective holds the name ("Waterlogged Saw: 0/1" for the saw), or
-- the name holds an objective of five letters or more ("Crate of Supplies"
-- for "Supplies: 0/4"). A name of fewer than four letters never matches.
function Objects.WantedByObjective(name, objectives)
	if type(name) ~= "string" or type(objectives) ~= "table" or #objectives == 0 then
		return false
	end
	local plain = Objects.Plain(name)
	if Text.Length(plain) < 4 then
		return false
	end
	for _, objective in ipairs(objectives) do
		if objective:find(plain, 1, true) or (Text.Length(objective) >= 5 and plain:find(objective, 1, true)) then
			return true
		end
	end
	return false
end

-- Whether a name starts or ends with one of the chest words, as a word.
function Objects.NamesChest(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local folded = Text.FoldCase(name)
	for _, word in ipairs(Objects.CHEST_WORDS) do
		if folded == word or folded:sub(1, #word + 1) == word .. " " or folded:sub(-(#word + 1)) == " " .. word then
			return true
		end
	end
	return false
end

-- The kind of the soft target and whether it can be used now: kind, unable,
-- and for a quest object how it was known ("game", "tooltip", "objective",
-- "cursor"); or nil and why it is none of the kinds: "none" (no target),
-- "unit" (a creature, a player or a corpse), "bobber", "service", "other".
-- known: { cursors = CursorFiles(…), chests = { [objectID] = true },
-- objectives = ObjectiveTexts(…) }.
-- Gathering needs the skill, so a herb or a vein a quest also wants stays a
-- herb or a vein; any other object the game says a quest wants is a quest
-- object. An objective's words never make a mailbox or a vendor one (Lueur
-- saw "Mailbox" taken for a quest's box): they come after those cursors, and
-- before the other cursors, the learned chests and the chest words.
function Objects.Classify(facts, known)
	if not facts then
		return nil, "none"
	end
	if facts.isObject ~= true then
		return nil, "unit"
	end
	known = known or {}
	local kind, unable = fromCursor(facts.cursor, known.cursors)
	if kind == "herbs" or kind == "ore" then
		return kind, unable
	end
	if facts.questRelated == true then
		return "quest", unable, "game"
	end
	if facts.questObjective == true then
		return "quest", unable, "tooltip"
	end
	if kind == "bobber" or kind == "service" then
		return nil, kind
	end
	if Objects.WantedByObjective(facts.name, known.objectives) then
		return "quest", unable, "objective"
	end
	if kind then
		return kind, unable, kind == "quest" and "cursor" or nil
	end
	if facts.objectID and known.chests and known.chests[facts.objectID] then
		return "chests", unable
	end
	if Objects.NamesChest(facts.name) then
		return "chests", unable
	end
	return nil, "other"
end

-- After looting a game object: every source object of the loot window (its
-- ID) is a chest from now on, in chests, as Lueur learns them; the caller
-- leaves out fishing. A herb or a vein learned so stays what it is, as its
-- cursor comes before the learned chests (Classify); only an object with
-- neither, a crate or a Windstone, lights as a chest from then on. An object
-- in skip (the quest objects seen, { [objectID] = true }) is not learned:
-- once its quest is done, it is no chest. Returns how many were learned.
function Objects.Learn(chests, sources, skip)
	local learned = 0
	for _, id in ipairs(sources) do
		if not chests[id] and not (skip and skip[id]) then
			chests[id] = true
			learned = learned + 1
		end
	end
	return learned
end
