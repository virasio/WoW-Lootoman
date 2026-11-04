local Loader = require("tests.helpers.loader")

-- Broker displays, with a fake LibDataBroker-1.1 in the four states an
-- integration can be in.
describe("broker", function()
	local ns, Test, ldb, made, toggled

	-- What a broker display would bring: LibStub with LibDataBroker-1.1.
	local function installLibrary(library)
		rawset(_G, "LibStub", function(name) return name == "LibDataBroker-1.1" and library or nil end)
	end

	local function workingLibrary()
		local library = { objects = {} }
		function library:NewDataObject(name, data)
			made = made + 1
			self.objects[name] = data
			return data
		end
		function library:GetDataObjectByName(name)
			return self.objects[name]
		end
		return library
	end

	local function start()
		ns = Loader.Start(Loader.LoadAddon())
		Test = ns.Compat.Test
		Test.SetBags({ [0] = { size = 20, items = { [1] = { itemID = 1, count = 1, name = "Filler", quality = 1 } } } })
		return ns.Modules:Get("FreeSlots")
	end

	local function report()
		Test.state.printed = {}
		ns.SelfTest.Run()
		for _, line in ipairs(Test.state.printed) do
			local found = line:match("Broker: .*")
			if found then
				return found
			end
		end
	end

	before_each(function()
		made, toggled = 0, 0
		rawset(_G, "ToggleAllBags", function() toggled = toggled + 1 end)
	end)

	after_each(function()
		rawset(_G, "LibStub", nil)
		rawset(_G, "ToggleAllBags", nil)
	end)

	it("without a broker display makes nothing", function()
		local module = start()
		assert.is_nil(module.broker)
		assert.equals("Broker: no broker display loaded", report())
	end)

	it("with a library without its API makes nothing", function()
		installLibrary({})
		local module = start()
		assert.is_nil(module.broker)
		assert.matches("without NewDataObject", report())
	end)

	it("working shows the free-slot text, its tooltip and opens the bags on a click", function()
		ldb = workingLibrary()
		installLibrary(ldb)
		local module = start()
		local object = ldb.objects["Lootoman: free slots"]
		assert.same({ "data source", "Free slots" }, { object.type, object.label })
		assert.equals(module.frame.Label.text, object.text)
		local lines = {}
		object.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
		assert.same({ "Free slots", "All bags: 19 free of 20", "General bags: 19 free of 20" }, lines)
		object.OnClick()
		assert.equals(1, toggled)
		assert.equals("Broker: working", report())
	end)

	it("working makes the object once, and empties it when turned off or with the module", function()
		ldb = workingLibrary()
		installLibrary(ldb)
		local module = start()
		module:Set("broker", false)
		assert.equals("", ldb.objects["Lootoman: free slots"].text)
		module:Set("broker", true)
		assert.is_true(#ldb.objects["Lootoman: free slots"].text > 0)
		ns.Modules:SetEnabled("FreeSlots", false)
		assert.equals("", ldb.objects["Lootoman: free slots"].text)
		assert.equals(1, made)
	end)

	it("raising an error makes nothing until the next login, and the self-test says why", function()
		ldb = workingLibrary()
		function ldb:NewDataObject() error("registry is broken") end
		installLibrary(ldb)
		local module = start()
		assert.is_nil(module.broker)
		assert.matches("off after an error: .*registry is broken", report())
		assert.same({}, Test.state.errors)
	end)
end)
