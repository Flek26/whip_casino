fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_casino'
description 'The casino on whip: blackjack, three card poker, roulette and the lucky wheel, with the chips and the cashier, in one resource.'
version '0.1.0'
author 'Flek'

-- Each game is a folder of its own, its files starting with local _ENV = CasinoGame('<game>') (shared/env.lua).
-- Blackjack loads first: it registers the chips item the other games bet in.
shared_scripts {
    '@whip_core/lib/satellite.lua',
    'shared/env.lua',
    'config.lua',
    'blackjack/shared/cards.lua',
    'threecard/shared/cards.lua',
    'roulette/shared/wheel.lua',
}

client_scripts {
    'blackjack/client/table.lua',
    'blackjack/client/play.lua',
    'blackjack/client/editor.lua',
    'blackjack/client/cashier.lua',

    'threecard/client/table.lua',
    'threecard/client/play.lua',
    'threecard/client/editor.lua',

    'roulette/client/table.lua',
    'roulette/client/play.lua',
    'roulette/client/editor.lua',

    'luckywheel/client/main.lua',
}

server_scripts {
    'blackjack/server/shoe.lua',
    'blackjack/server/main.lua',
    'blackjack/server/round.lua',
    'blackjack/server/cashier.lua',

    'threecard/server/main.lua',
    'threecard/server/round.lua',

    'roulette/server/main.lua',

    'luckywheel/server/main.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'casinochips.png',
    'blackjack/html/*',
    'threecard/html/*',
    'roulette/html/*',
}

dependency 'whip_core'
whip_requires '1.0'
