local _, ns = ...
local Compat, L = ns.Compat, ns.L
local Feed = ns.Feed

-- The loot feed (techspec §7.3): what you pick up shows next to the screen
-- centre and fades out. Sources reads the game's events, Model keeps the rows,
-- Frames draws them; this module connects them to the settings, the options
-- page and Edit Mode, where the feed is placed and where the same settings
-- appear in its dialog. Settings apply at once.
local LootFeed = ns.Modules:Register({
	name = "LootFeed",
	title = L["Loot feed"],
	switchLabel = L["Enable loot feed"],
	description = L["Shows what you pick up: items, currencies, money, reputation and, if you want, experience."],
	defaults = {
		enabled = true,
		items = true,
		currencies = true,
		money = true,
		reputation = true,
		xp = false,
		minQuality = 0,
		maxRows = 8,
		direction = "up",
		duration = 6,
		fade = 1,
		size = 13,
		backgroundOpacity = 50,
		owned = true,
		glow = true,
		-- The named layout of the rows (Layouts.lua).
		layout = "Default",
	},
})

-- Right of the screen centre.
LootFeed.DEFAULT_POSITION = { point = "CENTER", x = 300, y = 0 }

-- Item quality names come from the client, from Poor to Legendary.
local function qualityChoices()
	local choices = {}
	for quality = 0, 5 do
		choices[#choices + 1] = { quality, Compat.GetGlobalString(("ITEM_QUALITY%d_DESC"):format(quality)) or tostring(quality) }
	end
	return choices
end

-- The settings, in groups, for the options page and the Edit Mode dialog
-- alike; the row designer's button ends the last group.
local function settings()
	return {
		{ kind = "header", label = L["What the feed shows"] },
		{ kind = "checkbox", key = "items", label = L["Items"] },
		{ kind = "checkbox", key = "currencies", label = L["Currencies"] },
		{ kind = "checkbox", key = "money", label = L["Money"] },
		{ kind = "checkbox", key = "reputation", label = L["Reputation"] },
		{ kind = "checkbox", key = "xp", label = L["Experience"] },
		{ kind = "dropdown", key = "minQuality", label = L["Minimum quality"],
			tooltip = L["Items of a lower quality are not shown."], choices = qualityChoices() },
		{ kind = "header", label = L["Rows and timing"] },
		{ kind = "slider", key = "maxRows", label = L["Rows"], tooltip = L["How many rows are shown at once. When there are more, the oldest ones fade out at once."],
			min = 1, max = 20, step = 1, format = "%d" },
		{ kind = "dropdown", key = "direction", label = L["New rows appear"],
			tooltip = L["On top: the oldest row stays at the bottom edge and new rows stack above it. At the bottom: the oldest row stays at the top edge and new rows stack below it."],
			choices = { { "up", L["On top"] }, { "down", L["At the bottom"] } } },
		{ kind = "slider", key = "duration", label = L["Time on screen"], tooltip = L["Seconds before a row starts to fade out."],
			min = 2, max = 30, step = 1, format = L["%d s"] },
		{ kind = "slider", key = "fade", label = L["Fade-out time"], min = 0.2, max = 3, step = 0.1, format = L["%.1f s"] },
		{ kind = "header", label = L["Appearance"] },
		{ kind = "slider", key = "size", label = L["Size"], tooltip = L["The size of the text; the icons and rows follow it."],
			min = 10, max = 16, step = 1, format = "%d" },
		{ kind = "slider", key = "backgroundOpacity", label = L["Background opacity"], min = 0, max = 100, step = 5, format = L["%d %%"] },
		{ kind = "checkbox", key = "owned", label = L["Owned count"],
			tooltip = L["Shows on the icon how many of the item you have in your bags and bank, and the total of a currency."] },
		{ kind = "checkbox", key = "glow", label = L["Glow for rare items"], tooltip = L["Rare and better items glow in their quality colour."] },
	}
end

-- Whether a value is one the controls can set; profile texts are read with it
-- (Share). The value already has the default's type.
function LootFeed:Validate(key, value)
	for _, setting in ipairs(settings()) do
		if setting.key == key and setting.kind == "slider" then
			return value >= setting.min and value <= setting.max
		elseif setting.key == key and setting.kind == "dropdown" then
			for _, choice in ipairs(setting.choices) do
				if choice[1] == value then
					return true
				end
			end
			return false
		end
	end
	return true
end

-- In profile texts (Share): the feed's position and the layout it uses under
-- its settings, and the player's layouts.
local Layouts = Feed.Layouts
ns.EditMode.SharePosition(LootFeed.name, LootFeed.name)
ns.Share.RegisterPart({
	name = "layout:LootFeed",
	module = LootFeed.name,
	owns = "layout",
	label = function(data)
		return L["Use layout “%s”"]:format(Layouts.DisplayName(data.layout or Layouts.DEFAULT))
	end,
	get = function()
		return { layout = Layouts.Current() }
	end,
	set = function(profile, data, renamed)
		local name = renamed.layouts and renamed.layouts[data.layout]
		if name then
			profile.modules = type(profile.modules) == "table" and profile.modules or {}
			local values = type(profile.modules.LootFeed) == "table" and profile.modules.LootFeed or {}
			values.layout = name ~= Layouts.DEFAULT and name or nil
			profile.modules.LootFeed = next(values) and values or nil
		end
	end,
	clean = function(data)
		return type(data.layout) == "string" and { layout = data.layout } or nil
	end,
	needs = function(data)
		return "layouts", data.layout
	end,
})
ns.Share.RegisterCollection({
	name = "layouts",
	label = L["Loot feed layouts"],
	list = Layouts.List,
	get = Layouts.Get,
	taken = Layouts.Taken,
	freeName = Layouts.FreeName,
	put = Layouts.Put,
	display = Layouts.DisplayName,
	clean = Feed.Design.Clean,
})

function LootFeed:ModelOptions()
	return {
		maxRows = self:Get("maxRows"),
		duration = self:Get("duration"),
		fade = self:Get("fade"),
		minQuality = self:Get("minQuality"),
		kinds = {
			item = self:Get("items"),
			currency = self:Get("currencies"),
			money = self:Get("money"),
			reputation = self:Get("reputation"),
			xp = self:Get("xp"),
		},
	}
end

-- The design of the rows: the layout the profile uses (Layouts.lua).
function LootFeed:DesignSection()
	return Layouts.CurrentDesign()
end

function LootFeed:Apply()
	self.model:SetOptions(self:ModelOptions(), Compat.GetTime())
	self.feed:SetOptions({
		direction = self:Get("direction"),
		maxRows = self:Get("maxRows"),
		layout = Feed.Design.Layout(Feed.Design.Current(self:DesignSection()), self:Get("size")),
		opacity = self:Get("backgroundOpacity") / 100,
		showOwned = self:Get("owned"),
		showGlow = self:Get("glow"),
	})
end

function LootFeed:OnEnable()
	if not self.feed then
		self.model = Feed.Model.New(self:ModelOptions(), Compat.GetTime())
		self.feed = Feed.Frames.Create(self.model)
		ns.EditMode.Register(self, self.feed.frame, {
			default = self.DEFAULT_POSITION,
			settings = settings(),
			onEditMode = function(active)
				self.feed:SetPreview(active)
			end,
			buttons = { { text = L["Design rows"], click = function() self.Designer.Open() end } },
		})
	end
	self:Apply()
	Feed.Sources.Start(self, function(entry)
		if self.model:Add(entry, Compat.GetTime()) then
			self.feed:Wake()
		end
	end)
	self:On("SettingChanged", function(_, module)
		if module == self.name then
			self:Apply()
		end
	end)
	self:On("ProfileChanged", function()
		self:Apply()
	end)
	-- The designer, a reset or an import changed the layout's design.
	self:On("FeedLayoutChanged", function(_, name)
		if name == Layouts.Current() then
			self:Apply()
		end
	end)
	-- Owned counts change when the looted items reach the bags.
	self:OnEvent("BAG_UPDATE_DELAYED", function()
		self.feed:RefreshOwned()
	end)
end

function LootFeed:OnDisable()
	if self.feed then
		self.feed:SetPreview(false)
		self.feed.frame:Hide()
	end
end

function LootFeed:BuildSettings(category, layout)
	local Panel = ns.SettingsPanel
	Panel.AddSettings(category, layout, self.name, settings())
	Panel.AddButton(layout, L["Row design"], L["Open the designer"], function()
		self.Designer.Open()
	end, L["Change how the feed's rows look: move and resize their parts."])
end
