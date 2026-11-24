local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — server: one round, start to finish
-- ============================================
--
-- Bets -> the deal -> insurance and the dealer's peek -> each player's hands in seat order -> the dealer -> pay ->
-- clear. One thread per table while a round runs. Every wait for a player has a deadline: a player who doesn't
-- answer stands, and one who leaves has their hands stood and settled like everyone's.

Round = {}

local SEATS = 4
local R, TM = Config.Rules, Config.Timing

local function now() return GetGameTimer() end

local function seatsInOrder(T)
    local out = {}
    for s = 1, SEATS do
        local P = T.inRound[s]
        if P then out[#out + 1] = P end
    end
    return out
end

-- ============================================
-- Cards out
-- ============================================

local function dealTo(T, P, h, anim)
    local hand = P.hands[h]
    local card = T.shoe:draw()
    hand.cards[#hand.cards + 1] = card
    DealerAnim(T, anim)
    -- anim: the games carry the card in the dealer's hand through it, and lay it where he does.
    Fx(T, 'card', { seat = P.seat, hand = h, index = #hand.cards, card = card, anim = anim })
    return card
end

local function dealerDraw(T, faceDown, anim)
    local card = T.shoe:draw()
    local d = T.dealer
    d.cards[#d.cards + 1] = card
    DealerAnim(T, anim)
    -- Face down: the games get no card at all, only that one is there.
    Fx(T, 'card', { seat = 0, hand = 1, index = #d.cards, card = (not faceDown) and card or false, anim = anim })
    return card
end

local function callTotal(T, cards)
    local total = Cards.total(cards)
    if total <= 21 then Speech(T, 'MINIGAME_BJACK_DEALER_' .. total) end
end

-- ============================================
-- Asking a player
-- ============================================

--- Waits for one player's choice from `allowed` (a set), up to `seconds`. Gone or out of time: `default`.
local function ask(T, P, kind, allowed, seconds, hand, default, cost)
    if P.gone then return default end
    -- Held here as well as on P: Leave takes P.ask away, and reading P.ask.answer after that would end the round
    -- for the whole table (its error handler refunds everyone).
    local a = { kind = kind, allowed = allowed, hand = hand, deadline = now() + seconds * 1000, span = seconds * 1000, cost = cost }
    P.ask = a
    Hud(P)
    while not a.answer and not P.gone and now() < a.deadline do Wait(100) end
    if P.ask == a then P.ask = nil end
    Hud(P)
    return (not P.gone and a.answer) or default
end

local function pAnim(P, anim)
    if not P.gone then TriggerClientEvent('whip_casino:blackjack:anim', P.src, anim) end
end

local function react(P, how)
    if not P.gone then TriggerClientEvent('whip_casino:blackjack:anim', P.src, 'reaction_' .. how .. '_var_0' .. math.random(1, 4), 'shared') end
end

-- ============================================
-- A player's turn
-- ============================================

local function canAfford(P, amount)
    -- The real check is the charge; this only keeps the option off the screen when it plainly can't be paid.
    return not P.gone
end

local function playHand(T, P, h)
    local hand = P.hands[h]
    local seat = P.seat
    local split = #P.hands > 1
    local sfx = (h == 2) and '_split' or ''

    -- A split ace gets its one card and is done.
    if hand.aces then return end

    while true do
        local total = Cards.total(hand.cards)
        if total >= 21 or hand.state then return end

        DealerAnim(T, ('dealer_focus_player_0%d_idle_intro%s'):format(Cards.animSeat(seat), sfx))
        Speech(T, 'MINIGAME_BJACK_DEALER_ANOTHER_CARD')

        local first = #hand.cards == 2
        local allowed = { hit = true, stand = true }
        if first and (not split or R.doubleAfterSplit) and canAfford(P, hand.bet) then allowed.double = true end
        if first and not split and Cards.pair(hand.cards) and canAfford(P, hand.bet) then allowed.split = true end
        if first and not split and R.surrender then allowed.surrender = true end

        local choice = ask(T, P, 'play', allowed, TM.turnSeconds, h, 'stand')

        if choice == 'stand' then
            pAnim(P, 'decline_card_001')
            hand.state = 'stood'
            Wait(700)
            return

        elseif choice == 'surrender' then
            pAnim(P, 'decline_card_alt1')
            hand.state, hand.settled = 'surrendered', true
            local back = math.floor(hand.bet / 2)
            Pay(P, back, 'Blackjack surrender')
            -- won / lost: all that came back / all that was staked, so won - lost is how the round went.
            P.won = (P.won or 0) + back
            P.lost = (P.lost or 0) + hand.bet
            Fx(T, 'chips', { seat = seat, hand = h, amount = 0 })
            Wait(700)
            return

        elseif choice == 'hit' then
            pAnim(P, 'request_card')
            Wait(600)
            dealTo(T, P, h, ('hit_%scard_player_0%d'):format(h == 2 and 'second_' or '', Cards.animSeat(seat)))
            Wait(TM.dealMs)
            local t = Cards.total(hand.cards)
            if t > 21 then
                hand.state = 'bust'
                Speech(T, 'MINIGAME_BJACK_DEALER_PLAYER_BUST')
                react(P, 'terrible')
                Hud(P)
                return
            elseif t == 21 then
                Speech(T, 'MINIGAME_BJACK_DEALER_21')
                hand.state = 'stood'
                Hud(P)
                return
            end
            callTotal(T, hand.cards)
            Hud(P)

        elseif choice == 'double' then
            local receipt, why = Charge(P, hand.bet, 'Blackjack double')
            if not receipt then
                Notify(P, why or 'You can\'t cover the double', 'error')
            else
                hand.receipts[#hand.receipts + 1] = receipt
                hand.bet = hand.bet * 2
                hand.doubled = true
                local betAnim = h == 2 and 'place_bet_double_down' or 'place_bet_small'
                pAnim(P, betAnim)
                Fx(T, 'chips', { seat = seat, hand = h, amount = hand.bet, anim = betAnim })
                Wait(1200)
                dealTo(T, P, h, ('hit_%scard_player_0%d'):format(h == 2 and 'second_' or '', Cards.animSeat(seat)))
                Wait(TM.dealMs)
                local t = Cards.total(hand.cards)
                if t > 21 then
                    hand.state = 'bust'
                    Speech(T, 'MINIGAME_BJACK_DEALER_PLAYER_BUST')
                    react(P, 'terrible')
                else
                    hand.state = 'stood'
                    callTotal(T, hand.cards)
                end
                Hud(P)
                return
            end

        elseif choice == 'split' then
            local receipt, why = Charge(P, hand.bet, 'Blackjack split')
            if not receipt then
                Notify(P, why or 'You can\'t cover the split', 'error')
            else
                pAnim(P, 'place_bet_small_split')
                local moved = table.remove(hand.cards)
                P.hands[2] = { cards = { moved }, bet = hand.bet, receipts = { receipt }, split = true }
                hand.split = true
                Fx(T, 'chips', { seat = seat, hand = 2, amount = hand.bet, anim = 'place_bet_small_split' })
                Wait(1200)
                local splitAnim = 'split_card_player_0' .. Cards.animSeat(seat)
                DealerAnim(T, splitAnim)
                Fx(T, 'split', { seat = seat, anim = splitAnim })
                Wait(TM.dealMs)
                local aces = Cards.rank(moved) == 'ace'
                -- A card to each hand; split aces stop there.
                dealTo(T, P, 1, 'hit_card_player_0' .. Cards.animSeat(seat))
                Wait(TM.dealMs)
                dealTo(T, P, 2, 'hit_second_card_player_0' .. Cards.animSeat(seat))
                Wait(TM.dealMs)
                if aces and R.splitAcesOneCard then
                    hand.aces, P.hands[2].aces = true, true
                    hand.state, P.hands[2].state = 'stood', 'stood'
                end
                split = true
                Hud(P)
            end
        end
    end
end

-- ============================================
-- Settling up
-- ============================================

local function settle(T, P, dealerTotal, dealerNatural)
    local owed = 0
    for _, hand in ipairs(P.hands) do
        if not hand.settled then
            hand.settled = true
            local total = Cards.total(hand.cards)
            local natural = Cards.natural(hand.cards, hand.split)
            local pay = 0
            if hand.state == 'bust' or total > 21 then
                pay = 0
            elseif natural and not dealerNatural then
                pay = hand.bet + math.floor(hand.bet * R.blackjackPays)
            elseif dealerNatural and not natural then
                pay = 0
            elseif natural and dealerNatural then
                pay = hand.bet
            elseif dealerTotal > 21 or total > dealerTotal then
                pay = hand.bet * 2
            elseif total == dealerTotal then
                pay = hand.bet
            end
            owed = owed + pay
            P.won = (P.won or 0) + pay
            P.lost = (P.lost or 0) + hand.bet
        end
    end
    if P.insurance and not P.insurance.settled then
        P.insurance.settled = true
        P.lost = (P.lost or 0) + P.insurance.amount
        if dealerNatural then
            local pay = P.insurance.amount * 3
            owed = owed + pay
            P.won = (P.won or 0) + pay
        end
    end
    if owed > 0 then Pay(P, owed, 'Blackjack winnings') end

    local net = (P.won or 0) - (P.lost or 0)
    if net > 0 then
        P.result = 'won'
        Notify(P, ('You won %s'):format(Cards.money(net)), 'success')
        react(P, 'great')
    elseif net < 0 then
        P.result = 'lost'
        Notify(P, ('You lost %s'):format(Cards.money(-net)), 'error')
        react(P, 'bad')
    else
        P.result = 'push'
        Notify(P, 'Push: your bet is back', 'inform')
        react(P, 'impartial')
    end
end

-- ============================================
-- The round
-- ============================================

local function bettingWindow(T)
    T.phase = 'betting'
    T.deadline = now() + TM.betSeconds * 1000
    T.span = TM.betSeconds * 1000
    Speech(T, 'MINIGAME_DEALER_PLACE_CHIPS')
    HudAll(T)
    while now() < T.deadline do
        Wait(200)
        local seated, bets = 0, 0
        for s = 1, SEATS do
            local P = T.seats[s]
            if P then
                seated = seated + 1
                if P.bet then bets = bets + 1 end
            end
        end
        if bets == 0 then return false end   -- everyone took their bet back, or left
        if bets == seated and T.deadline - now() > TM.allInSeconds * 1000 then
            T.deadline = now() + TM.allInSeconds * 1000
            T.span = TM.allInSeconds * 1000
            HudAll(T)
        end
    end
    return true
end

local function play(T)
    if not bettingWindow(T) then return end

    -- Bets closed: who's in.
    T.phase = 'dealing'
    T.inRound = {}
    for s = 1, SEATS do
        local P = T.seats[s]
        if P and P.bet then
            P.hands = { { cards = {}, bet = P.bet, receipts = { P.receipt } } }
            P.won, P.lost, P.result, P.insurance = 0, 0, nil, nil
            T.inRound[s] = P
        end
    end
    local players = seatsInOrder(T)
    if #players == 0 then return end
    Speech(T, 'MINIGAME_DEALER_CLOSED_BETS')
    HudAll(T)
    Wait(700)

    if T.shoe:check() then
        DealerAnim(T, 'deck_shuffle', 'tcp')
        Wait(2500)
    end

    -- The deal: a card to each player, the dealer's face down; again, the dealer's face up.
    for round = 1, 2 do
        for _, P in ipairs(players) do
            dealTo(T, P, 1, 'deal_card_player_0' .. Cards.animSeat(P.seat))
            Wait(TM.dealMs)
            if round == 2 then
                local hand = P.hands[1]
                if Cards.natural(hand.cards) then
                    Speech(T, 'MINIGAME_BJACK_DEALER_BLACKJACK')
                    react(P, 'great')
                else
                    callTotal(T, hand.cards)
                end
            end
            Hud(P)
        end
        dealerDraw(T, round == 1, round == 1 and 'deal_card_self' or 'deal_card_self_second_card')
        Wait(TM.dealMs)
        HudAll(T)
    end

    local d = T.dealer
    local up = d.cards[2]
    local upAce = Cards.rank(up) == 'ace'
    local upTen = Cards.value(up) == 10

    -- Insurance, everyone at once, when the dealer shows an ace.
    if upAce and R.insurance then
        T.phase = 'insurance'
        local waiting = {}
        for _, P in ipairs(players) do
            local cost = math.floor(P.hands[1].bet / 2)
            if cost > 0 then
                waiting[#waiting + 1] = P
                CreateThread(function()
                    local answer = ask(T, P, 'insurance', { insure = true, decline = true }, TM.insuranceSeconds, 1, 'decline', cost)
                    if answer == 'insure' then
                        local receipt, why = Charge(P, cost, 'Blackjack insurance')
                        if receipt then
                            P.insurance = { amount = cost, receipt = receipt }
                            pAnim(P, 'place_bet_small')
                        else
                            Notify(P, why or 'You can\'t cover the insurance', 'error')
                        end
                    end
                    P.insuranceDone = true
                end)
            else
                P.insuranceDone = true
            end
        end
        local deadline = now() + (TM.insuranceSeconds + 3) * 1000
        while now() < deadline do
            local all = true
            for _, P in ipairs(players) do if not P.insuranceDone then all = false break end end
            if all then break end
            Wait(100)
        end
        for _, P in ipairs(players) do P.insuranceDone = nil end
    end

    -- The peek: with an ace or a ten showing, the dealer checks for blackjack.
    local dealerNatural = false
    if upAce or upTen then
        dealerNatural = Cards.natural(d.cards)
        if dealerNatural then
            DealerAnim(T, 'check_and_turn_card')
            Wait(1000)
            d.hidden = false
            Fx(T, 'reveal', { card = d.cards[1] })
            Speech(T, 'MINIGAME_BJACK_DEALER_BLACKJACK')
            HudAll(T)
            Wait(2000)
        else
            DealerAnim(T, 'check_card')
            Wait(1700)
        end
    end

    -- Each player's hands, seat by seat.
    if not dealerNatural then
        T.phase = 'playing'
        for _, P in ipairs(players) do
            if not Cards.natural(P.hands[1].cards) then
                playHand(T, P, 1)
                if P.hands[2] then playHand(T, P, 2) end
            else
                P.hands[1].state = 'blackjack'
            end
        end

        -- The dealer turns the hole card, and draws only if someone still has a hand to beat.
        T.phase = 'dealer'
        HudAll(T)
        Wait(800)
        DealerAnim(T, 'turn_card')
        Wait(900)
        d.hidden = false
        Fx(T, 'reveal', { card = d.cards[1] })
        HudAll(T)
        Wait(1200)

        local live = false
        for _, P in ipairs(players) do
            for _, hand in ipairs(P.hands) do
                local total = Cards.total(hand.cards)
                if total <= 21 and hand.state ~= 'surrendered' and not Cards.natural(hand.cards, hand.split) then live = true end
            end
        end

        callTotal(T, d.cards)
        while live do
            local total, soft = Cards.total(d.cards)
            if total > 17 or (total == 17 and not (soft and R.hitSoft17)) then break end
            dealerDraw(T, false, 'deal_card_self_second_card')
            Wait(TM.dealMs)
            callTotal(T, d.cards)
            HudAll(T)
        end
        if Cards.total(d.cards) > 21 then
            DealerAnim(T, 'reaction_bad_var_0' .. math.random(1, 3), 'shared')
            Speech(T, 'MINIGAME_DEALER_BUSTS')
            Wait(1500)
        end
    end

    -- Pay.
    T.phase = 'payout'
    local dealerTotal = Cards.total(d.cards)
    for _, P in ipairs(players) do settle(T, P, dealerTotal, dealerNatural) end
    HudAll(T)
    Wait(2000)

    -- Clear the felt, seat by seat, then the dealer's own.
    for _, P in ipairs(players) do
        DealerAnim(T, 'retrieve_cards_player_0' .. Cards.animSeat(P.seat))
        Wait(800)
        Fx(T, 'clear', { seat = P.seat })
        Wait(300)
    end
    DealerAnim(T, 'retrieve_own_cards_and_remove')
    Wait(1200)
    Fx(T, 'clear', { seat = 0 })
end

--- Called on a bet: starts this table's round if one isn't running.
function Round.start(T)
    if T.running then return end
    T.running = true
    CreateThread(function()
        local ok, err = pcall(play, T)
        if not ok then
            print(('[whip_casino:blackjack] table %d: the round failed: %s'):format(T.id, tostring(err)))
            -- Anything not settled goes back.
            for _, P in pairs(T.inRound or {}) do
                for _, hand in ipairs(P.hands or {}) do
                    if not hand.settled then
                        hand.settled = true
                        for _, r in ipairs(hand.receipts) do Refund(r) end
                    end
                end
                if P.insurance and not P.insurance.settled then
                    P.insurance.settled = true
                    Refund(P.insurance.receipt)
                end
            end
            Fx(T, 'clear', { all = true })
        end
        -- Ready for the next.
        for _, P in pairs(T.inRound or {}) do
            P.hands, P.bet, P.receipt, P.insurance, P.ask = nil, nil, nil, nil, nil
        end
        T.inRound = nil
        T.dealer = { cards = {}, hidden = true }
        T.phase = 'idle'
        T.running = false
        DealerAnim(T, 'idle')
        Speech(T, 'MINIGAME_DEALER_ANOTHER_GO')
        HudAll(T)
        -- Bets placed while the last round ran: go again.
        for s = 1, SEATS do
            local P = T.seats[s]
            if P and P.bet then Round.start(T) break end
        end
    end)
end
