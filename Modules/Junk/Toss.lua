local _, ns = ...
local Compat, Inventory, L, Prices, Text = ns.Compat, ns.Inventory, ns.L, ns.Prices, ns.Text

-- The toss window: the bags as an item grid (ItemGrid.lua), junk on top, to
-- throw things away. It opens from the toss button, next to the loot window
-- (right of it, or left when there is no room) and closes with the loot; or
-- with /lootoman toss, in the middle of the screen.
--
-- Dragging an item out of the window deletes its stack: a gray one at once;
-- any other after a confirmation in Lootoman's own dialog, which for rare and
-- better items also asks for the game's confirmation word, as the game does.
-- An item whose quality the client has not loaded yet counts as rare.
-- (The game's own question comes only from dropping an item onto the world,
-- and showing Blizzard's dialogs from addon code would taint them.) A right
-- click moves an item between the sections (ItemGrid.lua).
--
-- Deleting is a pick up and a delete in the same mouse action (the release of
-- the drag, or the click on Delete), one item per action, as the game requires
-- (Blizzard's own action bar code deletes in OnDragStop too); DeleteCursorItem
-- deletes whatever the cursor holds. So
-- the cursor must be empty first, the slot must still hold the listed item,
-- and after the pick up the cursor must hold exactly that slot; otherwise the
-- cursor is cleared and nothing is deleted.
local Junk = ns.Modules:Get("Junk")
local Toss = {}
Junk.Toss = Toss

Toss.NAME = "LootomanTossWindow"
Toss.CONFIRM_NAME = "LootomanDeleteConfirm"
-- Enum.ItemQuality: from Rare on, the game asks for its confirmation word,
-- except for heirlooms.
Toss.RARE, Toss.HEIRLOOM = 3, 7
Toss.GAP = 4

local grid, confirm
local active, fromLoot = false, false
-- The most valuable item left in the loot while the window is by it.
---@type { link: string, count: number, worth: number }?
local lootBest

local function describe(item)
	return item.count > 1 and L["%s ×%d"]:format(item.link, item.count) or item.link
end

-- Deletes an entry's stack now, after the checks above. True when it was deleted.
function Toss.DeleteNow(entry)
	local item = entry.item
	if not Compat.IsCursorEmpty() then
		ns.Print(L["Put down what the cursor holds first; nothing was deleted."])
		return false
	end
	if not Inventory.StillThere(item) then
		ns.Print(L["This item has moved or changed; nothing was deleted."])
		return false
	end
	-- Read again: a question may have been open while the item went into an
	-- equipment set.
	local facts = Compat.GetBagItemFacts(item.bag, item.slot)
	if facts.equipmentSet then
		ns.Print(L["This item is now in an equipment set; nothing was deleted."])
		return false
	end
	Compat.PickupBagItem(item.bag, item.slot)
	local bag, slot = Compat.GetCursorBagSlot()
	if bag ~= item.bag or slot ~= item.slot then
		Compat.ClearCursor()
		ns.Print(L["This item has moved or changed; nothing was deleted."])
		return false
	end
	Compat.DeleteCursorItem()
	ns.Print(L["Deleted %s."]:format(describe(item)))
	return true
end

-- Whether deleting the item asks for the typed word: rare and better, and an
-- item of unknown quality.
function Toss.NeedsWord(item)
	return item.quality == nil or (item.quality >= Toss.RARE and item.quality ~= Toss.HEIRLOOM)
end

local function confirmWord()
	return Compat.GetGlobalString("DELETE_ITEM_CONFIRM_STRING") or "DELETE"
end

local function wordMatches(text)
	return Text.FoldCase(text or "") == Text.FoldCase(confirmWord())
end

local function updateConfirm()
	confirm.delete:SetEnabled(not confirm.needsWord or wordMatches(confirm.word:GetText()))
end

local function accept()
	if confirm.entry and confirm.delete:IsEnabled() then
		local entry = confirm.entry
		confirm:Hide()
		Toss.DeleteNow(entry)
	end
end

local function createConfirm()
	local frame = CreateFrame("Frame", Toss.CONFIRM_NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(340, 150)
	frame:SetPoint("CENTER", 0, 120)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetTitle(L["Delete"])
	-- Escape closes it as it closes the game's own windows (see the look window).
	table.insert(UISpecialFrames, Toss.CONFIRM_NAME)
	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.text:SetPoint("TOP", 0, -36)
	frame.text:SetWidth(300)
	frame.word = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.word:SetSize(140, 22)
	frame.word:SetPoint("TOP", frame.text, "BOTTOM", 0, -10)
	frame.word:SetAutoFocus(false)
	frame.word:SetScript("OnTextChanged", updateConfirm)
	-- Enter is a key press, so it may delete as the button does.
	frame.word:SetScript("OnEnterPressed", accept)
	frame.word:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	frame.delete = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.delete:SetSize(120, 22)
	frame.delete:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 14)
	frame.delete:SetText(L["Delete"])
	frame.delete:SetScript("OnClick", accept)
	frame.cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.cancel:SetSize(120, 22)
	frame.cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 14)
	frame.cancel:SetText(CANCEL)
	frame.cancel:SetScript("OnClick", function()
		frame:Hide()
	end)
	frame:SetScript("OnHide", function()
		frame.entry = nil
	end)
	return frame
end

-- Asks before deleting an item above gray.
function Toss.Confirm(entry)
	confirm = confirm or createConfirm()
	confirm.entry = entry
	confirm.needsWord = Toss.NeedsWord(entry.item)
	if confirm.needsWord then
		confirm.text:SetText(L["Delete %s? Type “%s” to confirm."]:format(describe(entry.item), confirmWord()))
	else
		confirm.text:SetText(L["Delete %s?"]:format(describe(entry.item)))
	end
	confirm.word:SetText("")
	confirm.word:SetShown(confirm.needsWord)
	updateConfirm()
	confirm:Show()
	if confirm.needsWord then
		confirm.word:SetFocus()
	end
end

-- An item dropped outside the window: only a gray one goes without a question.
function Toss.Delete(entry)
	if entry.item.quality == ns.Rules.Junk.POOR then
		Toss.DeleteNow(entry)
	else
		Toss.Confirm(entry)
	end
end

local function place(nextToLoot)
	local frame = grid.frame
	frame:ClearAllPoints()
	if not nextToLoot then
		frame:SetPoint("CENTER")
		return
	end
	local right, screen = LootFrame:GetRight(), UIParent:GetRight()
	if right and screen and right + Junk.ItemGrid.WIDTH + Toss.GAP > screen then
		frame:SetPoint("TOPRIGHT", LootFrame, "TOPLEFT", -Toss.GAP, 0)
	else
		frame:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", Toss.GAP, 0)
	end
end

-- The most valuable item left in the open loot window, by what it is worth
-- as the window weighs items (Prices.Worth): { link, count, worth }, or nil.
-- Junk worth less is marked, so the player sees what to give up for it.
function Toss.BestInLoot()
	local best
	for slot = 1, Compat.GetNumLootItems() do
		local info = Compat.GetLootSlot(slot)
		-- A value the client keeps secret cannot be weighed: that slot is left out.
		if info and info.kind == "item" and not Compat.IsSecret(info.link) and not Compat.IsSecret(info.quantity)
			and type(info.link) == "string" then
			local count = type(info.quantity) == "number" and info.quantity > 0 and info.quantity or 1
			local worth = Prices.Worth({ link = info.link, count = count })
			if not best or worth > best.worth then
				best = { link = info.link, count = count, worth = worth }
			end
		end
	end
	return best
end

-- The line over the sections, and the marks, for the loot of now; none when
-- nothing left in the loot has a price.
local function showBest()
	local best = fromLoot and Toss.BestInLoot() or nil
	if best and best.worth <= 0 then
		best = nil
	end
	lootBest = best
	if best and grid.lootLine then
		grid.lootLine:SetText(L["In the loot: %s, worth %s"]:format(best.link, GetMoneyString(best.worth, true)))
	end
	if grid.lootLine then
		grid.lootLine:SetShown(best ~= nil)
	end
end

-- Opens the window: with nextToLoot, next to the loot window when it is
-- visible (and it then closes with the loot); else in the middle of the screen.
function Toss.Open(nextToLoot)
	if not active or not grid then
		return
	end
	-- Visible, not only shown: fast autoloot keeps a shown window in a hidden holder.
	fromLoot = nextToLoot == true and LootFrame ~= nil and LootFrame:IsVisible()
	place(fromLoot)
	showBest()
	grid:Open()
end

-- The toss buttons: the window opens (next to the loot window with
-- nextToLoot, from the loot window's button; else in the middle of the
-- screen, from the bag button), or closes.
function Toss.Toggle(nextToLoot)
	if grid and grid:IsShown() then
		grid:Close()
	else
		Toss.Open(nextToLoot)
	end
end

function Toss.Grid()
	return grid
end

ns.Slash.Register("toss", function()
	if active then
		Toss.Open(false)
	else
		ns.Print(L["Junk management is off. Turn it on in the options."])
	end
end, L["/lootoman toss: open the window to throw away junk"])

Junk.AddPart({
	Enable = function()
		grid = grid or Junk.ItemGrid.Create({
			name = Toss.NAME,
			title = L["Throw Away Junk"],
			kind = "toss",
			dropOutside = L["Drag it out of the window to delete it."],
			onDropOutside = Toss.Delete,
			-- Room for the loot's best item over the sections.
			top = 18,
			checked = function(entry)
				return lootBest ~= nil and entry.decision.junk and entry.price < lootBest.worth
			end,
			checkedNote = L["Worth less than what is left in the loot."],
			onHide = function()
				if confirm then
					confirm:Hide()
				end
			end,
		})
		if not grid.lootLine then
			grid.lootLine = grid.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			grid.lootLine:SetPoint("TOPLEFT", Junk.ItemGrid.SIDE, -Junk.ItemGrid.TOP)
			grid.lootLine:SetPoint("TOPRIGHT", -Junk.ItemGrid.SIDE, -Junk.ItemGrid.TOP)
			grid.lootLine:SetJustifyH("LEFT")
			grid.lootLine:Hide()
		end
		grid:Attach()
		active = true
		Junk.ListenEvent("LOOT_CLOSED", function()
			if fromLoot then
				grid:Close()
			end
		end)
		-- An item taken from the loot: the best of what is left.
		Junk.ListenEvent("LOOT_SLOT_CLEARED", function()
			if fromLoot and grid:IsShown() then
				showBest()
				grid:Refresh()
			end
		end)
	end,
	Disable = function()
		active = false
		if grid then
			grid:Close()
		end
		if confirm then
			confirm:Hide()
		end
	end,
})
