# Bussin Brews

A cozy traveling drink-truck management game built with Godot 4.7. Prices follow the real Consumer Price Index, weather and location change what sells, and customers from five generations, from Gen Alpha kids saying "aura" to boomers saying "groovy", buy, tip and talk differently.

## Look and feel
An illustrated street scene in the spirit of Tiny Bookshop: your truck, a backdrop per location (school, beach, office park), weather and time of day, and flat-style people who walk up to the window, order, take their cup and leave. Each generation has its own look. Everything is drawn from shapes in code (`scripts/ui/truck_scene.gd`, `person.gd`) as a stand-in, so real sprite art can replace it later without touching game logic.

## Playing
Run `./run.sh`, or open the folder in the Godot editor and press F5. (On a fresh checkout, launching with plain `godot --path .` fails until the project has been imported once; `run.sh` and the editor both handle that.) Pick a start: **Easy** ($1,000), **Medium** ($500) or **Hard** ($100). Each day:
1. **Briefing:** weather, gas price, headlines, and how yesterday went.
2. **Plan:** pick a spot on the left; on the right, pick a **quantity step** (by 1, 3 or 5) and your **tips** setup (tip jar, or a checkout tip screen that earns more but annoys some people), then use −/+ in the **Drinks** and **Baked goods** tabs to set each item's price and servings. "Restock from yesterday's sales" adjusts stock to what sold.
3. **Serve customers** one at a time (space serves what they asked for, or suggest something else, chat, or turn them away). After each drink you can **upsell a bakery treat** (brownie, cupcake, protein ball, cookie, muffin) matched to who they are and what they bought. Or **breeze through the day** on autopilot, where treats still sell but less often.
4. **Wrap-up:** today vs yesterday, drink by drink, plus lessons for tomorrow.

**Stats** (on the briefing, plan and wrap-up screens): a daily graph of profit, sales, tips, customers or any item's sales, colored by location, weather or tip setup, plus averages per group and a table of which items sell best where. Hover a bar for details.

## Saving
Press **Save progress** on the wrap-up after a day. The title screen then offers **Continue**, or **New game**, which asks before erasing your save. Losing a run (running out of gas money) clears the save. The file is `savegame.json` in Godot's user data folder for this project (macOS: `~/Library/Application Support/Godot/app_userdata/Bussin Brews/`).

## Development
- Design: [docs/DESIGN.md](docs/DESIGN.md), generation data and sources: [docs/GENERATIONS.md](docs/GENERATIONS.md)
- Tests: `godot --headless --path . --script tests/run_sim_tests.gd` (sim logic). UI checks, each needs a display: `godot --path . tests/playthrough.tscn` (clicks through a day), `tests/sweep.tscn` (every weather/location and random seeds), `tests/soak.tscn` (40s on a banner screen), `tests/save_test.tscn` (saving and loading; uses a throwaway file, runs headless), `tests/service_race_test.tscn` (double presses and other timing edge cases during service), `tests/stats_test.tscn` (the Stats screen). The editor halts on any script error, so these should print no `SCRIPT ERROR` lines.
- Refresh CPI data: `python3 tools/fetch_cpi.py 2025 2026`
- Screenshots of each screen (needs a display): `godot --path . tests/screenshots.tscn -- <out_dir>`
