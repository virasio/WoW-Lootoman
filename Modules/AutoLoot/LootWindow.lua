local _, ns = ...

-- Hides Blizzard's loot window (LootFrame) while fast autoloot takes the slots,
-- and shows it with the slots that are left. LootFrame keeps working while it is
-- hidden: it moves into a hidden holder frame and back. LootFrame is not a
-- protected frame, so this works in combat too.
--
-- Rules from Blizzard's LootFrame.lua:
-- - It moves into the holder only while it is not visible: a visible frame whose
--   parent is hidden gets OnHide, and LootFrame's OnHide closes the loot.
-- - LOOT_OPENED opens it about 0.25 s after the first LOOT_READY, so the move
--   happens on LOOT_READY.
-- - It listens to LOOT_SLOT_CLEARED only while visible, so its list is rebuilt
--   (LootFrame:Open) before it is shown again.
-- - Its close animation may not run while it is hidden, so it is hidden when
--   the loot closes. The UI panel manager forgets panels that were hidden.
-- - In Edit Mode it stays where it is.
local AutoLoot = ns.Modules:Get("AutoLoot")

local Window = {}
AutoLoot.LootWindow = Window

local holder
local hidden = false
local strata

-- Out of combat, when the module starts. Clients without LootFrame (and tests
-- of other parts) get no holder, and the window is left alone.
function Window.Prepare()
	if not holder and LootFrame then
		-- A child of UIParent, so LootFrame keeps its scale and position.
		holder = CreateFrame("Frame", nil, UIParent)
		holder:Hide()
	end
end

function Window.Hide()
	local frame = LootFrame
	if hidden or not holder or frame:IsVisible() or frame.isInEditMode then
		return
	end
	strata = frame:GetFrameStrata()
	frame:SetParent(holder)
	hidden = true
end

local function restore(frame)
	frame:SetParent(UIParent)
	frame:SetFrameStrata(strata)
	hidden = false
end

-- Shows the window with the slots that are left. Before LOOT_OPENED it is not
-- open yet, and LOOT_OPENED opens it as usual.
function Window.Show()
	if not hidden then
		return
	end
	local frame = LootFrame
	restore(frame)
	if frame:IsShown() then
		frame:Open()
	end
end

-- When the module stops: a loot that is still open gets its window back with
-- the slots that are left, as after an error; no LOOT_OPENED would show it.
function Window.Release()
	if hidden and LootFrame:IsShown() then
		Window.Show()
	else
		Window.Reset()
	end
end

-- When the loot closes.
function Window.Reset()
	if not hidden then
		return
	end
	local frame = LootFrame
	if frame:IsShown() and not frame.isInEditMode then
		frame:Hide()
	end
	restore(frame)
end
