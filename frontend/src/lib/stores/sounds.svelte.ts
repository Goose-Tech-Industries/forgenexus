/**
 * Sound system — synthesized AIM/MSN/Yahoo-style messenger sounds via Web Audio API.
 * No audio files required.
 */

let audioCtx: AudioContext | null = null;
let enabled = $state(true);
let volume = $state(0.4);

function getCtx(): AudioContext {
  if (!audioCtx) audioCtx = new AudioContext();
  if (audioCtx.state === 'suspended') audioCtx.resume();
  return audioCtx;
}

function makeGain(ctx: AudioContext, vol: number): GainNode {
  const g = ctx.createGain();
  g.gain.value = vol * volume;
  g.connect(ctx.destination);
  return g;
}

// ---- Sound definitions ----

/** AIM-style door open: ascending two-tone chime */
function playBuddySignOn() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;
  const g = makeGain(ctx, 0.3);

  // First tone
  const o1 = ctx.createOscillator();
  o1.type = 'sine';
  o1.frequency.setValueAtTime(523, now); // C5
  o1.frequency.setValueAtTime(659, now + 0.1); // E5
  o1.connect(g);
  o1.start(now);
  o1.stop(now + 0.2);

  // Second tone
  const o2 = ctx.createOscillator();
  o2.type = 'sine';
  o2.frequency.setValueAtTime(784, now + 0.15); // G5
  const g2 = makeGain(ctx, 0.25);
  o2.connect(g2);
  o2.start(now + 0.15);
  o2.stop(now + 0.35);

  // Fade out
  g.gain.setValueAtTime(0.3 * volume, now + 0.2);
  g.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
  g2.gain.setValueAtTime(0.25 * volume, now + 0.25);
  g2.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
}

/** AIM-style door close: descending two-tone */
function playBuddySignOff() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;
  const g = makeGain(ctx, 0.25);

  const o1 = ctx.createOscillator();
  o1.type = 'sine';
  o1.frequency.setValueAtTime(659, now); // E5
  o1.frequency.setValueAtTime(523, now + 0.1); // C5
  o1.connect(g);
  o1.start(now);
  o1.stop(now + 0.25);

  const o2 = ctx.createOscillator();
  o2.type = 'sine';
  o2.frequency.setValueAtTime(440, now + 0.12); // A4
  const g2 = makeGain(ctx, 0.2);
  o2.connect(g2);
  o2.start(now + 0.12);
  o2.stop(now + 0.3);

  g.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
  g2.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
}

/** Message received: classic IM ding */
function playMessageReceived() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;
  const g = makeGain(ctx, 0.3);

  const o = ctx.createOscillator();
  o.type = 'sine';
  o.frequency.setValueAtTime(880, now); // A5
  o.frequency.exponentialRampToValueAtTime(1200, now + 0.05);
  o.frequency.exponentialRampToValueAtTime(880, now + 0.1);
  o.connect(g);
  o.start(now);
  o.stop(now + 0.15);

  g.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
}

/** Message sent: soft blip */
function playMessageSent() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;
  const g = makeGain(ctx, 0.15);

  const o = ctx.createOscillator();
  o.type = 'triangle';
  o.frequency.setValueAtTime(600, now);
  o.frequency.exponentialRampToValueAtTime(800, now + 0.06);
  o.connect(g);
  o.start(now);
  o.stop(now + 0.08);

  g.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
}

/** MSN-style nudge/buzz: aggressive vibrating buzz */
function playNudge() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;

  // Create a rapid sequence of harsh tones to simulate a buzz/vibration
  for (let i = 0; i < 6; i++) {
    const t = now + i * 0.08;
    const g = makeGain(ctx, 0.25);
    const o = ctx.createOscillator();
    o.type = 'square';
    o.frequency.setValueAtTime(i % 2 === 0 ? 220 : 180, t);
    o.connect(g);
    o.start(t);
    o.stop(t + 0.05);
    g.gain.setValueAtTime(0.25 * volume, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
  }
}

/** Yahoo-style alert: triple ascending ding */
function playAlert() {
  if (!enabled) return;
  const ctx = getCtx();
  const now = ctx.currentTime;
  const notes = [698, 880, 1047]; // F5, A5, C6

  notes.forEach((freq, i) => {
    const t = now + i * 0.12;
    const g = makeGain(ctx, 0.2);
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(freq, t);
    o.connect(g);
    o.start(t);
    o.stop(t + 0.1);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.15);
  });
}

// ---- Saved preferences ----

function loadPrefs() {
  try {
    const saved = localStorage.getItem('fn_sound_prefs');
    if (saved) {
      const p = JSON.parse(saved);
      enabled = p.enabled ?? true;
      volume = p.volume ?? 0.4;
    }
  } catch { /* ignore */ }
}

function savePrefs() {
  try {
    localStorage.setItem('fn_sound_prefs', JSON.stringify({ enabled, volume }));
  } catch { /* ignore */ }
}

// Load on module init
if (typeof window !== 'undefined') {
  loadPrefs();
}

// ---- Public API ----

export const soundStore = {
  get enabled() { return enabled; },
  get volume() { return volume; },

  setEnabled(val: boolean) {
    enabled = val;
    savePrefs();
  },

  setVolume(val: number) {
    volume = Math.max(0, Math.min(1, val));
    savePrefs();
  },

  buddySignOn: playBuddySignOn,
  buddySignOff: playBuddySignOff,
  messageReceived: playMessageReceived,
  messageSent: playMessageSent,
  nudge: playNudge,
  alert: playAlert,
};
