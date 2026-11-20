local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The demo: two look-alikes of the game's roll frame, drawn with the game's
-- art and marked "Demo", stand where the game's frames would, each with its
-- panel, and play for about 15 seconds. A group roll: the player and four
-- made-up players of the client's classes choose and roll one by one, the
-- leader changes, and there is a winner. A raid roll: twenty made-up
-- players. The look-alikes' buttons only mark the player's choice on the
-- look-alike: nothing goes to the game, and nothing into the history. The
-- items are the character's worn gear, which the game has loaded; with
-- nothing worn, a few items of the client's data. No demo while a real roll
-- is open, or in a fight (its frames are made out of combat).
ns.Rolls = ns.Rolls or {}
local Demo = {}
ns.Rolls.Demo = Demo

local Panel = ns.Rolls.Panel
local STATE = ns.Rules.Need.STATE

-- Made-up names, Lootoman's own.
Demo.NAMES = {
	"Maelis", "Torvald", "Senna", "Hobart", "Ysolde", "Quill", "Brannoc", "Lirien", "Fenwick", "Odessa", "Garrick",
	"Thessaly", "Rowan", "Ingrid", "Pell", "Varga", "Edda", "Coll", "Mirela", "Durnan", "Sabeth", "Jory", "Kestrel", "Nym",
}
Demo.LENGTH = 15
Demo.STEP = 1.5
Demo.RAID = 20
Demo.WIDTH, Demo.HEIGHT = 277, 67
-- The game's roll frame's background: a part of its loot toast texture.
Demo.TEXTURE = [[Interface\LootFrame\LootToast]]
Demo.COORDS = { 0.28222656, 0.55273438, 0.30859375, 0.57031250 }
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

-- The client's classes, from a turn of the clock, so each demo differs.
local function classes(count, turn)
	local list, all = {}, ns.Data.rolls.classes
	for index = 1, count do
		list[index] = all[((index + turn) % #all) + 1][1]
	end
	return list
end

local function choiceButton(card, state, atlas, offset)
	local button = CreateFrame("Button", nil, card.frame)
	button:SetSize(32, 32)
	button:SetPoint("RIGHT", card.frame, "RIGHT", offset, 4)
	button:SetNormalAtlas(atlas)
	button:SetScript("OnClick", function()
		Demo.Choose(card, state)
	end)
	return button
end

-- A look-alike of the game's roll frame.
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
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(42, 42)
	frame.icon:SetPoint("LEFT", frame, "LEFT", 12, 2)
	frame.name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 8, 6)
	frame.name:SetWidth(110)
	frame.name:SetJustifyH("LEFT")
	frame.timer = CreateFrame("StatusBar", nil, frame)
	frame.timer:SetSize(180, 8)
	frame.timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 62, 12)
	frame.timer:SetStatusBarTexture([[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]])
	frame.timer:SetStatusBarColor(1, 0.82, 0)
	frame.timer:SetMinMaxValues(0, Demo.LENGTH)
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontRedLarge")
	frame.label:SetPoint("TOP", frame, "TOP", 0, 10)
	frame.label:SetText(L["Demo"])
	card.frame = frame
	card.buttons = {
		choiceButton(card, STATE.PASS, "lootroll-toast-icon-pass-up", -8),
		choiceButton(card, STATE.GREED, "lootroll-toast-icon-greed-up", -40),
		choiceButton(card, STATE.NEED, "lootroll-toast-icon-need-up", -72),
	}
	card.panel = Panel.New()
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

local function newPlayers(count, turn, withSelf)
	local players, names = {}, Demo.NAMES
	local kinds = classes(count, turn)
	if withSelf then
		local own = Compat.GetUnitName("player") or (Compat.GetCharacterKey() or "?"):match("^[^%-]+")
		players[1] = { name = own, class = Compat.GetPlayerClass(), guid = Compat.GetPlayerGUID(),
			level = Compat.GetPlayerLevel(), isSelf = true, state = STATE.NONE }
	end
	for index = 1, count - (withSelf and 1 or 0) do
		local name = names[((index + turn) % #names) + 1]
		players[#players + 1] = { name = name, class = kinds[index], guid = "Demo-" .. name, level = 30 + ((index * 7 + turn) % 30), state = STATE.NONE }
	end
	return players
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
		card.frame.name:SetText(info and info.name or "?")
		card.frame.icon:SetTexture(kind and kind.icon or 134400)
		card.frame.timer:SetValue(Demo.LENGTH)
		local group = slot == 1
		local players = newPlayers(group and 5 or Demo.RAID, turn + slot, group)
		card.view = { rollID = "demo" .. slot, link = link, item = info, bound = true, demo = true, players = players }
		card.context = nil
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
