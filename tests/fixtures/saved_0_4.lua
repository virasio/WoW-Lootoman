-- Saved data as version 0.4 writes it: LootomanDB at account schema 2 and
-- LootomanCharDB at character schema 1.
--
-- - Profile Default: an Icons layout filling right to left, 6 rows, pets not
--   kept; selling with the sell button's click and Shift-click swapped.
-- - Profiles Raid and Alt: the same compact layout with the owned count
--   hidden and the same settings; Raid also keeps 0.3.5's bar settings.
-- - Profile Solo: the loot feed turned off, on the Default layout.
-- - Row layouts: Default, Quiet (compact), Strip (icons), Spare (minimal,
--   used by no profile); 0.3.5's bar sets, untouched since.
--
-- Made-up names. Every later version must load it: never change it, add a
-- fixture for each new schema. Returns fresh tables on each call.
return function()
	return {
		LootomanDB = {
			schema = 2,
			profiles = {
				Default = {
					modules = {
						LootFeed = { layout = "Strip", maxRows = 6, direction = "left", otherViewDirection = "down", keepPets = false },
						Junk = { sellOnOpen = false, swapClicks = true },
					},
					sections = {
						positions = {
							LootFeed = { Modern = { point = "BOTTOM", x = 0, y = 220 } },
						},
					},
				},
				Raid = {
					modules = {
						AutoLoot = { confirmBind = false },
						Bars = { set = "Raid" },
						FreeSlots = { template = "{free|33ff33}", background = true },
						LootFeed = { layout = "Quiet", size = 14, xp = true },
					},
				},
				Alt = {
					modules = {
						LootFeed = { layout = "Quiet", size = 14, xp = true },
					},
				},
				Solo = {
					modules = {
						LootFeed = { enabled = false },
					},
				},
			},
			profileKeys = {
				["Tester-Realm"] = "Default",
				["Healer-Realm"] = "Raid",
				["Alt-Realm"] = "Alt",
				["Fisher-Realm"] = "Solo",
			},
			global = {},
			sections = {
				feedLayouts = {
					Default = { schema = 1, base = "large" },
					Quiet = { schema = 1, base = "compact", changes = { owned = { shown = false } } },
					Strip = { schema = 1, base = "icons", changes = { amount = { fontSize = 15, background = true } } },
					Spare = { schema = 1, base = "minimal" },
				},
				barSets = {
					Raid = { schema = 2, bars = { { entries = { { kind = "money" } } } } },
				},
			},
		},
		LootomanCharDB = { schema = 1 },
	}
end
