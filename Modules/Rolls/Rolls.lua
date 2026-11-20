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
	},
	-- Under the switch: the detection's checkbox with the Ninja Rules button
	-- beside it, then the demo.
	mainSettings = {
		{ kind = "custom", build = function(page, indent)
			local check = page:AddCheckbox("Rolls", "ninja", L["Detect Ninja Looters"],
				L["Marks needs that look like ninja looting on the panels beside the game's roll frames, with the reasons in their tooltips."], indent, "Rolls")
			local row = check:GetParent()
			local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			button:SetSize(120, 22)
			button:SetPoint("LEFT", row, "LEFT", ns.SettingsPanel.CONTROL_X - ns.SettingsPanel.LEFT - indent, 0)
			-- Above the checkbox's hit area, which spans the row.
			button:SetFrameLevel(check:GetFrameLevel() + 2)
			button:SetText(L["Ninja Rules"])
			button:SetScript("OnClick", function()
				ns.Rolls.NinjaRules.Open()
			end)
			page:OnRefresh(function()
				button:SetEnabled(ns.Storage:Get("Rolls", "enabled") == true)
			end)
			page.ninjaRules = button
		end },
		{ kind = "button", label = L["Show Demo"], tooltip = L["Two rolls with made-up players play beside look-alikes of the game's roll frames, where the real ones stand."],
			click = function()
				ns.Rolls.Demo.Start()
			end },
	},
	-- What profile texts may hold for the choices of the Ninja Rules window.
	settings = function()
		return {
			{ kind = "choice", key = "strictness", choices = { { "lenient" }, { "normal" }, { "strict" } } },
			{ kind = "choice", key = "minQuality", choices = { { 2 }, { 3 }, { 4 } } },
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
		end
	end
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
	if not chosenHooked then
		chosenHooked = true
		Compat.OnRollChosen(function(rollID, rollType)
			if Rolls.active then
				Model.Chose(rollID, rollType)
			end
		end)
	end
	-- New rules or checks mean new marks.
	self:On("NeedRulesChanged", function()
		ns.Rolls.Marks.Invalidate()
		Rolls.RedrawAll()
	end)
	self:On("SettingChanged", function(_, module)
		if module == Rolls.name then
			ns.Rolls.Marks.Invalidate()
			Rolls.RedrawAll()
		end
	end)
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
	waiting = false
	ns.Rolls.Demo.Stop()
	for _, panel in pairs(panels) do
		Panel.Hide(panel)
	end
	Model.Clear()
	Chat.Reset()
end
