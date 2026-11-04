local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The sell window: the bags as an item grid (ItemGrid.lua), laid out like the
-- toss window, with what a merchant buys: the junk on top, everything else
-- below, by the merchant's price. It opens from the sell-junk button (Shift-
-- click), to the right of the merchant's window, and closes with it.
--
-- Sell junk, at the bottom, sells the upper section, less the junk in bags the
-- game keeps out of junk selling (shown darker), and closes the window; the
-- sale goes on with the window closed. A right click moves an item
-- between the sections (ItemGrid.lua). The bottom also says so when there is
-- more junk than the merchant can buy back.
local Junk = ns.Modules:Get("Junk")
local SellWindow = {}
Junk.SellWindow = SellWindow

SellWindow.NAME = "LootomanSellWindow"
SellWindow.GAP = 4

local grid
local active = false

-- The upper section's junk that Sell junk sells.
local function saleOf(built)
	local list = {}
	for _, entry in ipairs(built.junk.entries) do
		if not entry.kept then
			list[#list + 1] = entry
		end
	end
	return list
end

local function updateFooter()
	if not grid or not grid.built then
		return
	end
	local sale = saleOf(grid.built)
	local selling = Junk.SellQueue.State() == "selling" or Junk.SellQueue.State() == "waiting"
	grid.sellButton:SetEnabled(#sale > 0 and not selling)
	grid.warning:SetShown(#sale > Junk.SellQueue.BUYBACK)
end

local function footer(owner, frame)
	owner.sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	owner.sellButton:SetSize(120, 22)
	owner.sellButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	owner.sellButton:SetText(L["Sell junk"])
	-- The sale goes on without the window, which is done once the junk is picked.
	owner.sellButton:SetScript("OnClick", function()
		Junk.SellQueue.Start(saleOf(owner.built))
		owner:Close()
	end)
	owner.warning = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	owner.warning:SetPoint("LEFT", frame, "LEFT", 0, 0)
	owner.warning:SetPoint("RIGHT", owner.sellButton, "LEFT", -8, 0)
	owner.warning:SetJustifyH("LEFT")
	owner.warning:SetText(L["Only the last 12 sold items can be bought back."])
end

function SellWindow.Open()
	if not active or not grid or not Compat.IsInteracting("Merchant") then
		return
	end
	grid.frame:ClearAllPoints()
	grid.frame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", SellWindow.GAP, 0)
	grid:Open()
end

function SellWindow.Grid()
	return grid
end

Junk.AddPart({
	Enable = function()
		if not MerchantFrame then
			return
		end
		if not grid then
			grid = Junk.ItemGrid.Create({
				name = SellWindow.NAME,
				title = L["Sell junk"],
				kind = "sell",
				onRefresh = updateFooter,
				footer = footer,
			})
			Junk.SellQueue.Watch(updateFooter)
		end
		grid:Attach()
		active = true
		Junk.ListenEvent("MERCHANT_CLOSED", function()
			grid:Close()
		end)
	end,
	Disable = function()
		active = false
		if grid then
			grid:Close()
		end
	end,
})
