local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The loot rolls: a panel at the side of each of the game's roll frames,
-- with who chose what on that roll and rolled what, in class colours, as it
-- happens (Panel.lua), from the model of the rolls and the loot history
-- (Model.lua, with the chat as a fallback, Chat.lua). Every drop seen in a
-- group goes into the history by group (History.lua, Groups.lua). The game's
-- roll frames keep working as they do: the module only hooks their showing
-- and hiding, and the player's choice.
local Rolls = ns.Modules:Register({
	name = "Rolls",
	title = L["Loot rolls"],
	switchLabel = L["Show Who Rolled What"],
	description = L["Beside the game's loot roll frames: who chose what and rolled what, in class colours, as it happens."],
	defaults = {
		enabled = true,
		-- Ninja detection, off until the player turns it on, and its checks.
		ninja = false,
		checkArmor = true,
		checkWeapons = true,
		checkStats = true,
		checkEverything = true,
		checkBoE = true,
		checkLastTime = true,
		strictness = "normal",
		minQuality = 2,
		spareFriends = true,
		summary = true,
		-- The live window, where the game does not open its own loot history window.
		liveWindow = true,
		-- The game's roll frames kept away: the rolls in the Loot Rolls window.
		hideGameFrames = false,
		-- The roll history's filters.
		historyMinQuality = 2,
		historyMarkedOnly = false,
	},
	-- On the switch's row: the roll history.
	switchButton = {
		label = L["Roll History"],
		tooltip = L["Opens the rolls kept in your groups: who chose what, who won and with which button."],
		onClick = function()
			ns.Rolls.HistoryWindow.Open()
		end,
	},
	-- Under the switch: the detection's checkbox with the Ninja Rules button
	-- beside it. The demo is a debug command's, not the player's.
	mainSettings = {
		{ kind = "custom", build = function(page, indent)
			page:AddCheckbox("Rolls", "liveWindow", L["Show the Loot Rolls Window After Your Choice"],
				L["Once you have chosen on a roll, a window shows it with the group's other rolls as they go, and keeps every item rolled on until you close it; not where the game opens its own loot history window."],
				indent, "Rolls")
			page:AddCheckbox("Rolls", "hideGameFrames", L["Hide the Game's Roll Frames"],
				L["The game's loot roll frames no longer show: each roll comes into the Loot Rolls window as it starts, at the top, with the buttons and a timer. Turning this off needs a reload."],
				indent, "Rolls", nil, nil, L["You then roll in the Loot Rolls window."])
			local check = page:AddCheckbox("Rolls", "ninja", L["Detect Ninja Looters"],
				L["Marks needs that look like ninja looting on the panels beside the game's roll frames, with the reasons in their tooltips."], indent, "Rolls")
			local row = check:GetParent()
			local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			button:SetSize(120, 22)
			-- Right after the label, whatever its length.
			button:SetPoint("LEFT", check.label, "RIGHT", 12, 0)
			-- Above the checkbox's hit area, which spans the row.
			button:SetFrameLevel(check:GetFrameLevel() + 2)
			button:SetText(L["Ninja Rules"])
			button:SetScript("OnClick", function()
				ns.Rolls.NinjaRules.Open()
			end)
			-- Greyed while the detection is off, the checkbox's own row with it.
			page:OnRefresh(function()
				button:SetEnabled(ns.Storage:Get("Rolls", "enabled") == true and ns.Storage:Get("Rolls", "ninja") == true)
			end)
			page.ninjaRules = button
		end },
	},
	-- What profile texts may hold for the choices of the Ninja Rules window.
	settings = function()
		return {
			{ kind = "choice", key = "strictness", choices = { { "lenient" }, { "normal" }, { "strict" } } },
			{ kind = "choice", key = "minQuality", choices = { { 2 }, { 3 }, { 4 } } },
			{ kind = "choice", key = "historyMinQuality", choices = { { 2 }, { 3 }, { 4 } } },
		}
	end,
})

local Model, Chat, Groups, History, Panel = ns.Rolls.Model, ns.Rolls.Chat, ns.Rolls.Groups, ns.Rolls.History, ns.Rolls.Panel
ns.Rolls.Module = Rolls


-- Whether the module works now: on, or starting (the registry calls it
-- active only once OnEnable is over).
local function on()
	return Rolls.active or Rolls.starting == true
end

-- One panel per game roll frame, by the frame.
local panels = {}
local hooked = {}
local chosenHooked = false

-- The view of a roll as its panel draws it; the marks (Marks.lua) add to it.
function Rolls.View(rollID)
	local view = Model.View(rollID)
	if view and ns.Rolls.Marks then
		ns.Rolls.Marks.Add(view)
	end
	return view
end

-- Draws a panel under xpcall: one that fails hides for its roll, the error
-- goes to the journal, and the game's frame is untouched, so rolling works.
local function draw(panel, frame, rollID)
	local ok = xpcall(function()
		Panel.Show(panel, frame, Rolls.View(rollID))
	end, Compat.ReportError)
	if not ok then
		panel.frame:Hide()
	end
end

local function show(frame)
	local panel = panels[frame]
	local rollID = frame.rollID
	if not on() or not panel or rollID == nil then
		return
	end
	Model.AddRoll(rollID)
	panel.rollID = rollID
	draw(panel, frame, rollID)
end

local function hide(frame)
	local panel = panels[frame]
	if panel then
		Panel.Hide(panel)
	end
end

-- Redraws the panel of a roll, wherever it is.
function Rolls.Redraw(rollID)
	for frame, panel in pairs(panels) do
		if panel.rollID == rollID and panel.anchor == frame then
			if Model.Roll(rollID) then
				draw(panel, frame, rollID)
			else
				Panel.Hide(panel)
			end
		end
	end
end

function Rolls.RedrawAll()
	for frame, panel in pairs(panels) do
		if panel.rollID and panel.anchor == frame then
			Rolls.Redraw(panel.rollID)
		end
	end
	ns.Rolls.LiveWindow.Redraw()
	ns.Rolls.HistoryWindow.Changed()
end

-- The game's roll frames kept away while *Hide the Game's Roll Frames* is on:
-- each roll comes into the Loot Rolls window instead. Done once a session,
-- as the option turns on or the module starts with it on; a client that
-- routes its roll frames otherwise keeps them, with a line saying so. Only a
-- reload brings them back, which a dialog offers when the option or the
-- loot rolls are turned off.
local framesAway = false

function Rolls.GameFramesAway()
	return framesAway
end

local function keepFramesAway()
	if framesAway or not ns.Storage:Get("Rolls", "hideGameFrames") then
		return
	end
	if Compat.KeepGameRollFramesAway() then
		framesAway = true
	else
		ns.Print(L["This client shows its roll frames in a way Lootoman cannot hold back, so they stay."])
	end
end

local function askReload()
	ns.NameMenu.Confirm(L["The game's roll frames come back after a reload. Reload now?"], nil, L["Reload"], function()
		Compat.ReloadUI()
	end)
end

-- An item's stats are asked for: once an item comes in, the marks are
-- judged again; the module listens only while it waits.
local waiting = false
function Rolls.WaitForItem()
	if waiting or not on() then
		return
	end
	waiting = true
	Rolls:OnEvent("ITEM_DATA_LOAD_RESULT", function()
		waiting = false
		ns.Bus:OffEvent("ITEM_DATA_LOAD_RESULT", Rolls)
		Rolls.RedrawAll()
	end)
end

-- The right click on a marked name or square, and leaving a group: the
-- exceptions (SuspiciousNeeds.lua).
function Rolls.OnRightClick(owner, player, view)
	ns.Rolls.SuspiciousNeeds.Menu(owner, player, view)
end

function Rolls.OnGroupLeft(group)
	ns.Rolls.SuspiciousNeeds.GroupLeft(group)
end

-- The panel of a game roll frame (for tests and the demo's place).
function Rolls.PanelOf(frame)
	return panels[frame]
end

Model.Subscribe(function(kind, value)
	if not on() then
		return
	end
	if kind == "roll" then
		Rolls.Redraw(value)
	elseif kind == "drop" then
		if Groups.Current() then
			History.Record(value)
			ns.Rolls.HistoryWindow.Changed()
		end
	end
	ns.Rolls.LiveWindow.OnModel(kind, value)
end)

local function hookFrames()
	for _, frame in ipairs(Compat.GetGameRollFrames()) do
		if not panels[frame] then
			panels[frame] = Panel.New()
			panels[frame].onRightClick = function(...)
				if Rolls.OnRightClick then
					Rolls.OnRightClick(...)
				end
			end
		end
		if not hooked[frame] then
			hooked[frame] = true
			frame:HookScript("OnShow", show)
			frame:HookScript("OnHide", hide)
		end
	end
end

function Rolls:OnEnable()
	Rolls.starting = true
	hookFrames()
	ns.Rolls.LiveWindow.Build()
	-- In Edit Mode, the roll frames' look-alikes get panels of made-up choices.
	self:On("RollFramesPreview", function(_, active, frames, strata, level)
		if active then
			ns.Rolls.Demo.Preview(frames, strata, level)
		else
			ns.Rolls.Demo.EndPreview()
		end
	end)
	if not chosenHooked then
		chosenHooked = true
		Compat.OnRollChosen(function(rollID, rollType)
			if Rolls.active then
				Model.Chose(rollID, rollType)
				ns.Rolls.LiveWindow.Chose(rollID)
			end
		end)
	end
	-- New rules or checks mean new marks.
	self:On("NeedRulesChanged", function()
		ns.Rolls.Marks.Invalidate()
		Rolls.RedrawAll()
	end)
	self:On("SettingChanged", function(_, module, key, value)
		if module == Rolls.name then
			if key == "hideGameFrames" then
				if value then
					keepFramesAway()
				elseif framesAway then
					askReload()
				end
			end
			ns.Rolls.Marks.Invalidate()
			Rolls.RedrawAll()
		end
	end)
	keepFramesAway()
	self:OnEvent("START_LOOT_ROLL", function(_, rollID)
		Model.AddRoll(rollID)
		Compat.After(Chat.WAIT, function()
			if Rolls.active then
				Chat.Use(rollID)
			end
		end)
	end)
	self:OnEvent("CANCEL_LOOT_ROLL", function(_, rollID)
		Model.RemoveRoll(rollID)
	end)
	self:OnEvent("CANCEL_ALL_LOOT_ROLLS", function()
		for _, roll in ipairs(Model.Rolls()) do
			Model.RemoveRoll(roll.rollID)
		end
	end)
	self:OnEvent("LOOT_HISTORY_UPDATE_DROP", function(_, encounterID, listID)
		Model.UpdateDrop(encounterID, listID)
	end)
	self:OnEvent("LOOT_HISTORY_UPDATE_ENCOUNTER", function()
		Model.RefreshDrops()
	end)
	self:OnEvent("LOOT_HISTORY_CLEAR_HISTORY", function()
		Model.ClearDrops()
	end)
	self:OnEvent("CHAT_MSG_LOOT", function(_, text)
		Chat.Hear(text)
	end)
	self:OnEvent("GROUP_JOINED", function(_, category, partyGUID)
		Groups.Joined(category, partyGUID)
	end)
	self:OnEvent("GROUP_LEFT", function(_, category, partyGUID)
		local left = History.Open()
		Groups.Left(category, partyGUID)
		if left and left.ended and Rolls.OnGroupLeft then
			Rolls.OnGroupLeft(left)
		end
	end)
	Groups.Login()
	Model.RefreshDrops()
	-- Rolls open before a /reload: the game shows their frames again.
	for _, rollID in ipairs(Compat.GetActiveRolls()) do
		Model.AddRoll(rollID)
	end
	for frame in pairs(panels) do
		if frame:IsShown() then
			show(frame)
		end
	end
	Rolls.starting = false
end

function Rolls:OnDisable()
	Rolls.starting = false
	-- With the game's frames kept away, the rolls would have nowhere to go.
	if framesAway then
		askReload()
	end
	waiting = false
	ns.Rolls.Demo.EndPreview()
	-- The played demo, in the repository's version only.
	if ns.Rolls.Demo.Stop then
		ns.Rolls.Demo.Stop()
	end
	ns.Rolls.LiveWindow.Hide()
	ns.Rolls.HistoryWindow.Hide()
	for _, panel in pairs(panels) do
		Panel.Hide(panel)
	end
	Model.Clear()
	Chat.Reset()
end
