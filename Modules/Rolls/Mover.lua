local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Moving the game's roll frames in Edit Mode: a frame of its own, Loot Roll
-- Frames, with a place per Edit Mode layout. While it has never been moved,
-- the game places its roll frames as always. Once moved, after each of the
-- game's layouts of them (GroupLootContainer_Update) the four frames stand on
-- our place, stacked upwards 100 pixels apart as the game stacks them, and
-- the panels beside them follow. The game's container stays where it is: it
-- is one of the bottom managed frames, beside the extra action button, and
-- moving it would lay them all out from our code. The roll frames are not
-- protected, so moving them in a fight is allowed. Reset Position in Edit
-- Mode gives the game its place back. In Edit Mode the demo's look-alikes
-- show where the frames will stand.
ns.Rolls = ns.Rolls or {}
local Mover = {}
ns.Rolls.Mover = Mover

Mover.KEY = "RollFrames"
Mover.WIDTH, Mover.HEIGHT = 277, 200
-- Bottom centre, above the action bars, about where the game stacks them.
Mover.DEFAULT = { point = "BOTTOM", x = 0, y = 230 }
-- The room the game leaves per roll frame.
Mover.SLOT = 100

local frame
local hooked = false

local function active()
	local module = ns.Rolls.Module
	return module and (module.active or module.starting == true)
end

-- Whether the player moved the frames in the Edit Mode layout in use.
function Mover.Moved()
	return frame ~= nil and ns.EditMode.HasPosition(frame)
end

-- What the look-alikes and the game's frames stand on: the mover in Edit
-- Mode or once moved, else nil (the game's place).
function Mover.Anchor()
	if frame and (ns.EditMode.IsActive() or Mover.Moved()) then
		return frame
	end
	return nil
end

-- The game's frames on our place, as the game stacks them.
function Mover.Apply()
	if not frame or not Mover.Moved() then
		return
	end
	for _, slot in ipairs(Compat.GetGameRollSlots()) do
		slot.frame:ClearAllPoints()
		slot.frame:SetPoint("CENTER", frame, "BOTTOM", 0, Mover.SLOT * (slot.slot - 0.5))
	end
end

-- The game's frames back on the game's place, as its layout puts them.
function Mover.Restore()
	local container = Compat.GetGameRollContainer()
	if not container then
		return
	end
	for _, slot in ipairs(Compat.GetGameRollSlots()) do
		slot.frame:ClearAllPoints()
		slot.frame:SetPoint("CENTER", container, "BOTTOM", 0, Mover.SLOT * (slot.slot - 0.5))
	end
end

local function preview(on)
	if on then
		frame:Show()
		ns.Rolls.Demo.Start(true)
	else
		ns.Rolls.Demo.Stop()
		frame:Hide()
		if Mover.Moved() then
			Mover.Apply()
		else
			Mover.Restore()
		end
	end
end

-- Made once, when the module first starts (out of combat): the frame and its
-- place in Edit Mode, and the hook on the game's layout.
function Mover.Create(module)
	if not frame then
		frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(Mover.WIDTH, Mover.HEIGHT)
		frame:SetPoint(Mover.DEFAULT.point, Mover.DEFAULT.x, Mover.DEFAULT.y)
		frame:SetMovable(true)
		frame:Hide()
		ns.EditMode.Register(module, frame, {
			key = Mover.KEY,
			name = L["Loot Roll Frames"],
			default = Mover.DEFAULT,
			onEditMode = preview,
		})
	end
	if not hooked then
		hooked = true
		Compat.AfterGameRollLayout(function()
			if active() then
				Mover.Apply()
			end
		end)
	end
	Mover.Apply()
end

-- The frame, for tests.
function Mover.Frame()
	return frame
end
