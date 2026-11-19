-- Saved data as version 0.5.8 writes it: LootomanDB at account schema 3 and
-- LootomanCharDB at character schema 1.
--
-- - Profiles Default (the Default look) and Raid (the Glass look).
-- - Looks: Default untouched; Glass, rows, with a background at 60 % in a
--   blue, size 14 and a taller row; Plain, icons, size 11, filling to the left.
-- - The character's session holds one sale.
--
-- Made-up names. Every later version must load it: never change it, add a
-- fixture for each new schema. Returns fresh tables on each call.
return function()
	return {
		LootomanDB = {
			schema = 3,
			profiles = {
				Default = {},
				Raid = { modules = { LootFeed = { look = "Glass" } } },
			},
			profileKeys = { ["Tester-Realm"] = "Raid" },
			global = { debug = false },
			sections = {
				feedLooks = {
					Default = { schema = 1, base = "large" },
					Glass = {
						schema = 1,
						base = "large",
						changes = { row = { height = 40 } },
						values = { backgroundOpacity = 60, backgroundColor = "336699", size = 14 },
					},
					Plain = { schema = 1, base = "icons", values = { size = 11, direction = "left" } },
				},
			},
		},
		LootomanCharDB = {
			schema = 1,
			session = { sales = { { count = 2, money = 150, items = { { link = "item:2589", count = 2, money = 150 } } } } },
		},
	}
end
