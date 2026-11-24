-- ============================================
-- whip_casino — one resource, five games, each with its own globals
-- ============================================
-- Every game file starts with
--     local _ENV = CasinoGame('blackjack')
-- so the globals a game makes (Config, Tables, Seated, SitDown, Fx...) belong to that game alone: blackjack's
-- Config is not roulette's, and two games can both have a SitDown. Anything a game doesn't make itself (natives,
-- Whip, exports, json, source...) is read through to the real globals, so the game code is as it was on its own.
-- config.lua does the same, one block per game.

local Games = {}

function CasinoGame(name)
    local env = Games[name]
    if env then return env end
    env = setmetatable({ CASINO_GAME = name }, { __index = _G })
    if not IsDuplicityVersion() then
        -- One page for the resource (html/index.html), one frame on it per game: a game's NUI messages are sent
        -- with its name, and the page hands each to that game's own frame, as its page had them before.
        env.SendNUIMessage = function(msg) return SendNUIMessage({ game = name, msg = msg }) end
    end
    Games[name] = env
    return env
end
