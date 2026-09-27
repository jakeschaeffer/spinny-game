// Synthesized sound effects via Web Audio (no asset files needed).
// iOS only lets audio start inside a user gesture, so `unlockAudio` is called
// from input handlers and also plays a silent buffer the first time.

let ctx = null;
let master = null;
let noise = null;
let unlocked = false;
let enabled = true;

function ensureContext() {
  if (ctx) return ctx;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return null;
  ctx = new AudioContextClass();
  const compressor = ctx.createDynamicsCompressor();
  master = ctx.createGain();
  master.gain.value = 0.55;
  master.connect(compressor);
  compressor.connect(ctx.destination);

  noise = ctx.createBuffer(1, ctx.sampleRate * 0.4, ctx.sampleRate);
  const data = noise.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
  return ctx;
}

export function unlockAudio() {
  try {
    if (!ensureContext()) return;
    if (ctx.state !== 'running') ctx.resume();
    if (!unlocked) {
      const source = ctx.createBufferSource();
      source.buffer = ctx.createBuffer(1, 1, 22050);
      source.connect(ctx.destination);
      source.start(0);
      unlocked = true;
    }
  } catch {
    // Audio unavailable; the game still works silently.
  }
}

export function setSoundEnabled(value) {
  enabled = value;
}

function tone({ freq, to = freq, dur, type = 'sine', vol = 0.2, delay = 0 }) {
  const t = ctx.currentTime + delay;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t);
  if (to !== freq) osc.frequency.exponentialRampToValueAtTime(to, t + dur);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(vol, t + 0.006);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  osc.connect(gain);
  gain.connect(master);
  osc.start(t);
  osc.stop(t + dur + 0.02);
}

function burst({ dur, vol, from, to }) {
  const t = ctx.currentTime;
  const source = ctx.createBufferSource();
  const filter = ctx.createBiquadFilter();
  const gain = ctx.createGain();
  source.buffer = noise;
  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(from, t);
  filter.frequency.exponentialRampToValueAtTime(to, t + dur);
  gain.gain.setValueAtTime(vol, t);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  source.connect(filter);
  filter.connect(gain);
  gain.connect(master);
  source.start(t);
  source.stop(t + dur);
}

function play(fn) {
  if (!enabled || !ctx || ctx.state !== 'running') return;
  try {
    fn();
  } catch {
    // Ignore audio errors so they never interrupt gameplay.
  }
}

export const sfx = {
  hook(combo = 1) {
    play(() => {
      const step = Math.min(combo - 1, 12);
      const freq = 520 * Math.pow(2, (step * 2) / 12);
      tone({ freq, dur: 0.14, type: 'triangle', vol: 0.22 });
      tone({ freq: freq * 2, dur: 0.1, vol: 0.06 });
    });
  },
  launch() {
    play(() => {
      tone({ freq: 280, to: 720, dur: 0.13, vol: 0.1 });
      burst({ dur: 0.12, vol: 0.05, from: 3000, to: 800 });
    });
  },
  death() {
    play(() => {
      tone({ freq: 240, to: 50, dur: 0.5, type: 'sawtooth', vol: 0.14 });
      burst({ dur: 0.35, vol: 0.25, from: 2500, to: 150 });
    });
  },
  best() {
    play(() => {
      [523, 659, 784, 1047].forEach((freq, i) =>
        tone({ freq, dur: 0.18, type: 'triangle', vol: 0.16, delay: 0.1 + i * 0.08 })
      );
    });
  },
};
