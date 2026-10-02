# Generational behavior

Customers belong to one of four generations. Each has a profile in `data/generations.json` that drives what they buy, whether they tip, whether they chat (and slow the line), and how they talk. Each location has its own generation mix in `data/locations.json`.

## What the data says (and how it's used)

| Behavior | Gen Z | Millennial | Gen X | Boomer | Used for |
|---|---|---|---|---|---|
| Always tip counter-service staff | ~14% (estimate) | 18% | 19% | 26% | `tip_chance` |
| Always tip at sit-down restaurants | 45% | 61% | 83% | 84% | Scaling the Gen Z estimate above |
| Tip 20%+ at sit-down restaurants | 16% | 30% | 40% | 49% | `tip_pct` (scaled down for counter service) |
| Weekly beverage-only purchase | 50% | 47% | 36% | 20% | `buy_rate` |
| Coffee spend rated high | 31% | 39% | n/a | 25% (older boomers) | Drink buying |
| Drink style | iced, specialty | iced, specialty (64% had specialty coffee in a day) | middle | hot, plain, rarely sweetened | `tag_fit` |

**Important:** the survey data does not match the "older people don't tip, younger people tip generously" idea. It points the other way: older generations tip more often and more generously, and Gen Z and millennials tip *less* often. The game follows the data. Younger customers still matter because they buy far more drinks (see `buy_rate`).

Boomers being the chattiest and Gen X chatting more than Gen Z is a **game-design choice**, not survey data. It makes older customers a funny trade-off: they tip well but cost you service time.

## Estimates to know about
- Gen Z counter-service tip rate (14%) is not published in the sources I found. I scaled the boomer figure (26%) by the Gen Z/boomer sit-down ratio (45/84).
- `tip_pct` for counter service is a modeled estimate scaled from the sit-down 20%+ shares.
- `tag_fit` multipliers are directional estimates from the qualitative findings, not measured values.
- I read these numbers from search-result summaries, not the original studies. Verify before quoting them publicly.

## Treat preferences
Which generation likes which treat (`gen_fit` in `data/treats.json`) is a **design estimate**, not survey data: muffins and cookies skew older, cupcakes and brownies skew younger, protein balls skew millennial. Pairings (`pairs_with`) are also design choices. Treat prices follow the same CPI scaling as drinks.

## Language
Per game, the player picks:
- **Generational:** each generation, and each named character, speaks in their own era's slang (`data/dialogue.json`, `data/characters.json`).
- **Gen Z only:** everyone uses Gen Z lines.

Slang lives entirely in data files so it's easy to refresh as it ages.

## Sources
- Tipping by generation (counter service, sit-down, 20%+ shares): [Fox News on a millennial tipping survey](https://www.foxnews.com/food-drink/millennials-are-the-worst-tippers-new-survey-shows.amp), [Newsweek](https://www.newsweek.com/millennials-are-the-most-anti-tipping-generation-11915915), and [Fox 9 on the 2025 annual tipping poll](https://www.fox9.com/news/tipping-out-of-control-survey-2025)
- Beverage-only purchase frequency: [Restaurant Dive on NRA beverage research](https://www.restaurantdive.com/news/nra-dirty-soda-coffee-beverage-only-gen-z-occasions/828942/)
- Coffee habits by generation: [Coffee BI](https://coffeebi.com/?p=295401), [GlobalData](https://www.globaldata.com/media/consumer/rtd-iced-coffee-demand-driven-millennials-gen-z-third-say-high-coffee-spenders-says-globaldata-2/)
- Generational language: [UCLA Languaged Life](https://languagedlife.ucla.edu/sociolinguistics/from-slay-to-on-fleek-linguistic-features-of-millennial-and-gen-z-internet-communication/)
