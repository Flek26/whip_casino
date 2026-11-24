// whip_blackjack: the panel while seated. Lua sends { type: 'show' | 'hud' | 'bet' | 'hide' } (client/play.lua).
// The server's hud says what's true; the timer counts down here from its endsIn.

const $ = (id) => document.getElementById(id);

// whip's scale: its 2560 x 1440 design fitted to the window (whip_core html/js/utils.js).
function applyScale() {
    const s = Math.min(window.innerHeight / 1440, window.innerWidth / 2560);
    document.documentElement.style.setProperty('--ui-scale', s);
}
applyScale();
window.addEventListener('resize', applyScale);

const money = (n) => '$' + Math.floor(Number(n) || 0).toLocaleString('en-US');

let hud = {};
let chosen = 0;          // the bet being picked, before it's placed
let endsAt = 0, span = 0; // the countdown

function esc(t) {
    const d = document.createElement('div');
    d.textContent = t == null ? '' : String(t);
    return d.innerHTML;
}

function title() {
    const h = hud;
    if (h.ask === 'insurance') return ['Insurance?', 'turn'];
    if (h.ask === 'play') return [h.hands && h.hands.length > 1 ? `Your turn: hand ${h.active}` : 'Your turn', 'turn'];
    switch (h.phase) {
        case 'idle':      return [h.result ? resultText(h.result) : (h.bet ? 'Waiting for the deal' : 'Place your bet'), h.result || ''];
        case 'betting':   return [h.bet ? 'Bets closing' : 'Place your bet', ''];
        case 'dealing':   return ['Dealing', ''];
        case 'insurance': return ['Insurance', ''];
        case 'playing':   return [h.hands && h.hands.length ? 'Waiting for the table' : 'Sitting out', ''];
        case 'dealer':    return ["Dealer's turn", ''];
        case 'payout':    return [h.result ? resultText(h.result) : 'Paying out', h.result || ''];
    }
    return ['Blackjack', ''];
}

function resultText(r) {
    return r === 'won' ? 'You won' : r === 'lost' ? 'You lost' : 'Push';
}

function stateTag(hand) {
    const s = hand.state;
    if (hand.natural) return '<span class="bj-tag blackjack">Blackjack</span>';
    if (s === 'bust' || hand.total > 21) return '<span class="bj-tag bust">Bust</span>';
    if (s === 'surrendered') return '<span class="bj-tag">Surrendered</span>';
    if (s === 'stood') return '<span class="bj-tag">Stood</span>';
    return '';
}

function render() {
    const h = hud;
    const [text, tone] = title();
    const t = $('title');
    t.textContent = text;
    t.className = 'bj-title ' + tone;

    // The bet: the one being picked, or the one placed.
    const betEl = $('bet');
    const placing = (h.phase === 'idle' || h.phase === 'betting' || !h.phase) && !h.bet;
    $('bet-row').classList.toggle('hidden', !!(h.hands && h.hands.length));
    betEl.textContent = money(placing ? chosen : h.bet);
    betEl.classList.toggle('pending', placing);
    $('bet-label').textContent = placing ? 'Your bet' : 'Bet placed';

    $('hands').innerHTML = (h.hands || []).map((hand, i) => {
        const total = (hand.soft ? 'soft ' : '') + hand.total;
        const active = h.ask === 'play' && h.active === i + 1 ? ' active' : '';
        const name = h.hands.length > 1 ? `Hand ${i + 1}` : 'Your hand';
        return `<div class="bj-row${active}">
            <span class="bj-hand-left"><span class="bj-label">${esc(name)}</span><span class="bj-hand-bet">${money(hand.bet)}</span></span>
            <span class="bj-hand-right">${stateTag(hand)}<span class="bj-total">${esc(total)}</span></span>
        </div>`;
    }).join('');

    $('dealer-row').classList.toggle('hidden', h.dealer == null);
    $('dealer').textContent = h.dealer == null ? '-' : h.dealer;
}

function tick() {
    const timer = $('timer');
    const left = endsAt - Date.now();
    if (!endsAt || left <= 0) { timer.classList.add('hidden'); return; }
    timer.classList.remove('hidden');
    $('timer-bar').style.width = Math.max(0, Math.min(100, (left / span) * 100)) + '%';
    timer.classList.toggle('low', left < 5000);
}
setInterval(tick, 250);

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'show') {
        hud = { phase: 'idle' };
        chosen = m.bet;
        $('label').textContent = m.label;
        $('limits').textContent = `${money(m.min)} – ${money(m.max)}`;
        $('panel').classList.remove('hidden');
        endsAt = 0;
        render();
    } else if (m.type === 'hud') {
        hud = m.hud || {};
        if (m.bet != null) chosen = m.bet;
        if (hud.endsIn > 0) {
            endsAt = Date.now() + hud.endsIn;
            span = Math.max(hud.span || hud.endsIn, 1);
        } else {
            endsAt = 0;
        }
        render();
        tick();
    } else if (m.type === 'bet') {
        chosen = m.bet;
        render();
    } else if (m.type === 'hide') {
        $('panel').classList.add('hidden');
        hud = {};
        endsAt = 0;
    }
});
