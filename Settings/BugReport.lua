local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- The bug report window: what to do, the Extended Log switch, the address to
-- send a report to, and the report itself (Core/BugReport.lua), built each
-- time the window opens and on Refresh, ready to copy. The report box is
-- read-only: typing puts the report back. It is the player's own frame, built
-- the first time it opens, never in combat; Escape and its close button hide
-- it. /ltm report, the minimap icon's menu and the addon compartment open it.
local Window = {}
ns.BugReportWindow = Window

Window.NAME = "LootomanBugReport"
-- GitHub Issues only: CurseForge's issue link leads there too.
Window.ADDRESS = "https://github.com/virasio/WoW-Lootoman/issues"
Window.WIDTH, Window.HEIGHT = 600, 520
Window.BOX_HEIGHT = 290

local frame

function Window.Refresh()
	if not frame then
		return
	end
	frame.text = ns.BugReport.Build()
	frame.report.EditBox:SetText(frame.text)
	frame.extended:SetChecked(Storage:GetGlobal("debug"))
end

local function newText(font, text)
	local line = frame:CreateFontString(nil, "ARTWORK", font)
	line:SetJustifyH("LEFT")
	line:SetText(text)
	return line
end

local function newButton(text, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(130, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function build()
	frame = CreateFrame("Frame", Window.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(Window.WIDTH, Window.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Bug Report"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the look window).
	table.insert(UISpecialFrames, Window.NAME)

	frame.intro = newText("GameFontHighlight",
		L["Something went wrong? Copy this report and open a new issue at the address below: say what you did and what you saw."])
	frame.intro:SetPoint("TOPLEFT", 20, -34)
	frame.intro:SetPoint("TOPRIGHT", -20, -34)

	frame.extended = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame.extended:SetPoint("TOPLEFT", frame.intro, "BOTTOMLEFT", -4, -8)
	frame.extendedLabel = newText("GameFontHighlight", L["Extended Log"])
	frame.extendedLabel:SetPoint("LEFT", frame.extended, "RIGHT", 2, 0)
	frame.extended:SetScript("OnClick", function(check)
		Storage:SetGlobal("debug", check:GetChecked() == true)
		Window.Refresh()
	end)
	frame.extended:SetScript("OnEnter", function(check)
		GameTooltip:SetOwner(check, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["Extended Log"])
		GameTooltip_AddNormalLine(GameTooltip,
			L["Records what Lootoman decides as it happens, for every character. Turn it on, do what goes wrong, and come back here."])
		GameTooltip:Show()
	end)
	frame.extended:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	frame.where = newText("GameFontNormal", L["Where to send it"])
	frame.where:SetPoint("TOPLEFT", frame.extended, "BOTTOMLEFT", 4, -8)
	-- The address in a line to copy: selected on a click, and typing puts it back.
	frame.address = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.address:SetSize(Window.WIDTH - 60, 22)
	frame.address:SetPoint("TOPLEFT", frame.where, "BOTTOMLEFT", 6, -4)
	frame.address:SetAutoFocus(false)
	frame.address:SetText(Window.ADDRESS)
	frame.address:SetScript("OnTextChanged", function(box, userInput)
		if userInput then
			box:SetText(Window.ADDRESS)
			box:HighlightText()
		end
	end)
	frame.address:SetScript("OnEditFocusGained", function(box)
		box:HighlightText()
	end)
	frame.address:SetScript("OnEscapePressed", function(box)
		box:ClearFocus()
	end)

	-- The report, in a scrolling box as Blizzard's import dialogs have.
	frame.report = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
	frame.report:SetSize(Window.WIDTH - 48, Window.BOX_HEIGHT)
	frame.report:SetPoint("TOPLEFT", frame.address, "BOTTOMLEFT", 0, -14)
	-- The template sizes the text to the frame when it loads, before it has a size.
	frame.report.EditBox:SetWidth(Window.WIDTH - 66)
	frame.report.CharCount:Hide()
	frame.report.EditBox:HookScript("OnTextChanged", function(box, userInput)
		if userInput then
			box:SetText(frame.text or "")
		end
	end)

	frame.selectAll = newButton(L["Select All"], function()
		frame.report.EditBox:SetFocus()
		frame.report.EditBox:HighlightText()
	end)
	frame.selectAll:SetPoint("TOPLEFT", frame.report, "BOTTOMLEFT", -6, -10)
	frame.refresh = newButton(L["Refresh"], Window.Refresh)
	frame.refresh:SetPoint("LEFT", frame.selectAll, "RIGHT", 6, 0)
	frame.clear = newButton(L["Clear the Log"], function()
		ns.Diagnostics.Clear()
		Window.Refresh()
	end)
	frame.clear:SetPoint("LEFT", frame.refresh, "RIGHT", 6, 0)

	frame.bugSack = newText("GameFontDisableSmall", L["Errors from other addons, and some of Lootoman's, are in BugSack."])
	frame.bugSack:SetPoint("BOTTOMLEFT", 20, 14)
end

-- Opens the window with a fresh report; the first time, out of combat only.
function Window.Open()
	if not frame then
		if Compat.InCombat() then
			ns.Print(L["The bug report opens out of combat."])
			return false
		end
		build()
	end
	Window.Refresh()
	frame:Show()
	return true
end

-- The window, for tests.
function Window.Frame()
	return frame
end

ns.Slash.Register("report", Window.Open, L["/ltm report: open the bug report window"])
