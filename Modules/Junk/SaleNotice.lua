local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- A sale cut short says so in a dialog like the game's own: the text and OK,
-- where the game puts its dialogs, closed by OK or Escape. Lootoman's own
-- frame: the game's generic dialog always has two buttons, and changing its
-- buttons from an addon would taint them, as the game's protected questions
-- use them too. Built at its first showing.
local Junk = ns.Modules:Get("Junk")
local Notice = {}
Junk.SaleNotice = Notice

Notice.NAME = "LootomanSaleNotice"
Notice.WIDTH = 360
Notice.TEXT = 320

local frame

local function build()
	frame = CreateFrame("Frame", Notice.NAME, UIParent)
	frame:Hide()
	frame:SetSize(Notice.WIDTH, 110)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame.border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
	frame.border:SetAllPoints(frame)
	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.text:SetPoint("TOP", frame, "TOP", 0, -20)
	frame.text:SetWidth(Notice.TEXT)
	frame.text:SetJustifyH("CENTER")
	frame.ok = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.ok:SetSize(110, 22)
	frame.ok:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	frame.ok:SetText(Compat.GetGlobalString("OKAY") or L["OK"])
	frame.ok:SetScript("OnClick", function()
		frame:Hide()
	end)
	table.insert(UISpecialFrames, Notice.NAME)
end

-- Shows the dialog with a text, as tall as the text needs.
function Notice.Show(text)
	if not frame then
		build()
	end
	frame.text:SetText(text)
	frame:SetHeight(20 + (frame.text:GetStringHeight() or 14) + 16 + 22 + 16)
	frame:Show()
end

-- The dialog, for tests.
function Notice.Frame()
	return frame
end
