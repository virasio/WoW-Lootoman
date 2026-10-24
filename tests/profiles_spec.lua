local Loader = require("tests.helpers.loader")

describe("profiles", function()
	local Storage, Profiles, db, changes

	before_each(function()
		local ns = Loader.LoadAddon()
		Storage, Profiles = ns.Storage, ns.Profiles
		Storage:RegisterDefaults("Feed", { rows = 5 })
		db = Storage:Load(nil, nil)
		Storage:SetCharacter("Ana-Realm")
		changes = {}
		ns.Bus:On("ProfileChanged", "test", function(_, new, old) changes[#changes + 1] = { new, old } end)
	end)

	it("starts with Default", function()
		assert.same({ "Default" }, Profiles.List())
		assert.equals("Default", Profiles.GetCurrent())
	end)

	it("lists Default first, then the others alphabetically", function()
		Profiles.Create("raid")
		Profiles.Create("Alts")
		Profiles.Create("Main")
		assert.same({ "Default", "Alts", "Main", "raid" }, Profiles.List())
	end)

	describe("names", function()
		it("are trimmed", function()
			assert.equals("Main", Profiles.Create("  Main "))
		end)

		it("must not be empty", function()
			assert.same({ nil, "empty" }, { Profiles.Create("   ") })
		end)

		it("count characters, not bytes", function()
			assert.equals(48, #Profiles.Create(("a"):rep(48)))
			assert.same({ nil, "too_long" }, { Profiles.Create(("a"):rep(49)) })
			assert.is_not_nil(Profiles.Create(("ж"):rep(48)))
		end)

		it("are unique regardless of letter case", function()
			Profiles.Create("Main")
			assert.same({ nil, "exists" }, { Profiles.Create("main") })
			assert.same({ nil, "exists" }, { Profiles.Create("DEFAULT") })
		end)

		it("are unique regardless of letter case in Cyrillic and Latin-1", function()
			Profiles.Create("Рейд")
			Profiles.Create("Ёлка")
			Profiles.Create("Über")
			assert.same({ nil, "exists" }, { Profiles.Create("рейд") })
			assert.same({ nil, "exists" }, { Profiles.Create("ЁЛКА") })
			assert.same({ nil, "exists" }, { Profiles.Create("über") })
			assert.equals("Рейды", Profiles.Create("Рейды"))
		end)

		it("may not take the name Default is shown under", function()
			local ru = Loader.LoadAddon({ locale = "ruRU" })
			ru.Storage:Load(nil, nil)
			ru.Storage:SetCharacter("Ana-Realm")
			assert.same({ nil, "exists" }, { ru.Profiles.Create("По умолчанию") })
			assert.same({ nil, "exists" }, { ru.Profiles.Create("по УМОЛЧАНИЮ") })
			ru.Profiles.Create("Main")
			assert.same({ nil, "exists" }, { ru.Profiles.Rename("Main", "По умолчанию") })
		end)

		it("may take the Russian name of Default on a client in another language", function()
			assert.equals("По умолчанию", Profiles.Create("По умолчанию"))
		end)

		it("may change only the letter case of a Cyrillic name", function()
			Profiles.Create("рейд")
			assert.equals("Рейд", Profiles.Rename("рейд", "Рейд"))
		end)
	end)

	it("switches the current character and announces it", function()
		Profiles.Create("Main")
		assert.is_true(Profiles.Switch("Main"))
		assert.equals("Main", Profiles.GetCurrent())
		assert.same({ { "Main", "Default" } }, changes)
		assert.equals("Main", db.profileKeys["Ana-Realm"])
	end)

	it("does not announce switching to the same profile", function()
		Profiles.Switch("Default")
		assert.same({}, changes)
	end)

	it("stores no profile for characters on Default", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		Profiles.Switch("Default")
		assert.same({}, db.profileKeys)
	end)

	it("refuses to switch to a missing profile", function()
		assert.same({ nil, "missing" }, { Profiles.Switch("Nope") })
	end)

	it("keeps two characters on different profiles apart", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		Storage:Set("Feed", "rows", 8)

		Storage:SetCharacter("Bo-Realm")
		assert.equals("Default", Profiles.GetCurrent())
		assert.equals(5, Storage:Get("Feed", "rows"))
		Storage:Set("Feed", "rows", 2)

		Storage:SetCharacter("Ana-Realm")
		assert.equals("Main", Profiles.GetCurrent())
		assert.equals(8, Storage:Get("Feed", "rows"))
	end)

	it("copies a profile into a new, independent one", function()
		Storage:Set("Feed", "rows", 8)
		assert.equals("Copy", Profiles.Copy("Default", "Copy"))
		Profiles.Switch("Copy")
		assert.equals(8, Storage:Get("Feed", "rows"))
		Storage:Set("Feed", "rows", 3)
		Profiles.Switch("Default")
		assert.equals(8, Storage:Get("Feed", "rows"))
	end)

	it("copies the sections of a profile, independent of the source", function()
		Storage:GetSection("positions").LootFeed = { Modern = { "CENTER", 200, 0 } }
		Profiles.Copy("Default", "Copy")
		Profiles.Switch("Copy")
		local copied = Storage:GetSection("positions")
		assert.same({ LootFeed = { Modern = { "CENTER", 200, 0 } } }, copied)
		copied.LootFeed.Modern[2] = 50
		Profiles.Switch("Default")
		assert.equals(200, Storage:GetSection("positions").LootFeed.Modern[2])
	end)

	describe("renaming", function()
		it("moves every character using the profile", function()
			Profiles.Create("Main")
			db.profileKeys["Bo-Realm"] = "Main"
			Profiles.Switch("Main")
			changes = {}
			assert.equals("Raid", Profiles.Rename("Main", "Raid"))
			assert.same({ "Default", "Raid" }, Profiles.List())
			assert.same({ ["Ana-Realm"] = "Raid", ["Bo-Realm"] = "Raid" }, db.profileKeys)
			assert.same({ { "Raid", "Main" } }, changes)
		end)

		it("may change only the letter case", function()
			Profiles.Create("main")
			assert.equals("Main", Profiles.Rename("main", "Main"))
		end)

		it("refuses Default and missing profiles", function()
			assert.same({ nil, "default" }, { Profiles.Rename("Default", "Other") })
			assert.same({ nil, "missing" }, { Profiles.Rename("Nope", "Other") })
		end)
	end)

	it("resets a profile to the defaults", function()
		Storage:Set("Feed", "rows", 8)
		assert.is_true(Profiles.Reset("Default"))
		assert.equals(5, Storage:Get("Feed", "rows"))
		assert.same({ { "Default", "Default" } }, changes)
	end)

	it("clears the sections of a reset profile", function()
		Storage:GetSection("positions").LootFeed = { Modern = { "CENTER", 200, 0 } }
		Profiles.Reset("Default")
		assert.same({}, Storage:GetSection("positions"))
	end)

	describe("deleting", function()
		it("moves the characters that used the profile to Default", function()
			Profiles.Create("Main")
			db.profileKeys["Bo-Realm"] = "Main"
			Profiles.Switch("Main")
			changes = {}
			assert.is_true(Profiles.Delete("Main"))
			assert.same({ "Default" }, Profiles.List())
			assert.same({}, db.profileKeys)
			assert.same({ { "Default", "Main" } }, changes)
		end)

		it("does not announce deleting a profile the character does not use", function()
			Profiles.Create("Main")
			Profiles.Delete("Main")
			assert.same({}, changes)
		end)

		it("refuses Default and missing profiles", function()
			assert.same({ nil, "default" }, { Profiles.Delete("Default") })
			assert.same({ nil, "missing" }, { Profiles.Delete("Nope") })
		end)
	end)
end)
