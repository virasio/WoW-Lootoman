# Lootoman changelog

## 0.7

Loot rolls: roll in the Loot Rolls window, with advice on whether to need, and their options rearranged.

- **Hide the Game's Roll Frames** (off by default, under *Show the Loot Rolls Window*, and only together with it): each roll comes into the Loot Rolls window as it starts, on top, with need, greed, transmog where the game offers it, pass and a timer; once the game takes your choice, it goes under a line, the same row without its buttons. Closing the window while a roll waits asks first. Turning it off takes a reload.
- **Whether to need:** with Forever Leveling BiS (WoW Forever) or Pawn installed, the Loot Rolls window says whether an item is an upgrade for you. With neither, the options suggest one, with its address to copy: Forever Leveling BiS on WoW Forever, Pawn on retail.
- **The Loot Rolls window** has options for its background's opacity and for its border, and you can change its height from its bottom right corner; it keeps the height with its place.
- **The loot rolls' options, rearranged:** *Track Loot Rolls* turns the whole part on and off, the roll history with it, and has *Roll History* at the end of its row. *Show Who Rolled What* is now only the panels beside the game's roll frames, and moving those frames in Edit Mode sits in the same block. If you had turned *Show Who Rolled What* off, the loot rolls stay off.
- The options page has a divider between its blocks, and the suggestion to install QuestieDB stands in a frame.
- **Fixed:** the Loot Rolls window often opened empty when you were the last to choose; it now opens with that item, and every item rolled on after it joins it.

## 0.6.6

Selling junk does what you picked, and the Loot Rolls window takes less room.

- **Items you moved into the junk for one sale are sold** too, not only the ones marked as junk for good.
- At a merchant, the junk group is called **To Sell**.
- **A sale cut short says so:** if the merchant's window closes before the last stack is sold, a dialog (and a red chat line) tells you how many were left. Back at a merchant within a minute, they are in *To Sell* again, also an item that is not junk and was picked for that sale.
- **The Loot Rolls window** is half as wide, with everyone's choices under each item, opens at the left of the screen and **stays where you put it**, also in your next session.

## 0.6.5

Loot rolls: follow the rolls as they go, and look back on them.

- **The Loot Rolls window** on WoW Forever, where the game does not open one of its own: once you have chosen on a roll, a window shows it with the group's other rolls as they go, and keeps every item rolled on until you close it, each with who won it, with which button and roll, and everyone's choices. It opens again at your next choice; an option under *Show Who Rolled What* turns it off.
- **Roll History** (`/ltm rolls`, the *Roll History* button on the options page, or the minimap menu): your groups newest first; for each, its players with their needs, greeds, passes, wins and marks, and its drops in time order with the winner and everyone's choices. Click a player to see everything they did in your groups, or search for them by name. Filter by quality or to marked needs, and delete a group or the whole history.
- **Exceptions in the history:** a marked need in any of your groups can be excused with its checkbox, or marked again; the marks it caused later follow.
- `/ltm debug loot` and `/ltm debug demoroll` are gone: made-up loot and the loot rolls' demo were for testing the addon, and are no longer in the released version.

## 0.6

Loot rolls: see who chose what, and who is ninja looting.

- **A panel beside each of the game's loot roll frames** shows who chose what on that roll and what they rolled, in class colours, as it happens: in a group of five a line per player, with the game's icons, the leader and the winner; in a raid a few short lines with who leads, how many needed, greed and pass, and who has not chosen. The game's roll frames work as before.
- **Ninja detection**, off until you tick *Detect Ninja Looters*: a need on an armor type, a weapon type or primary stats the needer's class does not count as its own is marked, with the reason in its tooltip; for BoE items it says what the player did on the group's other BoE items; players who need nearly everything in the group are marked, and so is a player who did so the last time you were in a group with them. In a raid the marked players show as squares in class colours.
- **Ninja Rules** (`/ltm ninja`): for each class, which armor types (up to which level: on WoW Forever a warrior's mail counts up to 40), weapon types and primary stats are its own, and which checks run and how strictly.
- **Exceptions:** right-click a marked name to excuse a need the group agreed to; leaving a group, a window lists its marked needs.
- **The game's roll frames can be moved** in Edit Mode (*Loot Roll Frames*); *Edit* beside *Move the Loot Roll Frames in Edit Mode* opens Edit Mode with them picked.
- The minimap icon's menu has *Ninja Rules*. A menu entry or a command of a feature that is off asks to turn it on, with a button to the options.

## 0.5.10

Lootoman is easier to find, to reach and to report about.

- **A minimap icon** with Lootoman's own picture, which the game's AddOns list now shows too: a click opens the options, a right click a menu with the loot feed's look, the junk window and *Bug Report*. Drag it round the minimap's edge. A checkbox at the top right of the options page hides it, for each character. The game's addon compartment has the same entry.
- **One junk window** instead of three: *Throw Away Junk*, *Sell Junk* at a merchant, and *Junk List*, which a gear by the close button switches to and back. It opens to sell when you are at a merchant, and to throw away elsewhere.
- **Fewer commands:** `/ltm` opens the options, `/ltm feed` the loot feed's look, `/ltm junk` the junk window, `/ltm report` the bug report, and `/ltm help` lists them. `/lootoman design`, `toss`, `sales` and `selftest` are gone; the commands for testing and bug reports are under `/ltm debug help`.
- **Bug reports in a window:** the whole report, ready to copy, with the address to send it to, and an *Extended Log* switch. It names neither your character nor your realm.
- **No debug lines in the chat** any more: Lootoman keeps them, and its own errors always, for the report. The self-test in the chat says only what failed.
- **"Options"** in every English text, as the game says.
- The list of what was sold in a session is gone; the chat line after each sale stays.
- **Icons:** an amount or owned count wider than its icon, such as "1.23K" gold with its coin, gets smaller to fit instead of running into the next icon's number.

## 0.5.9

The loot feed reads better, does more with a click, and its settings are easier to reach.

- **The low-space warning stops crying wolf:** by default it warns only when your general bags run low (3 slots or fewer), since reagents go into the general bags when their own bag is full. Turn on a threshold for all bags or for the reagent bag if you like. Its number is a text you can write (`{general}+{reagent}` by default, every token explained under the field), its tooltip lists every kind of bag, and a click opens the window to throw away junk.
- **All junk in one row:** gray items and items you marked as junk gather in one "Junk" row that lists them in its tooltip. An item you can still use, such as a picked lockbox, stays on its own.
- **Quest items** carry the bags' gold quest border.
- **Clicks:** Shift-click an item row to link it in the chat; right-click a piece of gear you just looted to equip it.
- **Rows come in one after another** when you loot a lot at once, and leave the same way; the delay is a setting.
- **The background** has a switch of its own, takes the colour you pick, reaches half a row past the rows and fades out there (or ends sharply just past them, if you turn the fade off), and follows them smoothly. A look that showed a background keeps it.
- **The look window, rebuilt:** an *Edit* button beside the look on the options page; in Edit Mode, clicking the feed opens the window directly, and picking another frame closes it. While the window is open, the feed shows its sample rows where it stands, as in Edit Mode. At its top the look you edit, with *Apply* to use another one and *Reset Position*; its settings on four tabs: *Content*, *Appearance*, *Timings* and *Layout*.
- **More to set:** each text of a row can have a shadow or an outline, a row's background can have a border in a colour, width and opacity of your choice, the icons' quality border can be turned off, and the gap between rows is on *Appearance*. The look's *Size* is gone: the rows' and icons' own sizes do its job, and a look you made bigger or smaller stays as it was.
- **The look window's samples** stand in front of the feed's background, centred, on a dark or light backdrop; they can be drawn at 150 or 200 percent or widened over the whole window, and the window can be resized from its corner. A text over the icon is easy to pick.
- **WoW Forever:** the kept usable items no longer offer appearance sets and heirlooms, which it does not have.

## 0.5.8

Junk management suggests what else can go, and the junk windows are easier to use.

- **Suggestions:** items of quests you have done, leftovers from them, soulbound gear your class can't use, recipes and collectibles you already have, and food and potions you have outgrown, each in its own group with a *To Junk* button, and each a switch on the options page. A suggestion stays a suggestion until you send it to the junk. With [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) installed, quest suggestions know every quest an item is for.
- **A quest hint:** junk that a quest in your log still wants sits at the bottom of the junk, under a highlighted line.
- **Not junk is for any item now:** mark something you keep, and it is never suggested again. *Not Junk* is grouped by kind of item.
- **Quicker moves:** left-click a suggestion to junk it, right-click to keep it, or drag any item between the groups.
- **At merchants**, moves in the sort window are for this sale only; hold Shift to mark items for good.
- **The toss window** (*Throw Away Junk*) names the most valuable item left in the loot and checks the junk worth less. Quest items no quest needs any more can be thrown away there too.
- **A button by the bags** opens the toss window: small in the bag window's title, large above it, or large on its own, placed and sized in Edit Mode.
- **The junk list window** shows your bags and both lists in tabs. Add an item by dropping it there, Shift-clicking it or pasting its link or ID.
- **Share your junk list** as a text, alone or with a profile; import it merged with your list or in its place, and settle each item marked otherwise.
- **Fixed:** a corpse to skin no longer shows a nameplate addon's plate (Platynator's health bar and name) under its sparkles.

## 0.5.7

Gathering highlights on WoW Forever show what you are about to loot.

- **The icon and the name over a sparkling object:** the object's interaction icon and its name under it, over the stars, on by default. Choose the icon alone or nothing under *Above the Object*.
- **The name your way:** its size, colour and style, with an outline, a thick outline or a dark backdrop so it reads over any landscape; the icon and the name have their own opacity.
- **Intensity and colour** of the sparkles, right under the highlights' switch.
- **Corpses to skin sparkle:** a corpse you can skin now, so you see at once which corpses others have looted (on by default; *Only What You Can Gather* now covers Skinning too).
- **Quest objects sparkle from the start:** objects a quest asks you to collect sparkle before you pick up the first one, known by your quest log's objectives; once the quest is done, they stop.
- **Sliders and colour buttons** on the options page, as in the game's own options.

## 0.5.6

Clearer fast autoloot options.

- **A note under *Enable Fast Autoloot*** says that the loot window stays hidden and opens only for what can't be picked up.
- **The game's Auto Loot box** shows only while fast autoloot is on. It says in one line that fast autoloot works only together with the game's Auto Loot, and a grey line at the bottom says where the game keeps these settings.
- **Titles on the options page** are capitalized the way the game's own options are.
- **A checkbox's whole row** lights up and takes the click on the options page, its label, its note and the empty space included.

## 0.5.5

Safer settings, less work while you play, and easier bug reports.

- **Your settings stay safe** if a new version can't upgrade them: they are kept as they were, that session runs on default settings, and a chat message says so.
- **Less work while you play**: the loot feed rests while it only shows a warning or a kept item, the sell-junk button looks at your bags only at a merchant, and gathering highlights read an object's quest details once instead of five times a second.
- **Easier bug reports**: `/lootoman selftest` checks that the game offers everything the addon uses and keeps its report in your saved data, as do debug messages while they are on (the last 300); `/lootoman debug clear` empties both.

## 0.5.2

Fixes for gathering highlights on WoW Forever.

- **Sparkles with nameplate addons**: with an addon that draws its own nameplates, such as Platynator, nothing sparkled, because Lootoman took its nameplates for another addon already lighting the object. Lootoman no longer looks at other addons: objects sparkle whatever else is installed.
- **No herb leaf or pickaxe over what sparkles**: with the game's *Interact Key Icons* on, the game drew its icon over the herb or vein under the stars. Lootoman now turns those icons off only while something sparkles and gives your setting back with the next target, so NPCs keep theirs.

## 0.5.1

A fix for gathering highlights on WoW Forever.

- **Herbs and ore sparkle for every herbalist and miner**: some characters with Herbalism or Mining saw no sparkles on herbs or veins, because Lootoman could take them for characters without the profession, especially right after logging in. The profession is now read the way the game reports it, each time.

## 0.5

Gathering highlights on WoW Forever.

- **What you are about to loot sparkles**: a few small gold stars on the herb, ore vein, chest or quest object your Interact key would use, within about 15 yards. Bright in reach, quieter further away, faint on what you can't use yet. Each kind has its own switch under *Highlight lootable objects*.
- **Only herbs and ore you can gather** (on by default): herbs need Herbalism and ore Mining. Turn it off to see them anyway, say to help a friend who gathers.
- **Chests** are known by their look and name, and anything you loot once, a crate or a Windstone, sparkles from then on.
- **Your game settings stay yours**: the soft targeting Lootoman needs is borrowed while highlights are on and given back when you turn them off or log out. No pickaxe or name over objects that don't sparkle, and a spell cast without a target never lands on someone else.
- **The options page scrolls** when it is taller than the window, the profile staying on top.

## 0.4.5

One options page, feed looks you can share, and one window to sort your junk.

- **One options page**, with no subpages, in the order loot flows: your profile, fast autoloot, junk and the loot feed. If the game's own Auto Loot is off, a box there asks you to turn it on, right from Lootoman's page.
- **Feed looks**: every setting of the loot feed and the design of its rows now form a named look, shared by your profiles and chosen on the options page or in the feed's Edit Mode dialog. Edit a look in its own window, copy it, rename it, reset it, and share it as text. Your 0.4 settings and layouts became looks, keeping how your feed looked.
- **Backgrounds in any colour** for the rows, the amount and the owned count, each with its own opacity.
- **The low-space warning** now follows the look's design: a bag with a red border, and the free slots of each bag kind that is low ("3+2": general white, reagent green), its tooltip naming each.
- **Kept usable items**: one you can't use right now fades out instead of vanishing, and comes back if you can use it again; in a fight, its tooltip says when a right click waits for the end of the fight; marks also show on rows without an icon.
- **Junk**: one sort window at the loot window and at merchants. Its button by the loot window shows when your bags are full (or always, or never), large next to the window or small in its title. At merchants choose how junk is sold: automatically, with the sell button, or by picking it in the sort window. The junk list has a window of its own.

## 0.4

A compact loot feed, and usable items that wait for you. Lootoman is now only about loot.

- **Compact view**: the new Icons layout shows square icons only, filling up, down, left or right, with the amount and the owned count on each icon or beside it. Big numbers are short (1.23K, 12.34K, 1.23M), and money is a number with a coin.
- **Usable items stay**: an item this character can use right now stays in the feed until you click it: left to dismiss it, right to use it. That covers items that start a quest (on WoW Forever, fast autoloot no longer takes them unnoticed), recipes to learn, containers to open, and pets, mounts, toys, appearance sets and heirlooms not in your collection yet. Turn off *Keep usable items*, or any of its kinds, if you don't want it.
- **Owned count**: now part of each row layout, shown or hidden there, counting your bags and bank or only your bags. If you had it turned off, it stays hidden.
- **Tooltips** for money, experience and reputation show the full numbers.
- **Low-space warnings** work with icons too, and sit at the feed's edge.
- The feed shows at least 3 rows.
- **The currency bars and the free-slot bar are gone.** Your bar settings stay in your saved variables, untouched.

## 0.3.5

Stacks and banks on the currency bars.

- **Stacks**: put several currencies or items in one spot on a bar, most important first, such as upgrade crests. The bar shows the most important one you have, and hovering it lists them all. A stack at zero hides, unless you want it shown.
- **Bags, banks or both**: an item on a bar counts your bags, your banks or both, and the same item can stand on a bar once for each, so you can see what you carry next to what is stored. Its tooltip tells how many are in the bags, the bank and the warband bank.
- **Bar editor**: drop a row on another to make a stack; right-click a stack or an item for its options.
- **Free-slot bar**: it can sit right on your bags, and clicks go through to them; it can have a background with its opacity. On WoW Forever, new tokens for herb, enchanting and soul bags, quivers and ammo pouches, such as `{herb}` and `{quiver.total}`.
- **Fast autoloot on WoW Forever**: a herb bag in the reagent bag's slot gets only herbs, so other reagents no longer stay behind with "Inventory is full".

## 0.3

Bars of currencies and free slots.

- **Currency bars**: bars of currencies, of items in your bags and of your money (in coins), anywhere on the screen, as many as you want. Place them and set their width, background, border and the edge they fill from in Edit Mode; drag entries along a bar to reorder them, off it to take them off, and drop items from your bags on it. What does not fit hides behind a double arrow. Capped currencies show their cap and turn red at it.
- **Bar editor** (`/lootoman bars`): pick what each bar shows from your currencies and money, by dragging between two lists or with buttons; drop items from your bags, or add them by ID. Bars come in named sets shared by your profiles, and sets can be shared as text.
- **Free-slot bar**: your bags' free slots in your own format and colours, such as `{free|33ff33} ({reagent|ffd100}) / {general}`, also in broker displays such as Titan Panel.
- **Low-space warnings** in the loot feed when few bag or reagent bag slots are left.
- Lootoman now also runs on WoW Forever and the 12.1.7 test realm.

## 0.2

Getting rid of junk.

- **Toss button and window**: a button on the loot window, shown when your bags are full (or always, or never), opens your bags with the junk on top and everything else below, cheapest first. Drag an item out of the window to delete it; anything above gray asks first. Also `/lootoman toss`.
- **Junk marks**: right-click an item, or drag it, to move it between the junk and everything else; a gray item taken out of the junk is kept from then on. The options list every mark, to remove some or all.
- **Selling junk**: Lootoman's sell-junk button takes the place of the game's. A click sells the junk, Shift-click opens a sell window to pick what to sell, and the junk can be sold as soon as a merchant opens. Each sale is summed up in chat; `/lootoman sales` lists the session.
- **Auctionator prices**: with Auctionator installed, the toss window weighs items by their auction price too.

## 0.1-alpha

The first release. It is an alpha: features and options may still change.

- **Fast autoloot**: with the game's Auto Loot on, Lootoman picks up everything at once and keeps the loot window hidden. It checks bag space for the whole loot first; what does not fit stays in the loot window, which then opens.
- **Loot feed**: items, currencies, money, reputation and, if you want, experience appear next to the centre of the screen and fade out. Place it with Edit Mode.
- **Row designer**: change how the feed's rows look, and keep the result as named row layouts that every profile can use.
- **Profiles**: each character can use its own profile; share a profile or your row layouts as text.
- English and Russian.
