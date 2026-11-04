local _, ns = ...
local Marks = ns.Marks

-- What is junk: gray items, and items the player marked as junk, but not gray
-- items marked "not junk". Every part that shows or sells junk asks here, so
-- they never disagree. An item is { itemID, quality }; quality is nil while
-- the client has not loaded the item, and such an item is junk only when
-- marked.
ns.Rules = ns.Rules or {}
local Junk = {}
ns.Rules.Junk = Junk

-- Enum.ItemQuality.Poor.
Junk.POOR = 0

-- { junk = true or false, reason }: reason is "marked" (marked junk), "gray",
-- "notJunk" (gray, marked not junk) or nil (any other item).
function Junk.Decide(item)
	local mark = Marks.Get(item.itemID)
	if mark == "junk" then
		return { junk = true, reason = "marked" }
	elseif item.quality == Junk.POOR then
		if mark == "notJunk" then
			return { junk = false, reason = "notJunk" }
		end
		return { junk = true, reason = "gray" }
	end
	return { junk = false }
end

-- Dragged into the junk section: junk from now on. A gray item only loses its
-- "not junk" mark, as being gray makes it junk.
function Junk.MarkJunk(item)
	if item.quality == Junk.POOR then
		Marks.Set(item.itemID, nil)
	else
		Marks.Set(item.itemID, "junk")
	end
end

-- Dragged out of the junk section: a gray item is marked "not junk", any other
-- item loses its mark.
function Junk.MarkNotJunk(item)
	if item.quality == Junk.POOR then
		Marks.Set(item.itemID, "notJunk")
	else
		Marks.Set(item.itemID, nil)
	end
end
