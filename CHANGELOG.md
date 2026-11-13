# Lootoman changelog

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
