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

-- What an entry shows: { icon, name, text, red }, or nil for a currency the
-- character does not have. A capped currency shows "quantity / cap" (with a
-- seasonal cap, only the quantity, as the cap counts what was earned), red at
-- its cap.
function Bars.Describe(entry)
	if entry.kind == "currency" then
		local info = Currencies.Info(entry.id)
		if not info or not info.name or info.name == "" then
			return nil
		end
		local text = tostring(info.quantity)
		if info.max > 0 and not info.capsTotalEarned then
			text = L["%d / %d"]:format(info.quantity, info.max)
		end
		return { icon = info.icon, name = info.name, text = text, red = info.atCap }
	end
	local icon = Compat.GetItemLook(entry.id)
	local info = Compat.GetItemInfo(entry.id)
	return {
		icon = icon,
		name = info and info.name or L["Item %d"]:format(entry.id),
		text = tostring(Currencies.ItemCount(entry.id)),
		red = false,
	}
end

-- The bar frames, one per bar of the set in use, by place in the set.
Bars.slots = {}

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
	self:OnEvent("PLAYER_REGEN_ENABLED", function()
		if self.waiting then
			self:Refresh()
		end
	end)
end

function Bars:OnDisable()
	self.on = false
	for _, slot in ipairs(self.slots) do
		slot:SetBar(nil)
	end
end
