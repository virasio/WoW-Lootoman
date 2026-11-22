local _, ns = ...
local L = ns.L

-- Lootoman's sell-junk button at merchants, in place of Blizzard's. It lies
-- over Blizzard's MerchantSellAllJunkButton: a child of MerchantFrame with the
-- same textures, on all of its points and one level above it, shown and hidden
-- with it. So it moves when Blizzard moves its button (guild repair), hides on
-- the buyback tab, and Blizzard's button is never touched: nothing that could
-- taint the merchant frame. Turning the module off hides it, and Blizzard's
-- button works again.
--
-- A click sells the junk (Sections.SaleList) at once; Shift-click opens the
-- junk window to pick what to sell, and sells nothing by itself; a setting
-- swaps the two. The icon is grey
-- when there is no junk to sell. With "Sell junk at merchants" on, the junk is
-- sold as soon as a merchant's window opens.
local Junk = ns.Modules:Get("Junk")
local SellButton = {}
Junk.SellButton = SellButton

SellButton.ICON = "SpellIcon-256x256-SellJunk"

local button
local hooked, active = false, false

local function blizzard()
	return MerchantSellAllJunkButton
end

-- The junk is read only while the button is on screen: away from merchants a
-- bag change costs nothing. Visible, not shown: closing the merchant hides its
-- frame but leaves Blizzard's button flagged as shown. The hook on Blizzard's
-- OnShow, which fires as the merchant's frame opens, puts the icon right.
local function update()
	if not button then
		return
	end
	button:SetShown(active and blizzard():IsShown())
	if active and blizzard():IsVisible() then
		button.icon:SetDesaturated(#Junk.Sections.SaleList(Junk.SellQueue.Carried()) == 0)
	end
end

-- The junk, with what a sale cut short left a moment ago.
local function sell()
	local carried = Junk.SellQueue.Carried()
	return Junk.SellQueue.Start(Junk.Sections.SaleList(carried), carried)
end

-- Whether a plain click opens the junk window, by the selling choice: it
-- does unless the button sells ("button"); Shift-click does the other.
local function clickOpens()
	return Junk:Get("selling") ~= "button"
end

-- What a click does: open the junk window to sell and sell nothing, or sell the junk.
function SellButton.Click(shift)
	if (not shift) == clickOpens() then
		if Junk.SellWindow then
			Junk.SellWindow.Open()
		end
	else
		sell()
	end
end

local function showTooltip(self)
	local sale = Junk.Sections.SaleList(Junk.SellQueue.Carried())
	local value = 0
	for _, entry in ipairs(sale) do
		value = value + entry.price
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, L["Sell junk"])
	if #sale > 0 then
		GameTooltip_AddNormalLine(GameTooltip, L["Junk to sell: %d, for %s."]:format(#sale, GetMoneyString(value, true)))
	else
		GameTooltip_AddNormalLine(GameTooltip, L["No junk to sell."])
	end
	local opens = clickOpens()
	GameTooltip_AddNormalLine(GameTooltip, opens and L["Click: pick what to sell."] or L["Click: sell the junk."])
	GameTooltip_AddNormalLine(GameTooltip, opens and L["Shift-click: sell the junk."] or L["Shift-click: pick what to sell."])
	GameTooltip:Show()
end

local function create()
	local below = blizzard()
	button = CreateFrame("Button", nil, MerchantFrame)
	button:SetAllPoints(below)
	button:SetFrameLevel(below:GetFrameLevel() + 1)
	-- The textures of Blizzard's button (MerchantFrame.xml).
	local slot = button:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
	slot:SetSize(64, 64)
	slot:SetPoint("TOPLEFT", -13, 14)
	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAtlas(SellButton.ICON)
	button.icon:SetAllPoints()
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", function()
		SellButton.Click(IsShiftKeyDown())
	end)
	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Hide()
end

function SellButton.Button()
	return button
end

Junk.AddPart({
	Enable = function()
		-- A client without Blizzard's sell-junk button keeps its merchant as it is.
		if not (MerchantFrame and blizzard()) then
			return
		end
		if not button then
			create()
		end
		if not hooked then
			hooked = true
			blizzard():HookScript("OnShow", update)
			blizzard():HookScript("OnHide", update)
		end
		active = true
		Junk.Listen("InventoryChanged", update)
		Junk.Listen("MarksChanged", update)
		Junk.Listen("ProfileChanged", update)
		Junk.ListenEvent("MERCHANT_SHOW", function()
			-- The merchant's window is set up in the same frame; sell after it.
			ns.Compat.After(0, function()
				update()
				if active and Junk:Get("selling") == "auto" then
					sell()
				end
			end)
		end)
		update()
	end,
	Disable = function()
		active = false
		if button then
			button:Hide()
		end
	end,
})
