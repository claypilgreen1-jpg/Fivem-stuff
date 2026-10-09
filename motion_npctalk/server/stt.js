// Speech-to-text for NPC conversations.
// Clips recorded by the player's game are sent here, transcribed by a Whisper-style
// /audio/transcriptions endpoint, and the text is handed to server/main.lua.
//
// server.cfg:
//   set npctalk_stt_key "your-stt-api-key"
//   set npctalk_stt_url "https://api.openai.com/v1/audio/transcriptions"   (default)
//   set npctalk_stt_model "whisper-1"                                       (default)
//   set npctalk_stt_language "en"                                           (default; "" = auto-detect)
//
// Any service with the same API shape works (OpenAI, Groq, or a self-hosted faster-whisper server).

const https = require('https');
const http = require('http');
const { URL } = require('url');

const STT_URL = GetConvar('npctalk_stt_url', 'https://api.openai.com/v1/audio/transcriptions');
const STT_KEY = GetConvar('npctalk_stt_key', '');
const STT_MODEL = GetConvar('npctalk_stt_model', 'whisper-1');
const STT_LANGUAGE = GetConvar('npctalk_stt_language', 'en');

const MAX_BASE64 = 1500000; // ~1.1 MB of audio, far more than a 20-second clip needs
const COOLDOWN_MS = 1500;

// Things Whisper tends to "hear" in silence or noise.
const JUNK = [/^thank(s| you)( so much)? for watching/i, /^\W*$/, /^(you|bye\.?|\.+)$/i, /subtitles by/i];

const busy = new Set();
const lastAt = new Map();

if (!STT_KEY && STT_URL.includes('api.openai.com')) {
  console.log('^3[motion_npctalk] Voice is off: set npctalk_stt_key in server.cfg to let NPCs hear players.^0');
}

function status(src, msg) {
  emitNet('motion_npctalk:voiceStatus', src, msg);
}

function transcribe(audio, mime) {
  return new Promise((resolve, reject) => {
    const url = new URL(STT_URL);
    const boundary = `----npctalk${Date.now().toString(16)}`;
    const ext = mime.includes('ogg') ? 'ogg' : mime.includes('wav') ? 'wav' : 'webm';
    const field = (name, value) => Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`);
    const parts = [
      field('model', STT_MODEL),
      field('response_format', 'json'),
    ];
    if (STT_LANGUAGE) parts.push(field('language', STT_LANGUAGE));
    parts.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="clip.${ext}"\r\n` +
      `Content-Type: ${mime}\r\n\r\n`));
    parts.push(audio, Buffer.from(`\r\n--${boundary}--\r\n`));
    const body = Buffer.concat(parts);

    const headers = {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': body.length,
    };
    if (STT_KEY) headers.Authorization = `Bearer ${STT_KEY}`;

    const lib = url.protocol === 'http:' ? http : https;
    const req = lib.request(url, { method: 'POST', headers, timeout: 20000 }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8');
        if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}: ${text.slice(0, 300)}`));
        try {
          resolve(String(JSON.parse(text).text || '').trim());
        } catch (e) {
          reject(new Error(`unreadable response: ${text.slice(0, 200)}`));
        }
      });
    });
    req.on('timeout', () => req.destroy(new Error('timed out')));
    req.on('error', reject);
    req.end(body);
  });
}

onNet('motion_npctalk:voice', async (pedKey, netId, info, base64, mime) => {
  const src = global.source;
  if (typeof base64 !== 'string' || base64.length > MAX_BASE64 || typeof pedKey !== 'number') return;
  if (busy.has(src) || Date.now() - (lastAt.get(src) || 0) < COOLDOWN_MS) return;
  if (!STT_KEY && STT_URL.includes('api.openai.com')) {
    status(src, 'Voice is not set up on this server yet.');
    return;
  }

  mime = typeof mime === 'string' && /^audio\/[\w.+-]+(;.*)?$/.test(mime) ? mime.split(';')[0] : 'audio/webm';
  busy.add(src);
  lastAt.set(src, Date.now());
  try {
    const text = await transcribe(Buffer.from(base64, 'base64'), mime);
    if (!text || JUNK.some((re) => re.test(text))) {
      status(src, "They didn't catch that.");
      emitNet('motion_npctalk:voiceDone', src);
      return;
    }
    emit('motion_npctalk:voiceText', src, pedKey, netId, info, text);
  } catch (err) {
    console.log(`[motion_npctalk] speech-to-text failed: ${err.message}`);
    status(src, "They didn't catch that.");
    emitNet('motion_npctalk:voiceDone', src);
  } finally {
    busy.delete(src);
  }
});

on('playerDropped', () => {
  busy.delete(global.source);
  lastAt.delete(global.source);
});
