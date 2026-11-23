local _, ns = ...
local Bus, Compat, L = ns.Bus, ns.Compat, ns.L

-- Moving the game's roll frames in Edit Mode, a module of its own, on by
-- default, working while the loot rolls are tracked (Track Loot Rolls), in
-- whose block its checkbox stands: a frame of its own in Edit Mode, Loot Roll Frames,
-- with a place per Edit Mode layout. While it has never been moved, the game
-- places its roll frames as always. Once moved, after each of the game's
-- layouts of them (GroupLootContainer_Update) the four frames stand on its
-- place, stacked upwards 100 pixels apart as the game stacks them, and the
-- loot rolls' panels beside them follow. The game's container stays where it
-- is: it is one of the bottom managed frames, beside the extra action button,
-- and moving it would lay them all out from the addon's code. The roll frames
-- are not protected, so moving them in a fight is allowed. Reset To Default
-- and turning the module off give the game its place back.
--
-- In Edit Mode two look-alikes of the game's roll frame stand on its place,
-- and, while Show Who Rolled What is on, their panels beside them, all of them
-- under Edit Mode's selection. The Edit button beside the checkbox opens
-- Edit Mode with this frame picked: a secure button runs the game's own
-- /editmode, so the game opens Edit Mode itself.
local RollFrames = ns.Modules:Register({
	name = "RollFrames",
	title = L["Loot roll frames"],
	switchLabel = L["Move the Loot Roll Frames in Edit Mode"],
	description = L["Lets you place the game's loot roll frames where you want in Edit Mode, a place for each Edit Mode layout. Until you move them, the game places them as always."],
	switchNote = L["In Edit Mode (the game menu, Edit Mode), drag “Loot Roll Frames”."],
	requires = "Rolls",
	defaults = { enabled = true },
	switchButton = {
		label = L["Edit"],
		tooltip = L["Opens Edit Mode with the loot roll frames picked."],
		macro = "/editmode",
		preClick = function()
			if ns.RollFrames.frame then
				ns.EditMode.PickWhenOpen(ns.RollFrames.frame)
			end
		end,
	},
})

RollFrames.KEY = "RollFrames"
RollFrames.WIDTH, RollFrames.HEIGHT = 277, 200
-- Bottom centre, above the action bars, about where the game stacks them.
RollFrames.DEFAULT = { point = "BOTTOM", x = 0, y = 230 }
-- The room the game leaves per roll frame.
RollFrames.SLOT = 100
-- In Edit Mode the look-alikes and the panels stand under the selection,
-- whose template fixes it at MEDIUM, frame level 1000: on MEDIUM too, lower.
-- Out of Edit Mode (the demo, real rolls) they are on DIALOG, as the game's
-- roll frames are.
RollFrames.PREVIEW_STRATA, RollFrames.PREVIEW_LEVEL = "MEDIUM", 100
-- How far right of the frames the loot rolls' panels reach: their gap and width.
RollFrames.PANELS = 4 + 190
ns.RollFrames = RollFrames

-- In profile texts (Share): where the frames were moved, under this module's settings.
ns.EditMode.SharePosition(RollFrames.name, RollFrames.KEY)

local hooked = false
local panelsOn = false
local cards = {}

local function on()
	return RollFrames.active or RollFrames.starting == true
end

-- Whether the player moved the frames in the Edit Mode layout in use.
function RollFrames.Moved()
	return RollFrames.frame ~= nil and on() and ns.EditMode.HasPosition(RollFrames.frame)
end

-- The look-alikes' place follows: the frame in Edit Mode or once moved.
local function updateAnchor()
	local frame = RollFrames.frame
	if frame and on() and (ns.EditMode.IsActive() or ns.EditMode.HasPosition(frame)) then
		ns.RollLookalike.anchor = frame
	else
		ns.RollLookalike.anchor = nil
	end
end

-- The game's frames on our place, as the game stacks them.
function RollFrames.Apply()
	updateAnchor()
	if not RollFrames.Moved() then
		return
	end
	for _, slot in ipairs(Compat.GetGameRollSlots()) do
		slot.frame:ClearAllPoints()
		slot.frame:SetPoint("CENTER", RollFrames.frame, "BOTTOM", 0, RollFrames.SLOT * (slot.slot - 0.5))
	end
end

-- The game's frames back on the game's place, as its layout puts them.
function RollFrames.Restore()
	local container = Compat.GetGameRollContainer()
	if not container then
		return
	end
	for _, slot in ipairs(Compat.GetGameRollSlots()) do
		slot.frame:ClearAllPoints()
		slot.frame:SetPoint("CENTER", container, "BOTTOM", 0, RollFrames.SLOT * (slot.slot - 0.5))
	end
end

-- Edit Mode's selection over the frame, and over the panels at its right
-- while they show.
local function fitSelection()
	local selection = ns.EditMode.Selection(RollFrames.frame)
	if not (selection and selection.SetPoint) then
		return
	end
	selection:ClearAllPoints()
	selection:SetPoint("TOPLEFT", RollFrames.frame, "TOPLEFT", 0, 0)
	selection:SetPoint("BOTTOMRIGHT", RollFrames.frame, "BOTTOMRIGHT", panelsOn and RollFrames.PANELS or 0, 0)
end

-- Edit Mode's look-alikes show the demo's items if the game has them, else
-- worn gear (a pair of trousers will do).
local function preview(active)
	updateAnchor()
	local frames = {}
	if active then
		RollFrames.frame:Show()
		fitSelection()
		local items = ns.RollLookalike.Items()
		for slot = 1, 2 do
			local card = cards[slot] or ns.RollLookalike.New()
			cards[slot] = card
			card.frame:SetFrameStrata(RollFrames.PREVIEW_STRATA)
			card.frame:SetFrameLevel(RollFrames.PREVIEW_LEVEL)
			ns.RollLookalike.Fill(card, items[slot])
			ns.RollLookalike.Place(card, slot)
			card.frame:Show()
			frames[slot] = card.frame
		end
	else
		for _, card in ipairs(cards) do
			card.frame:Hide()
		end
		RollFrames.frame:Hide()
		if RollFrames.Moved() then
			RollFrames.Apply()
		else
			RollFrames.Restore()
		end
	end
	Bus:Send("RollFramesPreview", active, frames, RollFrames.PREVIEW_STRATA, RollFrames.PREVIEW_LEVEL)
end

-- The look-alikes shown in Edit Mode, for tests.
function RollFrames.Cards()
	return cards
end

function RollFrames:OnEnable()
	RollFrames.starting = true
	if not RollFrames.frame then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(RollFrames.WIDTH, RollFrames.HEIGHT)
		frame:SetPoint(RollFrames.DEFAULT.point, RollFrames.DEFAULT.x, RollFrames.DEFAULT.y)
		frame:SetMovable(true)
		frame:Hide()
		RollFrames.frame = frame
		ns.EditMode.Register(RollFrames, frame, {
			key = RollFrames.KEY,
			name = L["Loot Roll Frames"],
			default = RollFrames.DEFAULT,
			onEditMode = preview,
		})
	end
	if not hooked then
		hooked = true
		Compat.AfterGameRollLayout(function()
			if on() then
				RollFrames.Apply()
			end
		end)
	end
	-- Whether the loot rolls' panels show, for the selection's width: the
	-- loot rolls on, with Show Who Rolled What, the game's frames not hidden.
	local function updatePanels()
		local rolls = ns.Modules:Get("Rolls")
		panelsOn = rolls ~= nil and rolls:IsActive() and ns.Storage:Get("Rolls", "panels") == true
			and not (rolls.GameFramesAway and rolls.GameFramesAway())
	end
	updatePanels()
	self:On("ModuleToggled", function(_, name)
		if name == "Rolls" then
			updatePanels()
			fitSelection()
		end
	end)
	self:On("SettingChanged", function(_, module)
		if module == "Rolls" then
			updatePanels()
			fitSelection()
		end
	end)
	RollFrames.Apply()
	RollFrames.starting = false
end

function RollFrames:OnDisable()
	RollFrames.starting = false
	local wasMoved = RollFrames.frame ~= nil and ns.EditMode.HasPosition(RollFrames.frame)
	ns.RollLookalike.anchor = nil
	for _, card in ipairs(cards) do
		card.frame:Hide()
	end
	if RollFrames.frame then
		RollFrames.frame:Hide()
	end
	if wasMoved then
		RollFrames.Restore()
	end
end

-- In the bug report, under the options.
ns.BugReport.AddPart(function()
	return { ("Loot roll frames: %s; %s"):format(ns.Storage:Get("RollFrames", "enabled") and "movable" or "the game's",
		RollFrames.Moved() and "moved" or "in the game's place") }
end)
