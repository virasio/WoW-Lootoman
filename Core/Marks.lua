local _, ns = ...
local Bus, Storage = ns.Bus, ns.Storage

-- The player's marks on items, by item ID, in the profile's section "marks":
-- marks[itemID] = "junk" (throw it away, whatever its quality) or "notJunk" (a
-- gray item to keep, for transmog, say). Every change sends
-- MarksChanged(itemID, mark), with mark nil when it was removed; clearing them
-- all sends MarksChanged(nil, nil). A profile switch brings the other profile's
-- marks (ProfileChanged).
local Marks = {}
ns.Marks = Marks

Marks.KINDS = { junk = true, notJunk = true }

local function section()
	return Storage:GetSection("marks")
end

-- The mark on an item, or nil. A saved value that is not a mark is ignored.
function Marks.Get(itemID)
	local mark = section()[itemID]
	return Marks.KINDS[mark] and mark or nil
end

-- Sets the mark, or removes it with nil.
function Marks.Set(itemID, mark)
	assert(type(itemID) == "number", "an item ID must be a number")
	assert(mark == nil or Marks.KINDS[mark], ("unknown mark %s"):format(tostring(mark)))
	if Marks.Get(itemID) == mark then
		return
	end
	section()[itemID] = mark
	Bus:Send("MarksChanged", itemID, mark)
end

-- Removes every mark of the profile.
function Marks.Clear()
	local marks = section()
	if next(marks) == nil then
		return
	end
	for itemID in pairs(marks) do
		marks[itemID] = nil
	end
	Bus:Send("MarksChanged", nil, nil)
end

-- Every mark as { itemID, mark }, by item ID.
function Marks.List()
	local list = {}
	for itemID, mark in pairs(section()) do
		if type(itemID) == "number" and Marks.KINDS[mark] then
			list[#list + 1] = { itemID = itemID, mark = mark }
		end
	end
	table.sort(list, function(a, b) return a.itemID < b.itemID end)
	return list
end
