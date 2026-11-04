local addonName, ns = ...
local Bus, Compat, L, Storage = ns.Bus, ns.Compat, ns.L, ns.Storage

-- ADDON_LOADED: the saved variables are there. PLAYER_LOGIN: the character is
-- known, so its profile can be chosen; "Ready" starts the modules and the
-- settings panel.

Bus:OnEvent("ADDON_LOADED", "Startup", function(_, loaded)
	if loaded ~= addonName then
		return
	end
	Bus:OffEvent("ADDON_LOADED", "Startup")
	local db, charDB = Storage:Load(Compat.GetSaved("LootomanDB"), Compat.GetSaved("LootomanCharDB"))
	Compat.SetSaved("LootomanDB", db)
	Compat.SetSaved("LootomanCharDB", charDB)
end)

Bus:OnEvent("PLAYER_LOGIN", "Startup", function()
	Bus:OffEvent("PLAYER_LOGIN", "Startup")
	Storage:SetCharacter(Compat.GetCharacterKey())
	if Storage.readOnly then
		ns.Print(L["Your settings were saved by a newer version of Lootoman. They are kept as they are, and this version uses default settings until you update."])
	end
	Bus:Send("Ready")
end)

-- The first PLAYER_ENTERING_WORLD tells a login from a /reload. At a login the
-- session's data starts anew, whether or not the module that keeps it is on.
Bus:OnEvent("PLAYER_ENTERING_WORLD", "Startup", function(_, isInitialLogin)
	Bus:OffEvent("PLAYER_ENTERING_WORLD", "Startup")
	if isInitialLogin then
		Storage:NewSession()
	end
end)
