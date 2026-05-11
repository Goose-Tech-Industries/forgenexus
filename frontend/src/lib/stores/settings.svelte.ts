import { api } from '$lib/api/client';

interface SiteSettings {
  chat_bar_enabled: boolean;
  shoutbox_enabled: boolean;
  welcome_center_enabled: boolean;
  welcome_center_title: string;
  welcome_center_guest_message: string;
  welcome_center_show_stats: boolean;
  welcome_center_show_recent_threads: boolean;
  welcome_center_show_new_members: boolean;
}

let settings = $state<SiteSettings>({
  chat_bar_enabled: true,
  shoutbox_enabled: true,
  welcome_center_enabled: true,
  welcome_center_title: 'ForgeNexus',
  welcome_center_guest_message: 'The next generation community platform',
  welcome_center_show_stats: true,
  welcome_center_show_recent_threads: true,
  welcome_center_show_new_members: true
});
let loaded = $state(false);

export const siteSettings = {
  get settings() { return settings; },
  get loaded() { return loaded; },
  get chatBarEnabled() { return settings.chat_bar_enabled; },
  get shoutboxEnabled() { return settings.shoutbox_enabled; },
  get welcomeCenterEnabled() { return settings.welcome_center_enabled; },
  get welcomeCenterTitle() { return settings.welcome_center_title; },

  async load() {
    try {
      const data = await api.getPublicSettings();
      settings = data.settings;
    } catch {
      // Use defaults on failure
    }
    loaded = true;
  }
};
