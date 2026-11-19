local _, ns = ...
local L = ns.L

-- The bag button: it opens the toss window from the bags, in the middle of the
-- screen. By the setting (bagButton): small, in the bag window's title left
-- of its close button; large, above the bag window over its close button;
-- large, on its own, placed in Edit Mode and sized in its dialog; or never.
--
-- In the bag window it is a child of the game's combined bag window and of
-- the backpack (when the bags are separate), so it shows and hides with them;
-- nothing of Blizzard's is changed or hooked. A bag addon that replaces the
-- game's bags leaves those windows closed: there, the button on its own and
-- /ltm junk open the window.
local Junk = ns.Modules:Get("Junk")
local BagButton = {}
Junk.BagButton = BagButton

BagButton.SMALL = 20
-- The large button over the bag window: as big as the loot window's, this
-- far above the window (its slot texture reaches past the button).
BagButton.LARGE = 37
BagButton.RAISE = 14
BagButton.DEFAULT_POSITION = { point = "BOTTOMRIGHT", x = -300, y = 120 }

local inBags = {}
local own
local active = false

local function click()
	if Junk.Toss and not ns.EditMode.IsActive() then
		Junk.Toss.Toggle(false)
	end
end

local function placeInBag(button, bag, style)
	button:ClearAllPoints()
	button.slot:SetShown(style == "large")
	local close = bag.CloseButton
	if style == "small" then
		button:SetSize(BagButton.SMALL, BagButton.SMALL)
		if close then
			button:SetPoint("RIGHT", close, "LEFT", -2, 0)
		else
			button:SetPoint("TOPRIGHT", bag, "TOPRIGHT", -24, -2)
		end
	else
		Junk.TossButton.Fit(button, BagButton.LARGE)
		button:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", -4, BagButton.RAISE)
	end
end

local function update()
	local style = Junk:Get("bagButton")
	for bag, button in pairs(inBags) do
		local shown = active and (style == "small" or style == "large")
		if shown then
			placeInBag(button, bag, style)
		end
		button:SetShown(shown)
	end
	if own then
		Junk.TossButton.Fit(own, Junk:Get("bagButtonSize"))
		own:SetShown(active and style == "own")
	end
end

-- The game's bag windows that get a button, those this client has: the
-- combined bag window and the backpack.
local function bagFrames()
	local found = {}
	for _, frame in ipairs({ ContainerFrameCombinedBags or false, ContainerFrame1 or false }) do
		if frame then
			found[#found + 1] = frame
		end
	end
	return found
end

local function create()
	for _, bag in ipairs(bagFrames()) do
		local button = Junk.TossButton.New(bag, click)
		button:SetFrameLevel((bag.CloseButton or bag):GetFrameLevel() + (bag.CloseButton and 0 or 5))
		inBags[bag] = button
	end
	own = Junk.TossButton.New(UIParent, click)
	own:SetFrameStrata("MEDIUM")
	own:SetClampedToScreen(true)
	local position = BagButton.DEFAULT_POSITION
	own:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	ns.EditMode.Register(Junk, own, {
		key = "BagButton",
		-- In Edit Mode's title case, as its own frames are named.
		name = L["Throw Away Junk"],
		default = position,
		settings = { { kind = "slider", key = "bagButtonSize", label = L["Size"], min = 24, max = 64, step = 1,
			format = "%d" } },
	})
end

-- The button in a bag window (by the window), and the one on its own, once
-- the module has started.
function BagButton.InBag(bag)
	return inBags[bag]
end

function BagButton.Own()
	return own
end

Junk.AddPart({
	Enable = function()
		if not own then
			create()
		end
		active = true
		Junk.Listen("SettingChanged", function(_, module)
			if module == Junk.name then
				update()
			end
		end)
		Junk.Listen("ProfileChanged", update)
		update()
	end,
	Disable = function()
		active = false
		update()
	end,
})
