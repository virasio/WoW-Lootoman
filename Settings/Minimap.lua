local addonName, ns = ...
local Bus, Compat, L, Storage = ns.Bus, ns.Compat, ns.L, ns.Storage

-- The minimap icon and the addon compartment entry, so a player finds the
-- addon after installing it. A click opens the options; a right click a menu:
-- the options, the loot feed's look, the junk window, the loot rolls' ninja
-- rules, and the bug report. An entry whose feature is off asks to turn it on.
--
-- The icon is a round button on the minimap's edge, as LibDBIcon draws its
-- buttons (the same textures), with a global name so minimap button
-- collectors find it. Dragged with the left button it goes round the edge;
-- its angle is kept. The minimap is round, or square when another addon's
-- GetMinimapShape() says so; its size follows Edit Mode's minimap size, a
-- scale of the minimap, which its child takes on. Shown or not per character
-- (the checkbox at the top right of the options page), never part of a
-- profile or a profile text: { shown, angle } in the character's section
-- "minimap". The compartment entry is there whether the icon shows or not,
-- on a client that has the compartment.
local Icon = {}
ns.MinimapIcon = Icon

Icon.NAME = "LootomanMinimapButton"
Icon.SECTION = "minimap"
Icon.SIZE = 31
-- Bottom left, as LibDBIcon starts its buttons.
Icon.ANGLE = 225
-- How far past the minimap's edge the button's centre sits.
Icon.RADIUS = 5
-- Lootoman's own picture, the one the TOC names for the addon list: a bag of
-- coins with a purple gem, painted to the edges, with no frame to cut away.
Icon.TEXTURE = [[Interface\AddOns\Lootoman\Art\Icon]]
-- LibDBIcon's textures: the border, the background and the highlight.
Icon.BORDER, Icon.BACKGROUND, Icon.HIGHLIGHT = 136430, 136467, 136477

local button

-- The character's place for the icon, filled with the defaults.
function Icon.Saved()
	local saved = Storage:GetCharacterSection(Icon.SECTION)
	if type(saved.shown) ~= "boolean" then
		saved.shown = true
	end
	if type(saved.angle) ~= "number" then
		saved.angle = Icon.ANGLE
	end
	return saved
end

-- "ROUND", or "SQUARE" when a minimap addon says so.
function Icon.Shape()
	local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or nil
	return shape == "SQUARE" and "SQUARE" or "ROUND"
end

-- Where on the minimap's edge an angle (degrees, 0 to the right, counted
-- anticlockwise) puts the button's centre, from the minimap's centre.
function Icon.Offset(angle)
	local radians = math.rad(angle)
	local x, y = math.cos(radians), math.sin(radians)
	local width = Minimap:GetWidth() / 2 + Icon.RADIUS
	local height = Minimap:GetHeight() / 2 + Icon.RADIUS
	if Icon.Shape() == "SQUARE" then
		-- On a square the ray goes to the corner's diagonal and stops at the edge.
		local diagonalX, diagonalY = math.sqrt(2 * width ^ 2) - 10, math.sqrt(2 * height ^ 2) - 10
		return math.max(-width, math.min(x * diagonalX, width)), math.max(-height, math.min(y * diagonalY, height))
	end
	return x * width, y * height
end

local function place()
	local x, y = Icon.Offset(Icon.Saved().angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- The angle from the minimap's centre to the cursor.
local function cursorAngle()
	local centerX, centerY = Minimap:GetCenter()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	return math.deg(math.atan2(y / scale - centerY, x / scale - centerX)) % 360
end

-- The menu, at the icon or (the compartment) at the cursor.
function Icon.ShowMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateButton(L["Options"], function()
			Bus:Send("OpenSettings")
		end)
		-- An entry whose feature is off asks to turn it on (TurnOn.lua).
		root:CreateButton(L["Loot Feed Look"], function()
			ns.TurnOn.WhenOn("LootFeed", function()
				ns.Modules:Get("LootFeed").LookWindow.Open()
			end)
		end)
		root:CreateButton(L["Junk"], function()
			ns.TurnOn.WhenOn("Junk", function()
				Bus:Send("OpenJunkWindow")
			end)
		end)
		-- The loot rolls' rules for ninja detection.
		root:CreateButton(L["Ninja Rules"], function()
			ns.Rolls.NinjaRules.OpenOrAsk()
		end)
		root:CreateButton(L["Bug Report"], function()
			ns.BugReportWindow.Open()
		end)
	end)
end

function Icon.ShowTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip_SetTitle(GameTooltip, ("Lootoman %s"):format(tostring(Compat.GetAddOnMetadata(addonName, "Version") or "")))
	GameTooltip_AddNormalLine(GameTooltip, L["Click: options"])
	GameTooltip_AddNormalLine(GameTooltip, L["Right-click: menu"])
	GameTooltip_AddNormalLine(GameTooltip, L["Drag: move"])
	GameTooltip:Show()
end

local function click(_, mouseButton)
	if mouseButton == "RightButton" then
		Icon.ShowMenu(button)
	else
		Bus:Send("OpenSettings")
	end
end

local function create()
	button = CreateFrame("Button", Icon.NAME, Minimap)
	button:SetSize(Icon.SIZE, Icon.SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(Icon.HIGHLIGHT)
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetTexture(Icon.BORDER)
	button.border:SetSize(50, 50)
	button.border:SetPoint("TOPLEFT", 0, 0)
	button.background = button:CreateTexture(nil, "BACKGROUND")
	button.background:SetTexture(Icon.BACKGROUND)
	button.background:SetSize(24, 24)
	button.background:SetPoint("CENTER", 0, 0)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(Icon.TEXTURE)
	button.icon:SetSize(18, 18)
	button.icon:SetPoint("CENTER", 0, 0)
	button:SetScript("OnClick", click)
	button:SetScript("OnEnter", Icon.ShowTooltip)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:LockHighlight()
		self:SetScript("OnUpdate", function()
			Icon.Saved().angle = cursorAngle()
			place()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)
end

-- Shows or hides the icon as the character's place says; showing and hiding
-- it are allowed in a fight.
function Icon.Update()
	if not button then
		return
	end
	place()
	button:SetShown(Icon.Saved().shown)
end

function Icon.SetShown(shown)
	Icon.Saved().shown = shown == true
	Icon.Update()
end

function Icon.Button()
	return button
end

-- The addon compartment: a click opens the options, a right click the menu
-- at the cursor; the tooltip is the icon's.
local function registerCompartment()
	if not (AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon) then
		return
	end
	AddonCompartmentFrame:RegisterAddon({
		text = "Lootoman",
		icon = Icon.TEXTURE,
		func = function(_, input)
			if input and input.buttonName == "RightButton" then
				Icon.ShowMenu(UIParent)
			else
				Bus:Send("OpenSettings")
			end
		end,
		funcOnEnter = function(owner)
			Icon.ShowTooltip(owner)
		end,
		funcOnLeave = function()
			GameTooltip:Hide()
		end,
	})
	Icon.compartment = true
end

-- At the top right of the options page, on the title's line: the label in the
-- small font and its checkbox right of it; only the two light on hover and
-- take the click.
ns.SettingsPanel.AddToMain(function(page)
	local check = CreateFrame("CheckButton", nil, page.frame, "SettingsCheckboxTemplate")
	check:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -ns.SettingsPanel.SCROLL_BAR, -16)
	local label = page.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("RIGHT", check, "LEFT", -2, 0)
	label:SetText(L["Show the Minimap Icon"])
	check.label = label
	check:SetTooltipFunc(function()
		Settings.InitTooltip(L["Show the Minimap Icon"], L["For this character."])
	end)
	check:SetScript("OnClick", function(self)
		Icon.SetShown(self:GetChecked() == true)
	end)
	page:OnRefresh(function()
		check:SetChecked(Icon.Saved().shown)
		-- The label lights and clicks with the box: measured once it is drawn.
		local width = label:GetStringWidth()
		check:SetHitRectInsets(-math.ceil(type(width) == "number" and width or 0) - 4, 0, 0, 0)
	end)
	page.minimap = check
end)

Bus:On("Ready", Icon, function()
	if Minimap and not button then
		create()
	end
	Icon.Update()
	registerCompartment()
end)
