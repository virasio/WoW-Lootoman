local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- Exists only when the addon runs from the repository: the packager removes
-- the #@debug@ block from the TOC. /lootoman families prints the bag family
-- bits the client gives one bag of each kind, and those of the equipped bags,
-- so the free-slot bar's family tokens rest on values checked in game: the
-- bits are known from the community, not from Blizzard. More item IDs can
-- follow the command. The lines are also kept in the character's session data
-- ("bagFamilies"), to read from the saved variables after a /reload; the next
-- login empties it. Development text is not translated.

-- One bag of each kind (item IDs checked against Wowhead's tooltips on Nov 5,
-- 2026): its ID, its name for the output, the kind it is, and the family bit
-- the community lists for that kind (0: a bag that holds anything).
local BAGS = {
	{ 22250, "Herb Pouch", "herb", 0x20 },
	{ 38347, "Mammoth Mining Bag", "mining", 0x400 },
	{ 34482, "Leatherworker's Satchel", "leather", 0x8 },
	{ 22246, "Enchanted Mageweave Pouch", "enchanting", 0x40 },
	{ 30745, "Heavy Toolbox", "engineering", 0x80 },
	{ 39489, "Scribe's Satchel", "inscription", 0x10 },
	{ 30747, "Gem Pouch", "gem", 0x200 },
	{ 60218, "Lure Master Tackle Box", "fishing", 0x8000 },
	{ 92748, "Portable Refrigerator", "cooking", 0x10000 },
	-- Kinds of older clients; retail may not have these items.
	{ 2101, "Light Quiver", "arrows", 0x1 },
	{ 2102, "Small Ammo Pouch", "bullets", 0x2 },
	{ 22243, "Small Soul Pouch", "soul", 0x4 },
	-- Profession bags of The War Within hold anything, and the reagent bag
	-- has no family either.
	{ 222859, "Concoctor's Clutch", "general", 0 },
	{ 222860, "Ignition Satchel", "general", 0 },
	{ 222855, "Weavercloth Reagent Bag", "reagent", 0 },
}

local function bits(value)
	if value == nil then
		return "nil"
	end
	return ("%d (0x%x)"):format(value, value)
end

local saved

local function say(text)
	ns.Print(text)
	saved.lines[#saved.lines + 1] = text
end

-- One line per bag; returns whether the family is the expected one, or nil
-- when it cannot tell.
local function report(itemID, label, kind, expected)
	local found = Compat.GetItemKind(itemID)
	if not found then
		say(("%d %s: no such item on this client"):format(itemID, label))
		return nil
	end
	local info = Compat.GetItemInfo(itemID)
	local name = info and info.name or "(not loaded yet: run the command again)"
	local verdict, result = "", nil
	if expected and found.family ~= nil then
		result = found.family == expected
		verdict = result and ", as expected" or (", EXPECTED %s for %s"):format(bits(expected), kind)
	elseif expected then
		verdict = ", family not known yet: run the command again"
	end
	say(("%d %s: %s, %s (class %s.%s), family %s%s"):format(itemID, label, name, tostring(found.subType),
		tostring(found.classID), tostring(found.subClassID), bits(found.family), verdict))
	return result
end

ns.Slash.Register("families", function(argument)
	saved = Storage:GetSessionSection("bagFamilies")
	saved.project, saved.lines = Compat.GetProjectID(), {}
	say("Bag families, as this client gives them:")
	local same, different = 0, 0
	local function count(result)
		if result == true then
			same = same + 1
		elseif result == false then
			different = different + 1
		end
	end
	for _, bag in ipairs(BAGS) do
		count(report(bag[1], bag[2], bag[3], bag[4]))
	end
	for word in (argument or ""):gmatch("%d+") do
		report(tonumber(word), "(asked for)")
	end
	local bags, reagentBag = Compat.GetPlayerBags()
	local all = {}
	for _, bag in ipairs(bags) do
		all[#all + 1] = bag
	end
	all[#all + 1] = reagentBag
	for _, bag in ipairs(all) do
		local size = Compat.GetBagSize(bag)
		if size > 0 then
			local _, family = Compat.GetBagFreeSlots(bag)
			say(("Equipped bag %d: %d slots, family %s"):format(bag, size, bits(family)))
		end
	end
	say(("%d as expected, %d different."):format(same, different))
end)
