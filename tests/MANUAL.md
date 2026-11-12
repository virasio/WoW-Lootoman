# Manual tests

What the unit tests cannot cover: checks in the game, grouped by feature. Together they are the full regression. Before a release, run *Clients and start* and the checks of every feature the release adds or changes; a new feature adds its checks to its feature's section, or a new section.

**Setup for every round:**
- The branch under test checked out into `Interface/AddOns/Lootoman`. After TOC changes (files added or removed), restart the client; `/reload` is enough otherwise.
- BugSack and BugGrabber on. After each section, open BugSack (`/bugsack`): no Lootoman errors and no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` for Lootoman.
- The taint log on: `/console taintLog 1`, then `/reload`.
- A character with some gray items and some items above gray in the bags, a few free general slots, and gold to buy a few cheap items. A reagent bag on retail; a herb bag on WoW Forever.
- At the end, `/reload` or log out, so the SavedVariables, BugGrabber's errors and `Logs/taint.log` are written; the game overwrites the log at the next start. Turn the taint log off with `/console taintLog 0` when done.

## Clients and start

The PTR and WoW Forever load the same addon folder through their own `Interface/AddOns/Lootoman` link.

- [ ] **Loads everywhere.** Start retail, the PTR and WoW Forever in turn. *Expected:* Lootoman is in the AddOns list of each, not marked out of date, and loads without errors.
- [ ] **Self-test on retail.** `/lootoman selftest`.
  - *Expected:* every check `OK` (`Encode` included).
  - `Client …, interface …` with one of the TOC's `## Interface` numbers.
  - `Saved data: schema 2`.
  - `Game Standard, family Mainline, project 1; data set: Mainline; locale: …`.
  - A `Bags:` line with every equipped bag (a profession bag shows its family, the reagent bag as `reagent 5`).
  - `Auctionator:` `working`, or `not installed`.
  - `Loot feed chat formats: 20 of 20`.
  - A `Junk:` line, and `Last sale: none this session`.
  - A `Module …: on` line for AutoLoot, LootFeed and Junk.
  - `All checks passed.`, then `After: OK`.
- [ ] **Self-test on WoW Forever.** `/lootoman selftest`. *Expected:* as on retail, but `Game Camelot` (or `Forever`, if the client renamed it), its own project number and `data set: Forever`; a herb bag in the reagent slot shows as `reagent 5 (…, family 32)`.
- [ ] **Commands.** `/ltm` opens the options; `/lootoman help` lists `/lootoman` or `/ltm`, `debug`, `selftest`, `design`, `toss` and `sales`; `/lootoman debug` shows the state, `on` and `off` change it. *Expected:* `/lootoman bars` and `/lootoman families` are unknown commands and show the list.
- [ ] **Smoke test on the PTR and WoW Forever.** Loot with fast autoloot, watch the feed, open the toss window, sell junk at a merchant.
- [ ] **Saved data with bars.** Log in with saved variables of 0.3 or 0.3.5 that have a bar set and the free-slot bar set up.
  - *Expected:* no errors; no bar frames in Edit Mode and no bar pages in the options.
  - After `/reload`, the saved variables still hold `barSets` and the bars' settings.
- [ ] **Saved data of 0.3.5's feed.** Saved variables of 0.3.5 with a feed of 1 or 2 rows, and with *Owned count* off on the loot feed's options page or the owned count's *Shown* off in the designer. *Expected:* the feed shows 3 rows; the owned count stays hidden, now with *Shown* unticked on the owned count of the layout that profile uses.

## Options and profiles

- [ ] **Main page.** Options → AddOns → Lootoman.
  - *Expected:* *Profile* above its dropdown with *Reset* beside it, a divider, then a switch for each feature:
    - *Enable fast autoloot*, with its bind-on-pickup option under it (greyed out while autoloot is off);
    - *Enable loot feed*, with *Configure* under it (opens its page);
    - *Enable junk tossing and selling*, with *Sell junk at merchants* (greyed out while it is off) and *Configure*.
  - Hovering a checkbox highlights only its row.
  - The panel's *Defaults* button is hidden on Lootoman's pages and back on others.
- [ ] **Profile menu.** New profile, and for a profile: copy, rename, reset, delete. *Expected:* the character switches as each tooltip says; Default cannot be renamed or deleted.
- [ ] **Two characters.** Give two characters different profiles. *Expected:* each keeps its own after relog.
- [ ] **Share.** *Share* in the profile menu; untick some parts.
  - *Expected:* the parts are *Fast autoloot settings*, *Loot feed settings* (with *Position* and *Use layout …* under it) and *Junk settings*, then the loot feed layouts.
  - The position and the layout are ticked only while *Loot feed settings* is.
  - The text changes with the ticks and can be copied.
- [ ] **Import into a new profile.** On another character, *Import*, paste, untick some parts. *Expected:* a new profile with the ticked parts only, and the character uses it.
- [ ] **Import into the current profile.** Tick *Put the parts into the current profile instead*. *Expected:* a confirmation, then only the ticked parts change.
- [ ] **Layout name taken.** Import a text with a layout whose name exists, once with each choice. *Expected:*
  - keep both adds the layout under a free name, and the imported profile uses it;
  - replace overwrites yours;
  - keep mine leaves yours, and the imported profile uses it.
- [ ] **A text of 0.3.5 with bars.** Import a profile text that 0.3.5 made with a bar set in it. *Expected:* it reads; its loot feed and junk parts come in; the bar parts are left out and counted.
- [ ] **Layouts alone.** Share and import layouts from the designer's layout menu.
- [ ] **Bad texts.** Import random text, a cut text and an empty field. *Expected:* a message, nothing imported.
- [ ] **Closing the options and Escape.**
  - Open the row designer and the Share and Import windows, and close each with Escape.
  - Close the options with the *Close* button, with the X and with Escape, after visiting Lootoman's pages, using *Configure*, the profile menu, the search box and the Keybindings page.
  - Press Escape in the world, also while casting.
  - *Expected:* each window closes on Escape, the game menu opens as usual, and there is no `ADDON_ACTION_FORBIDDEN` (`SpellStopCasting`); if it comes back, keep the taint log.

## Fast autoloot

The game's *Auto Loot* option on, Lootoman's fast autoloot on.

- [ ] **Mobs, chests, herbs, ore, fishing.** Loot each. *Expected:* the loot window never shows; everything is in the bags.
- [ ] **Game auto loot off.** Turn the game's *Auto Loot* off and loot. *Expected:*
  - the normal loot window;
  - holding the auto loot key while looting: fast loot again;
  - with *Auto Loot* on, the key gives the normal window.
- [ ] **Profession bag.** General bags full, a herb bag with free slots; loot herbs together with other items. *Expected:* the herbs go into the herb bag; the window opens with the other items only.
- [ ] **All bags full.** Loot something. *Expected:* the window opens with what is left; the feed shows only what was looted.
- [ ] **One free slot, two new items.** One free general slot; loot a corpse with two items that do not stack with anything you have, and money.
  - *Expected:* the money and one item are looted, the other item stays in the window, and there is no "Inventory is full" error.
  - The same with a stack of 18 of 20 herbs: looting 1–2 more needs no free slot, 3 or more do.
- [ ] **Profession bag first.** One free general slot and one free slot in a herb bag; loot herbs together with an item that is not a herb.
  - *Expected:* both are looted, the herbs go into the herb bag, and there is no "Inventory is full" error.
  - The same with crafting reagents and a free slot in the reagent bag.
- [ ] **Herb bag in the reagent slot.** On WoW Forever, a herb bag in the reagent bag's slot and the general bags full; loot herbs together with cloth or ore. *Expected:* the herbs go into that bag; the cloth or ore stays in the loot window, and there is no "Inventory is full" error.
- [ ] **Large pull.** Area loot of many corpses at once (a dungeon pull). *Expected:* no disconnect, nothing left behind that fits.
- [ ] **In combat.** Loot in combat in the open world and in a dungeon. *Expected:* no errors.
- [ ] **Bind on pickup.**
  - Alone: a bind-on-pickup item is looted without asking.
  - In a group: the window opens and asks.
  - With *Confirm bind-on-pickup items when alone* off, alone: the game asks.

## Loot feed

The Default layout and default options unless a check says otherwise.

- [ ] **Sources.** Pick up items, currencies, money and reputation; turn *Experience* on and gain experience. *Expected:* each shows a row with its icon, name and amount; money from a merchant, mail or trade does not.
- [ ] **Merging.** Loot the same item from several corpses quickly. *Expected:* one row with the total.
- [ ] **Feed turned on at a merchant.** Turn the loot feed off, talk to a merchant, turn the feed on in the options and sell an item.
  - *Expected:* no money row; after the merchant closes, looted money shows again.
  - The same at a mailbox, at a bank and in a trade with another player.
- [ ] **Options page.** Options → Lootoman → Loot feed.
  - *Expected:* the groups *What the feed shows* (with *Keep usable items* and its kinds indented under it), *Rows and timing*, *Appearance* and *Low-space warnings*, then *Row design* with *Open the designer*.
  - There is no *Owned count* option: it belongs to the layout.
- [ ] **Options.** Change each:
  - what the feed shows, minimum quality, rows (3 to 20), fill direction;
  - time on screen, fade-out time, size, background opacity, glow for rare items.

  *Expected:* the feed changes at once, also after `/reload`. A full feed fades its oldest rows out. With a rows layout, *Fill direction* offers only *Bottom to top* and *Top to bottom*.
- [ ] **Tooltips.** Point at an item row, a currency row, money, experience and reputation.
  - *Expected:* the game's tooltip for an item or a currency.
  - "Money" with the sum in coins; "Experience" with "+12,345"; "Reputation with …" with its signed amount.
  - The rows wait while the pointer is over them; clicks and the mouse wheel reach the game world.
- [ ] **Edit Mode.** Open Edit Mode.
  - *Expected:* the loot feed is listed with sample rows. The first place is a stuck quest item with the quest mark and "+1", and after it come an item, a rare item, money, a currency, reputation and experience, as many as the rows allow.
  - It can be moved, and keeps its position per Edit Mode layout and across `/reload`.
  - Its dialog shows the same option groups, with *Keep usable items* but without its kinds, and a *Design rows* button; changes apply at once.
  - Dragging a slider in the dialog moves smoothly from end to end.
- [ ] **Look.** The Default layout. *Expected:* a big icon with its quality border, the owned count on it, a glow on rare and better items, one shared background fading to the right.

### Row designer and layouts

- [ ] **Opening.** From the loot feed's options page, the Edit Mode dialog and `/lootoman design`. *Expected:* it opens; in combat it refuses with a message.
- [ ] **Samples.** *Expected:* sample rows of every kind, the experience row with a thousands amount, and the stuck quest item with the quest mark and "+1".
- [ ] **Parts.**
  - Choose each part (Row, Icon, Name, Amount, Owned count) by clicking it and from the part list, and click a row's free space and the space between rows.
  - *Expected:* the clicked part, or the row, is chosen; the gold frame marks it (a text shows the most room it may take).
- [ ] **Editing.** Drag parts; change every control by slider and by typing a number (also out of range); tick and untick *Shown*.
  - *Expected:* parts stay inside the row; the feed follows at once and after `/reload`.
  - The amount and the owned count each have *Background* and *Background opacity*.
  - The owned count also has *Counts*: *Bags and bank* or *Bags only*.
- [ ] **Owned count per layout.** Untick the owned count's *Shown* in one layout, and set *Counts* to *Bags only* with some of an item in the bank and some in the bags; loot that item. *Expected:* with *Bags only* the bank's are not counted; the other layouts keep their own; the option is nowhere else.
- [ ] **Layouts.**
  - *+ New layout* from each template (Large, Compact, Minimal, Icons): type a name and press *Done*. Then copy, rename, reset to template and delete (the delete button appears on hover).
  - *Expected:* each dialog closes after *Done*, *Reset* or *Delete*, with no BugSack error.
  - Default cannot be renamed or deleted; a deleted layout's profiles switch to Default.
- [ ] **Shared by profiles.** Two profiles use the same layout; change it in one. *Expected:* the other shows the change.

### Compact view

- [ ] **Icons.** In the designer, *+ New layout* → *Icons*.
  - *Expected:* square icons, the amount at the bottom right, the owned count small at the top right.
  - The part list has *Icon* (its size and the gap), *Amount* and *Owned count*.
  - The samples stand side by side, wrapping at the preview's edge.
- [ ] **Four directions.** With the Icons layout, each *Fill direction*.
  - *Expected:* the oldest icon stays at the edge it fills from, new ones line up away from it.
  - Each view keeps its own direction: with *Right to left* on Icons and *Top to bottom* on a rows layout, switching to the rows layout and back brings back each one's own.
- [ ] **Amount.** Move the amount over the icon and beside it (it stops one icon's size away); change its text size; turn its background on with an opacity; untick its *Shown*. *Expected:* the feed follows; hidden, only the owned count shows.
- [ ] **Owned count.** The same for the owned count, and *Counts* set to *Bags only*. *Expected:* the feed follows; untick *Shown*, and only the amount shows.
- [ ] **Numbers.** Loot 78 copper, 1 silver 23 copper, 1 gold 2 silver 45 copper, a few hundred gold and over a thousand gold; gain experience in the thousands; loot a stack of 1,234 of an item if you can.
  - *Expected:* "78" with a copper coin, "1.23" with a silver coin, "1.02" with a gold coin, whole gold, "1.23K" with a gold coin.
  - Experience as "1.23K" or "12.34K", cut, not rounded, without a "+".
  - An item's count without "×".
  - A rows layout keeps "×3" and "+123".
- [ ] **Background.** With the Icons layout. *Expected:* one even background behind all the icons, not fading.

### Usable items

*Keep usable items* and all its kinds on (the default).

- [ ] **Quest starter on WoW Forever.** With fast autoloot, loot an item that starts a quest.
  - *Expected:* it stays at the start of the feed with the bags' quest mark; others fade in the places after it.
  - Its tooltip ends with "Left-click: dismiss. Right-click: use.".
  - A right click opens the quest's offer, and taking the quest lets the row go.
- [ ] **Quest starter on retail.** Loot an item that starts a quest. *Expected:* it stays, as above; taking the quest from the game's own offer lets the row go.
- [ ] **Kinds.** Loot each where you can:
  - a recipe you can learn and one you know;
  - a container you can open (a clam), and a locked box before and after picking it;
  - a new pet, mount, toy, appearance set and heirloom, and one of each you already have.

  *Expected:* the usable ones stay with a pin at the icon's top left; the known recipe, the collected ones and the locked box fade as usual. Note what a right click does on an heirloom: learn it, or equip it.
- [ ] **Several.** Two kept items at once. *Expected:* the second waits under the first, with a "+1" badge at the icon's bottom left; letting the first go shows the second.
- [ ] **Stacks.** Loot three clams. *Expected:*
  - right clicks open them one by one, the count going down;
  - a left click hides the row;
  - looting another clam brings it back.
- [ ] **Used from the bags.** Keep a recipe, then learn it from the bags (or sell it). *Expected:* its row goes by itself.
- [ ] **In a fight.** With a kept item showing, start a fight: right-click it, then left-click it, then loot another usable item.
  - *Expected:* no Lua errors and no blocked action.
  - The left click lets the row go.
  - A right click does nothing for the next row until the fight ends, then works.
- [ ] **Placing.** With a kept item showing, move the feed in Edit Mode, change its size and its fill direction. *Expected:* right clicks still hit the item where it is, after each change (out of combat).
- [ ] **Switches.** Turn off each kind, then *Keep usable items*, then *Items* with a kept item showing. *Expected:* those items fade as usual, and with *Items* off a kept item goes; the kinds sit under the switch on the options page, greyed out while it is off.
- [ ] **Below the minimum quality.** Set the minimum quality to Uncommon and loot a common usable item. *Expected:* it shows and stays.
- [ ] **WoW Forever's collections.** On WoW Forever, the options page's kinds. *Expected:* only the kinds whose collections the client has (note which).

### Low-space warnings

- [ ] **General slots.** Default options.
  - Fill the general bags down to 3 free slots: no warning.
  - Down to 2: "Free bag slots: 2" at the feed's bottom edge, the rows above it.
  - Down to 0: "No free bag slots".

  *Expected:* the warning stays while it holds, also with no rows, and goes when slots are freed. With *Fill direction: Top to bottom* it sits at the top edge.
- [ ] **Before a kept item.** A kept item while a warning holds, with rows and with icons filling up or down. *Expected:*
  - the warning at the edge, the kept item after it, then the fading rows;
  - when the warning goes, the kept item moves to the edge, and right clicks still hit it;
  - when a warning comes in a fight, the kept item stays where it is and the warning comes after it until the fight ends; then they swap.
- [ ] **Reagent bag.** Turn on *Warn when few reagent bag slots are free*; fill the reagent bag. *Expected:* its own warning, under its own threshold; without a reagent bag, none.
- [ ] **Thresholds.** Set each to 0 and to 5. *Expected:* the warnings follow at once.
- [ ] **With icons.** With the Icons layout. *Expected:*
  - filling up or down, a bag icon with the free slots in red, its text in the tooltip;
  - filling sideways, a line of text above the icons, a little apart from them, and the background behind both.

## Junk

Some gray items and some items above gray in the bags; Auctionator installed for the checks that name it.

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* an `Auctionator:` line (`working` with it enabled, `not installed` without it), a `Junk:` line with the junk to sell and the marks, and `Last sale: none this session` before any sale.

### Toss button and window

- [ ] **Toss button, when the bags are full.** Default options.
  - Loot with free general slots: no button.
  - Fill the general bags (a free slot in a herb bag does not count) and loot: the button on the loot window's title bar, left of the close button, not over the title.
  - With fast autoloot on, also when an item of the loot did not fit.
- [ ] **Toss button, always and never.** *Show the toss button: Always*, then *Never*. *Expected:* with every loot window, then with none.
- [ ] **Large button.** *Button style: Large*; change the size, each side and the offset.
  - *Expected:* a square button with an empty-slot border outside the window, moving at once.
  - It follows the loot window after moving the window in Edit Mode.
  - In Edit Mode it shows where it will be and does nothing.
- [ ] **Toss window.** Click the button.
  - *Expected:* the window to the right of the loot window (to its left near the right screen edge).
  - Junk on top, the rest below, each cheapest first, with each stack's price under it and each section's total; each section scrolls on its own.
  - It closes with the loot, with its X and with Escape.
  - `/lootoman toss` opens it in the middle of the screen, also without loot and also while a loot window is open; it then stays open when the loot closes.
- [ ] **Prices.** With and without Auctionator. *Expected:*
  - without it, merchant prices;
  - with it, an item with an auction price is weighed by it after the 5 % cut, and its tooltip shows *Auction price*;
  - a soulbound item (an equipped, then removed bind-on-equip piece) is weighed by the merchant's price only.
- [ ] **Tooltips.** Point at items. *Expected:* the game's own tooltip for the bag item (with the comparison while Shift is held, or always with *Always compare items*), then what a right click and a drag do.
- [ ] **Deleting.**
  - Drag a gray stack out of the window and let it go over the game world. *Expected:* it is gone, with a chat line, and no "Interface action failed because of an AddOn" message. Deleting needs a mouse action, and the end of a drag should count, as it does for Blizzard's own buttons; if it does not, tell Claude.
  - Let one go over another window (the bags, the loot window). *Expected:* deleted as well.
  - Drag a white or green item out. *Expected:* a question; *Cancel* keeps it, *Delete* deletes it.
  - Drag a rare or epic item out. *Expected:* the question asks for the game's word (DELETE, or the client's own word), and *Delete* stays off until it is typed; Enter in the field deletes.
  - Pick up an item from the bags and, holding it, drag another item out of the window. *Expected:* nothing is deleted, and a chat line says why.
- [ ] **Never listed.** A quest item and an item of an equipment set. *Expected:* in neither window.

### Junk marks

- [ ] **Marking.**
  - Right-click an item below: it moves up. Right-click it again: it moves down.
  - Drag an item up, and back down: the same.
  - Right-click or drag a gray item down: it stays below, also after `/reload`.
  - Drag an item and let it go on the window's title or bottom: nothing changes.

  *Expected:* nothing goes onto the game's cursor during a drag.
- [ ] **Junk list.** Options → Lootoman → Junk → Junk list (and its button on the Junk page). *Expected:*
  - the marked items under *Marked as junk* and the kept gray ones under *Not junk*, by name;
  - *Remove* takes one away (it moves in the toss window at once);
  - *Clear list* asks, then empties both;
  - another profile has its own list.

### Selling

- [ ] **Sell-junk button.** Open a merchant with *Sell junk at merchants* off.
  - *Expected:* Lootoman's button in the place of the game's, with the same look, grey without junk; its tooltip lists the junk's count and value.
  - A click sells the junk without a question, one stack at a time; Shift-click only opens the sell window and sells nothing.
  - With *Swap click and Shift-click*, a click only opens the window (nothing is sold) and Shift-click sells the junk.
  - With a guild repair button, both buttons move together; on the buyback tab it hides.
- [ ] **Selling on opening.** *Sell junk at merchants* on. *Expected:* the junk is sold as the window opens, with a chat line «Sold … items for …».
- [ ] **Ignore for junk selling.** Tick the game's *Ignore for junk selling* on a bag (its bag menu) with junk in it. *Expected:* that junk stays, by the button, on opening and with the sell window's *Sell junk* (it shows darker there).
- [ ] **Sell window.**
  - *Expected:* it opens to the right of the merchant's window and closes with it.
  - Refundable items and items without a sell price are not listed.
  - *Sell junk* sells only the upper section and closes the window, and the sale goes on.
  - A right click or a drag moves an item between the sections and sells nothing; an item dragged out of the window stays where it is.
  - More than 12 stacks of junk show the buyback warning, and selling them warns in chat.
- [ ] **Stopping.** Close the merchant's window in the middle of a sale. *Expected:* selling stops with a chat line, and no item is used, equipped or opened afterwards. Sell an item you can still trade to your group: the game's question shows and selling stops.
- [ ] **Sales log.** `/lootoman sales`. *Expected:* every stack sold this session with its price and the total; the same after `/reload`; empty after logging out and in.

### The module

- [ ] **Turning the module off.** Untick *Enable junk tossing and selling*. *Expected:* no toss button, the game's own sell-junk button works again, nothing is sold at merchants; `/lootoman toss` says it is off.

## Taint

- [ ] **Taint log.** After the rounds above, `/reload` and look at `Logs/taint.log`. *Expected:* no lines blaming Lootoman for the loot window, the merchant frame, the game menu or a protected action of the loot feed's use button.

## Russian client

- [ ] **Strings.** Game language Russian. *Expected:* every option, menu, window and message in Russian, the new ones too: *Не скрывать используемые предметы* and its kinds, *Только иконки*, *Направление заполнения*, *Считать*.
- [ ] **Feed messages.** Loot items and gain reputation. *Expected:* rows like «Репутация Штормграда +250» («Фракция «…»» for a faction name the message does not decline); the self-test still shows `20 of 20`.
- [ ] **Numbers.** With the Icons layout, loot money and gain experience in the thousands; point at the experience row. *Expected:* note the decimal point the client gives ("1.23" or "1,23"), the K and M, and the thousands separator in the tooltip.
