local _, ns = ...
local Compat = ns.Compat

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
-- /ltm demo chime plays the highlights' chime now; /ltm demo chime <object
-- IDs> makes this character chime on those objects until /reload, and
-- /ltm demo chime copper on WoW Forever's copper veins (the highlights exist
-- on WoW Forever only). Development text is not translated.
local FILE = "Interface\\AddOns\\Lootoman\\Art\\Sounds\\chime.mp3"
-- WoW Forever's copper veins, by object ID.
local COPPER = { 1731, 2055, 3763, 103713 }

ns.Slash.RegisterDemo("chime", function(rest)
	local highlights = ns.Modules:Get("Highlights")
	local objects = {}
	for id in (rest or ""):gmatch("%d+") do
		objects[#objects + 1] = tonumber(id)
	end
	if ns.Text.FoldCase(rest or "") == "copper" then
		objects = COPPER
	end
	if #objects == 0 then
		local file = highlights and highlights.CHIME.file or FILE
		ns.Print(Compat.PlaySoundFile(file, "Master") and "demo chime: playing"
			or "demo chime: the client does not play it (the file was not there when the client started, or the sound is off)")
		return
	end
	if not highlights then
		ns.Print("demo chime: the highlights exist on WoW Forever only")
		return
	end
	highlights.CHIME.objects = {}
	for _, id in ipairs(objects) do
		highlights.CHIME.objects[id] = true
	end
	highlights.CHIME.key = highlights.Hash(Compat.GetCharacterKey() or "")
	highlights.ReadChimes()
	ns.Print(("demo chime: this character chimes on object %s until /reload"):format(table.concat(objects, ", ")))
end, "/ltm demo chime [object IDs | copper]: play the highlights' chime, or make this character chime on those objects (copper veins) until /reload")
