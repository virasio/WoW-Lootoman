-- Saved data as version 0.3 writes it: LootomanDB at account schema 1 with a
-- profile that uses its own bar set, the free-slot bar's template, a feed
-- warning threshold, and two bar sets at schema 1: Default with the
-- backpack's currencies, Raid with two bars (currencies, an item, money, one
-- bar filling from the right with a background and a border, positions in two
-- Edit Mode layouts). Made-up names. Every later version must load it: never
-- change it, add a fixture for each new schema. Returns fresh tables on each
-- call.
return function()
	return {
		LootomanDB = {
			schema = 1,
			profiles = {
				Default = {
					modules = {
						Bars = { set = "Raid" },
						FreeSlots = { template = "{free|33ff33} / {general}" },
						LootFeed = { warnGeneralAt = 4 },
					},
				},
			},
			profileKeys = { ["Tester-Realm"] = "Default" },
			global = {},
			sections = {
				barSets = {
					Default = {
						schema = 1,
						bars = {
							{ id = 1, width = 300, gap = 6, size = 22, direction = "right", background = false, opacity = 50,
								border = false, positions = {} },
						},
					},
					Raid = {
						schema = 1,
						bars = {
							{ id = 1, width = 420, gap = 8, size = 26, direction = "left", background = true, opacity = 30,
								border = true,
								entries = { { kind = "currency", id = 3008 }, { kind = "item", id = 2589 }, { kind = "money", id = 0 } },
								positions = {
									Modern = { point = "BOTTOM", x = 0, y = 210 },
									Healer = { point = "TOPRIGHT", x = -40, y = -300 },
								} },
							{ id = 3, width = 200, gap = 6, size = 22, direction = "right", background = false, opacity = 50,
								border = false, entries = { { kind = "currency", id = 2815 } },
								positions = { Modern = { point = "BOTTOM", x = 0, y = 240 } } },
						},
					},
				},
			},
		},
		LootomanCharDB = { schema = 1 },
	}
end
