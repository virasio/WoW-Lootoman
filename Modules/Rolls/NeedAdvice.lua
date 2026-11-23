local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Whether to need: a line on the Loot Rolls window's rows, while the item is
-- gear the player can wear, from the addons that know the player's gear best.
-- Lootoman judges no gear itself; with neither addon there is no line.
--   Forever Leveling BiS first (WoW Forever only): the score the item gains
--   the main spec over what is worn, as its own tooltip shows it; nothing for
--   an item worn. Its API speaks for the main spec only, so the line says
--   so; the off specs picked in it show in its own lines of the item's
--   tooltip.
--   Pawn otherwise: the best upgrade over its scales shown (a scale for an
--   off spec counts too) with the scale's name, or that it is not one.
-- An answer that cannot be told yet (an item still loading) is asked again
-- when Forever Leveling BiS says its answers changed, and after a moment, a
-- few times.
ns.Rolls = ns.Rolls or {}
local NeedAdvice = {}
ns.Rolls.NeedAdvice = NeedAdvice

-- The colours of an upgrade and of the rest, as the game writes them.
NeedAdvice.COLORS = {
	up = { 0.1, 1, 0.1 },
	down = { 0.6, 0.6, 0.6 },
}
-- How long until an answer still loading is asked again, and how many times.
NeedAdvice.WAIT = 1
NeedAdvice.TRIES = 5

local tries = {}
local pending = false
local listening = false

local function redraw()
	local module = ns.Rolls.Module
	if module and module.active and ns.Rolls.LiveWindow then
		ns.Rolls.LiveWindow.Redraw()
	end
end

-- An answer still loading: asked again after a moment, a few times per item.
local function later(link)
	tries[link] = (tries[link] or 0) + 1
	if pending or tries[link] > NeedAdvice.TRIES then
		return
	end
	pending = true
	Compat.After(NeedAdvice.WAIT, function()
		pending = false
		redraw()
	end)
end

local function number(value)
	return (("%.1f"):format(value):gsub("%.0$", ""))
end

local function fromLevelingBiS(flb, link)
	if not listening then
		listening = true
		flb.OnChanged(redraw)
	end
	local gain, loading = flb.Gain(link)
	if loading then
		later(link)
		return nil
	end
	if gain and gain > 0 then
		return L["Main spec: +%s (%s)"]:format(number(gain), flb.NAME), "up"
	elseif gain and gain < 0 then
		return L["Main spec: %s (%s)"]:format(number(gain), flb.NAME), "down"
	end
	return nil
end

local function fromPawn(pawn, link)
	local share, scale = pawn.Upgrade(link)
	if share == nil then
		if scale == true then
			later(link)
		end
		return nil
	elseif share == false then
		return L["Not an upgrade (%s)"]:format(pawn.NAME), "down"
	end
	local percent = ("%d%%"):format(math.floor(share * 100 + 0.5))
	if type(scale) == "string" and scale ~= "" then
		return L["Upgrade: +%s (%s: %s)"]:format(percent, pawn.NAME, scale), "up"
	end
	return L["Upgrade: +%s (%s)"]:format(percent, pawn.NAME), "up"
end

-- The line for an item's link and its colour ("up" or "down"), or nil when
-- there is none.
function NeedAdvice.Line(link)
	if type(link) ~= "string" then
		return nil
	end
	local integrations = ns.Integrations or {}
	local flb, pawn = integrations.ForeverLevelingBiS, integrations.Pawn
	if flb and flb.Working() then
		return fromLevelingBiS(flb, link)
	elseif pawn and pawn.Working() then
		return fromPawn(pawn, link)
	end
	return nil
end

-- The addon the options page suggests while no addon gives the advice:
-- Forever Leveling BiS on the client it is made for, else Pawn.
function NeedAdvice.Suggested()
	return ns.Data.levelingBiS and ns.Integrations.ForeverLevelingBiS or ns.Integrations.Pawn
end

-- Whether no addon gives the advice now: the options page then suggests one.
function NeedAdvice.Missing()
	return not ns.Integrations.ForeverLevelingBiS.Working() and not ns.Integrations.Pawn.Working()
end
