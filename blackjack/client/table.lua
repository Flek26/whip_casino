local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — client: the tables as this game draws them
-- ============================================
--
-- Every table near you is made here, in this game only: the table (when we place it), its dealer, the cards and
-- chips. The server sends what happens (fx) and this game shows it, so nothing is networked and every game agrees.
-- Coming near a table mid-hand, the game asks for it as it stands (snapshot).
--
-- Where a card or chip lands is decided by the animation, not by sums: a card rides in the dealer's hand and is
-- put down where his hand puts it down, chips where the player's hand drops them. Each landing is remembered (for
-- this table model, across restarts) so a card shown without its animation (a snapshot) goes to the same place.
-- The same watching learns which chair each of the dealer's seat animations reaches (they number the seats their
-- own way), and the players are sat accordingly.

local DICT = {
    bj     = 'anim_casino_b@amb@casino@games@blackjack@dealer',
    shared = 'anim_casino_b@amb@casino@games@shared@dealer@',
    tcp    = 'anim_casino_b@amb@casino@games@threecardpoker@dealer',
}
local PLAY_DICT = 'anim_casino_b@amb@casino@games@blackjack@player'
local SEATS = 4
local LY = Config.Layout

Live = {}   -- [tableId] = L: { id, def, obj, owned, dealer, voice, frame, learn, model, cards, chips, placed, ready, queue }

-- ============================================
-- What's been learnt, per table model, kept on this PC
-- ============================================

local Learnt = {}   -- [model] = { chairs = { [seat] = chair }, cards = { ['s:h:i'] = {x, y} }, chips = { ['s:h'] = {x, y} } }

local function kvpKey(model) return 'learnt:' .. model end

local function learnFor(model)
    if Learnt[model] then return Learnt[model] end
    local t
    local raw = GetResourceKvpString(kvpKey(model))
    if raw then
        local ok, v = pcall(json.decode, raw)
        if ok and type(v) == 'table' then t = v end
    end
    t = t or {}
    t.cards, t.chips = t.cards or {}, t.chips or {}
    if not t.chairs then
        t.chairs = {}
        for s = 1, SEATS do t.chairs[tostring(s)] = (LY.seatChairs and LY.seatChairs[s]) or s end
    end
    Learnt[model] = t
    return t
end

local saveAt = {}
local function save(model)
    if saveAt[model] then return end
    saveAt[model] = true
    SetTimeout(2000, function()
        saveAt[model] = nil
        SetResourceKvp(kvpKey(model), json.encode(Learnt[model]))
    end)
end

-- Forget it all (a table was moved, or the learning went wrong): /bjforget.
RegisterCommand('bjforget', function()
    for model in pairs(Learnt) do DeleteResourceKvp(kvpKey(model)) end
    for _, T in ipairs(Config.Tables) do DeleteResourceKvp(kvpKey(T.model)) end
    Learnt = {}
    for _, L in pairs(Live) do L.learn = learnFor(L.def.model) end
    print('[whip_casino:blackjack] forgot every learnt chair and landing spot')
end, false)

-- ============================================
-- The table's frame: chairs, the middle, the dealer's side
-- ============================================

local function norm(x, y)
    local l = math.sqrt(x * x + y * y)
    if l < 0.0001 then return 0.0, 1.0, 0.0 end
    return x / l, y / l, l
end

local function buildFrame(L)
    local obj = L.obj
    local cx, cy = LY.centre.x, LY.centre.y
    local chairs, bones, mx, my = {}, {}, 0.0, 0.0
    for c = 1, SEATS do
        local idx = GetEntityBoneIndexByName(obj, ('Chair_Base_0%d'):format(c))
        local lp
        if idx ~= -1 then
            bones[c] = idx
            lp = GetOffsetFromEntityGivenWorldCoords(obj, GetWorldPositionOfEntityBone(obj, idx))
        else
            -- No bones (another model): four chairs on an arc in front of the table.
            local a = math.rad(-60 + (c - 1) * 40)
            lp = vector3(cx + math.sin(a) * 1.05, cy - math.cos(a) * 1.05, 0.0)
        end
        chairs[c] = lp
        mx, my = mx + (lp.x - cx), my + (lp.y - cy)
    end
    -- The dealer stands opposite the chairs.
    local dx, dy = norm(-mx, -my)
    L.frame = { chairs = chairs, bones = bones, cx = cx, cy = cy, dx = dx, dy = dy }
    if not next(bones) then
        print(('[whip_casino:blackjack] table %d: no chair bones on its model, seats are guessed'):format(L.id))
    end
end

-- ============================================
-- The saved layout (/bjedit): first say over everything below
-- ============================================
-- Per table model, in the table's own frame: { chairs = { ['1'] = chair }, cards = { ['s:h:i'] = { x, y, z, h } },
-- chips = { ['s:h'] = { x, y, z, h } }, dealer = { x, y, z, h } }. h is degrees from the table's heading. Cards
-- 1-3 (the dealer's 1-3) are set; later ones carry on the step from the last two.

Layouts = {}

local function lay(L) return Layouts[L.def.model] end

local function layCard(L, s, h, i)
    local t = lay(L)
    local cards = t and t.cards
    if not cards then return nil end
    local key = function(k) return cards[('%d:%d:%d'):format(s, h, k)] end
    if key(i) then return key(i) end
    -- Past the last set card: on along the step between the last two.
    local last
    for k = 3, 1, -1 do if key(k) then last = k break end end
    if not last or i <= last then return nil end
    local a, b = key(last - 1), key(last)
    if not a then return { b[1], b[2], b[3], b[4] } end
    local n = i - last
    return { b[1] + (b[1] - a[1]) * n, b[2] + (b[2] - a[2]) * n, b[3] + 0.0007 * n, b[4] }
end

--- The chair a seat (as the dealer's animations number it) is.
local function chairOf(L, s)
    local t = lay(L)
    if t and t.chairs and t.chairs[tostring(s)] then return t.chairs[tostring(s)] end
    return L.learn.chairs[tostring(s)] or s
end

local boneRotation = GetEntityBoneRotation or GetWorldRotationOfEntityBone

local function world(L, x, y, z)
    return GetOffsetFromEntityInWorldCoords(L.obj, x, y, z)
end

local function toLocal(L, p)
    return GetOffsetFromEntityGivenWorldCoords(L.obj, p.x, p.y, p.z)
end

-- A local direction as a world heading (GTA: 0 is north, turning left).
local function headingOf(L, dx, dy)
    return (GetEntityHeading(L.obj) + math.deg(math.atan(-dx, dy))) % 360.0
end

local function seatAxes(L, s)
    local f = L.frame
    local c = f.chairs[chairOf(L, s)]
    local ux, uy, r = norm(c.x - f.cx, c.y - f.cy)   -- out towards the chair
    return ux, uy, -uy, ux, r                         -- out, and sideways
end

local function cardHeading(L, s)
    if s == 0 then return headingOf(L, -L.frame.dx, -L.frame.dy) end
    local ux, uy = seatAxes(L, s)
    return headingOf(L, -ux, -uy)
end

-- Later cards are dealt by the same animation as the one before: each lands a step along from where it put the first.
local function extraStep(L, s, steps)
    local tx, ty
    if s == 0 then tx, ty = -L.frame.dy, L.frame.dx else local _, _, a, b = seatAxes(L, s) tx, ty = a, b end
    return tx * LY.cardSpread * steps, ty * LY.cardSpread * steps
end

--- Which learnt landing a card goes by, and how many steps along from it: the dealer's 3rd card on are dealt by the
--- 2nd card's animation, a player's 4th on by the 3rd's.
local function baseIndex(s, i)
    local last = (s == 0) and 2 or 3
    if i > last then return last, i - last end
    return i, 0
end

--- Where card `i` of hand `h` at seat `s` lies (s = 0: the dealer's), and its heading.
function CardSpot(L, s, h, i)
    local f = L.frame
    local set = layCard(L, s, h, i)
    if set then
        return world(L, set[1], set[2], set[3]), (GetEntityHeading(L.obj) + set[4]) % 360.0, true
    end
    local z = LY.surface + 0.0007 * i
    local heading = cardHeading(L, s)
    local bi, steps = baseIndex(s, i)
    local learnt = L.learn.cards[('%d:%d:%d'):format(s, h, bi)]
    if learnt then
        local ex, ey = extraStep(L, s, steps)
        return world(L, learnt[1] + ex, learnt[2] + ey, z), heading
    end
    if s == 0 then
        local tx, ty = -f.dy, f.dx
        local off = (i - 1) * LY.cardSpread * 1.4 - LY.cardSpread * 0.7
        return world(L, f.cx + f.dx * LY.dealerCardAt + tx * off, f.cy + f.dy * LY.dealerCardAt + ty * off, z), heading
    end
    local ux, uy, tx, ty, r = seatAxes(L, s)
    local side = (h == 2) and LY.splitGap * 2 or 0.0
    local along = r * LY.cardAt - (i - 1) * 0.012
    local across = side + (i - 1.5) * LY.cardSpread
    return world(L, f.cx + ux * along + tx * across, f.cy + uy * along + ty * across, z), heading
end

--- Where a seat's chips stack, in the table's frame: x, y, the sideways direction, the height, and (set) true.
function ChipSpot(L, s, h)
    local f = L.frame
    local ux, uy, tx, ty, r = seatAxes(L, s)
    local t = lay(L)
    local set = t and t.chips and t.chips[('%d:%d'):format(s, h)]
    if set then
        local a = math.rad(set[4] or 0.0)
        return set[1], set[2], math.cos(a), math.sin(a), set[3], true
    end
    local learnt = L.learn.chips[('%d:%d'):format(s, h)]
    if learnt then return learnt[1], learnt[2], tx, ty end
    local side = (h == 2) and LY.splitGap * 2 or 0.0
    return f.cx + ux * r * LY.chipAt + tx * side, f.cy + uy * r * LY.chipAt + ty * side, tx, ty
end

--- Where the dealer stands (his feet), his heading, and how high his hips are.
function DealerSpot(L)
    local t = lay(L)
    if t and t.dealer then
        local d = t.dealer
        return world(L, d[1], d[2], 0.0), (GetEntityHeading(L.obj) + d[4]) % 360.0, d[3]
    end
    local f = L.frame
    return world(L, f.cx + f.dx * LY.dealerStand, f.cy + f.dy * LY.dealerStand, 0.0), headingOf(L, -f.dx, -f.dy), LY.dealerLift
end

--- A seat's chair in the world, and the heading its sit animations are played at (the chair bone's own).
function ChairSpot(L, s)
    local c = chairOf(L, s)
    local p = L.frame.chairs[c]
    local at = world(L, p.x, p.y, p.z)
    local idx = L.frame.bones[c]
    local bone = (idx and boneRotation) and boneRotation(L.obj, idx) or nil
    local heading
    if bone then
        heading = bone.z
    else
        local d = DealerSpot(L)
        heading = GetHeadingFromVector_2d(d.x - at.x, d.y - at.y)
    end
    return at, (heading + LY.seatTurn) % 360.0
end

function FeltMiddle(L)
    local f = L.frame
    return world(L, f.cx + f.dx * LY.dealerCardAt * 0.5, f.cy + f.dy * LY.dealerCardAt * 0.5, LY.surface)
end

-- ============================================
-- Props
-- ============================================

local function model(name)
    return exports.whip_core:LoadModel(name)
end

-- Made inside an MLO, a prop or ped isn't drawn until it's put in the table's room.
local function intoRoom(L, ent)
    local interior = GetInteriorFromEntity(L.obj)
    if interior ~= 0 then
        ForceRoomForEntity(ent, interior, GetRoomKeyFromEntity(L.obj))
    end
end

local function flat(ent, heading, faceDown)
    SetEntityRotation(ent, faceDown and 180.0 or 0.0, 0.0, heading, 2, true)
end

local function makeProp(L, name, at, heading, faceDown)
    local hash = model(name)
    if not hash then return nil end
    local ent = CreateObject(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    intoRoom(L, ent)
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(ent, true)
    flat(ent, heading, faceDown)
    return ent
end

local function gone(ent)
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function moveTo(ent, p, heading, faceDown)
    -- Face down, the card is turned over on its own middle: lifted a touch so it doesn't sink into the felt.
    SetEntityCoordsNoOffset(ent, p.x, p.y, p.z + (faceDown and 0.003 or 0.0), false, false, false)
    flat(ent, heading, faceDown)
end

-- ============================================
-- Watching a hand
-- ============================================

--- Follows a ped's hand through one animation, calling `onHand(pos, phase)` each frame, until the hand puts
--- something down on the felt: its lowest point there, once it lifts again. nil when the animation never played
--- or nothing was put down.
local function watchDrop(ped, dict, anim, bone, feltZ, onHand, minAway, cut)
    minAway = minAway or 0.25
    local t0 = GetGameTimer()
    while not IsEntityPlayingAnim(ped, dict, anim, 3) do
        if GetGameTimer() - t0 > 1500 or not DoesEntityExist(ped) or (cut and cut()) then return nil end
        Wait(0)
    end
    -- Never longer than the animation once through: the same one played again (the dealer drawing card after card)
    -- is the next card's, not this one's.
    local untilAt = GetGameTimer() + math.max(600, math.floor(GetAnimDuration(dict, anim) * 1000))
    local start, low, lastPhase = nil, nil, -1.0
    while DoesEntityExist(ped) and IsEntityPlayingAnim(ped, dict, anim, 3) do
        local phase = GetEntityAnimCurrentTime(ped, dict, anim)
        if phase < lastPhase - 0.05 or GetGameTimer() > untilAt or (cut and cut()) then break end
        lastPhase = phase
        local p = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
        if onHand then onHand(p, phase) end
        if phase >= LY.grabPhase then
            start = start or p
            -- Not where it took the card from (the shoe, or a resting hand): somewhere it was carried to.
            local away = #(vector2(p.x, p.y) - vector2(start.x, start.y)) > minAway
            if away and p.z <= feltZ + LY.dropBand then
                if not low or p.z < low.z then low = p
                elseif p.z > low.z + 0.015 then return low end
            elseif low then
                return low
            end
        end
        Wait(0)
    end
    return low
end

-- ============================================
-- The model: what's on the felt, and drawing it
-- ============================================

local function seatModel(L, s)
    local m = L.model.seats[s]
    if not m then
        m = { hands = { { cards = {}, bet = 0 } } }
        L.model.seats[s] = m
    end
    return m
end

local function cardKey(s, h, i) return ('%d:%d:%d'):format(s, h, i) end

local function nearestChair(L, p)
    local lp = toLocal(L, p)
    local best, bestD
    for c = 1, SEATS do
        local ch = L.frame.chairs[c]
        local d = (ch.x - lp.x) ^ 2 + (ch.y - lp.y) ^ 2
        if not bestD or d < bestD then best, bestD = c, d end
    end
    return best
end

-- A card the dealer dealt to seat `s` landed near chair `c`: if that isn't the chair we have for `s`, the dealer's
-- animations number the seats another way. Learnt for the whole table: mirrored if it's mirrored, else that seat.
local function learnChair(L, s, p)
    local t = lay(L)
    if t and t.chairs and next(t.chairs) then return end   -- set by hand in /bjedit
    local c = nearestChair(L, p)
    if c == chairOf(L, s) then return end
    local chairs = L.learn.chairs
    if c == SEATS + 1 - s then
        for k = 1, SEATS do chairs[tostring(k)] = SEATS + 1 - k end
    else
        for k = 1, SEATS do if chairs[tostring(k)] == c then chairs[tostring(k)] = chairOf(L, s) end end
        chairs[tostring(s)] = c
    end
    save(L.def.model)
    print(('[whip_casino:blackjack] the dealer deals seat %d to chair %d: learnt (chairs now %s). Players sit there from the next time they sit down.')
        :format(s, c, json.encode(chairs)))
end

--- A card dealt now: it appears in the dealer's hand as he takes it, rides there, and lies where he puts it.
local function dealCard(L, s, h, i, card, anim)
    local key = cardKey(s, h, i)
    local faceDown = not card
    local fallback, heading, setByHand = CardSpot(L, s, h, i)
    local ent = makeProp(L, Cards.model(card or 'spd_ace'), fallback, heading, faceDown)
    if not ent then return end
    L.cards[key] = ent
    local ped = L.dealer
    if not anim or not ped or not DoesEntityExist(ped) then
        moveTo(ent, fallback, heading, faceDown)
        L.placed[key] = fallback
        return
    end
    SetEntityVisible(ent, false, false)
    -- One card in the dealer's hand at a time: dealing the next one puts this one down.
    L.dealSeq = (L.dealSeq or 0) + 1
    local mine = L.dealSeq
    CreateThread(function()
        local drop = watchDrop(ped, (L.dicts or DICT).bj, anim, LY.dealerHand, GetEntityCoords(L.obj).z + LY.surface, function(hand, phase)
            if phase >= LY.grabPhase and L.cards[key] == ent then
                SetEntityVisible(ent, true, false)
                SetEntityCoordsNoOffset(ent, hand.x, hand.y, hand.z - 0.01, false, false, false)
                flat(ent, heading, faceDown)
            end
        end, nil, function() return L.dealSeq ~= mine end)
        if L.cards[key] ~= ent then return end
        SetEntityVisible(ent, true, false)
        local at = fallback
        -- Set in /bjedit: the hand only says when, the layout says where.
        if drop and not setByHand then
            local bi, steps = baseIndex(s, i)
            local lp = toLocal(L, drop)
            if steps == 0 then
                -- Learnt where this animation lays this card.
                L.learn.cards[cardKey(s, h, bi)] = { lp.x, lp.y }
                save(L.def.model)
                if s > 0 and (anim:find('^deal_card_player') or anim:find('^hit_card_player')) then learnChair(L, s, drop) end
            end
            local ex, ey = extraStep(L, s, steps)
            at = world(L, lp.x + ex, lp.y + ey, LY.surface + 0.0007 * i)
        end
        L.placed[key] = at
        -- From the hand down onto its spot, quickly.
        local from = GetEntityCoords(ent)
        local t0 = GetGameTimer()
        while L.cards[key] == ent and DoesEntityExist(ent) do
            local k = math.min(1.0, (GetGameTimer() - t0) / 160)
            moveTo(ent, from + (at - from) * k, heading, faceDown)
            if k >= 1.0 then break end
            Wait(0)
        end
    end)
end

local function placeCard(L, s, h, i, card)
    local key = cardKey(s, h, i)
    gone(L.cards[key])
    L.cards[key] = nil
    local at, heading = CardSpot(L, s, h, i)
    at = L.placed[key] or at
    local ent = makeProp(L, Cards.model(card or 'spd_ace'), at, heading, not card)
    if not ent then return end
    moveTo(ent, at, heading, not card)
    L.cards[key] = ent
    L.placed[key] = at
end

local function stackChips(L, s, h, amount, x, y, tx, ty, z)
    local key = ('%d:%d'):format(s, h)
    for _, e in ipairs(L.chips[key] or {}) do gone(e) end
    L.chips[key] = nil
    if not amount or amount <= 0 then return end
    z = z or LY.surface
    local stacks = Cards.chips(amount)
    local list = {}
    for k, st in ipairs(stacks) do
        local off = (k - 1 - (#stacks - 1) / 2) * 0.042
        for j = 1, st.count do
            local at = world(L, x + tx * off, y + ty * off, z + (j - 1) * LY.chipHeight)
            local e = makeProp(L, st.model, at, GetEntityHeading(L.obj), false)
            if e then list[#list + 1] = e end
        end
    end
    L.chips[key] = list
end

local function seatPed(L, s)
    local src = L.model.taken[s]
    if not src then return nil end
    local p = GetPlayerFromServerId(src)
    if p == -1 then return nil end
    local ped = GetPlayerPed(p)
    return ped ~= 0 and ped or nil
end

--- Chips on the felt: where the player's hand drops them, when it drops them (an `anim` playing), or where the
--- last ones went.
local function chipsAt(L, s, h, amount, anim)
    local x, y, tx, ty, z, setByHand = ChipSpot(L, s, h)
    local ped = anim and seatPed(L, s)
    if not ped or not amount or amount <= 0 then
        return stackChips(L, s, h, amount, x, y, tx, ty, z)
    end
    CreateThread(function()
        local drop = watchDrop(ped, PLAY_DICT, anim, LY.playerHand, GetEntityCoords(L.obj).z + LY.surface, nil, 0.12)
        -- Set in /bjedit: the hand only says when, the layout says where.
        if drop and not setByHand then
            local lp = toLocal(L, drop)
            x, y = lp.x, lp.y
            L.learn.chips[('%d:%d'):format(s, h)] = { x, y }
            save(L.def.model)
        end
        local m = L.model.seats[s]
        if m and m.hands[h] and m.hands[h].bet == amount then stackChips(L, s, h, amount, x, y, tx, ty, z) end
    end)
end

--- Everything at a table put where it belongs now (a new layout arrived).
local function refresh(L)
    for key, ent in pairs(L.cards) do
        local s, h, i = key:match('^(%d+):(%d+):(%d+)$')
        s, h, i = tonumber(s), tonumber(h), tonumber(i)
        if s and DoesEntityExist(ent) then
            local at, heading = CardSpot(L, s, h, i)
            local faceDown = (s == 0 and i == 1 and L.model.dealer[1] == false)
            moveTo(ent, at, heading, faceDown)
            L.placed[key] = at
        end
    end
    for s, m in pairs(L.model.seats) do
        for h, hand in ipairs(m.hands) do
            local x, y, tx, ty, z = ChipSpot(L, s, h)
            stackChips(L, s, h, hand.bet, x, y, tx, ty, z)
        end
    end
    if L.dealer and DoesEntityExist(L.dealer) then
        local at, heading, lift = DealerSpot(L)
        SetEntityCoordsNoOffset(L.dealer, at.x, at.y, at.z + lift, false, false, false)
        SetEntityHeading(L.dealer, heading)
    end
end

-- Every saved layout, once at start (and after a whip_core restart).
Whip.register(function()
    CreateThread(function()
        local all = exports.whip_core:Callback('whip_casino:blackjack:layouts')
        if type(all) ~= 'table' then return end
        Layouts = all
        for _, L in pairs(Live) do refresh(L) end
    end)
end)

RegisterNetEvent('whip_casino:blackjack:layout', function(model, data)
    if type(model) ~= 'string' then return end
    Layouts[model] = type(data) == 'table' and data or nil
    for _, L in pairs(Live) do
        if L.def.model == model then refresh(L) end
    end
end)

local function clearSeat(L, s)
    for key, ent in pairs(L.cards) do
        if key:match('^' .. s .. ':') then gone(ent) L.cards[key] = nil L.placed[key] = nil end
    end
    for key, list in pairs(L.chips) do
        if key:match('^' .. s .. ':') then
            for _, e in ipairs(list) do gone(e) end
            L.chips[key] = nil
        end
    end
    if s == 0 then L.model.dealer = {} else L.model.seats[s] = nil end
end

local function clearAll(L)
    for s = 0, SEATS do clearSeat(L, s) end
end

-- ============================================
-- The dealer
-- ============================================

local function dealerIdle(L)
    local n, only = 0, nil
    for s = 1, SEATS do if L.model.taken[s] then n, only = n + 1, s end end
    if n == 1 then return 'idle_single_p0' .. Cards.animSeat(only) end
    return 'dealer_idle'
end

-- A female dealer's own moves, where the game has them; else the male set (the same skeleton, it plays fine).
local FEMALE = {
    bj     = 'anim_casino_b@amb@casino@games@blackjack@dealer_female',
    shared = 'anim_casino_b@amb@casino@games@shared@dealer@female',
}

local function dictsFor(female)
    local d = { bj = DICT.bj, shared = DICT.shared, tcp = DICT.tcp }
    if female then
        for k, name in pairs(FEMALE) do
            if DoesAnimDictExist(name) then d[k] = name end
        end
    end
    return d
end

local function playDealer(L, anim, dictKey)
    local ped = L.dealer
    if not ped or not DoesEntityExist(ped) then return end
    local D = L.dicts or DICT
    L.token = (L.token or 0) + 1
    local mine = L.token
    CreateThread(function()
        local dict = D[dictKey or 'bj'] or D.bj
        if anim == 'idle' then anim, dict = dealerIdle(L), D.shared end
        if not exports.whip_core:LoadAnimDict(dict) then return end
        if L.token ~= mine or not DoesEntityExist(ped) then return end
        local loopIdle = dict == D.shared and (anim == 'dealer_idle' or anim:find('^idle_single'))
        TaskPlayAnim(ped, dict, anim, 3.0, -3.0, -1, loopIdle and 1 or 0, 0.0, false, false, false)
        if loopIdle then return end
        local ms = math.floor(GetAnimDuration(dict, anim) * 1000)
        Wait(math.max(500, ms - 150))
        if L.token ~= mine then return end
        if exports.whip_core:LoadAnimDict(D.shared) and DoesEntityExist(ped) then
            TaskPlayAnim(ped, D.shared, dealerIdle(L), 3.0, -3.0, -1, 1, 0.0, false, false, false)
        end
    end)
end

local function speak(L, line)
    if L.dealer and DoesEntityExist(L.dealer) then
        PlayPedAmbientSpeechWithVoiceNative(L.dealer, line, L.voice, 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR', false)
    end
end

-- The same numbers from the same seed in every game (math.random would differ from game to game).
local function seeded(seed)
    local state = (tonumber(seed) or 1) % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function(n)
        state = (state * 48271) % 2147483647
        return (state % n) + 1
    end
end

-- A face, hair and the textures of the rest from the seed: a different dealer, in the model's own uniform.
local function dress(ped, seed)
    SetPedDefaultComponentVariation(ped)
    local roll = seeded(seed)
    for _, c in ipairs({ 0, 2 }) do   -- head, hair: any of the model's
        local n = GetNumberOfPedDrawableVariations(ped, c)
        if n > 0 then
            local d = roll(n) - 1
            local t = GetNumberOfPedTextureVariations(ped, c, d)
            SetPedComponentVariation(ped, c, d, t > 0 and (roll(t) - 1) or 0, 0)
        end
    end
    for _, c in ipairs({ 3, 4 }) do   -- torso, legs: their colour only, so the uniform stays a uniform
        local d = GetPedDrawableVariation(ped, c)
        local t = GetNumberOfPedTextureVariations(ped, c, d)
        if t > 1 then SetPedComponentVariation(ped, c, d, roll(t) - 1, 0) end
    end
end

local function makeDealer(L, look)
    look = type(look) == 'table' and look or { pick = ((L.id - 1) % #Config.Dealers) + 1, seed = L.id }
    local pick = Config.Dealers[look.pick] or Config.Dealers[1]
    local hash = model(pick.model)
    if not hash then
        return print(('[whip_casino:blackjack] table %d: the dealer model %s would not load'):format(L.id, pick.model))
    end
    local at, heading, lift = DealerSpot(L)
    -- A ped's position is its hips, not its feet: the floor is the table's origin, so up by the hips' height.
    local z = at.z + lift
    local ped = CreatePed(4, hash, at.x, at.y, z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then
        return print(('[whip_casino:blackjack] table %d: the dealer could not be made'):format(L.id))
    end
    intoRoom(L, ped)
    SetEntityCoordsNoOffset(ped, at.x, at.y, z, false, false, false)
    SetEntityHeading(ped, heading)
    dress(ped, look.seed)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    FreezeEntityPosition(ped, true)
    L.dealer, L.voice = ped, pick.voice
    L.dicts = dictsFor(pick.female)
    playDealer(L, 'idle')
end

-- ============================================
-- What the server says
-- ============================================

local function apply(L, kind, d, live)
    if kind == 'seat' then
        L.model.taken[d.seat] = d.src or nil
    elseif kind == 'chips' then
        local m = seatModel(L, d.seat)
        m.hands[d.hand] = m.hands[d.hand] or { cards = {}, bet = 0 }
        m.hands[d.hand].bet = d.amount
        chipsAt(L, d.seat, d.hand, d.amount, live and d.anim or nil)
        if d.amount == 0 and d.hand == 1 and #m.hands[1].cards == 0 and not m.hands[2] then L.model.seats[d.seat] = nil end
    elseif kind == 'card' then
        local h = (d.seat == 0) and 1 or d.hand
        if d.seat == 0 then
            L.model.dealer[d.index] = d.card
        else
            local m = seatModel(L, d.seat)
            m.hands[h] = m.hands[h] or { cards = {}, bet = 0 }
            m.hands[h].cards[d.index] = d.card
        end
        local key = cardKey(d.seat, h, d.index)
        gone(L.cards[key])
        L.cards[key], L.placed[key] = nil, nil
        if live then dealCard(L, d.seat, h, d.index, d.card, d.anim)
        else placeCard(L, d.seat, h, d.index, d.card) end
    elseif kind == 'reveal' then
        L.model.dealer[1] = d.card
        placeCard(L, 0, 1, 1, d.card)
    elseif kind == 'split' then
        local m = L.model.seats[d.seat]
        if not m or not m.hands[1].cards[2] or (m.hands[2] and #m.hands[2].cards > 0) then return end
        local card = table.remove(m.hands[1].cards, 2)
        m.hands[2] = m.hands[2] or { cards = {}, bet = m.hands[1].bet }
        m.hands[2].cards[1] = card
        -- The second card goes across to the new hand: carried by the dealer's split animation.
        local ent = L.cards[cardKey(d.seat, 1, 2)]
        L.cards[cardKey(d.seat, 1, 2)], L.placed[cardKey(d.seat, 1, 2)] = nil, nil
        gone(ent)
        if live then dealCard(L, d.seat, 2, 1, card, d.anim) else placeCard(L, d.seat, 2, 1, card) end
    elseif kind == 'clear' then
        if d.all then clearAll(L) else clearSeat(L, d.seat) end
    elseif kind == 'dealer' then
        playDealer(L, d.anim, d.dict)
    elseif kind == 'speech' then
        speak(L, d.line)
    end
end

RegisterNetEvent('whip_casino:blackjack:fx', function(id, kind, d)
    local L = Live[id]
    if not L or type(d) ~= 'table' then return end
    if not L.ready then
        L.queue[#L.queue + 1] = { kind, d }
        return
    end
    apply(L, kind, d, true)
end)

local function fromSnapshot(L, snap)
    clearAll(L)
    L.model.taken = {}
    for _, e in ipairs(snap.seats or {}) do L.model.taken[e.seat] = e.src end
    for _, e in ipairs(snap.hands or {}) do
        for h, hand in ipairs(e.hands) do
            apply(L, 'chips', { seat = e.seat, hand = h, amount = hand.bet }, false)
            for i, card in ipairs(hand.cards) do apply(L, 'card', { seat = e.seat, hand = h, index = i, card = card }, false) end
        end
    end
    for i, card in ipairs(snap.dealer or {}) do apply(L, 'card', { seat = 0, hand = 1, index = i, card = card or false }, false) end
end

-- ============================================
-- Near and far
-- ============================================

local function findTable(def)
    local hash = joaat(def.model)
    if def.spawn then
        local h = model(def.model)
        if not h then return nil end
        local obj = CreateObject(h, def.coords.x, def.coords.y, def.coords.z, false, false, false)
        SetModelAsNoLongerNeeded(h)
        SetEntityHeading(obj, def.heading or 0.0)
        FreezeEntityPosition(obj, true)
        if def.texture then SetObjectTextureVariation(obj, def.texture) end
        return obj, true
    end
    local obj = GetClosestObjectOfType(def.coords.x, def.coords.y, def.coords.z, 1.5, hash, false, false, false)
    if obj ~= 0 then
        if def.texture then SetObjectTextureVariation(obj, def.texture) end
        return obj, false
    end
    return nil
end

-- The seat (as the dealer numbers them) that a chair is.
local function seatAtChair(L, c)
    for s = 1, SEATS do if chairOf(L, s) == c then return s end end
    return c
end

-- A "Sit down" on each chair, while it's free. Which seat a chair is gets asked when it's chosen, so a learnt chair
-- order is used at once.
local function chairPrompts(L)
    for c = 1, SEATS do
        local p = L.frame.chairs[c]
        local at = world(L, p.x, p.y, p.z + 0.85)
        exports.whip_core:AddAction({
            id = ('blackjack_%d_%d'):format(L.id, c),
            group = 'blackjack_' .. L.id,
            at = { coords = at },
            label = 'Sit down',
            icon = 'dollar',
            reach = 1.6,
            focusMode = 'aim',
            canInteract = function()
                return Seated == nil and not L.model.taken[seatAtChair(L, c)]
            end,
            onSelect = function() SitDown(L.id, seatAtChair(L, c)) end,
        })
    end
end

local function goLive(id, def)
    local obj, owned = findTable(def)
    if not obj then return end
    local L = {
        id = id, def = def, obj = obj, owned = owned, learn = learnFor(def.model),
        model = { seats = {}, dealer = {}, taken = {} }, cards = {}, chips = {}, placed = {},
        ready = false, queue = {},
    }
    Live[id] = L
    buildFrame(L)
    chairPrompts(L)
    local snap = exports.whip_core:Callback('whip_casino:blackjack:snapshot', id)
    if Live[id] ~= L then return end
    -- The dealer the server chose for this table this time (the same in every game).
    makeDealer(L, type(snap) == 'table' and snap.look or nil)
    if type(snap) == 'table' then fromSnapshot(L, snap) end
    L.ready = true
    for _, q in ipairs(L.queue) do apply(L, q[1], q[2], false) end
    L.queue = {}
end

local function goDark(id)
    local L = Live[id]
    if not L then return end
    Live[id] = nil
    exports.whip_core:RemoveActionGroup('blackjack_' .. id)
    clearAll(L)
    gone(L.dealer)
    if L.owned then gone(L.obj) end
end

CreateThread(function()
    while true do
        local here = GetEntityCoords(PlayerPedId())
        for id, def in ipairs(Config.Tables) do
            local d = #(here - vector3(def.coords.x, def.coords.y, def.coords.z))
            if d <= Config.DrawRange and not Live[id] then
                goLive(id, def)
            elseif d > Config.DrawRange + 10.0 and Live[id] and not (Seated and Seated.table == id) then
                goDark(id)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Live) do goDark(id) end
end)

-- For client/editor.lua.
BJ = {
    world = world, toLocal = toLocal, makeProp = makeProp, gone = gone, moveTo = moveTo, flat = flat,
    chairOf = chairOf, refresh = refresh, intoRoom = intoRoom,
}

-- ============================================
-- /bjlayout: every spot drawn, for tuning Config.Layout
-- ============================================

local showLayout = false
RegisterCommand('bjlayout', function()
    showLayout = not showLayout
    if not showLayout then return end
    CreateThread(function()
        while showLayout do
            local here = GetEntityCoords(PlayerPedId())
            for _, L in pairs(Live) do
                if #(here - GetEntityCoords(L.obj)) < 10.0 then
                    local function dot(p, r, g, b) DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.025, 0.025, 0.025, r, g, b, 220, false, false, 2, false, nil, nil, false) end
                    for s = 1, SEATS do
                        local chair = ChairSpot(L, s)
                        DrawMarker(1, chair.x, chair.y, chair.z, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.05, 96, 165, 250, 160, false, false, 2, false, nil, nil, false)
                        for i = 1, 3 do dot((CardSpot(L, s, 1, i)), 255, 255, 255) end
                        local x, y = ChipSpot(L, s, 1)
                        dot(world(L, x, y, LY.surface), 250, 204, 21)
                    end
                    for i = 1, 3 do dot((CardSpot(L, 0, 1, i)), 248, 113, 113) end
                    local d = DealerSpot(L)
                    DrawMarker(1, d.x, d.y, d.z, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.05, 248, 113, 113, 160, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end)
end, false)
