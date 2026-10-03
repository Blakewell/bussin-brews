# Generational behavior

Customers belong to one of five generations: Gen Alpha (kids and young teens, born about 2010 on), Gen Z, millennials, Gen X and boomers. Each has a profile in `data/generations.json` that drives what they buy, whether they tip, whether they chat (and slow the line), and how they talk. Each location has its own generation mix in `data/locations.json`.

## What the data says (and how it's used)

| Behavior | Gen Alpha | Gen Z | Millennial | Gen X | Boomer | Used for |
|---|---|---|---|---|---|---|
| Always tip counter-service staff | ~3% (estimate) | ~14% (estimate) | 18% | 19% | 26% | `tip_chance` |
| Always tip at sit-down restaurants | n/a | 45% | 61% | 83% | 84% | Scaling the Gen Z estimate above |
| Tip 20%+ at sit-down restaurants | n/a | 16% | 30% | 40% | 49% | `tip_pct` (scaled down for counter service) |
| Weekly beverage-only purchase | n/a | 50% | 47% | 36% | 20% | `buy_rate` |
| Coffee spend rated high | n/a | 31% | 39% | n/a | 25% (older boomers) | Drink buying |
| Drink style | sweet, iced, little caffeine | iced, specialty | iced, specialty (64% had specialty coffee in a day) | middle | hot, plain, rarely sweetened | `tag_fit` |

**Important:** the survey data does not match the "older people don't tip, younger people tip generously" idea. It points the other way: older generations tip more often and more generously, and Gen Z and millennials tip *less* often. The game follows the data. Younger customers still matter because they buy far more drinks (see `buy_rate`).

Boomers being the chattiest and Gen X chatting more than Gen Z is a **game-design choice**, not survey data. It makes older customers a funny trade-off: they tip well but cost you service time.

## Gen Alpha
Kids and young teens. What the research says, and how it's used:
- 53% of Gen Alpha get an allowance, averaging $22 a week, and 31% spend it on drinks; 72% say they buy food and drinks. They're spending small, fixed amounts, so they react more to price (`price_sensitivity` 1.6× the location's).
- They strongly influence what their parents buy, and interest in coffee chains like Starbucks rises around ages 11 to 14.
- They show up mostly at the **school pickup line** (35% of that crowd), some at the beach, and almost never downtown.

Design estimates (no survey data found): they rarely tip (`tip_chance` 3%), favor sweet and iced drinks and avoid caffeine, love cupcakes, cookies and brownies but not protein balls, and chat in quick bursts ("six seven!") that cost half the time of an adult chat. Kids are drawn smaller, with a backpack, a backwards cap and light-up sneakers.

**Slang** (kept PG): aura, aura points ("+1000 aura", "-1000 aura"), aura farming, 6-7 (Dictionary.com's 2025 word of the year), sigma, rizz, mogging, plus fanum tax, Ohio and unc. Nova, nicknamed "Aura", is the recurring Gen Alpha regular.

## Estimates to know about
- Gen Z counter-service tip rate (14%) is not published in the sources I found. I scaled the boomer figure (26%) by the Gen Z/boomer sit-down ratio (45/84).
- `tip_pct` for counter service is a modeled estimate scaled from the sit-down 20%+ shares.
- `tag_fit` multipliers are directional estimates from the qualitative findings, not measured values.
- I read these numbers from search-result summaries, not the original studies. Verify before quoting them publicly.

## Treat preferences
Which generation likes which treat (`gen_fit` in `data/treats.json`) is a **design estimate**, not survey data: muffins and cookies skew older, cupcakes and brownies skew younger, protein balls skew millennial. Pairings (`pairs_with`) are also design choices. Treat prices follow the same CPI scaling as drinks.

## Language
Each generation, and each named character, speaks in their own era's slang (`data/dialogue.json`, `data/characters.json`). Slang lives entirely in data files so it's easy to refresh as it ages.

## Sources
- Tipping by generation (counter service, sit-down, 20%+ shares): [Fox News on a millennial tipping survey](https://www.foxnews.com/food-drink/millennials-are-the-worst-tippers-new-survey-shows.amp), [Newsweek](https://www.newsweek.com/millennials-are-the-most-anti-tipping-generation-11915915), and [Fox 9 on the 2025 annual tipping poll](https://www.fox9.com/news/tipping-out-of-control-survey-2025)
- Beverage-only purchase frequency: [Restaurant Dive on NRA beverage research](https://www.restaurantdive.com/news/nra-dirty-soda-coffee-beverage-only-gen-z-occasions/828942/)
- Coffee habits by generation: [Coffee BI](https://coffeebi.com/?p=295401), [GlobalData](https://www.globaldata.com/media/consumer/rtd-iced-coffee-demand-driven-millennials-gen-z-third-say-high-coffee-spenders-says-globaldata-2/)
- Gen Alpha spending: [eMarketer](https://www.emarketer.com/content/gen-alpha-reshaping-household-spending-habits), [Franchising.com on $28B purchasing power](https://australia.franchising.com/articles/20251022_gen_alpha_purchasing_power_tops_28_billion.html), [PwC Generation Alpha Survey 2026](https://www.pwc.com/us/en/industries/consumer-markets/library/gen-alpha-survey-report.html)
- Gen Alpha slang: [Mental Floss, top Gen Alpha slang 2026](https://www.mentalfloss.com/language/slang/top-gen-alpha-slang-2026), [Euronews, most-searched Gen Alpha slang of 2026](https://www.euronews.com/2026/09/28/from-chud-to-bop-most-searched-gen-alpha-slang-terms-of-2026-so-far-revealed)
- Generational language: [UCLA Languaged Life](https://languagedlife.ucla.edu/sociolinguistics/from-slay-to-on-fleek-linguistic-features-of-millennial-and-gen-z-internet-communication/)
