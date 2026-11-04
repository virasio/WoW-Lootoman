-- Saved data as version 0.1 writes it: LootomanDB at account schema 1 and
-- LootomanCharDB at character schema 1, with two profiles, a character on
-- each, a changed row layout and loot feed positions in two Edit Mode
-- layouts. Shaped after a real 0.1 save, with made-up names. Every later
-- version must load it: never change it, add a fixture for each new schema.
-- Returns fresh tables on each call.
return function()
	return {
		LootomanDB = {
			schema = 1,
			profiles = {
				Default = {
					modules = {
						LootFeed = { maxRows = 5, xp = true },
					},
					sections = {
						positions = {
							LootFeed = {
								Modern = { point = "BOTTOMRIGHT", x = -398.4111328125, y = 6.166245937347412 },
							},
						},
					},
				},
				Raid = {
					modules = {
						AutoLoot = { confirmBind = false },
						LootFeed = { direction = "down", fade = 1.5, minQuality = 2, layout = "Raid rows" },
					},
					sections = {
						positions = {
							LootFeed = {
								Modern = { point = "TOP", x = 0, y = -120 },
								Healer = { point = "LEFT", x = 240, y = 40 },
							},
						},
					},
				},
			},
			profileKeys = {
				["Tester-Realm"] = "Raid",
				["Alt-Realm"] = "Default",
			},
			global = { debug = true },
			sections = {
				feedLayouts = {
					Default = { schema = 1, base = "large" },
					["Raid rows"] = {
						schema = 1,
						base = "compact",
						changes = { icon = { size = 80 }, name = { fontSize = 14 }, row = { gap = 4 } },
					},
				},
			},
		},
		LootomanCharDB = { schema = 1 },
	}
end
