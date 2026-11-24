local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — server: tables, seats, money, and what each game is told
-- ============================================
--
-- The server deals and decides everything. Games near a table are told what to show (fx), and each seated player
-- what's theirs (hud). The dealer's hole card is never sent to anyone until it's turned over.

Tables = {}   -- [id] = T: { id, def, pos, seats = { [1..4] = P }, phase, shoe, dealer = { cards, hidden }, running, deadline }
BySrc  = {}   -- [source] = P: { src, charId, name, table, seat, bet, receipt, hands, insurance, ask, gone, dropped, result }

local SEATS = 4

local function now() return GetGameTimer() end

for id, def in ipairs(Config.Tables) do
    Tables[id] = {
        id = id, def = def, pos = vector3(def.coords.x, def.coords.y, def.coords.z),
        step = def.step or def.min,
        seats = {}, phase = 'idle', shoe = Shoe.new(),
        -- This table's dealer until the next restart: which of Config.Dealers, and a seed for their face and hair.
        -- Every game builds the same dealer from it.
        look = { pick = math.random(#Config.Dealers), seed = math.random(1, 2147483646) },
        dealer = { cards = {}, hidden = true },
        running = false, deadline = 0,
    }
end

-- ============================================
-- Telling games
-- ============================================

--- News of a table, to the games near it (they draw it): seat, chips, card, reveal, split, clear, dealer, speech.
function Fx(T, kind, data)
    for _, s in ipairs(Whip.core:GetPlayersInRange(T.pos, Config.SyncRange) or {}) do
        TriggerClientEvent('whip_casino:blackjack:fx', s, T.id, kind, data)
    end
end

function Speech(T, line) Fx(T, 'speech', { line = line }) end

function DealerAnim(T, anim, dict) Fx(T, 'dealer', { anim = anim, dict = dict }) end

--- One seated player's panel: their bet, their hands, the dealer's count, what they may do and for how long.
function Hud(P)
    if P.gone or P.dropped then return end
    local T = Tables[P.table]
    local t = now()
    local d = {
        table = T.id, seat = P.seat, label = T.def.label or 'Blackjack',
        min = T.def.min, max = T.def.max, step = T.step,
        phase = T.phase, bet = P.bet, result = P.result, hands = {},
    }
    if P.hands then
        for i, h in ipairs(P.hands) do
            local total, soft = Cards.total(h.cards)
            d.hands[i] = { total = total, soft = soft and total < 21, bet = h.bet, state = h.state,
                natural = Cards.natural(h.cards, h.split) }
        end
    end
    local dc = T.dealer.cards
    if #dc > 0 then
        if T.dealer.hidden then
            d.dealer = dc[2] and tostring(Cards.value(dc[2])) or nil
        else
            local total, soft = Cards.total(dc)
            d.dealer = (soft and total < 21 and 'soft ' or '') .. tostring(total)
        end
    end
    if P.ask then
        d.ask, d.choices, d.active = P.ask.kind, P.ask.allowed, P.ask.hand
        d.endsIn = math.max(0, P.ask.deadline - t)
        d.span = P.ask.span
        d.cost = P.ask.cost
    elseif T.phase == 'betting' then
        d.endsIn = math.max(0, T.deadline - t)
        d.span = T.span
    end
    TriggerClientEvent('whip_casino:blackjack:hud', P.src, d)
end

function HudAll(T)
    for s = 1, SEATS do
        local P = T.seats[s]
        if P then Hud(P) end
    end
end

-- What a game coming near needs to draw the table as it is now. The hole card is false while it's face down.
local function snapshot(T)
    local seats, hands = {}, {}
    for s = 1, SEATS do
        local P = T.seats[s]
        if P then seats[#seats + 1] = { seat = s, src = P.src } end
    end
    for _, P in pairs(T.inRound or {}) do
        if P.hands then
            local list = {}
            for i, h in ipairs(P.hands) do list[i] = { cards = h.cards, bet = h.bet } end
            hands[#hands + 1] = { seat = P.seat, hands = list }
        end
    end
    for s = 1, SEATS do
        local P = T.seats[s]
        if P and P.bet and not P.hands then hands[#hands + 1] = { seat = s, hands = { { cards = {}, bet = P.bet } } } end
    end
    local dealer = {}
    for i, c in ipairs(T.dealer.cards) do dealer[i] = (i == 1 and T.dealer.hidden) and false or c end
    return { seats = seats, hands = hands, dealer = dealer, look = T.look }
end

-- ============================================
-- Money
-- ============================================

local function moneyOpts(reason, P)
    local o = { reason = reason }
    if Config.Money.currency then o.currency = Config.Money.currency end
    if not (P and P.dropped) then o.method = Config.Money.method end
    return o
end

--- Takes a stake. A receipt, or false and a sentence for the player.
function Charge(P, amount, reason)
    if P.dropped then return false, 'gone' end
    return Whip.core:ChargePlayer(P.src, amount, moneyOpts(reason, P))
end

--- Pays a player, at the table or not (a player who has gone home is paid to their character).
function Pay(P, amount, reason)
    if amount <= 0 then return true end
    local who = P.dropped and { charId = P.charId } or P.src
    local ok, why = Whip.core:PayPlayer(who, amount, moneyOpts(reason, P))
    if not ok then
        print(('[whip_casino:blackjack] CRITICAL: could not pay %s (char %s) %d: %s'):format(P.name, tostring(P.charId), amount, tostring(why)))
    end
    return ok
end

function Refund(receipt)
    if not receipt then return end
    local ok, why = Whip.core:RefundPlayer(receipt)
    if not ok then print(('[whip_casino:blackjack] CRITICAL: refund failed: %s'):format(tostring(why))) end
end

function Notify(P, msg, kind)
    if P.gone or P.dropped then return end
    Whip.core:NotifyPlayer(P.src, msg, kind or 'inform')
end

-- ============================================
-- Sitting down and getting up
-- ============================================

local function greet(T, P)
    local model = GetEntityModel(GetPlayerPed(P.src))
    local lines = { 'MINIGAME_DEALER_GREET' }
    if model == `mp_f_freemode_01` then lines[2] = 'MINIGAME_DEALER_GREET_FEMALE'
    elseif model == `mp_m_freemode_01` then lines[2] = 'MINIGAME_DEALER_GREET_MALE' end
    if T.recent and T.recent[P.charId] and os.time() - T.recent[P.charId] < 900 then
        Speech(T, 'MINIGAME_DEALER_REJOIN_TABLE')
    else
        Speech(T, lines[math.random(#lines)])
    end
end

local function sit(src, player, tableId, seat)
    local T = Tables[tableId]
    if not T then return false, 'No such table' end
    if BySrc[src] then return false, 'You are already at a table' end
    local at = GetEntityCoords(GetPlayerPed(src))
    if #(at - T.pos) > 3.5 then return false, 'Too far from the table' end

    -- The chair they chose. One whose player left mid-hand stays theirs until the round ends: their cards are on it.
    if T.seats[seat] then return false, 'Someone is sitting there' end
    if T.inRound and T.inRound[seat] then return false, 'That seat is still in the hand, wait for it to finish' end

    local P = {
        src = src, charId = player.charId, name = player.fullName or GetPlayerName(src),
        table = tableId, seat = seat,
    }
    T.seats[seat], BySrc[src] = P, P
    Fx(T, 'seat', { seat = seat, src = src })
    DealerAnim(T, 'acknowledge_p0' .. Cards.animSeat(seat), 'shared')
    greet(T, P)
    CreateThread(function() Wait(250) Hud(P) end)
    return { seat = seat }
end

--- Off the table: a bet not yet dealt goes back; a hand in play is stood and settled with everyone's.
function Leave(P, why)
    local T = Tables[P.table]
    if not T or T.seats[P.seat] ~= P then return end
    T.seats[P.seat] = nil
    BySrc[P.src] = nil
    P.ask = nil

    if P.bet and not P.hands then
        Refund(P.receipt)
        P.bet, P.receipt = nil, nil
        Fx(T, 'chips', { seat = P.seat, hand = 1, amount = 0 })
    end
    if P.hands then P.gone = true end   -- the round plays their hands out (they stand) and pays them

    T.recent = T.recent or {}
    T.recent[P.charId] = os.time()
    Fx(T, 'seat', { seat = P.seat, src = false })
    if P.result == 'won' then Speech(T, 'MINIGAME_DEALER_LEAVE_GOOD_GAME')
    elseif P.result == 'lost' then Speech(T, 'MINIGAME_DEALER_LEAVE_BAD_GAME')
    else Speech(T, 'MINIGAME_DEALER_LEAVE_NEUTRAL_GAME') end
    if not P.dropped and why ~= 'asked' then TriggerClientEvent('whip_casino:blackjack:stand', P.src) end
end

-- ============================================
-- Betting and playing
-- ============================================

local function bet(src, amount)
    local P = BySrc[src]
    if not P then return false, 'You are not at a table' end
    local T = Tables[P.table]
    if P.bet then return false, 'You have already bet' end
    if T.phase ~= 'idle' and T.phase ~= 'betting' then return false, 'Wait for the next hand' end
    if amount < T.def.min then return false, ('The minimum here is %s'):format(Cards.money(T.def.min)) end
    if amount > T.def.max then return false, ('The maximum here is %s'):format(Cards.money(T.def.max)) end

    local receipt, why = Charge(P, amount, 'Blackjack bet')
    if not receipt then return false, why end
    -- It may have closed while the money moved.
    if T.phase ~= 'idle' and T.phase ~= 'betting' then
        Refund(receipt)
        return false, 'Too late, the cards are out'
    end
    P.bet, P.receipt, P.result = amount, receipt, nil
    TriggerClientEvent('whip_casino:blackjack:anim', src, 'place_bet_small')
    -- With the animation: each game puts the chips down where the player's hand does.
    Fx(T, 'chips', { seat = P.seat, hand = 1, amount = amount, anim = 'place_bet_small' })
    Round.start(T)
    HudAll(T)
    return true
end

local function unbet(src)
    local P = BySrc[src]
    if not P or not P.bet or P.hands then return end
    local T = Tables[P.table]
    if T.phase ~= 'idle' and T.phase ~= 'betting' then return end
    Refund(P.receipt)
    P.bet, P.receipt = nil, nil
    Fx(T, 'chips', { seat = P.seat, hand = 1, amount = 0 })
    HudAll(T)
end

local function act(src, choice)
    local P = BySrc[src]
    if not P or not P.ask or P.ask.answer then return end
    if not P.ask.allowed[choice] then return end
    P.ask.answer = choice
end

Whip.register(function()
    Whip.core:SecureCallback('whip_casino:blackjack:sit', {
        rateLimit = 1000, params = { { 'table', 'id', 1, #Config.Tables }, { 'seat', 'id', 1, SEATS } },
    }, sit)

    Whip.core:SecureCallback('whip_casino:blackjack:snapshot', {
        rateLimit = 500, burst = 6, params = { { 'table', 'id', 1, #Config.Tables } },
    }, function(_, _, tableId)
        return snapshot(Tables[tableId])
    end)

    Whip.core:SecureEvent('whip_casino:blackjack:bet', {
        rateLimit = 400, params = { { 'amount', 'amount', 100000000 } },
    }, function(source, _, amount)
        local ok, why = bet(source, amount)
        if not ok and why then Whip.core:NotifyPlayer(source, why, 'error') end
    end)

    Whip.core:SecureEvent('whip_casino:blackjack:unbet', { rateLimit = 400 }, function(source) unbet(source) end)

    Whip.core:SecureEvent('whip_casino:blackjack:act', {
        rateLimit = 250, burst = 3,
        params = { { 'choice', 'enum', { 'hit', 'stand', 'double', 'split', 'surrender', 'insure', 'decline' } } },
    }, function(source, _, choice) act(source, choice) end)

    Whip.core:SecureEvent('whip_casino:blackjack:leave', { rateLimit = 500, whileDead = true }, function(source)
        local P = BySrc[source]
        if P then Leave(P, 'asked') end
    end)
end)

AddEventHandler('playerDropped', function()
    local P = BySrc[source]
    if P then
        P.dropped = true
        Leave(P, 'dropped')
    end
end)

-- Shoved off, teleported, or down: they've left.
CreateThread(function()
    while true do
        Wait(1000)
        for src, P in pairs(BySrc) do
            local T = Tables[P.table]
            local ped = GetPlayerPed(src)
            if ped == 0 or #(GetEntityCoords(ped) - T.pos) > Config.LeaveDistance + 2.0
                or Whip.core:IsPlayerDead(src) == true then
                Leave(P, 'away')
            end
        end
    end
end)

-- Stopping mid-hand: every stake still on the felt goes back. The players did nothing wrong.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, T in pairs(Tables) do
        local seen = {}
        local function back(P)
            if seen[P] then return end
            seen[P] = true
            if P.bet and not P.hands then Refund(P.receipt) end
            for _, h in ipairs(P.hands or {}) do
                if not h.settled then
                    for _, r in ipairs(h.receipts) do Refund(r) end
                end
            end
            if P.insurance and not P.insurance.settled then Refund(P.insurance.receipt) end
        end
        for s = 1, SEATS do if T.seats[s] then back(T.seats[s]) end end
        for _, P in pairs(T.inRound or {}) do back(P) end
    end
end)

-- ============================================
-- The layout (/bjedit): where cards, chips and the dealer go, per table model
-- ============================================
-- Kept in layout.json in this resource: { [model] = { chairs, cards, chips, dealer } }, in each table's own frame.

local LAYOUT_FILE = 'blackjack/layout.json'
local Layouts = {}

do
    local raw = LoadResourceFile(GetCurrentResourceName(), LAYOUT_FILE)
    if raw and raw ~= '' then
        local ok, v = pcall(json.decode, raw)
        if ok and type(v) == 'table' then Layouts = v
        else print('[whip_casino:blackjack] layout.json could not be read: ' .. tostring(v)) end
    end
end

-- Only numbers in the shapes we use, so a bad send can't write rubbish into the file: x, y, z within 50 m of the
-- table, and a turn in degrees.
local dropped = 0
local function cleanSpot(v, n)
    if type(v) ~= 'table' then dropped = dropped + 1 return nil end
    local out = {}
    for i = 1, n do
        local x = tonumber(v[i])
        local limit = (i == 4) and 720 or 50
        if not x or x ~= x or math.abs(x) > limit then dropped = dropped + 1 return nil end
        out[i] = math.floor(x * 10000 + 0.5) / 10000
    end
    return out
end

local function cleanLayout(d)
    if type(d) ~= 'table' then return nil end
    local out = { chairs = {}, cards = {}, chips = {} }
    for k, v in pairs(type(d.chairs) == 'table' and d.chairs or {}) do
        local s, c = tonumber(k), tonumber(v)
        if s and c and s >= 1 and s <= SEATS and c >= 1 and c <= SEATS then out.chairs[tostring(s)] = math.floor(c) end
    end
    for k, v in pairs(type(d.cards) == 'table' and d.cards or {}) do
        if type(k) == 'string' and k:match('^[0-4]:[12]:[1-3]$') then out.cards[k] = cleanSpot(v, 4) end
    end
    for k, v in pairs(type(d.chips) == 'table' and d.chips or {}) do
        if type(k) == 'string' and k:match('^[1-4]:[12]$') then out.chips[k] = cleanSpot(v, 4) end
    end
    out.dealer = cleanSpot(d.dealer, 4)
    return out
end

Whip.register(function()
    Whip.core:SecureCallback('whip_casino:blackjack:layouts', { rateLimit = 2000, requirePlayer = false }, function()
        return Layouts
    end)

    Whip.core:SecureEvent('whip_casino:blackjack:saveLayout', {
        rateLimit = 2000, params = { { 'model', 'key', 64 }, { 'data', 'any' } },
    }, function(source, _, model, data)
        if not IsPlayerAceAllowed(source, 'whip.devtools') then return false, 'Dev only' end
        local known = false
        for _, def in ipairs(Config.Tables) do if def.model == model then known = true break end end
        if not known then return false, 'No table uses that model' end
        dropped = 0
        local clean = cleanLayout(data)
        if not clean then return false, 'Bad layout' end
        if dropped > 0 then
            -- Never quietly: say what didn't go in.
            Whip.core:NotifyPlayer(source, ('%d spot(s) were not valid and were not saved'):format(dropped), 'error')
        end
        Layouts[model] = clean
        SaveResourceFile(GetCurrentResourceName(), LAYOUT_FILE, json.encode(Layouts, { indent = true }), -1)
        TriggerClientEvent('whip_casino:blackjack:layout', -1, model, clean)
        print(('[whip_casino:blackjack] %s saved the layout for %s to %s'):format(GetPlayerName(source), model, LAYOUT_FILE))
        Whip.core:NotifyPlayer(source, 'Layout saved for every ' .. model, 'success')
    end)
end)

-- ============================================
-- Dev: a config line for where you stand
-- ============================================

Whip.command('bjhere', { dev = true }, function(source)
    local ped = GetPlayerPed(source)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local line = ("{ label = 'Blackjack', coords = vec3(%.2f, %.2f, %.2f), heading = %.1f, model = 'vw_prop_casino_blckjack_01', spawn = true, texture = 0, min = 100, max = 5000 },")
        :format(c.x, c.y, c.z - 1.0, h)
    print('[whip_casino:blackjack] ' .. line)
    Whip.core:NotifyPlayer(source, 'Table line printed to the server console', 'success')
end)

Whip.sayStarted()
