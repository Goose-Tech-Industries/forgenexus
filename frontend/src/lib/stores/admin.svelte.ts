import { api } from '$lib/api/client';

export interface WarRoomStats {
  active_users: number; posts_per_minute: number; posts_last_hour: number;
  open_reports: number; active_bans: number; online_staff: number;
  total_users: number; total_threads: number; server_uptime_seconds: number;
}

export interface HealthScore {
  score: number; trend: number;
  metrics: HealthMetrics; previous_metrics: HealthMetrics;
}

export interface HealthMetrics {
  new_user_retention: number; post_reply_ratio: number;
  report_density: number; active_to_lurker: number; avg_reply_time_score: number;
}

export interface DecayForum {
  forum_id: string; forum_name: string; forum_slug: string; category_name: string;
  current_threads_30d: number; previous_threads_30d: number; total_posts: number;
  decline_pct: number; is_declining: boolean; suggestions: string[];
}

export interface FunnelData {
  total_registered: number; email_confirmed: number;
  first_post: number; active_7d: number; active_30d: number; days: number;
}

export interface PluginStat {
  id: string; name: string; status: string; type: string;
  total: number; failures: number; avg_duration: number | null;
}

export interface HeatmapCell {
  day: number; hour: number; count: number;
}

export interface AuditLog {
  id: string; action: string; category: string;
  target_type: string | null; target_id: string | null;
  description: string | null;
  previous_state: Record<string, any>; new_state: Record<string, any>;
  is_rolled_back: boolean; rolled_back_at: string | null;
  admin: { id: string; username: string; slug: string; avatar_url: string | null } | null;
  rolled_back_by: { id: string; username: string } | null;
  inserted_at: string;
}

let warRoom = $state<WarRoomStats | null>(null);
let healthScore = $state<HealthScore | null>(null);
let contentDecay = $state<DecayForum[]>([]);
let funnel = $state<FunnelData | null>(null);
let pluginImpact = $state<PluginStat[]>([]);
let heatmap = $state<HeatmapCell[]>([]);
let auditLogs = $state<AuditLog[]>([]);
let settings = $state<Record<string, any>>({});
let settingsCategories = $state<Record<string, string[]>>({});
let users = $state<any[]>([]);
let usersTotal = $state(0);
let groups = $state<any[]>([]);
let ranks = $state<any[]>([]);
let themes = $state<any[]>([]);
let announcements = $state<any[]>([]);
let systemInfo = $state<any>(null);
let dbStats = $state<any[]>([]);
let sentimentTrends = $state<any>(null);
let mergeSuggestions = $state<any[]>([]);
let liveFeed = $state<any[]>([]);
let comparison = $state<any>(null);
let modQueue = $state<any>(null);
let newMembers = $state<any[]>([]);
let loading = $state(false);

export const admin = {
  get warRoom() { return warRoom; },
  get healthScore() { return healthScore; },
  get contentDecay() { return contentDecay; },
  get funnel() { return funnel; },
  get pluginImpact() { return pluginImpact; },
  get heatmap() { return heatmap; },
  get auditLogs() { return auditLogs; },
  get settings() { return settings; },
  get settingsCategories() { return settingsCategories; },
  get users() { return users; },
  get groups() { return groups; },
  get ranks() { return ranks; },
  get themes() { return themes; },
  get announcements() { return announcements; },
  get systemInfo() { return systemInfo; },
  get dbStats() { return dbStats; },
  get sentimentTrends() { return sentimentTrends; },
  get mergeSuggestions() { return mergeSuggestions; },
  get liveFeed() { return liveFeed; },
  get comparison() { return comparison; },
  get modQueue() { return modQueue; },
  get newMembers() { return newMembers; },
  get loading() { return loading; },

  setWarRoom(stats: WarRoomStats) { warRoom = stats; },

  async loadWarRoom() {
    const d = await api.getWarRoom();
    warRoom = d.stats;
  },

  async loadHealthScore() {
    const d = await api.getHealthScore();
    healthScore = d.health;
  },

  async loadContentDecay() {
    const d = await api.getContentDecay();
    contentDecay = d.forums;
  },

  async loadFunnel(days?: number) {
    const d = await api.getRegistrationFunnel(days);
    funnel = d.funnel;
  },

  async loadPluginImpact() {
    const d = await api.getPluginImpact();
    pluginImpact = d.impact.plugins;
  },

  async loadHeatmap(days?: number) {
    const d = await api.getActivityHeatmap(days);
    heatmap = d.heatmap.cells;
  },

  async loadAuditLogs(params?: Record<string, string>) {
    loading = true;
    try {
      const d = await api.getAuditLogs(params);
      auditLogs = d.logs;
    } finally { loading = false; }
  },

  async rollbackAction(id: string) {
    const d = await api.rollbackAuditLog(id);
    auditLogs = auditLogs.map(l => l.id === id ? d.log : l);
    return d.log;
  },

  async reorderCategories(orderedIds: string[]) { await api.reorderCategories(orderedIds); },
  async reorderForums(categoryId: string, orderedIds: string[]) { await api.reorderForums(categoryId, orderedIds); },

  // Settings
  async loadSettings() { const d = await api.getAdminSettings(); settings = d.settings; settingsCategories = d.categories; },
  async saveSettings(s: Record<string, string>) { const d = await api.updateAdminSettings(s); settings = d.settings; },

  // Users
  async loadUsers(params?: Record<string, string>) { loading = true; try { const d = await api.getAdminUsers(params); users = d.users; usersTotal = d.total ?? d.users.length; } finally { loading = false; } },
  get usersTotal() { return usersTotal; },
  async loadUser(id: string) { const d = await api.getAdminUser(id); return d.user; },
  async updateUser(id: string, data: Record<string, any>) { const d = await api.updateAdminUser(id, data); users = users.map(u => u.id === id ? d.user : u); return d.user; },
  async deleteUser(id: string) { await api.deleteAdminUser(id); users = users.filter(u => u.id !== id); },
  async resetPassword(id: string) { return await api.resetUserPassword(id); },
  async bulkAction(action: string, userIds: string[], params?: Record<string, any>) { return await api.bulkUserAction(action, userIds, params); },
  async loadUserJourney(id: string) { const d = await api.getUserJourney(id); return d.events; },
  async searchUsersByIp(ip: string) { loading = true; try { const d = await api.searchUsersByIp(ip); users = d.users; } finally { loading = false; } },

  // Groups
  async loadGroups() { const d = await api.getAdminGroups(); groups = d.groups; },
  async createGroup(data: Record<string, any>) { const d = await api.createAdminGroup(data); groups = [...groups, d.group]; return d.group; },
  async updateGroup(id: string, data: Record<string, any>) { const d = await api.updateAdminGroup(id, data); groups = groups.map(g => g.id === id ? d.group : g); return d.group; },
  async deleteGroup(id: string) { await api.deleteAdminGroup(id); groups = groups.filter(g => g.id !== id); },

  // Ranks
  async loadRanks() { const d = await api.getAdminRanks(); ranks = d.ranks; },
  async createRank(data: Record<string, any>) { const d = await api.createAdminRank(data); ranks = [...ranks, d.rank]; return d.rank; },
  async updateRank(id: string, data: Record<string, any>) { const d = await api.updateAdminRank(id, data); ranks = ranks.map(r => r.id === id ? d.rank : r); return d.rank; },
  async deleteRank(id: string) { await api.deleteAdminRank(id); ranks = ranks.filter(r => r.id !== id); },

  // Themes
  async loadThemes() { const d = await api.getAdminThemes(); themes = d.themes; },
  async createTheme(data: Record<string, any>) { const d = await api.createAdminTheme(data); themes = [...themes, d.theme]; return d.theme; },
  async updateTheme(id: string, data: Record<string, any>) { const d = await api.updateAdminTheme(id, data); themes = themes.map(t => t.id === id ? d.theme : t); return d.theme; },
  async deleteTheme(id: string) { await api.deleteAdminTheme(id); themes = themes.filter(t => t.id !== id); },
  async setDefaultTheme(id: string) { const d = await api.setDefaultTheme(id); themes = themes.map(t => ({ ...t, is_default: t.id === id })); return d.theme; },

  // Announcements
  async loadAnnouncements() { const d = await api.getAnnouncements(); announcements = d.announcements; },
  async createAnnouncement(data: Record<string, any>) { const d = await api.createAnnouncement(data); announcements = [d.announcement, ...announcements]; return d.announcement; },
  async updateAnnouncement(id: string, data: Record<string, any>) { const d = await api.updateAnnouncement(id, data); announcements = announcements.map(a => a.id === id ? d.announcement : a); return d.announcement; },
  async deleteAnnouncement(id: string) { await api.deleteAnnouncement(id); announcements = announcements.filter(a => a.id !== id); },

  // Maintenance
  async loadSystemInfo() { const d = await api.getSystemInfo(); systemInfo = d.info; },
  async loadDbStats() { const d = await api.getDbStats(); dbStats = d.tables; },
  async clearCache() { return await api.clearCache(); },
  async reindexSearch() { return await api.reindexSearch(); },

  // Dashboard enhancements
  async loadLiveFeed(limit = 30) { try { const d = await api.getLiveFeed(limit); liveFeed = d.events || []; } catch { liveFeed = []; } },
  async loadComparison() { try { const d = await api.getComparison(); comparison = d.comparison; } catch { comparison = null; } },
  async loadModQueue() { try { const d = await api.getModQueue(); modQueue = d.mod_queue; } catch { modQueue = null; } },
  async loadNewMembers() { try { const d = await api.getNewMembers(); newMembers = d.members || []; } catch { newMembers = []; } },

  // Innovative features
  async whatIf(thresholds: any[], days?: number) { const d = await api.postWhatIf(thresholds, days); return d.results; },
  async loadSentimentTrends(days?: number) { const d = await api.getSentimentTrends(days); sentimentTrends = d.sentiment; },
  async loadMergeSuggestions(days?: number) { const d = await api.getMergeSuggestions(days); mergeSuggestions = d.merge.suggestions; },
};
