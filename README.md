# whip_casino

The casino on whip, in one resource: blackjack, three card poker, roulette and the lucky wheel, with the casino chips and the cashier who sells them. It's built for the k4mb1-casino map: the games use its own tables and wheel.

| Game | Folder | Dev commands | More |
| --- | --- | --- | --- |
| **Blackjack**, the chips and the cashier | `blackjack/` | `/bjedit`, `/bjlayout`, `/bjforget`, `/bjhere`, `/bjcashier`, `/bjcashierremove` | [README](blackjack/README.md) |
| **Three Card Poker** | `threecard/` | `/tcpedit` | [README](threecard/README.md) |
| **Roulette** | `roulette/` | `/rledit`, `/rlspin` | [README](roulette/README.md) |
| **Lucky Wheel** | `luckywheel/` | `/lwspin` | [README](luckywheel/README.md) |

## Setting it up

1. Put `whip_casino` in resources and `ensure whip_casino` after whip_core.
2. **Don't run the old resources alongside it:** whip_blackjack, whip_threecard, whip_roulette and whip_luckywheel. They are the same games, and two copies would both put dealers at the tables and both register the chips.
3. Each game's README has its own setup checks (lining up the boards and screens with its editor).

## The config

There's one `config.lua`, with a section per game. Each section is that game's own `Config`, as it was when the game was a resource of its own: `Config.Money` in the Roulette section is roulette's alone. The chips item is set in the Blackjack section (`Config.ChipItem`), and each game's `Config.Money.currency` names it. Set a game's currency to `nil` to bet cash there.

## Where things are saved

- **Saved layouts** (from each game's editor) are in `blackjack/layout.json`, `threecard/layout.json` and `roulette/layout.json`.
- **Cashiers** are in `blackjack/cashiers.json`.
- **Players' state** is in whip's character data, under the same keys as before. That covers chips, the lucky wheel's daily cooldown and cars still owed from it, so nothing is lost moving over.

## How it's put together

- **Separate globals:** each game's Lua files start with `local _ENV = CasinoGame('<game>')` (`shared/env.lua`). Everything a game makes globally (`Config`, `Tables`, `SitDown`...) stays in that game's own table. Natives, `Whip` and `exports` are read through as usual. That's what lets four games that each had a `Config` and a `SitDown` share one resource unchanged.
- **One page:** a resource has one NUI page. `html/index.html` holds each game's own page in a frame, and hands it that game's messages.
- **Event names** are `whip_casino:<game>:...`.
