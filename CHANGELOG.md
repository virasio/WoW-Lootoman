# Lootoman changelog

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
