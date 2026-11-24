-- ============================================
-- whip_casino — the config, one section per game
-- ============================================
-- Each section is that game's own Config (blackjack's Config.Money is not roulette's). The sections are as each
-- game had them on its own; only the money's currency is shared in practice: the chips, made in Blackjack's section.

-- ############################################################################################################
-- BLACKJACK (AND THE CHIPS, AND THE CASHIER)
-- ############################################################################################################
do local _ENV = CasinoGame('blackjack')

Config = {}

-- ============================================
-- Money
-- ============================================
-- Bets are taken with whip's ChargePlayer and paid with PayPlayer, so every one is on the activity log.
--   method:   'cash', 'bank' or 'auto' (cash if they carry enough, else the bank)
--   currency: an item that counts as money instead of cash, e.g. 'casino_chips' once there's a cashier. nil = cash.
Config.Money = {
    method   = 'cash',
    currency = 'casino_chips',   -- bets are in chips, bought at the cashier. nil: plain cash instead
}

-- The chips: an item this resource registers (its picture is casinochips.png here).
Config.ChipItem = {
    key  = 'casino_chips',
    name = 'Casino Chips',
    desc = 'One chip, one dollar. Cash them in at the casino cashier.',
}

-- ============================================
-- The cashier
-- ============================================
-- Placed with /bjcashier (dev: a ghost of the cashier to put where they stand), kept in cashiers.json.
-- /bjcashierremove takes away the one nearest you.
Config.Cashier = {
    model     = 'u_f_m_casinocash_01',
    label     = 'Casino Cashier',
    buyPrice  = 1.0,       -- dollars for one chip
    sellPrice = 1.0,       -- dollars back for one chip
    payWith   = 'auto',    -- buying chips: 'cash', 'bank' or 'auto' (cash if they carry enough, else the bank)
    payOut    = 'cash',    -- cashing chips in: 'cash' or 'bank'
    min       = 10,        -- chips in one go
    max       = 1000000,
    reach     = 2.5,       -- metres from the cashier to buy or sell
    -- What a cashier does where they're placed: chosen in /bjcashier, with a live preview to set the height (a seat).
    -- scenario: a GTA scenario played at the spot (seat = true for the sitting ones). Neither: just stands.
    poses = {
        { id = 'stand',  label = 'Standing' },
        { id = 'stool',  label = 'Sitting on a stool',    scenario = 'PROP_HUMAN_SEAT_BAR',             seat = true },
        { id = 'chair',  label = 'Sitting on a chair',    scenario = 'PROP_HUMAN_SEAT_CHAIR_UPRIGHT',   seat = true },
        { id = 'lean',   label = 'Leaning on the counter', scenario = 'PROP_HUMAN_BUM_SHOPPING_CART' },
        { id = 'wait',   label = 'Waiting, hands folded', scenario = 'WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT' },
        { id = 'phone',  label = 'On the phone',          scenario = 'WORLD_HUMAN_STAND_MOBILE_UPRIGHT' },
    },
}

-- ============================================
-- The rules
-- ============================================
Config.Rules = {
    decks             = 6,      -- in the shoe
    penetration       = 0.75,   -- how much of the shoe is dealt before it's shuffled again
    shuffleEveryRound = false,  -- true: a fresh shoe every round (no counting at all)
    hitSoft17         = false,  -- false: the dealer stands on every 17
    blackjackPays     = 1.5,    -- 3:2. A natural only: 21 on two cards, not after a split
    insurance         = true,   -- offered when the dealer shows an ace (costs half the bet, pays 2:1)
    surrender         = true,   -- late surrender: half the bet back, first two cards only, not after a split
    doubleAfterSplit  = true,
    splitAcesOneCard  = true,   -- split aces get one card each, and that's it
    -- One split per player (two hands): the table's own animations have places for two.
}

-- ============================================
-- Timing (seconds unless it says ms)
-- ============================================
Config.Timing = {
    betSeconds       = 15,   -- the betting window, from the first bet
    allInSeconds     = 3,    -- once everyone seated has bet, the window shrinks to this
    turnSeconds      = 20,   -- to decide on a hand; time out and you stand
    insuranceSeconds = 8,
    dealMs           = 2300, -- between cards: the dealer's deal animation plays out before the next
}

-- ============================================
-- Tables
-- ============================================
-- coords is the table's origin (on the floor), heading which way it faces.
-- spawn = true: we place the table. false: it's already in the map (an MLO's own table), and we find it there.
-- model: 'vw_prop_casino_blckjack_01' (normal) or 'vw_prop_casino_blckjack_01b' (high limit).
-- texture: the felt, 0 green, 1 red, 2 blue, 3 purple.
-- min / max: bet limits. step: how much the arrows change your bet (default the min).
-- /bjhere (dev) prints a line for where you stand.
--
-- These are k4mb1-casino's own tables, read out of its map files (stream/casino2/k4mb1_casino2.ytyp, placed by
-- k4mb1_casino2_milo_.ymap; the penthouse's from vw_vwdlc_int_02.ytyp). spawn = false: the map has them, we find
-- them. No texture: the felt stays as the map made it.
Config.Tables = {
    -- The main floor (casino2)
    { label = 'Blackjack',            coords = vec3(1001.859, 61.971, 79.993), heading = 58.0,  model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 100,  max = 5000 },
    { label = 'Blackjack',            coords = vec3(996.231, 52.963, 79.993),  heading = 58.0,  model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 100,  max = 5000 },
    { label = 'Blackjack',            coords = vec3(958.045, 67.729, 80.002),  heading = 58.0,  model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 100,  max = 5000 },
    { label = 'Blackjack',            coords = vec3(947.809, 65.060, 79.989),  heading = 58.0,  model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 100,  max = 5000 },
    { label = 'Blackjack',            coords = vec3(962.055, 32.245, 79.991),  heading = 328.0, model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 100,  max = 5000 },
    { label = 'High Limit Blackjack', coords = vec3(942.256, 43.203, 79.985),  heading = 328.0, model = 'vw_prop_casino_blckjack_01b', spawn = false, min = 2000, max = 50000, step = 1000 },
    { label = 'High Limit Blackjack', coords = vec3(999.104, 57.561, 79.993),  heading = 58.0,  model = 'vw_prop_casino_blckjack_01b', spawn = false, min = 2000, max = 50000, step = 1000 },
    -- The penthouse lounge (its Blackjack entity set, k4mb1_apart_lounge_room_01, is on in k4mb1's client2.lua)
    { label = 'Penthouse Blackjack',  coords = vec3(967.315, 32.215, 115.172), heading = 238.0, model = 'vw_prop_casino_blckjack_01',  spawn = false, min = 1000, max = 25000, step = 500 },
}

-- The dealer's animations number the seats their own way: [our seat] = the animation's seat. Our seats are the
-- table's chairs (Chair_Base_01-04, and "Seat N" in /bjedit); the animations count them from the other end.
-- If the dealer turns to the wrong chair, change this: { 1, 2, 3, 4 } is the same numbering, { 4, 3, 2, 1 } mirrored.
Config.AnimSeats = { 4, 3, 2, 1 }

-- The dealers: each restart, every table gets one of these at random, with its own face and hair (every player
-- sees the same one). female = true uses the female dealer moves where the game has them.
Config.Dealers = {
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_LATINO_01' },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_ASIAN_01',  female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_LATINA_01', female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_WHITE_01',  female = true },
}

-- ============================================
-- Where things go on the felt
-- ============================================
-- Worked out from the table's own chair bones, so it fits however the table is turned. All in metres, in the
-- table's own frame. If cards or chips land off their printed spots, tune here: /bjlayout (dev) draws every spot.
Config.Layout = {
    centre       = vec2(0.0, 0.0),  -- the middle of the felt, from the table's origin
    surface      = 0.95,            -- the felt's height above the origin
    cardAt       = 0.40,            -- a seat's cards: this far from the middle towards its chair (0 middle, 1 chair)
    chipAt       = 0.52,            -- a seat's chips: the same, on the printed diamond
    cardSpread   = 0.045,           -- each extra card steps sideways this much
    splitGap     = 0.10,            -- a split's two hands sit this far apart, either side
    dealerStand  = 0.82,            -- the dealer stands this far behind the middle
    dealerLift   = 1.0,             -- the dealer's hips above the floor (a ped stands on its hips' height)
    dealerCardAt = 0.15,            -- the dealer's cards: this far from the middle towards the dealer
    chipHeight   = 0.0072,          -- one chip's thickness, for stacking
    seatTurn     = 0.0,             -- degrees: turn a seated player if the chairs face off

    -- Cards and chips land where the animations put them, and each game remembers it (/bjforget clears it).
    -- These numbers above are only used until a spot has been seen once.
    dealerHand   = 28422,           -- the hand the dealer deals with (28422 right, 60309 left)
    playerHand   = 28422,           -- the hand a player puts chips down with
    grabPhase    = 0.12,            -- how far into a deal the card is in the dealer's hand (0-1)
    dropBand     = 0.10,            -- a hand this close above the felt is putting something down
    seatChairs   = nil,             -- { 4, 3, 2, 1 }: which chair each of the dealer's seats is, if you know.
                                    -- nil: learnt from the first card dealt to each seat.
}

-- Chips on the felt for a bet: the biggest that fit, stacked. Value -> model.
Config.Chips = {
    { 10000, 'vw_prop_chip_10kdollar_x1' },
    { 5000,  'vw_prop_chip_5kdollar_x1' },
    { 1000,  'vw_prop_chip_1kdollar_x1' },
    { 500,   'vw_prop_chip_500dollar_x1' },
    { 100,   'vw_prop_chip_100dollar_x1' },
    { 50,    'vw_prop_chip_50dollar_x1' },
    { 10,    'vw_prop_chip_10dollar_x1' },
}

-- ============================================
-- At the table
-- ============================================
-- The camera over your shoulder while seated (C turns it on and off).
Config.Camera = {
    enabled = true,
    back    = 0.55,  -- behind the chair
    up      = 1.45,  -- above the floor
    fov     = 55.0,
}

-- Keys: GTA control ids, keyboard and pad. Shown on screen with whip's key hints.
Config.Keys = {
    up        = { key = 172, pad = 188, text = 'Up',        button = 'dpad_up' },
    down      = { key = 173, pad = 187, text = 'Down',      button = 'dpad_down' },
    min       = { key = 174, pad = 189, text = 'Left',      button = 'dpad_left' },
    max       = { key = 175, pad = 190, text = 'Right',     button = 'dpad_right' },
    accept    = { key = 191, pad = 201, text = 'Enter',     button = 'a' },        -- bet, hit, take insurance
    stand     = { key = 22,  pad = 203, text = 'Space',     button = 'x' },        -- stand, no insurance
    double    = { key = 45,  pad = 204, text = 'R',         button = 'y' },
    split     = { key = 38,  pad = 206, text = 'E',         button = 'rb' },
    surrender = { key = 23,  pad = 189, text = 'F',         button = 'dpad_left' },
    camera    = { key = 26,  pad = 217, text = 'C',         button = 'view' },
    -- 194 is Backspace alone (177 is Backspace, right mouse and Esc all at once).
    leave     = { key = 194, pad = 202, text = 'Backspace', button = 'b' },        -- take your bet back, or get up
}

-- How far away a table and its game are drawn, and news of it sent.
Config.DrawRange = 45.0
Config.SyncRange = 60.0

-- Getting up: more than this far from your chair (a shove, a teleport) and you've left.
Config.LeaveDistance = 3.5

end

-- ############################################################################################################
-- THREE CARD POKER
-- ############################################################################################################
do local _ENV = CasinoGame('threecard')

Config = {}

-- ============================================
-- Money
-- ============================================
-- Bets are taken with whip's ChargePlayer and paid with PayPlayer, so every one is on the activity log.
--   method:   'cash', 'bank' or 'auto' (cash if they carry enough, else the bank)
--   currency: an item that counts as money instead of cash. 'casino_chips' is the chips item (Blackjack's section), bought
--             and cashed in at the cashier. nil = plain cash.
Config.Money = {
    method   = 'cash',
    currency = 'casino_chips',
}

-- ============================================
-- The rules
-- ============================================
-- You put down an Ante (and, if you like, a Pair Plus). You see your three cards, then Play (a second bet the
-- size of the Ante) or Fold (the Ante is lost). The dealer needs a Queen high or better to qualify.
--   Dealer doesn't qualify: the Ante pays 1:1, the Play bet comes back.
--   Dealer qualifies:        the better hand wins Ante and Play at 1:1 each; a tie gives both back.
-- Hands, best first: straight flush, three of a kind, straight, flush, pair, high card. A-2-3 is the lowest straight.
Config.Rules = {
    qualifyHigh = 12,   -- the dealer qualifies with this high card or better (12 Queen, 13 King, 14 Ace)
    -- Ante Bonus: paid on the Ante for a hand you played, whatever the dealer has. x times the Ante.
    anteBonus = { straightFlush = 5, three = 4, straight = 1 },
    -- Pair Plus: on your own hand alone (played or folded, whatever the dealer has). x to 1.
    pairPlus  = { straightFlush = 40, three = 30, straight = 6, flush = 4, pair = 1 },
    pairPlusMax = nil,  -- the most a Pair Plus can be. nil: the table's max
}

-- ============================================
-- Timing (seconds, or ms where it says)
-- ============================================
-- The ms ones are how long the dealer's animations take: the server waits them out before the next.
Config.Timing = {
    betSeconds    = 20,     -- the betting window, from the first Ante
    allInSeconds  = 6,      -- once everyone seated has an Ante down, the window shrinks to this (time for Pair Plus)
    decideSeconds = 30,     -- to Play or Fold; time out and you fold
    pickUpMs      = 1800,   -- the dealer picks up the deck
    shuffleMs     = 3000,
    dealSeatMs    = 2800,   -- three cards to one seat
    dealSelfMs    = 3200,   -- three to the dealer
    playerMoveMs  = 2200,   -- a player's play or fold
    flipMs        = 900,    -- into a reveal, when the cards turn over
    revealSelfMs  = 2800,
    revealSeatMs  = 2800,
    collectMs     = 1700,   -- the dealer takes one seat's cards and chips
    putDownMs     = 1500,
}

-- ============================================
-- Tables
-- ============================================
-- coords is the table's origin (on the floor), heading which way it faces.
-- spawn = true: we place the table. false: it's already in the map (an MLO's own table), and we find it there.
-- model: 'vw_prop_casino_3cardpoker_01' or 'vw_prop_casino_3cardpoker_01b'. Both are GTA's own three card poker
--        table, felt printed for it (Ante, Play, Pair Plus).
-- texture: the felt, 0 green, 1 red, 2 blue, 3 purple. Leave it out to keep the map's.
-- min / max: bet limits. step: how much the arrows change your bet (default the min).
--
-- These are k4mb1-casino's own tables, read out of its map files (stream/casino2/k4mb1_casino2.ytyp; the
-- penthouse's from vw_vwdlc_int_02.ytyp). The penthouse one is in k4mb1's lounge entity set 04 (Three Card Poker),
-- which k4mb1's client2.lua leaves off (set 01, Blackjack, is on): turn 04 on there for it to appear.
Config.Tables = {
    -- The main floor
    { label = 'Three Card Poker',            coords = vec3(994.685, 66.706, 79.981), heading = 238.0, model = 'vw_prop_casino_3cardpoker_01',  spawn = false, min = 50,   max = 2500 },
    { label = 'Three Card Poker',            coords = vec3(991.848, 62.165, 79.981), heading = 238.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 50,   max = 2500 },
    { label = 'Three Card Poker',            coords = vec3(988.997, 57.600, 79.981), heading = 238.0, model = 'vw_prop_casino_3cardpoker_01',  spawn = false, min = 50,   max = 2500 },
    { label = 'Three Card Poker',            coords = vec3(985.126, 77.554, 79.991), heading = 328.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 50,   max = 2500 },
    { label = 'Three Card Poker',            coords = vec3(988.979, 75.723, 79.991), heading = 328.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 50,   max = 2500 },
    { label = 'Three Card Poker',            coords = vec3(992.494, 72.990, 79.991), heading = 328.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 50,   max = 2500 },
    -- The high limit room, beside its blackjack table
    { label = 'High Limit Three Card Poker', coords = vec3(937.543, 35.661, 79.986), heading = 148.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 1000, max = 25000, step = 500 },
    -- The penthouse lounge (entity set k4mb1_apart_lounge_room_04, see above)
    { label = 'Penthouse Three Card Poker',  coords = vec3(967.314, 32.215, 115.172), heading = 238.0, model = 'vw_prop_casino_3cardpoker_01b', spawn = false, min = 1000, max = 25000, step = 500 },
}

-- The dealer's animations number the seats their own way (deck_deal_p01-p04): [our seat] = the animation's seat.
-- Our seats are the table's chairs (Chair_Base_01-04, "Seat N" in /tcpedit). If the dealer turns to the wrong
-- chair, change this: { 1, 2, 3, 4 } is the same numbering, { 4, 3, 2, 1 } mirrored (blackjack's tables are mirrored).
Config.AnimSeats = { 4, 3, 2, 1 }

-- The dealers: each restart, every table gets one of these at random, with its own face and hair (every player
-- sees the same one). female = true uses the female dealer moves where the game has them.
Config.Dealers = {
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_LATINO_01' },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_ASIAN_01',  female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_LATINA_01', female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_WHITE_01',  female = true },
}

-- ============================================
-- Where things go on the felt
-- ============================================
-- Only until /tcpedit has set them: the editor's layout (layout.json) wins over all of this. Worked out from the
-- table's chair bones, in metres in the table's own frame.
Config.Layout = {
    centre       = vec2(0.0, 0.0),  -- the middle of the felt, from the table's origin
    surface      = 0.95,            -- the felt's height above the origin
    cardAt       = 0.38,            -- a seat's cards: this far from the middle towards its chair (0 middle, 1 chair)
    cardSpread   = 0.07,            -- between a hand's three cards
    -- A seat's three betting spots: { towards the chair (0-1), sideways (metres) }.
    chips = {
        ante = { 0.52, -0.06 },
        play = { 0.52,  0.06 },
        plus = { 0.64,  0.0 },
    },
    dealerStand  = 0.82,            -- the dealer stands this far behind the middle
    dealerLift   = 1.0,             -- the dealer's hips above the floor (a ped stands on its hips' height)
    dealerCardAt = 0.18,            -- the dealer's cards: this far from the middle towards the dealer
    chipHeight   = 0.0072,          -- one chip's thickness, for stacking
    seatTurn     = 0.0,             -- degrees: turn a seated player if the chairs face off
    -- Cards ride in the dealer's hand as he deals, and go down to their spots when it reaches the felt.
    dealerHand   = 28422,           -- the hand the dealer deals with (28422 right, 60309 left)
    playerHand   = 28422,           -- the hand a player puts chips down with
    grabPhase    = 0.12,            -- how far into a deal the cards are in the dealer's hand (0-1)
    dropBand     = 0.10,            -- a hand this close above the felt is putting something down

    -- The deck: lies on the felt, and is in the dealer's hand from deck_pick_up to deck_put_down.
    -- Both are set in /tcpedit ("Dealer: the deck on the table", "Dealer: the deck in his hand").
    deckModel     = 'vw_prop_casino_cards_01',
    deckAt        = 0.30,           -- on the felt: this far from the middle towards the dealer
    deckSide      = 0.28,           --              and this far to one side
    deckHand      = 60309,          -- the hand holding it (60309 left, 28422 right)
    deckHold      = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },   -- in the hand: x, y, z, then turn x, y, z (degrees)
    deckPickPhase = 0.40,           -- how far into deck_pick_up the hand has it (0-1)
    deckPutPhase  = 0.60,           -- how far into deck_put_down it's let go
}

-- Chips on the felt for a bet: the biggest that fit, stacked. Value -> model.
Config.Chips = {
    { 10000, 'vw_prop_chip_10kdollar_x1' },
    { 5000,  'vw_prop_chip_5kdollar_x1' },
    { 1000,  'vw_prop_chip_1kdollar_x1' },
    { 500,   'vw_prop_chip_500dollar_x1' },
    { 100,   'vw_prop_chip_100dollar_x1' },
    { 50,    'vw_prop_chip_50dollar_x1' },
    { 10,    'vw_prop_chip_10dollar_x1' },
}

-- ============================================
-- At the table
-- ============================================
-- The camera over your shoulder while seated (C turns it on and off; V is GTA's views, first person among them).
Config.Camera = {
    enabled = true,
    back    = 0.55,  -- behind the chair
    up      = 1.45,  -- above the floor
    fov     = 55.0,
}

-- Keys: GTA control ids, keyboard and pad. Shown on screen with whip's key hints.
Config.Keys = {
    up     = { key = 172, pad = 188, text = 'Up',        button = 'dpad_up' },
    down   = { key = 173, pad = 187, text = 'Down',      button = 'dpad_down' },
    min    = { key = 174, pad = 189, text = 'Left',      button = 'dpad_left' },
    max    = { key = 175, pad = 190, text = 'Right',     button = 'dpad_right' },
    accept = { key = 191, pad = 201, text = 'Enter',     button = 'a' },     -- Ante, Pair Plus, Play
    fold   = { key = 22,  pad = 203, text = 'Space',     button = 'x' },     -- Fold
    camera = { key = 26,  pad = 217, text = 'C',         button = 'view' },
    -- 194 is Backspace alone (177 is Backspace, right mouse and Esc all at once).
    leave  = { key = 194, pad = 202, text = 'Backspace', button = 'b' },     -- take your bets back, or get up
}

-- How far away a table and its game are drawn, and news of it sent.
Config.DrawRange = 45.0
Config.SyncRange = 60.0

-- Getting up: more than this far from your chair (a shove, a teleport) and you've left.
Config.LeaveDistance = 3.5

end

-- ############################################################################################################
-- ROULETTE
-- ############################################################################################################
do local _ENV = CasinoGame('roulette')

Config = {}

-- ============================================
-- Money
-- ============================================
-- Bets are taken with whip's ChargePlayer and paid with PayPlayer, so every one is on the activity log.
--   method:   'cash', 'bank' or 'auto' (cash if they carry enough, else the bank)
--   currency: an item that counts as money instead of cash. 'casino_chips' is the chips item (Blackjack's section), bought
--             and cashed in at the cashier. nil = plain cash.
Config.Money = {
    method   = 'cash',
    currency = 'casino_chips',
}

-- ============================================
-- The wheel
-- ============================================
-- GTA's roulette is American: 0 and 00. Its ball animations end in one of 38 pockets (exit_1_ball ... exit_38_ball);
-- this is the number each pocket is, round the wheel. /rlspin <1-38> (dev) spins one so you can check: if the
-- ball stops on another number, this is the list to fix.
-- Checked in game: with ballTurn 4.74, exit_1 drops in 18, exit_2 in 6, and on round the wheel.
Config.Pockets = {
    '18', '6', '21', '33', '16', '4', '23', '35', '14', '2', '0', '28', '9', '26', '30', '11', '7', '20', '32',
    '17', '5', '22', '34', '15', '3', '24', '36', '13', '1', '00', '27', '10', '25', '29', '12', '8', '19', '31',
}

-- What each bet pays, to 1.
Config.Payouts = {
    straight = 35,  -- one number
    split    = 17,  -- two side by side
    street   = 11,  -- a row of three
    corner   = 8,   -- four that meet
    basket   = 6,   -- 0, 00, 1, 2, 3
    sixline  = 5,   -- two rows of three
    column   = 2,   -- "2 to 1"
    dozen    = 2,   -- 1st, 2nd, 3rd 12
    even     = 1,   -- red / black, odd / even, 1-18 / 19-36
}

-- The chips you pick from on the board (only those within the table's limits are offered).
Config.ChipValues = { 10, 50, 100, 500, 1000, 5000, 10000 }

-- ============================================
-- Timing (seconds, or ms where it says)
-- ============================================
Config.Timing = {
    betSeconds = 25,     -- the betting window, from the first chip down
    -- The spin, as each game plays it: the dealer's spin, the ball going in, round loops times, then dropping.
    spinStartMs = 1500,  -- into the dealer's spin, when the ball goes in
    loops       = 3,
    -- The server holds the result until the ball is at rest: the seated players' games tell it how long their spin
    -- runs. This is only used if none does.
    spinMs      = 22000,
    clearMs     = 3500,  -- the dealer sweeps the chips
}

-- ============================================
-- Tables
-- ============================================
-- coords is the table's origin (on the floor), heading which way it faces.
-- spawn = true: we place the table. false: it's already in the map (an MLO's own table), and we find it there.
-- model: 'vw_prop_casino_roulette_01' or 'vw_prop_casino_roulette_01b'.
-- texture: the felt, 0 green, 1 red, 2 blue, 3 purple. Leave it out to keep the map's.
-- min / max: for one bet (one spot on the board). maxTotal: all of one player's bets on one spin (default 10 x max).
--
-- These are k4mb1-casino's own tables, read out of its map files (stream/casino2/k4mb1_casino2.ytyp; the
-- penthouse's from vw_vwdlc_int_02.ytyp). The penthouse one is in k4mb1's lounge entity set 05 (Roulette), which
-- k4mb1's client2.lua leaves off (set 01, Blackjack, is on): turn 05 on there for it to appear.
Config.Tables = {
    -- The main floor
    { label = 'Roulette',            coords = vec3(997.985, 64.196, 79.993), heading = 238.0, model = 'vw_prop_casino_roulette_01b', spawn = false, min = 10,  max = 2500 },
    { label = 'Roulette',            coords = vec3(995.150, 59.660, 79.993), heading = 238.0, model = 'vw_prop_casino_roulette_01',  spawn = false, min = 10,  max = 2500 },
    { label = 'Roulette',            coords = vec3(992.331, 55.148, 79.993), heading = 238.0, model = 'vw_prop_casino_roulette_01b', spawn = false, min = 10,  max = 2500 },
    { label = 'Roulette',            coords = vec3(979.283, 53.806, 79.999), heading = 328.0, model = 'vw_prop_casino_roulette_01b', spawn = false, min = 10,  max = 2500 },
    { label = 'Roulette',            coords = vec3(973.683, 57.305, 79.999), heading = 328.0, model = 'vw_prop_casino_roulette_01b', spawn = false, min = 10,  max = 2500 },
    -- The high limit room
    { label = 'High Limit Roulette', coords = vec3(939.290, 39.517, 80.000), heading = 328.0, model = 'vw_prop_casino_roulette_01b', spawn = false, min = 500, max = 25000 },
    -- The penthouse lounge (entity set k4mb1_apart_lounge_room_05, see above)
    { label = 'Penthouse Roulette',  coords = vec3(967.314, 32.215, 115.172), heading = 58.0, model = 'vw_prop_casino_roulette_01',  spawn = false, min = 500, max = 25000 },
}

-- The dealers: each restart, every table gets one of these at random, with its own face and hair (every player
-- sees the same one). female = true uses the female dealer moves where the game has them.
Config.Dealers = {
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_WHITE_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_01' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_ASIAN_02' },
    { model = 's_m_y_casino_01', voice = 'S_M_Y_CASINO_01_LATINO_01' },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_ASIAN_01',  female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_LATINA_01', female = true },
    { model = 's_f_y_casino_01', voice = 'S_F_Y_CASINO_01_WHITE_01',  female = true },
}

-- ============================================
-- Where things go
-- ============================================
-- Only until /rledit has set them: the editor's layout (layout.json) wins. In metres, in the table's own frame.
Config.Layout = {
    surface     = 0.95,   -- the felt's height above the origin
    dealerStand = 0.82,   -- the dealer stands this far behind the middle of the chairs' arc
    dealerLift  = 1.0,    -- the dealer's hips above the floor
    -- The betting board on the felt, by where the middles of three of its numbers are. /rledit sets these, and the
    -- middles of "1st 12" and "1 to 18" (which say how deep the two strips below the numbers are).
    board = {
        n1  = vec3(-0.30, -0.10, 0.95),
        n3  = vec3(-0.30,  0.14, 0.95),
        n34 = vec3( 0.70, -0.10, 0.95),
        dozenRows = 0.55,   -- until /rledit sets them: the dozens strip, as deep as this many number rows
        evenRows  = 0.55,   --                          the 1-18 / Even / Red ... strip
    },
    chipHeight = 0.0072,  -- one chip's thickness, for stacking
    seatTurn   = 0.0,     -- degrees: turn a seated player if the chairs face off
    ballTurn   = 4.74,    -- degrees: the ball's path round the wheel (half a pocket: it drops into pockets, not on the frets)
    ballBone   = 'Roulette_Wheel',   -- the table's wheel bone, where the ball starts
}

-- Chips on the felt for a bet: the biggest that fit, stacked. Value -> model.
Config.Chips = {
    { 10000, 'vw_prop_chip_10kdollar_x1' },
    { 5000,  'vw_prop_chip_5kdollar_x1' },
    { 1000,  'vw_prop_chip_1kdollar_x1' },
    { 500,   'vw_prop_chip_500dollar_x1' },
    { 100,   'vw_prop_chip_100dollar_x1' },
    { 50,    'vw_prop_chip_50dollar_x1' },
    { 10,    'vw_prop_chip_10dollar_x1' },
}

-- ============================================
-- At the table
-- ============================================
-- The camera over your shoulder while seated (C turns it on and off; V is GTA's views, first person among them).
Config.Camera = {
    enabled = true,
    back    = 0.55,
    up      = 1.45,
    fov     = 55.0,
}

-- Putting chips down (Enter): the camera nearly straight down over the board, squared up with it.
Config.BetCamera = {
    back = 0.20,   -- back from the middle of the board, towards the dozens (a touch of slope, so it reads as a table)
    up   = 1.25,   -- above the felt: higher shows more of the board
    fov  = 50.0,
}

-- Watching the wheel (E while seated): the camera over the wheel, looking down into it from the board's side.
Config.WheelCamera = {
    auto = true,   -- switch to it by itself when the spin starts, and back once the felt is cleared
    back = 0.40,   -- from the wheel towards the board
    up   = 0.80,   -- above the wheel
    fov  = 45.0,
}

-- Keys while seated. Putting chips down is the mouse: see the README.
Config.Keys = {
    wheel  = { key = 38,  pad = 205, text = 'E',         button = 'lb' },    -- watch the wheel, or back
    board  = { key = 191, pad = 201, text = 'Enter',     button = 'a' },     -- put chips down
    camera = { key = 26,  pad = 217, text = 'C',         button = 'view' },
    -- 194 is Backspace alone (177 is Backspace, right mouse and Esc all at once).
    leave  = { key = 194, pad = 202, text = 'Backspace', button = 'b' },
}

Config.DrawRange = 45.0
Config.SyncRange = 60.0
Config.LeaveDistance = 3.5

end

-- ############################################################################################################
-- LUCKY WHEEL
-- ############################################################################################################
do local _ENV = CasinoGame('luckywheel')

Config = {}

-- ============================================
-- Money
-- ============================================
-- Chip prizes and the spin's cost (if any) are in this currency: 'casino_chips' is the chips item (Blackjack's section),
-- cashed in at the cashier. nil = plain cash. Cash prizes are always cash.
Config.Money = {
    method   = 'cash',
    currency = 'casino_chips',
}

-- ============================================
-- The spin
-- ============================================
--   cost:          what a spin costs, in Config.Money's currency. 0 = free, as in GTA.
--   cooldownHours: how long a character waits between spins (kept with the character, so it survives restarts
--                  and relogs). 0 = no wait.
Config.Spin = {
    cost          = 0,
    cooldownHours = 0,
}

-- ============================================
-- The wheel
-- ============================================
-- base: the wheel's stand, already in the map (k4mb1 has it in entity set k4_luckywheel2). We find it there and put
-- GTA's wheel (vw_prop_vw_luckywheel_02a, the part that turns) on it, offset from the stand as in GTA's casino.
-- spawnBase = true places the stand too, at coords / heading, for a casino without one.
Config.Wheel = {
    base        = 'vw_prop_vw_luckywheel_01a',
    wheel       = 'vw_prop_vw_luckywheel_02a',
    coords      = vec3(964.640, 49.320, 80.557),   -- k4mb1's stand, read out of k4mb1_casino2.ytyp
    heading     = 238.0,                           -- only used with spawnBase
    spawnBase   = false,
    wheelOffset = vec3(0.0, 0.0087, 1.5079),       -- the wheel's middle, from the stand
    -- Degrees: turns the wheel's print against where it stops. /lwspin <segment> (dev) spins one in your game: if
    -- the pointer stops between two prizes, or on the one next door, this is what to change (18 is one segment).
    turn        = 0.0,
    -- GTA's lucky wheel moves are played from the stand's origin. If you stand off the handle, nudge them:
    -- metres in the stand's own frame (x right, y away from the wheel... -y is towards you), and degrees.
    standOffset = vec3(0.0, 0.0, 0.0),
    standTurn   = 0.0,
}

-- ============================================
-- The prizes, round the wheel
-- ============================================
-- The wheel has 20 segments, and this is each one in order, as the wheel is printed (segment 1 is where the wheel
-- starts). /lwspin <1-20> (dev) checks one: it says what this list expects, and the wheel stops on what's printed.
--
-- label:  what the player is told they won
-- weight: how likely, against the others (they needn't add up to anything)
-- prize:  { type = 'chips', amount }      Config.Money.currency (casino chips)
--         { type = 'cash', amount }       cash in hand
--         { type = 'item', item, amount } any registered item
--         { type = 'vehicle', model }     a car of their own, in their garage with its key (shown on the podium)
--         { type = 'mystery' }            one of Config.Mystery, drawn by its weights
--         { type = 'nothing' }
--
-- The print is a texture in k4mb1's map (stream/extra/vw_prop_vw_luckywheel.ytd, prop_luckywheel_decal_d): this list
-- can't change what's printed, only what each segment pays. Keep the two matching. Going clockwise from 2,500:
-- the $ segments pay cash, the money bags (printed in euros) cash, the chip stacks chips, DRINKS whip_core's drink.
Config.Segments = {
    { label = '$2,500',             weight = 10,  prize = { type = 'cash',  amount = 2500 } },
    { label = '$20,000',            weight = 3,   prize = { type = 'cash',  amount = 20000 } },
    { label = '10,000 chips',       weight = 5,   prize = { type = 'chips', amount = 10000 } },
    { label = 'Nothing',            weight = 6,   prize = { type = 'nothing' } },
    { label = '$5,000',             weight = 8,   prize = { type = 'cash',  amount = 5000 } },
    { label = '$30,000',            weight = 2,   prize = { type = 'cash',  amount = 30000 } },
    { label = '15,000 chips',       weight = 4,   prize = { type = 'chips', amount = 15000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$7,500',             weight = 6,   prize = { type = 'cash',  amount = 7500 } },
    { label = '20,000 chips',       weight = 3,   prize = { type = 'chips', amount = 20000 } },
    { label = 'a Random prize',     weight = 3,   prize = { type = 'mystery' } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$10,000',            weight = 4,   prize = { type = 'cash',  amount = 10000 } },
    { label = '$40,000',            weight = 1.5, prize = { type = 'cash',  amount = 40000 } },
    { label = '25,000 chips',       weight = 2,   prize = { type = 'chips', amount = 25000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$15,000',            weight = 2,   prize = { type = 'cash',  amount = 15000 } },
    { label = 'the Podium Vehicle', weight = 0.5, prize = { type = 'vehicle', model = 'zentorno' } },
    { label = '$50,000',            weight = 1,   prize = { type = 'cash',  amount = 50000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
}

-- The RANDOM segment draws one of these.
Config.Mystery = {
    { label = '$10,000',      weight = 5, prize = { type = 'cash',  amount = 10000 } },
    { label = '5,000 chips',  weight = 6, prize = { type = 'chips', amount = 5000 } },
    { label = '50,000 chips', weight = 1, prize = { type = 'chips', amount = 50000 } },
    { label = 'nothing',      weight = 2, prize = { type = 'nothing' } },
}

-- A prize worth this much or more gets the big celebration, and huge the biggest (a car always does).
Config.Celebrate = { big = 15000, huge = 40000 }

-- ============================================
-- The podium
-- ============================================
-- The car you can win, turning on the casino's podium (k4mb1's own, read out of its map files). The car is the
-- first 'vehicle' prize in Config.Segments. spin = true turns the podium with it: the map's podium can't move, so a
-- copy goes in its place and the map's is hidden while you're near.
Config.Podium = {
    enabled  = true,
    model    = 'k4mb1_casino2_podium',
    coords   = vec3(970.030, 45.990, 80.515),
    carUp    = 1.07,    -- the car above the podium's origin
    spin     = true,
    perSec   = 6.0,     -- degrees a second
    colours  = nil,     -- { primary, secondary } GTA colour ids; nil = a random one each restart
}

-- ============================================
-- Timing (ms)
-- ============================================
Config.Timing = {
    pullMs  = 700,     -- the arm coming down, before the wheel moves
    spinMs  = 10000,   -- the wheel turning, start to stop
    turns   = 4,       -- whole turns before it slows onto the prize
    holdMs  = 60000,   -- how long someone can stand at the wheel without spinning, before it's let go
}

-- ============================================
-- At the wheel
-- ============================================
-- The camera on the wheel while it turns, from in front of it.
Config.Camera = {
    enabled = true,
    back    = 3.4,   -- in front of the wheel
    up      = 0.0,   -- above its middle
    fov     = 50.0,
}

-- The sounds: GTA's own, from the casino's audio. Set bank = nil for none.
Config.Sounds = {
    bank = 'DLC_VINEWOOD/CASINO_GENERAL',
    set  = 'dlc_vw_casino_lucky_wheel_sounds',
    tick = 'Spin_Single_Ticks',
    win  = 'Win',
}

Config.Keys = {
    spin  = { key = 191, pad = 201, text = 'Enter',     button = 'a' },   -- or left click
    leave = { key = 194, pad = 202, text = 'Backspace', button = 'b' },
}

Config.Reach     = 2.2    -- how close to the wheel the prompt shows
Config.DrawRange = 60.0   -- the wheel and podium car are made within this
Config.SyncRange = 70.0   -- players this close see each spin

end
