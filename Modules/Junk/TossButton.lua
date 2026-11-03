local _, ns = ...
local L = ns.L

-- The toss button on Blizzard's loot window: it opens the toss window. It is a
-- child of LootFrame, so it goes wherever the window goes: its show and hide
-- animations, its place in Edit Mode, and fast autoloot's hidden holder.
-- Nothing of Blizzard's is changed; the button only hooks the window's OnShow.
--
-- When it shows, by the setting: always with the loot window; when the bags are
-- full (something of this loot did not fit, LootSkipped, or the backpack and
-- the general bags have no free slot; checked as the window opens, and the
-- button stays while it is open); or never. Small, it sits on the window's
-- title bar left of the close button (the title is centred, which leaves
-- room); large, it is a square outside the window, on the chosen side and
-- moved along it by the offset. In Edit Mode it shows where it will be, and
-- does nothing.
local Junk = ns.Modules:Get("Junk")
local TossButton = {}
Junk.TossButton = TossButton

TossButton.SMALL = 20
-- Between the large button and the window.
TossButton.GAP = 4
TossButton.ICON = "SpellIcon-256x256-SellJunk"

local button
local hooked, active, skipped = false, false, false

local function inEditMode()
	return LootFrame.isInEditMode == true
end

-- Whether the button shows when the loot window opens.
function TossButton.Wanted()
	local mode = Junk:Get("tossButton")
	if mode == "never" then
		return false
	elseif mode == "always" or inEditMode() then
		return true
	end
	return skipped or ns.Bags.FreeGeneralSlots() == 0
end

local function place()
	button:ClearAllPoints()
	local large = Junk:Get("tossStyle") == "large"
	button.slot:SetShown(large)
	if not large then
		button:SetSize(TossButton.SMALL, TossButton.SMALL)
		button:SetPoint("RIGHT", LootFrame.ClosePanelButton, "LEFT", -2, 0)
		return
	end
	local size, offset, gap = Junk:Get("tossSize"), Junk:Get("tossOffset"), TossButton.GAP
	button:SetSize(size, size)
	-- Blizzard's 36 px slot button has a 64 px slot texture at -13, 14.
	local k = size / 36
	button.slot:ClearAllPoints()
	button.slot:SetPoint("TOPLEFT", -13 * k, 14 * k)
	button.slot:SetPoint("BOTTOMRIGHT", 15 * k, -14 * k)
	local side = Junk:Get("tossSide")
	if side == "left" then
		button:SetPoint("TOPRIGHT", LootFrame, "TOPLEFT", -gap, -offset)
	elseif side == "right" then
		button:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", gap, -offset)
	elseif side == "top" then
		button:SetPoint("BOTTOMLEFT", LootFrame, "TOPLEFT", offset, gap)
	else
		button:SetPoint("TOPLEFT", LootFrame, "BOTTOMLEFT", offset, -gap)
	end
end

local function update()
	if not button then
		return
	end
	place()
	button:SetShown(active and LootFrame:IsShown() and TossButton.Wanted())
end

local function create()
	button = CreateFrame("Button", nil, LootFrame)
	button:SetFrameLevel(LootFrame.ClosePanelButton:GetFrameLevel())
	-- The large button looks like the merchant's sell-junk button: an empty slot
	-- around the icon.
	button.slot = button:CreateTexture(nil, "BACKGROUND")
	button.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAtlas(TossButton.ICON)
	button.icon:SetAllPoints()
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:SetScript("OnClick", function()
		if not inEditMode() and Junk.Toss then
			Junk.Toss.Toggle()
		end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["Throw away junk"])
		GameTooltip_AddNormalLine(GameTooltip, L["Opens your bags with the junk on top. Right-click an item to delete it."])
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Hide()
end

-- The button, once the module has started on a client with a loot window.
function TossButton.Button()
	return button
end

Junk.AddPart({
	Enable = function()
		-- Clients without Blizzard's loot window get no button.
		if not LootFrame then
			return
		end
		if not button then
			create()
		end
		if not hooked then
			hooked = true
			LootFrame:HookScript("OnShow", update)
			LootFrame:HookScript("OnHide", function()
				if button then
					button:Hide()
				end
			end)
		end
		active = true
		Junk.Listen("LootSkipped", function()
			skipped = true
			update()
		end)
		Junk.ListenEvent("LOOT_CLOSED", function()
			skipped = false
		end)
		Junk.Listen("SettingChanged", function(_, module)
			if module == Junk.name then
				update()
			end
		end)
		Junk.Listen("ProfileChanged", update)
		update()
	end,
	Disable = function()
		active, skipped = false, false
		if button then
			button:Hide()
		end
	end,
})
