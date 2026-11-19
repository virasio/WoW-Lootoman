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
  - `Saved data: schema 3`.
  - `Game Standard, family Mainline, project 1; data set: Mainline; locale: …`.
  - A `Bags:` line with every equipped bag (a profession bag shows its family, the reagent bag as `reagent 5`).
  - `Auctionator:` `working`, or `not installed`.
  - `Loot feed chat formats: 20 of 20`.
  - A `Junk:` line, and `Last sale: none this session`.
  - A `Module …: on` line for AutoLoot, LootFeed and Junk.
  - `Compat: … of … functions have what they need`, with no `missing:`; note what `not on this client:` lists.
  - `Edit Mode: LibEditMode …; dialog found, reset button found, hooked yes`.
  - `All checks passed.`, then `After: OK`.
- [ ] **Self-test on WoW Forever.** `/lootoman selftest`. *Expected:* as on retail, but `Game Camelot` (or `Forever`, if the client renamed it), its own project number and `data set: Forever`; a herb bag in the reagent slot shows as `reagent 5 (…, family 32)`.
- [ ] **Commands.** `/ltm` opens the options; `/lootoman help` lists `/lootoman` or `/ltm`, `debug`, `selftest`, `design`, `toss` and `sales`; `/lootoman debug` shows the state, `on` and `off` change it, `clear` says the saved messages are cleared. *Expected:* `/lootoman bars` and `/lootoman families` are unknown commands and show the list.
- A saved-data upgrade that fails can't be checked in game without breaking saved data on purpose; the unit tests cover it (the data is kept as it was, the session runs on defaults, a chat message says so).
- [ ] **Smoke test on the PTR and WoW Forever.** Loot with fast autoloot, watch the feed, open the sort window, sell junk at a merchant.
- [ ] **Saved data with bars.** Log in with saved variables of 0.3 or 0.3.5 that have a bar set and the free-slot bar set up.
  - *Expected:* no errors; no bar frames in Edit Mode and no bar pages in the options.
  - After `/reload`, the saved variables still hold `barSets` and the bars' settings.
- [ ] **Saved data of 0.3.5's feed.** Saved variables of 0.3.5 with a feed of 1 or 2 rows, and with *Owned count* off on the loot feed's options page or the owned count's *Shown* off in the designer. *Expected:* the feed shows 3 rows; the owned count stays hidden, now with *Shown* unticked on the owned count of the look that profile uses.
- [ ] **Saved data of 0.4.** Log in with saved variables of 0.4: two profiles on the same layout with the same feed settings, one on the same layout with other settings, a layout no profile uses, and junk set to sell on opening with click and Shift-click swapped.
  - *Expected:* no errors; each profile's feed looks and behaves as before (rows, direction, owned count, kept items, warnings).
  - The look menu lists a look named after each layout, "Layout (Profile)" for the profile whose settings differ, and the unused layout as a look of its own.
  - Junk sells on opening; the sort window's button keeps its old style (small, unless it was large); a profile that had junk turned off keeps it off.
  - A new character's profile uses the new defaults.

## Options and profiles

- [ ] **Main page.** Options → AddOns → Lootoman.
  - *Expected:* *Profile* with its dropdown on the same line (no *Reset* beside it), a divider, then:
    - *Enable Fast Autoloot*, a small white hint under it («When enabled, the loot window stays hidden…»), lined up with the switch's label, then its bind-on-pickup option (greyed out while autoloot is off);
    - *Enable Junk Management*, with *Edit the Junk List* right under it (and the QuestieDB note and button without QuestieDB), then *Loot Window Button*, *Style* under it (greyed out while the button is *Never*), *Bag Window Button*, *At Merchants* and the *Suggestions*, all greyed out while junk is off;
    - *Show the Loot Feed*, with *Feed Look* under it and *Edit* beside it (both greyed out while the feed is off);
    - on WoW Forever, *Highlight Lootable Objects* with *Quest Objects*, *Herbs*, *Chests*, *Ore* and *Only What You Can Gather*.
  - Every title on the page is capitalized as the game's own are (short words such as *when*, *at*, *the* lowercase); the dropdowns' choices, the tooltips and the Russian texts stay as they were.
  - Every dropdown but the profile's looks like the ones in Edit Mode dialogs, all of one size and lined up with the profile's; the profile's keeps the options panel's own style.
  - There are no subpages under Lootoman.
  - When the page is taller than the panel (WoW Forever with the Auto Loot box, or a small window), everything under the profile's divider scrolls, with the mouse wheel and the scroll bar, and the last checkbox can be reached; the title, the profile and its divider stay.
  - Hovering a checkbox's row lights the whole row: the checkbox, its label, its hint and the empty space up to the right edge, and nothing else. A click anywhere in that lit area toggles it; outside it, nothing. In the two columns of gathering highlights, each half lights and clicks on its own.
  - The panel's *Defaults* button is hidden on Lootoman's page and back on others.
- [ ] **Profile menu.** New profile, and for a profile: copy, rename, reset, delete. *Expected:* the character switches as each tooltip says; Default cannot be renamed or deleted.
- [ ] **Two characters.** Give two characters different profiles. *Expected:* each keeps its own after relog.
- [ ] **Share.** *Share* in the profile menu; untick some parts.
  - *Expected:* the parts are *Fast autoloot settings*, *Loot feed settings* (with *Position* and *Use look …* under it) and *Junk settings*, then the feed looks.
  - The position and the look are ticked only while *Loot feed settings* is.
  - The text changes with the ticks and can be copied.
- [ ] **Import into a new profile.** On another character, *Import*, paste, untick some parts. *Expected:* a new profile with the ticked parts only, and the character uses it.
- [ ] **Import into the current profile.** Tick *Put the parts into the current profile instead*. *Expected:* a confirmation, then only the ticked parts change.
- [ ] **Look name taken.** Import a text with a look whose name exists, once with each choice. *Expected:*
  - keep both adds the look under a free name, and the imported profile uses it;
  - replace overwrites yours;
  - keep mine leaves yours, and the imported profile uses it.
- [ ] **A text of 0.4.** Import a profile text that 0.4 made with its layout, feed settings and junk settings. *Expected:* it reads; its feed settings and layout come in as a look that the profile uses; junk sells as it did (on opening, or with the clicks swapped).
- [ ] **A text of 0.3.5 with bars.** Import a profile text that 0.3.5 made with a bar set in it. *Expected:* it reads; its loot feed and junk parts come in; the bar parts are left out and counted.
- [ ] **Looks alone.** Share and import looks from the look menu, and *Share* in a look's window (that look ticked).
- [ ] **Bad texts.** Import random text, a cut text and an empty field. *Expected:* a message, nothing imported.
- [ ] **Closing the options and Escape.**
  - Open a look's window, the junk list, and the Share and Import windows, and close each with Escape.
  - Close the options with the *Close* button, with the X and with Escape, after visiting Lootoman's page, using the profile menu, the look menu, the search box and the Keybindings page.
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
  - With *Confirm Bind-on-Pickup Items when Alone* off, alone: the game asks.

### The game's Auto Loot box (0.4.5, 0.5.6)

The box holds, top to bottom: a message; the game's *Auto Loot* checkbox and *Auto Loot Key* choice; a small grey line «These are standard game settings. You can find them in Options > Gameplay > Controls.».

- [ ] **Shown when Auto Loot is off.** Turn the game's *Auto Loot* off (Options → Gameplay → Controls), then open Lootoman's page with fast autoloot on.
  - *Expected:* under fast autoloot, the box with the red message «Auto Loot is off in the game. Fast Autoloot works only together with Auto Loot.», the checkbox unticked, *Auto Loot Key* with the key the game has, and the grey line at the bottom.
  - With *Auto Loot* on when the page opens, there is no box.
- [ ] **Changing the game's settings.** Tick *Auto Loot* in the box, then choose another key.
  - *Expected:* the box stays; the message turns white: «All set. Next time this box will be hidden.»; the key's label becomes *Loot Key*; the grey line stays; the game's Controls page shows the same values.
  - Untick it in the box: the red message and *Auto Loot Key* are back.
  - Tick it again, click another options page (*Controls*) and come back to Lootoman: the box is gone.
  - After closing and opening the options with Auto Loot on, the box is gone.
- [ ] **Shown whenever the page shows Auto Loot off.** `/reload`, open the options on the game's *Controls* page, untick *Auto Loot* there, then click Lootoman. *Expected:* the box is there at once, with the red message.
- [ ] **Only while fast autoloot is on.** Auto Loot off in the game.
  - Untick *Enable Fast Autoloot*. *Expected:* the box is hidden at once; closing and opening the options keeps it hidden.
  - Tick it again. *Expected:* the box is back.
  - Tick *Auto Loot* in the box, untick *Enable Fast Autoloot*, tick it again. *Expected:* no box (Auto Loot is on now).
  - Switch to a profile with fast autoloot off. *Expected:* no box; back to a profile with it on, the box is back while Auto Loot is off.
- [ ] **In combat.** Open the options in a fight and change the box's controls. *Expected:* nothing changes, a chat line says why; no errors.
- [ ] **Taint.** After setting the key, press Escape in the world and cast. *Expected:* no `ADDON_ACTION_FORBIDDEN` or `ADDON_ACTION_BLOCKED`; key bindings still save from the game's own page.
- [ ] **Where an addon may not change it.** If the client keeps *Auto Loot* from addons, the box shows the same message and the grey line, with *Open the Game's Setting* instead of the checkbox and the key, which opens the Controls page at Auto Loot; back with Auto Loot on, the box is gone. (Note whether this ever happens.)
- [ ] **Russian client.** *Expected:* «Включить быстрый автолут», the hint «При включении окно добычи остаётся скрытым…», the red message «Автоматический сбор добычи в игре выключен. Быстрый автолут работает только вместе с автоматическим сбором добычи.», the white «Всё настроено. В следующий раз эта рамка будет скрыта.», the grey line «Это стандартные настройки игры. Их можно найти здесь: …»; nothing cut or overlapping.

## Loot feed

The Default look and default options unless a check says otherwise.

- [ ] **Sources.** Pick up items, currencies, money and reputation; turn *Experience* on and gain experience. *Expected:* each shows a row with its icon, name and amount; money from a merchant, mail or trade does not.
- [ ] **Merging.** Loot the same item from several corpses quickly. *Expected:* one row with the total.
- [ ] **Feed turned on at a merchant.** Turn the loot feed off, talk to a merchant, turn the feed on in the options and sell an item.
  - *Expected:* no money row; after the merchant closes, looted money shows again.
  - The same at a mailbox, at a bank and in a trade with another player.
- [ ] **Settings.** On the look window's tabs, change each:
  - *Content*: what the feed shows, minimum quality, junk in one row;
  - *Appearance*: fill direction, number of rows (3 to 20), gap between rows (or icons), glow for rare items, the background with its colour, opacity and fade;
  - *Timings*: delay between rows, time on screen, fade-out time.

  *Expected:* the feed changes at once, also after `/reload`. A full feed fades its oldest rows out. With a look of rows, *Fill direction* offers only *Bottom to top* and *Top to bottom*.
- [ ] **Tooltips.** Point at an item row, a currency row, money, experience and reputation.
  - *Expected:* the game's tooltip for an item or a currency.
  - "Money" with the sum in coins; "Experience" with "+12,345"; "Reputation with …" with its signed amount.
  - The rows wait while the pointer is over them; clicks and the mouse wheel reach the game world, but on a row of gear in the bags and, while Shift is held, on any item row.
- [ ] **Edit Mode.** Open Edit Mode.
  - *Expected:* the loot feed is listed as *Loot Feed* with sample rows, drawn as the feed draws them: only the look's own background behind them, no dark box of Lootoman's (Edit Mode's own highlight marks the feed). The first place is a stuck quest item with the quest mark and "+1", and after it come an item, a rare item, money, a currency, reputation and experience, as many as the rows allow.
  - It can be moved, and keeps its position per Edit Mode layout and across `/reload`.
  - Clicking it opens the look's window, not a small dialog (0.5.9); it stays picked and can still be dragged. Dragging it opens nothing. With the window open on another look than the profile's, a click on the feed keeps that look. Other frames, Blizzard's and other addons', keep their dialogs. Leaving Edit Mode closes the window it opened; a window opened with *Edit* stays.
- [ ] **Looks from 0.5.8 (0.5.9).** Before updating, a look with *Size* 14 and one with a background (opacity 60 %). *Expected:* after the update both look as before: the first as big (its row height and texts larger in the *Layout* tab), the second with *Background* ticked at 60 %.
- [ ] **Look.** The Default look. *Expected:* a big icon with its quality border, a glow on rare and better items, no owned count, no background (*Background* is off until ticked).

### Feed looks and their window (0.4.5)

- [ ] **Look menu.** On the options page and in the look window's dropdown.
  - *+ New look*: type a name and press *Done*; the profile uses it. Then copy, rename, reset and delete (the delete button appears on hover).
  - *Expected:* each dialog closes after *Done*, *Reset* or *Delete*, with no BugSack error.
  - Default cannot be renamed or deleted; a deleted look's profiles switch to Default.
- [ ] **Shared by profiles.** Two profiles use the same look; change it in one. *Expected:* the other shows the change.
- [ ] **Opening the window.** *Edit* in a look's menu, *Edit* beside the feed look on the options page, the feed clicked in Edit Mode, and `/lootoman design`.
  - *Expected:* titled "Feed Look: …"; opened for the first time in a fight, it refuses with a message.
  - *Edit* on a look the profile does not use edits that look and leaves the feed alone; renaming it renames the title, deleting it closes the window.
- [ ] **Tabs (0.5.9).** *Expected:* on the left four tabs standing on a frame around their area, each as wide as its title, in English and in Russian; *Content* first: *What the Feed Shows*, *Kept Usable Items* (its kinds under the switch, greyed out while it is off; on WoW Forever without *Appearance Sets* and *Heirlooms*) and *Low-Space Warning*; *Appearance* (with *View* before *Fill direction*); *Timings*; and the designer's tab, *Layout*. Every heading, switch, label and button of the window in title capitals, the choices and tooltips in sentences. The samples on the right. Choosing another *View* asks first, then starts the look's design afresh; with *Icons*, *Number of Rows* and *Gap Between Rows* become *Number of Icons* and *Gap Between Icons*, and back with *Rows*.
- [ ] **Samples.** *Expected:* sample rows of every kind, the experience row with a thousands amount, and the stuck quest item with the quest mark and "+1", centred in their area, drawn exactly as in the feed, with no lighter box behind each row (the gold frame on *Layout* shows the chosen row's edges). With *Background* on, the feed's background behind them as in the feed (its colour, opacity and fade). *Light Backdrop* over them turns their backdrop light and back.
- [ ] **Resizing (0.5.9).** Drag the window's bottom right corner larger, then try to make it smaller than it started. Do it right after opening the window, after dragging a part of a sample, and after picking the background's colour.
  - *Expected:* the corner follows the pointer from where it was grabbed and never jumps; the samples' area fills all the room right of the tabs (the whole width when widened), with the same margins as before, and the samples stay centred in it; the tabs' area grows taller; the window never gets smaller than its first size. At 200 % with a taller window, all the samples fit.
  - Make the window as big as the screen, close it, raise the game's UI scale, and open it again. *Expected:* the window fits the screen, its corner on it, and cannot be dragged past the screen's edge.
- [ ] **Zoom (0.5.9).** Over the samples, choose 150 % and 200 % in the dropdown, then click the maximize button beside it, and click it again.
  - *Expected:* the samples are drawn larger, centred while they fit and from the top left corner when they do not, cut at the area's edge (icons never wrap to a second line); parts are chosen and dragged as before, and a drag moves a part as far on screen as the pointer goes.
  - The maximize button widens the samples over the whole window, the tabs and their panel hidden; clicking again brings them back.
  - Close and reopen the window: the zoom, the width, the window's size and the backdrop are as you left them; after `/reload`, back to 100 %, narrow and dark.
- [ ] **Text style (0.5.9).** On the *Layout* tab, for the name, the amount and the owned count, each *Text Style* after *Text Size*: *None*, *Shadow*, *Outline*, *Thick outline*.
  - *Expected:* only that text follows, in the feed and in the samples, at once and after `/reload` (the stuck row's waiting count follows the owned count's); *None* (the default) looks as before 0.5.9. *Appearance* has no *Text Style* and no *Size*.
- [ ] **Layout tab.** Choose each part (Row, Icon, Name, Amount, Owned count) by clicking it and from the *Part* list, and click a row's free space and the space between rows.
  - *Expected:* the *Layout* tab comes up; the clicked part, or the row, is chosen; a thin gold frame marks it (a text shows the most room it may take), and shows on this tab only. With a look of icons, click the amount on the icon: the amount is chosen, not the icon.
  - The first line sits clear of the tab's top edge: *Part* and, for a part but the row, *Shown* to its right with its checkbox first; a divider under it.
  - With *Shown* unticked, no other control shows.
- [ ] **Editing.** Drag parts; change every control by slider and by typing a number (also out of range); tick and untick *Shown*.
  - *Expected:* parts stay inside the row; the feed follows at once and after `/reload`.
  - The owned count also has *Counts*: *Bags and bank* or *Bags only*.
- [ ] **Backgrounds.** For the row, the amount and the owned count: tick *With Background*, click the colour swatch beside it, pick a colour, then *Cancel*; pick again and *OK*; change *Opacity* under it.
  - *Expected:* the swatch and *Opacity* are greyed out and do nothing until *With Background* is ticked; the default colour is black.
  - The feed follows each colour as it is picked; *Cancel* puts the old one back.
  - The row's background lies behind the whole row, under its icon and texts.
- [ ] **Row border (0.5.9).** A look of rows, the *Row* part: tick *With Border*, pick a colour with the swatch beside it, then move *Border Width* (1 to 4) and *Opacity* under it; also with *With Background* ticked.
  - *Expected:* the swatch, *Border Width* and *Opacity* are greyed out until *With Border* is ticked; the default is a white 1-pixel border at half opacity.
  - Four thin edges along the row's box, inside it, over its own background and under its icon and texts; the feed and the samples follow each change at once, and after `/reload`.
  - A look of icons has no border controls.
- [ ] **Quality border (0.5.9).** With a rare item, a junk row and the low-space warning in the feed, untick *Quality Border* on the *Icon* part (a look of rows), then on the *Icon* of a look of icons, and tick it again.
  - *Expected:* ticked by default, in every look made before; unticked, the icons lose their borders, the item's quality colour, the junk row's gray and the warning's red one alike, and keep their glow; the warning's name stays red. The feed and the samples follow at once, and after `/reload`.
- [ ] **Owned count per look.** Tick the owned count's *Shown* in one look, and set *Counts* to *Bags only* with some of an item in the bank and some in the bags; loot that item. *Expected:* with *Bags only* the bank's are not counted; the other looks keep their own.
- [ ] **Top row (0.5.9).** *Expected:* the looks' dropdown at the top left with the look menu, the edited look chosen; no *Reset* or *Share* buttons (both are in the menu). Choose another look in it: the window edits it, the feed keeps the profile's look, and *Apply* appears beside the dropdown; *Apply* makes the profile use it and goes away. *Reset Position*, at the far right of the row, puts the feed back at its default place in the current Edit Mode layout.

### Compact view

- [ ] **Icons.** A new look, with *View: Icons* on its *Appearance* tab.
  - *Expected:* square icons, the amount at the bottom right, the owned count hidden (when shown, small at the top right).
  - The part list has *Icon* (its size), *Amount* and *Owned Count*; the gap is *Gap Between Icons* on *Appearance*.
  - The samples stand side by side in one line, centred, cut at the area's edge.
- [ ] **Four directions.** With a look of icons, each *Fill direction*.
  - *Expected:* the oldest icon stays at the edge it fills from, new ones line up away from it.
  - Switching the profile between a look of icons and a look of rows brings back each look's own direction.
- [ ] **Amount.** Move the amount over the icon and beside it (it stops one icon's size away); change its text size; turn its background on with an opacity; untick its *Shown*. *Expected:* the feed follows; hidden, only the owned count shows.
- [ ] **Owned count.** The same for the owned count, and *Counts* set to *Bags only*. *Expected:* the feed follows; untick *Shown*, and only the amount shows.
- [ ] **Numbers.** Loot 78 copper, 1 silver 23 copper, 1 gold 2 silver 45 copper, a few hundred gold and over a thousand gold; gain experience in the thousands; loot a stack of 1,234 of an item if you can.
  - *Expected:* "78" with a copper coin, "1.23" with a silver coin, "1.02" with a gold coin, whole gold, "1.23K" with a gold coin.
  - Experience as "1.23K" or "12.34K", cut, not rounded, without a "+".
  - An item's count without "×".
  - A look of rows keeps "×3" and "+123".
- [ ] **Background.** With a look of icons and *Background* on. *Expected:* one background behind all the icons, fading out past them on every side by a third of an icon.

### Usable items

*Keep Usable Items* and all its kinds on (the default).

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
- [ ] **Without an icon.** In a look, untick the icon's *Shown*; keep two usable items. *Expected:* the quest mark or the pin just before the row's left edge, and "+1" inside its right edge.
- [ ] **Several.** Two kept items at once. *Expected:* the second waits under the first, with a "+1" badge at the icon's bottom left; letting the first go shows the second.
- [ ] **Stacks.** Loot three clams. *Expected:*
  - right clicks open them one by one, the count going down;
  - a left click hides the row;
  - looting another clam brings it back.
- [ ] **Stacks with some in the bags already.** With ten clams in the bags, loot three. *Expected:* the row shows ×3, counts down as you open them, and goes after three are opened, with ten still in the bags.
- [ ] **Used from the bags.** Keep a recipe, then learn it from the bags. *Expected:* its row fades out like any row. Keep another one and sell it: its row goes at once.
- [ ] **In a fight.** With a kept item showing, start a fight: right-click it, then left-click it, then loot another usable item.
  - *Expected:* no Lua errors and no blocked action.
  - The left click lets the row go.
  - A right click does nothing for the next row until the fight ends, then works; meanwhile its tooltip ends with "Left-click: dismiss. Right-click: use, after the fight.".
- [ ] **Placing.** With a kept item showing, move the feed in Edit Mode, change its row height and its fill direction. *Expected:* right clicks still hit the item where it is, after each change (out of combat).
- [ ] **Switches.** Turn off each kind, then *Keep Usable Items*, then *Items* with a kept item showing. *Expected:* those items fade as usual, and with *Items* off a kept item goes; the kinds sit under the switch on the look window's *Content* tab, greyed out while it is off.
- [ ] **Below the minimum quality.** Set the minimum quality to Uncommon and loot a common usable item. *Expected:* it shows and stays.
- [ ] **WoW Forever's collections.** On WoW Forever, the kinds on the look window's *Content* tab. *Expected:* only the kinds whose collections the client has (note which).

### Low-space warning (0.5.9)

- [ ] **Defaults.** Default options, with a reagent bag.
  - Fill the reagent bag; keep 20 general slots free: no warning.
  - Fill the general bags down to 4 free slots: no warning. Down to 3: a warning row at the feed's bottom edge, the rows above it: the bag icon as big as the rows' icons, with a red border, "Few free bag slots" in red as its name, and "3+0" as its amount (the general slots white, the reagent ones green).
  - Its tooltip lists every kind of bag the character has, free of how many ("General bags: 3 of 16 free", "Reagent bag: 0 of 36 free", and the profession bags on WoW Forever).

  *Expected:* the warning stays while it holds, also with no rows, and goes when slots are freed. With *Fill direction: Top to bottom* it sits at the top edge.
- [ ] **Thresholds.** On the look window's *Content* tab, *Low-space warning*: turn on *Warn when few slots are free in all bags* and *Warn when few reagent slots are free*, turn off the general one, and set each number to 0 and to 5. *Expected:* the warning shows while any threshold that is on is reached, and follows at once; without a reagent bag the reagent threshold never warns.
- [ ] **Text.** Change *Warning text*: `{free} / {total}`, `{general|ff0000}`, and a typo such as `{genral}`. *Expected:* the warning's amount and its sample in the window follow when the field loses the focus or Enter is pressed; the typo shows as typed; a typed `|` shows as itself. Under the field, a grey note names every token in white and what it stands for, and how to add a colour; nothing is cut, in Russian too, and the settings under it are not covered.
- [ ] **Click.** With junk management on, point at the warning and click it. *Expected:* its tooltip ends with "Click: throw away junk."; a left click opens the toss window in the middle of the screen. With junk management off: no such line, and clicks reach the world.
- [ ] **Before a kept item.** A kept item while a warning holds, with rows and with icons filling up or down. *Expected:*
  - the warning at the edge, the kept item after it, then the fading rows;
  - when the warning goes, the kept item moves to the edge, and right clicks still hit it;
  - when a warning comes in a fight, the kept item stays where it is and the warning comes after it until the fight ends; then they swap.
- [ ] **Following the design.** Change the look's design (icon size and place, the name's and the amount's place and size, their backgrounds, the row's background), and check the warning sample in the look window. *Expected:* the warning row follows like any row.
- [ ] **With icons.** With a look of icons, filling up, down and sideways. *Expected:* the warning is a bag icon in the first place, like the other icons, with a red border and its text as its amount; no name.

### Junk, quest items, clicks, timing and the background (0.5.9)

- [ ] **Junk in one row.** Loot several gray items and an item you marked as junk. *Expected:* one row, "Junk" in gray with the sell-junk icon and the items' count ("×5"); its tooltip lists each item with its count. A gray item marked not junk, and an item the client has not loaded yet, get rows of their own. Untick *Junk in one row* on *Content*: each item has its own row again.
- [ ] **Usable junk.** Pick a lockbox (a junkbox, gray) and loot it if you can. *Expected:* it leaves the junk row and stays in the feed as a kept item.
- [ ] **Quest items.** On WoW Forever, loot a quest item (one a quest asks you to collect). *Expected:* the gold quest border on its icon, as in the bags; an item that starts a quest keeps its "!"; with the icon hidden in the design, no mark.
- [ ] **Shift-click.** Hold Shift and click an item row, with the chat's input box open and closed. *Expected:* the link goes into the chat, as from the bags. Ctrl-click opens the dressing room. Without Shift, clicks on rows that are not gear reach the world.
- [ ] **Right-click to equip.** Loot a piece of gear you can wear. *Expected:* its tooltip ends with "Right-click: equip."; a right click equips it, or swaps it with what you wear; a bind-on-equip piece asks first. In a fight, armour is refused by the game and a weapon swaps. Gear that has left the bags takes no clicks.
- [ ] **One after another.** Loot a corpse or a container with several items at once. *Expected:* the rows come in one after another, a short moment apart, and later leave one after another the same way. *Delay between rows* on *Timings* at 0: all at once; at 0.5: clearly apart. The pointer over the feed holds the rows still waiting.
- [ ] **Background.** On *Appearance*, tick *Background* (its *Color*, *Opacity* and *Fade at the Edges* greyed until then), pick a *Color* (and *Cancel* once), keep *Opacity* at 50 %. *Expected:* the background in that colour covers the rows and reaches past them on every side by half a row (or half an icon), fading out there over the whole margin, round at the corners; with *Fade at the Edges* off, a plain box with sharp edges only 4 pixels past the rows; no seams where its pieces meet, at a few UI scales; as rows come and go it grows and shrinks smoothly. The same with a look of icons.

### At rest (0.5.5)

The feed draws on every frame only while something moves, and a few times a second otherwise.

- [ ] **Looks as before.** Loot several things in a row, with rows and with icons. *Expected:* rows fade in, slide to their places and fade out as smoothly as before; a full feed pushes the oldest out; the pointer over the feed holds the rows, and they go on when it leaves (they may wait a moment longer to notice).
- [ ] **Kept item and warning.** With only a kept item, then only a low-space warning on screen for a minute. *Expected:* they stay put; a right click on the kept item uses it, out of combat and, where allowed, in a fight; a new loot row appears at once.
- [ ] **After a client or library update.** Open Edit Mode and select the loot feed. *Expected:* no small dialog shows, the look's window opens, and the feed can still be dragged; the self-test's `Edit Mode:` line says the dialog was found and hooked.

## Junk

Some gray items and some items above gray in the bags; Auctionator installed for the checks that name it; QuestieDB installed for the checks that name it, and not installed for the others.

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* an `Auctionator:` line and a `QuestieDB:` line (`working` with the addon enabled, `not installed` without it), a `Junk:` line with the junk to sell and the marks, and `Last sale: none this session` before any sale.

### The groups and the suggestions (0.5.8)

The same groups in all three junk windows.

- [ ] **Groups.** Open any junk window. *Expected:* top to bottom:
  - *Junk*: gray items and items marked as junk; at its bottom, under a highlighted *A quest in your log still wants these*, junk that a quest in your log still names (a gray quest item, say);
  - *Suggested as Junk*, a subgroup per rule, each with its total and a *To Junk* button;
  - *Not Junk*, a subgroup per kind of item in the client's own names (*Armor*, *Consumable*, *Trade Goods*, …; *Other* for the rest);
  - each cheapest first, with the stack's price under it; a subgroup with nothing is not shown; each section scrolls on its own.
- [ ] **Quest Done.** An item that starts a quest you have done; with QuestieDB a quest item whose quests are all done; without it a quest item no quest in your log names. *Expected:* under *Quest Done*, the tooltip saying why.
- [ ] **Leftovers from Quests.** With QuestieDB, an item for quests you have all done; without it, turn in a quest that asked for an item and keep one more of it. *Expected:* under *Leftovers from Quests*, unless the auction pays more than 1.5 times the merchant's price for it.
- [ ] **Your Class Can't Use It.** Soulbound gear your class cannot wear (plate on a mage). *Expected:* suggested; the same gear above your level is not.
- [ ] **Already Known.** A recipe you know, a mount, pet or toy you have. *Expected:* suggested; a tradeable one only when it is not worth the auction.
- [ ] **Outgrown.** Food, a potion or a bandage 20 levels or more below yours. *Expected:* suggested; one closer to your level is not.
- [ ] **Never suggested.** An item with a mark, in an equipment set, refundable, an appearance you have not collected, and an item a quest in your log still wants. *Expected:* none of them under *Suggested as Junk*.
- [ ] **Rules off.** Untick each rule under *Suggestions* on the options page with a window open. *Expected:* its subgroup goes at once, and comes back when ticked.

### The toss window and the loot window's button

- [ ] **Button, when the bags are full.** Default options (*Loot Window Button: When the bags are full*, *Style: Large, next to the window*).
  - Loot with free general slots: no button.
  - Fill the general bags (a free slot in a herb bag does not count) and loot: a square button with an empty-slot border, as big as the loot window's items, just right of the window's top right corner.
  - With fast autoloot on, also when an item of the loot did not fit.
- [ ] **Always and never.** *Loot Window Button: Always*, then *Never*. *Expected:* with every loot window, then with none; with *Never*, *Style* is greyed out.
- [ ] **Small button.** *Style: Small, in the window's title*. *Expected:* the button on the loot window's title bar, left of the close button, not over the title.
- [ ] **Following the loot window.** Move the loot window in Edit Mode. *Expected:* the button follows; in Edit Mode it shows where it will be and does nothing.
- [ ] **Toss window.** Click the button.
  - *Expected:* the window, titled *Throw Away Junk*, to the right of the loot window (to its left near the right screen edge), with the groups above.
  - *Junk List* in its title bar opens the junk list.
  - It closes with the loot, with its X and with Escape.
  - `/lootoman toss` opens it in the middle of the screen, also without loot and also while a loot window is open; it then stays open when the loot closes.
- [ ] **Cheaper than the loot (0.5.8).** Open it from the loot window with items left in the loot.
  - *Expected:* a line at its top, *In the loot: [item], worth …*, naming the most valuable item left, and a green check on every junk item worth less; their tooltips say so.
  - Take that item from the loot: the line names the next one, and the checks follow.
  - With only money or items without a price left, no line and no checks; opened from the bags or with `/lootoman toss`, neither.
- [ ] **Moves for good (0.5.8).** In the toss window:
  - left-click a suggestion: it goes to *Junk*; right-click one: it goes to *Not Junk*; each stays after `/reload` (a mark);
  - left-click a hinted junk item: it goes to *Not Junk*;
  - drag an item from *Junk* to *Not Junk* and back, and a suggestion to either: the same; clicks do not move items between *Junk* and *Not Junk*;
  - *To Junk* on a subgroup sends all of it to *Junk*;
  - let a dragged item go on the window's title or bottom: nothing changes; nothing goes onto the game's cursor during a drag.
- [ ] **Prices.** With and without Auctionator. *Expected:*
  - without it, merchant prices;
  - with it, an item with an auction price is weighed by it after the 5 % cut, and its tooltip shows *Auction price*;
  - a soulbound item (an equipped, then removed bind-on-equip piece) is weighed by the merchant's price only.
- [ ] **Tooltips.** Point at items. *Expected:* the game's own tooltip for the bag item (with the comparison while Shift is held, or always with *Always compare items*), then why it is suggested or hinted, and what its clicks and drags do.
- [ ] **Deleting.**
  - Drag a gray stack out of the window and let it go over the game world. *Expected:* it is gone, with a chat line, and no "Interface action failed because of an AddOn" message.
  - Let one go over another window (the bags, the loot window). *Expected:* deleted as well.
  - Drag a white or green item out. *Expected:* a question; *Cancel* keeps it, *Delete* deletes it.
  - Drag a rare or epic item out. *Expected:* the question asks for the game's word (DELETE, or the client's own word), and *Delete* stays off until it is typed; Enter in the field deletes.
  - Pick up an item from the bags and, holding it, drag another item out of the window. *Expected:* nothing is deleted, and a chat line says why.
  - Drag out a quest item no quest wants any more (0.5.8: quest items are listed). *Expected:* deleted after the question.
- [ ] **Never listed.** An item of an equipment set. *Expected:* in no junk window.

### The bag window's button (0.5.8)

- [ ] **Small, in the title (the default).** Open the bags, combined, then separate (the bag menu's *Combine bags* option). *Expected:* a small toss button on the bag window's title, left of its close button; with separate bags, on the backpack only. A click opens the toss window in the middle of the screen, with no loot line; a second click closes it.
- [ ] **Large, above the window.** *Bag Window Button: Large, above the window*. *Expected:* a large button with an empty-slot border above the bag window, over its close button; with separate bags, note whether it covers the bag above the backpack.
- [ ] **Large, on its own.** *Bag Window Button: Large, on its own*. *Expected:* a large button on the screen with the bags closed too. In Edit Mode it is *Throw Away Junk*: it can be moved, its *Size* slider resizes it, and it stays where it was put after `/reload`, per Edit Mode layout. In Edit Mode a click does nothing.
- [ ] **Never.** *Bag Window Button: Never*. *Expected:* no button by the bags and none on its own.
- [ ] **With a bag addon.** With an addon that replaces the game's bags (if one is at hand). *Expected:* no button in its window; *Large, on its own* and `/lootoman toss` still open the toss window.

### Selling and the sort window

- [ ] **Sell-junk button.** Open a merchant with *At Merchants: The sell button opens the sort window* (the default).
  - *Expected:* Lootoman's button in the place of the game's, with the same look, grey without junk; its tooltip lists the junk's count and value, and what a click and Shift-click do.
  - A click only opens the sort window and sells nothing; Shift-click sells the junk (gray and marked items only) without a question, one stack at a time.
  - With *Sell with the sell button*, a click sells the junk and Shift-click opens the window.
  - With a guild repair button, both buttons move together; on the buyback tab it hides.
- [ ] **Selling automatically.** *At Merchants: Sell automatically*. *Expected:* the junk (gray and marked items only) is sold as the window opens, with a chat line «Sold … items for …»; the button still opens the window with a click.
- [ ] **Ignore for junk selling.** Tick the game's *Ignore for junk selling* on a bag (its bag menu) with junk in it. *Expected:* that junk stays, by the button, on opening and with the sort window's *Sell Junk* (it shows darker there).
- [ ] **Sort window at a merchant.**
  - *Expected:* titled *Sort Junk*, it opens to the right of the merchant's window and closes with it; the groups show the merchant's prices.
  - Refundable items and items without a sell price are not listed.
  - *Sell Junk* sells only the *Junk* section and closes the window, and the sale goes on.
  - More than 12 stacks of junk show the buyback warning, and selling them warns in chat.
- [ ] **This sale only (0.5.8).** In the sort window, left-click a suggestion, right-click another, drag an item from *Not Junk* to *Junk*. *Expected:* each moves, sells with *Sell Junk* if it is in *Junk*, and leaves no mark: close the window and open it again, and they are back where the rules put them. The same moves with Shift held mark them for good, as in the toss window. The tooltip says which is which.
- [ ] **Stopping.** Close the merchant's window in the middle of a sale. *Expected:* selling stops with a chat line, and no item is used, equipped or opened afterwards. Sell an item you can still trade to your group: the game's question shows and selling stops.
- [ ] **Sell button away from merchants (0.5.5).** Loot and move items with no merchant open, then open a merchant with junk in the bags, and again with none. *Expected:* the button's icon is coloured with junk and grey without it from the moment the merchant opens; selling by the button, by the sort window and automatically on opening work as before.
- [ ] **Sales log.** `/lootoman sales`. *Expected:* every stack sold this session with its price and the total; the same after `/reload`; empty after logging out and in.

### The junk list window (0.5.8)

- [ ] **Opening.** *Edit the Junk List* on the options page, and *Junk List* in the toss and sort windows' title bars. *Expected:* a window titled *Junk List* with three tabs under it, *Bags* first. The first time after a reload, from the options it opens right of the options window, level with its top (over its right edge on a narrow screen or a large UI scale), from the other windows in the middle of the screen; after that it opens where it was left, moved or not; it closes with its X and with Escape; opened for the first time in a fight, it refuses with a chat line, and opens afterwards even in a fight. Turning junk management off closes it.
- [ ] **Bags.** *Expected:* the groups; every click and drag marks for good, as in the toss window, with no Shift; items dragged out are not deleted.
- [ ] **Junk and Not Junk.** *Expected:* every item with that mark, in the bags or not, by name, each with its icon, its tooltip on hover and *Remove*; *None* for an empty list. *Remove* takes one away (it moves in the open junk windows at once).
- [ ] **Adding.** On *Junk*, then on *Not Junk*:
  - drag an item from the bags onto the list: it joins the list and goes back to its slot;
  - click into the field, then Shift-click an item in the bags, a chat link or an item in the loot window: its link goes into the field; *Add* or Enter adds it;
  - paste a link, or type an item ID, and *Add*; a word that is neither says so in chat.
- [ ] **Clear List.** *Expected:* it asks, naming the profile, then empties both lists; another profile has its own lists.
- [ ] **Share.** *Share* at the bottom. *Expected:* the share window with only *Junk List* ticked, and a text to copy.
- [ ] **Import, merged.** On another character with other marks, *Import* and paste the text. *Expected:* only *Junk List*, with *Merge with my list* chosen; *Import* adds the new items without a question. An item marked otherwise here than in the text keeps its mark, and a window *Marked Otherwise* shows each such item, one by one (*1 of 3*), with its icon, its name, its tooltip beside the window, *Here: …* and *In the text: …*; *Keep mine* and *Take theirs* settle it and go to the next; after the last, it closes. Escape keeps the rest as they are.
- [ ] **Import, replaced.** Choose *Replace my list* and *Import*. *Expected:* a question naming the profile; accepted, the list is the text's.
- [ ] **In a profile text.** *Share* in the profile menu. *Expected:* *Junk List* under *Junk settings*. Importing a profile text: into a new profile, no choice on its row; with *Put the parts into the current profile instead*, the merge or replace choice on its row.

### Options (0.5.8)

- [ ] **Order.** *Expected:* under *Enable Junk Management*: *Edit the Junk List*, *Loot Window Button* with *Style*, *Bag Window Button*, *At Merchants*, then a heading *Suggestions* with the five rules two to a row: *Quest Done*, *Leftovers from Quests*, *Your Class Can't Use It*, *Already Known*, *Outgrown*; each rule's tooltip says what it finds.
- [ ] **Without QuestieDB.** *Expected:* a note under the switch, «Suggestions about quests are better with QuestieDB…», and *Copy the QuestieDB Address* right under it; the button opens a small window with the address selected, to copy with Ctrl+C (Cmd+C on a Mac); typing changes nothing; Escape and *Close* close it.
- [ ] **With QuestieDB.** *Expected:* neither the note nor the button.

### The switch

- [ ] **Turning junk off.** Untick *Enable Junk Management*. *Expected:* the settings under it are greyed out; no button at the loot window or by the bags; at a merchant the game's own sell-junk button works again and nothing is sold on opening; `/lootoman toss` says it is off. Tick it again: all is back.

## Gathering highlights (0.5)

On WoW Forever. Before the first check, note the game settings: `/dump C_CVar.GetCVar("SoftTargetInteract")`, and the same for `SoftTargetInteractRange`, `SoftTargetInteractArc`, `SoftTargetInteractOnlyInRange`, `SoftTargetIconGameObject`, `SoftTargetIconInteract`, `SoftTargetNameplateInteract` and `nameplateGameObjectMaxDistance`. Turn debug on (`/lootoman debug on`) to see each target's line.

- [ ] **Self-test.** `/lootoman selftest`. *Expected:* a `Highlights:` line with every function `yes` (note any `NO`), the settings with Lootoman's values, the cursors found (note how many) and your Herbalism and Mining. On retail there is no such line.
- [ ] **Each kind.** Walk up to a herb, an ore vein, a chest (and a crate or barrel you have looted before), and a quest object. *Expected:* each sparkles gold, in the same style, when it is the object the Interact key would use; at most one at a time.
- [ ] **The look.** *Expected:* only a few small gold stars twinkling around the object, on every kind; no glow, frame or ring.
- [ ] **States.** *Expected:* full sparkles in reach, quieter out of reach, faint on a locked chest or a node that needs more skill; no flicker at the edge of reach.
- [ ] **Where they sit.** *Expected:* on the object, a little below where its name would be; note tall and flat objects where they miss.
- [ ] **The switches.** Turn each kind off and on, without `/reload`. *Expected:* the kinds stand in two columns (quest objects and chests on the left, herbs and ore on the right), hovering one lights only its half, and *Only What You Can Gather* sits a little apart under them; each applies at once; with all off, nothing sparkles; *Only What You Can Gather* greys out while both herbs and ore are off.
- [ ] **Professions.** On a character without Herbalism or Mining. *Expected:* herbs and ore stay dark; with *Only What You Can Gather* off, they sparkle; with Herbs on and Ore off, only herbs.
- [ ] **Never sparkle.** NPCs, players, corpses, a mailbox and the fishing bobber. *Expected:* no sparkles, and no nameplate, bar, name or icon from Lootoman over them; the object under the sparkles shows no bar, name or icon either.
- [ ] **Interact icons.** With *Interact Key Icons* on in the game's options and *Above the Object: Nothing*. *Expected:* no herb leaf or pickaxe over a sparkling herb or vein; walk on to an NPC: its icon shows as before. Turn highlights off: `SoftTargetIconInteract` is back at `1`.
- [ ] **No icon without sparkles.** On a character without Mining, with *Only What You Can Gather* on, walk up to an ore vein. *Expected:* no sparkles and no pickaxe over it (unless *Interact Key Icons* was your own setting before).
- [ ] **Self-cast.** With *Enable Interact Key* off before highlights: stand next to an NPC, then next to a player, and cast a friendly spell (a heal) without a target, out of combat and as a fight begins. *Expected:* it lands on you. Note whether soft targeting pauses as a fight begins (debug line, or `SoftTargetInteract` at 0).
- [ ] **Your own interact key.** With *Enable Interact Key* on before highlights. *Expected:* the key keeps working on NPCs; nothing pauses it.
- [ ] **Game settings.** Turn highlights off. *Expected:* every setting noted above is back. Turn them on, change *Enable Interact Key* by hand, turn them off: yours stays. Turn them on and log out: back again after logging in with highlights off.
- [ ] **Other addons.** With a nameplate addon loaded (Platynator), then with Lueur. *Expected:* herbs, ore, chests and quest objects sparkle all the same, with no interact icon over them; what the nameplate addon draws itself (its plate) stays its own. With Lueur, note how both effects look.
- [ ] **The game's loot sparkle.** With `outlineModeShowLootEffectWhenDisabled` on (Forever Loot Sparkles, or by hand), look at a quest object. *Expected:* note how both sparkles look together.
- [ ] **In a fight.** *Expected:* the sparkles keep working; a switch changed in the fight applies at once, game settings after it; no errors and no blocked action.
- [ ] **Profile texts.** Share a profile on WoW Forever and import it on retail. *Expected:* it reads, with the highlights' part left out.
- [ ] **A quest object's quest changes (0.5.5).** Stand at a quest object until it sparkles; finish the objective it is for (or abandon the quest), and accept a quest that wants an object you stand at. *Expected:* the sparkles follow at once: the object you no longer need stops sparkling as a quest object, the one you now need starts.
- [ ] **Quest objects before the first one (0.5.7).** Debug on (`/lootoman debug on`). Accept a quest that asks to collect objects from the world, and walk up to one before collecting any. *Expected:* it sparkles at once, as a quest object; the debug line says `quest by game`, `quest by tooltip` or `quest by objective`. Collect them all (or abandon the quest), walk up to another: no sparkles. A mailbox, a vendor and an object the quest does not want: no sparkles. Note the quest and the debug line of any quest object that stays dark.
- [ ] **Corpses to skin (0.5.7).** On a character with Skinning, debug on. Walk up to a corpse you killed and have not looted, loot it, then walk up to it again; then to corpses others killed, looted and not. *Expected:* a corpse sparkles only once it can be skinned (looted, or with no loot), with its name and the skinning icon over it; faint with too little skill; no empty nameplates over the other corpses. Note each corpse's debug line (its cursor, and `no nameplate` if the game gave none). On a character without Skinning: no sparkles, unless *Only What You Can Gather* is off (note whether the skinning cursor shows at all). Untick *Corpses to Skin*: none.
- [ ] **Corpses with a nameplate addon (0.5.8).** With Platynator (or another nameplate addon) enabled, walk up to a corpse that can be skinned. *Expected:* only the sparkles, the skinning icon and the corpse's name: no health bar, name or numbers from the nameplate addon over it. Walk away: other units' plates look as before. A herb or a vein still shows the nameplate addon's own icon, if it draws one.
- [ ] **After a client update.** *Expected:* the object's nameplate still stays hidden under the sparkles (no name, bar or interact icon from the game), and the self-test's `Highlights:` line shows every function `yes`.

### The icon and the name over a sparkling object (0.5.7)

On WoW Forever, with the default settings unless the check says otherwise.

- [ ] **The default.** Walk up to a herb, an ore vein, a chest and a quest object. *Expected:* over the stars, the object's interaction icon (the herb leaf, the pickaxe, the hand) and its name under it, in white with an outline, fully opaque, about the size of the game's normal text; one icon only, ours (the game's own stays off); NPCs keep the game's icon.
- [ ] **On the options page.** Right under *Highlight Lootable Objects*, *Intensity* (a slider, 100 %) and under it *Sparkle Color* (a gold swatch); a bigger gap, then the heading *What to Highlight* (in the checkbox labels' font) with the four kinds in two columns and *Only What You Can Gather*; a bigger gap, then *Above the Object* (*Icon and name*) with *Opacity* (100 %), *Text Size* (12), *Text Color* (a white swatch) and *Text Style* (*Outline*) under it. Choose *Icon*: *Expected:* the three text settings greyed, *Opacity* not; the icon alone at the centre. Choose *Nothing*: *Opacity* greyed too; nothing over the object. Each change applies at once. Turn highlights off: the heading and every setting greyed.
- [ ] **Size, colour and style.** With *Icon and name*: move *Text Size* to 8 and 24; pick a colour with the swatch, then open it again and press *Cancel*; try *Shadow*, *Outline*, *Thick outline* and *Backdrop* over grass, snow, stone and water. *Expected:* the name follows each change at once; Cancel puts the colour before back; the backdrop is a dark strip just around the name; note which style reads best.
- [ ] **Intensity.** Move *Intensity* to 10 % and back to 100 %; walk out of reach, then to a locked chest or a node that needs more skill. *Expected:* the stars follow the slider at once; out of reach and locked they are fainter, by the same share; the icon and the name stay as they are.
- [ ] **Sparkle colour.** Pick another colour with *Sparkle Color*, then open it again and press *Cancel*. *Expected:* the stars take the colour at once, and Cancel puts the gold back; the icon and the name keep theirs.
- [ ] **Opacity.** Move *Opacity* to 10 % and back. *Expected:* the icon and the name follow at once, the stars do not.
- [ ] **In a fight.** *Expected:* the icon and the name keep showing (the name may be one the game hides from addons: it still shows); no errors.
- [ ] **A nameplate addon.** With Platynator. *Expected:* our icon and name over the stars; the addon's own plate stays its own; no second icon from the game.
- [ ] **Kept.** `/reload`, and a profile text shared and imported. *Expected:* the four settings kept; a new character gets *Icon and name*.
- [ ] **Russian client.** *Expected:* «Яркость искр», «Цвет искр», «Что подсвечивать» with «Трупы для свежевания» and «Только то, что можно собрать», «Над объектом», «Непрозрачность», «Ничего», «Иконка», «Иконка и название», «Размер текста», «Цвет текста», «Оформление текста» with «Тень», «Обводка», «Толстая обводка», «Подложка»; nothing cut.

## Saved diagnostics (0.5.5)

- [ ] **Self-test kept.** `/lootoman selftest`, then `/reload`. *Expected:* the saved data holds the same lines (`LootomanDB.sections.diagnostics.selfTest`), with the client and the time it ran.
- [ ] **Debug log kept.** `/lootoman debug on`, loot a few things, `/lootoman debug off`, loot again, `/reload`. *Expected:* the saved log holds the debug lines from while it was on, each with its session time, and nothing after.
- [ ] **Cleared.** `/lootoman debug clear`, then `/reload`. *Expected:* a chat line says they are cleared; the saved log is empty and no self-test is kept.

## Taint

- [ ] **Taint log.** After the rounds above, `/reload` and look at `Logs/taint.log`. *Expected:* no lines blaming Lootoman for the loot window, the merchant frame, the game menu or a protected action of the loot feed's use button.

## Russian client

- [ ] **Strings.** Game language Russian. *Expected:* every option, menu, window and message in Russian, the new ones too: *Вид ленты*, *Лента* and *Оформление* in the look window, *С фоном*, *Кнопка у окна добычи*, *Кнопка у сумок*, *У торговца*, *Выбросить хлам*, *Разбор хлама*, *Список хлама*, *Предложения*, *Изменить список хлама*, and the Auto Loot box's header with the game's own names; on WoW Forever *Подсвечивать объекты с добычей* with *Травы*, *Руда*, *Сундуки*, *Объекты заданий* and *Только травы и руду, которые можно собрать*. Nothing is cut off in the main page's dropdowns.
- [ ] **Feed messages.** Loot items and gain reputation. *Expected:* rows like «Репутация Штормграда +250» («Фракция «…»» for a faction name the message does not decline); the self-test still shows `20 of 20`.
- [ ] **Numbers.** With a look of icons, loot money and gain experience in the thousands; point at the experience row. *Expected:* note the decimal point the client gives ("1.23" or "1,23"), the K and M, and the thousands separator in the tooltip.
