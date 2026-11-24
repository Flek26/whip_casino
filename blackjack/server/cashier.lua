local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — server: the chips, and the cashier who sells them
-- ============================================
--
-- casino_chips is an item (Config.ChipItem). The cashier sells them for money and buys them back, all through
-- whip's ChargePlayer and PayPlayer (so it's on the activity log): if the second half of a trade can't happen, the
-- first is given back. Cashiers are placed by a dev with /bjcashier and kept in cashiers.json.

local C = Config.Cashier
local ITEM = Config.ChipItem.key
local FILE = 'blackjack/cashiers.json'

local Cashiers = {}   -- { { id, x, y, z, w } }

do
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    if raw and raw ~= '' then
        local ok, v = pcall(json.decode, raw)
        if ok and type(v) == 'table' then Cashiers = v
        else print('[whip_casino:blackjack] cashiers.json could not be read: ' .. tostring(v)) end
    end
end

local function store()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(Cashiers, { indent = true }), -1)
    TriggerClientEvent('whip_casino:blackjack:cashiers', -1, Cashiers)
end

local function nearCashier(src, range)
    local at = GetEntityCoords(GetPlayerPed(src))
    for _, c in ipairs(Cashiers) do
        if #(at - vector3(c.x, c.y, c.z)) <= range then return c end
    end
    return nil
end

local function notify(src, msg, kind) Whip.core:NotifyPlayer(src, msg, kind or 'inform') end

-- ============================================
-- Buying and cashing in
-- ============================================

local function buy(src, amount)
    local price = math.ceil(amount * C.buyPrice)
    local receipt, why = Whip.core:ChargePlayer(src, price, { method = C.payWith, reason = 'Casino chips' })
    if not receipt then return false, why end
    local paid, why2 = Whip.core:PayPlayer(src, amount, { method = 'cash', currency = ITEM, reason = 'Casino chips' })
    if not paid then
        Whip.core:RefundPlayer(receipt)
        return false, why2 or 'The chips could not be given'
    end
    if paid.placement == 'ground' then notify(src, 'Your pockets are full: the chips are at your feet', 'error') end
    return true, ('Bought %s in chips for %s'):format(Cards.money(amount), Cards.money(price))
end

local function sell(src, amount)
    local receipt, why = Whip.core:ChargePlayer(src, amount, { method = 'cash', currency = ITEM, reason = 'Chips cashed in' })
    if not receipt then return false, why or 'You don\'t have that many chips' end
    local value = math.floor(amount * C.sellPrice)
    local paid, why2 = Whip.core:PayPlayer(src, value, { method = C.payOut, reason = 'Chips cashed in' })
    if not paid then
        Whip.core:RefundPlayer(receipt)
        return false, why2 or 'The cashier could not pay you'
    end
    return true, ('Cashed in %s chips for %s'):format(Cards.money(amount):sub(2), Cards.money(value))
end

Whip.register(function()
    -- The chips item, with its picture from this resource.
    local ok, why = Whip.core:RegisterItem(ITEM, {
        name = Config.ChipItem.name, desc = Config.ChipItem.desc,
        weight = 0.0001, type = 'currency', stack = true, maxStack = 9999999, usable = false, cooldown = 0,
        prop = 'vw_prop_chip_100dollar_st',
        image = 'casinochips.png',
    })
    if not ok then Whip.startProblem('could not register the chips item: %s', tostring(why)) end

    Whip.core:SecureCallback('whip_casino:blackjack:cashiers', { rateLimit = 2000, requirePlayer = false }, function()
        return Cashiers
    end)

    Whip.core:SecureCallback('whip_casino:blackjack:chips', {
        rateLimit = 1000,
        params = { { 'how', 'enum', { 'buy', 'sell' } }, { 'amount', 'amount', C.max } },
    }, function(source, _, how, amount)
        if not nearCashier(source, C.reach + 1.5) then return false, 'Go to the cashier' end
        if amount < C.min then return false, ('At least %d chips'):format(C.min) end
        if how == 'buy' then return buy(source, amount) end
        return sell(source, amount)
    end)

    -- The dev's placement, from /bjcashier: a new cashier (id 0), or one moved / given another pose.
    local poseIds = {}
    for _, p in ipairs(C.poses) do poseIds[#poseIds + 1] = p.id end
    Whip.core:SecureEvent('whip_casino:blackjack:placeCashier', {
        rateLimit = 1000,
        params = {
            { 'id', 'int', 0, 100000 },
            { 'x', 'number', -10000, 10000 }, { 'y', 'number', -10000, 10000 },
            { 'z', 'number', -500, 2000 }, { 'w', 'number', -360, 720 },
            { 'pose', 'enum', poseIds, 'stand' },
        },
    }, function(source, _, id, x, y, z, w, pose)
        if not IsPlayerAceAllowed(source, 'whip.devtools') then return false, 'Dev only' end
        if #(GetEntityCoords(GetPlayerPed(source)) - vector3(x, y, z)) > 30.0 then return false, 'Too far from you' end
        local entry = { x = x, y = y, z = z, w = w % 360.0, pose = pose }
        local found
        for _, c in ipairs(Cashiers) do
            if id > 0 and c.id == id then found = c break end
        end
        if found then
            for k, v in pairs(entry) do found[k] = v end
        else
            id = 1
            for _, c in ipairs(Cashiers) do if c.id >= id then id = c.id + 1 end end
            entry.id = id
            Cashiers[#Cashiers + 1] = entry
        end
        store()
        notify(source, ('Cashier #%d %s'):format(id, found and 'updated' or 'placed'), 'success')
        print(('[whip_casino:blackjack] %s %s cashier #%d (%s)'):format(GetPlayerName(source), found and 'updated' or 'placed', id, pose))
    end)
end)

Whip.command('bjcashier', { dev = true }, function(source)
    TriggerClientEvent('whip_casino:blackjack:placeCashier', source)
end)

Whip.command('bjcashierremove', { dev = true }, function(source)
    local here = GetEntityCoords(GetPlayerPed(source))
    local best, bestD = nil, 4.0
    for i, c in ipairs(Cashiers) do
        local d = #(here - vector3(c.x, c.y, c.z))
        if d < bestD then best, bestD = i, d end
    end
    if not best then return notify(source, 'No cashier within 4 m', 'error') end
    local id = Cashiers[best].id
    table.remove(Cashiers, best)
    store()
    notify(source, ('Cashier #%d removed'):format(id), 'success')
end)

local function suggestions(src)
    if not IsPlayerAceAllowed(src, 'whip.devtools') then return end
    TriggerClientEvent('chat:addSuggestions', src, {
        { name = '/bjcashier', help = 'Place a casino cashier, or (stood next to one) move it and change its pose' },
        { name = '/bjcashierremove', help = 'Remove the casino cashier nearest you' },
        { name = '/bjedit', help = 'Blackjack: move the cards, chips and dealer at the table you stand at' },
    })
end
AddEventHandler('whip_core:player:loaded', function(e) if type(e) == 'table' and e.source then suggestions(e.source) end end)
CreateThread(function() for _, s in ipairs(GetPlayers()) do suggestions(tonumber(s)) end end)
