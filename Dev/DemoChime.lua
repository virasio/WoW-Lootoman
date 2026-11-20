local _, ns = ...
local Compat = ns.Compat

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
-- /ltm demo chime plays the highlights' chime now; /ltm demo chime <objectID>
-- makes this character chime on that object until /reload (the highlights
-- exist on WoW Forever only). Development text is not translated.
local FILE = "Interface\\AddOns\\Lootoman\\Art\\Sounds\\chime.mp3"

ns.Slash.RegisterDemo("chime", function(rest)
	local highlights = ns.Modules:Get("Highlights")
	local objectID = tonumber(rest)
	if not objectID then
		local file = highlights and highlights.CHIME.file or FILE
		ns.Print(Compat.PlaySoundFile(file, "Master") and "demo chime: playing"
			or "demo chime: the client does not play it (the file was not there when the client started, or the sound is off)")
		return
	end
	if not highlights then
		ns.Print("demo chime: the highlights exist on WoW Forever only")
		return
	end
	highlights.CHIME.objectID = objectID
	highlights.CHIME.key = highlights.Hash(Compat.GetCharacterKey() or "")
	highlights.ReadChimes()
	ns.Print(("demo chime: this character chimes on object %d until /reload"):format(objectID))
end, "/ltm demo chime [objectID]: play the highlights' chime, or make this character chime on that object until /reload")
