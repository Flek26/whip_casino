local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — client: the casino cashier
-- ============================================
--
-- Each cashier (from the server, placed with /bjcashier) is made in this game while you're near: a ped behind the
-- counter, and a prompt on them to buy or cash in chips. The server checks you're at a cashier and does the money.

local C = Config.Cashier
local NEAR, FAR = 40.0, 50.0

local list = {}   -- from the server: { { id, x, y, z, w, pose } }
local made = {}   -- [id] = { ped, action }
local editing = nil   -- the id /bjcashier's preview stands in for

local function notify(msg, kind) exports.whip_core:Notify(msg, kind or 'inform') end

-- ============================================
-- Buying and cashing in
-- ============================================

local function trade(how)
    CreateThread(function()
        local r = exports.whip_core:Input(how == 'buy' and 'Buy chips' or 'Cash in chips', {
            { label = how == 'buy'
                and ('How many chips? (%s each)'):format(Cards.money(C.buyPrice))
                or ('How many chips? (%s back each)'):format(Cards.money(C.sellPrice)),
              type = 'number', min = C.min, max = C.max, default = how == 'buy' and 1000 or nil },
        })
        if not r then return end
        local amount = math.floor(tonumber(r[1]) or 0)
        if amount < C.min then return notify(('At least %d chips'):format(C.min), 'error') end
        local ok, msg = exports.whip_core:Callback('whip_casino:blackjack:chips', how, amount)
        notify(msg or (ok and 'Done' or 'That didn\'t work'), ok and 'success' or 'error')
    end)
end

-- ============================================
-- The cashiers near you
-- ============================================

local function poseOf(id)
    for _, p in ipairs(C.poses) do if p.id == id then return p end end
    return C.poses[1]
end

-- A cashier ped at a spot, doing a pose. Shared by the real ones and /bjcashier's preview.
local function spawnCashier(x, y, z, w, poseId)
    local hash = exports.whip_core:LoadModel(C.model)
    if not hash then print('[whip_casino:blackjack] the cashier model ' .. C.model .. ' would not load') return nil end
    local ped = CreatePed(4, hash, x, y, z, w, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    -- Inside an MLO: put in the room it stands in, or it isn't drawn.
    local interior = GetInteriorAtCoords(x, y, z)
    if interior ~= 0 then
        local room = GetRoomKeyFromEntity(PlayerPedId())
        if GetInteriorFromEntity(PlayerPedId()) == interior and room ~= 0 then ForceRoomForEntity(ped, interior, room) end
    end
    SetEntityHeading(ped, w)
    SetPedDefaultComponentVariation(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    local pose = poseOf(poseId)
    if pose.scenario then
        -- Played at the spot itself: a sitting one puts them on the seat there (the height is the seat's).
        TaskStartScenarioAtPosition(ped, pose.scenario, x, y, z, w, -1, pose.seat == true, true)
    else
        FreezeEntityPosition(ped, true)
    end
    return ped
end

local function make(c)
    local ped = spawnCashier(c.x, c.y, c.z, c.w, c.pose)
    if not ped then return end

    local action = exports.whip_core:AddAction({
        id = 'bj_cashier_' .. c.id,
        at = { coords = vector3(c.x, c.y, c.z + 1.0) },
        label = C.label,
        icon = 'dollar',
        reach = C.reach,
        focusMode = 'near',
        options = {
            { label = 'Buy chips',     icon = 'dollar', onSelect = function() trade('buy') end },
            { label = 'Cash in chips', icon = 'cash',   onSelect = function() trade('sell') end },
        },
    })
    made[c.id] = { ped = ped, action = action }
end

local function unmake(id)
    local m = made[id]
    if not m then return end
    made[id] = nil
    if m.action then exports.whip_core:RemoveAction(m.action) end
    if DoesEntityExist(m.ped) then DeleteEntity(m.ped) end
end

local function setList(l)
    for id in pairs(made) do unmake(id) end
    list = type(l) == 'table' and l or {}
end

CreateThread(function()
    while true do
        local here = GetEntityCoords(PlayerPedId())
        for _, c in ipairs(list) do
            local d = #(here - vector3(c.x, c.y, c.z))
            if d <= NEAR and not made[c.id] and c.id ~= editing then make(c)
            elseif d > FAR and made[c.id] then unmake(c.id) end
        end
        Wait(1000)
    end
end)

RegisterNetEvent('whip_casino:blackjack:cashiers', setList)

Whip.register(function()
    CreateThread(function()
        local l = exports.whip_core:Callback('whip_casino:blackjack:cashiers')
        if type(l) == 'table' then setList(l) end
    end)
end)

-- ============================================
-- /bjcashier: put one down (the server asks this game, after checking it's a dev)
-- ============================================

-- After the ghost: the cashier as they'll be, doing the pose, to set just so (onto a stool, say).
local function preview(id, spot, poseIdx)
    local x, y, z, w = spot.x, spot.y, spot.z, spot.w or 0.0
    local ped
    local function respawn()
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
        ped = spawnCashier(x, y, z, w, C.poses[poseIdx].id)
        if ped then SetEntityAlpha(ped, 220, false) end
    end
    respawn()
    exports.whip_core:BlockControls('whip_blackjack_cashier', {
        all = true, except = { 0, 1, 2, 30, 31, 32, 33, 34, 35, 199, 200, 245, 249 }, mode = true,
    })
    local saved, lastHint, settle = false, nil, 0
    while true do
        local dt = GetFrameTime()
        local fine = IsDisabledControlPressed(0, 21)
        local function held(c) return IsDisabledControlPressed(0, c) end
        local function hit(c) return IsDisabledControlJustPressed(0, c) end

        -- Pose: the mouse wheel.
        local dir = hit(15) and -1 or (hit(14) and 1 or 0)
        if dir ~= 0 then
            poseIdx = ((poseIdx - 1 + dir) % #C.poses) + 1
            respawn()
        end

        -- Move (the way you look), turn, raise. A scenario is restarted when it settles, not every frame.
        local a = math.rad(GetGameplayCamRot(2).z)
        local fx, fy, rx, ry = -math.sin(a), math.cos(a), math.cos(a), math.sin(a)
        local mf = (held(172) and 1 or 0) - (held(173) and 1 or 0)
        local mr = (held(175) and 1 or 0) - (held(174) and 1 or 0)
        local turn = (held(44) and 1 or 0) - (held(38) and 1 or 0)
        local up = (held(10) and 1 or 0) - (held(11) and 1 or 0)
        if mf ~= 0 or mr ~= 0 or turn ~= 0 or up ~= 0 then
            local speed = (fine and 0.05 or 0.4) * dt
            x, y = x + (fx * mf + rx * mr) * speed, y + (fy * mf + ry * mr) * speed
            z = z + up * (fine and 0.02 or 0.25) * dt
            w = (w + turn * (fine and 15.0 or 70.0) * dt) % 360.0
            if ped and DoesEntityExist(ped) then
                SetEntityCoords(ped, x, y, z, false, false, false, false)
                SetEntityHeading(ped, w)
            end
            settle = GetGameTimer() + 250
        elseif settle > 0 and GetGameTimer() > settle then
            settle = 0
            respawn()
        end

        -- A marker where the spot is, so it's clear even mid-scenario.
        DrawMarker(28, x, y, z, 0, 0, 0, 0, 0, 0, 0.06, 0.06, 0.06, 96, 165, 250, 220, false, false, 2, false, nil, nil, false)

        local hint = ('%s  |  [Scroll] Pose  |  [Arrows] Move  |  [Q][E] Turn  |  [PgUp][PgDn] Height  |  [Shift] Fine  |  [Enter] Save  |  [Backspace] Cancel')
            :format(C.poses[poseIdx].label)
        if hint ~= lastHint then
            lastHint = hint
            exports.whip_core:ShowText(hint, { icon = 'place' })
        end

        if hit(191) then saved = true break end
        if hit(194) then break end
        Wait(0)
    end
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    exports.whip_core:HideText()
    exports.whip_core:UnblockControls('whip_blackjack_cashier')
    if saved then
        TriggerServerEvent('whip_casino:blackjack:placeCashier', id, x, y, z, w, C.poses[poseIdx].id)
    end
end

RegisterNetEvent('whip_casino:blackjack:placeCashier', function()
    CreateThread(function()
        -- Stood beside one already: that one, to move or re-pose. Else a new one, put down with the ghost first.
        local here = GetEntityCoords(PlayerPedId())
        local near, nearD
        for _, c in ipairs(list) do
            local d = #(here - vector3(c.x, c.y, c.z))
            if d < 2.5 and (not nearD or d < nearD) then near, nearD = c, d end
        end
        local id, spot, poseIdx = 0, nil, 1
        if near then
            id, spot = near.id, { x = near.x, y = near.y, z = near.z, w = near.w }
            for i, p in ipairs(C.poses) do if p.id == near.pose then poseIdx = i end end
            editing = near.id
            unmake(near.id)   -- the preview stands in for it
        else
            local why
            spot, why = exports.whip_core:PlacePoint({ model = C.model, ped = true, label = C.label })
            if not spot then
                if why ~= 'cancelled' then notify('Could not place: ' .. tostring(why), 'error') end
                return
            end
        end
        preview(id, spot, poseIdx)
        -- Saved: the server sends the list again. Cancelled: the old one comes back on the next near-check.
        editing = nil
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(made) do unmake(id) end
end)
