local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The junk window: one window, of one size, in three modes, its title saying
-- which. The bags as an item grid (ItemGrid.lua) in the first two:
--   toss   Throw Away Junk: dragging an item out deletes it; every move marks
--          for good (Toss.lua);
--   sell   Sell Junk, only while a merchant is open: the merchant's prices,
--          moves for this sale only (with Shift for good), Sell Junk at the
--          bottom (SellWindow.lua);
--   lists  Junk List: the marks in two tabs, Junk and Not Junk, with the
--          field to add, Clear List, Share and Import (Settings/JunkList.lua).
-- Each mode is a part that registers here (Window.Register) and owns what
-- it adds to the window.
--
-- Where it opens (Window.Open):
--   "auto"     /ltm junk, the minimap icon's menu, the bag button and the
--              loot feed's warning: to sell beside the merchant while one is
--              open, else to throw away in the middle of the screen;
--   "loot"     the loot window's button: to throw away beside the loot window;
--   "merchant" the sell button: to sell beside the merchant;
--   "options"  Edit the Junk List: the lists beside the game's options, over
--              them.
-- The gear left of the close button switches to the lists and back to the
-- bags (selling at a merchant, throwing away elsewhere); the window stays
-- where it is. A merchant opening while it throws away switches it to
-- selling, and the merchant closing takes it back to throwing away. It closes
-- with what it was opened beside (the loot, the merchant), in whatever mode.
local Junk = ns.Modules:Get("Junk")
local Window = {}
Junk.Window = Window

Window.NAME = "LootomanJunkWindow"
Window.GAP = 4
-- The game's own gear (UIPanelIconDropdownButtonTemplate), and an older one
-- for a client without that atlas.
Window.GEAR = "questlog-icon-setting"
Window.GEAR_FALLBACK = [[Interface\Buttons\UI-OptionsButton]]
-- Room over the sections for the loot's best item, kept in every mode so the
-- window is of one size.
Window.TOP = 18

local grid
local active = false
-- The mode shown, and what the window was opened beside: "loot",
-- "merchant", "options" or nil.
local mode, anchor
local parts = {}

-- A mode: { title, kind ("toss" or "sell"), gridMode, hidesSections,
-- dropOutside, onDropOutside, checked, checkedNote, onRefresh, build(grid),
-- enter(grid, anchor), leave(grid), place(frame) }. build runs once, when the
-- window is made; enter and leave as the mode comes and goes.
function Window.Register(name, part)
	parts[name] = part
	if grid and part.build then
		part.build(grid)
	end
end

function Window.Grid()
	return grid
end

-- The mode shown, or the one the window last showed.
function Window.Mode()
	return mode
end

function Window.Anchor()
	return anchor
end

local function atMerchant()
	return MerchantFrame ~= nil and Compat.IsInteracting("Merchant") == true
end

-- The bags' mode for here and now: selling at a merchant, else throwing away.
local function bagsMode()
	return atMerchant() and "sell" or "toss"
end

local function setMode(name)
	local old = parts[mode]
	if old and old.leave then
		old.leave(grid)
	end
	mode = name
	local part = parts[name]
	grid:SetKind(part.kind or "toss", part.gridMode)
	grid:ShowSections(not part.hidesSections)
	local options = grid.options
	options.dropOutside, options.onDropOutside = part.dropOutside, part.onDropOutside
	options.checked, options.checkedNote = part.checked, part.checkedNote
	options.onRefresh = part.onRefresh
	grid.frame:SetTitle(part.title)
	if part.enter then
		part.enter(grid, anchor)
	end
end

-- Switches the shown window to another mode, where it is.
function Window.SetMode(name)
	if not grid or not parts[name] or name == mode then
		return
	end
	setMode(name)
	if grid:IsShown() then
		grid:Refresh()
	end
end

-- The gear: to the lists, and back to the bags.
function Window.SwitchLists()
	Window.SetMode(mode == "lists" and bagsMode() or "lists")
end

local function placeByLoot(frame)
	local right, screen = LootFrame:GetRight(), UIParent:GetRight()
	if right and screen and right + Junk.ItemGrid.WIDTH + Window.GAP > screen then
		frame:SetPoint("TOPRIGHT", LootFrame, "TOPLEFT", -Window.GAP, 0)
	else
		frame:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", Window.GAP, 0)
	end
end

local function place()
	local frame = grid.frame
	frame:ClearAllPoints()
	if anchor == "loot" then
		placeByLoot(frame)
	elseif anchor == "merchant" then
		frame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", Window.GAP, 0)
	elseif anchor == "options" and parts.lists.place then
		parts.lists.place(frame)
	else
		frame:SetPoint("CENTER")
	end
end

-- Opens the window for a place (above); false when it cannot: junk
-- management is off, there is no merchant to sell to, or no lists.
function Window.Open(where)
	if not active or not grid then
		return false
	end
	local newMode, newAnchor
	if where == "options" then
		newMode, newAnchor = "lists", "options"
	elseif where == "loot" then
		-- Visible, not only shown: fast autoloot keeps a shown window in a hidden holder.
		newMode = "toss"
		newAnchor = LootFrame ~= nil and LootFrame:IsVisible() and "loot" or nil
	elseif where == "merchant" then
		if not atMerchant() then
			return false
		end
		newMode, newAnchor = "sell", "merchant"
	else
		newMode = bagsMode()
		newAnchor = newMode == "sell" and "merchant" or nil
	end
	if not parts[newMode] then
		return false
	end
	anchor = newAnchor
	setMode(newMode)
	place()
	-- Over the game's options window (HIGH) when opened from it.
	grid.frame:SetFrameStrata(anchor == "options" and "DIALOG" or "HIGH")
	grid:Open()
	return true
end

-- The buttons: the window opens for its place, or closes.
function Window.Toggle(where)
	if grid and grid:IsShown() then
		Window.Close()
	else
		Window.Open(where)
	end
end

function Window.Close()
	if grid then
		grid:Close()
	end
end

local function createGear()
	local gear = CreateFrame("Button", nil, grid.frame)
	gear:SetSize(18, 18)
	gear:SetPoint("RIGHT", grid.close, "LEFT", -2, 0)
	-- At the close button's level: lower, the panel's title bar covers it.
	gear:SetFrameLevel(grid.close:GetFrameLevel())
	if Compat.HasAtlas(Window.GEAR) then
		gear:SetNormalAtlas(Window.GEAR)
		gear:SetHighlightAtlas(Window.GEAR, "ADD")
	else
		gear:SetNormalTexture(Window.GEAR_FALLBACK)
		gear:SetHighlightTexture(Window.GEAR_FALLBACK, "ADD")
	end
	gear:SetScript("OnClick", Window.SwitchLists)
	gear:SetScript("OnEnter", function()
		GameTooltip:SetOwner(gear, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, mode == "lists" and L["Back to the bags"] or L["The junk list"])
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	grid.gear = gear
end

local function build()
	grid = Junk.ItemGrid.Create({
		name = Window.NAME,
		title = "",
		kind = "toss",
		top = Window.TOP,
		onHide = function()
			local part = parts[mode]
			if part and part.leave then
				part.leave(grid)
			end
			anchor = nil
			-- Shown again, it enters its mode afresh.
			mode = nil
		end,
	})
	createGear()
	for _, part in pairs(parts) do
		if part.build then
			part.build(grid)
		end
	end
end

ns.Slash.Register("junk", function()
	if not Window.Open("auto") then
		ns.Print(L["Junk management is off. Turn it on in the options."])
	end
end, L["/ltm junk: open the junk window"])

Junk.AddPart({
	Enable = function()
		if not grid then
			build()
		end
		grid:Attach()
		active = true
		Junk.ListenEvent("LOOT_CLOSED", function()
			if anchor == "loot" then
				Window.Close()
			end
		end)
		Junk.ListenEvent("MERCHANT_SHOW", function()
			if grid:IsShown() and mode == "toss" then
				Window.SetMode("sell")
			end
		end)
		Junk.ListenEvent("MERCHANT_CLOSED", function()
			if anchor == "merchant" then
				Window.Close()
			elseif grid:IsShown() and mode == "sell" then
				Window.SetMode("toss")
			end
		end)
		-- Another part of Lootoman asks for the window (the loot feed's warning,
		-- the minimap icon's menu).
		Junk.Listen("OpenJunkWindow", function()
			Window.Open("auto")
		end)
	end,
	Disable = function()
		active = false
		Window.Close()
	end,
})
