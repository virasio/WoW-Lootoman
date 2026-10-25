# Lootoman

Lootoman is a World of Warcraft addon for loot, bags and getting rid of junk. It looks and feels like the default game interface.

## Features

### Fast autoloot

- When the game loots automatically (the Auto Loot option, or the auto loot key), Lootoman picks up everything at once and the loot window stays hidden. It takes one item at a time, as fast as the server answers, so large pulls do not disconnect you.
- Before taking an item it checks that there is room: a partial stack of the same item, a free slot in a general bag, a profession bag that takes the item, or the reagent bag for crafting reagents.
- What does not fit stays in the loot window, which then opens with the items that are left. So does everything after an error, such as full bags or a roll that is still going on.
- Items that bind when picked up are confirmed for you when you are not in a group (an option, on by default). In a group, the loot window opens and you decide.

### Loot feed

- What you pick up appears next to the centre of the screen and fades out: items, currencies, money, reputation and, if you want, experience. Repeated items merge into one row with a count. Money from merchants, mail, trade, the auction house and banks is not loot and is not shown.
- Options: what the feed shows, the lowest item quality it shows, how many rows are shown at once (a full feed fades its oldest rows out), whether new rows appear on top or at the bottom, time on screen, fade-out time, size, background opacity, how many of the item you own on its icon, and a glow for rare items.
- Point at a row to see the item's or currency's tooltip; the feed waits while you do. Clicks go through to the game world.
- The feed is placed with the game's Edit Mode, with its own position in every Edit Mode layout. Its options are also in its Edit Mode dialog.
- **Row designer** (`/lootoman design`, or the buttons on the loot feed's options page and in its Edit Mode dialog): click a part of the sample rows — icon, name, amount or owned count — to choose it, and drag it to move it. For each part, choose whether it is shown, what it is anchored to and at which point, its offsets, the icon's size as a share of the row's height, and a text's size, maximum width and alignment; for the rows, their height, width and gap. The feed follows every change at once.
- **Row layouts** have names and are shared by every profile; each profile uses one of them. New layouts start from the Large, Compact or Minimal template, and layouts can be copied, renamed, reset to their template and deleted. The layout Default always exists.

### Options and profiles

- One options page in the game's AddOns settings: the profile on top, chosen from a menu like Edit Mode's layout menu (copy, rename, reset, delete, new profile, import, share), with a Reset button beside it; then a switch for each feature, with its main options under it and a button that opens its own page.
- Every character can use its own profile; new characters use the Default profile.
- **Share** makes a text of the current profile to give to another character or player. Tick what goes into it: each feature's settings, the loot feed's position and the layout it uses, and any of your row layouts. **Import** reads such a text, shows what it holds and takes what you tick, into a new profile or into the current one. When an imported layout's name is taken, choose for each one: keep both, replace yours, or keep yours. Row layouts can also be shared and imported on their own, from the designer.
- Changes apply at once, without `/reload`.

### Languages

English and Russian.

### Commands

- `/lootoman` or `/ltm`: open the options.
- `/lootoman design`: open the loot feed's row designer.
- `/lootoman debug on` or `off`: turn debug messages on or off for all characters.
- `/lootoman selftest`: check the addon against the game client. Its output helps with bug reports.

## Status

Alpha: features and options may still change between versions. Please report problems in the comments on [Lootoman's CurseForge page](https://www.curseforge.com/wow/addons/lootoman), with the output of `/lootoman selftest`.

## License

[MIT](LICENSE)

Libraries bundled in `Libs/` keep their own licenses:

- [LibStub](https://www.wowace.com/projects/libstub): public domain.
- [LibEditMode](https://github.com/p3lim-wow/LibEditMode) by p3lim: [its license](Libs/LibEditMode/LICENSE.txt).
