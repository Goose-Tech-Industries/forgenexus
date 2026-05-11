/**
 * Per-conversation chat themes — change colors, wallpaper, and style per DM window.
 * Stored in localStorage, keyed by conversationId.
 */

export interface ChatTheme {
  accentColor: string;
  bgColor: string;
  wallpaper: string | null;  // CSS gradient or pattern
  bubbleStyle: 'classic' | 'bubble' | 'minimal';
  fontSize: 'small' | 'normal' | 'large';
  compact: boolean;
  nickname: string | null;
  vanishMode: boolean;
}

const DEFAULT_THEME: ChatTheme = {
  accentColor: '',      // empty = use site accent
  bgColor: '',          // empty = use site bg
  wallpaper: null,
  bubbleStyle: 'classic',
  fontSize: 'normal',
  compact: false,
  nickname: null,
  vanishMode: false,
};

const PRESET_THEMES: Record<string, Partial<ChatTheme>> = {
  default: {},
  ocean: { accentColor: '#0ea5e9', bgColor: '#0c1929', wallpaper: 'linear-gradient(180deg, #0c1929 0%, #1e3a5f 100%)' },
  sunset: { accentColor: '#f97316', bgColor: '#1a0a00', wallpaper: 'linear-gradient(180deg, #1a0a00 0%, #4a1a00 100%)' },
  forest: { accentColor: '#22c55e', bgColor: '#0a1a0a', wallpaper: 'linear-gradient(180deg, #0a1a0a 0%, #1a3a1a 100%)' },
  lavender: { accentColor: '#a855f7', bgColor: '#1a0a2e', wallpaper: 'linear-gradient(180deg, #1a0a2e 0%, #2d1b4e 100%)' },
  rose: { accentColor: '#f43f5e', bgColor: '#1a0a0f', wallpaper: 'linear-gradient(180deg, #1a0a0f 0%, #3a1a25 100%)' },
  midnight: { accentColor: '#6366f1', bgColor: '#080812', wallpaper: 'linear-gradient(180deg, #080812 0%, #1a1a3a 100%)' },
  retro: { accentColor: '#facc15', bgColor: '#1a1a00', wallpaper: 'repeating-linear-gradient(45deg, transparent, transparent 10px, rgba(250,204,21,0.03) 10px, rgba(250,204,21,0.03) 20px)' },
  matrix: { accentColor: '#22c55e', bgColor: '#000a00', wallpaper: 'linear-gradient(180deg, #000a00 0%, #001a00 100%)' },
};

const WALLPAPER_PATTERNS: Record<string, string> = {
  none: '',
  dots: 'radial-gradient(circle, rgba(255,255,255,0.03) 1px, transparent 1px)',
  grid: 'linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)',
  diagonal: 'repeating-linear-gradient(45deg, transparent, transparent 10px, rgba(255,255,255,0.02) 10px, rgba(255,255,255,0.02) 20px)',
  waves: 'repeating-linear-gradient(0deg, transparent, transparent 20px, rgba(255,255,255,0.02) 20px, rgba(255,255,255,0.02) 21px)',
};

const STORAGE_KEY = 'fn_chat_themes';

function loadAll(): Record<string, ChatTheme> {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
  } catch { return {}; }
}

function saveAll(themes: Record<string, ChatTheme>) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(themes)); } catch { /* ignore */ }
}

export function getChatTheme(conversationId: string): ChatTheme {
  const all = loadAll();
  return { ...DEFAULT_THEME, ...all[conversationId] };
}

export function setChatTheme(conversationId: string, updates: Partial<ChatTheme>) {
  const all = loadAll();
  all[conversationId] = { ...DEFAULT_THEME, ...all[conversationId], ...updates };
  saveAll(all);
}

export function resetChatTheme(conversationId: string) {
  const all = loadAll();
  delete all[conversationId];
  saveAll(all);
}

export function applyThemeToElement(el: HTMLElement, theme: ChatTheme) {
  if (theme.accentColor) el.style.setProperty('--chat-accent', theme.accentColor);
  else el.style.removeProperty('--chat-accent');

  if (theme.bgColor) el.style.setProperty('--chat-bg', theme.bgColor);
  else el.style.removeProperty('--chat-bg');

  if (theme.wallpaper) el.style.backgroundImage = theme.wallpaper;
  else el.style.backgroundImage = '';

  el.style.fontSize = theme.fontSize === 'small' ? '12px' : theme.fontSize === 'large' ? '15px' : '13px';
}

export { PRESET_THEMES, WALLPAPER_PATTERNS, DEFAULT_THEME };
