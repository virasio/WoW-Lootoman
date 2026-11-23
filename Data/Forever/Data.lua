local _, ns = ...

-- Data for WoW Forever, where the clients differ. The TOC loads this file
-- only for game type "camelot", so code never checks the client; the name is
-- for the self-test.
ns.Data = {
	set = "Forever",
	-- Gathering highlights (Modules/Highlights): the soft targeting they use
	-- works there as Lueur found it.
	highlights = true,
	-- Collections the game has none of, though the client has their API: no
	-- appearance sets and no heirlooms, so the loot feed does not offer to
	-- keep them (Rules/Usable.lua).
	noCollections = { set = true, heirloom = true },
	-- Forever Leveling BiS, made for this client, advises on whether to need
	-- first (Modules/Rolls/NeedAdvice.lua), and the options recommend it.
	levelingBiS = true,
}
