local _, ns = ...
local Compat, L, Storage = ns.Compat, ns.L, ns.Storage

-- Exceptions: a need the group agreed to ("he asked in the chat") is excused
-- and counts no more. A right click on a marked name on a panel, or on a
-- raid's square, excuses it or takes that back; and when the character
-- leaves a group with marked needs, the Suspicious Needs window lists them,
-- each with an Exception checkbox (with the detection and its summary on).
-- Left in a fight, the window waits for its end; it is built the first time
-- it opens, out of combat. Exceptions are kept in the roll history; in the
-- demo they touch only the demo.
ns.Rolls = ns.Rolls or {}
local Suspicious = {}
ns.Rolls.SuspiciousNeeds = Suspicious

local History, Marks = ns.Rolls.History, ns.Rolls.Marks
local Need = ns.Rules.Need

Suspicious.NAME = "LootomanSuspiciousNeeds"
Suspicious.WIDTH, Suspicious.HEIGHT = 620, 400
Suspicious.ROW = 34

-- Excuses a need on a real roll (in the open group's history) or on the
-- demo's, or takes it back.
function Suspicious.SetExcused(view, player, excused)
	if view.demo then
		ns.Rolls.Demo.SetExcused(view, player.guid, excused)
		return
	end
	local group = History.Open()
	local key = view.drop and view.drop.key
	if not group or not key or not player.guid then
		return
	end
	if not History.Find(group, key) then
		History.Record(view.drop)
	end
	History.SetExcused(group, key, player.guid, excused)
	Marks.Invalidate()
	ns.Rolls.Module.RedrawAll()
	if Suspicious.refresh then
		Suspicious.refresh()
	end
end

-- The right click's menu on a marked or excused need.
function Suspicious.Menu(owner, player, view)
	if not Storage:Get("Rolls", "ninja") or not view or not Need.IsNeed(player.state) or not (player.mark or player.excused) then
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		if player.excused then
			root:CreateButton(L["Undo the Exception"], function()
				Suspicious.SetExcused(view, player, false)
			end)
		else
			root:CreateButton(L["Exception: Agreed in the Chat"], function()
				Suspicious.SetExcused(view, player, true)
			end)
		end
	end)
end

-- The marked and excused needs of a closed group, judged as the panels did:
-- { name, class, link, reasons, excused, set = fn(excused) }.
function Suspicious.Rows(group)
	local rows = {}
	for _, entry in ipairs(group and group.drops or {}) do
		local players = {}
		for index, kept in ipairs(entry.rolls) do
			players[index] = { name = kept.name, guid = kept.guid, class = kept.class, level = kept.level, state = kept.state, roll = kept.roll }
		end
		local view = { bound = true, link = entry.link, players = players, drop = { key = entry.key } }
		Marks.Add(view, { group = group })
		for _, player in ipairs(view.players) do
			if player.mark then
				rows[#rows + 1] = {
					name = player.name,
					class = player.class,
					link = entry.link,
					reasons = player.notes or { L["Excused"] },
					excused = player.excused == true,
					set = function(excused)
						History.SetExcused(group, entry.key, player.guid, excused)
						Marks.Invalidate()
						ns.Rolls.Module.RedrawAll()
					end,
				}
			end
		end
	end
	return rows
end

local frame

local function newRow(index)
	local row = CreateFrame("Frame", nil, frame.content)
	row:SetSize(Suspicious.WIDTH - 60, Suspicious.ROW)
	row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(index - 1) * Suspicious.ROW)
	row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.who:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2)
	row.who:SetWidth(150)
	row.who:SetJustifyH("LEFT")
	row.item = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.item:SetPoint("LEFT", row.who, "RIGHT", 6, 0)
	row.item:SetWidth(250)
	row.item:SetJustifyH("LEFT")
	row.reasons = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.reasons:SetPoint("TOPLEFT", row.who, "BOTTOMLEFT", 0, -2)
	row.reasons:SetWidth(Suspicious.WIDTH - 170)
	row.reasons:SetJustifyH("LEFT")
	row.exception = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.exception:SetSize(22, 22)
	row.exception:SetPoint("TOPRIGHT", row, "TOPRIGHT", -70, 0)
	row.exception.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.exception.label:SetPoint("LEFT", row.exception, "RIGHT", 2, 0)
	row.exception.label:SetText(L["Exception"])
	row.exception:SetScript("OnClick", function(check)
		if row.data then
			row.data.set(check:GetChecked() == true)
			Suspicious.Refresh()
		end
	end)
	return row
end

local function build()
	frame = CreateFrame("Frame", Suspicious.NAME, UIParent, "DefaultPanelFlatTemplate")
	frame:Hide()
	frame:SetSize(Suspicious.WIDTH, Suspicious.HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Suspicious Needs"])
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	table.insert(UISpecialFrames, Suspicious.NAME)
	frame.intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.intro:SetPoint("TOPLEFT", 20, -34)
	frame.intro:SetPoint("TOPRIGHT", -20, -34)
	frame.intro:SetJustifyH("LEFT")
	frame.intro:SetText(L["The needs marked in the group you left. Tick those the group agreed to: they are excused and count no more."])
	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", 20, -70)
	frame.scroll:SetPoint("BOTTOMRIGHT", -36, 16)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetSize(Suspicious.WIDTH - 60, 1)
	frame.scroll:SetScrollChild(frame.content)
	frame.rows = {}
end

-- Draws the rows the window's source gives now.
function Suspicious.Refresh()
	if not frame or not frame.source then
		return
	end
	local rows = frame.source()
	for index, data in ipairs(rows) do
		local row = frame.rows[index] or newRow(index)
		frame.rows[index] = row
		row.data = data
		row.who:SetText(ns.Rolls.Panel.ClassName(data.name, data.class))
		row.item:SetText(data.link or "")
		row.reasons:SetText(table.concat(data.reasons, "; "))
		row.exception:SetChecked(data.excused)
		row:Show()
	end
	for index = #rows + 1, #frame.rows do
		frame.rows[index]:Hide()
		frame.rows[index].data = nil
	end
	frame.content:SetHeight(math.max(1, #rows * Suspicious.ROW))
	frame.count = #rows
end

-- Opens the window on a source of rows (a function giving them); the first
-- time, out of combat only.
function Suspicious.Open(source)
	if not frame then
		if Compat.InCombat() then
			return false
		end
		build()
	end
	frame.source = source
	Suspicious.refresh = Suspicious.Refresh
	Suspicious.Refresh()
	frame:Show()
	return true
end

-- After leaving a group: its marked needs, if there are any, now or after the fight.
function Suspicious.GroupLeft(group)
	if not Storage:Get("Rolls", "ninja") or not Storage:Get("Rolls", "summary") then
		return
	end
	local function source()
		return Suspicious.Rows(group)
	end
	if #source() == 0 then
		return
	end
	local module = ns.Rolls.Module
	if Compat.InCombat() then
		module:OnEvent("PLAYER_REGEN_ENABLED", function()
			ns.Bus:OffEvent("PLAYER_REGEN_ENABLED", module)
			Suspicious.Open(source)
		end)
		return
	end
	Suspicious.Open(source)
end

-- The window, for tests.
function Suspicious.Frame()
	return frame
end
