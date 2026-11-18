local _, ns = ...

-- What junk Lootoman suggests, and the junk it warns about: pure rules over
-- the facts the junk sections gather for each bag item, so they can be tested
-- without the game. A suggestion is only a suggestion: an item becomes junk
-- when the player sends it there.
--
-- The rules, in this order; an item goes to the first that finds it:
--   questDone   an item that starts a quest already done, or a quest item
--               whose quests are all done (QuestieDB) or, without it, a quest
--               item no quest in the log wants;
--   leftovers   any other item whose quests are all done (QuestieDB), or,
--               without it, one a quest this character turned in wanted;
--               only when it is not worth the auction;
--   unusable    soulbound gear the character cannot use, while its required
--               level is not above the character's;
--   known       a recipe the character knows, or a mount, pet, toy or
--               heirloom already collected; when tradeable, only when it is
--               not worth the auction;
--   outgrown    food, drink, potions, elixirs, flasks and bandages whose
--               required level is OUTGROWN or more below the character's;
--               when tradeable, only when it is not worth the auction.
-- Never suggested: an item with a mark, in an equipment set, refundable, an
-- appearance not collected yet, or one a quest in the log still wants.
--
-- The facts (all optional; a missing one counts as false or unknown):
--   mark, equipmentSet, refundable, uncollected, quality, bound, equippable,
--   canUse, requiredLevel, classID, subclassID, isCraftingReagent, level,
--   startsQuest, startsQuestDone, questItem, recipeKnown, collected,
--   related (QuestieDB's quest IDs, or nil without it), relatedDone (every
--   related quest done), relatedActive (one of them in the log),
--   wantedByLog (an unfinished objective in the log names it), doneByMemory
--   (a quest turned in wanted it), auction (the stack's auction price after
--   the cut), vendor (the stack's merchant price).
ns.Rules = ns.Rules or {}
local Suggest = {}
ns.Rules.Suggest = Suggest

Suggest.RULES = { "questDone", "leftovers", "unusable", "known", "outgrown" }
-- Not worth the auction: its price after the cut is at most this many times
-- what a merchant pays.
Suggest.AUCTION_FACTOR = 1.5
-- Outgrown: this many levels and more below the character.
Suggest.OUTGROWN = 20
-- Enum.ItemClass.Consumable and the subclasses a character outgrows
-- (Enum.ItemConsumableSubclass): potion, elixir, flask, food and drink, bandage.
Suggest.CONSUMABLE = 0
Suggest.OUTGROWN_SUBCLASSES = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true }

-- Whether a quest in the log still wants the item.
local function wanted(facts)
	return facts.wantedByLog == true or facts.relatedActive == true
end

-- Not worth the auction: its auction price after the cut is at most
-- AUCTION_FACTOR times a merchant's; with no auction price, an item no
-- profession uses as a reagent.
function Suggest.Cheap(facts)
	if facts.auction then
		return facts.auction <= Suggest.AUCTION_FACTOR * (facts.vendor or 0)
	end
	return facts.isCraftingReagent ~= true
end

-- Cheap, or bound (it can only go to a merchant anyway).
local function cheapOrBound(facts)
	return facts.bound == true or Suggest.Cheap(facts)
end

local function quests(facts)
	return type(facts.related) == "table" and #facts.related > 0
end

local RULES = {
	questDone = function(facts)
		if facts.startsQuest and facts.startsQuestDone == true then
			return { rule = "questDone", why = "started" }
		end
		if facts.questItem == true then
			if facts.related ~= nil then
				if quests(facts) and facts.relatedDone == true then
					return { rule = "questDone", why = "done" }
				end
			elseif not facts.wantedByLog then
				return { rule = "questDone", why = "notInLog" }
			end
		end
	end,
	leftovers = function(facts)
		if facts.questItem == true then
			return nil
		end
		local done
		if facts.related ~= nil then
			done = quests(facts) and facts.relatedDone == true
		else
			done = facts.doneByMemory == true
		end
		if done and Suggest.Cheap(facts) then
			return { rule = "leftovers", auction = facts.auction, vendor = facts.vendor }
		end
	end,
	unusable = function(facts)
		if facts.bound == true and facts.equippable == true and facts.canUse == false
			and (facts.requiredLevel or 0) <= (facts.level or 0) then
			return { rule = "unusable" }
		end
	end,
	known = function(facts)
		if (facts.recipeKnown == true or facts.collected == true) and cheapOrBound(facts) then
			return { rule = "known", why = facts.recipeKnown == true and "recipe" or "collected" }
		end
	end,
	outgrown = function(facts)
		if facts.classID == Suggest.CONSUMABLE and Suggest.OUTGROWN_SUBCLASSES[facts.subclassID]
			and (facts.requiredLevel or 0) + Suggest.OUTGROWN <= (facts.level or 0) and cheapOrBound(facts) then
			return { rule = "outgrown", requiredLevel = facts.requiredLevel or 0 }
		end
	end,
}

-- The suggestion for an item, or nil: { rule, and what tells why }. enabled:
-- the rules' switches by key; a rule missing from it is on.
---@return { rule: string }?
function Suggest.Find(facts, enabled)
	if facts.mark or facts.equipmentSet or facts.refundable or facts.uncollected or wanted(facts) then
		return nil
	end
	for _, key in ipairs(Suggest.RULES) do
		if not enabled or enabled[key] ~= false then
			local found = RULES[key](facts)
			if found then
				return found
			end
		end
	end
	return nil
end

-- Whether junk should be looked at again: a quest in the log still wants it.
function Suggest.Hint(facts)
	return wanted(facts)
end
