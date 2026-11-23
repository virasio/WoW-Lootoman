local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- Ninja detection on a roll's view, while its checkbox is on: a need that
-- breaks the needer's class's rules (Rules/Need.lua with Core/NeedRules.lua);
-- for a BoE item, what he did on the other BoE items in the group; needing
-- nearly everything in this group; and a mark he had in the last group the
-- character shared with him, until he is fair again. Each marked player gets
-- a mark after his name and the reasons in his tooltip; the raid lines count
-- them and show them as squares. An excused need ("he asked in the chat")
-- gets a faint mark of its own and counts nowhere. Friends and guild
-- members are never marked, when the check says so.
ns.Rolls = ns.Rolls or {}
local Marks = {}
ns.Rolls.Marks = Marks

local Need = ns.Rules.Need
local History = ns.Rolls.History

-- The marks after a name: the raid's skull for a ninja, the ready check's
-- tick for an excused need.
Marks.NINJA = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"
Marks.EXCUSED = " |TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t"
Marks.BOE = 2

local function setting(key)
	return Storage:Get("Rolls", key)
end

local function checks()
	return {
		armor = setting("checkArmor"),
		weapons = setting("checkWeapons"),
		stats = setting("checkStats"),
		minQuality = setting("minQuality"),
	}
end

-- The game's name of a class, of an armor or weapon type, of a stat.
local classIDs
local function className(classFile)
	if not classIDs then
		classIDs = {}
		for _, class in ipairs(ns.Data.rolls.classes) do
			classIDs[class[1]] = class[2]
		end
	end
	return classIDs[classFile] and Compat.GetClassName(classIDs[classFile]) or tostring(classFile)
end

local function statName(stat)
	return Compat.GetGlobalString("ITEM_MOD_" .. stat .. "_SHORT") or stat
end

-- What the item of a link is, for the rules: its kind, quality, primary stats
-- (nil while the game has not loaded them) and bind type.
function Marks.Facts(link)
	if not link then
		return nil
	end
	local kind = Compat.GetItemKind(link)
	if not kind then
		return nil
	end
	local info = Compat.GetItemInfo(link)
	local stats = Need.PrimaryStats(Compat.GetItemStats(link), ns.Data.rolls.stats)
	if not stats then
		Compat.RequestItem(kind.itemID)
		if ns.Rolls.Module then
			ns.Rolls.Module.WaitForItem()
		end
	end
	return {
		itemID = kind.itemID,
		classID = kind.classID,
		subclassID = kind.subclassID,
		equipLoc = kind.equipLoc,
		quality = info and info.quality,
		bindType = info and info.bindType,
		stats = stats,
	}
end

-- A reason as the tooltip says it.
function Marks.Text(reason, class)
	local who = className(class)
	if reason.kind == "armor" then
		local name = Compat.GetItemSubClassName(Need.ARMOR, reason.subclass) or tostring(reason.subclass)
		if reason.level then
			return (L["%s: not a %s's armor past level %d"]):format(name, who, reason.level)
		end
		return (L["%s: not a %s's armor"]):format(name, who)
	elseif reason.kind == "weapon" then
		return (L["%s: not a %s's weapon"]):format(Compat.GetItemSubClassName(Need.WEAPON, reason.subclass) or tostring(reason.subclass), who)
	elseif reason.kind == "stats" then
		local names = {}
		for index, stat in ipairs(reason.stats) do
			names[index] = statName(stat)
		end
		return (L["%s: not a %s's stat"]):format(table.concat(names, ", "), who)
	elseif reason.kind == "everything" then
		return (L["Needed %d of %d items in this group"]):format(reason.needs, reason.total)
	elseif reason.kind == "greedFitting" then
		return (L["Greed on a fitting BoE (%s), need on this one"]):format(reason.link or "?")
	elseif reason.kind == "everyBoE" then
		return (L["Needs every BoE: %d of %d"]):format(reason.needs, reason.total)
	elseif reason.kind == "lastTime" then
		if reason.boe then
			return (L["Last time: needed BoE items that did not fit (%s, %s)"]):format(reason.day or "?", reason.place or "?")
		end
		return (L["Last time: needed %d of %d items (%s, %s)"]):format(reason.needs, reason.total, reason.day or "?", reason.place or "?")
	end
	return "?"
end

-- Whether a player is spared: a friend or a guild member, when the check says so.
local function spared(player)
	return setting("spareFriends") and player.guid ~= nil and (Compat.IsFriend(player.guid) or Compat.IsGuildMember(player.guid))
end

-- The group's members' levels by GUID, read now.
local function levels()
	local found = {}
	for _, unit in ipairs(Compat.GetGroupUnits()) do
		local guid = Compat.GetUnitGUID(unit)
		if guid then
			found[guid] = Compat.GetUnitLevel(unit)
		end
	end
	return found
end

-- A player's choices with what the rules say of each item: { state, excused,
-- boe, fits, link }.
local function judged(choices, player, factsOf)
	local rules = ns.NeedRules.Get(player.class)
	local list = {}
	for index, choice in ipairs(choices) do
		local facts = factsOf(choice.link)
		local reasons = facts and Need.Judge(facts, { class = player.class, level = choice.level or player.level }, rules, checks()) or {}
		list[index] = { state = choice.state, excused = choice.excused, link = choice.link, boe = facts ~= nil and facts.bindType == Marks.BOE,
			fits = facts ~= nil and #reasons == 0 }
	end
	return list
end

-- What a closed group says of a player: needing nearly everything, or a need
-- on a BoE item that did not fit him with a reason of the BoE kind. Kept
-- until the rules or the settings change (Marks.Invalidate).
local lastCache = {}

function Marks.Invalidate()
	lastCache = {}
end

local function lastTime(player, history, current, preset, factsOf)
	local key = tostring(player.guid) .. "|" .. tostring(current)
	if lastCache[key] ~= nil then
		return lastCache[key] or nil
	end
	local group = history.LastShared(player.guid, current)
	local found
	if group then
		local choices = judged(history.Choices(group, player.guid), player, factsOf)
		local needy, needs, total = Need.NeedsEverything(choices, preset)
		local place = group.drops[1] and group.drops[1].place
		local day = group.started and Compat.FormatDay(group.started)
		if needy then
			found = { kind = "lastTime", needs = needs, total = total, day = day, place = place }
		else
			for index, choice in ipairs(choices) do
				if Need.IsNeed(choice.state) and not choice.excused and choice.boe and not choice.fits then
					local earlier = { unpack(choices, 1, index - 1) }
					if Need.BoEReason(earlier, preset) then
						found = { kind = "lastTime", boe = true, day = day, place = place }
						break
					end
				end
			end
		end
	end
	lastCache[key] = found or false
	return found
end

-- Whether a need on the item breaks none of a class's rules, as the checks
-- now say (for the demos).
function Marks.Fits(facts, class, level)
	return #Need.Judge(facts, { class = class, level = level }, ns.NeedRules.Get(class), checks()) == 0
end

-- A class whose rules a need on the item breaks (for the demo), or nil.
function Marks.BreakingClass(facts, level)
	for _, class in ipairs(ns.Data.rolls.classes) do
		if not Marks.Fits(facts, class[1], level) then
			return class[1]
		end
	end
	return nil
end

-- Adds the marks to a view (Model.View, or the demo's). context, for the
-- demo: { history = a stand-in for History, group = its open group, facts =
-- fn(link), reasons = { [guid] = extra reasons }, excused = { [guid] = true } }.
function Marks.Add(view, context)
	view.ninjas = {}
	if not setting("ninja") or not view.bound then
		view.needLine = nil
		return view
	end
	context = context or {}
	local history = context.history or History
	local group = context.group or history.Open()
	local factsOf = context.facts or Marks.Facts
	local preset = Need.Preset(setting("strictness"))
	local item = factsOf(view.link)
	local now = context.levels or levels()
	local key = view.drop and view.drop.key
	local entry = group and key and History.Find(group, key)
	local excusedHere = {}
	for _, kept in ipairs(entry and entry.rolls or {}) do
		if kept.guid and kept.excused then
			excusedHere[kept.guid] = true
		end
	end
	local needs = 0
	for _, player in ipairs(view.players) do
		player.level = player.level or (player.guid and now[player.guid])
		player.mark, player.notes = nil, nil
		local isNeed = Need.IsNeed(player.state)
		if isNeed then
			needs = needs + 1
		end
		local excused = (context.excused and context.excused[player.guid]) or excusedHere[player.guid]
		player.excused = excused or nil
		if isNeed and excused then
			player.mark = Marks.EXCUSED
		elseif isNeed and not spared(player) then
			local reasons = {}
			local rules = ns.NeedRules.Get(player.class)
			local ruleReasons = item and Need.Judge(item, { class = player.class, level = player.level }, rules, checks()) or {}
			local before = group and judged(history.Choices(group, player.guid, key), player, factsOf) or {}
			local boeReason
			if setting("checkBoE") and item and item.bindType == Marks.BOE and #ruleReasons > 0 then
				boeReason = Need.BoEReason(before, preset)
			end
			for _, reason in ipairs(ruleReasons) do
				reasons[#reasons + 1] = { reason = reason, boe = item ~= nil and item.bindType == Marks.BOE and not boeReason }
			end
			if boeReason then
				reasons[#reasons + 1] = { reason = boeReason }
			end
			local sofar = { unpack(before) }
			sofar[#sofar + 1] = { state = player.state }
			if setting("checkEverything") then
				local needy, count, total = Need.NeedsEverything(sofar, preset)
				if needy then
					reasons[#reasons + 1] = { reason = { kind = "everything", needs = count, total = total } }
				end
			end
			if setting("checkLastTime") and player.guid and not Need.Fair(sofar, preset) then
				local last = lastTime(player, history, group, preset, factsOf)
				if last then
					reasons[#reasons + 1] = { reason = last }
				end
			end
			for _, extra in ipairs(context.reasons and context.reasons[player.guid] or {}) do
				reasons[#reasons + 1] = { reason = extra }
			end
			if #reasons > 0 then
				player.mark = Marks.NINJA
				player.notes = {}
				for index, found in ipairs(reasons) do
					local text = Marks.Text(found.reason, player.class)
					player.notes[index] = found.boe and (text .. " " .. L["(BoE)"]) or text
				end
				view.ninjas[#view.ninjas + 1] = player
			end
		end
	end
	view.needLine = (L["Need: %d, ninja: %d"]):format(needs, #view.ninjas)
	return view
end
