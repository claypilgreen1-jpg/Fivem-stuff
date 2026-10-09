const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'esx_multicharacter';
const $ = (id) => document.getElementById(id);

let characters = {};
let slots = 4;
let selected = 1;
let canDelete = true;
let identity = {};
let sex = 'm';
let scenes = [];
let sceneChoice = 'random';
let switchingScene = false;

const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify(data),
}).catch(() => {});

const money = (n) => `$${Number(n || 0).toLocaleString('en-US')}`;
const fullName = (c) => `${c.firstname} ${c.lastname}`.trim();

function renderSlots() {
  const list = $('slots');
  list.innerHTML = '';
  const used = Object.keys(characters).length;
  $('slot-count').textContent = `${used} of ${slots} slots used`;
  for (let i = 1; i <= slots; i++) {
    const c = characters[i];
    const el = document.createElement('div');
    el.className = `slot${c ? '' : ' empty'}${i === selected ? ' active' : ''}`;
    el.innerHTML = `<div class="num">${i}</div><div><div class="who"></div><div class="sub"></div></div>`;
    el.querySelector('.who').textContent = c ? fullName(c) : 'Create new character';
    el.querySelector('.sub').textContent = c ? [c.job, c.grade].filter(Boolean).join(' · ') : 'Empty slot';
    el.addEventListener('click', () => select(i));
    list.append(el);
  }
}

function renderDetails() {
  const c = characters[selected];
  $('details').classList.toggle('hidden', !c);
  if (!c) return;
  $('d-slot').textContent = `Character ${c.slot}`;
  $('d-name').innerHTML = '';
  const [first, ...rest] = fullName(c).split(' ');
  $('d-name').append(first, document.createElement('br'), rest.join(' '));
  $('d-meta').textContent = [c.sex === 'f' ? 'Female' : 'Male', c.height ? `${c.height} cm` : ''].filter(Boolean).join(' · ');
  $('d-job').textContent = [c.job, c.grade].filter(Boolean).join(' · ');
  $('d-born').textContent = c.dateofbirth || '-';
  $('d-cash').textContent = money(c.money);
  $('d-bank').textContent = money(c.bank);
  $('btn-delete').classList.toggle('hidden', !canDelete);
  $('btn-play').disabled = !!c.disabled;
  $('d-disabled').classList.toggle('hidden', !c.disabled);
}

function select(slot) {
  selected = slot;
  renderSlots();
  renderDetails();
  if (characters[slot]) {
    post('preview', { slot });
  } else {
    openCreate();
  }
}

/* ---------- Create ---------- */
function setSex(value) {
  sex = value;
  document.querySelectorAll('.sex-btn').forEach((b) => b.classList.toggle('active', b.dataset.sex === value));
  post('previewSex', { sex: value });
}

function openCreate() {
  const form = $('create-form');
  form.reset();
  $('create-error').classList.add('hidden');
  const today = new Date();
  const iso = (years) => new Date(today.getFullYear() - years, today.getMonth(), today.getDate()).toISOString().slice(0, 10);
  form.dateofbirth.max = iso(identity.minAge || 18);
  form.dateofbirth.min = iso(identity.maxAge || 90);
  form.height.min = identity.minHeight || 140;
  form.height.max = identity.maxHeight || 210;
  form.height.value = 178;
  form.firstname.maxLength = form.lastname.maxLength = identity.maxNameLength || 16;
  $('create').classList.remove('hidden');
  setSex('m');
  form.firstname.focus();
}

function closeCreate() {
  $('create').classList.add('hidden');
  const first = Object.keys(characters).map(Number).sort((a, b) => a - b)[0];
  if (first) select(first);
}

document.querySelectorAll('.sex-btn').forEach((b) => b.addEventListener('click', () => setSex(b.dataset.sex)));
$('create-cancel').addEventListener('click', () => {
  if (!Object.keys(characters).length) return; // nothing to go back to
  closeCreate();
});
$('create-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const f = e.target;
  const nameOk = /^[A-Za-z][A-Za-z '\-]*$/;
  if (!nameOk.test(f.firstname.value.trim()) || !nameOk.test(f.lastname.value.trim())) {
    return showError('Names can only use letters, spaces, hyphens and apostrophes.');
  }
  $('create-error').classList.add('hidden');
  post('create', {
    slot: selected,
    character: {
      firstname: f.firstname.value.trim(),
      lastname: f.lastname.value.trim(),
      dateofbirth: f.dateofbirth.value,
      height: Number(f.height.value),
      sex,
    },
  });
});

function showError(message) {
  const el = $('create-error');
  el.textContent = message;
  el.classList.remove('hidden');
}

/* ---------- Play / delete ---------- */
$('btn-play').addEventListener('click', () => post('play', { slot: selected }));

$('btn-delete').addEventListener('click', () => {
  const c = characters[selected];
  if (!c) return;
  $('confirm-text').textContent = `${fullName(c)} and everything they own will be deleted. This can't be undone.`;
  $('confirm-input').value = '';
  $('confirm-ok').disabled = true;
  $('confirm').classList.remove('hidden');
  $('confirm-input').focus();
});
$('confirm-input').addEventListener('input', (e) => {
  const c = characters[selected];
  $('confirm-ok').disabled = !c || e.target.value.trim().toLowerCase() !== fullName(c).toLowerCase();
});
$('confirm-cancel').addEventListener('click', () => $('confirm').classList.add('hidden'));
$('confirm-ok').addEventListener('click', () => {
  $('confirm').classList.add('hidden');
  post('delete', { slot: selected });
});

/* ---------- Settings: background picker ---------- */
function renderSceneOptions() {
  const box = $('scene-options');
  box.innerHTML = '';
  [{ id: 'random', label: 'Random every login' }, ...scenes].forEach((sc) => {
    const b = document.createElement('button');
    b.className = `scene-opt${sc.id === sceneChoice ? ' active' : ''}`;
    b.textContent = sc.label;
    b.disabled = switchingScene;
    b.addEventListener('click', async () => {
      if (switchingScene || sc.id === sceneChoice) return;
      switchingScene = true;
      sceneChoice = sc.id;
      renderSceneOptions();
      try {
        const res = await fetch(`https://${RES}/setScene`, {
          method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
          body: JSON.stringify({ scene: sc.id }),
        }).then((r) => r.json());
        if (res && res.location) {
          $('location-name').textContent = res.location;
          $('location').classList.remove('hidden');
        }
      } catch (e) { /* game didn't answer; keep the old background */ }
      switchingScene = false;
      renderSceneOptions();
    });
    box.append(b);
  });
}

$('btn-settings').addEventListener('click', (e) => {
  e.stopPropagation();
  $('settings').classList.toggle('hidden');
  $('btn-settings').classList.toggle('active', !$('settings').classList.contains('hidden'));
});
document.addEventListener('click', (e) => {
  if (!e.target.isConnected) return; // the options list was just redrawn under the click
  if (!$('settings').contains(e.target) && e.target !== $('btn-settings')) {
    $('settings').classList.add('hidden');
    $('btn-settings').classList.remove('active');
  }
});

/* ---------- Messages from the game ---------- */
window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (action === 'open') {
    characters = {};
    (data.characters || []).forEach((c) => { characters[c.slot] = c; });
    slots = data.slots;
    canDelete = data.canDelete;
    identity = data.identity || {};
    selected = data.selected || 1;
    $('location').classList.toggle('hidden', !data.location);
    $('location-name').textContent = data.location || '';
    scenes = data.scenes || [];
    sceneChoice = data.sceneChoice || 'random';
    $('btn-settings').classList.toggle('hidden', scenes.length < 2);
    $('settings').classList.add('hidden');
    renderSceneOptions();
    $('create').classList.add('hidden');
    $('confirm').classList.add('hidden');
    $('app').classList.remove('hidden');
    renderSlots();
    renderDetails();
    if (!characters[selected]) openCreate();
  } else if (action === 'close') {
    $('app').classList.add('hidden');
  } else if (action === 'error') {
    if (!$('create').classList.contains('hidden')) showError(data.message);
  }
});
