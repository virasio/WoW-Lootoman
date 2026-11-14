local _, ns = ...

-- Data for WoW Forever, where the clients differ. The TOC loads this file
-- only for game type "camelot", so code never checks the client; the name is
-- for the self-test.
ns.Data = {
	set = "Forever",
	-- Gathering highlights (Modules/Highlights): the soft targeting they use
	-- works there as Lueur found it.
	highlights = true,
}
