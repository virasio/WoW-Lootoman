# Manual tests

What the unit tests cannot cover: checks in the game, run before every release. Each release adds the checks for its features, so the whole list is the full regression (1.0). The heading of each section names the release that added it.

**Setup for every round:** the branch under test checked out into `Interface/AddOns/Lootoman`; BugSack and BugGrabber on; the taint log on (`/console taintLog 1`, then `/reload`). After each section, open BugSack: no Lootoman errors. At the end, `/reload` or log out, so the SavedVariables, BugGrabber's errors and `Logs/taint.log` are written; the game overwrites the log at the next start. Turn the taint log off with `/console taintLog 0` when done.

## Start (0.1)

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* every check `OK` (`Encode` included); `Game Standard, family Mainline; data set: Mainline`; a `Bags:` line with every equipped bag (a profession bag shows its family); `Loot feed chat formats: 20 of 20`; every module `on`; `All checks passed.`, then `After: OK`.
- [ ] **Commands.** `/ltm` opens the options; `/lootoman help` lists the commands; `/lootoman debug` shows the state, `on` and `off` change it.

## Fast autoloot (0.1)

The game's *Auto Loot* option on, Lootoman's fast autoloot on.

- [ ] **Mobs, chests, herbs, ore, fishing.** Loot each. *Expected:* the loot window never shows; everything is in the bags.
- [ ] **Game auto loot off.** Turn the game's *Auto Loot* off and loot. *Expected:* the normal loot window. Hold the auto loot key while looting: fast loot again. With *Auto Loot* on, the key gives the normal window.
- [ ] **Profession bag.** General bags full, a herb bag with free slots; loot herbs together with other items. *Expected:* the herbs go into the herb bag; the window opens with the other items only.
- [ ] **All bags full.** Loot something. *Expected:* the window opens with what is left; the feed shows only what was looted.
- [ ] **One free slot, two new items.** One free general slot; loot a corpse with two items that do not stack with anything you have, and money. *Expected:* the money and one item are looted, the other item stays in the window, and there is no "Inventory is full" error. The same with a stack of 18 of 20 herbs: looting 1–2 more needs no free slot, 3 or more do.
- [ ] **Profession bag first.** One free general slot and one free slot in a herb bag; loot herbs together with an item that is not a herb. *Expected:* both are looted, the herbs go into the herb bag, and there is no "Inventory is full" error. The same with crafting reagents and a free slot in the reagent bag.
- [ ] **Large pull.** Area loot of many corpses at once (a dungeon pull). *Expected:* no disconnect, nothing left behind that fits.
- [ ] **In combat.** Loot in combat in the open world and in a dungeon. *Expected:* no errors.
- [ ] **Bind on pickup.** Alone: a bind-on-pickup item is looted without asking. In a group: the window opens and asks. With *Confirm bind-on-pickup items when alone* off, alone: the game asks.

## Loot feed (0.1)

- [ ] **Sources.** Pick up items, currencies, money and reputation; turn *Experience* on and gain experience. *Expected:* each shows a row with its icon, name and amount; money from a merchant, mail or trade does not.
- [ ] **Merging.** Loot the same item from several corpses quickly. *Expected:* one row with the total.
- [ ] **Feed turned on at a merchant.** Turn the loot feed off, talk to a merchant, turn the feed on in the options and sell an item. *Expected:* no money row; after the merchant closes, looted money shows again. The same at a mailbox, at a bank and in a trade with another player.
- [ ] **Options.** Change each: what the feed shows, minimum quality, rows, where new rows appear, time on screen, fade-out time, size, background opacity, owned count, glow for rare items. *Expected:* the feed changes at once, also after `/reload`. A full feed fades its oldest rows out.
- [ ] **Tooltips.** Point at an item row and at a currency row. *Expected:* their tooltips; the rows wait while the pointer is over them; clicks and the mouse wheel reach the game world.
- [ ] **Edit Mode.** Open Edit Mode. *Expected:* the loot feed is listed with sample rows, can be moved, and keeps its position per Edit Mode layout and across `/reload`. Its dialog shows the same option groups and a *Design rows* button; changes apply at once. Dragging a slider in the dialog moves smoothly from end to end.
- [ ] **Look.** The Default layout. *Expected:* a big icon with its quality border, the owned count on it, a glow on rare and better items, one shared background.

## Row designer and layouts (0.1)

- [ ] **Opening.** From the loot feed's options page, the Edit Mode dialog and `/lootoman design`. *Expected:* it opens; in combat it refuses with a message.
- [ ] **Editing.** Click each part (row, icon, name, amount, owned count) and the row background; drag parts; change every control by slider and by typing. *Expected:* the selected text shows its maximum width; parts stay inside the row; the feed follows at once and after `/reload`.
- [ ] **Layouts.** *+ New layout* from each template; copy, rename, reset to template, delete (the delete button appears on hover). *Expected:* Default cannot be renamed or deleted; a deleted layout's profiles switch to Default.
- [ ] **Shared by profiles.** Two profiles use the same layout; change it in one. *Expected:* the other shows the change.

## Options and profiles (0.1)

- [ ] **Main page.** Options → AddOns → Lootoman. *Expected:* *Profile* above its dropdown with *Reset* beside it, a divider, *Enable fast autoloot* with its bind-on-pickup option under it (greyed out while autoloot is off), *Enable loot feed* with *Configure* under it (opens the loot feed page). Hovering a checkbox highlights only its row. The panel's *Defaults* button is hidden on Lootoman's pages and back on others.
- [ ] **Profile menu.** New profile, and for a profile: copy, rename, reset, delete. *Expected:* the character switches as each tooltip says; Default cannot be renamed or deleted.
- [ ] **Two characters.** Give two characters different profiles. *Expected:* each keeps its own after relog.
- [ ] **Share.** *Share* in the profile menu; untick some parts. *Expected:* the loot feed's position and layout are under *Loot feed*, the position only while *Loot feed* is ticked; the text changes with the ticks and can be copied.
- [ ] **Import into a new profile.** On another character, *Import*, paste, untick some parts. *Expected:* a new profile with the ticked parts only, and the character uses it.
- [ ] **Import into the current profile.** Tick *Put the parts into the current profile instead*. *Expected:* a confirmation, then only the ticked parts change.
- [ ] **Layout name taken.** Import a text with a layout whose name exists, once with each choice. *Expected:* keep both adds the layout under a free name and the imported profile uses it; replace overwrites yours; keep mine leaves yours, and the imported profile uses it.
- [ ] **Layouts alone.** Share and import layouts from the designer's layout menu.
- [ ] **Bad texts.** Import random text, a cut text and an empty field. *Expected:* a message, nothing imported.
- [ ] **Closing the options and Escape.** Open the row designer and the Share and Import windows, and close each with Escape; then close the options with the *Close* button, with the X and with Escape, after visiting Lootoman's pages, using *Configure*, the profile menu, the search box and the Keybindings page; then press Escape in the world, also while casting. *Expected:* each window closes on Escape, the game menu opens as usual, and there is no `ADDON_ACTION_FORBIDDEN` (`SpellStopCasting`); if it comes back, keep the taint log.

## Junk (0.2)

Some gray items and some items above gray in the bags; Auctionator installed for the checks that name it.

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* an `Auctionator:` line (`working` with it enabled, `not installed` without it), a `Junk:` line with the junk to sell and the marks, and `Last sale: none this session` before any sale.
- [ ] **Toss button, when the bags are full.** Default options. Loot with free general slots: no button. Fill the general bags (a free slot in a herb bag does not count) and loot: the button on the loot window's title bar, left of the close button, not over the title. With fast autoloot on, also when an item of the loot did not fit.
- [ ] **Toss button, always and never.** *Show the toss button: Always*, then *Never*. *Expected:* with every loot window, then with none.
- [ ] **Large button.** *Button style: Large*; change the size, each side and the offset. *Expected:* a square button with an empty-slot border outside the window, moving at once; it follows the loot window after moving the window in Edit Mode. In Edit Mode it shows where it will be and does nothing.
- [ ] **Toss window.** Click the button. *Expected:* the window to the right of the loot window (to its left near the right screen edge); junk on top, the rest below, each cheapest first, each stack's price under it and each section's total; each section scrolls on its own. It closes with the loot, with its X and with Escape. `/lootoman toss` opens it in the middle of the screen, also without loot and also while a loot window is open, and it then stays open when the loot closes.
- [ ] **Prices.** With and without Auctionator. *Expected:* without it, merchant prices; with it, an item with an auction price is weighed by it after the 5 % cut, and its tooltip shows *Auction price*; a soulbound item (an equipped, then removed bind-on-equip piece) is weighed by the merchant's price only.
- [ ] **Tooltips.** Point at items. *Expected:* the game's own tooltip for the bag item (with the comparison while Shift is held, or always with *Always compare items*), then what a right click and a drag do.
- [ ] **Marking.** Right-click an item below: it moves up. Right-click it again: it moves down. Drag an item up, and back down: the same. Right-click or drag a gray item down: it stays below, also after `/reload`. Drag an item and let it go on the window's title or bottom: nothing changes. *Expected:* nothing goes onto the game's cursor during a drag.
- [ ] **Deleting.** Drag a gray stack out of the window and let it go over the game world: it is gone, with a chat line, and no "Interface action failed because of an AddOn" message (deleting needs a mouse action; the end of a drag should count, as it does for Blizzard's own buttons; if it does not, tell Claude). Let one go over another window (the bags, the loot window): deleted as well. Drag a white or green item out: a question, *Cancel* keeps it, *Delete* deletes it. Drag a rare or epic item out: the question asks for the game's word (DELETE, or the client's own word) and *Delete* stays off until it is typed; Enter in the field deletes. Pick up an item from the bags and, holding it, drag another item out of the window: nothing is deleted, a chat line says why.
- [ ] **Never listed.** A quest item and an item of an equipment set. *Expected:* in neither window.
- [ ] **Junk list.** Options → Lootoman → Junk → Junk list (and its button on the Junk page). *Expected:* the marked items under *Marked as junk* and the kept gray ones under *Not junk*, by name; *Remove* takes one away (it moves in the toss window at once); *Clear list* asks, then empties both. Another profile has its own list.
- [ ] **Sell-junk button.** Open a merchant with *Sell junk at merchants* off. *Expected:* Lootoman's button in the place of the game's, with the same look, grey without junk; its tooltip lists the junk's count and value. A click sells the junk without a question, one stack at a time; Shift-click sells and opens the sell window. With *Swap click and Shift-click*, the other way round. With a guild repair button, both buttons move together; on the buyback tab it hides.
- [ ] **Selling on opening.** *Sell junk at merchants* on. *Expected:* the junk is sold as the window opens, with a chat line «Sold … items for …».
- [ ] **Ignore for junk selling.** Tick the game's *Ignore for junk selling* on a bag (its bag menu) with junk in it. *Expected:* that junk stays, by the button, on opening and with the sell window's *Sell junk* (it shows darker there).
- [ ] **Sell window.** *Expected:* to the right of the merchant's window, closing with it; refundable items and items without a sell price are not listed; *Sell junk* sells only the upper section; a right click or a drag moves an item between the sections and sells nothing; an item dragged out of the window stays where it is; more than 12 stacks of junk show the buyback warning, and selling them warns in chat.
- [ ] **Stopping.** Close the merchant's window in the middle of a sale. *Expected:* selling stops with a chat line, and no item is used, equipped or opened afterwards. Sell an item you can still trade to your group: the game's question shows and selling stops.
- [ ] **Sales log.** `/lootoman sales`. *Expected:* every stack sold this session with its price and the total; the same after `/reload`; empty after logging out and in.
- [ ] **Turning the module off.** Untick *Enable junk tossing and selling*. *Expected:* no toss button, the game's own sell-junk button works again, nothing is sold at merchants; `/lootoman toss` says it is off.
- [ ] **Taint.** After the rounds above, `/reload` and look at `Logs/taint.log`. *Expected:* no lines blaming Lootoman for the loot window, the merchant frame or the game menu.

## Russian client (0.1)

- [ ] **Strings.** Game language Russian. *Expected:* every option, menu, window and message in Russian.
- [ ] **Feed messages.** Loot items and gain reputation. *Expected:* rows like «Репутация Штормграда +250» («Фракция «…»» for a faction name the message does not decline); the self-test still shows `20 of 20`.
