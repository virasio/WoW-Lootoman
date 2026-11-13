local _, ns = ...
local Compat, L = ns.Compat, ns.L
local Feed = ns.Feed
local Looks = Feed.Looks

-- The loot feed: what you pick up shows next to the screen
-- centre and fades out. Sources reads the game's events, Model keeps the rows,
-- Frames draws them; this module connects them to the feed look the profile
-- uses (Looks.lua), which holds every setting but the feed's switch, and to
-- Edit Mode, where the feed is placed. Changes apply at once.
local LootFeed = ns.Modules:Register({
	name = "LootFeed",
	title = L["Loot feed"],
	switchLabel = L["Enable loot feed"],
	description = L["Shows what you pick up: items, currencies, money, reputation and, if you want, experience."],
	defaults = {
		enabled = true,
		-- The feed look the profile uses (Looks.lua).
		look = "Default",
	},
})

-- Right of the screen centre.
LootFeed.DEFAULT_POSITION = { point = "CENTER", x = 300, y = 0 }

-- A setting of the profile's feed look; the feed's switch and the look it
-- uses are the profile's own.
function LootFeed:Get(key)
	if Looks.DEFAULTS[key] ~= nil then
		return Looks.Value(Looks.Current(), key)
	end
	return ns.Modules.Mixin.Get(self, key)
end

function LootFeed:Set(key, value)
	if Looks.DEFAULTS[key] ~= nil then
		assert(Looks.Set(Looks.Current(), key, value), ("LootFeed.%s cannot be %s"):format(key, tostring(value)))
		return
	end
	ns.Modules.Mixin.Set(self, key, value)
end

-- In profile texts (Share): the feed's position and the look it uses under
-- its settings, and the player's looks.
ns.EditMode.SharePosition(LootFeed.name, LootFeed.name)
ns.Share.RegisterPart({
	name = "look:LootFeed",
	module = LootFeed.name,
	owns = "look",
	label = function(data)
		return L["Use look “%s”"]:format(Looks.DisplayName(data.look or Looks.DEFAULT))
	end,
	get = function()
		return { look = Looks.Current() }
	end,
	set = function(profile, data, renamed)
		local name = renamed.looks and renamed.looks[data.look]
		if name then
			profile.modules = type(profile.modules) == "table" and profile.modules or {}
			local values = type(profile.modules.LootFeed) == "table" and profile.modules.LootFeed or {}
			values.look = name ~= Looks.DEFAULT and name or nil
			profile.modules.LootFeed = next(values) and values or nil
		end
	end,
	clean = function(data)
		return type(data.look) == "string" and { look = data.look } or nil
	end,
	needs = function(data)
		return "looks", data.look
	end,
})
ns.Share.RegisterCollection({
	name = "looks",
	label = L["Loot feed looks"],
	list = Looks.List,
	get = Looks.Get,
	taken = Looks.Taken,
	freeName = Looks.FreeName,
	put = Looks.Put,
	display = Looks.DisplayName,
	clean = Looks.Clean,
})

-- Texts of 0.1 to 0.4 (format 1) held the feed's settings in its own part,
-- the layout it used in another, and row layouts: they become looks, as saved
-- data did (Migrations.FeedLookFrom). The look of the feed's settings is
-- named after the layout it used, Default without one; every other layout
-- becomes a look too.
ns.Share.RegisterUpgrade(1, function(data)
	local sections = type(data.sections) == "table" and data.sections or {}
	local collections = type(data.collections) == "table" and data.collections or {}
	local layouts = type(collections.layouts) == "table" and collections.layouts or {}
	local feed = type(sections["module:LootFeed"]) == "table" and sections["module:LootFeed"] or nil
	local usePart = type(sections["layout:LootFeed"]) == "table" and sections["layout:LootFeed"] or nil
	local used = usePart and type(usePart.layout) == "string" and usePart.layout or nil
	local looks = type(collections.looks) == "table" and collections.looks or {}
	for name, layout in pairs(layouts) do
		if type(name) == "string" and type(layout) == "table" then
			looks[name] = ns.Migrations.FeedLookFrom(name == used and feed or nil, layout)
		end
	end
	if feed then
		local name = used or Looks.DEFAULT
		if not looks[name] then
			looks[name] = ns.Migrations.FeedLookFrom(feed, nil)
		end
		sections["module:LootFeed"] = { enabled = feed.enabled }
		sections["look:LootFeed"] = { look = name }
	end
	sections["layout:LootFeed"] = nil
	collections.layouts = nil
	if next(looks) then
		collections.looks = looks
	end
	data.sections, data.collections = sections, collections
end)

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

-- The design of the rows: the look's (Looks.lua).
function LootFeed:DesignSection()
	return Looks.Get(Looks.Current())
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

-- Whether the feed keeps items of a kind of usable item: not while it shows
-- no items at all.
function LootFeed:Keeps(kind)
	return self:Get("items") and self:Get("keepUsable") and Looks.KEEP[kind] ~= nil and self:Get(Looks.KEEP[kind][1]) == true
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
	self.model:SetOptions(self:ModelOptions(), Compat.GetTime())
	self.feed:SetOptions({
		direction = self:Get("direction"),
		maxRows = self:Get("maxRows"),
		layout = Feed.Design.Layout(Feed.Design.Current(self:DesignSection()), self:Get("size")),
		opacity = self:Get("backgroundOpacity") / 100,
		-- Whether the owned count shows is the design's (its part's Shown).
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
			onEditMode = function(active)
				self.feed:SetPreview(active)
			end,
			buttons = { { text = L["Design rows"], click = function() self.LookWindow.Open() end } },
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
	self:On("SettingChanged", function(_, module)
		if module ~= self.name then
			return
		end
		self:Apply()
		self:CheckAll()
	end)
	self:On("ProfileChanged", function()
		self:Apply()
		self:CheckAll()
	end)
	-- The look's settings or design changed: in the designer, a reset, an import.
	self:On("FeedLookChanged", function(_, name)
		if name == Looks.Current() then
			self:Apply()
			self:CheckAll()
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

function LootFeed:BuildSettings(_, layout)
	local Panel = ns.SettingsPanel
	Panel.AddButton(layout, L["Row design"], L["Open the designer"], function()
		self.LookWindow.Open()
	end, L["Change how the feed's rows look: move and resize their parts."])
end
