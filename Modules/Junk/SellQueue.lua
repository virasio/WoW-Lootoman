local _, ns = ...
local Compat, Inventory, L, SelfTest = ns.Compat, ns.Inventory, ns.L, ns.SelfTest

-- Selling junk: a controller without frames, as fast autoloot is. The sell
-- button and the junk window only start it and show its state.
--
-- One stack every PACE seconds while a merchant is open (selling the next one
-- waits until the server has taken the last: its slot no longer holds it).
-- C_Container.UseContainerItem sells only at an open merchant and uses the item
-- anywhere else, so right before every sale the merchant must be open, and the
-- slot must still hold the listed item, not locked. A stack that stopped being
-- junk for sale meanwhile (moved out of the junk, its bag left out of junk
-- selling, put into an equipment set) is skipped.
--
-- States: "idle" (nothing sold yet), "selling", "waiting" (for the server to
-- take the last stack), "stopped" (with a reason) and "done". Reasons:
-- "closed" (the merchant's window closed), "tradeTimer" (the game asks whether
-- to sell an item that can still be traded within the group), "changed" (a
-- slot no longer holds its item), "refused" (the merchant did not take one),
-- "noAnswer" (the server did not answer in time).
--
-- Each sale ends with a chat line. A merchant can buy back only the last
-- BUYBACK stacks sold to it, so past that in one visit the chat line says so.
--
-- A sale cut short with stacks left says so in red in the chat and in a
-- dialog with OK (SaleNotice.lua), and keeps what was left for CARRY seconds: at a
-- merchant within that time those items are this sale's (Carried), so the
-- junk window lists them to sell and the sell button sells them, also an item
-- that is not junk and was picked for that sale only. A sale that ends with
-- nothing left, or the time passing, forgets them. Kept in memory only.
local Junk = ns.Modules:Get("Junk")
local SellQueue = {}
Junk.SellQueue = SellQueue

SellQueue.PACE = 0.2
-- How long what a cut-short sale left is kept, in seconds.
SellQueue.CARRY = 60
SellQueue.TIMEOUT = 5
-- BUYBACK_ITEMS_PER_PAGE in Blizzard's MerchantFrame.lua.
SellQueue.BUYBACK = 12

local REASONS = {
	closed = L["the merchant's window closed"],
	tradeTimer = L["the game asks about an item you can still trade"],
	changed = L["an item moved in the bags"],
	refused = L["the merchant did not take an item"],
	noAnswer = L["the server did not answer"],
}

local state, reason = "idle", nil
-- The sale's own decisions (moves for this sale only), kept from the window,
-- which closes as the sale starts.
local decisions
-- What a sale cut short left: { at, items = { [itemID] = true }, count }.
local left
-- fn(state, reason) after every change of state.
local watchers = {}
local queue, current, sale, last
-- Stacks sold to the merchant whose window is open, and whether the buyback
-- warning was shown for this visit.
local visit, warned = 0, false
-- Each run of timers belongs to one sale; a stopped sale's timers do nothing.
local run = 0

-- The stacks a stopped sale did not sell: the one being sold, if the server
-- did not take it, and those still waiting, that are still in their slots.
local function remaining()
	local items, count = {}, 0
	local function add(entry)
		if entry and Inventory.StillThere(entry.item) then
			items[entry.item.itemID] = true
			count = count + 1
		end
	end
	add(current)
	for _, entry in ipairs(queue or {}) do
		add(entry)
	end
	return items, count
end

local function finish(newState, why)
	if newState == "stopped" then
		local items, count = remaining()
		left = count > 0 and { at = Compat.GetTime(), items = items, count = count } or nil
	elseif newState == "done" then
		left = nil
	end
	state, reason = newState, why
	last = { count = sale.count, money = sale.money, items = sale.items, reason = why }
	queue, current = nil, nil
	if sale.count > 0 then
		ns.Print(L["Sold %d items for %s."]:format(sale.count, GetMoneyString(sale.money, true)))
		visit = visit + sale.count
		if visit > SellQueue.BUYBACK and not warned then
			warned = true
			ns.Print(L["Only the last 12 sold items can be bought back."])
		end
	end
	if newState == "stopped" then
		ns.Print(L["Selling stopped: %s."]:format(REASONS[why] or why))
		if left then
			local warning = L["Not everything was sold: %d left. Back at a merchant within a minute, they are in To Sell."]:format(left.count)
			ns.Print("|cffff2020" .. warning .. "|r")
			if Junk.SaleNotice then
				Junk.SaleNotice.Show(warning)
			end
		end
	end
	for _, watch in ipairs(watchers) do
		xpcall(function()
			watch(state, reason)
		end, Compat.ReportError)
	end
end

local step

-- The last stack is gone from its slot: sold.
local function sold()
	local item = current.item
	sale.count = sale.count + 1
	sale.money = sale.money + current.price
	sale.items[#sale.items + 1] = { link = item.link, count = item.count, money = current.price }
	current = nil
end

-- Whether the slot of the stack being sold no longer holds it.
local function gone()
	local item = current.item
	local now = Compat.GetBagItem(item.bag, item.slot)
	return not now or now.itemID ~= item.itemID or Compat.GetBagItemFacts(item.bag, item.slot).guid ~= Inventory.Facts(item).guid
end

function SellQueue.Stop(why)
	if state == "selling" or state == "waiting" then
		run = run + 1
		-- The server may have taken the last stack before the stop.
		if current and gone() then
			sold()
		end
		finish("stopped", why)
	end
end

local function check(myRun, since)
	if myRun ~= run or state ~= "waiting" then
		return
	end
	local item = current.item
	local now = Compat.GetBagItem(item.bag, item.slot)
	if gone() then
		sold()
		state = "selling"
		Compat.After(SellQueue.PACE, function()
			step(myRun)
		end)
	elseif not now.locked then
		run = run + 1
		finish("stopped", "refused")
	elseif Compat.GetTime() - since >= SellQueue.TIMEOUT then
		run = run + 1
		finish("stopped", "noAnswer")
	else
		Compat.After(SellQueue.PACE, function()
			check(myRun, since)
		end)
	end
end

step = function(myRun)
	if myRun ~= run or state ~= "selling" then
		return
	end
	if not Compat.IsInteracting("Merchant") then
		run = run + 1
		finish("stopped", "closed")
		return
	end
	-- A stack that is no longer junk, or is protected now, is left out; a stack
	-- that moved or changed stops the sale.
	local entry
	repeat
		entry = table.remove(queue, 1)
		if entry and not Inventory.StillThere(entry.item) then
			run = run + 1
			finish("stopped", "changed")
			return
		end
	until not entry or Junk.Sections.StillForSale(entry.item, decisions)
	if not entry then
		run = run + 1
		finish("done")
		return
	end
	current = entry
	state = "waiting"
	Compat.UseBagItem(entry.item.bag, entry.item.slot)
	local since = Compat.GetTime()
	Compat.After(SellQueue.PACE, function()
		check(myRun, since)
	end)
end

-- A copy of a sale's decisions, so the window's own can go.
local function copy(thisSale)
	if not thisSale then
		return nil
	end
	local kept = { junk = {}, keep = {} }
	for key, value in pairs(thisSale.junk or {}) do
		kept.junk[key] = value
	end
	for key, value in pairs(thisSale.keep or {}) do
		kept.keep[key] = value
	end
	return kept
end

-- Sells the entries (Sections entries: item and price), in order, by the
-- sale's own decisions too (thisSale, from the junk window). False when a
-- sale is going on, or no merchant is open.
function SellQueue.Start(entries, thisSale)
	if state == "selling" or state == "waiting" or not Compat.IsInteracting("Merchant") then
		return false
	end
	queue = {}
	for index, entry in ipairs(entries) do
		queue[index] = entry
	end
	if #queue == 0 then
		return false
	end
	run = run + 1
	decisions = copy(thisSale)
	sale = { count = 0, money = 0, items = {} }
	state, reason = "selling", nil
	for _, watch in ipairs(watchers) do
		xpcall(function()
			watch(state, reason)
		end, Compat.ReportError)
	end
	step(run)
	return true
end

-- Calls fn(state, reason) whenever the sale's state changes.
function SellQueue.Watch(fn)
	watchers[#watchers + 1] = fn
end

function SellQueue.State()
	return state, reason
end

-- The last sale: { count, money, items, reason }, or nil.
function SellQueue.LastResult()
	return last
end

-- What a sale cut short left, as this sale's decisions ({ junk, keep }),
-- while CARRY seconds have not passed; nil else.
function SellQueue.Carried()
	if left and Compat.GetTime() - left.at > SellQueue.CARRY then
		left = nil
	end
	if not left then
		return nil
	end
	local carried = { junk = {}, keep = {} }
	for itemID in pairs(left.items) do
		carried.junk[itemID] = true
	end
	return carried
end

SelfTest.AddReport(function()
	if not last then
		return "Last sale: none this session"
	end
	return ("Last sale: %d stacks, %d copper, %s"):format(last.count, last.money, last.reason or "done")
end)

Junk.AddPart({
	Enable = function()
		Junk.ListenEvent("MERCHANT_SHOW", function()
			visit, warned = 0, false
		end)
		Junk.ListenEvent("MERCHANT_CLOSED", function()
			SellQueue.Stop("closed")
		end)
		Junk.ListenEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL", function()
			SellQueue.Stop("tradeTimer")
		end)
	end,
	Disable = function()
		SellQueue.Stop("closed")
	end,
})
