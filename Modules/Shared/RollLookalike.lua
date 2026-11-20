local _, ns = ...
local Compat = ns.Compat

-- A look-alike of the game's roll frame, laid out as its template is
-- (GroupLootFrameTemplate): the loot toast's background and the border around
-- it, the item's icon in its quality's border, the name in its quality's
-- colour, need at the top right with pass beside it and greed under it, the
-- thin yellow timer at the bottom. The loot rolls' demo plays on two of them,
-- and Edit Mode shows two where the game's frames will stand once moved.
-- Where they stand: on the moved frames' place (Anchor, which the roll
-- frames' module keeps), else on the game's container, else above the
-- action bars, a slot of 100 pixels each, from the bottom.
local Lookalike = {}
ns.RollLookalike = Lookalike

Lookalike.WIDTH, Lookalike.HEIGHT = 277, 67
Lookalike.TEXTURE = [[Interface\LootFrame\LootToast]]
Lookalike.COORDS = { 0.28222656, 0.55273438, 0.30859375, 0.57031250 }
Lookalike.BORDER_COORDS = { 0.00097656, 0.28027344, 0.43750000, 0.73437500 }
Lookalike.BORDER_WIDTH, Lookalike.BORDER_HEIGHT = 286, 76
Lookalike.TIMER = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]]
Lookalike.SLOT = 100

-- The inventory slots whose gear stands in for an item the game does not give
-- (no shirt, no tabard).
Lookalike.SLOTS = { 1, 5, 7, 3, 10, 8, 6, 9, 16, 17, 15, 2, 11, 13 }

-- The links of worn gear, for an item the game does not give.
local function worn()
	local links, seen = {}, {}
	for _, slot in ipairs(Lookalike.SLOTS) do
		local link = Compat.GetEquippedLink(slot)
		local id = link and link:match("item:(%d+)")
		if id and not seen[id] then
			seen[id] = true
			links[#links + 1] = link
		end
	end
	return links
end

-- The demo's two items, the group's then the raid's: the data's when the game
-- has them, else worn gear; and whether one is still asked for.
function Lookalike.Items()
	local links, missing, spare = {}, false, worn()
	for slot, which in ipairs({ "group", "raid" }) do
		local itemID = ns.Data.rolls.demoItems[which]
		local info = itemID and Compat.GetItemInfo(itemID)
		if info and info.link then
			links[slot] = info.link
		else
			if itemID then
				Compat.RequestItem(itemID)
				missing = true
			end
			links[slot] = spare[slot] or spare[1]
		end
	end
	return links, missing
end

-- The frame the moved roll frames stand on, or nil while the game places them.
Lookalike.anchor = nil

function Lookalike.Anchor()
	return Lookalike.anchor
end

-- A choice's button, with the game's three atlases of it.
local function choiceButton(card, state, name)
	local button = CreateFrame("Button", nil, card.frame)
	button:SetSize(32, 32)
	button:SetNormalAtlas("lootroll-toast-icon-" .. name .. "-up")
	button:SetPushedAtlas("lootroll-toast-icon-" .. name .. "-down")
	button:SetHighlightAtlas("lootroll-toast-icon-" .. name .. "-highlight", "ADD")
	button:SetScript("OnClick", function()
		if card.onChoose then
			card.onChoose(card, state)
		end
	end)
	return button
end

-- A look-alike, hidden: { frame, buttons = { pass, greed, need }, onChoose =
-- fn(card, state) for its buttons }. Its frame is the player's, made out of combat.
function Lookalike.New()
	local STATE = ns.Rules.Need.STATE
	local card = {}
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(Lookalike.WIDTH, Lookalike.HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints(frame)
	frame.background:SetTexture(Lookalike.TEXTURE)
	frame.background:SetTexCoord(unpack(Lookalike.COORDS))
	frame.border = frame:CreateTexture(nil, "BORDER")
	frame.border:SetSize(Lookalike.BORDER_WIDTH, Lookalike.BORDER_HEIGHT)
	frame.border:SetPoint("CENTER")
	frame.border:SetTexture(Lookalike.TEXTURE)
	frame.border:SetTexCoord(unpack(Lookalike.BORDER_COORDS))
	frame.name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.name:SetSize(125, 30)
	frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -15)
	frame.name:SetJustifyH("LEFT")
	frame.name:SetJustifyV("MIDDLE")
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(34, 34)
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -13)
	frame.iconBorder = frame:CreateTexture(nil, "OVERLAY")
	frame.iconBorder:SetSize(42, 42)
	frame.iconBorder:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
	frame.timer = CreateFrame("StatusBar", nil, frame)
	frame.timer:SetSize(190, 8)
	frame.timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 2)
	frame.timer.background = frame.timer:CreateTexture(nil, "BACKGROUND")
	frame.timer.background:SetAllPoints(frame.timer)
	frame.timer.background:SetColorTexture(0, 0, 0, 1)
	frame.timer:SetStatusBarTexture(Lookalike.TIMER)
	frame.timer:SetStatusBarColor(1, 1, 0)
	card.frame = frame
	-- Need at the top right, pass right of it, greed under it, as in the game.
	local need = choiceButton(card, STATE.NEED, "need")
	need:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -6)
	local pass = choiceButton(card, STATE.PASS, "pass")
	pass:SetPoint("LEFT", need, "RIGHT", 6, 2)
	local greed = choiceButton(card, STATE.GREED, "greed")
	greed:SetPoint("TOP", need, "BOTTOM", 0, 5)
	card.buttons = { pass, greed, need }
	return card
end

-- Shows an item on a look-alike: its name in its quality's colour, its icon
-- in its quality's border; the timer full.
function Lookalike.Fill(card, link, length)
	local info = link and Compat.GetItemInfo(link)
	local kind = link and Compat.GetItemKind(link)
	local quality = info and info.quality or 2
	local color = ColorManager.GetColorDataForItemQuality(quality)
	card.frame.name:SetText(info and info.name or "?")
	if color then
		card.frame.name:SetTextColor(color.r, color.g, color.b)
	end
	card.frame.icon:SetTexture(kind and kind.icon or 134400)
	card.frame.iconBorder:SetAtlas(ColorManager.GetAtlasDataForLootBorderItemQuality(quality)
		or ColorManager.GetAtlasDataForLootBorderItemQuality(2))
	card.frame.timer:SetMinMaxValues(0, length or 1)
	card.frame.timer:SetValue(length or 1)
	return info
end

-- Puts a look-alike on its slot (1 at the bottom), where the game's frame of
-- that slot would stand.
function Lookalike.Place(card, slot)
	card.frame:ClearAllPoints()
	local anchor = Lookalike.anchor
	if not anchor then
		local container = Compat.GetGameRollContainer()
		if container and container.GetBottom and container:GetBottom() then
			anchor = container
		end
	end
	if anchor then
		card.frame:SetPoint("CENTER", anchor, "BOTTOM", 0, Lookalike.SLOT * (slot - 0.5))
	else
		card.frame:SetPoint("CENTER", UIParent, "BOTTOM", 0, 250 + Lookalike.SLOT * (slot - 1))
	end
end
