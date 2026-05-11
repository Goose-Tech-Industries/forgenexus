import { soundStore } from './sounds.svelte';

interface ChatTab {
  id: string;
  name: string;
  avatar?: string | null;
  minimized: boolean;
  unread: number;
  conversationId: string;
  nudging: boolean;
}

let tabs = $state<ChatTab[]>([]);
let buddyListOpen = $state(false);

// Track nudge cooldowns per conversation (prevent spam)
const nudgeCooldowns = new Map<string, number>();
const NUDGE_COOLDOWN_MS = 5000;

export const chatStore = {
  get tabs() { return tabs; },
  get buddyListOpen() { return buddyListOpen; },

  toggleBuddyList() {
    buddyListOpen = !buddyListOpen;
  },

  openChat(conversationId: string, name: string, avatar?: string | null) {
    const existing = tabs.find(t => t.conversationId === conversationId);
    if (existing) {
      existing.minimized = false;
      return;
    }

    tabs = [...tabs, {
      id: crypto.randomUUID(),
      name,
      avatar,
      minimized: false,
      unread: 0,
      conversationId,
      nudging: false
    }];
  },

  minimizeChat(id: string) {
    const tab = tabs.find(t => t.id === id);
    if (tab) tab.minimized = true;
  },

  restoreChat(id: string) {
    const tab = tabs.find(t => t.id === id);
    if (tab) {
      tab.minimized = false;
      tab.unread = 0;
    }
  },

  closeChat(id: string) {
    tabs = tabs.filter(t => t.id !== id);
  },

  /** Increment unread on a conversation (called from socket events) */
  incrementUnread(conversationId: string) {
    const tab = tabs.find(t => t.conversationId === conversationId);
    if (tab && tab.minimized) {
      tab.unread++;
      soundStore.messageReceived();
    }
  },

  /** Trigger nudge animation on a conversation window */
  triggerNudge(conversationId: string) {
    const tab = tabs.find(t => t.conversationId === conversationId);
    if (!tab) return;

    // Restore if minimized so they see it
    if (tab.minimized) tab.minimized = false;

    tab.nudging = true;
    soundStore.nudge();

    // Stop animation after 600ms
    setTimeout(() => {
      const t = tabs.find(t => t.conversationId === conversationId);
      if (t) t.nudging = false;
    }, 600);
  },

  /** Check if nudge is on cooldown for a conversation */
  canNudge(conversationId: string): boolean {
    const last = nudgeCooldowns.get(conversationId) || 0;
    return Date.now() - last >= NUDGE_COOLDOWN_MS;
  },

  /** Record that we sent a nudge (for cooldown tracking) */
  markNudgeSent(conversationId: string) {
    nudgeCooldowns.set(conversationId, Date.now());
  }
};
