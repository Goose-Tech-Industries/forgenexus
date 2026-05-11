import { api } from '$lib/api/client';

export interface Notification {
  id: string;
  type: string;  // mention, reply, reaction, dm, system
  title: string | null;
  body: string | null;
  url: string | null;
  is_read: boolean;
  read_at: string | null;
  actor: {
    id: string;
    username: string;
    slug: string;
    avatar_url: string | null;
    username_color: string | null;
  } | null;
  metadata: Record<string, any>;
  inserted_at: string;
}

let notifications = $state<Notification[]>([]);
let unreadCount = $state(0);
let loading = $state(false);
let pollInterval: ReturnType<typeof setInterval> | null = null;

// Transient toasts shown when a new notification arrives.
// Toaster component subscribes to this state.
export interface Toast extends Notification {
  toastId: number;
}
let toasts = $state<Toast[]>([]);
let nextToastId = 1;
const TOAST_TTL_MS = 6000;

export const notificationStore = {
  get notifications() { return notifications; },
  get unreadCount() { return unreadCount; },
  get loading() { return loading; },

  async load(unreadOnly = false) {
    loading = true;
    try {
      const data = await api.getNotifications({ limit: 30, unread_only: unreadOnly });
      notifications = data.notifications || [];
    } catch { /* silent */ }
    loading = false;
  },

  async loadCount() {
    try {
      const data = await api.getNotificationCount();
      unreadCount = data.count || 0;
    } catch { /* silent */ }
  },

  async markRead(id: string) {
    try {
      await api.markNotificationRead(id);
      notifications = notifications.map(n => n.id === id ? { ...n, is_read: true } : n);
      unreadCount = Math.max(0, unreadCount - 1);
    } catch { /* silent */ }
  },

  async markAllRead() {
    try {
      await api.markAllNotificationsRead();
      notifications = notifications.map(n => ({ ...n, is_read: true }));
      unreadCount = 0;
    } catch { /* silent */ }
  },

  async remove(id: string) {
    try {
      await api.deleteNotification(id);
      const wasUnread = notifications.find(n => n.id === id && !n.is_read);
      notifications = notifications.filter(n => n.id !== id);
      if (wasUnread) unreadCount = Math.max(0, unreadCount - 1);
    } catch { /* silent */ }
  },

  // Called from WebSocket
  onNewNotification(notif: Notification) {
    notifications = [notif, ...notifications];
    if (!notif.is_read) unreadCount++;

    // Toast popup for new arrivals only (skip if user is viewing the bell already)
    const toast: Toast = { ...notif, toastId: nextToastId++ };
    toasts = [...toasts, toast];
    setTimeout(() => {
      toasts = toasts.filter(t => t.toastId !== toast.toastId);
    }, TOAST_TTL_MS);
  },

  get toasts() { return toasts; },

  dismissToast(toastId: number) {
    toasts = toasts.filter(t => t.toastId !== toastId);
  },

  startPolling() {
    this.loadCount();
    pollInterval = setInterval(() => this.loadCount(), 15000);
  },

  stopPolling() {
    if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
  }
};
