local _ENV = CasinoGame('blackjack') -- The shoe: Config.Rules.decks decks, shuffled (Fisher-Yates), dealt from the top until the cut card.

Shoe = {}
Shoe.__index = Shoe

function Shoe.new()
    local s = setmetatable({ cards = {}, size = 0 }, Shoe)
    s:shuffle()
    return s
end

function Shoe:shuffle()
    local cards = {}
    for _ = 1, math.max(1, Config.Rules.decks) do
        for _, suit in ipairs(Cards.SUITS) do
            for _, rank in ipairs(Cards.RANKS) do cards[#cards + 1] = suit .. '_' .. rank end
        end
    end
    for i = #cards, 2, -1 do
        local j = math.random(i)
        cards[i], cards[j] = cards[j], cards[i]
    end
    self.cards, self.size = cards, #cards
end

--- Before a round: past the cut card (or every round, if the rules say), a fresh shoe. True when it was shuffled.
function Shoe:check()
    local dealt = 1 - #self.cards / self.size
    if Config.Rules.shuffleEveryRound or dealt >= Config.Rules.penetration then
        self:shuffle()
        return true
    end
    return false
end

function Shoe:draw()
    if #self.cards == 0 then self:shuffle() end
    return table.remove(self.cards)
end
