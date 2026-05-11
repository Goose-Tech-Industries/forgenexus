/**
 * Message effects — trigger visual effects based on message content.
 * Inspired by Facebook Messenger word effects and iMessage screen effects.
 */

export interface Effect {
  type: 'confetti' | 'hearts' | 'fireworks' | 'snow' | 'party' | 'sad' | 'fire';
  duration: number; // ms
}

const EFFECT_TRIGGERS: Array<{ pattern: RegExp; effect: Effect }> = [
  { pattern: /\bcongrat(s|ulations)?\b/i, effect: { type: 'confetti', duration: 3000 } },
  { pattern: /\bhappy birthday\b/i, effect: { type: 'confetti', duration: 4000 } },
  { pattern: /\byay\b|\bwoohoo\b|\bhooray\b|\bwoo\b/i, effect: { type: 'party', duration: 3000 } },
  { pattern: /\blove you\b|\bi love\b|\b<3\b|❤️|💕|💗|😍/i, effect: { type: 'hearts', duration: 3000 } },
  { pattern: /\bhappy new year\b|\bnye\b/i, effect: { type: 'fireworks', duration: 4000 } },
  { pattern: /\bgg\b|\bgood game\b|\bvictory\b|\bwinner\b|\bchampion\b/i, effect: { type: 'confetti', duration: 3000 } },
  { pattern: /🔥|💯|\blit\b|\bfire\b/i, effect: { type: 'fire', duration: 2500 } },
  { pattern: /😢|😭|\bcrying\b|\bso sad\b/i, effect: { type: 'sad', duration: 2500 } },
  { pattern: /❄️|🌨️|\bmerry christmas\b|\bxmas\b/i, effect: { type: 'snow', duration: 4000 } },
];

export function detectEffect(message: string): Effect | null {
  for (const trigger of EFFECT_TRIGGERS) {
    if (trigger.pattern.test(message)) {
      return trigger.effect;
    }
  }
  return null;
}

/** Render a visual effect in a container element */
export function renderEffect(container: HTMLElement, effect: Effect) {
  const particles: HTMLElement[] = [];
  const count = effect.type === 'snow' ? 30 : 20;

  for (let i = 0; i < count; i++) {
    const p = document.createElement('div');
    p.className = `effect-particle effect-${effect.type}`;
    p.style.left = `${Math.random() * 100}%`;
    p.style.animationDelay = `${Math.random() * 1}s`;
    p.style.animationDuration = `${1 + Math.random() * 2}s`;
    p.textContent = getParticleChar(effect.type);
    container.appendChild(p);
    particles.push(p);
  }

  setTimeout(() => {
    particles.forEach(p => p.remove());
  }, effect.duration);
}

function getParticleChar(type: string): string {
  switch (type) {
    case 'confetti': return ['🎊', '🎉', '✨', '⭐', '🌟'][Math.floor(Math.random() * 5)];
    case 'hearts': return ['❤️', '💕', '💗', '💖', '💘'][Math.floor(Math.random() * 5)];
    case 'fireworks': return ['🎆', '🎇', '✨', '💥', '🌟'][Math.floor(Math.random() * 5)];
    case 'snow': return ['❄️', '🌨️', '❅', '❆', '⛄'][Math.floor(Math.random() * 5)];
    case 'party': return ['🎊', '🎉', '🥳', '🎈', '🍾'][Math.floor(Math.random() * 5)];
    case 'sad': return ['😢', '💧', '🥺', '😿', '💔'][Math.floor(Math.random() * 5)];
    case 'fire': return ['🔥', '💥', '✨', '⚡', '💫'][Math.floor(Math.random() * 5)];
    default: return '✨';
  }
}

/** CSS for effects — inject into component styles */
export const EFFECT_CSS = `
  .effect-container {
    position: absolute;
    inset: 0;
    pointer-events: none;
    overflow: hidden;
    z-index: 100;
  }
  .effect-particle {
    position: absolute;
    top: -20px;
    font-size: 18px;
    animation: effect-fall linear forwards;
    pointer-events: none;
  }
  @keyframes effect-fall {
    0% { transform: translateY(-20px) rotate(0deg); opacity: 1; }
    100% { transform: translateY(400px) rotate(720deg); opacity: 0; }
  }
  .effect-snow { animation-name: effect-drift; font-size: 14px; }
  @keyframes effect-drift {
    0% { transform: translateY(-20px) translateX(0) rotate(0deg); opacity: 0.8; }
    50% { transform: translateY(200px) translateX(30px) rotate(360deg); opacity: 0.6; }
    100% { transform: translateY(400px) translateX(-20px) rotate(720deg); opacity: 0; }
  }
  .effect-fire { animation-direction: reverse; }
`;
