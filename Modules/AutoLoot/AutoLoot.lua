local _, ns = ...
local Bags, Bus, Compat, L = ns.Bags, ns.Bus, ns.Compat, ns.L

-- Fast autoloot. When the game auto loots, every slot is taken
-- at once, from the last to the first, one slot per server round trip: loot a
-- slot, wait for its LOOT_SLOT_CLEARED, then the next. Items that do not fit
-- are skipped and reported (LootSkipped). Blizzard's loot window stays hidden
-- meanwhile (LootWindow.lua); slots that are left, a slot that is not cleared in
-- time and a loot error show it (LootWindowShown).
--
-- The game sends LOOT_READY twice for one loot and can repeat
-- LOOT_SLOT_CLEARED and LOOT_CLOSED: repeats change nothing.
-- Looting never retries a slot: repeated LootSlot calls can disconnect.
local AutoLoot = ns.Modules:Register({
	name = "AutoLoot",
	title = L["Fast autoloot"],
	switchLabel = L["Enable fast autoloot"],
	description = L["When the game loots automatically, picks up everything at once. The loot window opens only for what cannot be picked up."],
	defaults = { enabled = true, confirmBind = true },
	mainSettings = {
		{ kind = "checkbox", key = "confirmBind", label = L["Confirm bind-on-pickup items when alone"],
			tooltip = L["Picks up items that bind when picked up without asking, unless you are in a group."] },
	},
})

-- A slot that is not cleared within this time stops looting; in game a slot
-- took about 0.4 s.
AutoLoot.SLOT_TIMEOUT = 1

-- Game errors after LootSlot that mean the server refused the slot.
local STOP_ERRORS = {
	ERR_INV_FULL = true,
	ERR_BAG_FULL = true,
	ERR_ITEM_MAX_COUNT = true,
	ERR_LOOT_ROLL_PENDING = true,
	ERR_LOOT_CANT_LOOT_THAT = true,
	ERR_LOOT_CANT_LOOT_THAT_NOW = true,
	ERR_LOOT_NO_UI = true,
	ERR_LOOT_NOTSTANDING = true,
	ERR_LOOT_STUNNED = true,
	ERR_LOOT_WHILE_INVULNERABLE = true,
}

-- The loot being taken, from its first LOOT_READY to LOOT_CLOSED:
-- { auto, queue = { slot, … }, waiting = slot, left, skipped, done }.
local loot

-- A value the client keeps secret cannot be compared or used; nil instead.
local function known(value)
	if Compat.IsSecret(value) then
		return nil
	end
	return value
end

local function showWindow(reason)
	AutoLoot.LootWindow.Show()
	ns.Debug(("Auto loot: loot window shown (%s)"):format(reason))
	Bus:Send("LootWindowShown", reason)
end

local function stop(reason)
	loot.done = true
	loot.waiting = nil
	loot.queue = {}
	showWindow(reason)
end

local function finish()
	loot.done = true
	if loot.left > 0 then
		showWindow(loot.skipped and "no room" or "locked")
	end
end

local function lootNext()
	while #loot.queue > 0 do
		local slot = table.remove(loot.queue, 1)
		-- The game's own auto loot may have taken it already.
		if Compat.GetLootSlot(slot) then
			-- Each slot is looted once, so the loot and the slot identify the wait.
			local current = loot
			current.waiting = slot
			Compat.LootSlot(slot)
			Compat.After(AutoLoot.SLOT_TIMEOUT, function()
				if loot == current and current.waiting == slot then
					stop("timeout")
				end
			end)
			return
		end
	end
	finish()
end

local function skippedEntry(info)
	return {
		kind = "skipped",
		link = info.link,
		name = info.name,
		icon = info.icon,
		quality = info.quality,
		amount = info.quantity,
	}
end

local function start(autoLoot)
	-- The first event of a loot decides; LOOT_READY repeats with LOOT_OPENED.
	if loot then
		return
	end
	if autoLoot == nil then
		autoLoot = Compat.IsAutoLootOn()
	end
	loot = { auto = autoLoot == true, queue = {}, left = 0, skipped = false, done = false }
	if not loot.auto then
		loot.done = true
		return
	end
	AutoLoot.LootWindow.Hide()
	for slot = Compat.GetNumLootItems(), 1, -1 do
		local info = Compat.GetLootSlot(slot)
		if info then
			local link = known(info.link)
			if known(info.locked) == true then
				loot.left = loot.left + 1
			elseif info.kind == "item" and link and not Bags.Fits(link, known(info.quantity) or 1) then
				loot.left = loot.left + 1
				loot.skipped = true
				Bus:Send("LootSkipped", skippedEntry(info))
			else
				-- Money and currency always fit; so does a slot the client keeps secret,
				-- and the server refuses it if it does not.
				loot.queue[#loot.queue + 1] = slot
			end
		end
	end
	ns.Debug(("Auto loot: %d slots to loot, %d left"):format(#loot.queue, loot.left))
	lootNext()
end

function AutoLoot:OnEnable()
	self.LootWindow.Prepare()
	self:OnEvent("LOOT_READY", function(_, autoLoot)
		start(autoLoot)
	end)
	self:OnEvent("LOOT_OPENED", function(_, autoLoot)
		start(autoLoot)
	end)
	self:OnEvent("LOOT_SLOT_CLEARED", function(_, slot)
		if loot and not loot.done and loot.waiting == slot then
			loot.waiting = nil
			lootNext()
		end
	end)
	self:OnEvent("UI_ERROR_MESSAGE", function(_, errorType)
		errorType = known(errorType)
		if errorType and loot and loot.waiting and STOP_ERRORS[Compat.GetGameErrorName(errorType)] then
			stop("error")
		end
	end)
	self:OnEvent("LOOT_BIND_CONFIRM", function(_, slot)
		if not loot or loot.done then
			return
		end
		if self:Get("confirmBind") and not Compat.IsInGroup() then
			Compat.ConfirmLootSlot(slot)
			-- Blizzard asks the same question in its own dialog.
			StaticPopup_Hide("LOOT_BIND")
		else
			stop("bind")
		end
	end)
	self:OnEvent("LOOT_CLOSED", function()
		loot = nil
		self.LootWindow.Reset()
	end)
end

function AutoLoot:OnDisable()
	loot = nil
	self.LootWindow.Reset()
end
