local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage
local Objects = ns.Rules.Objects

-- What the quest log says about items, for junk suggestions without
-- QuestieDB: which items the quests in the log still want (their unfinished
-- objectives to collect or use), and which items the quests this character
-- turned in wanted. The client tells neither once a quest is done, so the
-- objectives of every quest seen in the log are kept, by quest, and when a
-- quest is turned in its items go into a list kept for the character
-- (section questItems: { schema = 1, done = { [plain name] = true } }). It
-- learns from the first time it runs: a quest turned in before is not known.
-- Names are compared as gathering highlights compare them (Objects.Plain).
local Junk = ns.Modules:Get("Junk")
local QuestMemory = {}
Junk.QuestMemory = QuestMemory

QuestMemory.SECTION = "questItems"

-- The objectives of the quests seen in the log this session, by quest
-- ({ [questID] = { plain texts } }), and what the log wants now (a list of
-- plain texts); both read when the log changes.
local seen, wanted = {}, {}

local function section()
	local data = Storage:GetCharacterSection(QuestMemory.SECTION)
	data.schema = data.schema or 1
	if type(data.done) ~= "table" then
		data.done = {}
	end
	return data
end

-- The quest log read again.
function QuestMemory.Read()
	for questID, texts in pairs(Compat.GetQuestItemObjectives()) do
		seen[questID] = Objects.ObjectiveTexts(texts)
	end
	wanted = Objects.ObjectiveTexts(Compat.GetQuestObjectiveTexts())
end

-- A quest turned in: the items it wanted are done with.
function QuestMemory.TurnedIn(questID)
	local texts = seen[questID]
	if texts then
		local done = section().done
		for _, text in ipairs(texts) do
			done[text] = true
		end
		seen[questID] = nil
	end
	if ns.Integrations.QuestieDB then
		ns.Integrations.QuestieDB.Forget()
	end
end

-- Whether an unfinished objective of a quest in the log names the item.
function QuestMemory.Wanted(name)
	return Objects.WantedByObjective(name, wanted)
end

-- Whether a quest this character turned in wanted the item.
function QuestMemory.Done(name)
	local list = {}
	for text in pairs(section().done) do
		if type(text) == "string" then
			list[#list + 1] = text
		end
	end
	return Objects.WantedByObjective(name, list)
end

Junk.AddPart({
	Enable = function()
		seen, wanted = {}, {}
		QuestMemory.Read()
		Junk.ListenEvent("QUEST_LOG_UPDATE", QuestMemory.Read)
		Junk.ListenEvent("QUEST_TURNED_IN", function(_, questID)
			QuestMemory.TurnedIn(questID)
		end)
	end,
	Disable = function()
		seen, wanted = {}, {}
	end,
})
