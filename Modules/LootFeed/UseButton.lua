local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- The button that uses the stuck item with a right click. Using an item is a
-- protected action, so it is a secure action button (type "item" on the right
-- button only), made out of combat with the feed. It lies over the stuck
-- row's place, after the warnings. Its parent and its anchor are the screen,
-- not the feed: a frame a protected one hangs on is protected too, and the
-- feed must stay free to resize and hide in combat. In a fight the stuck row
-- keeps its place for the button (Frames.lua).
--
-- Out of combat it follows the stuck row: its item, and where its place is;
-- with no stuck row it hides. In combat the game lets no addon
-- change what it uses, or show, hide or move it, so it stays as the fight
-- found it:
-- - A left click still lets the row go; the button's own secure handler, which
--   may change it in combat, also turns the right-click use off then, so the
--   next row's click cannot use the item of the one before.
-- - A right click uses only what the button held when the fight began.
-- - A row that sticks during the fight has no right click until it ends.
-- After the fight it catches up.
--
--   local use = UseButton.Create(feed)       -- out of combat, with the feed
--   use:Sync(row, place)                     -- each draw: the stuck row and its place, or nil
ns.Feed = ns.Feed or {}
local UseButton = {}
ns.Feed.UseButton = UseButton

-- Run by the button's secure handler before each click, in combat too.
UseButton.LEFT_CLICK = [[
	if button == "LeftButton" then
		self:SetAttribute("type2", nil)
	end
]]

local ButtonMixin = {}
ButtonMixin.__index = ButtonMixin

-- The stuck row's own frame shows its tooltip, the button being over it.
local function rowFrameOf(use)
	return use.row and use.feed.frameOf[use.row] or nil
end

function UseButton.Create(feed)
	local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetFrameStrata(feed.frame:GetFrameStrata())
	button:SetFrameLevel(feed.frame:GetFrameLevel() + 20)
	button:Hide()
	local header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	SecureHandlerWrapScript(button, "OnClick", header, UseButton.LEFT_CLICK)
	local use = setmetatable({ button = button, feed = feed }, ButtonMixin)
	button:HookScript("OnClick", function(_, mouseButton, down)
		if mouseButton == "LeftButton" and not down then
			feed:Dismiss(use.row)
		end
	end)
	button:SetScript("OnEnter", function()
		local rowFrame = rowFrameOf(use)
		if rowFrame then
			rowFrame:GetScript("OnEnter")(rowFrame)
		end
	end)
	button:SetScript("OnLeave", function()
		local rowFrame = rowFrameOf(use)
		if rowFrame then
			rowFrame:GetScript("OnLeave")(rowFrame)
		end
	end)
	return use
end

-- Brings the button in line after a fight, with the feed as it is then.
local function afterCombat(use)
	Bus:OffEvent("PLAYER_REGEN_ENABLED", use)
	use.waiting = false
	use.feed:SyncUse()
end

-- Stands for the stuck row (row, or nil) at its place (place: { left, bottom,
-- width, height } on the screen, or nil while the feed has none). The
-- row is followed in combat too, for the left click and the tooltip; the rest
-- waits for the end of the fight.
function ButtonMixin:Sync(row, place)
	self.row, self.place = row, place
	if Compat.InCombat() then
		if not self.waiting then
			self.waiting = true
			Bus:OnEvent("PLAYER_REGEN_ENABLED", self, function()
				afterCombat(self)
			end)
		end
		return
	end
	local button = self.button
	if not row or not row.id or not place then
		if button:IsShown() then
			button:Hide()
		end
		return
	end
	local item = "item:" .. row.id
	if button:GetAttribute("item") ~= item or button:GetAttribute("type2") ~= "item" then
		button:SetAttribute("type2", "item")
		button:SetAttribute("item", item)
	end
	local now = self.placed
	if not now or now.left ~= place.left or now.bottom ~= place.bottom or now.width ~= place.width or now.height ~= place.height then
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", place.left, place.bottom)
		button:SetSize(place.width, place.height)
		self.placed = place
	end
	if not button:IsShown() then
		button:Show()
	end
end
