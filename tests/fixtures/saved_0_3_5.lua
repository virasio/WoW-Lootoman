-- Saved data as version 0.3.5 writes it: LootomanDB at account schema 1 and
-- LootomanCharDB at character schema 1.
--
-- - Profile Raid: its own bar set, the free-slot bar with a background and a
--   position, a two-row feed with the owned count off, and a row layout that
--   hides the owned part.
-- - Profile Default: a one-row feed on the Default layout.
-- - Bar sets at schema 2: Raid with a stack of currencies, an item counted in
--   the banks and one counted everywhere; Default with the backpack's
--   currencies.
--
-- Made-up names. Every later version must load it: never change it, add a
-- fixture for each new schema. Returns fresh tables on each call.
return function()
	return {
		LootomanDB = {
			schema = 1,
			profiles = {
				Default = {
					modules = {
						LootFeed = { maxRows = 1 },
					},
				},
				Raid = {
					modules = {
						Bars = { set = "Raid" },
						FreeSlots = { template = "{free|33ff33} ({herb|ffd100})", background = true, opacity = 30 },
						LootFeed = { maxRows = 2, owned = false, layout = "Quiet" },
					},
					sections = {
						positions = {
							FreeSlots = { Modern = { point = "BOTTOMRIGHT", x = -300, y = 40 } },
							LootFeed = { Modern = { point = "RIGHT", x = -250, y = 0 } },
						},
					},
				},
			},
			profileKeys = {
				["Tester-Realm"] = "Raid",
				["Alt-Realm"] = "Default",
			},
			global = {},
			sections = {
				feedLayouts = {
					Default = { schema = 1, base = "large" },
					Quiet = { schema = 1, base = "compact", changes = { owned = { shown = false }, row = { gap = 2 } } },
				},
				barSets = {
					Default = {
						schema = 2,
						bars = {
							{ id = 1, width = 300, gap = 6, size = 22, direction = "right", background = false, opacity = 50,
								border = false, positions = {} },
						},
					},
					Raid = {
						schema = 2,
						bars = {
							{ id = 1, width = 420, gap = 8, size = 26, direction = "left", background = true, opacity = 30,
								border = true,
								entries = {
									{ kind = "stack", members = { { kind = "currency", id = 3008 }, { kind = "currency", id = 2917 } },
										showEmpty = true },
									{ kind = "item", id = 2589, count = "banks" },
									{ kind = "item", id = 2589, count = "all" },
									{ kind = "money", id = 0 },
								},
								positions = { Modern = { point = "BOTTOM", x = 0, y = 210 } } },
						},
					},
				},
			},
		},
		LootomanCharDB = { schema = 1 },
	}
end
