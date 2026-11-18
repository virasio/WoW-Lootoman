local _, ns = ...
local Panel = ns.SettingsPanel

-- A small window with a line of text selected for copying, such as an addon's
-- address: the game cannot open a browser or write to the clipboard, so the
-- player copies it with the keyboard. Typing changes nothing; the text is
-- selected again. Built the first time it opens.
Panel.COPY_NAME = "LootomanCopyDialog"
Panel.COPY_WIDTH = 420

local dialog

local function build()
	local frame = CreateFrame("Frame", Panel.COPY_NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:SetSize(Panel.COPY_WIDTH, 130)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	-- Escape closes it as it closes the game's own windows (see the share dialog).
	table.insert(UISpecialFrames, Panel.COPY_NAME)
	frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.hint:SetPoint("TOPLEFT", 24, -34)
	frame.hint:SetPoint("TOPRIGHT", -24, -34)
	frame.hint:SetJustifyH("LEFT")
	frame.box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.box:SetSize(Panel.COPY_WIDTH - 56, 22)
	frame.box:SetPoint("TOPLEFT", frame.hint, "BOTTOMLEFT", 6, -10)
	frame.box:SetAutoFocus(false)
	frame.box:SetScript("OnTextChanged", function(box, userInput)
		if userInput then
			box:SetText(frame.text or "")
			box:HighlightText()
		end
	end)
	frame.box:SetScript("OnEditFocusGained", function(box)
		box:HighlightText()
	end)
	frame.box:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	frame.box:SetScript("OnEnterPressed", function()
		frame:Hide()
	end)
	local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	done:SetSize(120, 22)
	done:SetPoint("BOTTOMRIGHT", -20, 16)
	done:SetText(CLOSE)
	done:SetScript("OnClick", function()
		frame:Hide()
	end)
	return frame
end

-- Opens the window: its title, the line above the text, and the text.
function Panel.CopyText(title, hint, text)
	dialog = dialog or build()
	dialog:SetTitle(title)
	dialog.hint:SetText(hint)
	dialog.text = text
	dialog.box:SetText(text)
	dialog:Show()
	dialog.box:SetFocus()
	dialog.box:HighlightText()
end
