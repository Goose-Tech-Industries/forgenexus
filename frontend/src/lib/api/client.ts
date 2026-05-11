const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:4000/api';

class ApiClient {
  // Token kept in memory only — used for WebSocket auth, never persisted to storage
  private wsToken: string | null = null;

  /** Store token in memory for WebSocket use. Cookie handles HTTP auth. */
  setToken(token: string | null) {
    this.wsToken = token;
  }

  /** Explicitly hit /auth/refresh; used on app boot to seed wsToken from cookie session. */
  async refreshToken(): Promise<{ token?: string; user?: any } | null> {
    try {
      const data = await this.request('/auth/refresh', { method: 'POST' });
      if (data?.token) this.wsToken = data.token;
      return data;
    } catch {
      return null;
    }
  }

  /** Get the token for WebSocket connections */
  getWsToken(): string | null {
    return this.wsToken;
  }

  /** No-op — cookies are loaded automatically by the browser */
  loadToken() {
    // httpOnly cookie is sent automatically, nothing to load
  }

  private refreshing: Promise<boolean> | null = null;

  async request(path: string, options: RequestInit = {}, _isRetry = false): Promise<any> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...((options.headers as Record<string, string>) || {})
    };

    const res = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers,
      credentials: 'include'  // Send httpOnly cookies
    });

    // Auto-refresh on 401 (expired access token) — try once
    if (res.status === 401 && !_isRetry && path !== '/auth/refresh' && path !== '/auth/login') {
      const refreshed = await this.tryRefresh();
      if (refreshed) {
        return this.request(path, options, true);
      }
    }

    if (!res.ok) {
      const error = await res.json().catch(() => ({ error: 'Request failed' }));
      throw { status: res.status, ...error };
    }

    return res.json();
  }

  /** Silently refresh the access token using the refresh cookie */
  private async tryRefresh(): Promise<boolean> {
    // Deduplicate concurrent refresh attempts
    if (this.refreshing) return this.refreshing;

    this.refreshing = (async () => {
      try {
        const res = await fetch(`${API_BASE}/auth/refresh`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' }
        });
        if (res.ok) {
          const data = await res.json();
          this.wsToken = data.token;
          return true;
        }
        return false;
      } catch {
        return false;
      } finally {
        this.refreshing = null;
      }
    })();

    return this.refreshing;
  }

  // Auth
  register(user: { username: string; email: string; password: string }) {
    return this.request('/auth/register', { method: 'POST', body: JSON.stringify({ user }) });
  }

  login(email: string, password: string) {
    return this.request('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
  }

  me() {
    return this.request('/auth/me');
  }

  logout() {
    return this.request('/auth/logout', { method: 'POST' });
  }

  // Forums
  getForums() {
    return this.request('/forums');
  }

  getForumThreads(slug: string, page = 1, opts?: { sort?: string; prefix?: string }) {
    const params = new URLSearchParams({ page: String(page) });
    if (opts?.sort) params.set('sort', opts.sort);
    if (opts?.prefix) params.set('prefix', opts.prefix);
    return this.request(`/forums/${slug}/threads?${params.toString()}`);
  }

  // Threads
  getThread(slug: string, page = 1) {
    return this.request(`/threads/${slug}?page=${page}`);
  }

  createThread(data: { title: string; body: string; forum_id: string }) {
    return this.request('/threads', { method: 'POST', body: JSON.stringify({ thread: data }) });
  }

  replyToThread(slug: string, body: string) {
    return this.request(`/threads/${slug}/reply`, { method: 'POST', body: JSON.stringify({ post: { body } }) });
  }

  // Chat
  getConversations() {
    return this.request('/chat/conversations');
  }

  getMessages(conversationId: string) {
    return this.request(`/chat/conversations/${conversationId}/messages`);
  }

  sendDmMessage(conversationId: string, body: string) {
    return this.request(`/chat/conversations/${conversationId}/messages`, {
      method: 'POST', body: JSON.stringify({ body })
    });
  }

  editDmMessage(conversationId: string, messageId: string, body: string) {
    return this.request(`/chat/conversations/${conversationId}/messages/${messageId}`, {
      method: 'PUT', body: JSON.stringify({ body })
    });
  }

  deleteDmMessage(conversationId: string, messageId: string) {
    return this.request(`/chat/conversations/${conversationId}/messages/${messageId}`, { method: 'DELETE' });
  }

  updatePresence(data: Record<string, any>) {
    return this.request('/presence', { method: 'PUT', body: JSON.stringify(data) });
  }

  createDirectChat(userId: string) {
    return this.request('/chat/conversations/direct', { method: 'POST', body: JSON.stringify({ user_id: userId }) });
  }

  getFriends() {
    return this.request('/chat/friends');
  }

  createGroupChat(title: string, participantIds: string[]) {
    return this.request('/chat/conversations/group', {
      method: 'POST',
      body: JSON.stringify({ title, participant_ids: participantIds })
    });
  }

  // Shoutbox
  getShoutbox() {
    return this.request('/shoutbox');
  }

  sendShoutbox(body: string) {
    return this.request('/shoutbox', { method: 'POST', body: JSON.stringify({ body }) });
  }

  // Settings
  getPublicSettings() {
    return this.request('/settings/public');
  }

  // Profiles
  getProfile(slug: string) {
    return this.request(`/profiles/${slug}`);
  }

  getReputationBreakdown(slug: string) {
    return this.request(`/profiles/${slug}/reputation`);
  }

  updateProfile(data: Record<string, any>) {
    return this.request('/profile', { method: 'PUT', body: JSON.stringify({ profile: data }) });
  }

  setTopFriends(friendIds: string[]) {
    return this.request('/profile/top-friends', {
      method: 'PUT',
      body: JSON.stringify({ friend_ids: friendIds })
    });
  }

  getGuestbook(slug: string, page = 1) {
    return this.request(`/profiles/${slug}/guestbook?page=${page}`);
  }

  signGuestbook(slug: string, body: string) {
    return this.request(`/profiles/${slug}/guestbook`, {
      method: 'POST',
      body: JSON.stringify({ body })
    });
  }

  deleteGuestbookEntry(id: string) {
    return this.request(`/guestbook/${id}`, { method: 'DELETE' });
  }

  // Themes
  getThemes() {
    return this.request('/themes');
  }

  getTheme(id: string) {
    return this.request(`/themes/${id}`);
  }

  // Avatar Frames
  getAvatarFrames() {
    return this.request('/avatar-frames');
  }

  // === Moderation (User-facing) ===

  createReport(data: { reason: string; description?: string; reportable_type: string; reportable_id: string }) {
    return this.request('/reports', { method: 'POST', body: JSON.stringify({ report: data }) });
  }

  getMyReports(page = 1) {
    return this.request(`/reports/mine?page=${page}`);
  }

  // === Moderation (Staff) ===

  // Reports
  getReports(params?: { status?: string; assigned_to_id?: string; limit?: number; offset?: number }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/reports${query ? `?${query}` : ''}`);
  }

  getReport(id: string) {
    return this.request(`/mod/reports/${id}`);
  }

  getReportWithContext(id: string) {
    return this.request(`/mod/reports/${id}/context`);
  }

  assignReport(id: string, moderatorId?: string) {
    return this.request(`/mod/reports/${id}/assign`, {
      method: 'PUT',
      body: JSON.stringify({ moderator_id: moderatorId })
    });
  }

  resolveReport(id: string, resolutionNote?: string) {
    return this.request(`/mod/reports/${id}/resolve`, {
      method: 'PUT',
      body: JSON.stringify({ resolution_note: resolutionNote })
    });
  }

  dismissReport(id: string, resolutionNote?: string) {
    return this.request(`/mod/reports/${id}/dismiss`, {
      method: 'PUT',
      body: JSON.stringify({ resolution_note: resolutionNote })
    });
  }

  // Bans
  getBans(params?: { user_id?: string; active_only?: string }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/bans${query ? `?${query}` : ''}`);
  }

  createBan(data: { user_id: string; type: string; reason: string; expires_at?: string; ip_address?: string }) {
    return this.request('/mod/bans', { method: 'POST', body: JSON.stringify({ ban: data }) });
  }

  revokeBan(id: string) {
    return this.request(`/mod/bans/${id}/revoke`, { method: 'PUT' });
  }

  // Warnings
  getWarnings(userId: string, activeOnly = false) {
    return this.request(`/mod/warnings?user_id=${userId}&active_only=${activeOnly}`);
  }

  createWarning(data: { user_id: string; type?: string; reason: string; points?: number; expires_at?: string }) {
    return this.request('/mod/warnings', { method: 'POST', body: JSON.stringify({ warning: data }) });
  }

  revokeWarning(id: string) {
    return this.request(`/mod/warnings/${id}/revoke`, { method: 'PUT' });
  }

  // User infractions
  getUserInfractions(userId: string) {
    return this.request(`/mod/users/${userId}/infractions`);
  }

  // Mod Notes
  getModNotes(userId: string) {
    return this.request(`/mod/users/${userId}/notes`);
  }

  createModNote(userId: string, body: string) {
    return this.request(`/mod/users/${userId}/notes`, {
      method: 'POST',
      body: JSON.stringify({ body })
    });
  }

  deleteModNote(id: string) {
    return this.request(`/mod/notes/${id}`, { method: 'DELETE' });
  }

  // Mod Log
  getModLogs(params?: { moderator_id?: string; action?: string; target_type?: string; limit?: number; offset?: number }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/logs${query ? `?${query}` : ''}`);
  }

  // Thread management
  lockThread(id: string) {
    return this.request(`/mod/threads/${id}/lock`, { method: 'PUT' });
  }

  unlockThread(id: string) {
    return this.request(`/mod/threads/${id}/unlock`, { method: 'PUT' });
  }

  pinThread(id: string) {
    return this.request(`/mod/threads/${id}/pin`, { method: 'PUT' });
  }

  unpinThread(id: string) {
    return this.request(`/mod/threads/${id}/unpin`, { method: 'PUT' });
  }

  hideThread(id: string, reason?: string) {
    return this.request(`/mod/threads/${id}/hide`, {
      method: 'PUT',
      body: JSON.stringify({ reason })
    });
  }

  unhideThread(id: string) {
    return this.request(`/mod/threads/${id}/unhide`, { method: 'PUT' });
  }

  moveThread(id: string, forumId: string) {
    return this.request(`/mod/threads/${id}/move`, {
      method: 'PUT',
      body: JSON.stringify({ forum_id: forumId })
    });
  }

  mergeThreads(sourceId: string, targetThreadId: string) {
    return this.request(`/mod/threads/${sourceId}/merge`, {
      method: 'PUT',
      body: JSON.stringify({ target_thread_id: targetThreadId })
    });
  }

  // === Appeals (User-facing) ===

  createAppeal(data: { type: string; target_id: string; reason: string }) {
    return this.request('/appeals', { method: 'POST', body: JSON.stringify({ appeal: data }) });
  }

  getMyAppeals(page = 1) {
    return this.request(`/appeals/mine?limit=25&offset=${(page - 1) * 25}`);
  }

  // === Appeals (Staff) ===

  getAppeals(params?: { status?: string; limit?: number; offset?: number }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/appeals${query ? `?${query}` : ''}`);
  }

  getAppeal(id: string) {
    return this.request(`/mod/appeals/${id}`);
  }

  reviewAppeal(id: string, decision: string, decisionNote?: string) {
    return this.request(`/mod/appeals/${id}/review`, {
      method: 'PUT',
      body: JSON.stringify({ decision, decision_note: decisionNote })
    });
  }

  // === Dashboard / Workload ===

  getWorkload(moderatorId?: string) {
    const query = moderatorId ? `?moderator_id=${moderatorId}` : '';
    return this.request(`/mod/dashboard/workload${query}`);
  }

  getQueueStats() {
    return this.request('/mod/dashboard/queue');
  }

  getSuggestedAssignment() {
    return this.request('/mod/dashboard/suggest-assignment');
  }

  // Post management
  hidePost(id: string, reason?: string) {
    return this.request(`/mod/posts/${id}/hide`, {
      method: 'PUT',
      body: JSON.stringify({ reason })
    });
  }

  unhidePost(id: string) {
    return this.request(`/mod/posts/${id}/unhide`, { method: 'PUT' });
  }

  // === Suspicious Accounts ===

  getSuspiciousAccounts(params?: { reviewed?: string; limit?: number; offset?: number }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/suspicious-accounts${query ? `?${query}` : ''}`);
  }

  scanSuspicious(userId: string) {
    return this.request(`/mod/suspicious-accounts/scan/${userId}`, { method: 'POST' });
  }

  reviewSuspicious(id: string) {
    return this.request(`/mod/suspicious-accounts/${id}/review`, { method: 'PUT' });
  }

  // === Impersonation (Admin) ===

  startImpersonation(targetUserId: string, reason: string) {
    return this.request('/admin/impersonate/start', {
      method: 'POST',
      body: JSON.stringify({ target_user_id: targetUserId, reason })
    });
  }

  endImpersonation() {
    return this.request('/admin/impersonate/end', { method: 'POST' });
  }

  getActiveImpersonation() {
    return this.request('/admin/impersonate/active');
  }

  getImpersonationLogs(params?: { admin_id?: string; limit?: number; offset?: number }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/admin/impersonate/logs${query ? `?${query}` : ''}`);
  }

  // === Double Post Merge ===

  checkDoubleMerge(threadId: string, body: string) {
    return this.request('/mod/posts/check-merge', {
      method: 'POST',
      body: JSON.stringify({ thread_id: threadId, body })
    });
  }

  // === Content Policies ===

  getPolicies(params?: { forum_id?: string; active_only?: string }) {
    const query = new URLSearchParams(params as Record<string, string>).toString();
    return this.request(`/mod/policies${query ? `?${query}` : ''}`);
  }

  getPolicy(id: string) {
    return this.request(`/mod/policies/${id}`);
  }

  createPolicy(data: Record<string, any>) {
    return this.request('/mod/policies', { method: 'POST', body: JSON.stringify({ policy: data }) });
  }

  updatePolicy(id: string, data: Record<string, any>) {
    return this.request(`/mod/policies/${id}`, { method: 'PUT', body: JSON.stringify({ policy: data }) });
  }

  deletePolicy(id: string) {
    return this.request(`/mod/policies/${id}`, { method: 'DELETE' });
  }

  // === Plugin System ===

  getFlows(params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/flows${q ? `?${q}` : ''}`);
  }
  getFlow(id: string) { return this.request(`/admin/plugins/flows/${id}`); }
  createFlow(data: Record<string, any>) { return this.request('/admin/plugins/flows', { method: 'POST', body: JSON.stringify({ flow: data }) }); }
  updateFlow(id: string, data: Record<string, any>) { return this.request(`/admin/plugins/flows/${id}`, { method: 'PUT', body: JSON.stringify({ flow: data }) }); }
  deleteFlow(id: string) { return this.request(`/admin/plugins/flows/${id}`, { method: 'DELETE' }); }
  activateFlow(id: string) { return this.request(`/admin/plugins/flows/${id}/activate`, { method: 'PUT' }); }
  deactivateFlow(id: string) { return this.request(`/admin/plugins/flows/${id}/deactivate`, { method: 'PUT' }); }
  executeFlow(id: string, params?: Record<string, any>) { return this.request(`/admin/plugins/flows/${id}/execute`, { method: 'POST', body: JSON.stringify({ params }) }); }
  getNodeTypes() { return this.request('/admin/plugins/flows/node-types'); }

  getExecutions(params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/executions${q ? `?${q}` : ''}`);
  }
  getExecution(id: string) { return this.request(`/admin/plugins/executions/${id}`); }

  getDataTables(params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/data-tables${q ? `?${q}` : ''}`);
  }
  getDataTable(id: string) { return this.request(`/admin/plugins/data-tables/${id}`); }
  createDataTable(data: Record<string, any>) { return this.request('/admin/plugins/data-tables', { method: 'POST', body: JSON.stringify({ table: data }) }); }
  updateDataTable(id: string, data: Record<string, any>) { return this.request(`/admin/plugins/data-tables/${id}`, { method: 'PUT', body: JSON.stringify({ table: data }) }); }
  deleteDataTable(id: string) { return this.request(`/admin/plugins/data-tables/${id}`, { method: 'DELETE' }); }
  addDataColumn(tableId: string, data: Record<string, any>) { return this.request(`/admin/plugins/data-tables/${tableId}/columns`, { method: 'POST', body: JSON.stringify({ column: data }) }); }
  deleteDataColumn(tableId: string, colId: string) { return this.request(`/admin/plugins/data-tables/${tableId}/columns/${colId}`, { method: 'DELETE' }); }
  getDataRows(tableId: string, params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/data-tables/${tableId}/rows${q ? `?${q}` : ''}`);
  }
  createDataRow(tableId: string, data: Record<string, any>) { return this.request(`/admin/plugins/data-tables/${tableId}/rows`, { method: 'POST', body: JSON.stringify({ row: data }) }); }
  updateDataRow(tableId: string, rowId: string, data: Record<string, any>) { return this.request(`/admin/plugins/data-tables/${tableId}/rows/${rowId}`, { method: 'PUT', body: JSON.stringify({ row: data }) }); }
  deleteDataRow(tableId: string, rowId: string) { return this.request(`/admin/plugins/data-tables/${tableId}/rows/${rowId}`, { method: 'DELETE' }); }

  // === Admin Dashboard ===

  getWarRoom() { return this.request('/admin/dashboard/war-room'); }
  getLiveFeed(limit = 30) { return this.request(`/admin/dashboard/live-feed?limit=${limit}`); }
  getComparison() { return this.request('/admin/dashboard/comparison'); }
  getModQueue() { return this.request('/admin/dashboard/mod-queue'); }
  getNewMembers() { return this.request('/admin/dashboard/new-members'); }
  getHealthScore() { return this.request('/admin/dashboard/health-score'); }
  getContentDecay() { return this.request('/admin/dashboard/content-decay'); }
  getRegistrationFunnel(days?: number) { return this.request(`/admin/dashboard/registration-funnel${days ? `?days=${days}` : ''}`); }
  getPluginImpact() { return this.request('/admin/dashboard/plugin-impact'); }
  getActivityHeatmap(days?: number) { return this.request(`/admin/dashboard/activity-heatmap${days ? `?days=${days}` : ''}`); }
  postWhatIf(thresholds: any[], days?: number) { return this.request(`/admin/dashboard/what-if`, { method: 'POST', body: JSON.stringify({ thresholds, days: days || 90 }) }); }
  getSentimentTrends(days?: number) { return this.request(`/admin/dashboard/sentiment-trends${days ? `?days=${days}` : ''}`); }
  getMergeSuggestions(days?: number) { return this.request(`/admin/dashboard/merge-suggestions${days ? `?days=${days}` : ''}`); }

  // Admin Settings
  getAdminSettings() { return this.request('/admin/settings'); }
  updateAdminSettings(settings: Record<string, string>) { return this.request('/admin/settings', { method: 'PUT', body: JSON.stringify({ settings }) }); }

  // Admin Users
  getAdminUsers(params?: Record<string, string>) { const q = new URLSearchParams(params || {}).toString(); return this.request(`/admin/users${q ? `?${q}` : ''}`); }
  getAdminUser(id: string) { return this.request(`/admin/users/${id}`); }
  updateAdminUser(id: string, data: Record<string, any>) { return this.request(`/admin/users/${id}`, { method: 'PUT', body: JSON.stringify({ user: data }) }); }
  deleteAdminUser(id: string) { return this.request(`/admin/users/${id}`, { method: 'DELETE' }); }
  resetUserPassword(id: string) { return this.request(`/admin/users/${id}/reset-password`, { method: 'POST' }); }
  bulkUserAction(action: string, userIds: string[], params?: Record<string, any>) { return this.request('/admin/users/bulk', { method: 'POST', body: JSON.stringify({ action, user_ids: userIds, ...params }) }); }
  getUserJourney(id: string) { return this.request(`/admin/users/${id}/journey`); }
  searchUsersByIp(ip: string) { return this.request(`/admin/users/search-by-ip?ip=${encodeURIComponent(ip)}`); }

  // Admin Groups & Ranks
  getAdminGroups() { return this.request('/admin/groups'); }
  createAdminGroup(data: Record<string, any>) { return this.request('/admin/groups', { method: 'POST', body: JSON.stringify({ group: data }) }); }
  updateAdminGroup(id: string, data: Record<string, any>) { return this.request(`/admin/groups/${id}`, { method: 'PUT', body: JSON.stringify({ group: data }) }); }
  deleteAdminGroup(id: string) { return this.request(`/admin/groups/${id}`, { method: 'DELETE' }); }
  getGroupMembers(id: string) { return this.request(`/admin/groups/${id}/members`); }
  addGroupMember(groupId: string, userId: string) { return this.request(`/admin/groups/${groupId}/members`, { method: 'POST', body: JSON.stringify({ user_id: userId }) }); }
  removeGroupMember(groupId: string, userId: string) { return this.request(`/admin/groups/${groupId}/members/${userId}`, { method: 'DELETE' }); }
  getAdminRanks() { return this.request('/admin/ranks'); }
  createAdminRank(data: Record<string, any>) { return this.request('/admin/ranks', { method: 'POST', body: JSON.stringify({ rank: data }) }); }
  updateAdminRank(id: string, data: Record<string, any>) { return this.request(`/admin/ranks/${id}`, { method: 'PUT', body: JSON.stringify({ rank: data }) }); }
  deleteAdminRank(id: string) { return this.request(`/admin/ranks/${id}`, { method: 'DELETE' }); }

  // Admin Forums
  getAdminForums() { return this.request('/admin/forums/all'); }
  createAdminCategory(data: Record<string, any>) { return this.request('/admin/categories', { method: 'POST', body: JSON.stringify({ category: data }) }); }
  updateAdminCategory(id: string, data: Record<string, any>) { return this.request(`/admin/categories/${id}`, { method: 'PUT', body: JSON.stringify({ category: data }) }); }
  deleteAdminCategory(id: string) { return this.request(`/admin/categories/${id}`, { method: 'DELETE' }); }
  createAdminForum(data: Record<string, any>) { return this.request('/admin/forums', { method: 'POST', body: JSON.stringify({ forum: data }) }); }
  updateAdminForum(id: string, data: Record<string, any>) { return this.request(`/admin/forums/${id}`, { method: 'PUT', body: JSON.stringify({ forum: data }) }); }
  deleteAdminForum(id: string) { return this.request(`/admin/forums/${id}`, { method: 'DELETE' }); }

  // Admin Themes
  getAdminThemes() { return this.request('/admin/themes'); }
  createAdminTheme(data: Record<string, any>) { return this.request('/admin/themes', { method: 'POST', body: JSON.stringify({ theme: data }) }); }
  updateAdminTheme(id: string, data: Record<string, any>) { return this.request(`/admin/themes/${id}`, { method: 'PUT', body: JSON.stringify({ theme: data }) }); }
  deleteAdminTheme(id: string) { return this.request(`/admin/themes/${id}`, { method: 'DELETE' }); }
  setDefaultTheme(id: string) { return this.request(`/admin/themes/${id}/set-default`, { method: 'PUT' }); }

  // Admin Announcements
  getAnnouncements() { return this.request('/admin/announcements'); }
  createAnnouncement(data: Record<string, any>) { return this.request('/admin/announcements', { method: 'POST', body: JSON.stringify({ announcement: data }) }); }
  updateAnnouncement(id: string, data: Record<string, any>) { return this.request(`/admin/announcements/${id}`, { method: 'PUT', body: JSON.stringify({ announcement: data }) }); }
  deleteAnnouncement(id: string) { return this.request(`/admin/announcements/${id}`, { method: 'DELETE' }); }
  getActiveAnnouncements() { return this.request('/announcements/active'); }

  // Admin Maintenance
  getSystemInfo() { return this.request('/admin/maintenance/info'); }
  getDbStats() { return this.request('/admin/maintenance/db-stats'); }
  clearCache() { return this.request('/admin/maintenance/clear-cache', { method: 'POST' }); }
  reindexSearch() { return this.request('/admin/maintenance/reindex-search', { method: 'POST' }); }

  getAuditLogs(params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/audit-logs${q ? `?${q}` : ''}`);
  }
  rollbackAuditLog(id: string) { return this.request(`/admin/audit-logs/${id}/rollback`, { method: 'POST' }); }
  reorderCategories(orderedIds: string[]) { return this.request('/admin/forums/reorder-categories', { method: 'PUT', body: JSON.stringify({ ordered_ids: orderedIds }) }); }
  reorderForums(categoryId: string, orderedIds: string[]) { return this.request(`/admin/forums/${categoryId}/reorder-forums`, { method: 'PUT', body: JSON.stringify({ ordered_ids: orderedIds }) }); }

  // === Chat Channels ===

  getChannels() { return this.request('/channels'); }
  getChannel(slug: string) { return this.request(`/channels/${slug}`); }
  getChannelMessages(slug: string, params?: { before?: string; limit?: number }) {
    const q = new URLSearchParams(params as Record<string, string> || {}).toString();
    return this.request(`/channels/${slug}/messages${q ? `?${q}` : ''}`);
  }
  sendChannelMessage(slug: string, data: { body: string; reply_to_id?: string }) {
    return this.request(`/channels/${slug}/messages`, { method: 'POST', body: JSON.stringify({ message: data }) });
  }
  editChannelMessage(slug: string, messageId: string, body: string) {
    return this.request(`/channels/${slug}/messages/${messageId}`, { method: 'PUT', body: JSON.stringify({ message: { body } }) });
  }
  deleteChannelMessage(slug: string, messageId: string) {
    return this.request(`/channels/${slug}/messages/${messageId}`, { method: 'DELETE' });
  }
  markChannelRead(slug: string, messageId: string) {
    return this.request(`/channels/${slug}/read`, { method: 'PUT', body: JSON.stringify({ message_id: messageId }) });
  }
  addReaction(slug: string, messageId: string, emoji: string) {
    return this.request(`/channels/${slug}/messages/${messageId}/reactions`, { method: 'POST', body: JSON.stringify({ emoji }) });
  }
  removeReaction(slug: string, messageId: string, emoji: string) {
    return this.request(`/channels/${slug}/messages/${messageId}/reactions/${encodeURIComponent(emoji)}`, { method: 'DELETE' });
  }
  getChannelPins(slug: string) { return this.request(`/channels/${slug}/pins`); }
  pinMessage(slug: string, messageId: string) {
    return this.request(`/channels/${slug}/messages/${messageId}/pin`, { method: 'POST' });
  }
  unpinMessage(slug: string, messageId: string) {
    return this.request(`/channels/${slug}/messages/${messageId}/pin`, { method: 'DELETE' });
  }
  updateChannelSettings(slug: string, data: { notification_level?: string; is_muted?: boolean }) {
    return this.request(`/channels/${slug}/settings`, { method: 'PUT', body: JSON.stringify(data) });
  }

  // Mentions
  getUnreadMentions() { return this.request('/mentions'); }
  markMentionsRead(channelId: string) { return this.request('/mentions/read', { method: 'PUT', body: JSON.stringify({ channel_id: channelId }) }); }

  // Notifications
  getNotifications(params?: { limit?: number; offset?: number; unread_only?: boolean }) {
    const q = new URLSearchParams(params as Record<string, string> || {}).toString();
    return this.request(`/notifications${q ? `?${q}` : ''}`);
  }
  getNotificationCount() { return this.request('/notifications/count'); }
  markNotificationRead(id: string) { return this.request(`/notifications/${id}/read`, { method: 'PUT' }); }
  markAllNotificationsRead() { return this.request('/notifications/read-all', { method: 'PUT' }); }
  deleteNotification(id: string) { return this.request(`/notifications/${id}`, { method: 'DELETE' }); }

  // User Status
  updateStatus(data: { status?: string; custom_text?: string; custom_emoji?: string }) {
    return this.request('/status', { method: 'PUT', body: JSON.stringify(data) });
  }

  // Chat Threads
  getChannelThreads(channelSlug: string) {
    return this.request(`/channels/${channelSlug}/threads`);
  }
  createChatThread(channelSlug: string, messageId: string, name: string) {
    return this.request(`/channels/${channelSlug}/messages/${messageId}/thread`, {
      method: 'POST', body: JSON.stringify({ name })
    });
  }
  getChatThread(threadId: string) {
    return this.request(`/threads/${threadId}`);
  }
  getThreadMessages(threadId: string, params?: { before?: string; limit?: number }) {
    const qs = new URLSearchParams();
    if (params?.before) qs.set('before', params.before);
    if (params?.limit) qs.set('limit', String(params.limit));
    const q = qs.toString();
    return this.request(`/threads/${threadId}/messages${q ? '?' + q : ''}`);
  }
  sendThreadMessage(threadId: string, body: string) {
    return this.request(`/threads/${threadId}/messages`, {
      method: 'POST', body: JSON.stringify({ body })
    });
  }

  // DM Calls
  initiateCall(conversationId: string, type: string = 'audio') {
    return this.request('/calls', { method: 'POST', body: JSON.stringify({ conversation_id: conversationId, type }) });
  }
  answerCall(callId: string) {
    return this.request(`/calls/${callId}/answer`, { method: 'POST' });
  }
  declineCall(callId: string) {
    return this.request(`/calls/${callId}/decline`, { method: 'POST' });
  }
  hangUpCall(callId: string) {
    return this.request(`/calls/${callId}/hang-up`, { method: 'POST' });
  }
  getActiveCall(conversationId: string) {
    return this.request(`/calls/active/${conversationId}`);
  }
  getCallHistory(conversationId: string) {
    return this.request(`/calls/history/${conversationId}`);
  }

  // Voice Rooms
  getVoiceRooms() { return this.request('/voice/rooms'); }
  getVoiceRoom(slug: string) { return this.request(`/voice/rooms/${slug}`); }
  getLiveKitToken(roomId: string): Promise<{ token: string; url: string; room: string; identity: string; role: string }> {
    return this.request(`/voice/rooms/${roomId}/token`, { method: 'POST', body: '{}' });
  }
  getRoomRecordings(slug: string) { return this.request(`/voice/rooms/${slug}/recordings`); }
  getRecording(id: string) { return this.request(`/voice/recordings/${id}`); }
  async uploadVoiceRecording(roomId: string, blob: Blob, meta: { started_at: string; ended_at: string; duration_seconds: number; participant_count: number; title?: string }) {
    const form = new FormData();
    form.append('audio', blob, `recording-${Date.now()}.webm`);
    form.append('started_at', meta.started_at);
    form.append('ended_at', meta.ended_at);
    form.append('duration_seconds', String(meta.duration_seconds));
    form.append('participant_count', String(meta.participant_count));
    if (meta.title) form.append('title', meta.title);
    const res = await fetch(`${API_BASE}/voice/rooms/${roomId}/recordings`, {
      method: 'POST',
      body: form,
      credentials: 'include'
    });
    if (!res.ok) throw await res.json().catch(() => ({ error: 'Upload failed' }));
    return res.json();
  }

  // Bookmarks
  getBookmarks() { return this.request('/bookmarks'); }
  getBookmarkIds() { return this.request('/bookmarks/ids'); }
  toggleBookmark(messageId: string, note?: string) {
    return this.request(`/bookmarks/${messageId}`, {
      method: 'POST',
      body: JSON.stringify({ note: note || undefined })
    });
  }

  // Post Bookmarks (Forum)
  getPostBookmarks() { return this.request('/post-bookmarks'); }
  getPostBookmarkIds() { return this.request('/post-bookmarks/ids'); }
  togglePostBookmark(postId: string, note?: string) {
    return this.request(`/posts/${postId}/bookmark`, {
      method: 'POST',
      body: JSON.stringify({ note: note || undefined })
    });
  }

  // Drafts
  saveDraft(contextType: string, contextId: string, body: string, title?: string) {
    return this.request('/drafts', {
      method: 'POST',
      body: JSON.stringify({ context_type: contextType, context_id: contextId, body, title })
    });
  }
  getDraft(contextType: string, contextId: string) {
    return this.request(`/drafts/${contextType}/${contextId}`);
  }
  deleteDraft(contextType: string, contextId: string) {
    return this.request(`/drafts/${contextType}/${contextId}`, { method: 'DELETE' });
  }

  // Bulk Thread Moderation
  bulkThreadAction(action: string, threadIds: string[], targetForumId?: string) {
    return this.request('/mod/threads/bulk', {
      method: 'POST',
      body: JSON.stringify({ action, thread_ids: threadIds, target_forum_id: targetForumId })
    });
  }

  // Webhooks
  getWebhooks(channelId: string) { return this.request(`/admin/webhooks?channel_id=${channelId}`); }
  createWebhook(data: Record<string, any>) {
    return this.request('/admin/webhooks', { method: 'POST', body: JSON.stringify(data) });
  }
  updateWebhook(id: string, data: Record<string, any>) {
    return this.request(`/admin/webhooks/${id}`, { method: 'PUT', body: JSON.stringify(data) });
  }
  deleteWebhook(id: string) {
    return this.request(`/admin/webhooks/${id}`, { method: 'DELETE' });
  }
  regenerateWebhookToken(id: string) {
    return this.request(`/admin/webhooks/${id}/regenerate`, { method: 'POST' });
  }

  // Custom Emojis
  getCustomEmojis() { return this.request('/emojis'); }
  getAdminEmojis() { return this.request('/admin/emojis'); }
  createEmoji(data: Record<string, any>) {
    return this.request('/admin/emojis', { method: 'POST', body: JSON.stringify(data) });
  }
  updateEmoji(id: string, data: Record<string, any>) {
    return this.request(`/admin/emojis/${id}`, { method: 'PUT', body: JSON.stringify(data) });
  }
  deleteEmoji(id: string) {
    return this.request(`/admin/emojis/${id}`, { method: 'DELETE' });
  }

  // Message Edit History
  getMessageEdits(channelSlug: string, messageId: string) {
    return this.request(`/channels/${channelSlug}/messages/${messageId}/edits`);
  }

  // Channel Message Search
  searchMessages(params: { q: string; channel?: string; user_id?: string; has?: string; limit?: number; offset?: number }) {
    const qs = new URLSearchParams();
    qs.set('q', params.q);
    if (params.channel) qs.set('channel', params.channel);
    if (params.user_id) qs.set('user_id', params.user_id);
    if (params.has) qs.set('has', params.has);
    if (params.limit) qs.set('limit', String(params.limit));
    if (params.offset) qs.set('offset', String(params.offset));
    return this.request(`/channels/search?${qs.toString()}`);
  }

  // Admin Chat Management
  getAdminChatCategories() { return this.request('/admin/chat/categories'); }
  createChatCategory(data: Record<string, any>) { return this.request('/admin/chat/categories', { method: 'POST', body: JSON.stringify({ category: data }) }); }
  updateChatCategory(id: string, data: Record<string, any>) { return this.request(`/admin/chat/categories/${id}`, { method: 'PUT', body: JSON.stringify({ category: data }) }); }
  deleteChatCategory(id: string) { return this.request(`/admin/chat/categories/${id}`, { method: 'DELETE' }); }
  getAdminChatChannels() { return this.request('/admin/chat/channels'); }
  createChatChannel(data: Record<string, any>) { return this.request('/admin/chat/channels', { method: 'POST', body: JSON.stringify({ channel: data }) }); }
  updateChatChannel(id: string, data: Record<string, any>) { return this.request(`/admin/chat/channels/${id}`, { method: 'PUT', body: JSON.stringify({ channel: data }) }); }
  deleteChatChannel(id: string) { return this.request(`/admin/chat/channels/${id}`, { method: 'DELETE' }); }
  archiveChatChannel(id: string) { return this.request(`/admin/chat/channels/${id}/archive`, { method: 'PUT' }); }
  unarchiveChatChannel(id: string) { return this.request(`/admin/chat/channels/${id}/unarchive`, { method: 'PUT' }); }

  // === Online Users ===

  getOnlineUsers() { return this.request('/users/online'); }

  // Points/Currency
  getPoints() { return this.request('/points'); }
  getPointHistory() { return this.request('/points/history'); }
  getPointsLeaderboard() { return this.request('/points/leaderboard'); }
  getPointsConfig() { return this.request('/admin/points/config'); }
  updatePointsConfig(action: string, points: number, isActive: boolean) {
    return this.request('/admin/points/config', { method: 'PUT', body: JSON.stringify({ action, points, is_active: isActive }) });
  }
  grantPoints(userId: string, amount: number, description?: string) {
    return this.request('/admin/points/grant', { method: 'POST', body: JSON.stringify({ user_id: userId, amount, description }) });
  }

  // BBCode preview render (server-side, single-source-of-truth with stored HTML)
  renderBbcode(body: string) {
    return this.request('/bbcode/render', { method: 'POST', body: JSON.stringify({ body }) });
  }

  // === Community SaaS billing (Stripe-backed) ===
  getBillingPlans() {
    return this.request('/billing/plans');
  }
  getCommunitySubscription(communityId: string) {
    return this.request(`/billing/communities/${communityId}/subscription`);
  }
  createCommunityCheckout(communityId: string, plan: string) {
    return this.request(`/billing/communities/${communityId}/checkout`, {
      method: 'POST',
      body: JSON.stringify({ plan })
    });
  }

  // Post Ratings
  ratePost(postId: string, ratingType: string) {
    return this.request(`/posts/${postId}/rate`, { method: 'POST', body: JSON.stringify({ rating_type: ratingType }) });
  }
  getPostRatings(postId: string) { return this.request(`/posts/${postId}/ratings`); }

  // Events/Calendar
  getEvents(month?: number, year?: number) {
    const qs = new URLSearchParams();
    if (month) qs.set('month', String(month));
    if (year) qs.set('year', String(year));
    const q = qs.toString();
    return this.request(`/events${q ? '?' + q : ''}`);
  }
  getUpcomingEvents() { return this.request('/events/upcoming'); }
  getEvent(id: string) { return this.request(`/events/${id}`); }
  createEvent(data: Record<string, any>) { return this.request('/events', { method: 'POST', body: JSON.stringify(data) }); }
  updateEvent(id: string, data: Record<string, any>) { return this.request(`/events/${id}`, { method: 'PUT', body: JSON.stringify(data) }); }
  deleteEvent(id: string) { return this.request(`/events/${id}`, { method: 'DELETE' }); }
  rsvpEvent(id: string, status = 'going') { return this.request(`/events/${id}/rsvp`, { method: 'POST', body: JSON.stringify({ status }) }); }
  getEventSuggestions() { return this.request('/events/suggestions'); }

  // Gallery
  getUserAlbums(userId: string) { return this.request(`/gallery/user/${userId}`); }
  getMyAlbums() { return this.request('/gallery/mine'); }
  getAlbum(id: string) { return this.request(`/gallery/albums/${id}`); }
  createAlbum(data: Record<string, any>) { return this.request('/gallery/albums', { method: 'POST', body: JSON.stringify(data) }); }
  updateAlbum(id: string, data: Record<string, any>) { return this.request(`/gallery/albums/${id}`, { method: 'PUT', body: JSON.stringify(data) }); }
  deleteAlbum(id: string) { return this.request(`/gallery/albums/${id}`, { method: 'DELETE' }); }
  addMedia(albumId: string, data: Record<string, any>) { return this.request(`/gallery/albums/${albumId}/media`, { method: 'POST', body: JSON.stringify(data) }); }
  removeMedia(id: string) { return this.request(`/gallery/media/${id}`, { method: 'DELETE' }); }
  getRecentMedia() { return this.request('/gallery/recent'); }

  // Staff Applications
  getOpenApplicationForms() { return this.request('/applications/forms'); }
  getApplicationForm(id: string) { return this.request(`/applications/forms/${id}`); }
  submitApplication(formId: string, answers: any[]) { return this.request('/applications', { method: 'POST', body: JSON.stringify({ form_id: formId, answers }) }); }
  getMyApplications() { return this.request('/applications/mine'); }
  getAdminApplicationForms() { return this.request('/admin/applications/forms'); }
  createApplicationForm(data: Record<string, any>) { return this.request('/admin/applications/forms', { method: 'POST', body: JSON.stringify(data) }); }
  getAdminApplications(status?: string) { return this.request(`/admin/applications${status ? '?status=' + status : ''}`); }
  reviewApplication(id: string, status: string, note?: string) {
    return this.request(`/admin/applications/${id}/review`, { method: 'PUT', body: JSON.stringify({ status, note }) });
  }

  // Admin Innovative Features (19-28)
  getStaffPerformance(days = 30) { return this.request(`/admin/dashboard/staff-performance?days=${days}`); }
  getEngagementScores(limit = 50) { return this.request(`/admin/dashboard/engagement-scores?limit=${limit}`); }
  updateEngagementConfig(config: Record<string, number>) {
    return this.request('/admin/dashboard/engagement-scores/config', { method: 'PUT', body: JSON.stringify({ config }) });
  }
  getToxicWarning() { return this.request('/admin/dashboard/toxic-warning'); }
  getContentQuality(mode = 'best', limit = 20) { return this.request(`/admin/dashboard/content-quality?mode=${mode}&limit=${limit}`); }
  getGrowthForecast() { return this.request('/admin/dashboard/growth-forecast'); }
  getLapsedUsers(limit = 50) { return this.request(`/admin/dashboard/lapsed-users?limit=${limit}`); }
  getSeoHealth() { return this.request('/admin/dashboard/seo-health'); }
  getCleanupPreview() { return this.request('/admin/dashboard/cleanup-preview'); }
  runCleanup(rule: string) { return this.request('/admin/dashboard/cleanup-run', { method: 'POST', body: JSON.stringify({ rule }) }); }

  // Admin Mass Email
  sendMassEmail(data: { subject: string; body: string; segment: string }) {
    return this.request('/admin/mass-email', { method: 'POST', body: JSON.stringify(data) });
  }
  getMassEmailPreview(segment: string) { return this.request('/admin/mass-email/preview?segment=' + segment); }

  // === Welcome Center Stats ===

  getWelcomeStats() { return this.request('/stats/welcome'); }

  // === Forum Statistics ===

  getStats() { return this.request('/stats'); }

  // === Creator Subscription Tiers ($4.99 / $9.99 / $24.99 — Twitch-style) ===
  //
  // SAFETY LOCK (2026-05-04): the backend `Subscriptions.subscribe_user/3`
  // currently inserts a UserSubscription row WITHOUT going through Stripe —
  // so calling api.subscribe() would create a "free" sub that bypasses
  // payment. Until Stripe Connect is wired for creator payouts, the write
  // path is locked client-side. Read methods stay live so existing UI that
  // displays tier listings keeps working.
  //
  // To unlock: set VITE_PAYMENTS_LIVE=true at build time AFTER Stripe Connect
  // is wired end-to-end and tested in test mode.

  getSubscriptionTiers() { return this.request('/subscriptions/tiers'); }
  getMySubscription() { return this.request('/subscriptions/my'); }
  subscribe(_tierSlug: string): Promise<any> {
    if (import.meta.env.VITE_PAYMENTS_LIVE === 'true') {
      return this.request('/subscriptions', { method: 'POST', body: JSON.stringify({ tier_slug: _tierSlug }) });
    }
    console.warn('[client] api.subscribe() blocked: creator payments not yet wired through Stripe Connect.');
    return Promise.reject({ error: 'Creator subscriptions not yet available — Stripe Connect setup pending.', code: 'payments_not_live' });
  }
  cancelSubscription() {
    if (import.meta.env.VITE_PAYMENTS_LIVE === 'true') {
      return this.request('/subscriptions', { method: 'DELETE' });
    }
    return Promise.reject({ error: 'Creator subscriptions not yet active.', code: 'payments_not_live' });
  }

  // Admin Subscription Tiers
  getAdminSubscriptionTiers() { return this.request('/admin/subscription-tiers'); }
  createSubscriptionTier(data: Record<string, any>) { return this.request('/admin/subscription-tiers', { method: 'POST', body: JSON.stringify({ tier: data }) }); }
  updateSubscriptionTier(id: string, data: Record<string, any>) { return this.request(`/admin/subscription-tiers/${id}`, { method: 'PUT', body: JSON.stringify({ tier: data }) }); }
  deleteSubscriptionTier(id: string) { return this.request(`/admin/subscription-tiers/${id}`, { method: 'DELETE' }); }

  // === JS Plugins (Tier 2) ===

  getJsPlugins(params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/js-plugins${q ? `?${q}` : ''}`);
  }
  getJsPlugin(id: string) { return this.request(`/admin/plugins/js-plugins/${id}`); }
  createJsPlugin(data: Record<string, any>) { return this.request('/admin/plugins/js-plugins', { method: 'POST', body: JSON.stringify({ plugin: data }) }); }
  updateJsPlugin(id: string, data: Record<string, any>) { return this.request(`/admin/plugins/js-plugins/${id}`, { method: 'PUT', body: JSON.stringify({ plugin: data }) }); }
  deleteJsPlugin(id: string) { return this.request(`/admin/plugins/js-plugins/${id}`, { method: 'DELETE' }); }
  activateJsPlugin(id: string) { return this.request(`/admin/plugins/js-plugins/${id}/activate`, { method: 'PUT' }); }
  deactivateJsPlugin(id: string) { return this.request(`/admin/plugins/js-plugins/${id}/deactivate`, { method: 'PUT' }); }
  executeJsPlugin(id: string) { return this.request(`/admin/plugins/js-plugins/${id}/execute`, { method: 'POST' }); }
  getJsPluginExecutions(id: string, params?: Record<string, string>) {
    const q = new URLSearchParams(params || {}).toString();
    return this.request(`/admin/plugins/js-plugins/${id}/executions${q ? `?${q}` : ''}`);
  }
  // === OAuth ===

  getLinkedAccounts() { return this.request('/auth/oauth/accounts'); }
  linkOAuth(provider: string) { return this.request(`/auth/oauth/${provider}/link`, { method: 'POST' }); }
  unlinkOAuth(provider: string) { return this.request(`/auth/oauth/${provider}/unlink`, { method: 'DELETE' }); }

  // === Auth Extended ===

  forgotPassword(email: string) { return this.request('/auth/forgot-password', { method: 'POST', body: JSON.stringify({ email }) }); }
  resetPassword(token: string, password: string) { return this.request('/auth/reset-password', { method: 'POST', body: JSON.stringify({ token, password }) }); }
  verifyEmail(token: string) { return this.request('/auth/verify-email', { method: 'POST', body: JSON.stringify({ token }) }); }
  confirmEmailChange(token: string) { return this.request('/auth/confirm-email-change', { method: 'POST', body: JSON.stringify({ token }) }); }
  resendVerification() { return this.request('/auth/resend-verification', { method: 'POST' }); }
  changePassword(currentPassword: string, newPassword: string) { return this.request('/auth/change-password', { method: 'PUT', body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }) }); }
  changeEmail(newEmail: string, password: string) { return this.request('/auth/change-email', { method: 'POST', body: JSON.stringify({ new_email: newEmail, password }) }); }
  getSessions() { return this.request('/auth/sessions'); }
  revokeSession(id: string) { return this.request(`/auth/sessions/${id}`, { method: 'DELETE' }); }
  revokeAllSessions() { return this.request('/auth/sessions/all', { method: 'DELETE' }); }
  deactivateAccount(password: string, reason?: string) { return this.request('/auth/deactivate', { method: 'POST', body: JSON.stringify({ password, reason }) }); }
  getLoginHistory() { return this.request('/auth/login-history'); }
  getMyWarnings() { return this.request('/auth/my-warnings'); }
  exportData() { return this.request('/auth/export-data'); }

  // === File Uploads ===

  uploadFile(file: File, attachableType?: string, attachableId?: string) {
    const formData = new FormData();
    formData.append('file', file);
    if (attachableType && attachableId) {
      formData.append('attachable_type', attachableType);
      formData.append('attachable_id', attachableId);
    }

    return fetch(`${API_BASE}/uploads`, {
      method: 'POST',
      body: formData,
      credentials: 'include'
    }).then(async (res) => {
      if (!res.ok) throw await res.json().catch(() => ({ error: 'Upload failed' }));
      return res.json();
    });
  }

  getAttachments(type: string, id: string) { return this.request(`/uploads/${type}/${id}`); }
  deleteAttachment(id: string) { return this.request(`/uploads/${id}`, { method: 'DELETE' }); }

  // === Posts ===

  editPost(postId: string, body: string) { return this.request(`/posts/${postId}`, { method: 'PUT', body: JSON.stringify({ post: { body } }) }); }
  getPostHistory(postId: string) { return this.request(`/posts/${postId}/history`); }

  // === 2FA ===

  setup2FA() { return this.request('/auth/2fa/setup', { method: 'POST' }); }
  confirm2FA(code: string) { return this.request('/auth/2fa/confirm', { method: 'POST', body: JSON.stringify({ code }) }); }
  disable2FA(password: string) { return this.request('/auth/2fa/disable', { method: 'POST', body: JSON.stringify({ password }) }); }
  verify2FALogin(tempToken: string, code: string) { return this.request('/auth/2fa/verify', { method: 'POST', body: JSON.stringify({ temp_token: tempToken, code }) }); }

  // === @Mentions ===

  searchUsers(q: string) { return this.request(`/members/search?q=${encodeURIComponent(q)}`); }

  // === Members ===

  getMembers(opts: { page?: number; search?: string; sort?: string } = {}) {
    const params = new URLSearchParams();
    if (opts.page) params.set('page', String(opts.page));
    if (opts.search) params.set('search', opts.search);
    if (opts.sort) params.set('sort', opts.sort);
    return this.request(`/members?${params.toString()}`);
  }

  getRecentPosts(limit = 25) { return this.request(`/recent-posts?limit=${limit}`); }

  // Link Previews
  getLinkPreview(url: string) { return this.request(`/link-preview?url=${encodeURIComponent(url)}`); }

  // === Search ===

  search(query: string, opts: { type?: string; page?: number; author?: string; forum_id?: string } = {}) {
    const params = new URLSearchParams({ q: query });
    if (opts.type) params.set('type', opts.type);
    if (opts.page) params.set('page', String(opts.page));
    if (opts.author) params.set('author', opts.author);
    if (opts.forum_id) params.set('forum_id', opts.forum_id);
    return this.request(`/search?${params.toString()}`);
  }

  // === User Preferences ===

  getPreferences() { return this.request('/preferences'); }
  updatePreferences(prefs: Record<string, any>) { return this.request('/preferences', { method: 'PUT', body: JSON.stringify({ preferences: prefs }) }); }

  // === Content Ignores (Mute) ===

  getIgnores() { return this.request('/ignores'); }
  ignoreForum(forumId: string) { return this.request(`/ignores/forum/${forumId}`, { method: 'POST' }); }
  unignoreForum(forumId: string) { return this.request(`/ignores/forum/${forumId}`, { method: 'DELETE' }); }
  ignoreThread(threadId: string) { return this.request(`/ignores/thread/${threadId}`, { method: 'POST' }); }
  unignoreThread(threadId: string) { return this.request(`/ignores/thread/${threadId}`, { method: 'DELETE' }); }

  // === Thread Subscriptions ===

  getThreadSubscription(slug: string) { return this.request(`/threads/${slug}/subscription`); }
  updateThreadSubscription(slug: string, level: string) { return this.request(`/threads/${slug}/subscription`, { method: 'PUT', body: JSON.stringify({ notification_level: level }) }); }
  deleteThreadSubscription(slug: string) { return this.request(`/threads/${slug}/subscription`, { method: 'DELETE' }); }

  // === Thread Ratings ===

  rateThread(threadId: string, rating: number) { return this.request(`/threads/${threadId}/rating`, { method: 'POST', body: JSON.stringify({ rating }) }); }
  getThreadRating(threadId: string) { return this.request(`/threads/${threadId}/rating`); }

  // === Thread Read Status ===

  markThreadRead(slug: string) { return this.request(`/threads/${slug}/read`, { method: 'PUT' }); }
  markForumRead(slug: string) { return this.request(`/forums/${slug}/read`, { method: 'PUT' }); }
  markAllForumsRead() { return this.request('/forums/read-all', { method: 'PUT' }); }
  getUnreadCounts() { return this.request('/forums/unread-counts'); }

  // === User Activity ===

  getUserActivity(slug: string, limit = 25, offset = 0) { return this.request(`/profiles/${slug}/activity?limit=${limit}&offset=${offset}`); }

  // === Badges ===

  getUserBadges(userId: string) { return this.request(`/badges/user/${userId}`); }

  // === Similar Threads ===

  getTrendingThreads(period = 'week', limit = 25, offset = 0) {
    return this.request(`/threads/trending?period=${period}&limit=${limit}&offset=${offset}`);
  }

  getSimilarThreads(title: string, forumId?: string) {
    const params = new URLSearchParams({ title });
    if (forumId) params.set('forum_id', forumId);
    return this.request(`/threads/similar?${params.toString()}`);
  }
  // === User Follows ===

  toggleFollow(userId: string) { return this.request(`/users/${userId}/follow`, { method: 'POST' }); }
  getFollowers(userId: string) { return this.request(`/users/${userId}/followers`); }
  getFollowing(userId: string) { return this.request(`/users/${userId}/following`); }
  getFollowingFeed(limit = 25, offset = 0) { return this.request(`/following/feed?limit=${limit}&offset=${offset}`); }

  // === Contact ===

  submitContact(data: { name: string; email: string; subject: string; message: string }) {
    return this.request('/contact', { method: 'POST', body: JSON.stringify(data) });
  }

  // === Data Import ===

  getImportSources() {
    return this.request('/admin/import/sources');
  }

  startImport(formData: FormData) {
    return fetch(`${API_BASE}/admin/import/start`, {
      method: 'POST',
      body: formData,
      credentials: 'include'
    }).then(async (res) => {
      if (!res.ok) throw await res.json().catch(() => ({ error: 'Import start failed' }));
      return res.json();
    });
  }

  previewImport(formData: FormData) {
    return fetch(`${API_BASE}/admin/import/preview`, {
      method: 'POST',
      body: formData,
      credentials: 'include'
    }).then(async (res) => {
      if (!res.ok) throw await res.json().catch(() => ({ error: 'Preview failed' }));
      return res.json();
    });
  }

  getImportStatus(id: string) {
    return this.request(`/admin/import/status/${id}`);
  }

  cancelImport(id: string) {
    return this.request(`/admin/import/cancel/${id}`, { method: 'POST' });
  }


  // === Custom BBCode Tags (Admin) ===
  getCustomBBCodes() { return this.request('/admin/bbcodes'); }
  createCustomBBCode(data: Record<string, any>) { return this.request('/admin/bbcodes', { method: 'POST', body: JSON.stringify({ bbcode: data }) }); }
  updateCustomBBCode(id: string, data: Record<string, any>) { return this.request('/admin/bbcodes/' + id, { method: 'PUT', body: JSON.stringify({ bbcode: data }) }); }
  deleteCustomBBCode(id: string) { return this.request('/admin/bbcodes/' + id, { method: 'DELETE' }); }

  // === Login Events (Admin security timeline) ===
  getLoginEvents(params: { user_id?: string; email?: string; ip?: string; success?: boolean; since?: string; limit?: number } = {}) {
    const qs = new URLSearchParams();
    if (params.user_id) qs.set('user_id', params.user_id);
    if (params.email) qs.set('email', params.email);
    if (params.ip) qs.set('ip', params.ip);
    if (typeof params.success === 'boolean') qs.set('success', String(params.success));
    if (params.since) qs.set('since', params.since);
    if (params.limit) qs.set('limit', String(params.limit));
    const q = qs.toString();
    return this.request('/admin/login-events' + (q ? '?' + q : ''));
  }

  // === Quarantine (Admin) ===
  getQuarantineRecords(activeOnly = false) { return this.request(`/admin/quarantine?active=${activeOnly}`); }
  quarantineUser(userId: string, reason: string) { return this.request('/admin/quarantine', { method: 'POST', body: JSON.stringify({ user_id: userId, reason }) }); }
  releaseQuarantine(userId: string) { return this.request('/admin/quarantine/' + userId, { method: 'DELETE' }); }

  // === AI Flow Generator ===
  generateFlowFromDescription(description: string, save = true) {
    return this.request('/admin/plugins/flows/generate', {
      method: 'POST',
      body: JSON.stringify({ description, save })
    });
  }

  // === Plugin Pages (Admin — pages rendered by a flow template) ===
  getAdminPluginPages() { return this.request('/admin/pages'); }
  createPluginPage(data: Record<string, any>) { return this.request('/admin/pages', { method: 'POST', body: JSON.stringify({ page: data }) }); }
  updatePluginPage(id: string, data: Record<string, any>) { return this.request('/admin/pages/' + id, { method: 'PUT', body: JSON.stringify({ page: data }) }); }
  deletePluginPage(id: string) { return this.request('/admin/pages/' + id, { method: 'DELETE' }); }

  // === Slash Commands (Admin) ===
  getAdminSlashCommands() { return this.request('/admin/commands'); }
  createSlashCommand(data: Record<string, any>) { return this.request('/admin/commands', { method: 'POST', body: JSON.stringify({ command: data }) }); }
  updateSlashCommand(id: string, data: Record<string, any>) { return this.request('/admin/commands/' + id, { method: 'PUT', body: JSON.stringify({ command: data }) }); }
  deleteSlashCommand(id: string) { return this.request('/admin/commands/' + id, { method: 'DELETE' }); }

  // === Promotion Rules (Admin — auto-promote users by criteria) ===
  getPromotionRules() { return this.request('/admin/promotion-rules'); }
  createPromotionRule(data: Record<string, any>) { return this.request('/admin/promotion-rules', { method: 'POST', body: JSON.stringify(data) }); }
  updatePromotionRule(id: string, data: Record<string, any>) { return this.request('/admin/promotion-rules/' + id, { method: 'PUT', body: JSON.stringify(data) }); }
  deletePromotionRule(id: string) { return this.request('/admin/promotion-rules/' + id, { method: 'DELETE' }); }
  evaluatePromotionRules() { return this.request('/admin/promotion-rules/evaluate', { method: 'POST' }); }

  // === Forum Event Webhooks (Admin) ===
  getForumWebhooks() { return this.request('/admin/forum-webhooks'); }
  createForumWebhook(data: Record<string, any>) { return this.request('/admin/forum-webhooks', { method: 'POST', body: JSON.stringify(data) }); }
  updateForumWebhook(id: string, data: Record<string, any>) { return this.request('/admin/forum-webhooks/' + id, { method: 'PUT', body: JSON.stringify(data) }); }
  deleteForumWebhook(id: string) { return this.request('/admin/forum-webhooks/' + id, { method: 'DELETE' }); }
  testForumWebhook(id: string) { return this.request('/admin/forum-webhooks/' + id + '/test', { method: 'POST' }); }
  getForumWebhookEventTypes() { return this.request('/admin/forum-webhooks/event-types'); }
  getForumWebhookDeliveries(id: string, limit = 50) { return this.request(`/admin/forum-webhooks/${id}/deliveries?limit=${limit}`); }

  // === Achievements (Admin) ===
  getAdminAchievements() { return this.request('/admin/achievements'); }
  getAdminAchievement(id: string) { return this.request('/admin/achievements/' + id); }
  createAchievement(data: Record<string, any>) { return this.request('/admin/achievements', { method: 'POST', body: JSON.stringify({ achievement: data }) }); }
  updateAchievement(id: string, data: Record<string, any>) { return this.request('/admin/achievements/' + id, { method: 'PUT', body: JSON.stringify({ achievement: data }) }); }
  deleteAchievement(id: string) { return this.request('/admin/achievements/' + id, { method: 'DELETE' }); }
  grantAchievement(achievementId: string, userId: string) { return this.request(`/admin/achievements/${achievementId}/grant/${userId}`, { method: 'POST' }); }
  revokeAchievement(achievementId: string, userId: string) { return this.request(`/admin/achievements/${achievementId}/grant/${userId}`, { method: 'DELETE' }); }
  bulkAchievement(achievementId: string, action: 'grant' | 'revoke', targets: string[]) {
    return this.request(`/admin/achievements/${achievementId}/bulk`, { method: 'POST', body: JSON.stringify({ action, targets }) });
  }

  // === User Activity Heatmap ===
  getUserActivityHeatmap(slug: string) { return this.request('/profiles/' + slug + '/activity-heatmap'); }

  // === Forge Codes (shareable profile themes) ===
  getForgeVocabulary() { return this.request('/forge-codes/vocabulary'); }
  getForgeGallery(tab: string = 'featured', vibe?: string, limit = 24, offset = 0) {
    const q = new URLSearchParams({ tab, limit: String(limit), offset: String(offset) });
    if (vibe) q.set('vibe', vibe);
    return this.request('/forge-codes/gallery?' + q.toString());
  }
  getMyForgeCodes() { return this.request('/forge-codes-mine'); }
  getForgeCode(code: string) { return this.request('/forge-codes/' + code); }
  createForgeCode(data: Record<string, any>) {
    return this.request('/forge-codes', { method: 'POST', body: JSON.stringify(data) });
  }
  applyForgeCode(code: string) {
    return this.request('/forge-codes/' + code + '/apply', { method: 'POST' });
  }
  updateForgeCode(code: string, data: Record<string, any>) {
    return this.request('/forge-codes/' + code, { method: 'PUT', body: JSON.stringify(data) });
  }
  deleteForgeCode(code: string) {
    return this.request('/forge-codes/' + code, { method: 'DELETE' });
  }

  // === Profile endorsements (emoji reactions) ===
  endorseProfile(slug: string, emoji: string) {
    return this.request('/profiles/' + slug + '/endorse', { method: 'POST', body: JSON.stringify({ emoji }) });
  }
  unendorseProfile(slug: string, emoji: string) {
    return this.request('/profiles/' + slug + '/endorse', { method: 'DELETE', body: JSON.stringify({ emoji }) });
  }

  // === Profile extras ===
  generateProfileAISummary(slug: string) {
    return this.request('/profiles/' + slug + '/ai-summary', { method: 'POST' });
  }
  pinThreadToProfile(threadId: string) {
    return this.request('/profile/pin-thread', { method: 'PUT', body: JSON.stringify({ thread_id: threadId }) });
  }
  unpinThreadFromProfile() {
    return this.request('/profile/pin-thread', { method: 'DELETE' });
  }

  // === Owner profile analytics ===
  getProfileAnalytics() { return this.request('/profile/analytics'); }

  // === Achievements (public) ===
  getUserAchievements(userId: string) { return this.request(`/users/${userId}/achievements`); }

  // === Friends ===
  getFriendshipStatus(userId: string) { return this.request(`/friends/status/${userId}`); }
  sendFriendRequest(userId: string) { return this.request('/friends/request', { method: 'POST', body: JSON.stringify({ user_id: userId }) }); }
  acceptFriend(id: string) { return this.request(`/friends/${id}/accept`, { method: 'PUT' }); }
  declineFriend(id: string) { return this.request(`/friends/${id}/decline`, { method: 'PUT' }); }
  removeFriend(id: string) { return this.request(`/friends/${id}`, { method: 'DELETE' }); }

  // === Admin actions on a user (staff only) ===
  adminGetUser(id: string) { return this.request(`/admin/users/${id}`); }
  adminUpdateUser(id: string, user: Record<string, any>) {
    return this.request(`/admin/users/${id}`, { method: 'PUT', body: JSON.stringify({ user }) });
  }
  adminResetUserPassword(id: string) {
    return this.request(`/admin/users/${id}/reset-password`, { method: 'POST' });
  }
  adminListGroups() { return this.request('/admin/groups'); }
  adminAddUserToGroup(groupId: string, userId: string) {
    return this.request(`/admin/groups/${groupId}/members`, { method: 'POST', body: JSON.stringify({ user_id: userId }) });
  }
  adminRemoveUserFromGroup(groupId: string, userId: string) {
    return this.request(`/admin/groups/${groupId}/members/${userId}`, { method: 'DELETE' });
  }
  adminWarnUser(userId: string, reason: string, points = 1) {
    return this.request('/mod/warnings', {
      method: 'POST',
      body: JSON.stringify({ warning: { user_id: userId, reason, points } })
    });
  }
  adminBanUser(userId: string, data: { type: string; reason: string; expires_at?: string }) {
    return this.request('/mod/bans', {
      method: 'POST',
      body: JSON.stringify({ ban: { user_id: userId, ...data } })
    });
  }
  adminGetUserInfractions(userId: string) {
    return this.request(`/mod/users/${userId}/infractions`);
  }
  adminRevokeWarning(id: string) {
    return this.request(`/mod/warnings/${id}/revoke`, { method: 'PUT' });
  }
  adminRevokeBan(id: string) {
    return this.request(`/mod/bans/${id}/revoke`, { method: 'PUT' });
  }
  adminStartImpersonation(userId: string, reason: string) {
    return this.request('/mod/impersonate/start', { method: 'POST', body: JSON.stringify({ user_id: userId, reason }) });
  }

  // === User-facing infractions ===
  getMyInfractions() { return this.request('/my/infractions'); }

  // === Member search (typeahead) ===
  searchMembers(q: string, limit = 8) {
    const qs = new URLSearchParams({ q, limit: String(limit) });
    return this.request('/members/search?' + qs.toString());
  }
}

export const api = new ApiClient();
