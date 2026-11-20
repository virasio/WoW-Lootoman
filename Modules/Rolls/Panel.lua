local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The panel at the side of a game's roll frame: who chose what on that roll
-- and rolled what, in class colours, as it happens. The game opens up to four
-- roll frames and stacks them upwards 100 pixels apart, so a panel is never
-- taller than that and stands beside its frame: at its right, or at its left
-- when the right would run off the screen. In a roll among five or fewer, a
-- line per player; in a bigger one (a raid), five short lines. The game's
-- frames are never changed: the panels only read their roll.
ns.Rolls = ns.Rolls or {}
local Panel = {}
ns.Rolls.Panel = Panel

local STATE = ns.Rules.Need.STATE

Panel.WIDTH = 190
Panel.LINE = 15
Panel.PAD = 6
Panel.GAP = 4
-- The room the game leaves per roll frame.
Panel.MAX_HEIGHT = 100
-- Up to this many players get a line each.
Panel.GROUP = 5
Panel.ICON = 13

-- The game's roll atlases for each choice.
Panel.ICONS = {
	[STATE.NEED] = "lootroll-toast-icon-need-up",
	[STATE.NEED_OFF_SPEC] = "lootroll-toast-icon-need-up",
	[STATE.GREED] = "lootroll-toast-icon-greed-up",
	[STATE.TRANSMOG] = "lootroll-toast-icon-transmog-up",
	[STATE.PASS] = "lootroll-toast-icon-pass-up",
	[STATE.NONE] = "lootroll-pendingdot",
}
Panel.WINNER = "lootroll-icon-checkmark"

-- A name in its class colour.
function Panel.ClassName(name, class)
	local color = class and Compat.GetClassColor(class)
	if color and color.code then
		return "|c" .. color.code .. tostring(name) .. "|r"
	end
	return tostring(name or "?")
end

local function showTooltip(owner, lines)
	if not lines or #lines == 0 then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, lines[1])
	for index = 2, #lines do
		GameTooltip_AddNormalLine(GameTooltip, lines[index])
	end
	GameTooltip:Show()
end

-- A line of the panel: a button for its tooltip and right click, an icon, a
-- text, a roll and the winner's checkmark.
local function newLine(panel, index)
	local line = CreateFrame("Button", nil, panel.frame)
	line:SetSize(Panel.WIDTH - 2 * Panel.PAD, Panel.LINE)
	line:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", Panel.PAD, -Panel.PAD - (index - 1) * Panel.LINE)
	line:RegisterForClicks("RightButtonUp")
	line.self = line:CreateTexture(nil, "BACKGROUND")
	line.self:SetAllPoints(line)
	line.self:SetColorTexture(1, 1, 1, 0.08)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetSize(Panel.ICON, Panel.ICON)
	line.icon:SetPoint("LEFT", line, "LEFT", 0, 0)
	line.text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
	line.text:SetPoint("RIGHT", line, "RIGHT", -40, 0)
	line.text:SetJustifyH("LEFT")
	line.roll = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line.roll:SetPoint("RIGHT", line, "RIGHT", -16, 0)
	line.roll:SetJustifyH("RIGHT")
	line.winner = line:CreateTexture(nil, "OVERLAY")
	line.winner:SetSize(Panel.ICON, Panel.ICON)
	line.winner:SetPoint("RIGHT", line, "RIGHT", 0, 0)
	line.winner:SetAtlas(Panel.WINNER)
	line:SetScript("OnEnter", function(owner)
		showTooltip(owner, owner.tooltip)
	end)
	line:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	line:SetScript("OnClick", function(owner, button)
		if button == "RightButton" and panel.onRightClick and owner.player then
			panel.onRightClick(owner, owner.player, panel.view)
		end
	end)
	line:Hide()
	return line
end

-- A panel, hidden; its own frame is the player's, created out of combat.
function Panel.New()
	local panel = {}
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetSize(Panel.WIDTH, Panel.LINE + 2 * Panel.PAD)
	frame:Hide()
	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints(frame)
	frame.background:SetColorTexture(0, 0, 0, 0.75)
	-- A thin edge in the gold of the game's loot toasts.
	frame.edges = {}
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetColorTexture(0.6, 0.5, 0.25, 0.8)
		edge:SetPoint(side[1], frame, side[1], 0, 0)
		edge:SetPoint(side[2], frame, side[2], 0, 0)
		if side[1]:match("TOP") and side[2]:match("TOP") or side[1]:match("BOTTOM") and side[2]:match("BOTTOM") then
			edge:SetHeight(1)
		else
			edge:SetWidth(1)
		end
		frame.edges[#frame.edges + 1] = edge
	end
	panel.frame = frame
	panel.lines = {}
	for index = 1, Panel.GROUP do
		panel.lines[index] = newLine(panel, index)
	end
	return panel
end

-- Places a panel beside a frame: at its right, at its left when the right
-- would run off the screen.
function Panel.Place(panel, frame)
	local right = frame.GetRight and frame:GetRight()
	local screen = UIParent.GetRight and UIParent:GetRight()
	panel.frame:ClearAllPoints()
	if type(right) == "number" and type(screen) == "number" and right + Panel.GAP + Panel.WIDTH > screen then
		panel.frame:SetPoint("RIGHT", frame, "LEFT", -Panel.GAP, 0)
		panel.side = "left"
	else
		panel.frame:SetPoint("LEFT", frame, "RIGHT", Panel.GAP, 0)
		panel.side = "right"
	end
end

local function resize(panel, count)
	panel.frame:SetHeight(math.min(Panel.MAX_HEIGHT, 2 * Panel.PAD + math.max(1, count) * Panel.LINE))
end

local function clear(panel)
	for _, line in ipairs(panel.lines) do
		line:Hide()
		line.player, line.tooltip = nil, nil
		line.icon:SetAtlas(nil)
		line.icon:Hide()
		line.self:Hide()
		line.winner:Hide()
		line.roll:SetText("")
		line.text:SetText("")
		line.text:SetAlpha(1)
		line.text:ClearAllPoints()
		line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
		line.text:SetPoint("RIGHT", line, "RIGHT", -40, 0)
		if line.squares then
			for _, square in ipairs(line.squares) do
				square:Hide()
			end
		end
	end
end

-- The words for a choice, the game's own.
function Panel.ChoiceName(state)
	if ns.Rules.Need.IsNeed(state) then
		return Compat.GetGlobalString("NEED")
	elseif state == STATE.GREED then
		return Compat.GetGlobalString("GREED")
	elseif state == STATE.TRANSMOG then
		return Compat.GetGlobalString("TRANSMOGRIFICATION")
	elseif state == STATE.PASS then
		return Compat.GetGlobalString("PASS")
	end
	return nil
end

-- The tooltip of a player's line: his name, his choice and roll, and what
-- else others add (the marks).
local function playerTooltip(player)
	local lines = { Panel.ClassName(player.name, player.class) }
	local choice = Panel.ChoiceName(player.state)
	if choice then
		lines[#lines + 1] = player.roll and ("%s: %d"):format(choice, player.roll) or choice
	end
	for _, extra in ipairs(player.notes or {}) do
		lines[#lines + 1] = extra
	end
	return lines
end

local function drawGroup(panel, view)
	for index, player in ipairs(view.players) do
		local line = panel.lines[index]
		if not line then
			break
		end
		line.player = player
		line.icon:SetAtlas(Panel.ICONS[player.state] or Panel.ICONS[STATE.NONE])
		line.icon:Show()
		line.text:SetText(Panel.ClassName(player.name, player.class) .. (player.mark or ""))
		line.text:SetAlpha((view.leader and not player.isLeader and not view.winner) and 0.8 or 1)
		line.roll:SetText(player.roll and tostring(player.roll) or "")
		line.self:SetShown(player.isSelf == true)
		line.winner:SetShown(player.isWinner == true)
		line.tooltip = playerTooltip(player)
		line:Show()
	end
	resize(panel, #view.players)
end

local function names(players)
	local list = {}
	for _, player in ipairs(players) do
		list[#list + 1] = Panel.ClassName(player.name, player.class)
	end
	return table.concat(list, ", ")
end

-- The raid's lines: the leader (or the winner); the needs; the ninjas'
-- squares (Marks.lua); greed, transmog and pass as icons with counts; who has
-- not chosen. Each line names its players in its tooltip.
local function drawRaid(panel, view)
	local needs, greeds, transmogs, passes, waiting = {}, {}, {}, {}, {}
	for _, player in ipairs(view.players) do
		if ns.Rules.Need.IsNeed(player.state) then
			needs[#needs + 1] = player
		elseif player.state == STATE.GREED then
			greeds[#greeds + 1] = player
		elseif player.state == STATE.TRANSMOG then
			transmogs[#transmogs + 1] = player
		elseif player.state == STATE.PASS then
			passes[#passes + 1] = player
		else
			waiting[#waiting + 1] = player
		end
	end
	local rows = {}
	local top = view.winner or view.leader
	if top then
		rows[#rows + 1] = { text = ("%s %s"):format(top.roll and tostring(top.roll) or "", Panel.ClassName(top.name, top.class)),
			winner = view.winner ~= nil, tooltip = { Panel.ClassName(top.name, top.class), Panel.ChoiceName(top.state) } }
	else
		rows[#rows + 1] = { text = L["Waiting for the rolls…"] }
	end
	local needLines = { (L["Need: %d"]):format(#needs) }
	for _, player in ipairs(needs) do
		needLines[#needLines + 1] = ("%s %s"):format(Panel.ClassName(player.name, player.class), player.roll and tostring(player.roll) or "")
	end
	rows[#rows + 1] = { text = view.needLine or (L["Need: %d"]):format(#needs), tooltip = needLines, icon = Panel.ICONS[STATE.NEED] }
	if view.ninjas and #view.ninjas > 0 then
		rows[#rows + 1] = { squares = view.ninjas }
	end
	local counts = {}
	local function count(state, list)
		counts[#counts + 1] = CreateAtlasMarkup(Panel.ICONS[state], Panel.ICON, Panel.ICON) .. " " .. #list
	end
	count(STATE.GREED, greeds)
	if #transmogs > 0 or (view.item and view.item.canTransmog) then
		count(STATE.TRANSMOG, transmogs)
	end
	count(STATE.PASS, passes)
	local choiceLines = { table.concat(counts, "  ") }
	if #greeds > 0 then
		choiceLines[#choiceLines + 1] = Panel.ChoiceName(STATE.GREED) .. ": " .. names(greeds)
	end
	if #transmogs > 0 then
		choiceLines[#choiceLines + 1] = Panel.ChoiceName(STATE.TRANSMOG) .. ": " .. names(transmogs)
	end
	if #passes > 0 then
		choiceLines[#choiceLines + 1] = Panel.ChoiceName(STATE.PASS) .. ": " .. names(passes)
	end
	rows[#rows + 1] = { text = table.concat(counts, "  "), tooltip = choiceLines }
	local waitingLines = { (L["Not chosen: %d"]):format(#waiting) }
	if #waiting > 0 then
		waitingLines[#waitingLines + 1] = names(waiting)
	end
	rows[#rows + 1] = { text = (L["Not chosen: %d"]):format(#waiting), tooltip = waitingLines }
	for index, row in ipairs(rows) do
		local line = panel.lines[index]
		if row.squares then
			Panel.DrawSquares(panel, line, row.squares)
		else
			line.text:SetText(row.text)
			line.winner:SetShown(row.winner == true)
			if row.icon then
				line.icon:SetAtlas(row.icon)
				line.icon:Show()
			end
		end
		line.tooltip = row.tooltip
		line:Show()
	end
	resize(panel, #rows)
end

-- The ninjas' squares, a little indented, one in class colour each, with the
-- player's name and reasons in its tooltip and the right click on it; those
-- that do not fit as "+3".
Panel.SQUARE = 10
function Panel.DrawSquares(panel, line, ninjas)
	line.squares = line.squares or {}
	local fits = math.floor((Panel.WIDTH - 2 * Panel.PAD - Panel.ICON - 30) / (Panel.SQUARE + 2))
	for index, player in ipairs(ninjas) do
		if index > fits then
			break
		end
		local square = line.squares[index]
		if not square then
			square = CreateFrame("Button", nil, line)
			square:SetSize(Panel.SQUARE, Panel.SQUARE)
			square:SetPoint("LEFT", line, "LEFT", Panel.ICON + 4 + (index - 1) * (Panel.SQUARE + 2), 0)
			square:RegisterForClicks("RightButtonUp")
			square.color = square:CreateTexture(nil, "ARTWORK")
			square.color:SetAllPoints(square)
			square:SetScript("OnEnter", function(owner)
				showTooltip(owner, owner.tooltip)
			end)
			square:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			square:SetScript("OnClick", function(owner, button)
				if button == "RightButton" and panel.onRightClick and owner.player then
					panel.onRightClick(owner, owner.player, panel.view)
				end
			end)
			line.squares[index] = square
		end
		local color = player.class and Compat.GetClassColor(player.class)
		square.color:SetColorTexture(color and color.r or 0.5, color and color.g or 0.5, color and color.b or 0.5, 1)
		square.player = player
		square.tooltip = playerTooltip(player)
		square:Show()
	end
	line.text:SetText(#ninjas > fits and ("+%d"):format(#ninjas - fits) or "")
	line.text:ClearAllPoints()
	line.text:SetPoint("LEFT", line, "LEFT", Panel.ICON + 4 + math.min(#ninjas, fits) * (Panel.SQUARE + 2) + 2, 0)
end

-- Draws a view (Model.View, with what the marks add) on a panel.
function Panel.Draw(panel, view)
	clear(panel)
	panel.view = view
	if not view then
		panel.frame:Hide()
		return
	end
	if not view.bound then
		local line = panel.lines[1]
		line.text:SetText(L["Waiting for the rolls…"])
		line:Show()
		resize(panel, 1)
	elseif #view.players > Panel.GROUP then
		drawRaid(panel, view)
	else
		drawGroup(panel, view)
	end
	panel.frame:Show()
end

-- Shows a panel beside a frame with a view.
function Panel.Show(panel, frame, view)
	Panel.Place(panel, frame)
	panel.anchor = frame
	Panel.Draw(panel, view)
end

function Panel.Hide(panel)
	panel.frame:Hide()
	panel.view, panel.anchor, panel.rollID = nil, nil, nil
end
