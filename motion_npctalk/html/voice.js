const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'motion_npctalk';
const MIN_MS = 400;     // ignore taps on the key
const MAX_MS = 20000;   // stop runaway recordings

let stream = null;
let recorder = null;
let chunks = [];
let startedAt = 0;
let maxTimer = null;

function post(name, data) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

async function getStream() {
  if (stream && stream.getAudioTracks().some((t) => t.readyState === 'live')) return stream;
  stream = await navigator.mediaDevices.getUserMedia({
    audio: { echoCancellation: true, noiseSuppression: true, channelCount: 1 },
  });
  return stream;
}

function pickMime() {
  const options = ['audio/webm;codecs=opus', 'audio/ogg;codecs=opus', 'audio/webm'];
  return options.find((m) => window.MediaRecorder && MediaRecorder.isTypeSupported(m)) || '';
}

function toBase64(blob) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(String(reader.result).split(',')[1] || '');
    reader.readAsDataURL(blob);
  });
}

async function start() {
  if (recorder && recorder.state === 'recording') return;
  try {
    const s = await getStream();
    const mime = pickMime();
    recorder = new MediaRecorder(s, mime ? { mimeType: mime, audioBitsPerSecond: 32000 } : undefined);
    chunks = [];
    recorder.ondataavailable = (e) => { if (e.data && e.data.size) chunks.push(e.data); };
    recorder.onstop = finish;
    recorder.start();
    startedAt = Date.now();
    clearTimeout(maxTimer);
    maxTimer = setTimeout(stop, MAX_MS);
  } catch (err) {
    post('voiceError', { message: `${err.name || 'Error'}: ${err.message || err}` });
  }
}

function stop() {
  clearTimeout(maxTimer);
  if (recorder && recorder.state === 'recording') recorder.stop();
}

async function finish() {
  const ms = Date.now() - startedAt;
  const type = recorder.mimeType || 'audio/webm';
  const blob = new Blob(chunks, { type });
  chunks = [];
  if (ms < MIN_MS || blob.size < 1000) {
    post('voiceClip', { skipped: true });
    return;
  }
  post('voiceClip', { audio: await toBase64(blob), mime: type, ms });
}

async function test() {
  try {
    const s = await getStream();
    const label = s.getAudioTracks()[0]?.label || 'unknown device';
    post('voiceTest', { ok: true, message: `Microphone works (${label}). Recording format: ${pickMime() || 'default'}.` });
  } catch (err) {
    post('voiceTest', { ok: false, message: `${err.name || 'Error'}: ${err.message || err}` });
  }
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'start') start();
  else if (msg.type === 'stop') stop();
  else if (msg.type === 'test') test();
});
