# Manual tests

What the unit tests cannot cover: checks in the game, grouped by feature. Together they are the full regression. Before a release, run *Clients and start* and the checks of every feature the release adds or changes; a new feature adds its checks to its feature's section, or a new section.

**Setup for every round:** the branch under test checked out into `Interface/AddOns/Lootoman`; BugSack and BugGrabber on; the taint log on (`/console taintLog 1`, then `/reload`). After each section, open BugSack: no Lootoman errors. At the end, `/reload` or log out, so the SavedVariables, BugGrabber's errors and `Logs/taint.log` are written; the game overwrites the log at the next start. Turn the taint log off with `/console taintLog 0` when done.

## Clients and start

The PTR and WoW Forever load the same `sources/` through their own `Interface/AddOns/Lootoman` link.

- [ ] **Loads everywhere.** Start retail, the PTR and Forever in turn. *Expected:* Lootoman is in the AddOns list of each, not marked out of date, and loads without errors.
- [ ] **Self-test on retail.** `/lootoman selftest`. *Expected:* every check `OK` (`Encode` included); `Game Standard, family Mainline, project 1; data set: Mainline`; a `Bags:` line with every equipped bag (a profession bag shows its family); `Loot feed chat formats: 20 of 20`; every module `on`; `All checks passed.`, then `After: OK`.
- [ ] **Self-test on each client.** `/lootoman selftest`. *Expected:* the client's version and interface, one of the TOC's `## Interface` numbers; on retail and the PTR `Game Standard, family Mainline, project 1; data set: Mainline`. On Forever, note the game, family, project and data set it shows, and every check that is not `OK`: they decide the Forever data and capability fixes.
- [ ] **Commands.** `/ltm` opens the options; `/lootoman help` lists the commands; `/lootoman debug` shows the state, `on` and `off` change it.
- [ ] **Smoke test on the PTR and Forever.** Loot with fast autoloot, watch the feed, open the toss window, sell junk at a merchant.
- [ ] **Bars on the PTR and Forever.** On the PTR and WoW Forever: a stack, an item counting the banks. *Expected:* they work; without a warband bank, its tooltip line is not there.

## Options and profiles

- [ ] **Main page.** Options → AddOns → Lootoman. *Expected:* *Profile* above its dropdown with *Reset* beside it, a divider, then a switch for each feature: *Enable fast autoloot* with its bind-on-pickup option under it (greyed out while autoloot is off); *Enable loot feed*, *Enable the free-slot bar* and *Enable currency bars*, each with *Configure* under it (opens its page); *Enable junk tossing and selling* with *Sell junk at merchants* (greyed out while it is off) and *Configure*. Hovering a checkbox highlights only its row. The panel's *Defaults* button is hidden on Lootoman's pages and back on others.
- [ ] **Profile menu.** New profile, and for a profile: copy, rename, reset, delete. *Expected:* the character switches as each tooltip says; Default cannot be renamed or deleted.
- [ ] **Two characters.** Give two characters different profiles. *Expected:* each keeps its own after relog.
- [ ] **Share.** *Share* in the profile menu; untick some parts. *Expected:* the loot feed's position and layout are under *Loot feed*, the position only while *Loot feed* is ticked; the text changes with the ticks and can be copied.
- [ ] **Import into a new profile.** On another character, *Import*, paste, untick some parts. *Expected:* a new profile with the ticked parts only, and the character uses it.
- [ ] **Import into the current profile.** Tick *Put the parts into the current profile instead*. *Expected:* a confirmation, then only the ticked parts change.
- [ ] **Layout name taken.** Import a text with a layout whose name exists, once with each choice. *Expected:* keep both adds the layout under a free name and the imported profile uses it; replace overwrites yours; keep mine leaves yours, and the imported profile uses it.
- [ ] **Layouts alone.** Share and import layouts from the designer's layout menu.
- [ ] **Bad texts.** Import random text, a cut text and an empty field. *Expected:* a message, nothing imported.
- [ ] **Closing the options and Escape.** Open the row designer and the Share and Import windows, and close each with Escape; then close the options with the *Close* button, with the X and with Escape, after visiting Lootoman's pages, using *Configure*, the profile menu, the search box and the Keybindings page; then press Escape in the world, also while casting. *Expected:* each window closes on Escape, the game menu opens as usual, and there is no `ADDON_ACTION_FORBIDDEN` (`SpellStopCasting`); if it comes back, keep the taint log.

## Fast autoloot

The game's *Auto Loot* option on, Lootoman's fast autoloot on.

- [ ] **Mobs, chests, herbs, ore, fishing.** Loot each. *Expected:* the loot window never shows; everything is in the bags.
- [ ] **Game auto loot off.** Turn the game's *Auto Loot* off and loot. *Expected:* the normal loot window. Hold the auto loot key while looting: fast loot again. With *Auto Loot* on, the key gives the normal window.
- [ ] **Profession bag.** General bags full, a herb bag with free slots; loot herbs together with other items. *Expected:* the herbs go into the herb bag; the window opens with the other items only.
- [ ] **All bags full.** Loot something. *Expected:* the window opens with what is left; the feed shows only what was looted.
- [ ] **One free slot, two new items.** One free general slot; loot a corpse with two items that do not stack with anything you have, and money. *Expected:* the money and one item are looted, the other item stays in the window, and there is no "Inventory is full" error. The same with a stack of 18 of 20 herbs: looting 1–2 more needs no free slot, 3 or more do.
- [ ] **Profession bag first.** One free general slot and one free slot in a herb bag; loot herbs together with an item that is not a herb. *Expected:* both are looted, the herbs go into the herb bag, and there is no "Inventory is full" error. The same with crafting reagents and a free slot in the reagent bag.
- [ ] **Herb bag in the reagent slot.** On WoW Forever, a herb bag in the reagent bag's slot and the general bags full; loot herbs together with cloth or ore. *Expected:* the herbs go into that bag; the cloth or ore stays in the loot window, and there is no "Inventory is full" error.
- [ ] **Large pull.** Area loot of many corpses at once (a dungeon pull). *Expected:* no disconnect, nothing left behind that fits.
- [ ] **In combat.** Loot in combat in the open world and in a dungeon. *Expected:* no errors.
- [ ] **Bind on pickup.** Alone: a bind-on-pickup item is looted without asking. In a group: the window opens and asks. With *Confirm bind-on-pickup items when alone* off, alone: the game asks.

## Loot feed

- [ ] **Sources.** Pick up items, currencies, money and reputation; turn *Experience* on and gain experience. *Expected:* each shows a row with its icon, name and amount; money from a merchant, mail or trade does not.
- [ ] **Merging.** Loot the same item from several corpses quickly. *Expected:* one row with the total.
- [ ] **Feed turned on at a merchant.** Turn the loot feed off, talk to a merchant, turn the feed on in the options and sell an item. *Expected:* no money row; after the merchant closes, looted money shows again. The same at a mailbox, at a bank and in a trade with another player.
- [ ] **Options.** Change each: what the feed shows, minimum quality, rows, where new rows appear, time on screen, fade-out time, size, background opacity, owned count, glow for rare items. *Expected:* the feed changes at once, also after `/reload`. A full feed fades its oldest rows out.
- [ ] **Tooltips.** Point at an item row and at a currency row. *Expected:* their tooltips; the rows wait while the pointer is over them; clicks and the mouse wheel reach the game world.
- [ ] **Edit Mode.** Open Edit Mode. *Expected:* the loot feed is listed with sample rows, can be moved, and keeps its position per Edit Mode layout and across `/reload`. Its dialog shows the same option groups and a *Design rows* button; changes apply at once. Dragging a slider in the dialog moves smoothly from end to end.
- [ ] **Look.** The Default layout. *Expected:* a big icon with its quality border, the owned count on it, a glow on rare and better items, one shared background.

### Low-space warnings

- [ ] **General slots.** Default options. Fill the general bags down to 3 free slots: no warning; to 2: "Free bag slots: 2" at the feed's bottom edge (rows stacking up), the rows above it; to 0: "No free bag slots". *Expected:* the warning stays while it holds, also with no rows; it goes when slots are freed. With *New rows appear: At the bottom* it sits at the top edge.
- [ ] **Reagent bag.** Turn on *Warn when few reagent bag slots are free*; fill the reagent bag. *Expected:* its own warning, under its own threshold; without a reagent bag, none.
- [ ] **Thresholds.** Set each to 0 and to 5. *Expected:* the warnings follow at once.

## Row designer and layouts

- [ ] **Opening.** From the loot feed's options page, the Edit Mode dialog and `/lootoman design`. *Expected:* it opens; in combat it refuses with a message.
- [ ] **Editing.** Click each part (row, icon, name, amount, owned count) and the row background; drag parts; change every control by slider and by typing. *Expected:* the selected text shows its maximum width; parts stay inside the row; the feed follows at once and after `/reload`.
- [ ] **Layouts.** *+ New layout* from each template; copy, rename, reset to template, delete (the delete button appears on hover). *Expected:* Default cannot be renamed or deleted; a deleted layout's profiles switch to Default.
- [ ] **Shared by profiles.** Two profiles use the same layout; change it in one. *Expected:* the other shows the change.

## Junk

Some gray items and some items above gray in the bags; Auctionator installed for the checks that name it.

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* an `Auctionator:` line (`working` with it enabled, `not installed` without it), a `Junk:` line with the junk to sell and the marks, and `Last sale: none this session` before any sale.

### Toss button and window

- [ ] **Toss button, when the bags are full.** Default options. Loot with free general slots: no button. Fill the general bags (a free slot in a herb bag does not count) and loot: the button on the loot window's title bar, left of the close button, not over the title. With fast autoloot on, also when an item of the loot did not fit.
- [ ] **Toss button, always and never.** *Show the toss button: Always*, then *Never*. *Expected:* with every loot window, then with none.
- [ ] **Large button.** *Button style: Large*; change the size, each side and the offset. *Expected:* a square button with an empty-slot border outside the window, moving at once; it follows the loot window after moving the window in Edit Mode. In Edit Mode it shows where it will be and does nothing.
- [ ] **Toss window.** Click the button. *Expected:* the window to the right of the loot window (to its left near the right screen edge); junk on top, the rest below, each cheapest first, each stack's price under it and each section's total; each section scrolls on its own. It closes with the loot, with its X and with Escape. `/lootoman toss` opens it in the middle of the screen, also without loot and also while a loot window is open, and it then stays open when the loot closes.
- [ ] **Prices.** With and without Auctionator. *Expected:* without it, merchant prices; with it, an item with an auction price is weighed by it after the 5 % cut, and its tooltip shows *Auction price*; a soulbound item (an equipped, then removed bind-on-equip piece) is weighed by the merchant's price only.
- [ ] **Tooltips.** Point at items. *Expected:* the game's own tooltip for the bag item (with the comparison while Shift is held, or always with *Always compare items*), then what a right click and a drag do.
- [ ] **Deleting.** Drag a gray stack out of the window and let it go over the game world: it is gone, with a chat line, and no "Interface action failed because of an AddOn" message (deleting needs a mouse action; the end of a drag should count, as it does for Blizzard's own buttons; if it does not, tell Claude). Let one go over another window (the bags, the loot window): deleted as well. Drag a white or green item out: a question, *Cancel* keeps it, *Delete* deletes it. Drag a rare or epic item out: the question asks for the game's word (DELETE, or the client's own word) and *Delete* stays off until it is typed; Enter in the field deletes. Pick up an item from the bags and, holding it, drag another item out of the window: nothing is deleted, a chat line says why.
- [ ] **Never listed.** A quest item and an item of an equipment set. *Expected:* in neither window.

### Junk marks

- [ ] **Marking.** Right-click an item below: it moves up. Right-click it again: it moves down. Drag an item up, and back down: the same. Right-click or drag a gray item down: it stays below, also after `/reload`. Drag an item and let it go on the window's title or bottom: nothing changes. *Expected:* nothing goes onto the game's cursor during a drag.
- [ ] **Junk list.** Options → Lootoman → Junk → Junk list (and its button on the Junk page). *Expected:* the marked items under *Marked as junk* and the kept gray ones under *Not junk*, by name; *Remove* takes one away (it moves in the toss window at once); *Clear list* asks, then empties both. Another profile has its own list.

### Selling

- [ ] **Sell-junk button.** Open a merchant with *Sell junk at merchants* off. *Expected:* Lootoman's button in the place of the game's, with the same look, grey without junk; its tooltip lists the junk's count and value. A click sells the junk without a question, one stack at a time; Shift-click only opens the sell window and sells nothing. With *Swap click and Shift-click*, a click only opens the window (nothing is sold) and Shift-click sells the junk. With a guild repair button, both buttons move together; on the buyback tab it hides.
- [ ] **Selling on opening.** *Sell junk at merchants* on. *Expected:* the junk is sold as the window opens, with a chat line «Sold … items for …».
- [ ] **Ignore for junk selling.** Tick the game's *Ignore for junk selling* on a bag (its bag menu) with junk in it. *Expected:* that junk stays, by the button, on opening and with the sell window's *Sell junk* (it shows darker there).
- [ ] **Sell window.** *Expected:* to the right of the merchant's window, closing with it; refundable items and items without a sell price are not listed; *Sell junk* sells only the upper section and closes the window, and the sale goes on; a right click or a drag moves an item between the sections and sells nothing; an item dragged out of the window stays where it is; more than 12 stacks of junk show the buyback warning, and selling them warns in chat.
- [ ] **Stopping.** Close the merchant's window in the middle of a sale. *Expected:* selling stops with a chat line, and no item is used, equipped or opened afterwards. Sell an item you can still trade to your group: the game's question shows and selling stops.
- [ ] **Sales log.** `/lootoman sales`. *Expected:* every stack sold this session with its price and the total; the same after `/reload`; empty after logging out and in.

### The module

- [ ] **Turning the module off.** Untick *Enable junk tossing and selling*. *Expected:* no toss button, the game's own sell-junk button works again, nothing is sold at merchants; `/lootoman toss` says it is off.
- [ ] **Taint.** After the rounds above, `/reload` and look at `Logs/taint.log`. *Expected:* no lines blaming Lootoman for the loot window, the merchant frame or the game menu.

## Free-slot bar

- [ ] **Default.** *Expected:* left of the bag buttons, `free (reagent) / general` with free in green and reagent in gold; its tooltip lists all bags and each kind you have.
- [ ] **Text.** Options → Free slots → *Edit the text*: type `{general|ff0000} / {general.total}`, then a text with a typo `{genral}` and a plain `|`. *Expected:* the bar follows at once; the typo and the `|` show as typed.
- [ ] **Colour and size.** Change *Default colour* and *Text size*. *Expected:* the text between tokens and tokens without a colour take the new colour; the size follows.
- [ ] **Edit Mode.** Move the bar; change its text size in its dialog. *Expected:* it keeps its place per Edit Mode layout and after `/reload`.
- [ ] **On the bags.** In Edit Mode, put the bar on the bag buttons, then open the bags. *Expected:* its text shows above the bag buttons and the open bags; pointing at it shows its tooltip; a click on it opens or closes the bag under it, as if the bar were not there.
- [ ] **Broker.** With a broker display (Titan Panel, ElvUI's data texts or another): add "Lootoman: free slots". *Expected:* the same coloured text, the same tooltip, a click opens the bags; turning *Also in broker panels* off empties it (it goes after `/reload`). `/lootoman selftest` shows `Broker: working` with a display and `Broker: no broker display loaded` without one.

### Bag families

- [ ] **Bag families.** In a debug build (the addon linked from the repository), `/lootoman families`, then `/reload`. *Expected:* a line per kind of bag; "as expected" for each family the client knows; the lines are kept in the character's session data for Claude to read. Add the IDs of any profession bags you have that are not listed, after the command.
- [ ] **Family tokens.** Once the checked families are in the addon's data: put `{herb} / {herb.total}` (and others you have bags for) in the template. *Expected:* the free and total slots of those bags; the tooltip lists each family you have by its bag's kind ("Herb Bag").

## Currency bars

### On the bar

- [ ] **Default.** Mark two currencies *Show on backpack* in the currency tab. *Expected:* one bar near the bottom centre with them, an icon and a count each.
- [ ] **Caps.** A capped currency shows `quantity / cap` and turns red at its cap; a season-capped one (crests) shows its quantity, red once the season's cap is earned.
- [ ] **Money.** Add *Money* from the editor's right list. *Expected:* your money in gold, silver and copper coins, as in the bags, with no icon; it follows a purchase or a sale. Put an entry after it and try sizes 12 and 48: the next entry starts a gap after the copper coin, never on it.
- [ ] **Overflow.** Make a bar narrow. *Expected:* what does not fit hides behind `»`; its click lists the hidden entries with icons and counts.
- [ ] **Reorder on the bar.** Outside Edit Mode, drag an entry along the bar. *Expected:* the entry dims, a copy follows the mouse, a gold line shows where it will go; it moves there; nothing goes onto the cursor; the tooltip is the currency's or item's own.
- [ ] **Take off by dragging.** Drag an entry off the bar. *Expected:* the copy turns red; on release Lootoman asks; *Take off* removes it, *Cancel* keeps it. With the bar editor open, a bag item taken off waits in its right list until the window closes; with the editor closed, it is not kept.
- [ ] **Nothing changes while it asks.** Drag an entry off the bar and leave the question open. Try to drag another entry off, to reorder, to drop an item from the bags, to change the bar in the bar editor (also its set menu) and in Edit Mode (width, grip, moving the bar, *New bar*). *Expected:* none of it does anything (an item from the bags stays on the cursor); *Take off* then removes only the entry asked about; after the answer, everything works again.
- [ ] **Drop from the bags.** Outside Edit Mode, drag an item from the bags onto a bar, between two entries. *Expected:* it is added there and the item goes back to its bag slot.

### Edit Mode

- [ ] **Edit Mode.** Open Edit Mode. *Expected:* each bar is listed as "Currency bar N"; move it; set width, gap and size in its dialog and the width with the grip on its right edge; *New bar* adds one (an empty bar shows a hint), *Remove this bar* removes it, *Edit bars* opens the editor. Positions are kept per Edit Mode layout and after `/reload`.
- [ ] **Look.** In the bar's Edit Mode dialog turn on *Background* (try opacities) and *Border*. *Expected:* a dark background behind the bar; the bags' coin-box border around it, its ends not stretched at any width and size.
- [ ] **Dialog sliders.** In a bar's Edit Mode dialog, drag *Width*, *Gap* and *Size* slowly from one end to the other. *Expected:* each slider follows the mouse all the way; the bar changes as it moves.
- [ ] **Right to left.** *Fill from: The right edge*. *Expected:* entries start at the right edge; the overflow arrow `«` sits on the left; reordering, drops and the width grip (now on the left edge) work the same way.

### Bar editor

- [ ] **Editor.** `/lootoman bars`. *Expected:* on the left the bar's entries, on the right the other currencies by name. Move one across with each button, and by dragging it to the other list (the right list lights up when a row would leave the bar); drag a row up and down (it dims, a copy follows the mouse, a gold line shows where it goes; dropped outside both lists, nothing changes); drop an item from the bags on the left list; type an item ID and *Add item by ID*. Take an item off: it waits on the right while the window is open; close and reopen it: it is gone, only money and currencies are there. Each change shows on the bar at once.

### Stacks

- [ ] **Stack of crests.** In the editor, drop one crest on another, then the others between the stack's rows, most important first. *Expected:* the row you drop on lights up; inside a stack the line is indented; the stack shows its members under it. On the bar: the most important crest the character has; hovering lists every member with its count (the shown one in gold, a capped one in red).
- [ ] **Empty stack.** A stack of currencies the character has none of. *Expected:* it takes no room on the bar; right-click it in the editor, *Show when empty*: it shows its last (least important) member at 0.
- [ ] **Taking a stack apart.** Drag a member to the gap after the stack's last row, then one to the other list, then *Break up the stack*. *Expected:* the first becomes an entry after the stack; the second leaves the bar; a stack left with one member is that member again; breaking up puts the members in its place, in order. Money cannot join a stack.
- [ ] **Stacks kept.** `/reload`, and share the set as text and import it on another character. *Expected:* stacks, their order and *Show when empty* come along.

### Bags and banks

- [ ] **Bags and banks.** An item with some in the bags, the bank and the warband bank: add it, right-click it in the editor, *Count the banks*, then *Show it again* twice. *Expected:* three entries, "…, in the banks", "…, everywhere" and the plain one, with their counts (the banks in light blue, both in light green); hovering one lists bags, bank and warband bank. Right after login, before opening a bank, the bank counts are already right (if not, say so: the tooltip then needs a "not opened this session" line). Deposit and take out at the bank: the counts follow.

### Sets and sharing

- [ ] **Sets.** In the editor's set menu: new set, copy, rename, reset, delete; two profiles on two sets. *Expected:* each profile shows its set's bars; a deleted set's profiles go back to Default.
- [ ] **Share.** Share the profile with its bar set, and a set alone from the editor's menu; import both on another character. *Expected:* the bars, their entries and positions come along; a taken name offers keep both, replace or keep mine.

## Russian client

- [ ] **Strings.** Game language Russian. *Expected:* every option, menu, window and message in Russian.
- [ ] **Feed messages.** Loot items and gain reputation. *Expected:* rows like «Репутация Штормграда +250» («Фракция «…»» for a faction name the message does not decline); the self-test still shows `20 of 20`.
