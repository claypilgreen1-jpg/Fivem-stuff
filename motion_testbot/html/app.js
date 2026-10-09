const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'motion_testbot';
const $ = (id) => document.getElementById(id);
const toArr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));

let state = { bots: [], selected: false, outfit: false, spots: [] };
let pickedPed = null;
let queue = [];

const WEAPONS = [
  'pistol', 'combatpistol', 'appistol', 'pistol50', 'revolver', 'microsmg', 'smg', 'assaultsmg',
  'assaultrifle', 'carbinerifle', 'specialcarbine', 'pumpshotgun', 'sawnoffshotgun', 'sniperrifle',
  'knife', 'bat', 'crowbar', 'stungun', 'motion_glock17', 'motion_m4a1', 'motion_ak47', 'none',
];
const SCENARIOS = [
  'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_DRINKING', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_CLIPBOARD',
  'WORLD_HUMAN_GUARD_STAND', 'WORLD_HUMAN_COP_IDLES', 'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_LEANING',
  'WORLD_HUMAN_AA_COFFEE', 'WORLD_HUMAN_BUM_STANDING', 'WORLD_HUMAN_DRUG_DEALER', 'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS',
  'WORLD_HUMAN_MUSICIAN', 'WORLD_HUMAN_PARTYING', 'WORLD_HUMAN_SIT_UPS', 'WORLD_HUMAN_PUSH_UPS',
  'WORLD_HUMAN_YOGA', 'WORLD_HUMAN_TOURIST_MAP', 'WORLD_HUMAN_WELDING', 'WORLD_HUMAN_HAMMERING',
  'WORLD_HUMAN_JANITOR', 'WORLD_HUMAN_GARDENER_PLANT', 'WORLD_HUMAN_PAPARAZZI', 'WORLD_HUMAN_CHEERING',
  'PROP_HUMAN_ATM', 'PROP_HUMAN_SEAT_CHAIR', 'PROP_HUMAN_BUM_BIN', 'CODE_HUMAN_MEDIC_KNEEL',
];

// label, task, args(target) -> array, needs a target?
const TASKS = {
  move: [
    ['Follow', 'follow', (t) => [t]],
    ['Stay', 'stay', () => []],
    ['Walk to', 'goto', (t) => [t, 'walk']],
    ['Run to', 'goto', (t) => [t]],
    ['Teleport to', 'tp', (t) => [t]],
    ['Wander', 'wander', () => []],
  ],
  vehicle: [
    ['Spawn car', 'car', () => [$('car-model').value.trim() || 'sultan']],
    ['Drive to', 'drive', (t) => [t]],
    ['Drive fast', 'drive', (t) => [t, 'fast']],
    ['Get in (driver)', 'enter', () => ['driver']],
    ['Get in (passenger)', 'enter', () => ['passenger']],
    ['Get out', 'leave', () => []],
  ],
  crime: [
    ['Victim (calm)', 'victim', () => ['stay', $('victim-secs').value || 8]],
    ['Victim (flee)', 'victim', () => ['flee', $('victim-secs').value || 8]],
    ['Rob target', 'rob', (t) => [t]],
    ['Aim at', 'aim', (t) => [t]],
    ['Shoot at', 'shoot', (t) => [t, 3]],
    ['Attack', 'attack', (t) => [t]],
    ['Hands up', 'handsup', () => []],
    ['Flee from', 'flee', (t) => [t]],
    ['Kneel', 'kneel', () => []],
  ],
  misc: [
    ['Ragdoll', 'ragdoll', () => [3]],
    ['Kill', 'kill', () => []],
    ['Revive', 'revive', () => []],
    ['Stop', 'stop', () => []],
  ],
};

async function post(action, data = {}) {
  try {
    const res = await fetch(`https://${RES}/action`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({ action, ...data }),
    });
    const next = await res.json();
    if (next) applyState(next);
    return next;
  } catch (e) {
    return null;
  }
}

let toastTimer;
function toast(text) {
  const el = $('toast');
  el.textContent = text;
  el.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add('hidden'), 3500);
}

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else if (k === 'text') node.textContent = v;
    else node.setAttribute(k, v);
  }
  for (const child of [].concat(children)) if (child) node.append(child);
  return node;
}

/* ---------- Tabs ---------- */
document.querySelectorAll('#tabs button').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('active', b === btn));
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.id === `tab-${btn.dataset.tab}`));
  });
});

/* ---------- Peds ---------- */
const PEDS = window.PEDS || [];
const categories = [...new Set(PEDS.map((p) => p.c))].sort();
categories.forEach((c) => $('ped-category').append(el('option', { value: c, text: c })));

function pedLabel(p) {
  return p.l || p.n;
}

function renderPeds() {
  const q = $('ped-search').value.trim().toLowerCase();
  const cat = $('ped-category').value;
  const matches = PEDS.filter((p) => (!cat || p.c === cat) && (!q || p.n.includes(q) || p.l.toLowerCase().includes(q)));
  const shown = matches.slice(0, 250);
  $('ped-count').textContent = matches.length > shown.length
    ? `Showing ${shown.length} of ${matches.length}. Search to narrow it down.`
    : `${matches.length} peds`;
  const list = $('ped-list');
  list.replaceChildren(...shown.map((p) => el('div', {
    class: `item${pickedPed === p.n ? ' active' : ''}`,
    onclick: () => { pickedPed = p.n; $('ped-custom').value = ''; renderPeds(); },
    ondblclick: () => post('spawn', { model: p.n }),
  }, [
    el('div', {}, [el('div', { class: 'name', text: pedLabel(p) }), el('div', { class: 'sub', text: `${p.n} · ${p.c}` })]),
  ])));
}

function chosenModel() {
  return $('ped-custom').value.trim().toLowerCase() || pickedPed;
}

$('ped-search').addEventListener('input', renderPeds);
$('ped-category').addEventListener('change', renderPeds);
$('ped-spawn').addEventListener('click', () => {
  const model = chosenModel();
  if (!model) return toast('Pick a ped from the list or type a model name.');
  post('spawn', { model });
});
$('ped-swap').addEventListener('click', () => {
  const model = chosenModel();
  if (!model) return toast('Pick a ped from the list or type a model name.');
  post('changeModel', { model });
});

/* ---------- Outfit ---------- */
// Cycles value through [minValue, max - 1]. minValue -1 adds a "none" option (props).
function stepper(value, max, onChange, minValue = 0) {
  const range = max - minValue;
  const text = max <= 0 ? '-' : value < 0 ? 'none' : `${value + 1} / ${max}`;
  const step = (delta) => onChange(((value - minValue + delta + range) % range) + minValue);
  const disabled = range <= 1 ? { disabled: '' } : {};
  return el('div', { class: 'ctl' }, [
    el('button', { text: '‹', onclick: () => step(-1), ...disabled }),
    el('span', { text }),
    el('button', { text: '›', onclick: () => step(1), ...disabled }),
  ]);
}

function outfitRow(kind, item) {
  const isProp = kind === 'prop';
  const minDrawable = isProp ? -1 : 0;
  const drawableCtl = stepper(item.drawable, item.maxDrawable, (v) => {
    post('outfitSet', { kind, id: item.id, drawable: v, texture: 0 });
  }, minDrawable);
  const textureCtl = stepper(item.texture, item.maxTexture, (v) => {
    post('outfitSet', { kind, id: item.id, drawable: item.drawable, texture: v });
  });
  return el('div', { class: 'stepper' }, [
    el('div', { class: 'label', text: item.label }),
    drawableCtl,
    textureCtl,
  ]);
}

function currentBot() {
  return toArr(state.bots).find((b) => b.id === state.selected);
}

function presetKey() {
  const bot = currentBot();
  return bot ? bot.model : null;
}

function loadPresets() {
  try { return JSON.parse(localStorage.getItem('tb_presets') || '{}'); } catch (e) { return {}; }
}

function savePresets(all) {
  try { localStorage.setItem('tb_presets', JSON.stringify(all)); } catch (e) { /* storage unavailable */ }
}

function renderPresets() {
  const key = presetKey();
  const presets = key ? (loadPresets()[key] || {}) : {};
  $('preset-list').replaceChildren(...Object.keys(presets).map((name) => el('span', { class: 'chip' }, [
    el('span', { text: name, style: 'cursor:pointer', onclick: () => post('outfitApply', { preset: presets[name] }) }),
    el('button', {
      text: '✕',
      onclick: () => {
        const all = loadPresets();
        delete all[key][name];
        savePresets(all);
        renderPresets();
      },
    }),
  ])));
}

$('preset-save').addEventListener('click', () => {
  const key = presetKey();
  const name = $('preset-name').value.trim();
  if (!key || !state.outfit) return toast('Select a bot first.');
  if (!name) return toast('Give the outfit a name.');
  const pick = (list) => toArr(list).map((i) => ({ id: i.id, drawable: i.drawable, texture: i.texture }));
  const all = loadPresets();
  all[key] = all[key] || {};
  all[key][name] = { components: pick(state.outfit.components), props: pick(state.outfit.props) };
  savePresets(all);
  $('preset-name').value = '';
  renderPresets();
  toast(`Saved "${name}".`);
});

function renderOutfit() {
  const outfit = state.outfit;
  $('outfit-empty').classList.toggle('hidden', !!outfit);
  $('outfit-body').classList.toggle('hidden', !outfit);
  if (!outfit) return;
  $('outfit-components').replaceChildren(...toArr(outfit.components).map((c) => outfitRow('component', c)));
  const props = toArr(outfit.props);
  $('outfit-props').replaceChildren(...(props.length
    ? props.map((p) => outfitRow('prop', p))
    : [el('div', { class: 'muted', text: 'This ped has no accessories.' })]));
  renderPresets();
}

$('outfit-random').addEventListener('click', () => post('outfitRandom'));
$('outfit-default').addEventListener('click', () => post('outfitDefault'));

/* ---------- Tasks ---------- */
function renderTargets() {
  const select = $('task-target');
  const prev = select.value || 'me';
  const options = [['me', 'Me'], ['ped', 'Nearest ped'], ['waypoint', 'My waypoint']];
  toArr(state.bots).forEach((b) => {
    if (b.id !== state.selected) options.push([`bot:${b.id}`, `Bot ${b.id} (${b.model})`]);
  });
  select.replaceChildren(...options.map(([v, t]) => el('option', { value: v, text: t })));
  select.value = options.some(([v]) => v === prev) ? prev : 'me';
}

function runStep(name, args) {
  const step = { name, args };
  if ($('queue-mode').checked) {
    queue.push(step);
    renderQueue();
  } else {
    post('run', { steps: [step], all: $('apply-all').checked });
  }
}

function renderQueue() {
  $('queue-chips').replaceChildren(...queue.map((s, i) => el('span', { class: 'chip' }, [
    el('span', { text: [s.name, ...s.args].join(' ') }),
    el('button', { text: '✕', onclick: () => { queue.splice(i, 1); renderQueue(); } }),
  ])));
  if (!queue.length) $('queue-chips').append(el('span', { class: 'muted', text: 'Click tasks to add them in order.' }));
}

Object.entries(TASKS).forEach(([group, tasks]) => {
  const grid = document.querySelector(`.grid[data-group="${group}"]`);
  tasks.forEach(([label, task, args]) => {
    grid.append(el('button', { text: label, onclick: () => runStep(task, args($('task-target').value)) }));
  });
});

$('queue-mode').addEventListener('change', () => {
  $('queue-box').classList.toggle('hidden', !$('queue-mode').checked);
  renderQueue();
});
$('queue-run').addEventListener('click', () => {
  if (!queue.length) return toast('The queue is empty.');
  post('run', { steps: queue, all: $('apply-all').checked });
});
$('queue-clear').addEventListener('click', () => { queue = []; renderQueue(); });

WEAPONS.forEach((w) => $('weapon-select').append(el('option', { value: w, text: w })));
SCENARIOS.forEach((s) => $('scenario-select').append(el('option', { value: s, text: s.replace(/_/g, ' ').toLowerCase() })));
$('weapon-give').addEventListener('click', () => runStep('weapon', [$('weapon-select').value]));
$('scenario-play').addEventListener('click', () => runStep('scenario', [$('scenario-select').value]));
$('anim-play').addEventListener('click', () => {
  const dict = $('anim-dict').value.trim();
  const name = $('anim-name').value.trim();
  if (!dict || !name) return toast('Enter an animation dict and name.');
  runStep('anim', $('anim-upper').checked ? [dict, name, 'upper'] : [dict, name]);
});
$('wait-add').addEventListener('click', () => runStep('wait', [$('wait-secs').value || 3]));

/* ---------- Bots ---------- */
function renderBots() {
  const bots = toArr(state.bots);
  const list = $('bot-list');
  if (!bots.length) {
    list.replaceChildren(el('div', { class: 'empty', text: 'No bots yet. Spawn one from the Peds tab.' }));
    return;
  }
  list.replaceChildren(...bots.map((b) => el('div', {
    class: `item${b.id === state.selected ? ' active' : ''}`,
    onclick: () => post('select', { id: b.id }),
  }, [
    el('div', {}, [
      el('div', { class: 'name', text: `Bot ${b.id}` }),
      el('div', { class: 'sub', text: `${b.model} · ${b.status}` }),
    ]),
    el('div', { class: 'actions' }, [
      el('button', { text: b.invincible ? 'God ✓' : 'God', title: 'Invincible', onclick: (e) => { e.stopPropagation(); post('setFlag', { id: b.id, flag: 'invincible', value: !b.invincible }); } }),
      el('button', { text: b.frozen ? 'Frozen ✓' : 'Freeze', onclick: (e) => { e.stopPropagation(); post('setFlag', { id: b.id, flag: 'frozen', value: !b.frozen }); } }),
      el('button', { text: 'To me', onclick: (e) => { e.stopPropagation(); post('botToMe', { id: b.id }); } }),
      el('button', { text: 'Go to', onclick: (e) => { e.stopPropagation(); post('meToBot', { id: b.id }); } }),
      el('button', { text: '✕', class: 'danger', title: 'Dismiss', onclick: (e) => { e.stopPropagation(); post('dismiss', { id: b.id }); } }),
    ]),
  ])));
}

$('bots-dismiss-all').addEventListener('click', () => post('dismissAll'));

/* ---------- Camera ---------- */
function renderSpots() {
  $('spot-list').replaceChildren(...toArr(state.spots).map((name) => el('div', { class: 'item' }, [
    el('div', { class: 'name', text: name }),
    el('div', { class: 'actions' }, [el('button', { text: 'Shoot', onclick: () => post('tour', { spot: name }) })]),
  ])));
  $('cam-toggle').textContent = state.freecam ? 'Exit free cam' : 'Free cam';
}

$('cam-toggle').addEventListener('click', () => post('freecam'));
$('cam-photo').addEventListener('click', () => post('photo'));
$('tour-all').addEventListener('click', () => post('tour'));
$('tour-stop').addEventListener('click', () => post('tourStop'));
$('spot-save').addEventListener('click', () => post('saveSpot', { name: $('spot-name').value.trim() }));

/* ---------- Events ---------- */
$('event-fire').addEventListener('click', () => {
  const name = $('event-name').value.trim();
  if (!name) return toast('Enter an event name.');
  post('event', { side: $('event-side').value, name, args: $('event-args').value });
});

/* ---------- State ---------- */
function applyState(next) {
  state = next;
  const bot = currentBot();
  $('selected-label').textContent = bot ? `· Bot ${bot.id} (${bot.model})` : '· no bot selected';
  renderOutfit();
  renderTargets();
  renderBots();
  renderSpots();
}

function show(open) {
  $('app').classList.toggle('hidden', !open);
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'open') { show(true); applyState(msg.state); renderPeds(); }
  else if (msg.type === 'close') show(false);
  else if (msg.type === 'state') {
    // Don't rebuild the outfit list on the timer, only bot statuses, so clicks never land on a redrawn row.
    const outfit = state.outfit;
    applyStateLight(msg.state, outfit);
  } else if (msg.type === 'toast') toast(msg.text);
});

function applyStateLight(next, outfit) {
  const sameBot = next.selected === state.selected;
  state = { ...next, outfit: sameBot ? outfit : next.outfit };
  if (!sameBot) renderOutfit();
  renderBots();
  renderTargets();
  $('cam-toggle').textContent = state.freecam ? 'Exit free cam' : 'Free cam';
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') post('close');
});

$('close').addEventListener('click', () => post('close'));
renderQueue();
