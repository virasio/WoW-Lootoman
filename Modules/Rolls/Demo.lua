local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The demo: two look-alikes of the game's roll frame, drawn as the game draws
-- it (its loot toast art and border, the item's icon in its quality border,
-- the name in its quality colour, the need, greed and pass buttons, the
-- timer), stand where the game's frames would, each with its panel, and play
-- for about 15 seconds. A group roll: the player and four heroes of Azeroth
-- choose and roll one by one, the leader changes, and there is a winner. A
-- raid roll: twenty heroes. Each hero has the class his stories give him,
-- among the classes the client has. It needs no group and no real roll:
-- everything in it is made up. /ltm debug demoroll plays it, for testing and
-- pictures, not as a player's feature; Edit Mode shows its look-alikes still, where the moved
-- frames will stand. The look-alikes' buttons only mark the player's choice on the
-- look-alike: nothing goes to the game, and nothing into the history. The
-- items are the character's worn gear, which the game has loaded; with
-- nothing worn, a few items of the client's data. No demo while a real roll
-- is open, or in a fight (its frames are made out of combat).
ns.Rolls = ns.Rolls or {}
local Demo = {}
ns.Rolls.Demo = Demo

local Panel = ns.Rolls.Panel
local STATE = ns.Rules.Need.STATE

-- The demo's players: heroes of Azeroth, each with the class of his stories.
Demo.HEROES = {
	{ L["Thrall"], "SHAMAN" }, { L["Jaina"], "MAGE" }, { L["Varian"], "WARRIOR" }, { L["Uther"], "PALADIN" },
	{ L["Sylvanas"], "HUNTER" }, { L["Tyrande"], "PRIEST" }, { L["Malfurion"], "DRUID" }, { L["Valeera"], "ROGUE" },
	{ L["Gul'dan"], "WARLOCK" }, { L["Rexxar"], "HUNTER" }, { L["Anduin"], "PRIEST" }, { L["Khadgar"], "MAGE" },
	{ L["Tirion"], "PALADIN" }, { L["Garrosh"], "WARRIOR" }, { L["Velen"], "PRIEST" }, { L["Alleria"], "HUNTER" },
	{ L["Muradin"], "WARRIOR" }, { L["Hamuul"], "DRUID" }, { L["Kel'Thuzad"], "WARLOCK" }, { L["Shaw"], "ROGUE" },
	{ L["Broll"], "DRUID" }, { L["Turalyon"], "PALADIN" }, { L["Drek'Thar"], "SHAMAN" }, { L["Antonidas"], "MAGE" },
	{ L["Garona"], "ROGUE" }, { L["Nobundo"], "SHAMAN" }, { L["Arthas"], "DEATHKNIGHT" }, { L["Darion"], "DEATHKNIGHT" },
	{ L["Chen"], "MONK" }, { L["Aysa"], "MONK" }, { L["Illidan"], "DEMONHUNTER" }, { L["Kayn"], "DEMONHUNTER" },
	{ L["Wrathion"], "EVOKER" }, { L["Ebyssian"], "EVOKER" },
}
Demo.LENGTH = 15
Demo.STEP = 1.5
Demo.RAID = 20
-- The game's roll frame (GroupLootFrameTemplate): its size, and the parts of
-- its loot toast texture for the background and the border around it.
Demo.WIDTH, Demo.HEIGHT = 277, 67
Demo.TEXTURE = [[Interface\LootFrame\LootToast]]
Demo.COORDS = { 0.28222656, 0.55273438, 0.30859375, 0.57031250 }
Demo.BORDER_COORDS = { 0.00097656, 0.28027344, 0.43750000, 0.73437500 }
Demo.BORDER_WIDTH, Demo.BORDER_HEIGHT = 286, 76
Demo.TIMER = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]]
-- The inventory slots whose gear the demo shows (no shirt, no tabard).
Demo.SLOTS = { 1, 5, 7, 3, 10, 8, 6, 9, 16, 17, 15, 2, 11, 13 }

local cards = {}
local generation = 0
local running = false

-- What the demo plays: its rolls' views, for tests and the marks.
Demo.cards = cards

-- The items of the demo: links of worn gear, else the data's.
function Demo.Items()
	local links, seen = {}, {}
	for _, slot in ipairs(Demo.SLOTS) do
		local link = Compat.GetEquippedLink(slot)
		local id = link and link:match("item:(%d+)")
		if id and not seen[id] then
			seen[id] = true
			links[#links + 1] = link
		end
	end
	if #links == 0 then
		for _, itemID in ipairs(ns.Data.rolls.demoItems) do
			local info = Compat.GetItemInfo(itemID)
			if info and info.link then
				links[#links + 1] = info.link
			else
				Compat.RequestItem(itemID)
			end
		end
	end
	return links
end

-- The heroes whose class the client has: { name, class, guid }.
function Demo.Heroes()
	local list = {}
	for index, hero in ipairs(Demo.HEROES) do
		if ns.Data.rolls.canEquip[hero[2]] then
			list[#list + 1] = { name = hero[1], class = hero[2], guid = "Demo-" .. index }
		end
	end
	return list
end

-- A choice's button, with the game's three atlases of it.
local function choiceButton(card, state, name)
	local button = CreateFrame("Button", nil, card.frame)
	button:SetSize(32, 32)
	button:SetNormalAtlas("lootroll-toast-icon-" .. name .. "-up")
	button:SetPushedAtlas("lootroll-toast-icon-" .. name .. "-down")
	button:SetHighlightAtlas("lootroll-toast-icon-" .. name .. "-highlight", "ADD")
	button:SetScript("OnClick", function()
		Demo.Choose(card, state)
	end)
	return button
end

-- A look-alike of the game's roll frame, laid out as its template is.
local function newCard()
	local card = {}
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(Demo.WIDTH, Demo.HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints(frame)
	frame.background:SetTexture(Demo.TEXTURE)
	frame.background:SetTexCoord(unpack(Demo.COORDS))
	frame.border = frame:CreateTexture(nil, "BORDER")
	frame.border:SetSize(Demo.BORDER_WIDTH, Demo.BORDER_HEIGHT)
	frame.border:SetPoint("CENTER")
	frame.border:SetTexture(Demo.TEXTURE)
	frame.border:SetTexCoord(unpack(Demo.BORDER_COORDS))
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
	frame.timer:SetStatusBarTexture(Demo.TIMER)
	frame.timer:SetStatusBarColor(1, 1, 0)
	frame.timer:SetMinMaxValues(0, Demo.LENGTH)
	card.frame = frame
	-- Need at the top right, pass right of it, greed under it, as in the game.
	local need = choiceButton(card, STATE.NEED, "need")
	need:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -6)
	local pass = choiceButton(card, STATE.PASS, "pass")
	pass:SetPoint("LEFT", need, "RIGHT", 6, 2)
	local greed = choiceButton(card, STATE.GREED, "greed")
	greed:SetPoint("TOP", need, "BOTTOM", 0, 5)
	card.buttons = { pass, greed, need }
	card.panel = Panel.New()
	card.panel.onRightClick = function(owner, player, view)
		ns.Rolls.SuspiciousNeeds.Menu(owner, player, view)
	end
	return card
end

-- Where the look-alikes stand: the moved roll frames' place, else the game's
-- container, else above the action bars.
function Demo.Place(card, slot)
	card.frame:ClearAllPoints()
	local anchor = ns.Rolls.Mover and ns.Rolls.Mover.Anchor()
	if not anchor then
		local container = Compat.GetGameRollContainer()
		if container and container.GetBottom and container:GetBottom() then
			anchor = container
		end
	end
	if anchor then
		card.frame:SetPoint("CENTER", anchor, "BOTTOM", 0, 100 * (slot - 0.5))
	else
		card.frame:SetPoint("CENTER", UIParent, "BOTTOM", 0, 250 + 100 * (slot - 1))
	end
end

-- The leader now: the highest need's roll, else the highest greed's.
local function leaderOf(players)
	local best
	for _, wanted in ipairs({ "need", "greed" }) do
		for _, player in ipairs(players) do
			local matches = (wanted == "need" and ns.Rules.Need.IsNeed(player.state)) or (wanted == "greed" and player.state == STATE.GREED)
			if matches and player.roll and (not best or player.roll > best.roll) then
				best = player
			end
		end
		if best then
			return best
		end
	end
	return nil
end

-- The view of a card, as the model would give it for a real roll.
local function viewOf(card)
	local view = card.view
	local leader = view.winner or leaderOf(view.players)
	for _, player in ipairs(view.players) do
		player.isLeader = not view.winner and player == leader
	end
	view.leader = leader
	return view
end

function Demo.Draw(card)
	local view = viewOf(card)
	if ns.Rolls.Marks then
		ns.Rolls.Marks.Add(view, card.context)
	end
	Panel.Show(card.panel, card.frame, view)
end

-- The player's choice on a look-alike: only the demo hears it.
function Demo.Choose(card, state)
	for _, player in ipairs(card.view.players) do
		if player.isSelf and player.state == STATE.NONE then
			player.state = state
			player.roll = state ~= STATE.PASS and 50 or nil
			Demo.Draw(card)
		end
	end
end

-- count players, from a turn of the clock so each demo differs; the player
-- himself first in the group roll.
local function newPlayers(count, turn, withSelf)
	local players, heroes = {}, Demo.Heroes()
	if withSelf then
		local own = Compat.GetUnitName("player") or (Compat.GetCharacterKey() or "?"):match("^[^%-]+")
		players[1] = { name = own, class = Compat.GetPlayerClass(), guid = Compat.GetPlayerGUID(),
			level = Compat.GetPlayerLevel(), isSelf = true, state = STATE.NONE }
	end
	for index = 1, math.min(#heroes, count - (withSelf and 1 or 0)) do
		local hero = heroes[((index + turn) % #heroes) + 1]
		players[#players + 1] = { name = hero.name, class = hero.class, guid = hero.guid, level = 30 + ((index * 7 + turn) % 30), state = STATE.NONE }
	end
	return players
end

-- Makes a player of the card another hero, of the class given, who is not on
-- the card yet; false when there is none.
local function becomeHero(card, player, class)
	local taken = {}
	for _, other in ipairs(card.view.players) do
		taken[other.guid] = true
	end
	for _, hero in ipairs(Demo.Heroes()) do
		if hero.class == class and not taken[hero.guid] then
			player.name, player.class, player.guid = hero.name, hero.class, hero.guid
			return true
		end
	end
	return false
end

-- What each made-up player does, step by step: { player, state, roll }.
local function script(players, steps)
	local moves = {}
	local states = { STATE.NEED, STATE.GREED, STATE.PASS, STATE.NEED, STATE.GREED, STATE.NEED }
	local index = 0
	for _, player in ipairs(players) do
		if not player.isSelf then
			index = index + 1
			local state = states[((index - 1) % #states) + 1]
			moves[#moves + 1] = { player = player, state = state, roll = state ~= STATE.PASS and ((index * 37) % 100) + 1 or nil,
				step = ((index - 1) % steps) + 1 }
		end
	end
	return moves
end

local function finish(card)
	local view = card.view
	local winner = leaderOf(view.players)
	if winner then
		winner.isWinner = true
		view.winner = winner
	else
		view.allPassed = true
	end
	Demo.Draw(card)
end

local function play(card, moves, steps, mine)
	for step = 1, steps do
		Compat.After(step * Demo.STEP, function()
			if generation ~= mine then
				return
			end
			for _, move in ipairs(moves) do
				if move.step == step then
					move.player.state, move.player.roll = move.state, move.roll
				end
			end
			card.frame.timer:SetValue(Demo.LENGTH - step * Demo.STEP)
			Demo.Draw(card)
		end)
	end
	Compat.After((steps + 1) * Demo.STEP, function()
		if generation == mine then
			finish(card)
		end
	end)
end

-- Excuses a need of the demo, or takes it back: only the demo hears it.
function Demo.SetExcused(view, guid, excused)
	for _, card in ipairs(cards) do
		if card.view == view then
			card.excused = card.excused or {}
			card.excused[guid] = excused or nil
			if card.context then
				card.context.excused = card.excused
			end
			Demo.Draw(card)
		end
	end
end

-- The demo's marked needs, as the Suspicious Needs window lists them.
function Demo.Rows()
	local rows = {}
	for _, card in ipairs(cards) do
		local view = card.view
		for _, player in ipairs(view and view.players or {}) do
			if player.mark then
				rows[#rows + 1] = {
					name = player.name,
					class = player.class,
					link = view.link,
					reasons = player.notes or { L["Excused"] },
					excused = player.excused == true,
					set = function(excused)
						Demo.SetExcused(view, player.guid, excused)
					end,
				}
			end
		end
	end
	return rows
end

-- The made-up group leaves: its marked needs show as after a real group.
function Demo.Leave()
	if ns.Storage:Get("Rolls", "ninja") and ns.Storage:Get("Rolls", "summary") and #Demo.Rows() > 0 then
		ns.Rolls.SuspiciousNeeds.Open(Demo.Rows)
	end
end

-- No history in the demo: its marks come from its own made-up past.
local NO_HISTORY = {
	Open = function() return nil end,
	Choices = function() return {} end,
	LastShared = function() return nil end,
}

-- The demo's marks, for the detection when it is on. In the group roll the
-- first made-up player needs an item that does not fit his class (a warrior
-- past 40 on mail, when the item is mail) after greeding a BoE item that
-- fits; the fourth carries a mark from a made-up last group. In the raid
-- roll, three of those who need are marked as needing nearly everything.
function Demo.Context(card, group, otherLink)
	local context = { history = NO_HISTORY, reasons = {}, levels = {}, excused = card.excused or {} }
	card.excused = context.excused
	local facts = ns.Rolls.Marks.Facts(card.view.link)
	local made = {}
	for _, player in ipairs(card.view.players) do
		if not player.isSelf then
			made[#made + 1] = player
		end
	end
	if group then
		local first, fourth = made[1], made[4]
		if first and facts then
			if facts.classID == ns.Rules.Need.ARMOR and facts.subclassID == 3 then
				becomeHero(card, first, "WARRIOR")
				first.level = 45
			else
				local breaking = ns.Rolls.Marks.BreakingClass(facts, first.level)
				if breaking and breaking ~= first.class then
					becomeHero(card, first, breaking)
				end
			end
			if facts.bindType == ns.Rolls.Marks.BOE then
				context.reasons[first.guid] = { { kind = "greedFitting", link = otherLink } }
			end
		end
		if fourth then
			context.reasons[fourth.guid] = { { kind = "lastTime", needs = 6, total = 7, day = Compat.FormatDay(Compat.GetServerTime() - 86400),
				place = Compat.GetPlace() } }
		end
	else
		local marked = 0
		for index, player in ipairs(made) do
			if index % 3 == 1 and marked < 3 then
				marked = marked + 1
				context.reasons[player.guid] = { { kind = "everything", needs = 5, total = 6 } }
			end
		end
	end
	for _, player in ipairs(card.view.players) do
		context.levels[player.guid] = player.level
	end
	return context
end

-- Why the demo cannot start now, or nil.
function Demo.Blocked()
	if Compat.InCombat() then
		return L["The demo starts out of combat."]
	elseif #ns.Rolls.Model.Rolls() > 0 then
		return L["The demo waits until the rolls in progress are over."]
	end
	return nil
end

-- Starts the demo (again). Returns false, with why, when it cannot.
function Demo.Start(static)
	local blocked = Demo.Blocked()
	if blocked then
		ns.Print(blocked)
		return false, blocked
	end
	Demo.Stop()
	generation = generation + 1
	running = true
	local mine = generation
	local items = Demo.Items()
	local turn = math.floor(Compat.GetTime())
	for slot = 1, 2 do
		local card = cards[slot] or newCard()
		cards[slot] = card
		local link = items[((slot - 1) % math.max(1, #items)) + 1]
		local info = link and Compat.GetItemInfo(link)
		local kind = link and Compat.GetItemKind(link)
		-- The name in its quality's colour, the icon in its quality's border.
		local quality = info and info.quality or 2
		local color = ColorManager.GetColorDataForItemQuality(quality)
		card.frame.name:SetText(info and info.name or "?")
		if color then
			card.frame.name:SetTextColor(color.r, color.g, color.b)
		end
		card.frame.icon:SetTexture(kind and kind.icon or 134400)
		card.frame.iconBorder:SetAtlas(ColorManager.GetAtlasDataForLootBorderItemQuality(quality)
			or ColorManager.GetAtlasDataForLootBorderItemQuality(2))
		card.frame.timer:SetValue(Demo.LENGTH)
		local group = slot == 1
		local players = newPlayers(group and 5 or Demo.RAID, turn + slot, group)
		card.view = { rollID = "demo" .. slot, link = link, item = info, bound = true, demo = true, players = players }
		card.context = Demo.Context(card, group, items[(slot % math.max(1, #items)) + 1])
		Demo.Place(card, slot)
		card.frame:Show()
		if Demo.OnStart then
			Demo.OnStart(card, slot)
		end
		Demo.Draw(card)
		if not static then
			local steps = math.floor(Demo.LENGTH / Demo.STEP) - 2
			play(card, script(players, steps - 1), steps, mine)
		end
	end
	if not static then
		Compat.After(Demo.LENGTH + Demo.STEP, function()
			if generation == mine then
				Demo.Leave()
			end
		end)
		Compat.After(Demo.LENGTH + 2 * Demo.STEP, function()
			if generation == mine then
				Demo.Stop()
			end
		end)
	end
	return true
end

function Demo.Stop()
	generation = generation + 1
	running = false
	for _, card in ipairs(cards) do
		card.frame:Hide()
		Panel.Hide(card.panel)
	end
end

function Demo.IsRunning()
	return running
end
