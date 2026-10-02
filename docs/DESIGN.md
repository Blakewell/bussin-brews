# Bussin Brews: Design Doc

## Pitch
You run a traveling drink truck. Every day you pick a spot, check the weather and the news, stock a menu, manage a crew with feelings, and try to stay profitable. The world pushes back: heat waves, rain, gas spikes, ingredient shortages, and a rotating cast of regulars and coworkers who all have opinions. Everything is narrated in teen slang.

## Inspiration and tone
The feel we're after is **Tiny Bookshop**: a cozy, low-stress management game about a small mobile shop. Take the structure, not the content:
- A calm daily rhythm of choosing a spot, setting up, serving, and winding down.
- A charming town of recurring locals you come to care about.
- A shop you personalize (decorate the truck, pick a menu that reflects your taste).
- Weather and local events that nudge decisions without punishing you harshly.

Bussin Brews differs by adding a teen-slang voice, staff drama, and real-world economic pressure. Those layers should add spice without breaking the cozy feel: setbacks are recoverable and failure is gentle.

## Starting modes
Easy starts with $1,000, Medium with $500, Hard with $100 (`data/difficulties.json`). The default stock on the plan screen scales to the starting cash so Hard begins with a small, affordable menu and no bakery stock.

## Core loop (one in-game day)
1. **Morning briefing.** Weather forecast, headlines, gas price, crew mood.
2. **Plan.** Pick a location, set the menu and prices, buy stock. Fuel cost depends on distance.
3. **Service.** A short real-time shift. Customers arrive, you or your crew make drinks, and speed and accuracy affect tips and reputation.
4. **Close out.** Revenue, costs, profit, and a **drama beat**: a crew conflict, a regular's request, or an event that forces a choice.
5. **Save and next day.** Choices carry consequences forward.

## Systems

### Demand model
Orders per hour at a spot:

```
orders = location.base_traffic
       * weather_fit(drink, weather)     // iced drinks boom in heat, hot drinks in rain/cold
       * event_modifier                  // festival, game day, school break
       * price_factor(price, location)   // elasticity depends on who lives there
       * reputation                      // grows with good service, shrinks with bad
```

Each drink has tags (`iced`, `hot`, `sweet`, `fancy`, `caffeinated`). Each location has a crowd profile (students like cheap and sweet; downtown likes fancy and caffeinated; the beach likes iced). `weather_fit` and the crowd match both read these tags, so adding a drink or place is data-only.

### Locations
Examples: School Pickup Line, Beach Boardwalk, Downtown Office Park, Stadium Lot, Farmers Market, Skate Park. Each has traffic, crowd profile, rent or permit cost, distance (fuel), and time-of-day curve. Some are locked until reputation grows.

### Truck customization
Decorate the truck with unlockable items (string lights, plants, stickers, signage, a tiny speaker). Decor gives small bonuses to certain crowds (fairy lights for evening spots, plants for the farmers market) and is mostly there for personality.

### Bakery case (upsells)
After a drink sells, offer one treat: brownie, cupcake, protein ball, cookie or muffin. Acceptance depends on the customer's generation, how well the treat pairs with their drink (cookies with hot drinks, protein balls with iced coffee), and price. Offers cost a little service time, so spamming slows the line. Autopilot sells treats too, but less persuasively than hands-on play.

### Menu and ingredients
Drinks are recipes made of ingredients (base, flavor, topping). Ingredients have a cost that the economy can move, and some can run out. Start with a fixed menu. Mixable custom drinks are a later milestone.

### Staff and morale
- Each staff member has skills (speed, accuracy, charm) and traits (e.g. `main-character`, `grinder`, `drama-magnet`).
- Stats: **morale**, **loyalty**, wage expectation.
- Choices that move them: tips (share tips or keep them), schedule fairness, handling conflicts, raises.
- Low morale slows service and raises the chance of a **quit** or a **no-show**. Hiring and training has a real cost.
- **Work drama** is an event system keyed on traits and relationships: two staff feud, someone posts a bad review, someone wants Friday off.

### Recurring characters
Fixed cast with arcs and running gags, so players recognize them. They appear as customers, crew, or vendors.
- **Kayden "Mid" Morris:** regular who rates everything "mid" until you earn a "bussin".
- **Priya:** overachiever barista, wants to be promoted.
- **Big Tony:** rival truck owner, sabotages with a smile.
- **Ms. Alvarez:** the health inspector, shows up at the worst moment.
- **Jaxon:** crew member, loyal but chaotic.
- **Nana Deb:** sweet customer, tips big, speaks in perfect slang that she learned yesterday.

### Economy and current events
The economy is driven by an **event feed** that applies timed modifiers to costs and demand.

```
event {
  headline, description, start_day, duration,
  effects: [{ target: "fuel" | "ingredient:<id>" | "demand:<tag>" | "wages", mult: 1.4 }]
}
```

- **Fuel** is the first-class example: gas price sets the cost of every trip, so a spike forces you to choose between a far lucrative spot and a nearby one.
- Other effects: sugar or dairy cost swings, oat milk shortage, a heat wave, a tariff on cups, inflation nudging wage demands.
- **Phase 1:** curated event packs in JSON, written to resemble real headlines, so the game works offline and tests are deterministic.
- **Phase 2 (optional):** pull real numbers where there is a free source, e.g. the national average gas price, and map them onto the fuel multiplier. Headlines in-game stay curated and hand-written so nothing depends on a news API or its licensing.

### Generations
Customers come from four generations with data-backed buying, tipping and chatting behavior, and each speaks its own slang. See [GENERATIONS.md](GENERATIONS.md).

### Lingo
All player-facing dialogue is pulled from data files with **tags** (greeting, order, praise, complaint, quit) so slang can be swapped out as it ages. Each character has a voice profile (words they favor, words they never use).

## Visual style
**Soothing color scheme** is a core requirement. The game is busy (queues, timers, drama), so the visuals should stay calm.
- Soft, low-saturation pastels: sage green, dusty blue, warm cream, peach, lavender. No pure black or pure white.
- Warm, off-white backgrounds with dark-slate text for readable contrast.
- One gentle accent color for key actions (e.g. soft coral), used sparingly.
- Weather and time of day shift the palette subtly (golden afternoon, misty rainy blue) rather than switching to harsh colors.
- Urgency (impatient customers, low morale) is shown with a warmer tint and motion, not alarm red.
- Define the palette once as a Godot `Theme` resource plus a `Palette` constants script so every screen shares it.

## Architecture (Godot 4, GDScript)
- **Autoloads:** `GameState` (money, day, reputation, save/load), `EventBus` (signals), `Economy` (active modifiers, price lookups), `Content` (loads data files).
- **Data in `data/*.json`:** drinks, ingredients, locations, characters, events, dialogue. No game content hard-coded in scripts.
- **Scenes:** `main_menu`, `briefing`, `planning`, `service`, `closeout`, `drama`.
- **Simulation is separate from UI:** `scripts/sim/` holds pure logic (demand, economy, morale) that can be unit tested without the scene tree.
- Tests via GUT or plain headless script checks for the sim.

## Milestones
1. **Vertical slice.** Data loader, one day loop with 3 locations, 4 drinks, weather and demand model, planning and closeout screens, one fuel event. No real-time service yet (auto-resolved shift).
2. **Service mini-game.** Real-time order taking and drink assembly.
3. **Staff.** Hiring, morale, tips choice, quits.
4. **Characters and drama.** Recurring cast, drama events, dialogue system.
5. **Economy depth.** More events, ingredient shortages, optional live gas price.
6. **Polish.** Art, audio, save/load, balance.

## Open questions
- Art direction: the palette is settled (soothing pastels) and the UI is text-first, with colored chips instead of icons. Is there room for illustrated portraits later?
- Desktop only, or touch controls too?
- Fixed menu to start, or mixable recipes from the beginning?
