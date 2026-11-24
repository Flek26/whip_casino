local _ENV = CasinoGame('blackjack') -- ============================================
-- whip_casino/blackjack — client: playing
-- ============================================
--
-- The prompt at each table, sitting down (the casino's own seat animations, played as networked scenes at the
-- chair so everyone sees them), the keys while seated, the camera over your shoulder, and the panel (html/).
-- The server decides everything: this game only says what the player chose.

local SEAT_DICT = 'anim_casino_b@amb@casino@games@shared@player@'
local PLAY_DICT = 'anim_casino_b@amb@casino@games@blackjack@player'
local K = Config.Keys

Seated = nil   -- { table, seat, chair, heading, bet, hud, camera, hint }

local function notify(msg, kind) exports.whip_core:Notify(msg, kind or 'inform') end

local function nui(msg) SendNUIMessage(msg) end

-- ============================================
-- The chair
-- ============================================

local function scene(dict, anim, loop)
    local S = Seated
    if not S then return end
    local c = S.chair
    local s = NetworkCreateSynchronisedScene(c.x, c.y, c.z, 0.0, 0.0, S.heading, 2, not loop, loop, 1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(PlayerPedId(), s, dict, anim, 2.0, -2.0, 13, 16, 1000.0, 0)
    NetworkStartSynchronisedScene(s)
    return s
end

local function idle()
    if Seated then scene(SEAT_DICT, 'idle_cardgames', true) end
end

local animToken = 0

--- One of the table's moves (a bet, asking for a card, a reaction), then back to sitting.
local function seatAnim(anim, dictKey)
    if not Seated then return end
    local dict = dictKey == 'shared' and SEAT_DICT or PLAY_DICT
    animToken = animToken + 1
    local mine = animToken
    CreateThread(function()
        if not exports.whip_core:LoadAnimDict(dict) or not Seated then return end
        scene(dict, anim, false)
        Wait(math.max(400, math.floor(GetAnimDuration(dict, anim) * 1000) - 100))
        if animToken == mine then idle() end
    end)
end

RegisterNetEvent('whip_casino:blackjack:anim', function(anim, dictKey) seatAnim(anim, dictKey) end)

-- ============================================
-- The camera
-- ============================================

local function cameraOn()
    local S = Seated
    local L = S and Live[S.table]
    if not L then return end
    local h = math.rad(S.heading)
    local fx, fy = -math.sin(h), math.cos(h)
    local pos = vector3(S.chair.x - fx * Config.Camera.back, S.chair.y - fy * Config.Camera.back, S.chair.z + Config.Camera.up)
    local look = FeltMiddle(L)
    local d = look - pos
    local pitch = math.deg(math.atan(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
    local yaw = GetHeadingFromVector_2d(d.x, d.y)
    exports.whip_core:PlayCamera({
        pos = pos, rot = vector3(pitch, 0.0, yaw), fov = Config.Camera.fov,
        exitKey = false, async = true, transitionIn = 600, transitionOut = 600,
    })
    S.camera = true
end

local function cameraOff()
    if Seated and Seated.camera then
        exports.whip_core:StopCamera()
        Seated.camera = false
    end
end

-- ============================================
-- What the keys say
-- ============================================

local function key(k) return exports.whip_core:KeyHint(k.text, k.button) end

local function hintFor(S)
    local H = S.hud or {}
    local parts = {}
    if H.ask == 'insurance' then
        parts[#parts + 1] = key(K.accept) .. ' Insurance ' .. Cards.money(H.cost or 0)
        parts[#parts + 1] = key(K.stand) .. ' No thanks'
    elseif H.ask == 'play' then
        local c = H.choices or {}
        parts[#parts + 1] = key(K.accept) .. ' Hit'
        parts[#parts + 1] = key(K.stand) .. ' Stand'
        if c.double then parts[#parts + 1] = key(K.double) .. ' Double' end
        if c.split then parts[#parts + 1] = key(K.split) .. ' Split' end
        if c.surrender then parts[#parts + 1] = key(K.surrender) .. ' Surrender' end
    elseif (H.phase == 'idle' or H.phase == 'betting') and not H.bet then
        parts[#parts + 1] = key(K.up) .. key(K.down) .. ' Bet'
        parts[#parts + 1] = key(K.min) .. key(K.max) .. ' Min / Max'
        parts[#parts + 1] = key(K.accept) .. ' Place ' .. Cards.money(S.bet)
        parts[#parts + 1] = key(K.leave) .. ' Leave'
    elseif (H.phase == 'idle' or H.phase == 'betting') and H.bet then
        parts[#parts + 1] = key(K.leave) .. ' Take bet back'
    else
        parts[#parts + 1] = key(K.leave) .. ' Leave'
    end
    parts[#parts + 1] = key(K.camera) .. ' Table camera'
    local v = exports.whip_core:KeyHint('V', nil)   -- keyboard only: on a pad that button is the table camera's
    if v ~= '' then parts[#parts + 1] = v .. ' View' end
    return table.concat(parts, '  |  ')
end

local function refreshHint()
    local S = Seated
    if not S then return end
    local text = hintFor(S)
    if text ~= S.hint then
        S.hint = text
        exports.whip_core:ShowText(text, { icon = 'dollar' })
    end
end

-- The server's word on this player arrives while they're still walking to the chair: kept until they've sat.
local lastHud = nil

RegisterNetEvent('whip_casino:blackjack:hud', function(d)
    if type(d) ~= 'table' then return end
    lastHud = d
    local S = Seated
    if not S or d.table ~= S.table then return end
    S.hud = d
    nui({ type = 'hud', hud = d, bet = S.bet })
    refreshHint()
end)

-- ============================================
-- Up and down
-- ============================================

local function standUp(tell)
    local S = Seated
    if not S then return end
    if tell then TriggerServerEvent('whip_casino:blackjack:leave') end
    cameraOff()
    exports.whip_core:HideText()
    exports.whip_core:UnblockControls('whip_blackjack')
    nui({ type = 'hide' })
    local ped = PlayerPedId()
    if not IsEntityDead(ped) and exports.whip_core:LoadAnimDict(SEAT_DICT) then
        local s = scene(SEAT_DICT, 'sit_exit_left', false)
        Seated = nil
        -- Up off the chair, then free: once they're on their feet, or sooner if they set off walking.
        local t0 = GetGameTimer()
        local total = math.max(800, math.floor(GetAnimDuration(SEAT_DICT, 'sit_exit_left') * 1000))
        while GetGameTimer() - t0 < total * 0.75 do
            local phase = 0.0
            local loc = s and NetworkGetLocalSceneFromNetworkId(s) or -1
            if loc ~= -1 then phase = GetSynchronizedScenePhase(loc) end
            if phase >= 0.7 then break end
            local moving = math.abs(GetControlNormal(0, 30)) > 0.3 or math.abs(GetControlNormal(0, 31)) > 0.3
            if moving and GetGameTimer() - t0 > total * 0.35 then break end
            Wait(0)
        end
        if s then NetworkStopSynchronisedScene(s) end
    end
    Seated = nil
    ClearPedTasks(ped)
end

RegisterNetEvent('whip_casino:blackjack:stand', function() standUp(false) end)

local function controls(S)
    local T = Config.Tables[S.table]
    local step = T.step or T.min
    local function pressed(k) return exports.whip_core:IsKeyPressed(k.key, k.pad) end
    while Seated == S do
        local H = S.hud or {}
        local betting = (H.phase == 'idle' or H.phase == 'betting')

        if pressed(K.camera) then
            if S.camera then cameraOff() else cameraOn() end
        end
        -- V: GTA's own views (first person and the rest), so the table camera steps aside.
        if S.camera and IsControlJustPressed(0, 0) then cameraOff() end

        if H.ask == 'insurance' then
            if pressed(K.accept) then TriggerServerEvent('whip_casino:blackjack:act', 'insure')
            elseif pressed(K.stand) then TriggerServerEvent('whip_casino:blackjack:act', 'decline') end
        elseif H.ask == 'play' then
            local c = H.choices or {}
            if pressed(K.accept) then TriggerServerEvent('whip_casino:blackjack:act', 'hit')
            elseif pressed(K.stand) then TriggerServerEvent('whip_casino:blackjack:act', 'stand')
            elseif c.double and pressed(K.double) then TriggerServerEvent('whip_casino:blackjack:act', 'double')
            elseif c.split and pressed(K.split) then TriggerServerEvent('whip_casino:blackjack:act', 'split')
            elseif c.surrender and pressed(K.surrender) then TriggerServerEvent('whip_casino:blackjack:act', 'surrender') end
        elseif betting and not H.bet then
            local bet = S.bet
            if pressed(K.up) then bet = bet + step
            elseif pressed(K.down) then bet = bet - step
            elseif pressed(K.min) then bet = T.min
            elseif pressed(K.max) then bet = T.max end
            bet = math.max(T.min, math.min(T.max, bet))
            if bet ~= S.bet then
                S.bet = bet
                nui({ type = 'bet', bet = bet })
                refreshHint()
            end
            if pressed(K.accept) then TriggerServerEvent('whip_casino:blackjack:bet', S.bet) end
        end

        if pressed(K.leave) and H.ask ~= 'insurance' then
            if betting and H.bet then
                TriggerServerEvent('whip_casino:blackjack:unbet')
            elseif H.ask == 'play' or (H.hands and #H.hands > 0 and not betting) then
                notify('Your hand is stood, and settled with the rest', 'inform')
                standUp(true)
            else
                standUp(true)
            end
        end

        -- Knocked off the chair.
        if #(GetEntityCoords(PlayerPedId()) - S.chair) > Config.LeaveDistance then standUp(true) end
        Wait(0)
    end
end

--- Sits in one seat (as the dealer numbers them) at a table: client/table.lua's chair prompts call it.
function SitDown(tableId, seat)
    if Seated then return end
    local L = Live[tableId]
    if not L then return notify('The table isn\'t ready yet', 'error') end
    local res, why = exports.whip_core:Callback('whip_casino:blackjack:sit', tableId, seat)
    if not res then return notify(why or 'You can\'t sit here', 'error') end

    local chair, heading = ChairSpot(L, res.seat)
    local ped = PlayerPedId()
    -- Walk to where the sit-down animation starts (beside the chair), not into the chair itself: the chair's
    -- in the way, and they'd walk on the spot. Close enough, or stopped getting closer, and the animation takes over.
    if exports.whip_core:LoadAnimDict(SEAT_DICT) then
        local start = GetAnimInitialOffsetPosition(SEAT_DICT, 'sit_enter_left', chair.x, chair.y, chair.z, 0.0, 0.0, heading, 0.0, 2)
        local turn = GetAnimInitialOffsetRotation(SEAT_DICT, 'sit_enter_left', chair.x, chair.y, chair.z, 0.0, 0.0, heading, 0.0, 2)
        if #(GetEntityCoords(ped) - start) > 0.35 then
            TaskGoStraightToCoord(ped, start.x, start.y, start.z, 1.0, 3000, turn.z, 0.05)
            local t0, best, still = GetGameTimer(), math.huge, 0
            while GetGameTimer() - t0 < 3000 do
                Wait(100)
                local d = #(GetEntityCoords(ped).xy - start.xy)
                if d < 0.3 then break end
                if d < best - 0.02 then best, still = d, 0 else still = still + 1 end
                if still >= 4 then break end   -- 0.4 s without getting closer: blocked
            end
        end
    end

    local T = Config.Tables[tableId]
    if lastHud and lastHud.table ~= tableId then lastHud = nil end
    Seated = { table = tableId, seat = res.seat, chair = chair, heading = heading, bet = T.min }
    local S = Seated
    -- Left free: looking (1, 2), GTA's views on V (0, first person among them), pause, chat, push-to-talk.
    exports.whip_core:BlockControls('whip_blackjack', { all = true, except = { 0, 1, 2, 199, 200, 245, 249 }, mode = true })
    if exports.whip_core:LoadAnimDict(SEAT_DICT) then
        scene(SEAT_DICT, 'sit_enter_left', false)
        Wait(math.max(1000, math.floor(GetAnimDuration(SEAT_DICT, 'sit_enter_left') * 1000) - 150))
    end
    if Seated ~= S then return end
    idle()
    nui({ type = 'show', label = T.label or 'Blackjack', min = T.min, max = T.max, bet = S.bet })
    if lastHud and lastHud.table == tableId then
        S.hud = lastHud
        nui({ type = 'hud', hud = lastHud, bet = S.bet })
    end
    if Config.Camera.enabled then cameraOn() end
    refreshHint()
    CreateThread(function() controls(S) end)
end

AddEventHandler('whip_core:player:died', function()
    if Seated then standUp(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not Seated then return end
    cameraOff()
    exports.whip_core:HideText()
    ClearPedTasks(PlayerPedId())
end)
