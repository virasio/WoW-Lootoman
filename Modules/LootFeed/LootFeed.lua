local _, ns = ...
local Compat, L = ns.Compat, ns.L
local Feed = ns.Feed

-- Item quality names come from the client, from Poor to Legendary.
local function qualityChoices()
	local choices = {}
	for quality = 0, 5 do
		choices[#choices + 1] = { quality, Compat.GetGlobalString(("ITEM_QUALITY%d_DESC"):format(quality)) or tostring(quality) }
	end
	return choices
end

-- Directions the feed fills in; the sideways ones only with icons.
local DIRECTIONS = {
	{ "up", L["Bottom to top"] },
	{ "down", L["Top to bottom"] },
	{ "right", L["Left to right"] },
	{ "left", L["Right to left"] },
}
local SIDEWAYS = { left = true, right = true }
local VALID_DIRECTION = { up = true, down = true, left = true, right = true }

-- Whether the profile's layout is of the icons view.
local function usesIcons()
	local Design = Feed.Design
	return Design.View(Design.Current(Feed.Layouts.CurrentDesign())) == "icons"
end

local function currentView()
	return usesIcons() and "icons" or "rows"
end

-- The directions the controls offer now: rows fill only up or down.
local function offeredDirections()
	if usesIcons() then
		return DIRECTIONS
	end
	return { DIRECTIONS[1], DIRECTIONS[2] }
end

-- The setting of each kind of usable item the feed keeps (Rules/Usable.lua),
-- and its label.
local KEEP = {
	quest = { "keepQuest", L["Items that start a quest"] },
	recipe = { "keepRecipes", L["Recipes"] },
	container = { "keepContainers", L["Containers"] },
	pet = { "keepPets", L["Pets"] },
	mount = { "keepMounts", L["Mounts"] },
	toy = { "keepToys", L["Toys"] },
	set = { "keepSets", L["Appearance sets"] },
	heirloom = { "keepHeirlooms", L["Heirlooms"] },
}

-- The settings, in groups, for the options page and the Edit Mode dialog
-- alike; the row designer's button ends the last group. The kinds of usable
-- item are on the options page only, under their switch, so the dialog stays
-- short; a kind the client has no collection for is not offered.
local function settings()
	local list = {
		{ kind = "header", label = L["What the feed shows"] },
		{ kind = "checkbox", key = "items", label = L["Items"] },
		{ kind = "checkbox", key = "currencies", label = L["Currencies"] },
		{ kind = "checkbox", key = "money", label = L["Money"] },
		{ kind = "checkbox", key = "reputation", label = L["Reputation"] },
		{ kind = "checkbox", key = "xp", label = L["Experience"] },
		{ kind = "dropdown", key = "minQuality", label = L["Minimum quality"],
			tooltip = L["Items of a lower quality are not shown."], choices = qualityChoices() },
		{ kind = "checkbox", key = "keepUsable", label = L["Keep usable items"],
			tooltip = L["Items this character can use right now stay at the start of the feed, after any warnings, also below the minimum quality, until you click them: left to dismiss, right to use."] },
	}
	for _, kind in ipairs(ns.Rules.Usable.Kinds()) do
		list[#list + 1] = { kind = "checkbox", key = KEEP[kind][1], label = KEEP[kind][2], parent = "keepUsable", pageOnly = true }
	end
	local rest = {
		{ kind = "header", label = L["Rows and timing"] },
		{ kind = "slider", key = "maxRows", label = L["Rows"], tooltip = L["How many rows are shown at once. When there are more, the oldest ones fade out at once."],
			min = 3, max = 20, step = 1, format = "%d" },
		{ kind = "dropdown", key = "direction", label = L["Fill direction"],
			tooltip = L["Where new entries go. Bottom to top: the oldest one stays at the bottom edge and new ones stack above it; the other directions likewise. Left to right and right to left are for the Icons layouts."],
			choices = DIRECTIONS, offered = offeredDirections },
		{ kind = "slider", key = "duration", label = L["Time on screen"], tooltip = L["Seconds before a row starts to fade out."],
			min = 2, max = 30, step = 1, format = L["%d s"] },
		{ kind = "slider", key = "fade", label = L["Fade-out time"], min = 0.2, max = 3, step = 0.1, format = L["%.1f s"] },
		{ kind = "header", label = L["Appearance"] },
		{ kind = "slider", key = "size", label = L["Size"], tooltip = L["The size of the text; the icons and rows follow it."],
			min = 10, max = 16, step = 1, format = "%d" },
		{ kind = "slider", key = "backgroundOpacity", label = L["Background opacity"], min = 0, max = 100, step = 5, format = L["%d %%"] },
		{ kind = "checkbox", key = "glow", label = L["Glow for rare items"], tooltip = L["Rare and better items glow in their quality colour."] },
		{ kind = "header", label = L["Low-space warnings"] },
		{ kind = "checkbox", key = "warnGeneral", label = L["Warn when few bag slots are free"],
			tooltip = L["Shows a warning at the feed's edge while no more general bag slots are free than the number below."] },
		{ kind = "slider", key = "warnGeneralAt", label = L["Bag slots"], min = 0, max = 20, step = 1, format = "%d" },
		{ kind = "checkbox", key = "warnReagent", label = L["Warn when few reagent bag slots are free"],
			tooltip = L["Shows a warning at the feed's edge while no more reagent bag slots are free than the number below."] },
		{ kind = "slider", key = "warnReagentAt", label = L["Reagent bag slots"], min = 0, max = 20, step = 1, format = "%d" },
	}
	for _, setting in ipairs(rest) do
		list[#list + 1] = setting
	end
	return list
end

-- The loot feed: what you pick up shows next to the screen
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
		-- Usable items stay at the start until clicked (Rules/Usable.lua).
		keepUsable = true,
		keepQuest = true,
		keepRecipes = true,
		keepContainers = true,
		keepPets = true,
		keepMounts = true,
		keepToys = true,
		keepSets = true,
		keepHeirlooms = true,
		-- At least 3: a place for a kept item, two for the rest.
		maxRows = 8,
		direction = "up",
		-- The direction the other view (rows or icons) left: each keeps its own,
		-- and switching views swaps the two. It has no control of its own.
		otherViewDirection = "up",
		duration = 6,
		fade = 1,
		size = 13,
		backgroundOpacity = 50,
		glow = true,
		-- The named layout of the rows (Layouts.lua).
		layout = "Default",
		-- The feed look the profile uses (Looks.lua).
		look = "Default",
		-- Low-space warnings at the feed's anchor edge.
		warnGeneral = true,
		warnGeneralAt = 2,
		warnReagent = false,
		warnReagentAt = 2,
	},
	settings = settings,
})

-- Right of the screen centre.
LootFeed.DEFAULT_POSITION = { point = "CENTER", x = 300, y = 0 }

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

-- The low-space warnings that hold now, each { text, count }: few free
-- general slots, few free reagent bag slots (only with a reagent bag), each
-- by its own threshold. Nothing before the client has told the bags (no
-- slots at all).
function LootFeed:Warnings()
	local slots, warnings = ns.Bags.FreeSlots(), {}
	if self:Get("warnGeneral") and slots.generalTotal > 0 and slots.general <= self:Get("warnGeneralAt") then
		warnings[#warnings + 1] = { count = slots.general,
			text = slots.general == 0 and L["No free bag slots"] or L["Free bag slots: %d"]:format(slots.general) }
	end
	if self:Get("warnReagent") and slots.reagentTotal > 0 and slots.reagent <= self:Get("warnReagentAt") then
		warnings[#warnings + 1] = { count = slots.reagent,
			text = slots.reagent == 0 and L["No free reagent bag slots"] or L["Free reagent bag slots: %d"]:format(slots.reagent) }
	end
	return warnings
end

-- The direction the feed fills in: a sideways one left from an Icons layout
-- counts as bottom to top with rows.
function LootFeed:Direction()
	local direction = self:Get("direction")
	if SIDEWAYS[direction] and not usesIcons() then
		return "up"
	end
	return direction
end

-- After a switch between a rows layout and an Icons layout: the new view gets
-- back the direction it had, and keeps the old view's for the way back.
function LootFeed:SwapDirections()
	local current, other = self:Get("direction"), self:Get("otherViewDirection")
	self:Set("otherViewDirection", VALID_DIRECTION[current] and current or "up")
	self:Set("direction", VALID_DIRECTION[other] and other or "up")
end

-- After the profile's layout or its design changed: when the view changed
-- with it, the directions swap; a rows layout fills only up or down. Returns
-- whether the view changed.
function LootFeed:FollowView()
	local changed = self.view ~= nil and currentView() ~= self.view
	if changed then
		self.view = currentView()
		self:SwapDirections()
	end
	if self:Direction() ~= self:Get("direction") then
		self:Set("direction", self:Direction())
	end
	return changed
end

-- Whether the feed keeps items of a kind of usable item: not while it shows
-- no items at all.
function LootFeed:Keeps(kind)
	return self:Get("items") and self:Get("keepUsable") and KEEP[kind] ~= nil and self:Get(KEEP[kind][1]) == true
end

-- A looted item below the minimum quality waits this long for the bags to
-- hold it: a usable one comes in anyway.
LootFeed.WAIT = 10

-- Counts a kept row down as its items are used: by as much as the bags'
-- count fell since the last check, so copies the bags held before the loot
-- do not keep it; more of the item looted merges into the row (Model.lua).
-- Returns false once the row's items are all used. A count of none while the
-- bags' scan still holds the item waits for the scan.
local function countDown(row)
	local count = Compat.GetItemCount(row.id, true)
	if count <= 0 then
		return true
	end
	local last = row.lastCount or count
	row.lastCount = count
	local amount = math.min((row.amount or 1) - math.max(0, last - count), count)
	if amount <= 0 then
		return false
	end
	row.amount = amount
	return true
end

-- Whether a looted item, once the bags hold it, is a usable one the feed
-- keeps: its row sticks, or stops being sticky. A kept row counts down what
-- is left as each use takes one, and goes when its items are used up or have
-- left the bags.
function LootFeed:CheckUsable(row, now)
	if row.kind ~= "item" or not row.id then
		return
	end
	local kind, held, behind = ns.Rules.Usable.Find(row.id)
	-- The item moved and the bags' scan has not caught up: the next one decides.
	if behind then
		return
	end
	if not held then
		if row.held then
			self.model:SetSticky(row, nil, now)
		end
		return
	end
	row.held = true
	if kind and self:Keeps(kind) then
		self.model:SetSticky(row, countDown(row) and kind or nil, now)
	elseif row.sticky then
		self.model:SetSticky(row, nil, now)
	end
end

-- Checks every row again, and the items waiting below the minimum quality.
function LootFeed:CheckAll()
	local now = Compat.GetTime()
	local rows = {}
	for index, row in ipairs(self.model.rows) do
		rows[index] = row
	end
	for _, row in ipairs(rows) do
		self:CheckUsable(row, now)
	end
	for index = #self.lowQuality, 1, -1 do
		local waiting = self.lowQuality[index]
		local kind, held, behind = ns.Rules.Usable.Find(waiting.entry.id)
		if (held and not behind) or now - waiting.at > LootFeed.WAIT then
			table.remove(self.lowQuality, index)
			if held and kind and self:Keeps(kind) then
				local row = self.model:Add(waiting.entry, now, true)
				if row then
					self:CheckUsable(row, now)
				end
			end
		end
	end
	self.feed:Wake()
end

function LootFeed:Apply()
	self.view = currentView()
	self.model:SetOptions(self:ModelOptions(), Compat.GetTime())
	self.feed:SetOptions({
		direction = self:Direction(),
		maxRows = self:Get("maxRows"),
		layout = Feed.Design.Layout(Feed.Design.Current(self:DesignSection()), self:Get("size")),
		opacity = self:Get("backgroundOpacity") / 100,
		-- Whether the owned count shows is the layout's (its part's Shown).
		showOwned = Feed.Design.Current(self:DesignSection()).parts.owned.shown,
		showGlow = self:Get("glow"),
	})
	self.feed:SetWarnings(self:Warnings())
end

function LootFeed:OnEnable()
	if not self.feed then
		self.model = Feed.Model.New(self:ModelOptions(), Compat.GetTime())
		self.feed = Feed.Frames.Create(self.model)
		ns.EditMode.Register(self, self.feed.frame, {
			default = self.DEFAULT_POSITION,
			settings = self:Settings(),
			onEditMode = function(active)
				self.feed:SetPreview(active)
			end,
			buttons = { { text = L["Design rows"], click = function() self.Designer.Open() end } },
		})
		self.feed.useButton = Feed.UseButton.Create(self.feed)
	end
	self.feed.disabled = false
	self.lowQuality = {}
	self:Apply()
	Feed.Sources.Start(self, function(entry)
		local now = Compat.GetTime()
		local row = self.model:Add(entry, now)
		if row then
			self:CheckUsable(row, now)
			self.feed:Wake()
		elseif entry.kind == "item" and entry.id and self:Get("keepUsable") and self:Get("items") then
			-- Below the minimum quality: shown anyway if it turns out usable.
			self.lowQuality[#self.lowQuality + 1] = { entry = entry, at = now }
		end
	end)
	self:On("SettingChanged", function(_, module, key)
		if module ~= self.name then
			return
		end
		-- Each view keeps its own direction, and the dialog offers what it can.
		if key == "layout" then
			self:FollowView()
			ns.EditMode.Refresh(self.feed.frame)
		end
		self:Apply()
		self:CheckAll()
	end)
	self:On("ProfileChanged", function()
		self:Apply()
		self:CheckAll()
	end)
	-- The designer, a reset or an import changed the layout's design; an
	-- import may put a design of the other view in its place.
	self:On("FeedLayoutChanged", function(_, name)
		if name == Layouts.Current() then
			if self:FollowView() then
				ns.EditMode.Refresh(self.feed.frame)
			end
			self:Apply()
		end
	end)
	-- Owned counts change when the looted items reach the bags.
	self:OnEvent("BAG_UPDATE_DELAYED", function()
		self.feed:RefreshOwned()
	end)
	-- So does what the character can use, read from the bags once they are read
	-- again; and taking a quest from an item.
	self:On("InventoryChanged", function()
		self.feed:SetWarnings(self:Warnings())
		self:CheckAll()
	end)
	self:OnEvent("QUEST_ACCEPTED", function()
		self:CheckAll()
	end)
end

function LootFeed:OnDisable()
	if self.feed then
		self.feed:SetPreview(false)
		self.feed:SetWarnings({})
		self.feed.frame:Hide()
		-- The use button hides now, or after the fight.
		self.feed.disabled = true
		self.feed:SyncUse()
	end
end

function LootFeed:BuildSettings(category, layout)
	local Panel = ns.SettingsPanel
	Panel.AddSettings(category, layout, self.name, self:Settings())
	Panel.AddButton(layout, L["Row design"], L["Open the designer"], function()
		self.Designer.Open()
	end, L["Change how the feed's rows look: move and resize their parts."])
end
