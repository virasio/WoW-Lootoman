local _, ns = ...
local Compat, Currencies, L = ns.Compat, ns.Currencies, ns.L

-- Bars of currencies and of items in the bags, anywhere on the screen. They
-- come in named sets shared by every profile (Sets.lua); each profile uses one.
-- Each bar of the set in use gets a frame (BarFrame.lua), placed with Edit
-- Mode; frames are made out of combat and kept for later bars, because
-- LibEditMode cannot forget a frame. The bars follow their set, the profile,
-- the currencies and the bags.
local Bars = ns.Modules:Register({
	name = "Bars",
	title = L["Currency bars"],
	switchLabel = L["Enable currency bars"],
	description = L["Bars of currencies and of items in your bags, anywhere on the screen."],
	defaults = {
		enabled = true,
		-- The named set of bars the profile uses (Sets.lua).
		set = "Default",
	},
})

-- A bar's entries: its own, or the backpack's currencies until it has some.
function Bars.Entries(bar)
	if bar.entries then
		return bar.entries
	end
	local entries = {}
	for index, currencyID in ipairs(Currencies.Backpack()) do
		entries[index] = { kind = "currency", id = currencyID }
	end
	return entries
end

-- Gives a bar its own entries before they change.
function Bars.OwnEntries(bar)
	bar.entries = bar.entries or Bars.Entries(bar)
	return bar.entries
end

-- What an item entry counts (entry.count): the bags (the default, as nil), the
-- banks or both. The same item can stand on a bar once for each.
Bars.COUNTS = { "bags", "banks", "all" }
Bars.COUNT_NAMES = { banks = L["%s, in the banks"], all = L["%s, everywhere"] }

-- The money entry's icon in the editor's lists; on a bar, money is its coins.
Bars.MONEY_ICON = [[Interface\Icons\INV_Misc_Coin_01]]

-- A stack: the first member with a count above zero, or with showEmpty its
-- last (least important) one; nil when every member is at zero.
local function describeStack(entry)
	local members, shown = {}, nil
	for _, member in ipairs(entry.members or {}) do
		local look = Bars.Describe(member)
		if look then
			members[#members + 1] = look
			if not shown and look.amount > 0 then
				shown = #members
			end
		end
	end
	if #members == 0 then
		return nil
	end
	if not shown and entry.showEmpty then
		shown = #members
	end
	local top = members[shown or #members]
	return {
		icon = top.icon, listIcon = top.icon or top.listIcon, name = L["Stack: %s"]:format(top.name), memberName = top.name,
		text = top.text, red = top.red, count = top.count, amount = top.amount,
		members = members, shown = shown, hidden = shown == nil,
	}
end

-- What an entry shows: { icon, name, text, red, amount }, or nil for a
-- currency the character does not have. A capped currency shows "quantity /
-- cap" (with a seasonal cap, only the quantity, as the cap counts what was
-- earned), red at its cap. Money shows in gold, silver and copper coins, as in
-- the bags, and has no icon on the bar. A stack shows one member (and lists
-- them all, in members, the shown one at shown); hidden when it shows none.
function Bars.Describe(entry)
	if entry.kind == "stack" then
		return describeStack(entry)
	elseif entry.kind == "money" then
		local money = Compat.GetMoney()
		return { name = L["Money"], text = GetMoneyString(money, true), red = false, listIcon = Bars.MONEY_ICON, amount = money }
	elseif entry.kind == "currency" then
		local info = Currencies.Info(entry.id)
		if not info or not info.name or info.name == "" then
			return nil
		end
		local text = tostring(info.quantity)
		if info.max > 0 and not info.capsTotalEarned then
			text = L["%d / %d"]:format(info.quantity, info.max)
		end
		return { icon = info.icon, name = info.name, text = text, red = info.atCap, amount = info.quantity }
	end
	local icon = Compat.GetItemLook(entry.id)
	local info = Compat.GetItemInfo(entry.id)
	if not info then
		-- Asking for it makes the client load it (GET_ITEM_INFO_RECEIVED).
		Bars.loading[entry.id] = true
	end
	local name = info and info.name or L["Item %d"]:format(entry.id)
	local count = entry.count or "bags"
	local amount = Currencies.ItemCount(entry.id, count)
	return {
		icon = icon,
		-- Two entries of one item that count different places tell apart.
		name = Bars.COUNT_NAMES[count] and Bars.COUNT_NAMES[count]:format(name) or name,
		text = tostring(amount),
		red = false,
		count = count,
		amount = amount,
	}
end

-- The bar frames, one per bar of the set in use, by place in the set.
Bars.slots = {}

-- Items described before the client had loaded them, by item ID: their names
-- (in the editor, the overflow list, the questions) follow once they arrive.
Bars.loading = {}

-- While the module is on (set in OnEnable, where IsActive is not true yet).
Bars.on = false

function Bars:Refresh()
	if not self.on then
		return
	end
	if Compat.InCombat() then
		self.waiting = true
		return
	end
	self.waiting = false
	local set = self.Sets.Get(self.Sets.Current())
	for index, bar in ipairs(set.bars) do
		local slot = self.slots[index] or self.BarFrame.Create(self, index)
		self.slots[index] = slot
		slot:SetBar(bar)
	end
	for index = #set.bars + 1, #self.slots do
		self.slots[index]:SetBar(nil)
	end
end

-- Counts change; the bars' layout stays.
function Bars:RefreshCounts()
	for _, slot in ipairs(self.slots) do
		if slot.bar then
			slot:Layout()
		end
	end
end

function Bars:OnEnable()
	Currencies.Watch()
	self.on = true
	self:Refresh()
	self:On("BarSetChanged", function(_, name)
		if name == self.Sets.Current() then
			self:Refresh()
		end
	end)
	self:On("SettingChanged", function(_, module, key)
		if module == self.name and key == "set" then
			self:Refresh()
		end
	end)
	self:On("ProfileChanged", function()
		self:Refresh()
	end)
	self:On("CurrenciesChanged", function()
		self:RefreshCounts()
	end)
	self:On("InventoryChanged", function()
		self:RefreshCounts()
	end)
	self:OnEvent("PLAYER_MONEY", function()
		self:RefreshCounts()
	end)
	-- The bank's contents change apart from the bags.
	for _, event in ipairs({ "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_CLOSED" }) do
		self:OnEvent(event, function()
			self:RefreshCounts()
		end)
	end
	self:OnEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
		if success and Bars.loading[itemID] then
			Bars.loading[itemID] = nil
			self:RefreshCounts()
			if self.Editor then
				self.Editor.Refresh()
			end
		end
	end)
	self:OnEvent("PLAYER_REGEN_ENABLED", function()
		if self.waiting then
			self:Refresh()
		end
	end)
end

function Bars:OnDisable()
	self.on = false
	for _, slot in ipairs(self.slots) do
		-- Edit Mode does not end the preview of a module that is off.
		slot:SetPreview(false)
		slot:SetBar(nil)
	end
end
