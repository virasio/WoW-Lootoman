local _, ns = ...
local Compat = ns.Compat

-- The sparkles of gathering highlights: one look for every kind of object, in
-- the default UI's gold or the player's colour, and light: six small stars that light up at random
-- points around the object and fade, nothing else. The game's own art, the
-- cooldown "bling" star, blended additively.
--
-- The effect is one frame, made when highlights start. While an object
-- sparkles it hangs on the object's nameplate, a little below it, where the
-- object is (the distance is the one Forever Loot Sparkles - Herbs & Ores
-- found); it follows the plate and its scale, keeps its own alpha, and our
-- frame is not protected, so this is allowed in combat too. The plate's own
-- frame stays invisible under it, so an object shows no bar or name from the
-- game, and is shown again when the sparkles leave. On a corpse's plate
-- (whole) everything else on it goes invisible too: a nameplate addon draws a
-- unit's whole plate there, its health bar and name over our label; what is
-- protected is left alone. Each frame gets back the alpha its owner last gave
-- it.
--
-- How bright: in reach the player's intensity, out of reach about 60 % of
-- it, not usable yet about 30 %. A new state shows only once it has held for a moment,
-- so the sparkles don't flicker at the edge of reach (Lueur's lesson), and
-- the brightness fades to it.
--
-- Above the stars, at the plate's centre, a label may show the object's
-- icon (the cursor the game would show over it) and its name under it, as
-- Lueur does: our own, as the game's icon stays off over a sparkling object
-- (GameSettings) and the plate's own frame, which holds the game's name, is
-- invisible. The label is a child of the effect, so it shows and goes with
-- the stars, but its alpha is its own (the player's opacity for it), not the
-- stars' intensity or state. The name may be a secret value: it goes only to
-- SetText, and the backdrop is anchored to the text's edges, not sized from
-- its width.
--
-- On an object's plate, what other addons hang there is not looked at: a
-- nameplate addon draws at most an icon on an object's plate, and another
-- addon that lights objects simply shows beside the stars.
ns.Highlights = ns.Highlights or {}
local Sparkles = {}
ns.Highlights.Sparkles = Sparkles

Sparkles.GOLD = { 1, 0.82, 0 }
Sparkles.STAR = [[Interface\Cooldown\star4]]
Sparkles.SIZE = 72
Sparkles.OFFSET = -45
Sparkles.STARS = 6
Sparkles.ALPHA = { ready = 1, far = 0.6, locked = 0.3 }
Sparkles.HOLD = 0.15
Sparkles.FADE = 0.25
-- The label's icon, about the size of the game's own.
Sparkles.ICON = 24
-- The name's styles: the font's flags, whether it keeps the game's shadow,
-- and whether a dark strip goes behind it.
Sparkles.STYLES = {
	shadow = { flags = "", shadow = true },
	outline = { flags = "OUTLINE" },
	thick = { flags = "THICKOUTLINE" },
	backdrop = { flags = "", shadow = true, backdrop = true },
}
Sparkles.BACKDROP = { 0, 0, 0, 0.6 }

local effect
-- The frames hidden under the sparkles, each with the alpha to give back,
-- and whether we are setting an alpha ourselves.
local veiled, ours = {}, false
local hooked = setmetatable({}, { __mode = "k" })

-- The owner sets the alpha again (the game's nameplate code, a nameplate
-- addon): it is kept for later, and the frame stays hidden.
local function keepVeiled(frame, alpha)
	if veiled[frame] ~= nil and not ours then
		veiled[frame] = alpha
		if alpha ~= 0 then
			ours = true
			frame:SetAlpha(0)
			ours = false
		end
	end
end

local function unveil()
	local frames = veiled
	veiled = {}
	for frame, alpha in pairs(frames) do
		frame:SetAlpha(alpha)
	end
end

local function hide(frame)
	if veiled[frame] ~= nil then
		return
	end
	if not hooked[frame] then
		hooked[frame] = true
		hooksecurefunc(frame, "SetAlpha", keepVeiled)
	end
	veiled[frame] = frame:GetAlpha() or 1
	ours = true
	frame:SetAlpha(0)
	ours = false
end

-- The plate's own frame, and with whole every other frame on it but ours
-- and the protected ones.
local function veil(plate, whole)
	unveil()
	if type(plate) ~= "table" then
		return
	end
	local unitFrame = plate.UnitFrame
	if type(unitFrame) == "table" and unitFrame.SetAlpha then
		hide(unitFrame)
	end
	if whole and plate.GetChildren then
		for _, child in ipairs({ plate:GetChildren() }) do
			if child ~= effect and type(child) == "table" and child.SetAlpha and not child:IsProtected() then
				hide(child)
			end
		end
	end
end

local random = math.random

-- A star starts again somewhere around the centre, faster when in reach.
local function respawn(star, state)
	local radius = Sparkles.SIZE * 0.4
	local angle = random() * 2 * math.pi
	local distance = radius * math.sqrt(random())
	star.x, star.y = math.cos(angle) * distance, math.sin(angle) * distance
	star.age = -random() * 0.6
	star.life = (0.7 + random() * 0.6) * (state == "ready" and 0.8 or 1)
	star.size = 10 + random() * 10
end

local function animate(frame, elapsed)
	-- A new state, once it has held.
	if frame.pending then
		frame.pendingFor = frame.pendingFor + elapsed
		if frame.pendingFor >= Sparkles.HOLD then
			frame.state, frame.pending = frame.pending, nil
		end
	end
	local target = Sparkles.ALPHA[frame.state] or 1
	local step = elapsed / Sparkles.FADE
	frame.level = frame.level + math.max(-step, math.min(step, target - frame.level))
	frame:SetAlpha(frame.level * (frame.intensity or 1))

	for _, star in ipairs(frame.stars) do
		star.age = star.age + elapsed
		if star.age >= star.life then
			respawn(star, frame.state)
		end
		local t = math.max(0, star.age) / star.life
		local size = star.size * (0.5 + t * 0.7)
		star:SetSize(size, size)
		star:ClearAllPoints()
		star:SetPoint("CENTER", frame, "CENTER", star.x, star.y)
		star:SetAlpha(star.age > 0 and math.sin(math.pi * t) or 0)
	end
end

-- The label over the stars, at the plate's centre: the backdrop, the name in
-- the game's normal font, and the icon over it.
local function createLabel(frame)
	local label = CreateFrame("Frame", nil, frame)
	label:SetSize(1, 1)
	label:SetPoint("CENTER", frame, "CENTER", 0, -Sparkles.OFFSET)
	label:SetIgnoreParentAlpha(true)
	label.backdrop = label:CreateTexture(nil, "BACKGROUND")
	local backdrop = Sparkles.BACKDROP
	label.backdrop:SetColorTexture(backdrop[1], backdrop[2], backdrop[3], backdrop[4])
	label.name = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label.name:SetPoint("CENTER", label, "CENTER", 0, 0)
	label.backdrop:SetPoint("TOPLEFT", label.name, "TOPLEFT", -4, 2)
	label.backdrop:SetPoint("BOTTOMRIGHT", label.name, "BOTTOMRIGHT", 4, -2)
	label.icon = label:CreateTexture(nil, "OVERLAY")
	label.icon:SetSize(Sparkles.ICON, Sparkles.ICON)
	-- The game's font for the client's alphabet; the size and flags are ours.
	label.font = label.name:GetFont()
	label:Hide()
	frame.label = label
end

-- The effect frame, made once, out of combat (the module's start).
function Sparkles.Create()
	if effect then
		return effect
	end
	local gold = Sparkles.GOLD
	effect = CreateFrame("Frame", nil, UIParent)
	effect:SetSize(Sparkles.SIZE, Sparkles.SIZE)
	effect:Hide()
	effect.stars = {}
	for index = 1, Sparkles.STARS do
		local star = effect:CreateTexture(nil, "ARTWORK")
		star:SetTexture(Sparkles.STAR)
		star:SetBlendMode("ADD")
		star:SetVertexColor(gold[1], gold[2], gold[3])
		respawn(star, "ready")
		effect.stars[index] = star
	end
	effect.state, effect.level, effect.pendingFor = "ready", 0, 0
	createLabel(effect)
	effect:SetScript("OnUpdate", animate)
	return effect
end

-- What the label shows. look: nil for nothing, else { icon, alpha, name,
-- hasName, size, color = { r, g, b }, style }: the icon when look.icon and
-- the target has a cursor; the name when look.hasName, in its size, colour
-- and style, with the icon over it; the icon alone at the centre; both at
-- look.alpha.
function Sparkles.Label(look)
	local label = Sparkles.Create().label
	if not look then
		label:Hide()
		return
	end
	local hasIcon = look.icon == true and Compat.SetSoftInteractCursor(label.icon)
	local hasName = look.hasName == true
	label.icon:SetShown(hasIcon)
	label.name:SetShown(hasName)
	label.icon:ClearAllPoints()
	if hasName then
		local style = Sparkles.STYLES[look.style] or Sparkles.STYLES.outline
		label.name:SetFont(label.font, look.size, style.flags)
		if style.shadow then
			label.name:SetShadowOffset(1, -1)
			label.name:SetShadowColor(0, 0, 0, 1)
		else
			label.name:SetShadowOffset(0, 0)
		end
		label.name:SetTextColor(look.color[1], look.color[2], look.color[3])
		label.name:SetText(look.name)
		label.backdrop:SetShown(style.backdrop == true)
		label.icon:SetPoint("BOTTOM", label.name, "TOP", 0, 4)
	else
		label.backdrop:Hide()
		label.icon:SetPoint("CENTER", label, "CENTER", 0, 0)
	end
	label:SetAlpha(look.alpha or 1)
	label:SetShown(hasIcon or hasName)
end

-- The sparkles on this plate, in this state ("ready", "far", "locked"), with
-- the label look gives (Sparkles.Label). stars: { intensity (0 to 1), color
-- = { r, g, b } }, full and gold without it. whole: a corpse's plate, where
-- everything else on it is hidden too. A new plate starts faint and
-- brightens; a new state waits until it has held.
function Sparkles.Show(plate, state, look, stars, whole)
	local frame = Sparkles.Create()
	frame.intensity = stars and stars.intensity or 1
	local color = stars and stars.color or Sparkles.GOLD
	for _, star in ipairs(frame.stars) do
		star:SetVertexColor(color[1], color[2], color[3])
	end
	if frame.plate ~= plate or frame.whole ~= (whole == true) then
		Sparkles.Hide()
		frame.plate, frame.whole = plate, whole == true
		frame:SetParent(plate)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", plate, "CENTER", 0, Sparkles.OFFSET)
		frame:SetIgnoreParentAlpha(true)
		veil(plate, whole)
		frame.state, frame.pending, frame.level = state, nil, 0
		frame:Show()
	elseif state ~= frame.state then
		if frame.pending ~= state then
			frame.pending, frame.pendingFor = state, 0
		end
	else
		frame.pending = nil
	end
	Sparkles.Label(look)
end

-- The sparkles leave, and the plate's own frame shows again.
function Sparkles.Hide()
	unveil()
	if effect and effect.plate then
		effect:Hide()
		effect:ClearAllPoints()
		effect:SetParent(UIParent)
		effect.plate, effect.whole = nil, nil
	end
end

-- The plate the sparkles hang on now, and their state, for tests.
function Sparkles.Current()
	return effect and effect.plate, effect and effect.state
end
