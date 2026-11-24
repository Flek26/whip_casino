# Blackjack

Casino blackjack on whip. You sit at a real casino table, and a dealer deals real cards from a shoe. Up to four players share a table. Bets go through whip's money, so every one appears on the activity log.

## How it plays

1. **Sit down.** Walk up to a table and press **E** on *Play Blackjack*. You take the next free chair.
2. **Place your bet.**
   - **↑ / ↓** changes the bet by the table's step.
   - **← / →** jumps to the minimum or maximum.
   - **Enter** places the bet.
   - The first bet opens a 15 second window for everyone at the table. If everyone seated has bet, it closes after 3 seconds.
   - **Backspace** takes your bet back while the window is still open.
3. **The deal.** Each player gets two cards and the dealer gets two, one face down.
   - **Insurance:** when the dealer shows an ace, you can buy insurance (**Enter**) or turn it down (**Space**).
   - **The peek:** with an ace or a ten-value card showing, the dealer checks for blackjack. If the dealer has it, the hand ends there.
4. **Your turn.** The keys:

   | Key | Action |
   | --- | --- |
   | **Enter** | Hit |
   | **Space** | Stand |
   | **R** | Double |
   | **E** | Split |
   | **F** | Surrender |

   You have 20 seconds to decide. If time runs out, you stand.
5. **The dealer** turns the hole card over and draws to 17.
6. **Payouts:**
   - A win pays 1:1.
   - Blackjack pays 3:2.
   - Insurance pays 2:1.
   - A push returns your bet.

**C** toggles the camera over your shoulder. **Backspace** gets up when you have no bet out.

All keys also work on a controller. The prompts at the bottom of the screen show whichever device you're using.

## The rules (Config.Rules)

| Rule | Default |
| --- | --- |
| Decks in the shoe | 6, reshuffled after 75% has been dealt (or every round, with `shuffleEveryRound`) |
| Dealer on soft 17 | Stands (`hitSoft17 = false`) |
| Blackjack pays | 3:2. Only a natural: 21 on the first two cards, and not after a split |
| Insurance | Yes, when the dealer shows an ace. Costs half the bet |
| Surrender | Late surrender, after the peek. First two cards only, not after a split. Half your bet back |
| Double | On any first two cards. Also allowed after a split (`doubleAfterSplit`) |
| Split | Once, into two hands. Split aces get one card each |

## Chips and the cashier

You play with **Casino Chips**, the `casino_chips` item. whip_casino registers it on start, with `casinochips.png` as its picture.

**Buying and cashing in:** a cashier sells chips and buys them back. Walk up and press **E** for *Buy chips* or *Cash in chips*, then type an amount.

| Setting in `Config.Cashier` | Default |
| --- | --- |
| Buying | One chip costs $1, paid from cash or, if you don't carry enough, the bank (`payWith`) |
| Cashing in | Each chip returns $1 as cash (`payOut`) |
| Price per chip | `buyPrice` and `sellPrice` |
| Limits per trade | `min` and `max` |

Every trade goes through whip's ChargePlayer and PayPlayer, so it's on the activity log. If the second half of a trade can't happen (you're short of chips, say, or the payment fails), the first half is refunded.

**Placing cashiers (dev):**
- `/bjcashier`: a ghost of the cashier appears. Drag it to their spot and turn it to face the counter, then place it. Next comes a live preview: **Scroll** picks a pose (standing, a stool, a chair, leaning, waiting, on the phone), and the arrows, **Q/E** and **PgUp/PgDn** set them just so, such as down onto a stool. **Enter** saves. Run it beside a cashier that's already placed to move it or change its pose. Poses are listed in `Config.Cashier.poses`.
- `/bjcashierremove`: removes the nearest cashier.

Cashiers are kept in `blackjack/cashiers.json` and appear for everyone straight away.

## Money

`Config.Money` controls how bets are taken and paid.

- `method`: `'cash'`, `'bank'` or `'auto'`.
- `currency`: the item bets are made in. Default `'casino_chips'`. Set it to `nil` to bet plain cash with no cashier.

Bets are taken with `ChargePlayer` and paid with `PayPlayer`.

- **If the server or resource stops mid-hand**, every stake still on the table is refunded.
- **If a player leaves mid-hand** (gets up, disconnects or dies), their hand stands and is settled with everyone else's. A win is paid to their character even if they're offline. Leaving doesn't get your stake back.

## Tables

`Config.Tables` contains k4mb1-casino's own tables: seven on the main floor (two are high limit) and one in the penthouse lounge. Their positions were read out of the MLO's map files, and `spawn = false` makes the game find each one in the map instead of placing its own. If the map changes, re-read the positions or use `/bjhere`. Each table has these fields:

| Field | What it does |
| --- | --- |
| `coords`, `heading` | The table's origin and the direction it faces |
| `model` | `vw_prop_casino_blckjack_01` (normal) or `vw_prop_casino_blckjack_01b` (high limit) |
| `spawn` | `true` to place the table ourselves. `false` if the map already has one there |
| `texture` | The felt colour: 0 green, 1 red, 2 blue, 3 purple |
| `min`, `max`, `step` | Bet limits, and how much the arrow keys change the bet (`step` defaults to `min`) |

To add a table, use `/bjhere` (dev). It prints a ready config line for where you stand to the server console.

## Setting it up

1. It's part of whip_casino: `ensure whip_casino` after whip_core (see the [main README](../README.md)).
2. If `sf-blackjack` is still running, stop it. Both scripts place tables at the same spots.
3. Sit at a table and run `/bjlayout`. It draws markers on the table:

   | Marker | What it shows |
   | --- | --- |
   | Blue rings | The chairs |
   | White dots | Where each seat's cards land |
   | Yellow dots | Where each seat's chips go |
   | Red ring and dots | Where the dealer stands, and the dealer's cards |

   If anything sits off the printed spots on the felt, nudge `Config.Layout` and restart the resource.

   Card and chip spots don't need tuning by hand. A card rides in the dealer's hand and lands where he puts it down, and chips land where the player's hand drops them. Each game remembers each landing spot for that table model, across restarts. The game also works out which chair each of the dealer's seat animations reaches, and seats players there. The `Config.Layout` numbers only apply until a spot has been seen once. `/bjforget` clears everything the game has learned.

## The layout editor: /bjedit

Stand at a table and run `/bjedit`. A ghost appears for every card, chip stack and split hand, and the dealer stands where he'll stand. Move each one to where it belongs. Saving needs the `whip.devtools` ACE.

| Key | What it does |
| --- | --- |
| **Scroll** | Next or previous item. **Shift + Scroll** jumps a whole seat |
| **Arrows** | Move the item, in the direction you're looking. On "which chair", **Left/Right** picks the chair |
| **Q / E** | Turn the item |
| **PgUp / PgDn** | Raise or lower the item (for the dealer, how high his hips sit) |
| **X** | On a card: whole hand on or off. On, moving, turning or raising one card does the same to all three of that hand, and turning spins them together around their middle |
| **Shift** | Hold for fine movement |
| **G** | Put the item back where it started |
| **Enter** | Save for this table's model |
| **Shift + Enter** | Save for every table model (normal and high limit) |
| **Backspace** | Leave. Press twice if you haven't saved |

The items for each seat:
- Which chair the seat is
- Chips
- Cards 1–3
- Split hand chips
- Split hand cards 1–3

The dealer's items are where he stands and his cards 1–3. Any card after the third follows on from the step between cards 2 and 3.

You can walk around the table while you edit (WASD) to check from every side.

Saving writes `blackjack/layout.json`, in each table's own frame. Every game picks it up at once, with no restart needed. Saved spots always win over learned spots and over the `Config.Layout` numbers. Animations still decide when a card lands, but the layout decides where.

## What's different from sf-blackjack

- **The hole card stays secret.** sf sent every game the dealer's hidden card at the deal, so a modded client could read it. Here no game sees it until the dealer turns it over.
- **No paying a split 21 as blackjack.** sf paid 21 after a split at 3:2. Here it's a plain 21.
- **No skipping the dealer's draw.** sf skipped the dealer's draw when every player had 21. That paid hands that should have pushed. Here the dealer only skips when no hand is left to beat.
- **Insurance, and the peek,** done properly.
- **Any bet within the limits,** not just a fixed list of chip sizes. The chips on the table show the bet in the biggest denominations that fit.
- **A timer on every decision.** A player who goes AFK only holds up the table for the turn timer.
- **The table shows correctly when you walk up mid-hand.**
- **Disconnecting doesn't cancel a losing hand.**
- **One shoe per table,** instead of a fresh three-deck shuffle every round. You can switch back to shuffling every round.

## Not done yet

- **One cashier for every casino game.** Every game in whip_casino bets the same chips, sold at this cashier.
