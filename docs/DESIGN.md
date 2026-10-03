# Bussin Brews: Design Doc

## Pitch
You run a traveling drink truck. Each day you check the weather and the news, pick where to park, set your menu and prices, and serve a line of customers from five generations, from Gen Alpha kids to boomers, who order, tip and talk differently. Prices follow the real Consumer Price Index, so a real-world gas spike really does make the long drive to the beach hurt. The feel is cozy, in the spirit of Tiny Bookshop.

## Requirements
Everything asked for so far, with where it stands. **Status:** Done, Partial (some of it is built), Planned (agreed, not built), Changed (we went a different way, and why).

| # | Requirement | Status | Notes |
|---|---|---|---|
| R1 | A traveling truck that sells fancy drinks ("Bussin Brews") | Done | 5 drinks in `data/drinks.json` |
| R2 | Weather, location and which drinks you stock affect orders | Done | See [Demand model](#demand-model) |
| R3 | Hip teen lingo | Changed | Became generational slang (R11): each age group talks like its generation |
| R4 | Fun recurring characters | Partial | Kayden, Priya, Dale and Nana Deb exist but only appear in the end-of-day quote. Big Tony, Ms. Alvarez and Jaxon are planned. See [Characters](#recurring-characters) |
| R5 | Staff you have to keep: tips or no tips, work drama | Planned | Not built yet. See [Staff and drama](#staff-and-drama-planned) |
| R6 | The economy reacts to real current events (e.g. the gas spike) | Done | Real BLS CPI data drives prices; the real March 2026 gas spike hits around day 21. See [Economy](#economy-and-real-world-prices) |
| R7 | A soothing color scheme | Done | See [Visual style](#visual-style) |
| R8 | Look and feel like Tiny Bookshop | Partial | Illustrated street scene with flat people walking up. Truck decorating and real art are not built yet |
| R9 | Starting money: originally $1,000, then Easy $1,000 / Medium $500 / Hard $100, default Easy | Done | `data/difficulties.json` |
| R10 | Real-world pricing based on the Consumer Price Index | Done | `tools/fetch_cpi.py` pulls BLS data into `data/cpi.json` |
| R11 | Older people use older slang, younger people use younger slang | Done | `data/dialogue.json`, `data/characters.json` |
| R12 | Generational behavior from real data (you suggested: older people chat but don't tip, younger tip generously) | Changed | The survey data says the opposite about tips: older generations tip more. The game follows the data. Older customers chatting more is kept as a design choice. See [GENERATIONS.md](GENERATIONS.md) |
| R13 | A language toggle, then removed since there was only one sensible mode | Done (removed) | Always generational |
| R14 | Sell to each customer by hand, or breeze through the day | Done | See [Service](#service-hands-on-or-breeze-through) |
| R15 | Compare what worked with the previous day | Done | Briefing, plan screen and wrap-up all compare. See [Wrap-up](#wrap-up-and-day-over-day-comparison) |
| R16 | Turn drinks up or down | Done | −/+ for price and servings on every item |
| R17 | Upsell brownies, cupcakes, protein balls, cookies and muffins | Done | See [Bakery case](#bakery-case-upsells) |
| R18 | Not emoji, not text-only: flat people moving, like Tiny Bookshop | Done | Drawn from shapes in code as a stand-in for real art |
| R19 | Drinks and baked goods as tabs, no long scrolling screen | Done | Plan screen fits on one page |
| R20 | Save progress | Done | See [Saving](#saving) |
| R21 | AI for realistic turn-by-turn conversations, without big running costs, since others may play | Planned | See [AI dialogue](#ai-dialogue-planned) |
| R22 | A path to real art later | Planned | See [Art](#art) |
| R23 | It must play from the Godot editor's Play button | Done | The editor halts on any script error, so the test suites check for zero `SCRIPT ERROR` lines |
| R24 | Public GitHub repo | Done | https://github.com/Blakewell/bussin-brews |
| R25 | Gen Alpha kids, using current Gen Alpha slang like "aura" | Done | Fifth generation; mostly at the school line; Nova "Aura" is a regular. See [GENERATIONS.md](GENERATIONS.md#gen-alpha) |
| R26 | Looks match the person: no beards on women, no buns on men | Done | Each customer has a gender with a matching name; beards are Gen X men only, buns millennial women only. Tested over 6,000+ customers |
| R27 | A Save button after each day | Done | "Save progress" on the wrap-up; saving no longer happens automatically |
| R28 | Quantities go by 1, 3 or 5 from a dropdown, default 5 | Done | "Quantity step" on the plan screen; applies to servings |
| R29 | At least 10 lines per generation, for variety | Done | 10+ lines for every situation (order, decline, chat, great, ok, bad, add-on yes/no, tip screen): 450 lines |
| R30 | Choose between a tip jar and a checkout tip screen | Done | See [Tips](#tips-jar-or-checkout-screen) |

## Inspiration and tone
**Tiny Bookshop**: a calm daily rhythm of choosing a spot, setting up, serving and winding down; a town of recurring locals; weather and events that nudge decisions without punishing you. Bussin Brews adds generational slang, real-world prices and (later) staff drama. Those should add spice without breaking the cozy feel: setbacks are recoverable and failure is gentle.

## Starting modes
Easy starts with $1,000, Medium $500, Hard $100. Easy is the default. Default stock on the plan screen scales with starting cash, so Hard opens with 3 of each drink and no baked goods. A run ends if cash drops below $25. On the title screen, 1/2/3 also pick a mode and Enter starts or continues.

## Daily loop (as built)
1. **Briefing:** date, weather, gas price and its change, headlines, and yesterday's result with lessons.
2. **Plan:** pick a location (left column), choose the quantity step (by 1, 3 or 5) and the tip setup, and set prices and servings in the Drinks and Baked goods tabs (right). The upfront cost (gas, permit, stock) and cash-after update live.
3. **Service:** serve customers one by one, or breeze through the day on autopilot.
4. **Wrap-up:** sales, tips, costs and profit against yesterday, per-item results, lessons, and a quote from a regular.
5. **Save progress** (button), then the next day.

## Demand model
Each shift has a number of arrivals:

```
arrivals = location.base_traffic × 2.4 × weather.traffic × event_multiplier × reputation
```

Each arrival rolls a generation from the location's mix (the school line is 35% Gen Alpha and 25% Gen Z; the office park is mostly millennials and Gen X). For each drink, their interest is:

```
appeal = average over the drink's tags of (crowd taste × weather fit × generation taste) × price factor
price factor = exp(−location sensitivity × generation sensitivity × (your price / fair price − 1))
```

Whether they buy at all depends on total appeal times the generation's `buy_rate` against a walk-away weight. If they buy, they pick a drink in proportion to appeal among what's in stock. If nothing they'd want is left, they leave unhappy. The truck has 90 service slots per shift; once they're used up, people give up on the line. Chatty customers and add-on offers use extra slots.

Reputation (0.7 to 1.5) moves with satisfaction: people served versus people lost to stockouts, the line, or declined pitches.

## Service: hands-on or breeze through
**Hands-on.** Each customer walks up to the window and says their order in a speech bubble in their generation's voice. You can:
- **Serve what they asked for** (Space).
- **Suggest a different drink.** They accept with a chance based on how much they like it compared to what they came for. Each pitch costs a moment, and after one "no" they stick with their order.
- **Hear them out** if they want to chat (better tip, costs time) or **keep it quick** (no time cost, worse tip).
- **Turn them away.**

After a drink sells you can offer one treat from the bakery case. Each treat shows a hint: good bet, maybe, or long shot.

**Breeze through.** The same model runs on autopilot: everyone gets what they asked for, every chatter is heard out, and the likeliest treat is offered with a lower success rate. You can switch from hands-on to breeze at any point in a shift.

## Bakery case (upsells)
Fudge brownie, frosted cupcake, protein ball, chocolate chip cookie, blueberry muffin (`data/treats.json`). Acceptance depends on generation taste (muffins and cookies skew older, cupcakes and brownies younger, kids love cupcakes and skip protein balls, protein balls skew millennial), how well it pairs with the drink they bought (cookies with hot drinks, protein balls with iced coffee), and price. These preferences are design estimates, not survey data. Unsold stock is wasted at the end of the day.

## Tips: jar or checkout screen
Chosen on the plan screen ("Tips"); the truck shows a tip jar or a card tablet on the counter.
- **Tip jar (default):** people tip on their own, at each generation's real counter-tipping rate. Coins and bills.
- **Tip screen at checkout:** the "feels like you have to tip" screen. Per customer it brings in about **12% more** in tips (calibrated to the finding that digital prompts raise gratuities about 12%; café tips average ~15% when given). But it **annoys** people at real rates by generation (Bankrate 2025: Gen Z 27%, millennials 35%, Gen X 45%, boomers 44%; Gen Alpha 20% is an estimate). Annoyed customers tip half as often, at 10%, grumble about it in a bubble, and cost a little reputation.
- **The trade-off today:** tips are small next to drink sales (~$10 vs ~$270 a day), so over a week the reputation hit usually outweighs the extra tips and the jar wins on cash. That's realistic: tips mostly belong to staff. Once the staff system exists, tips will fund staff pay and morale, which makes the screen more tempting.
- Tips use their own random dice, so switching tip mode never changes which customers show up.

## Wrap-up and day-over-day comparison
- **Wrap-up:** a Today / Yesterday / Change table for sales, tips, costs and profit (costs going up shows as a warning), per-item sold vs stocked with ▲/▼ against yesterday, add-on results, and what was lost to stockouts, the line, or declined pitches.
- **Lessons:** the best money-maker, items that sold out, and items that mostly went to waste.
- **Tips line:** how many tipped, and with the tip screen how many were annoyed and the reputation change.
- **Plan screen:** each item shows how it did yesterday, each location shows its last result and that day's weather, and "Restock from yesterday's sales" sizes stock to what sold.
- **Briefing:** yesterday's location, weather, profit and lessons.

## Economy and real-world prices
Prices follow four BLS CPI-U series in `data/cpi.json`:

| Series | Drives |
|---|---|
| Food away from home | The fair price of each drink and treat (what customers expect to pay) |
| Food at home | Ingredient cost per serving |
| Gasoline | Gas price, which sets trip cost (round trip ÷ 6 mpg × price per gallon) |
| All items | Reference only |

Reference prices are set for January 2026, the base month. Each game month is 10 days, starting January 2026. A month with no published value carries the previous value forward. October 2025 is missing from three of the four series in the BLS data.

**Headlines** come from two places. Real CPI moves generate them automatically at the start of each month: gas up 8%+, gas down 6%+, groceries up 1.5%+. Curated events in `data/events.json` add the rest: the spring school fair (day 32), the boardwalk festival (day 40) and a heat dome (day 55).

**Data window:** the data currently runs through August 2026, about day 80. After that, prices stop changing until the data is refreshed with `python3 tools/fetch_cpi.py 2025 2026`.

Planned: events that move fuel, ingredient and wage costs directly. The original design called for these, but none are wired up yet.

## Generations
Five generations (Gen Alpha, Gen Z, millennial, Gen X, boomer), each with buying, tipping, chatting and taste profiles from survey data where it exists, and its own slang. Details, sources and which numbers are estimates are in [GENERATIONS.md](GENERATIONS.md).

## Recurring characters
**Built** (in `data/characters.json`; they currently appear only in the end-of-day quote):
- **Nova "Aura"** (Gen Alpha): rates everything in aura points and yells "six seven".
Each regular's end-of-day quote is drawn from their own lines plus their generation's, so it varies day to day.
- **Kayden "Mid"** (Gen Z): rates everything "mid" until you earn a "bussin".
- **Priya** (millennial): overachiever barista who wants a raise.
- **Dale** (Gen X): unimpressed regular with a story about 1994.
- **Nana Deb** (boomer): sweet, says "groovy" and "cool beans".

**Planned:** Big Tony (rival truck owner, sabotages with a smile), Ms. Alvarez (health inspector, worst timing), Jaxon (loyal but chaotic crew member). Next steps: regulars should walk up as real customers in the scene, remember past visits, and have small arcs.

## Staff and drama (planned)
Not built yet. The plan:
- Staff have skills (speed, accuracy, charm) and traits (e.g. `main-character`, `grinder`, `drama-magnet`), plus morale, loyalty and wage expectations.
- The **tips** choice: share tips with staff or keep them. Sharing costs you money but raises morale. Other choices are schedule fairness, raises and handling conflicts.
- Low morale slows service and raises the chance of no-shows and quits. Hiring and training cost money.
- **Work drama** is an event system keyed on traits and relationships: feuds, a bad review, someone wanting Friday off.

## Visual style
**Soothing palette** (`scripts/ui/palette.gd`): sage, dusty blue, warm cream, peach and lavender, with dark-slate text and one soft coral accent for the main action. No pure black or white. Warnings use a warm amber, never alarm red.

**The street scene** (`scripts/ui/truck_scene.gd`) appears as the stage during service and as a banner on the other screens:
- A backdrop for each location: a school with a flagpole and fence, a beach with sea, umbrella and palm, or an office park with towers.
- Weather: drifting clouds, rain, heat glow, a chilly tint.
- Time of day: the sky moves from dawn to midday to dusk as the shift progresses.
- The truck with its awning, string lights, "BUSSIN BREWS" sign and a barista in the window.

**People** (`scripts/ui/person.gd`) are flat-style figures who walk up, order in a speech bubble, take a cup, and leave holding it. Non-buyers walk past. Looks follow generation and gender (every customer's name matches their gender):

| Generation | Women | Men |
|---|---|---|
| Gen Alpha (kid-sized, backpack, light-up sneakers) | ponytail and bow | backwards cap |
| Gen Z (hoodie, beanie, headphones) | long hair under the beanie | short hair |
| Millennial (glasses) | bun, tote bag | short hair |
| Gen X (flannel) | shoulder-length hair | beard |
| Boomer (cane, sometimes a visor) | curly gray hair | thinning gray hair, mustache |

## Art
All art is currently drawn from shapes in code, as a stand-in. Swapping in real art means replacing the draw calls in `person.gd` and `truck_scene.gd` with sprites; game logic doesn't change. Options: free CC0 packs (e.g. Kenney), cheap itch.io packs, or a commissioned illustrator for a consistent look. AI image tools are fine for concept art; check their licensing before shipping anything made with them.

## Saving
One save slot (`user://savegame.json`), written when you press **Save progress** on the wrap-up. It stores the run plus the UI's chosen spot, prices, stock, quantity step and tip setup. If you don't save, quitting and continuing picks up from the last day you saved. Today's weather and headlines are rebuilt from the run's seed, so a loaded day matches the one you left. Writes go to a temp file first, then get renamed into place. A damaged or old-version save is ignored. "New game" asks before erasing the save, and losing a run deletes it.

## AI dialogue (planned)
**Goal:** more realistic turn-by-turn conversations without running costs for you, since others may play.

**Approach:** a swappable dialogue layer. AI only writes words. Sales, prices and tips stay in the tested sim; at most a small, bounded mood nudge. Sources, in order:
1. **Shipped library (default).** Use AI once, during development, to write thousands of lines tagged by generation, situation, weather and mood, and ship them as data. Free to play, works offline, much more variety than today.
2. **Local model (optional).** If the player runs a local model (e.g. via Ollama), the game talks to it on their machine. No cost to anyone, but it's a multi-GB download, needs a decent computer, and small models are weaker at staying in character.
3. **Bring your own key (optional).** Players who want the best quality paste their own API key and pay for their own use.

The game always falls back to the shipped library, so it never breaks. A game must never ship with a built-in API key, because anyone can extract it.

## Architecture (Godot 4.7, GDScript)
- **Autoloads:** `Content` (loads all `data/*.json`; owns `Cpi` and `Economy`) and `GameState` (run state, day flow, saving).
- **Sim** (`scripts/sim/`, no UI): `cpi.gd`, `economy.gd`, `demand.gd`, `shift.gd` (one customer at a time; hands-on and autopilot share it), `game_calendar.gd`.
- **UI** (`scripts/ui/`): `main.gd` builds every screen in code; `palette.gd` holds the theme; `truck_scene.gd` and `person.gd` draw the scene.
- **Data** (`data/`): drinks, treats, locations, weather, events, generations, characters, dialogue, difficulties, cpi. No game content is hard-coded in scripts.
- **Launch:** the editor's Play button, or `./run.sh` (imports first, since a fresh checkout otherwise fails to find script classes).

## Testing
| Suite | Covers |
|---|---|
| `tests/run_sim_tests.gd` (headless) | CPI, economy, demand, generations, upsells, declined pitches, difficulty, event timing, names and looks by gender, dialogue counts, tip jar vs screen |
| `tests/save_test.tscn` (headless) | Save round trip, bad files, the Save button and Continue flow, tip modes and reputation, quantity step |
| `tests/playthrough.tscn` | A full day clicked with real mouse events |
| `tests/sweep.tscn` | Every location × weather × time of day, plus 12 random-seed games |
| `tests/soak.tscn` | 40 seconds on a banner screen (catches errors that need time to appear) |
| `tests/service_race_test.tscn` | Double presses and other timing edge cases during service |
| `tests/keys.tscn`, `tests/screenshots.tscn` | Title keyboard controls; screenshots of each screen |

All UI suites use a throwaway save file and should print zero `SCRIPT ERROR` lines.

## Roadmap
1. ~~Vertical slice: data, demand, CPI, one day loop~~
2. ~~Hands-on service, comparisons, −/+ controls, upsells, street scene, modes, tabs, saving~~
3. **Recurring characters in the scene:** regulars walk up, remember you, small arcs.
4. **Staff and drama:** hiring, morale, tips choice, quits, drama events.
5. **Dialogue library**, then optional local-model and bring-your-own-key sources.
6. **Economy depth:** fuel, ingredient and wage events, more locations (stadium lot, farmers market, skate park), refreshed CPI data.
7. **Polish:** truck decorating, real art, audio, balance.

## Known limitations
- Prices freeze after the CPI data ends (currently around day 80) until refreshed.
- Regulars only speak in the end-of-day quote, picked at random rather than tied to the location.
- Quitting mid-day and continuing replays the same day with the same customers (the day is seeded). That's fine for a cozy game, but it allows retries.
- The menu is fixed: no custom recipes yet.

## Open questions
- Desktop only, or touch controls too?
- Mixable custom drinks, or keep a fixed menu?
- Which art route (packs vs commissioned), and when?
