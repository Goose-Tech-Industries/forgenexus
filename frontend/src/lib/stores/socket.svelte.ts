import { Socket, Presence } from 'phoenix';
import { api } from '$lib/api/client';
import { auth } from '$lib/stores/auth.svelte';
import { channelStore } from '$lib/stores/channels.svelte';
import { notificationStore } from '$lib/stores/notifications.svelte';

function computeWsBase(): string {
  const base = import.meta.env.VITE_API_BASE;
  if (base && /^https?:\/\//.test(base)) {
    return base.replace(/\/api$/, '').replace(/^http/, 'ws');
  }
  if (typeof window !== 'undefined') {
    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
    return `${proto}://${window.location.host}`;
  }
  return '';
}
const WS_BASE = computeWsBase();

let socket: Socket | null = null;
let presenceChannel: any = null;
let shoutboxChannel: any = null;
let userChannel: any = null;
let chatChannels: Map<string, any> = new Map();
let threadChannels: Map<string, any> = new Map();
let adminChannel: any = null;
let onlineUsers = $state<Array<{
  user_id: string;
  username: string;
  slug: string | null;
  avatar_url: string | null;
  username_color: string | null;
  username_effect: string | null;
}>>([]);
let connected = $state(false);

// Shoutbox listeners registered by the Shoutbox component
let shoutboxListeners: Array<(msg: any) => void> = [];
// Thread listeners registered by thread pages
let threadListeners: Map<string, Array<(post: any) => void>> = new Map();
let threadUpdateListeners: Map<string, Array<(post: any) => void>> = new Map();
let joinAttempts: Map<string, number> = new Map();
// Admin war room listeners
let adminListeners: Array<(stats: any) => void> = [];

export const socketStore = {
  get socket() { return socket; },
  get connected() { return connected; },
  get onlineUsers() { return onlineUsers; },

  /** Initialize the Phoenix socket after auth. Call from +layout.svelte */
  connect() {
    if (socket) return;

    const token = api.getWsToken();
    if (!token) return;

    socket = new Socket(`${WS_BASE}/socket`, {
      params: { token },
      heartbeatIntervalMs: 30000,
      reconnectAfterMs: (tries: number) => Math.min(1000 * Math.pow(2, tries), 30000),
    });

    socket.onOpen(() => { connected = true; });
    socket.onClose(() => { connected = false; });
    socket.onError(() => { connected = false; });

    socket.connect();

    // Auto-join presence
    this.joinPresence();
    // Auto-join shoutbox
    this.joinShoutbox();
    // Auto-join user channel for live notification pushes
    this.joinUserChannel();
    // Polling is the fallback in case the WS push misses anything
    notificationStore.startPolling();
  },

  joinUserChannel() {
    if (!socket || userChannel || !auth.user) return;
    userChannel = socket.channel(`user:${auth.user.id}`, {});

    userChannel.on('new_notification', (notif: any) => {
      notificationStore.onNewNotification(notif);
    });

    userChannel.join()
      .receive('error', (err: any) => console.error('Failed to join user channel:', err));
  },

  disconnect() {
    // Leave all channels
    chatChannels.forEach(ch => ch.leave());
    chatChannels.clear();
    threadChannels.forEach(ch => ch.leave());
    threadChannels.clear();
    if (presenceChannel) { presenceChannel.leave(); presenceChannel = null; }
    if (shoutboxChannel) { shoutboxChannel.leave(); shoutboxChannel = null; }
    if (userChannel) { userChannel.leave(); userChannel = null; }
    if (adminChannel) { adminChannel.leave(); adminChannel = null; }
    shoutboxListeners = [];
    threadListeners.clear();
    threadUpdateListeners.clear();
    adminListeners = [];

    if (socket) {
      socket.disconnect();
      socket = null;
    }
    connected = false;
    onlineUsers = [];
  },

  // --- Presence ---

  joinPresence() {
    if (!socket) return;
    presenceChannel = socket.channel('presence:lobby', {});

    const presence = new Presence(presenceChannel);

    presence.onSync(() => {
      const users: Array<{
        user_id: string;
        username: string;
        slug: string | null;
        avatar_url: string | null;
        username_color: string | null;
        username_effect: string | null;
      }> = [];
      presence.list((id: string, { metas }: any) => {
        const meta = metas[0];
        users.push({
          user_id: id,
          username: meta.username,
          slug: meta.slug || null,
          avatar_url: meta.avatar_url || null,
          username_color: meta.username_color || null,
          username_effect: meta.username_effect || null
        });
      });
      onlineUsers = users;
    });

    presenceChannel.join()
      .receive('error', (err: any) => console.error('Failed to join presence:', err));
  },

  // --- Shoutbox ---

  joinShoutbox() {
    if (!socket) return;
    shoutboxChannel = socket.channel('shoutbox:lobby', {});

    shoutboxChannel.on('new_message', (msg: any) => {
      shoutboxListeners.forEach(fn => fn(msg));
    });

    shoutboxChannel.join()
      .receive('error', (err: any) => console.error('Failed to join shoutbox:', err));
  },

  sendShoutboxMessage(body: string): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!shoutboxChannel) return reject(new Error('Not connected to shoutbox'));
      shoutboxChannel.push('new_message', { body })
        .receive('ok', resolve)
        .receive('error', reject);
    });
  },

  onShoutboxMessage(fn: (msg: any) => void) {
    shoutboxListeners.push(fn);
    return () => {
      shoutboxListeners = shoutboxListeners.filter(f => f !== fn);
    };
  },

  // --- Chat channels (Discord-style) ---

  joinChatChannel(channelSlug: string) {
    if (!socket || chatChannels.has(channelSlug)) return;

    const ch = socket.channel(`chat:${channelSlug}`, {});

    ch.on('new_message', (msg: any) => {
      channelStore.onNewMessage(msg);
    });

    ch.on('message_edited', (msg: any) => {
      channelStore.onMessageEdited(msg);
    });

    ch.on('message_deleted', (data: any) => {
      channelStore.onMessageDeleted(data.id || data.message_id);
    });

    ch.on('typing', (data: any) => {
      if (data.user_id !== auth.user?.id) {
        channelStore.onUserTyping(data.channel_id, data.user_id, data.username);
      }
    });

    ch.on('reaction_update', (data: any) => {
      channelStore.onReactionUpdate(data.message_id, data.reactions);
    });

    ch.join()
      .receive('error', (err: any) => console.error(`Failed to join chat:${channelSlug}:`, err));

    chatChannels.set(channelSlug, ch);
  },

  leaveChatChannel(channelSlug: string) {
    const ch = chatChannels.get(channelSlug);
    if (ch) {
      ch.leave();
      chatChannels.delete(channelSlug);
    }
  },

  sendTyping(channelSlug: string) {
    const ch = chatChannels.get(channelSlug);
    if (ch) {
      ch.push('typing', {});
    }
  },

  // --- Thread channels ---

  joinThreadChannel(
    threadId: string,
    onNewPost: (post: any) => void,
    onPostUpdated?: (post: any) => void
  ) {
    // Listener registration is order-independent — record it now even if the
    // socket isn't ready yet. The actual channel join is retried below until
    // the socket comes online (covers the common race where the thread page
    // mounts before the WebSocket finishes its initial connect).
    if (!threadListeners.has(threadId)) threadListeners.set(threadId, []);
    threadListeners.get(threadId)!.push(onNewPost);
    if (onPostUpdated) {
      if (!threadUpdateListeners.has(threadId)) threadUpdateListeners.set(threadId, []);
      threadUpdateListeners.get(threadId)!.push(onPostUpdated);
    }

    if (threadChannels.has(threadId)) return;

    const tryJoin = () => {
      if (!socket) {
        // Retry once the socket initializes. 250ms is enough to cover the
        // common boot ordering, and we cap the total retry window at ~10s.
        if (joinAttempts.get(threadId) === undefined) joinAttempts.set(threadId, 0);
        const n = joinAttempts.get(threadId)!;
        if (n > 40) {
          console.warn(`[socket] gave up joining thread:${threadId} — socket never came up`);
          return;
        }
        joinAttempts.set(threadId, n + 1);
        setTimeout(tryJoin, 250);
        return;
      }
      if (threadChannels.has(threadId)) return;

      const ch = socket.channel(`thread:${threadId}`, {});
      ch.on('new_post', (post: any) => {
        (threadListeners.get(threadId) || []).forEach((fn) => fn(post));
      });
      ch.on('post_updated', (post: any) => {
        (threadUpdateListeners.get(threadId) || []).forEach((fn) => fn(post));
      });
      ch.join()
        .receive('ok', () => console.log(`[socket] joined thread:${threadId}`))
        .receive('error', (err: any) => console.error(`Failed to join thread:${threadId}:`, err));
      threadChannels.set(threadId, ch);
      joinAttempts.delete(threadId);
    };

    tryJoin();
  },

  leaveThreadChannel(threadId: string) {
    const ch = threadChannels.get(threadId);
    if (ch) {
      ch.leave();
      threadChannels.delete(threadId);
    }
    threadListeners.delete(threadId);
  },

  // --- Admin war room ---

  joinAdminChannel(onStats: (stats: any) => void) {
    if (!socket || adminChannel) return;

    adminListeners.push(onStats);
    adminChannel = socket.channel('admin:war_room', {});

    adminChannel.on('stats_update', (stats: any) => {
      adminListeners.forEach(fn => fn(stats));
    });

    adminChannel.join()
      .receive('error', (err: any) => console.error('Failed to join admin channel:', err));
  },

  leaveAdminChannel() {
    if (adminChannel) {
      adminChannel.leave();
      adminChannel = null;
    }
    adminListeners = [];
  },

  onAdminStats(fn: (stats: any) => void) {
    adminListeners.push(fn);
    return () => {
      adminListeners = adminListeners.filter(f => f !== fn);
    };
  },

  /** Get the raw Phoenix Socket for voice store usage */
  getSocket() {
    return socket;
  }
};
