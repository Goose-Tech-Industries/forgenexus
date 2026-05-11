import { api } from '$lib/api/client';

interface ThemeVariables {
  bg_primary?: string;
  bg_secondary?: string;
  bg_tertiary?: string;
  bg_hover?: string;
  bg_card?: string;
  bg_input?: string;
  accent?: string;
  accent_glow?: string;
  accent_hover?: string;
  accent_dim?: string;
  text_primary?: string;
  text_secondary?: string;
  text_muted?: string;
  text_link?: string;
  text_link_hover?: string;
  border_color?: string;
  border_accent?: string;
}

interface Theme {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  is_default: boolean;
  variables: ThemeVariables;
  position: number;
}

interface UserOverrides {
  color_override_accent?: string | null;
  color_override_bg_primary?: string | null;
  color_override_bg_secondary?: string | null;
  color_override_text_primary?: string | null;
}

// Map backend variable keys to CSS custom property names
const VAR_MAP: Record<string, string> = {
  bg_primary: '--bg-primary',
  bg_secondary: '--bg-secondary',
  bg_tertiary: '--bg-tertiary',
  bg_hover: '--bg-hover',
  bg_card: '--bg-card',
  bg_input: '--bg-input',
  accent: '--accent',
  accent_glow: '--accent-glow',
  accent_hover: '--accent-hover',
  accent_dim: '--accent-dim',
  text_primary: '--text-primary',
  text_secondary: '--text-secondary',
  text_muted: '--text-muted',
  text_link: '--text-link',
  text_link_hover: '--text-link-hover',
  border_color: '--border-color',
  border_accent: '--border-accent'
};

let themes = $state<Theme[]>([]);
let activeThemeId = $state<string | null>(null);
let loaded = $state(false);

export const themeStore = {
  get themes() { return themes; },
  get activeThemeId() { return activeThemeId; },
  get loaded() { return loaded; },

  async loadThemes() {
    try {
      const data = await api.getThemes();
      themes = data.themes || [];
    } catch {
      // Use defaults on failure
    }
    loaded = true;
  },

  applyTheme(themeId: string | null) {
    activeThemeId = themeId;
    const theme = themes.find(t => t.id === themeId);

    if (!theme) {
      // Reset to defaults by removing overrides
      if (typeof document !== 'undefined') {
        Object.values(VAR_MAP).forEach(prop => {
          document.documentElement.style.removeProperty(prop);
        });
      }
      return;
    }

    if (typeof document !== 'undefined') {
      for (const [key, value] of Object.entries(theme.variables)) {
        const cssProp = VAR_MAP[key];
        if (cssProp && value) {
          document.documentElement.style.setProperty(cssProp, value);
        }
      }
    }
  },

  applyUserOverrides(overrides: UserOverrides) {
    if (typeof document === 'undefined') return;

    const map: Record<string, string> = {
      color_override_accent: '--accent',
      color_override_bg_primary: '--bg-primary',
      color_override_bg_secondary: '--bg-secondary',
      color_override_text_primary: '--text-primary'
    };

    for (const [key, cssProp] of Object.entries(map)) {
      const value = overrides[key as keyof UserOverrides];
      if (value) {
        document.documentElement.style.setProperty(cssProp, value);
      }
    }
  },

  applyFromUser(user: { theme_id?: string | null } & UserOverrides) {
    if (user.theme_id) {
      this.applyTheme(user.theme_id);
    }
    this.applyUserOverrides(user);
  },

  reset() {
    if (typeof document !== 'undefined') {
      Object.values(VAR_MAP).forEach(prop => {
        document.documentElement.style.removeProperty(prop);
      });
    }
    activeThemeId = null;
  }
};
