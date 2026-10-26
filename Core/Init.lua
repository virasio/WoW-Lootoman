local addonName, ns = ...

ns.addonName = addonName

-- Chat output with the addon name in front.
function ns.Print(text)
	ns.Compat.Print("|cff33ccffLootoman|r: " .. text)
end
