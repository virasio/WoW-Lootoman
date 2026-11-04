local _, ns = ...
local L = ns.L

-- The settings of the module's page; the Edit Mode dialog shows the ones it
-- can (not the colour).
local function settings()
	return {
		{ kind = "header", label = L["Look"] },
		{ kind = "color", key = "color", label = L["Default colour"],
			tooltip = L["For the text between the tokens, and for tokens without a colour of their own."] },
		{ kind = "slider", key = "size", label = L["Text size"], min = 8, max = 32, step = 1, format = "%d" },
		{ kind = "checkbox", key = "broker", label = L["Also in broker panels"],
			tooltip = L["Offers the text to broker displays such as Titan Panel or ElvUI's data texts."] },
	}
end

-- The free-slot bar: the bags' free space as one line of text, in the
-- player's own format and colours (Template.lua), placed with Edit Mode. Its
-- tooltip lists the free and total slots of every kind of bag. The text
-- follows the bags, the settings and the profile. The same text goes to broker
-- displays when one is loaded (Integrations/Broker.lua), with the tooltip and
-- a click that opens the bags.
local FreeSlots = ns.Modules:Register({
	name = "FreeSlots",
	title = L["Free slots"],
	switchLabel = L["Enable the free-slot bar"],
	description = L["Shows the free slots of your bags as text, in your own format and colours."],
	defaults = {
		enabled = true,
		template = "{free|33ff33} ({reagent|ffd100}) / {general}",
		color = "ffffffff",
		size = 14,
		broker = true,
	},
	settings = settings,
})

-- Left of the bag buttons, above the micro menu.
FreeSlots.DEFAULT_POSITION = { point = "BOTTOMRIGHT", x = -260, y = 52 }
FreeSlots.MAX_TEMPLATE = 200
-- Room around the text, so it is easy to point at.
FreeSlots.PADDING = 4
FreeSlots.BROKER_NAME = "Lootoman: free slots"
FreeSlots.ICON = [[Interface\Icons\INV_Misc_Bag_08]]

-- The bar's text now.
function FreeSlots:Text()
	return self.Template.Render(self:Get("template"), ns.Bags.FreeSlots(), self:Get("color"))
end

-- The tooltip's lines: free and total slots of all bags and of each kind the
-- player has.
function FreeSlots.TooltipLines()
	local slots = ns.Bags.FreeSlots()
	local lines = { L["All bags: %d free of %d"]:format(slots.free, slots.total) }
	local kinds = {
		{ "general", L["General bags: %d free of %d"] },
		{ "reagent", L["Reagent bag: %d free of %d"] },
		{ "profession", L["Profession bags: %d free of %d"] },
	}
	for _, kind in ipairs(kinds) do
		if slots[kind[1] .. "Total"] > 0 then
			lines[#lines + 1] = kind[2]:format(slots[kind[1]], slots[kind[1] .. "Total"])
		end
	end
	return lines
end

function FreeSlots:Refresh()
	if not self.frame then
		return
	end
	local text = self:Text()
	local label = self.frame.Label
	local font = { GameFontNormal:GetFont() }
	label:SetFont(font[1], self:Get("size"), font[3])
	label:SetText(text)
	local padding = FreeSlots.PADDING
	self.frame:SetSize(math.max(label:GetUnboundedStringWidth(), 20) + 2 * padding, self:Get("size") + 2 * padding)
	self:UpdateBroker(text)
end

-- The broker object, made the first time the switch is on and a display is
-- there; turned off, its text is empty (LibDataBroker cannot remove it).
function FreeSlots:UpdateBroker(text)
	if not self.broker and self:Get("broker") then
		self.broker = ns.Integrations.Broker.Object(FreeSlots.BROKER_NAME, {
			type = "data source",
			label = L["Free slots"],
			icon = FreeSlots.ICON,
			OnTooltipShow = function(tooltip)
				tooltip:AddLine(L["Free slots"])
				for _, line in ipairs(FreeSlots.TooltipLines()) do
					tooltip:AddLine(line, 1, 1, 1)
				end
			end,
			OnClick = function()
				ToggleAllBags()
			end,
		})
	end
	if self.broker then
		self.broker.text = self:Get("broker") and text or ""
	end
end

local function createFrame(module)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame.Label = frame:CreateFontString(nil, "OVERLAY")
	frame.Label:SetPoint("CENTER")
	frame.Label:SetWordWrap(false)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L["Free slots"])
		for _, line in ipairs(FreeSlots.TooltipLines()) do
			GameTooltip_AddNormalLine(GameTooltip, line)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	module.frame = frame
	ns.EditMode.Register(module, frame, {
		default = FreeSlots.DEFAULT_POSITION,
		settings = module:Settings(),
		buttons = { { text = L["Edit the text"], click = function() module:EditTemplate() end } },
	})
end

-- Asks for the template, filled in with the current one. An edit box shows a
-- "|" only doubled and gives a typed one back doubled; the template is kept
-- with single ones.
function FreeSlots:EditTemplate()
	ns.NameMenu.AskName(L["The free-slot bar's text. Tokens: %s"], self.TokenList(), (self:Get("template"):gsub("|", "||")),
		FreeSlots.MAX_TEMPLATE, function(text)
			self:Set("template", (text:gsub("||", "|")))
		end)
end

-- The tokens as the player types them, for the help texts.
function FreeSlots.TokenList()
	local names = {}
	for index, token in ipairs(FreeSlots.Template.TOKENS) do
		names[index] = "{" .. token[1] .. "}"
	end
	return table.concat(names, " ")
end

-- The template is free text, but not longer than the dialog takes.
function FreeSlots:Validate(key, value)
	if key == "template" then
		return #value <= FreeSlots.MAX_TEMPLATE
	end
	return ns.Modules.Mixin.Validate(self, key, value)
end

function FreeSlots:OnEnable()
	if not self.frame then
		createFrame(self)
	end
	self.frame:Show()
	self:Refresh()
	self:On("InventoryChanged", function()
		self:Refresh()
	end)
	self:On("SettingChanged", function(_, module)
		if module == self.name then
			self:Refresh()
		end
	end)
	self:On("ProfileChanged", function()
		self:Refresh()
	end)
end

function FreeSlots:OnDisable()
	if self.frame then
		self.frame:Hide()
	end
	if self.broker then
		self.broker.text = ""
	end
end

function FreeSlots:BuildSettings(category, layout)
	local Panel = ns.SettingsPanel
	Panel.AddButton(layout, L["Text"], L["Edit the text"], function()
		self:EditTemplate()
	end, L["Tokens in braces show the free slots, each with a colour if you like: {free||33ff33}. Tokens: %s"]:format(self.TokenList()))
	Panel.AddSettings(category, layout, self.name, self:Settings())
end
