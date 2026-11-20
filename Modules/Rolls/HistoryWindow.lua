local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The history window, Roll History: the character's groups on the left,
-- newest first, each with its day, its places, how many drops and players it
-- had, and a skull when it had marked needs; on the right the chosen group:
-- its players with their needs, greeds, passes, wins and marks, and its drops
-- in time order, each a row with the item, the outcome and the choices
-- (DropRow.lua), with its time and place. Long lists reuse a pool of rows,
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
	frame.groupButtons, frame.playerLines, frame.dropRows = {}, {}, {}
	frame:SetScript("OnHide", function()
		judged = {}
	end)
	if HistoryWindow.OnBuild then
		HistoryWindow.OnBuild(frame)
	end
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

-- Whether a drop is shown under the filters (none until they come).
local function shows(entry, view)
	return not HistoryWindow.Shows or HistoryWindow.Shows(entry, view)
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
		end
	end
	for index = shown + 1, #frame.dropRows do
		DropRow.Hide(frame.dropRows[index])
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
	end
	frame.dropCount = 0
end

-- Draws the window as the history stands now.
function HistoryWindow.Redraw()
	if not frame or not frame:IsShown() then
		return
	end
	local groups = HistoryWindow.Groups()
	local still, any = false, false
	for _, group in ipairs(source().Groups()) do
		if group == frame.group then
			still = true
		end
		any = any or #group.drops > 0
	end
	if not still then
		frame.group = groups[1]
	end
	drawGroups(groups)
	frame.empty:SetShown(not any)
	if frame.player and HistoryWindow.DrawPlayer then
		hideDetail()
		HistoryWindow.DrawPlayer(frame.player)
	elseif frame.group then
		drawGroup(frame.group)
	else
		frame.header:SetText("")
		hideDetail()
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
