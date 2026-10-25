local _, ns = ...
local Bus, L, Storage = ns.Bus, ns.L, ns.Storage

-- Places module frames with Blizzard's Edit Mode through LibEditMode.
-- Positions are kept per Edit Mode layout in the profile
-- section "positions": positions[key][layoutName] = { point, x, y }. They are
-- restored when the layout or the profile changes, and follow a layout that
-- is renamed or copied. Module settings can also be shown in the frame's
-- Edit Mode dialog, bound to the same profile values as the options page.
--
--   ns.EditMode.Register(module, frame, {
--       key = "LootFeed",                    -- in the positions section; default module.name
--       name = <localized name>,             -- shown in Edit Mode; default module.title
--       default = { point = "CENTER", x = 250, y = 0 },
--       settings = {                         -- shown in the Edit Mode dialog
--           { kind = "header", label = … },  -- a divider with a title, starts a group
--           { kind = "slider", key = "rows", label = …, tooltip = …, min = 1, max = 20, step = 1, format = "%d" },
--           { kind = "dropdown", key = "direction", label = …, choices = { { "up", <label> }, … } },
--           { kind = "checkbox", key = "money", label = … },
--       },
--       onEditMode = function(active) end,   -- show a preview while Edit Mode is on
--       buttons = { { text = …, click = function() end } },   -- in the Edit Mode dialog
--   })
--
-- LibEditMode draws the selection on the frame itself, so a hidden frame
-- cannot be picked: an active module shows a preview in onEditMode(true). An
-- inactive module keeps its frame hidden, which leaves it out of Edit Mode.
local EditMode = {}
ns.EditMode = EditMode

local entries = {}
local lib
local layoutName
-- True while a value set in the Edit Mode dialog is being stored.
local fromDialog = false

local function positions()
	return Storage:GetSection("positions")
end

local POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- A frame's positions from a profile text: only well-formed ones, { point, x,
-- y } per Edit Mode layout.
local function cleanPositions(layouts)
	local kept = {}
	for layout, position in pairs(layouts) do
		if type(layout) == "string" and type(position) == "table" and POINTS[position.point]
			and type(position.x) == "number" and type(position.y) == "number" then
			kept[layout] = { point = position.point, x = position.x, y = position.y }
		end
	end
	return kept
end

-- A module's frame positions (key as in Register) can be shared with its
-- settings in profile texts (Share), as the part "Position" under them.
function EditMode.SharePosition(module, key)
	ns.Share.RegisterPart({
		name = "positions:" .. key,
		module = module,
		label = L["Position"],
		get = function(profile)
			local sections = type(profile.sections) == "table" and profile.sections
			local saved = sections and type(sections.positions) == "table" and sections.positions[key]
			return type(saved) == "table" and saved or nil
		end,
		set = function(profile, layouts)
			profile.sections = type(profile.sections) == "table" and profile.sections or {}
			local saved = profile.sections.positions
			profile.sections.positions = type(saved) == "table" and saved or {}
			profile.sections.positions[key] = layouts
		end,
		clean = cleanPositions,
	})
end

local function apply(entry)
	local saved = layoutName and positions()[entry.key]
	local position = saved and saved[layoutName] or entry.default
	entry.frame:ClearAllPoints()
	entry.frame:SetPoint(position.point, position.x, position.y)
end

local function applyAll()
	for _, entry in ipairs(entries) do
		apply(entry)
	end
end

local function preview(entry, active)
	if entry.onEditMode and entry.module:IsActive() then
		entry.onEditMode(active)
	end
end

-- Positions of one layout under another name (or none, to forget them), in
-- every profile; move drops the old name.
local function copyLayout(from, to, move)
	Storage:EachSection("positions", function(section)
		for _, layouts in pairs(section) do
			if type(layouts) == "table" and layouts[from] then
				if to then
					layouts[to] = layouts[from]
				end
				if move then
					layouts[from] = nil
				end
			end
		end
	end)
end

local function setup()
	lib:RegisterCallback("layout", function(name)
		layoutName = name
		applyAll()
	end)
	lib:RegisterCallback("create", function(name, _, sourceName)
		if sourceName then
			copyLayout(sourceName, name, false)
		end
	end)
	lib:RegisterCallback("rename", function(oldName, newName)
		copyLayout(oldName, newName, true)
		layoutName = layoutName == oldName and newName or layoutName
	end)
	lib:RegisterCallback("delete", function(name)
		copyLayout(name, nil, true)
	end)
	lib:RegisterCallback("enter", function()
		for _, entry in ipairs(entries) do
			preview(entry, true)
		end
	end)
	lib:RegisterCallback("exit", function()
		for _, entry in ipairs(entries) do
			preview(entry, false)
		end
	end)
	Bus:On("ProfileChanged", EditMode, applyAll)
	Bus:On("ModuleToggled", EditMode, function(_, name, active)
		for _, entry in ipairs(entries) do
			if entry.module.name == name then
				if active then
					apply(entry)
				end
				if lib:IsInEditMode() then
					preview(entry, active)
				end
			end
		end
	end)
	-- A value changed on the options page shows in an open Edit Mode dialog.
	-- A change made in the dialog itself does not rebuild it: that would hide
	-- and recreate the slider being dragged.
	Bus:On("SettingChanged", EditMode, function(_, name)
		if lib:IsInEditMode() and not fromDialog then
			for _, entry in ipairs(entries) do
				if entry.module.name == name and entry.settings then
					lib:RefreshFrameSettings(entry.frame)
				end
			end
		end
	end)
end

-- Stores a value set in the Edit Mode dialog, marked as coming from it.
local function store(name, key, value)
	fromDialog = true
	local ok, problem = pcall(Storage.Set, Storage, name, key, value)
	fromDialog = false
	if not ok then
		error(problem, 0)
	end
end

-- A module setting as a LibEditMode setting object. Settings are per profile,
-- so the layout name that LibEditMode passes is not used. A header becomes a
-- divider with its title, or nothing where LibEditMode has no dividers.
local function toLibSetting(module, setting)
	local name = module.name
	if setting.kind == "header" then
		return lib.SettingType.Divider and { kind = lib.SettingType.Divider, name = setting.label } or nil
	end
	local object = {
		name = setting.label,
		desc = setting.tooltip,
		default = Storage:GetDefault(name, setting.key),
		get = function()
			return Storage:Get(name, setting.key)
		end,
		set = function(_, value)
			store(name, setting.key, value)
		end,
	}
	if setting.kind == "checkbox" then
		object.kind = lib.SettingType.Checkbox
	elseif setting.kind == "slider" then
		object.kind = lib.SettingType.Slider
		object.minValue, object.maxValue, object.valueStep = setting.min, setting.max, setting.step
		object.set = function(_, value)
			store(name, setting.key, Storage.OnStep(value, setting.min, setting.max, setting.step))
		end
		local format = setting.format
		if format then
			object.formatter = type(format) == "function" and format or function(value)
				return format:format(value)
			end
		end
	elseif setting.kind == "dropdown" then
		object.kind = lib.SettingType.Dropdown
		object.values = {}
		for index, choice in ipairs(setting.choices) do
			object.values[index] = { value = choice[1], text = choice[2] }
		end
	else
		error(("%s.%s: unknown Edit Mode setting kind %s"):format(name, setting.key, tostring(setting.kind)))
	end
	return object
end

-- Registers a frame once, when the module creates it. Returns false on a
-- client without LibEditMode, where the frame stays where the module put it.
function EditMode.Register(module, frame, options)
	if not lib then
		lib = LibStub and LibStub("LibEditMode", true)
		if not lib then
			return false
		end
		setup()
	end
	local entry = {
		module = module,
		frame = frame,
		key = options.key or module.name,
		default = options.default,
		onEditMode = options.onEditMode,
		settings = options.settings,
	}
	entries[#entries + 1] = entry
	lib:AddFrame(frame, function(_, name, point, x, y)
		if not name then
			return
		end
		local layouts = positions()[entry.key] or {}
		positions()[entry.key] = layouts
		layouts[name] = { point = point, x = x, y = y }
	end, options.default, options.name or module.title)
	if options.settings then
		local objects = {}
		for _, setting in ipairs(options.settings) do
			objects[#objects + 1] = toLibSetting(module, setting)
		end
		lib:AddFrameSettings(frame, objects)
	end
	if options.buttons then
		lib:AddFrameSettingsButtons(frame, options.buttons)
	end
	apply(entry)
	if lib:IsInEditMode() then
		preview(entry, true)
	end
	return true
end
