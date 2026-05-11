import { api } from '$lib/api/client';

export interface ChannelCategory {
  id: string;
  name: string;
  slug: string;
  position: number;
  channels: Channel[];
}

export interface Channel {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  topic: string | null;
  type: string;
  icon: string | null;
  color: string | null;
  position: number;
  category_id: string | null;
  is_private: boolean;
  is_read_only: boolean;
  is_archived: boolean;
  is_nsfw: boolean;
  slowmode_seconds: number;
  message_count: number;
  last_message_at: string | null;
  unread_count?: number;
}

export interface ChannelMessage {
  id: string;
  body: string;
  channel_id: string;
  user: {
    id: string;
    username: string;
    slug: string;
    avatar_url: string | null;
    username_color: string | null;
    username_effect: string | null;
    avatar_frame: string | null;
    custom_title: string | null;
  };
  is_edited: boolean;
  edited_at: string | null;
  is_pinned: boolean;
  is_deleted: boolean;
  reply_to: {
    id: string;
    body: string;
    user: { username: string; username_color: string | null };
  } | null;
  attachments: any[];
  embeds: any[];
  reactions: Record<string, { count: number; users: string[]; me: boolean }>;
  inserted_at: string;
}

let categories = $state<ChannelCategory[]>([]);
let activeChannel = $state<Channel | null>(null);
let messages = $state<ChannelMessage[]>([]);
let loadingChannels = $state(false);
let loadingMessages = $state(false);
let hasMoreMessages = $state(true);
let typingUsers = $state<Map<string, { username: string; timeout: ReturnType<typeof setTimeout> }>>(new Map());
let unreadCounts = $state<Record<string, number>>({});
let slowmodeUntil = $state<number>(0); // timestamp when slowmode expires

export const channelStore = {
  get categories() { return categories; },
  get activeChannel() { return activeChannel; },
  get messages() { return messages; },
  get loadingChannels() { return loadingChannels; },
  get loadingMessages() { return loadingMessages; },
  get hasMoreMessages() { return hasMoreMessages; },
  get typingUsers() { return typingUsers; },
  get unreadCounts() { return unreadCounts; },
  get slowmodeUntil() { return slowmodeUntil; },

  get totalUnread() {
    return Object.values(unreadCounts).reduce((sum, c) => sum + c, 0);
  },

  async loadChannels() {
    loadingChannels = true;
    try {
      const data = await api.getChannels();
      categories = data.categories || [];
      // Extract unread counts
      for (const cat of categories) {
        for (const ch of cat.channels) {
          if (ch.unread_count) unreadCounts[ch.id] = ch.unread_count;
        }
      }
    } catch (e) {
      console.error('Failed to load channels:', e);
    }
    loadingChannels = false;
  },

  async selectChannel(slug: string) {
    loadingMessages = true;
    hasMoreMessages = true;
    messages = [];
    slowmodeUntil = 0;
    try {
      const data = await api.getChannel(slug);
      activeChannel = data.channel;
      messages = data.messages || [];
      hasMoreMessages = messages.length >= 50;
      // Clear unread for this channel + mentions
      if (activeChannel) {
        unreadCounts[activeChannel.id] = 0;
        if (messages.length > 0) {
          api.markChannelRead(slug, messages[messages.length - 1].id).catch(() => {});
        }
        // Also mark mentions as read for this channel
        api.markMentionsRead(activeChannel.id).catch(() => {});
      }
    } catch (e) {
      console.error('Failed to load channel:', e);
    }
    loadingMessages = false;
  },

  async loadMoreMessages() {
    if (!activeChannel || !hasMoreMessages || loadingMessages) return;
    loadingMessages = true;
    try {
      const oldestId = messages.length > 0 ? messages[0].id : undefined;
      const data = await api.getChannelMessages(activeChannel.slug, {
        before: oldestId,
        limit: 50
      });
      const older = data.messages || [];
      messages = [...older, ...messages];
      hasMoreMessages = older.length >= 50;
    } catch (e) {
      console.error('Failed to load more messages:', e);
    }
    loadingMessages = false;
  },

  async sendMessage(body: string, replyToId?: string) {
    if (!activeChannel) return null;
    try {
      const data = await api.sendChannelMessage(activeChannel.slug, {
        body,
        reply_to_id: replyToId
      });
      messages = [...messages, data.message];
      // Start local slowmode countdown after successful send
      if (activeChannel.slowmode_seconds > 0) {
        slowmodeUntil = Date.now() + activeChannel.slowmode_seconds * 1000;
      }
      return data.message;
    } catch (e: any) {
      // Handle slowmode 429 response
      if (e?.response?.status === 429 || e?.seconds_remaining) {
        const remaining = e?.seconds_remaining || e?.response?.data?.seconds_remaining || 5;
        slowmodeUntil = Date.now() + remaining * 1000;
      }
      console.error('Failed to send message:', e);
      return null;
    }
  },

  async editMessage(messageId: string, body: string) {
    if (!activeChannel) return;
    try {
      const data = await api.editChannelMessage(activeChannel.slug, messageId, body);
      messages = messages.map(m => m.id === messageId ? data.message : m);
    } catch (e) {
      console.error('Failed to edit message:', e);
    }
  },

  async deleteMessage(messageId: string) {
    if (!activeChannel) return;
    try {
      await api.deleteChannelMessage(activeChannel.slug, messageId);
      messages = messages.map(m => m.id === messageId ? { ...m, is_deleted: true } : m);
    } catch (e) {
      console.error('Failed to delete message:', e);
    }
  },

  async toggleReaction(messageId: string, emoji: string, hasReacted: boolean) {
    if (!activeChannel) return;
    try {
      if (hasReacted) {
        await api.removeReaction(activeChannel.slug, messageId, emoji);
      } else {
        await api.addReaction(activeChannel.slug, messageId, emoji);
      }
    } catch (e) {
      console.error('Failed to toggle reaction:', e);
    }
  },

  // Called from WebSocket events
  onNewMessage(message: ChannelMessage) {
    if (activeChannel && message.channel_id === activeChannel.id) {
      messages = [...messages, message];
    } else {
      // Increment unread
      unreadCounts[message.channel_id] = (unreadCounts[message.channel_id] || 0) + 1;
    }
  },

  onMessageEdited(message: ChannelMessage) {
    messages = messages.map(m => m.id === message.id ? message : m);
  },

  onMessageDeleted(messageId: string) {
    messages = messages.map(m => m.id === messageId ? { ...m, is_deleted: true } : m);
  },

  onUserTyping(channelId: string, userId: string, username: string) {
    if (activeChannel?.id !== channelId) return;
    // Clear existing timeout for this user
    const existing = typingUsers.get(userId);
    if (existing) clearTimeout(existing.timeout);
    // Set new timeout (clear after 3s)
    const timeout = setTimeout(() => {
      typingUsers.delete(userId);
      typingUsers = new Map(typingUsers);
    }, 3000);
    typingUsers.set(userId, { username, timeout });
    typingUsers = new Map(typingUsers);
  },

  onReactionUpdate(messageId: string, reactions: ChannelMessage['reactions']) {
    messages = messages.map(m => m.id === messageId ? { ...m, reactions } : m);
  },

  clearActive() {
    activeChannel = null;
    messages = [];
  }
};
