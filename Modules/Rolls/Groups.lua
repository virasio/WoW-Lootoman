local _, ns = ...
local Compat = ns.Compat

-- When a group of the roll history begins and ends: on GROUP_JOINED and on
-- GROUP_LEFT with the same partyGUID (both events carry it). A party that
-- becomes a raid stays the same group. The client has no call that reads the
-- party's GUID, so after a /reload or a login in a group the open group goes
-- on, and at a login outside a group it is closed. An instance group and the
-- home party are told apart by the events' category; while the character is
-- in both, the rolls go to the group joined last.
ns.Rolls = ns.Rolls or {}
local Groups = {}
ns.Rolls.Groups = Groups

local History = ns.Rolls.History

function Groups.Joined(category, partyGUID)
	local open = History.Open()
	if open and (open.id == partyGUID or open.id == nil) then
		-- The group that was open goes on; it learns its GUID if it had none.
		open.id = open.id or partyGUID
		open.category = open.category or category
		return open
	end
	return History.Start(partyGUID, category)
end

function Groups.Left(_, partyGUID)
	local open = History.Open()
	if open and (open.id == nil or open.id == partyGUID) then
		History.Close()
	end
	-- Still in a group (the home party after an instance group): it goes on as
	-- a group of its own.
	if Compat.IsInGroup() and not History.Open() then
		History.Start(nil, nil)
	end
end

-- At the start of the session: the open group goes on in a group, and is
-- closed outside one.
function Groups.Login()
	if Compat.IsInGroup() then
		return History.Open() or History.Start(nil, nil)
	end
	History.Close()
	return nil
end

-- The group drops go to now, opened if the character is in a group without
-- one (a GROUP_JOINED missed); nil outside a group.
function Groups.Current()
	if not Compat.IsInGroup() then
		return History.Open()
	end
	return History.Open() or History.Start(nil, nil)
end
