local _, ns = ...

-- Data for retail (techspec §3): disenchant tables, categories and default
-- rules arrive with their releases. The TOC loads this file only for game type
-- "standard", so code never checks the client; the name is for the self-test.
ns.Data = {
	set = "Mainline",
}
