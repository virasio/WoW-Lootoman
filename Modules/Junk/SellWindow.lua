local _, ns = ...
local L = ns.L

-- Selling, the junk window's second mode (Window.lua), only while a merchant
-- is open: the bags as an item grid (ItemGrid.lua), laid out as for throwing
-- away, with what a merchant buys, by the merchant's price. A move in it is
-- for this sale only, and for good with Shift held (ItemGrid.lua).
--
-- Sell Junk, at the bottom, sells the junk group, less the junk in bags the
-- game keeps out of junk selling (shown darker), and closes the window; the
-- sale goes on with the window closed. The bottom also says so when there is
-- more junk than the merchant can buy back.
local Junk = ns.Modules:Get("Junk")
local SellWindow = {}
Junk.SellWindow = SellWindow

local grid

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
	if not grid or not grid.built or Junk.Window.Mode() ~= "sell" then
		return
	end
	local sale = saleOf(grid.built)
	local selling = Junk.SellQueue.State() == "selling" or Junk.SellQueue.State() == "waiting"
	grid.sellButton:SetEnabled(#sale > 0 and not selling)
	grid.warning:SetShown(#sale > Junk.SellQueue.BUYBACK)
end

local function build(window)
	grid = window
	local frame = grid.footer
	grid.sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	grid.sellButton:SetSize(120, 22)
	grid.sellButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	grid.sellButton:SetText(L["Sell Junk"])
	-- The sale goes on without the window, which is done once the junk is picked.
	grid.sellButton:SetScript("OnClick", function()
		Junk.SellQueue.Start(saleOf(grid.built))
		grid:Close()
	end)
	grid.sellButton:Hide()
	grid.warning = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	grid.warning:SetPoint("LEFT", frame, "LEFT", 0, 0)
	grid.warning:SetPoint("RIGHT", grid.sellButton, "LEFT", -8, 0)
	grid.warning:SetJustifyH("LEFT")
	grid.warning:SetText(L["Only the last 12 sold items can be bought back."])
	grid.warning:Hide()
	Junk.SellQueue.Watch(updateFooter)
end

-- The sell button: the window selling, beside the merchant.
function SellWindow.Open()
	return Junk.Window.Open("merchant")
end

function SellWindow.Grid()
	return Junk.Window.Grid()
end

Junk.Window.Register("sell", {
	title = L["Sell Junk"],
	kind = "sell",
	onRefresh = updateFooter,
	build = build,
	enter = function()
		grid.sellButton:Show()
	end,
	leave = function()
		grid.sellButton:Hide()
		grid.warning:Hide()
	end,
})
