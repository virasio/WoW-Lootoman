local _, ns = ...
local Compat = ns.Compat

-- The sparkles of gathering highlights: one look for every kind of object, in
-- the default UI's gold. A soft glow, six stars that light up at random points
-- around the object and fade, and a few motes rising slowly. Only the game's
-- own art: the cooldown "bling" star and the loot toast's glow, blended
-- additively.
--
-- The effect is one frame, made when highlights start. While an object
-- sparkles it hangs on the object's nameplate, a little below it, where the
-- object is (the distance is the one Forever Loot Sparkles - Herbs & Ores
-- found); it follows the plate and its scale, keeps its own alpha, and our
-- frame is not protected, so this is allowed in combat too. The plate's own
-- frame stays invisible under it, so an object shows no bar or name from the
-- game, and is shown again when the sparkles leave.
--
-- How bright: in reach full, out of reach about 60 %, not usable yet about
-- 30 % and without motes. A new state shows only once it has held for a moment,
-- so the sparkles don't flicker at the edge of reach (Lueur's lesson), and
-- the brightness fades to it.
--
-- Another addon may already light the object (Lueur, Forever Loot Sparkles
-- - Herbs & Ores hang theirs on the plate too): Taken tells, from the plate's
-- shown child frames that come from another addon's files.
ns.Highlights = ns.Highlights or {}
local Sparkles = {}
ns.Highlights.Sparkles = Sparkles

Sparkles.GOLD = { 1, 0.82, 0 }
Sparkles.STAR = [[Interface\Cooldown\star4]]
Sparkles.HAZE = "loottoast-glow"
Sparkles.SIZE = 72
Sparkles.OFFSET = -45
Sparkles.STARS = 6
Sparkles.MOTES = 3
Sparkles.ALPHA = { ready = 1, far = 0.6, locked = 0.3 }
Sparkles.HOLD = 0.15
Sparkles.FADE = 0.25

local effect
-- The plate's own frame hidden under the sparkles, and whether we are hiding
-- it again ourselves.
local veiled, reveiling
local hooked = setmetatable({}, { __mode = "k" })

local function keepVeiled(unitFrame, alpha)
	if unitFrame == veiled and alpha ~= 0 and not reveiling then
		reveiling = true
		unitFrame:SetAlpha(0)
		reveiling = false
	end
end

local function unveil()
	if veiled then
		local unitFrame = veiled
		veiled = nil
		unitFrame:SetAlpha(1)
	end
end

-- The game's nameplate code may set the frame's alpha again; a hook keeps it
-- hidden while the sparkles are there.
local function veil(plate)
	unveil()
	local unitFrame = type(plate) == "table" and plate.UnitFrame or nil
	if type(unitFrame) ~= "table" or not unitFrame.SetAlpha then
		return
	end
	if not hooked[unitFrame] then
		hooked[unitFrame] = true
		hooksecurefunc(unitFrame, "SetAlpha", keepVeiled)
	end
	veiled = unitFrame
	unitFrame:SetAlpha(0)
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

-- A mote rises from below the centre.
local function respawnMote(mote)
	mote.x = (random() - 0.5) * Sparkles.SIZE * 0.5
	mote.y = -Sparkles.SIZE * 0.2
	mote.age = -random() * 1.5
	mote.life = 1.5 + random()
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
	frame:SetAlpha(frame.level)

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
	local motes = frame.state ~= "locked"
	for _, mote in ipairs(frame.motes) do
		mote.age = mote.age + elapsed
		if mote.age >= mote.life then
			respawnMote(mote)
		end
		local t = math.max(0, mote.age) / mote.life
		mote:ClearAllPoints()
		mote:SetPoint("CENTER", frame, "CENTER", mote.x, mote.y + t * Sparkles.SIZE * 0.6)
		mote:SetAlpha(motes and mote.age > 0 and (1 - t) * 0.8 or 0)
	end
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
	effect.haze = effect:CreateTexture(nil, "BACKGROUND")
	effect.haze:SetAtlas(Sparkles.HAZE)
	effect.haze:SetBlendMode("ADD")
	effect.haze:SetVertexColor(gold[1], gold[2], gold[3])
	effect.haze:SetPoint("CENTER")
	effect.haze:SetSize(Sparkles.SIZE, Sparkles.SIZE)
	effect.haze:SetAlpha(0.5)
	effect.stars, effect.motes = {}, {}
	for index = 1, Sparkles.STARS do
		local star = effect:CreateTexture(nil, "ARTWORK")
		star:SetTexture(Sparkles.STAR)
		star:SetBlendMode("ADD")
		star:SetVertexColor(gold[1], gold[2], gold[3])
		respawn(star, "ready")
		effect.stars[index] = star
	end
	for index = 1, Sparkles.MOTES do
		local mote = effect:CreateTexture(nil, "ARTWORK")
		mote:SetTexture(Sparkles.STAR)
		mote:SetBlendMode("ADD")
		mote:SetVertexColor(gold[1], gold[2], gold[3])
		mote:SetSize(6, 6)
		respawnMote(mote)
		effect.motes[index] = mote
	end
	effect.state, effect.level, effect.pendingFor = "ready", 0, 0
	effect:SetScript("OnUpdate", animate)
	return effect
end

-- The sparkles on this plate, in this state ("ready", "far", "locked"). A new
-- plate starts faint and brightens; a new state waits until it has held.
function Sparkles.Show(plate, state)
	local frame = Sparkles.Create()
	if frame.plate ~= plate then
		Sparkles.Hide()
		frame.plate = plate
		frame:SetParent(plate)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", plate, "CENTER", 0, Sparkles.OFFSET)
		frame:SetIgnoreParentAlpha(true)
		veil(plate)
		frame.state, frame.pending, frame.level = state, nil, 0
		frame:Show()
	elseif state ~= frame.state then
		if frame.pending ~= state then
			frame.pending, frame.pendingFor = state, 0
		end
	else
		frame.pending = nil
	end
end

-- The sparkles leave, and the plate's own frame shows again.
function Sparkles.Hide()
	unveil()
	if effect and effect.plate then
		effect:Hide()
		effect:ClearAllPoints()
		effect:SetParent(UIParent)
		effect.plate = nil
	end
end

-- The plate the sparkles hang on now, and their state, for tests.
function Sparkles.Current()
	return effect and effect.plate, effect and effect.state
end

-- Whether another addon already draws on this plate: a shown child frame that
-- is not ours and comes from an addon's files, not the game's own. A child
-- whose source the client does not tell is the game's.
function Sparkles.Taken(plate)
	if type(plate) ~= "table" or type(plate.GetChildren) ~= "function" then
		return false
	end
	for _, child in ipairs({ plate:GetChildren() }) do
		if child ~= effect and type(child) == "table" and child.IsShown and child:IsShown() then
			local source = Compat.GetFrameSource(child)
			if source then
				local path = source:gsub("\\", "/"):lower()
				if path:find("interface/addons/", 1, true) and not path:find("interface/addons/blizzard_", 1, true)
					and not path:find("interface/addons/lootoman/", 1, true) then
					return true
				end
			end
		end
	end
	return false
end
