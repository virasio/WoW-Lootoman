local _, ns = ...
local Bus, Compat, L = ns.Bus, ns.Compat, ns.L
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
	switchLabel = L["Show the Loot Feed"],
	description = L["Shows what you pick up: items, currencies, money, reputation and, if you want, experience."],
	defaults = {
		enabled = true,
		-- The feed look the profile uses (Looks.lua).
		look = "Default",
	},
	-- Under the switch, the look the profile uses, with the look menu: the
	-- dropdown looks as it does in the feed's Edit Mode dialog, with the same menu.
	mainSettings = { { kind = "custom", build = function(page, indent)
		local row = page:NewRow()
		local dropdown = page:NewDropdown(row)
		dropdown:SetupMenu(Feed.LookMenu.Build)
		page:AddRow(L["Feed Look"], dropdown, { indent = indent, height = 30,
			tooltip = L["The feed look this profile uses: every setting of the feed and its row design. Its menu opens it to edit."] })
		page.look = dropdown
		-- Edit: the window of the look the profile uses.
		local edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		edit:SetSize(90, 22)
		edit:SetPoint("LEFT", dropdown, "RIGHT", 8, 0)
		edit:SetText(L["Edit"])
		edit:SetScript("OnClick", function()
			Feed.LookWindow.Open()
		end)
		edit:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L["Edit"])
			GameTooltip_AddNormalLine(GameTooltip, L["Opens the window of the look this profile uses: its settings, its row design and the feed's position."])
			GameTooltip:Show()
		end)
		edit:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		page.lookEdit = edit
		page:OnRefresh(function()
			dropdown:GenerateMenu()
			local enabled = ns.Storage:Get("LootFeed", "enabled")
			dropdown:SetEnabled(enabled)
			edit:SetEnabled(enabled)
		end)
	end } },
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
		stagger = self:Get("stagger"),
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

-- The low-space warning, or nil: shown while any threshold switched on is
-- reached (free slots in all bags, in the general bags, in a reagent bag the
-- character has), with every kind of bag's count in its amount, as the
-- look's template writes them, and in its tooltip. A click opens the toss
-- window while junk management is on.
function LootFeed:Warning()
	local slots = ns.Bags.FreeSlots()
	local reached = (self:Get("warnTotal") and slots.total > 0 and slots.free <= self:Get("warnTotalAt"))
		or (self:Get("warnGeneral") and slots.generalTotal > 0 and slots.general <= self:Get("warnGeneralAt"))
		or (self:Get("warnReagent") and slots.reagentTotal > 0 and slots.reagent <= self:Get("warnReagentAt"))
	if not reached then
		return nil
	end
	local junk = ns.Modules:Get("Junk")
	return {
		amount = Feed.SlotsText.Render(self:Get("slotsText"), slots, "ffffffff"),
		lines = Feed.Frames.SlotLines(slots),
		clickable = junk ~= nil and junk:IsActive(),
	}
end

-- An item looted that Lootoman's junk rule calls junk (gray, or marked junk,
-- and not marked not junk) becomes part of the one junk row, while the look
-- wants it: { kind = "item", parts = { { key, link, amount } }, the item's
-- quality for the minimum quality }. Below the minimum quality it stays as it
-- is, to be dropped, or kept if the character can use it.
function LootFeed:AsJunk(entry)
	if entry.kind ~= "item" or not entry.id or not self:Get("junkRow") then
		return entry
	end
	if entry.quality ~= nil and entry.quality < self:Get("minQuality") then
		return entry
	end
	if not ns.Rules.Junk.Decide({ itemID = entry.id, quality = entry.quality }).junk then
		return entry
	end
	return {
		kind = "item",
		name = L["Junk"],
		quality = entry.quality,
		amount = entry.amount or 1,
		parts = { { key = entry.id, link = entry.link or entry.name, amount = entry.amount or 1, entry = entry } },
	}
end

-- A junk row's item the character turns out to be able to use, once the bags
-- hold it (a picked lockbox, gray as it is), leaves the junk row for a row of
-- its own, kept as any usable item; the junk row goes with its last item.
function LootFeed:CheckJunk(row, now)
	for index = #row.parts, 1, -1 do
		local part = row.parts[index]
		local kind, held, behind = ns.Rules.Usable.Find(part.key)
		if held and not behind and kind and self:Keeps(kind) then
			table.remove(row.parts, index)
			row.amount = (row.amount or 0) - part.amount
			part.entry.amount = part.amount
			local own = self.model:Add(part.entry, now, true)
			if own then
				self:CheckUsable(own, now)
			end
		end
	end
	if #row.parts == 0 then
		self.model:Release(row)
	end
end

-- Asks for the junk module's toss window, the window that frees room in the
-- bags; nothing opens while junk management is off.
function LootFeed:OpenTossWindow()
	Bus:Send("OpenTossWindow")
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
-- is left as each use takes one, and goes at once when its items are used up
-- or have left the bags. One still in the bags that cannot be used right now
-- (or is no longer kept) fades out as any row, and sticks again if it becomes
-- usable before it is gone.
function LootFeed:CheckUsable(row, now)
	if row.parts then
		self:CheckJunk(row, now)
		return
	end
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
		self.model:Unstick(row, now)
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
	self.feed:SetWarning(self:Warning())
end

function LootFeed:OnEnable()
	if not self.feed then
		self.model = Feed.Model.New(self:ModelOptions(), Compat.GetTime())
		self.feed = Feed.Frames.Create(self.model)
		ns.EditMode.Register(self, self.feed.frame, {
			-- In Edit Mode's title case, as its own frames are named.
			name = L["Loot Feed"],
			default = self.DEFAULT_POSITION,
			-- Picked in Edit Mode, the feed opens its look's window, which holds every
			-- setting, the choice of look and the position's reset.
			window = function()
				self.LookWindow.Open()
			end,
			onEditMode = function(active)
				self.feed:SetPreview(active)
			end,
		})
		self.feed.useButton = Feed.UseButton.Create(self.feed)
		self.feed.onWarningClick = function()
			self:OpenTossWindow()
		end
	end
	self.feed.disabled = false
	self.lowQuality = {}
	self:Apply()
	Feed.Sources.Start(self, function(entry)
		local now = Compat.GetTime()
		entry = self:AsJunk(entry)
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
		if key == "look" then
			ns.EditMode.Refresh(self.feed.frame)
		end
		self:Apply()
		self:CheckAll()
	end)
	self:On("FeedLookRenamed", function()
		ns.EditMode.Refresh(self.feed.frame)
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
		self.feed:SetWarning(self:Warning())
		self:CheckAll()
	end)
	self:OnEvent("QUEST_ACCEPTED", function()
		self:CheckAll()
	end)
	-- Shift held: every item row takes clicks, for its link into the chat.
	self:OnEvent("MODIFIER_STATE_CHANGED", function()
		self.feed:SetLinkModifier(IsModifiedClick("CHATLINK") == true)
	end)
	-- The warning's click opens the toss window only while junk management is on.
	self:On("ModuleToggled", function(_, name)
		if name == "Junk" then
			self.feed:SetWarning(self:Warning())
		end
	end)
end

function LootFeed:OnDisable()
	if self.feed then
		self.feed:SetPreview(false)
		self.feed:SetWarning(nil)
		self.feed.frame:Hide()
		-- The use button hides now, or after the fight.
		self.feed.disabled = true
		self.feed:SyncUse()
	end
end
