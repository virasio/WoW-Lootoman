local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The history window, Roll History: the character's groups on the left,
-- newest first, each with its day, its places, how many drops and players it
-- had, and a skull when it had marked needs; on the right the chosen group:
-- its players with their needs, greeds, passes, wins and marks, and its drops
-- in time order, each a row with the item, the outcome and the choices
-- (DropRow.lua), with its time and place. A click on a player (on their
-- line, or on a drop's line) shows them over all the kept groups: their
-- counts and every drop they chose on, group by group; the search box keeps
-- the groups with a player whose name holds its text, and Enter shows the
-- first such player. A player is known by GUID, under their latest name.
-- Above the drops, two filters kept in the profile: the lowest quality shown,
-- and, with the detection on, only the drops with marked needs (in a
-- player's view, their own). A marked need has an Exception checkbox beside
-- its line (in a raid's roll, the right click on its square, as on the
-- panels; in a player's view, beside the drop): ticked, the need is excused
-- and counts nowhere; unticked, it is marked again, in any kept group.
-- Long lists reuse a pool of rows,
-- made as they are first needed. Marks show only with ninja detection on,
-- judged by the rules of the day, once per drawing of a group (Marks.lua).
-- Built at its first opening, out of combat.
ns.Rolls = ns.Rolls or {}
local HistoryWindow = {}
ns.Rolls.HistoryWindow = HistoryWindow

local DropRow, History, Marks, Panel = ns.Rolls.DropRow, ns.Rolls.History, ns.Rolls.Marks, ns.Rolls.Panel

HistoryWindow.NAME = "LootomanRollHistory"
HistoryWindow.WIDTH, HistoryWindow.HEIGHT = 820, 540
HistoryWindow.LEFT = 250
HistoryWindow.GROUP = 40
HistoryWindow.LINE = 18
HistoryWindow.GAP = 4
HistoryWindow.TOP = 32

local frame

-- The history shown: the character's (History), or a stand-in with the same
-- calls (the made-up one).
local function source()
	return frame and frame.source or History
end

-- What a group's drops say once judged, kept until something changes:
-- { views = { [key] = view }, marked = { [guid] = count }, total }.
local judged = {}

function HistoryWindow.Invalidate()
	judged = {}
end

local function judge(group)
	if judged[group] then
		return judged[group]
	end
	local result = { views = {}, marked = {}, total = 0 }
	for _, entry in ipairs(group.drops) do
		local view = DropRow.Marked(DropRow.EntryView(entry, group), group, source())
		view.history = frame and frame.source
		result.views[entry.key] = view
		for _, player in ipairs(view.players) do
			if player.mark == Marks.NINJA and player.guid then
				result.marked[player.guid] = (result.marked[player.guid] or 0) + 1
				result.total = result.total + 1
			end
		end
	end
	judged[group] = result
	return result
end

-- A group's title: its day and its places.
local function titleOf(group)
	local day = group.started and Compat.FormatDay(group.started) or "?"
	local places = History.Places(group)
	if #places == 0 then
		return day
	end
	return ("%s  %s"):format(day, table.concat(places, ", "))
end

-- A player's counts, as one line.
local function countsOf(player)
	return (L["Need: %d, greed: %d, pass: %d, won: %d"]):format(player.need, player.greed, player.pass, player.won)
end

local function newGroupButton()
	local button = CreateFrame("Button", nil, frame.groupsContent)
	button:SetSize(HistoryWindow.LEFT - 28, HistoryWindow.GROUP)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints(button)
	button.highlight:SetColorTexture(1, 1, 1, 0.08)
	button.selected = button:CreateTexture(nil, "BACKGROUND")
	button.selected:SetAllPoints(button)
	button.selected:SetColorTexture(1, 0.82, 0, 0.15)
	button.title = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	button.title:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
	button.title:SetPoint("RIGHT", button, "RIGHT", -4, 0)
	button.title:SetJustifyH("LEFT")
	button.title:SetWordWrap(false)
	button.counts = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	button.counts:SetPoint("TOPLEFT", button.title, "BOTTOMLEFT", 0, -4)
	button.counts:SetPoint("RIGHT", button, "RIGHT", -4, 0)
	button.counts:SetJustifyH("LEFT")
	button:SetScript("OnClick", function(owner, mouse)
		if mouse == "RightButton" then
			if HistoryWindow.GroupMenu then
				HistoryWindow.GroupMenu(owner, owner.group)
			end
			return
		end
		HistoryWindow.Select(owner.group)
	end)
	frame.groupButtons[#frame.groupButtons + 1] = button
	return button
end

local function newPlayerLine()
	local line = CreateFrame("Button", nil, frame.detailContent)
	line:SetSize(HistoryWindow.WIDTH - HistoryWindow.LEFT - 70, HistoryWindow.LINE)
	line:RegisterForClicks("LeftButtonUp")
	line.highlight = line:CreateTexture(nil, "HIGHLIGHT")
	line.highlight:SetAllPoints(line)
	line.highlight:SetColorTexture(1, 1, 1, 0.08)
	line.name = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	line.name:SetPoint("LEFT", line, "LEFT", 4, 0)
	line.name:SetWidth(160)
	line.name:SetJustifyH("LEFT")
	line.name:SetWordWrap(false)
	line.counts = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line.counts:SetPoint("LEFT", line.name, "RIGHT", 6, 0)
	line.counts:SetPoint("RIGHT", line, "RIGHT", -4, 0)
	line.counts:SetJustifyH("LEFT")
	line:SetScript("OnClick", function(owner)
		if owner.player and HistoryWindow.ShowPlayer then
			HistoryWindow.ShowPlayer(owner.player.guid)
		end
	end)
	frame.playerLines[#frame.playerLines + 1] = line
	return line
end

-- A need's Exception checkbox on a row, the index-th.
local function exceptionCheck(row, index)
	row.checks = row.checks or {}
	local check = row.checks[index]
	if not check then
		check = CreateFrame("CheckButton", nil, row.frame, "UICheckButtonTemplate")
		check:SetSize(18, 18)
		check.label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		check.label:SetPoint("LEFT", check, "RIGHT", 1, 0)
		check.label:SetText(L["Exception"])
		check:SetScript("OnClick", function(button)
			if button.view and button.player then
				ns.Rolls.SuspiciousNeeds.SetExcused(button.view, button.player, button:GetChecked() == true)
			end
		end)
		row.checks[index] = check
	end
	return check
end

-- The Exception checkboxes of a drawn row: beside each line of a marked or
-- excused need, or, for one player (their view), beside the row.
local function drawExceptions(row, view, guid)
	local used = 0
	local detection = ns.Storage:Get("Rolls", "ninja") == true
	local function place(player, anchor, x)
		used = used + 1
		local check = exceptionCheck(row, used)
		check.view, check.player = view, player
		check:ClearAllPoints()
		check:SetPoint("LEFT", anchor, "RIGHT", x, 0)
		check:SetChecked(player.excused == true)
		check:Show()
		check.label:Show()
	end
	local function excusable(player)
		return detection and ns.Rules.Need.IsNeed(player.state) and (player.mark ~= nil or player.excused == true)
	end
	if guid then
		for _, player in ipairs(view.players) do
			if player.guid == guid and excusable(player) then
				place(player, row.panel.frame, 6)
			end
		end
	else
		-- On each line's height, past the panel's edge.
		for _, line in ipairs(row.panel.lines) do
			if line:IsShown() and line.player and excusable(line.player) then
				place(line.player, line, 6 + Panel.PAD)
			end
		end
	end
	for index = used + 1, #(row.checks or {}) do
		row.checks[index]:Hide()
		row.checks[index].label:Hide()
		row.checks[index].view, row.checks[index].player = nil, nil
	end
end

local function newDropRow()
	local row = DropRow.New(frame.detailContent)
	row.panel.onRightClick = function(...)
		if ns.Rolls.Module.OnRightClick then
			ns.Rolls.Module.OnRightClick(...)
		end
	end
	row.panel.onLeftClick = function(_, player)
		if player.guid and HistoryWindow.ShowPlayer then
			HistoryWindow.ShowPlayer(player.guid)
		end
	end
	frame.dropRows[#frame.dropRows + 1] = row
	return row
end

local function heading(parent, text)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

local function build()
	frame = CreateFrame("Frame", HistoryWindow.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(HistoryWindow.WIDTH, HistoryWindow.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Roll History"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	table.insert(UISpecialFrames, HistoryWindow.NAME)
	-- The groups, on the left.
	frame.groupsInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	frame.groupsInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -62)
	frame.groupsInset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 40)
	frame.groupsInset:SetWidth(HistoryWindow.LEFT)
	frame.groupsScroll = CreateFrame("ScrollFrame", nil, frame.groupsInset, "ScrollFrameTemplate")
	frame.groupsScroll:SetPoint("TOPLEFT", 4, -4)
	frame.groupsScroll:SetPoint("BOTTOMRIGHT", -24, 4)
	frame.groupsContent = CreateFrame("Frame", nil, frame.groupsScroll)
	frame.groupsContent:SetSize(HistoryWindow.LEFT - 28, 1)
	frame.groupsScroll:SetScrollChild(frame.groupsContent)
	-- The chosen group, on the right.
	local left = 10 + HistoryWindow.LEFT + 12
	frame.header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -HistoryWindow.TOP - 4)
	frame.header:SetPoint("RIGHT", frame, "RIGHT", -140, 0)
	frame.header:SetJustifyH("LEFT")
	frame.header:SetWordWrap(false)
	frame.ninjaRules = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.ninjaRules:SetSize(120, 22)
	frame.ninjaRules:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HistoryWindow.TOP)
	frame.ninjaRules:SetText(L["Ninja Rules"])
	frame.ninjaRules:SetScript("OnClick", function()
		ns.Rolls.NinjaRules.OpenOrAsk()
	end)
	frame.detailScroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	frame.detailScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -88)
	frame.detailScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)
	frame.detailContent = CreateFrame("Frame", nil, frame.detailScroll)
	frame.detailContent:SetSize(HistoryWindow.WIDTH - left - 40, 1)
	frame.detailScroll:SetScrollChild(frame.detailContent)
	frame.playersHeading = heading(frame.detailContent, L["Players"])
	frame.dropsHeading = heading(frame.detailContent, L["Drops"])
	frame.empty = frame.detailContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.empty:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 4, -4)
	frame.empty:SetPoint("RIGHT", frame.detailContent, "RIGHT", -4, 0)
	frame.empty:SetJustifyH("LEFT")
	frame.empty:SetText(L["No rolls kept yet. The rolls in your groups are kept here, by group, from joining to leaving."])
	frame.groupButtons, frame.playerLines, frame.dropRows, frame.groupHeadings = {}, {}, {}, {}
	-- The search, above the groups.
	frame.search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	frame.search:SetSize(HistoryWindow.LEFT - 12, 20)
	frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -HistoryWindow.TOP - 4)
	frame.search:SetAutoFocus(false)
	-- The template's own script keeps its clear button and hint: hooked, not replaced.
	frame.search:HookScript("OnTextChanged", function(box)
		frame.searchText = box:GetText() or ""
		HistoryWindow.Redraw()
	end)
	frame.search:HookScript("OnEnterPressed", function(box)
		box:ClearFocus()
		local guid = HistoryWindow.Found()
		if guid then
			HistoryWindow.ShowPlayer(guid)
		end
	end)
	-- Back from a player to the group.
	frame.back = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.back:SetSize(80, 22)
	frame.back:SetPoint("RIGHT", frame.ninjaRules, "LEFT", -6, 0)
	frame.back:SetText(L["Back"])
	frame.back:SetScript("OnClick", function()
		frame.player = nil
		HistoryWindow.Redraw()
	end)
	frame.back:Hide()
	-- The filters, above the drops.
	frame.qualityLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.qualityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + HistoryWindow.LEFT + 12, -66)
	frame.qualityLabel:SetText(L["Lowest Quality"])
	frame.quality = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.quality:SetWidth(130)
	frame.quality:SetPoint("LEFT", frame.qualityLabel, "RIGHT", 8, 0)
	frame.quality:SetupMenu(function(_, root)
		for _, quality in ipairs({ 2, 3, 4 }) do
			root:CreateRadio(Compat.GetGlobalString("ITEM_QUALITY" .. quality .. "_DESC") or tostring(quality), function()
				return ns.Storage:Get("Rolls", "historyMinQuality") == quality
			end, function()
				ns.Storage:Set("Rolls", "historyMinQuality", quality)
			end, quality)
		end
	end)
	frame.markedOnly = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame.markedOnly:SetSize(22, 22)
	frame.markedOnly:SetPoint("LEFT", frame.quality, "RIGHT", 16, 0)
	frame.markedOnly.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.markedOnly.label:SetPoint("LEFT", frame.markedOnly, "RIGHT", 2, 0)
	frame.markedOnly.label:SetText(L["Only Marked Needs"])
	frame.markedOnly:SetScript("OnClick", function(check)
		ns.Storage:Set("Rolls", "historyMarkedOnly", check:GetChecked() == true)
	end)
	frame:SetScript("OnHide", function()
		judged = {}
	end)
	if HistoryWindow.OnBuild then
		HistoryWindow.OnBuild(frame)
	end
end

-- Whether a name holds the search's text, whatever the case.
local function matches(name, text)
	return type(name) == "string" and ns.Text.FoldCase(name):find(ns.Text.FoldCase(text), 1, true) ~= nil
end

-- The search keeps the groups with a player whose name holds its text.
function HistoryWindow.Keeps(group)
	local text = frame and frame.searchText or ""
	if text == "" then
		return true
	end
	for _, player in ipairs(History.Players(group)) do
		if matches(player.name, text) then
			return true
		end
	end
	return false
end

-- The first player the search finds, newest group first: their GUID.
function HistoryWindow.Found()
	local text = frame and frame.searchText or ""
	if text == "" then
		return nil
	end
	for _, group in ipairs(HistoryWindow.Groups()) do
		for _, player in ipairs(History.Players(group)) do
			if player.guid and matches(player.name, text) then
				return player.guid
			end
		end
	end
	return nil
end

-- The groups shown on the left, newest first: those with drops.
function HistoryWindow.Groups()
	local groups, list = source().Groups(), {}
	for index = #groups, 1, -1 do
		local group = groups[index]
		if #group.drops > 0 and (not HistoryWindow.Keeps or HistoryWindow.Keeps(group)) then
			list[#list + 1] = group
		end
	end
	return list
end

local function drawGroups(groups)
	local detection = ns.Storage:Get("Rolls", "ninja") == true
	for index, group in ipairs(groups) do
		local button = frame.groupButtons[index] or newGroupButton()
		button.group = group
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame.groupsContent, "TOPLEFT", 0, -(index - 1) * HistoryWindow.GROUP)
		button.title:SetText(titleOf(group))
		local counts = (L["%d drops, %d players"]):format(#group.drops, #History.Players(group))
		if detection and judge(group).total > 0 then
			counts = counts .. Marks.NINJA
		end
		button.counts:SetText(counts)
		button.selected:SetShown(group == frame.group)
		button:Show()
	end
	for index = #groups + 1, #frame.groupButtons do
		frame.groupButtons[index]:Hide()
		frame.groupButtons[index].group = nil
	end
	frame.groupsContent:SetHeight(math.max(1, #groups * HistoryWindow.GROUP))
end

-- Whether a drop is shown under the filters: its quality, and with the
-- detection on and the filter ticked, a marked need on it (the player's own,
-- in their view).
local function shows(entry, view, guid)
	local lowest = ns.Storage:Get("Rolls", "historyMinQuality") or 2
	if entry.quality and entry.quality < lowest then
		return false
	end
	if ns.Storage:Get("Rolls", "ninja") and ns.Storage:Get("Rolls", "historyMarkedOnly") then
		for _, player in ipairs(view.players) do
			if player.mark == Marks.NINJA and (not guid or player.guid == guid) then
				return true
			end
		end
		return false
	end
	return true
end

-- The filters as the profile has them.
local function refreshFilters()
	frame.quality:GenerateMenu()
	local detection = ns.Storage:Get("Rolls", "ninja") == true
	frame.markedOnly:SetChecked(ns.Storage:Get("Rolls", "historyMarkedOnly") == true)
	frame.markedOnly:SetEnabled(detection)
	frame.markedOnly.label:SetAlpha(detection and 1 or 0.5)
end

-- The detail of a group: its players, then its drops.
local function drawGroup(group)
	local y = 0
	local result = judge(group)
	frame.header:SetText(titleOf(group))
	frame.playersHeading:ClearAllPoints()
	frame.playersHeading:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 4, -y)
	frame.playersHeading:Show()
	y = y + 20
	local players = History.Players(group)
	for index, player in ipairs(players) do
		local line = frame.playerLines[index] or newPlayerLine()
		line.player = player
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
		line.name:SetText(Panel.ClassName(player.name, player.class))
		local marked = player.guid and result.marked[player.guid]
		line.counts:SetText(countsOf(player) .. (marked and ("   %s %d"):format(Marks.NINJA, marked) or ""))
		line:Show()
		y = y + HistoryWindow.LINE
	end
	for index = #players + 1, #frame.playerLines do
		frame.playerLines[index]:Hide()
	end
	y = y + 10
	frame.dropsHeading:ClearAllPoints()
	frame.dropsHeading:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 4, -y)
	frame.dropsHeading:Show()
	y = y + 20
	local shown = 0
	for _, entry in ipairs(group.drops) do
		local view = result.views[entry.key]
		if view and shows(entry, view) then
			shown = shown + 1
			local row = frame.dropRows[shown] or newDropRow()
			row.frame:ClearAllPoints()
			row.frame:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
			local note = entry.time and Compat.FormatTime(entry.time) or ""
			if entry.place then
				note = note ~= "" and (note .. ", " .. entry.place) or entry.place
			end
			y = y + DropRow.Draw(row, view, note) + HistoryWindow.GAP
			drawExceptions(row, view)
		end
	end
	for index = shown + 1, #frame.dropRows do
		DropRow.Hide(frame.dropRows[index])
		drawExceptions(frame.dropRows[index], { players = {} })
	end
	frame.dropCount = shown
	frame.detailContent:SetHeight(math.max(1, y))
end

local function hideDetail()
	frame.playersHeading:Hide()
	frame.dropsHeading:Hide()
	for _, line in ipairs(frame.playerLines) do
		line:Hide()
	end
	for _, row in ipairs(frame.dropRows) do
		DropRow.Hide(row)
		drawExceptions(row, { players = {} })
	end
	for _, label in ipairs(frame.groupHeadings) do
		label:Hide()
	end
	frame.dropCount = 0
end

-- A player over every kept group: their counts, then each group with the
-- drops they chose on, each noting their choice and roll.
local function drawPlayer(guid)
	local found = History.Across(guid)
	if not found then
		frame.player = nil
		return false
	end
	local player = found.player
	frame.header:SetText(Panel.ClassName(player.name, player.class))
	local y = 0
	local marked = 0
	for _, each in ipairs(found.groups) do
		marked = marked + (judge(each.group).marked[guid] or 0)
	end
	local summary = frame.playerLines[1] or newPlayerLine()
	summary.player = nil
	summary:ClearAllPoints()
	summary:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
	summary.name:SetText(Panel.ClassName(player.name, player.class))
	summary.counts:SetText(countsOf(player) .. (marked > 0 and ("   %s %d"):format(Marks.NINJA, marked) or ""))
	summary:Show()
	y = y + HistoryWindow.LINE + 8
	local shown = 0
	for index, each in ipairs(found.groups) do
		local label = frame.groupHeadings[index]
		if not label then
			label = heading(frame.detailContent, "")
			frame.groupHeadings[index] = label
		end
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 4, -y)
		label:SetText(titleOf(each.group))
		label:Show()
		y = y + 20
		local result = judge(each.group)
		for _, drop in ipairs(each.drops) do
			local view = result.views[drop.entry.key]
			if view and shows(drop.entry, view, guid) then
				shown = shown + 1
				local row = frame.dropRows[shown] or newDropRow()
				row.frame:ClearAllPoints()
				row.frame:SetPoint("TOPLEFT", frame.detailContent, "TOPLEFT", 0, -y)
				local choice = Panel.ChoiceName(drop.choice.state) or ""
				if drop.choice.roll then
					choice = ("%s %d"):format(choice, drop.choice.roll)
				end
				local note = drop.entry.time and Compat.FormatTime(drop.entry.time) or ""
				y = y + DropRow.Draw(row, view, ("%s  %s"):format(note, choice)) + HistoryWindow.GAP
				drawExceptions(row, view, guid)
			end
		end
	end
	for index = #found.groups + 1, #frame.groupHeadings do
		frame.groupHeadings[index]:Hide()
	end
	for index = shown + 1, #frame.dropRows do
		DropRow.Hide(frame.dropRows[index])
		drawExceptions(frame.dropRows[index], { players = {} })
	end
	frame.dropCount = shown
	frame.detailContent:SetHeight(math.max(1, y))
	return true
end
HistoryWindow.DrawPlayer = drawPlayer

-- Shows a player over every kept group, by GUID.
function HistoryWindow.ShowPlayer(guid)
	if not frame or not guid then
		return
	end
	frame.player = guid
	HistoryWindow.Redraw()
end

-- Draws the window as the history stands now.
function HistoryWindow.Redraw()
	if not frame or not frame:IsShown() then
		return
	end
	local groups = HistoryWindow.Groups()
	local still, any = false, false
	-- The chosen group stays while the list (searched) still has it.
	for _, group in ipairs(groups) do
		if group == frame.group then
			still = true
		end
	end
	for _, group in ipairs(source().Groups()) do
		any = any or #group.drops > 0
	end
	if not still then
		frame.group = groups[1]
	end
	drawGroups(groups)
	refreshFilters()
	frame.empty:SetShown(not any)
	hideDetail()
	if frame.player and drawPlayer(frame.player) then
		frame.back:Show()
		return
	end
	frame.back:Hide()
	if frame.group then
		drawGroup(frame.group)
	else
		frame.header:SetText("")
	end
end

-- Shows a group on the right.
function HistoryWindow.Select(group)
	if not frame then
		return
	end
	frame.group = group
	frame.player = nil
	HistoryWindow.Redraw()
end

-- Opens the window on the character's history, or on a stand-in for it;
-- the first time, out of combat only.
function HistoryWindow.Open(stand)
	if not frame then
		if Compat.InCombat() then
			ns.Print(L["The roll history opens out of combat."])
			return false
		end
		build()
	end
	if frame.source ~= stand then
		frame.group, frame.player = nil, nil
	end
	frame.source = stand
	judged = {}
	frame:Show()
	HistoryWindow.Redraw()
	return true
end

-- Opens the window while the loot rolls are on; else asks to turn them on.
function HistoryWindow.OpenOrAsk()
	ns.TurnOn.WhenOn("Rolls", function()
		HistoryWindow.Open()
	end)
end

-- The history changed (a drop kept, the rules or an exception): the window
-- judges again and redraws.
function HistoryWindow.Changed()
	judged = {}
	HistoryWindow.Redraw()
end

function HistoryWindow.Hide()
	if frame then
		frame:Hide()
	end
end

-- The window, for tests.
function HistoryWindow.Frame()
	return frame
end

ns.Slash.Register("rolls", HistoryWindow.OpenOrAsk, L["/ltm rolls: open the roll history"])
