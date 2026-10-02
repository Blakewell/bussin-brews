# Bussin Brews

A cozy traveling drink-truck management game built with Godot 4.7. Prices follow the real Consumer Price Index, weather and location change what sells, and customers from four generations buy, tip and talk differently.

## Playing
Open the folder in Godot and press F5. Each day:
1. **Briefing:** weather, gas price, headlines, and how yesterday went.
2. **Plan:** pick a spot, then use −/+ to set each drink's price and servings. "Restock from yesterday's sales" adjusts stock to what sold.
3. **Serve customers** one at a time (space serves what they asked for, or suggest something else, chat, or turn them away). After each drink you can **upsell a bakery treat** (brownie, cupcake, protein ball, cookie, muffin) matched to who they are and what they bought. Or **breeze through the day** on autopilot, where treats still sell but less often.
4. **Wrap-up:** today vs yesterday, drink by drink, plus lessons for tomorrow.

## Development
- Design: [docs/DESIGN.md](docs/DESIGN.md), generation data and sources: [docs/GENERATIONS.md](docs/GENERATIONS.md)
- Tests: `godot --headless --path . --script tests/run_sim_tests.gd`
- Refresh CPI data: `python3 tools/fetch_cpi.py 2025 2026`
- Screenshots of each screen (needs a display): `godot --path . tests/screenshots.tscn -- <out_dir>`
