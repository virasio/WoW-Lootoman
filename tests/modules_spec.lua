local Loader = require("tests.helpers.loader")

describe("modules", function()
	local ns, Modules, Test, log

	-- A module that records its lifecycle and listens to one game event.
	local function register(name, enabled, extra)
		local definition = {
			name = name,
			defaults = { enabled = enabled, size = 1 },
			OnEnable = function(self)
				log[#log + 1] = "enable " .. self.name
				self:OnEvent("BAG_UPDATE_DELAYED", function() end)
			end,
			OnDisable = function(self)
				log[#log + 1] = "disable " .. self.name
			end,
		}
		for key, value in pairs(extra or {}) do
			definition[key] = value
		end
		return Modules:Register(definition)
	end

	before_each(function()
		-- Without the addon's own modules: these tests register their own.
		ns = Loader.LoadAddon({ skip = { "Settings/", "Modules/" } })
		Modules, Test = ns.Modules, ns.Compat.Test
		log = {}
	end)

	it("starts the enabled modules when the addon is ready", function()
		local on = register("On", true)
		local off = register("Off", false)
		assert.same({}, log)
		Loader.Start(ns)
		assert.same({ "enable On" }, log)
		assert.is_true(on:IsActive())
		assert.is_false(off:IsActive())
	end)

	it("turns a module off and on without a reload, and announces it", function()
		local module = register("Feed", true)
		local toggled = {}
		ns.Bus:On("ModuleToggled", "test", function(_, name, active) toggled[#toggled + 1] = { name, active } end)
		Loader.Start(ns)

		Modules:SetEnabled("Feed", false)
		assert.is_false(module:IsActive())
		Modules:SetEnabled("Feed", true)
		assert.is_true(module:IsActive())
		assert.same({ "enable Feed", "disable Feed", "enable Feed" }, log)
		assert.same({ { "Feed", true }, { "Feed", false }, { "Feed", true } }, toggled)
	end)

	it("leaves a disabled module with no listeners", function()
		local module = register("Feed", true)
		Loader.Start(ns)
		assert.same({ "BAG_UPDATE_DELAYED" }, ns.Bus:GetEvents(module))
		Modules:SetEnabled("Feed", false)
		assert.same({}, ns.Bus:GetEvents(module))
		assert.is_false(Test.IsRegistered("BAG_UPDATE_DELAYED"))
	end)

	it("follows a profile switch", function()
		local module = register("Feed", true)
		Loader.Start(ns)
		ns.Profiles.Create("Quiet")
		ns.Profiles.Switch("Quiet")
		Modules:SetEnabled("Feed", false)
		ns.Profiles.Switch("Default")
		assert.is_true(module:IsActive())
		ns.Profiles.Switch("Quiet")
		assert.is_false(module:IsActive())
	end)

	it("waits for the end of combat to change a module", function()
		local module = register("Feed", false)
		Loader.Start(ns)
		Test.SetCombat(true)
		Modules:SetEnabled("Feed", true)
		assert.is_false(module:IsActive())
		Test.SetCombat(false)
		assert.is_true(module:IsActive())
		assert.is_false(Test.IsRegistered("PLAYER_REGEN_ENABLED"))
	end)

	it("reports a module that fails to start and leaves it off", function()
		local module = register("Broken", true, {
			OnEnable = function(self)
				self:OnEvent("BAG_UPDATE_DELAYED", function() end)
				error("cannot start")
			end,
		})
		Loader.Start(ns)
		assert.is_false(module:IsActive())
		assert.same({}, ns.Bus:GetEvents(module))
		assert.matches("cannot start", Test.state.errors[1])
	end)

	it("undoes a start that failed halfway", function()
		local frameShown = false
		local module = register("Half", true, {
			OnEnable = function(self)
				frameShown = true
				self:OnEvent("BAG_UPDATE_DELAYED", function() end)
				error("setup failed")
			end,
			OnDisable = function()
				frameShown = false
			end,
		})
		Loader.Start(ns)
		assert.is_false(frameShown)
		assert.is_false(module:IsActive())
		assert.same({}, ns.Bus:GetEvents(module))
		assert.matches("setup failed", Test.state.errors[1])
	end)

	it("keeps a module off that turns itself off while starting", function()
		local module = register("Self", true, {
			OnEnable = function(self)
				self:Set("enabled", false)
			end,
		})
		Loader.Start(ns)
		assert.is_false(ns.Storage:Get("Self", "enabled"))
		assert.is_false(module:IsActive())
	end)

	it("follows a profile switch made by a module while it starts", function()
		local other = register("Other", true)
		register("Switcher", true, {
			OnEnable = function()
				ns.Profiles.Create("Quiet")
				ns.Profiles.Switch("Quiet")
				ns.Modules:SetEnabled("Other", false)
			end,
		})
		Loader.Start(ns)
		assert.equals("Quiet", ns.Profiles.GetCurrent())
		assert.is_false(other:IsActive())
	end)

	it("stops and reports modules that keep switching themselves", function()
		register("Flip", true, {
			OnEnable = function(self) self:Set("enabled", false) end,
			OnDisable = function(self) self:Set("enabled", true) end,
		})
		Loader.Start(ns)
		assert.matches("kept changing", Test.state.errors[#Test.state.errors])
		ns.Modules:SetEnabled("Flip", false)
	end)

	it("gives modules access to their own settings", function()
		local module = register("Feed", true)
		Loader.Start(ns)
		module:Set("size", 3)
		assert.equals(3, module:Get("size"))
		assert.equals(3, ns.Storage:Get("Feed", "size"))
	end)

	it("lists modules in the order they registered, with a title", function()
		register("B", true, { title = "Bee" })
		register("A", true)
		local list = Modules:List()
		assert.same({ "B", "A" }, { list[1].name, list[2].name })
		assert.same({ "Bee", "A" }, { list[1].title, list[2].title })
	end)

	it("rejects duplicate names and modules without an enabled default", function()
		register("Feed", true)
		assert.has_error(function() register("Feed", true) end)
		assert.has_error(function() Modules:Register({ name = "NoDefault", defaults = {} }) end)
	end)
end)
