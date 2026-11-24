local _ENV = CasinoGame('blackjack') -- Cards, hands and chips: one set of rules for the server (which deals) and each game (which shows them).
-- A card is 'suit_rank', as the casino's card props are named: 'hrt_ace', 'spd_10', 'club_queen'.

Cards = {}

Cards.SUITS = { 'club', 'dia', 'hrt', 'spd' }
Cards.RANKS = { 'ace', '02', '03', '04', '05', '06', '07', '08', '09', '10', 'jack', 'queen', 'king' }

local FACE = { jack = 10, queen = 10, king = 10 }

function Cards.rank(card)
    return type(card) == 'string' and card:match('_(%w+)$') or nil
end

--- A card's count: an ace is 11 here (total() brings it down to 1 when it must).
function Cards.value(card)
    local r = Cards.rank(card)
    if not r then return 0 end
    if r == 'ace' then return 11 end
    return FACE[r] or tonumber(r) or 0
end

--- A hand's best total, and whether an ace in it is still counting 11 (a soft hand).
function Cards.total(cards)
    local sum, aces = 0, 0
    for _, c in ipairs(cards) do
        sum = sum + Cards.value(c)
        if Cards.rank(c) == 'ace' then aces = aces + 1 end
    end
    while sum > 21 and aces > 0 do
        sum, aces = sum - 10, aces - 1
    end
    return sum, aces > 0
end

--- 21 on the first two cards, and not after a split.
function Cards.natural(cards, split)
    return not split and #cards == 2 and (Cards.total(cards)) == 21
end

--- Two cards of the same count may be split (a king and a ten too).
function Cards.pair(cards)
    return #cards == 2 and Cards.value(cards[1]) == Cards.value(cards[2])
end

--- The number the dealer's animations give a seat ('deal_card_player_0N'): Config.AnimSeats.
function Cards.animSeat(seat)
    return (Config.AnimSeats and Config.AnimSeats[seat]) or seat
end

function Cards.model(card)
    return 'vw_prop_cas_card_' .. card
end

--- A bet as chips on the felt: { { model, count }, ... }, biggest first, at most `cap` chips in all.
function Cards.chips(amount, cap)
    cap = cap or 24
    local out, left, n = {}, math.floor(tonumber(amount) or 0), 0
    for _, c in ipairs(Config.Chips) do
        local value, model = c[1], c[2]
        local k = math.floor(left / value)
        if k > 0 then
            k = math.min(k, cap - n)
            if k <= 0 then break end
            out[#out + 1] = { model = model, count = k }
            left, n = left - k * value, n + k
        end
    end
    -- Less than the smallest chip still shows one.
    if #out == 0 and amount and amount > 0 then out[1] = { model = Config.Chips[#Config.Chips][2], count = 1 } end
    return out
end

--- '$1,250'
function Cards.money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return '$' .. out:gsub('^,', '')
end
