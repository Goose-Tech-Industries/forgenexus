<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import WarRoomCard from '$lib/components/admin/WarRoomCard.svelte';
  import HealthGauge from '$lib/components/admin/HealthGauge.svelte';
  import ComparisonCard from '$lib/components/admin/ComparisonCard.svelte';
  import LiveFeed from '$lib/components/admin/LiveFeed.svelte';
  import ModQueueSnapshot from '$lib/components/admin/ModQueueSnapshot.svelte';
  import NewMemberSpotlight from '$lib/components/admin/NewMemberSpotlight.svelte';
  import GoalTracker from '$lib/components/admin/GoalTracker.svelte';

  let loading = $state(true);
  let feedLoading = $state(true);
  let pollInterval: ReturnType<typeof setInterval> | null = null;
  let feedInterval: ReturnType<typeof setInterval> | null = null;
  let showCustomize = $state(false);

  // Widget visibility — persisted to localStorage
  const defaultWidgets: Record<string, boolean> = {
    war_room: true, comparison: true, health: true,
    mod_queue: true, new_members: true, live_feed: true, goal: true
  };

  let widgetVisibility = $state<Record<string, boolean>>(
    JSON.parse(localStorage.getItem('fn_admin_widgets') || 'null') || { ...defaultWidgets }
  );

  function toggleWidget(key: string) {
    widgetVisibility[key] = !widgetVisibility[key];
    widgetVisibility = { ...widgetVisibility };
    localStorage.setItem('fn_admin_widgets', JSON.stringify(widgetVisibility));
  }

  function resetWidgets() {
    widgetVisibility = { ...defaultWidgets };
    localStorage.setItem('fn_admin_widgets', JSON.stringify(widgetVisibility));
  }

  // Goal settings (read from admin settings)
  let goalLabel = $derived(admin.settings?.dashboard_goal_label || '');
  let goalTarget = $derived(parseInt(admin.settings?.dashboard_goal_target || '0', 10));
  let goalMetric = $derived(admin.settings?.dashboard_goal_current_metric || 'total_users');
  let goalCurrent = $derived.by(() => {
    if (!admin.warRoom) return 0;
    const map: Record<string, number> = {
      total_users: admin.warRoom.total_users,
      total_threads: admin.warRoom.total_threads,
      total_posts: 0, // not in war room yet, but could be
    };
    return map[goalMetric] ?? 0;
  });

  $effect(() => {
    loadDashboard();

    // Real-time war room stats via WebSocket channel (backend pushes every 5s)
    socketStore.joinAdminChannel((stats: any) => {
      admin.setWarRoom(stats);
    });

    // Fallback polling for mod queue (not covered by admin channel) + feed
    pollInterval = setInterval(() => {
      admin.loadModQueue();
    }, 5000);
    feedInterval = setInterval(() => {
      admin.loadLiveFeed();
    }, 15000);
    return () => {
      if (pollInterval) clearInterval(pollInterval);
      if (feedInterval) clearInterval(feedInterval);
      socketStore.leaveAdminChannel();
    };
  });

  async function loadDashboard() {
    loading = true;
    feedLoading = true;
    try {
      // Load everything in parallel
      await Promise.all([
        admin.loadWarRoom(),
        admin.loadHealthScore(),
        admin.loadComparison(),
        admin.loadModQueue(),
        admin.loadNewMembers(),
        admin.loadSettings(),
      ]);
    } finally { loading = false; }
    // Load feed separately (can be slower)
    try {
      await admin.loadLiveFeed();
    } finally { feedLoading = false; }
  }

  function formatUptime(seconds: number): string {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  }
</script>

<div class="dashboard">
  <div class="dash-header">
    <h1>Admin Dashboard</h1>
    <div class="dash-header-right">
      <button class="customize-btn" onclick={() => showCustomize = !showCustomize} title="Customize dashboard">&#9881;</button>
      <div class="ws-status connected">
        <span class="ws-dot"></span>
        Live (5s)
      </div>
    </div>
  </div>

  {#if showCustomize}
    <div class="customize-panel">
      <div class="customize-header">
        <strong>Dashboard Widgets</strong>
        <button class="reset-btn" onclick={resetWidgets}>Reset</button>
      </div>
      <div class="widget-toggles">
        {#each [['war_room','War Room'],['comparison','Today vs Yesterday'],['health','Community Health'],['mod_queue','Mod Queue'],['new_members','New Members'],['live_feed','Live Feed'],['goal','Goal Tracker']] as [key, label]}
          <label class="widget-toggle">
            <input type="checkbox" checked={widgetVisibility[key]} onchange={() => toggleWidget(key)} />
            <span>{label}</span>
          </label>
        {/each}
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading dashboard...</p>
  {:else}
    <!-- War Room -->
    {#if widgetVisibility.war_room}
    <section class="war-room">
      <h2 class="section-title">War Room</h2>
      {#if admin.warRoom}
        <div class="war-grid">
          <WarRoomCard label="Active Users" value={admin.warRoom.active_users} color="#4ade80" pulse={admin.warRoom.active_users > 0} />
          <WarRoomCard label="Posts / Minute" value={admin.warRoom.posts_per_minute} color="#06b6d4" />
          <WarRoomCard label="Posts (1hr)" value={admin.warRoom.posts_last_hour} color="#3b82f6" />
          <WarRoomCard label="Open Reports" value={admin.warRoom.open_reports} color={admin.warRoom.open_reports > 5 ? '#f87171' : '#fbbf24'} pulse={admin.warRoom.open_reports > 0} />
          <WarRoomCard label="Active Bans" value={admin.warRoom.active_bans} color="#f97316" />
          <WarRoomCard label="Staff Online" value={admin.warRoom.online_staff} color="#a855f7" />
          <WarRoomCard label="Total Users" value={admin.warRoom.total_users} color="var(--text-secondary)" />
          <WarRoomCard label="Server Uptime" value={formatUptime(admin.warRoom.server_uptime_seconds)} color="var(--text-secondary)" />
        </div>
      {/if}
    </section>

    {/if}

    <!-- Today vs Yesterday + Health -->
    {#if widgetVisibility.comparison || widgetVisibility.health}
    <section class="comparison-health-row">
      <div class="comparison-section">
        <h2 class="section-title">Today vs Yesterday</h2>
        {#if admin.comparison}
          <div class="comparison-grid">
            <ComparisonCard label="Posts" today={admin.comparison.posts.today} yesterday={admin.comparison.posts.yesterday} changePct={admin.comparison.posts.change_pct} color="#3b82f6" />
            <ComparisonCard label="Threads" today={admin.comparison.threads.today} yesterday={admin.comparison.threads.yesterday} changePct={admin.comparison.threads.change_pct} color="#06b6d4" />
            <ComparisonCard label="Registrations" today={admin.comparison.registrations.today} yesterday={admin.comparison.registrations.yesterday} changePct={admin.comparison.registrations.change_pct} color="#4ade80" />
            <ComparisonCard label="Reports" today={admin.comparison.reports.today} yesterday={admin.comparison.reports.yesterday} changePct={admin.comparison.reports.change_pct} color="#f87171" />
            <ComparisonCard label="Active Users" today={admin.comparison.active_users.today} yesterday={admin.comparison.active_users.yesterday} changePct={admin.comparison.active_users.change_pct} color="#a855f7" />
          </div>
        {:else}
          <div class="placeholder-text">No comparison data available yet</div>
        {/if}
      </div>

      <div class="health-section">
        <h2 class="section-title">Community Health</h2>
        {#if admin.healthScore}
          <div class="health-layout">
            <HealthGauge score={admin.healthScore.score} trend={admin.healthScore.trend} />
            <div class="health-metrics">
              <div class="metric">
                <span class="metric-label">Retention</span>
                <span class="metric-value">{Math.round(admin.healthScore.metrics.new_user_retention * 100)}%</span>
              </div>
              <div class="metric">
                <span class="metric-label">Reply Ratio</span>
                <span class="metric-value">{Math.round(admin.healthScore.metrics.post_reply_ratio * 100)}%</span>
              </div>
              <div class="metric">
                <span class="metric-label">Report Rate</span>
                <span class="metric-value">{Math.round(admin.healthScore.metrics.report_density * 100)}%</span>
              </div>
              <div class="metric">
                <span class="metric-label">Active Ratio</span>
                <span class="metric-value">{Math.round(admin.healthScore.metrics.active_to_lurker * 100)}%</span>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </section>
    {/if}

    <!-- Goal Tracker -->
    <GoalTracker label={goalLabel} target={goalTarget} current={goalCurrent} />

    <!-- Middle row: Mod Queue + New Members -->
    <section class="mid-row">
      <ModQueueSnapshot queue={admin.modQueue} />
      <NewMemberSpotlight members={admin.newMembers} />
    </section>

    <!-- Live Feed -->
    <LiveFeed events={admin.liveFeed} loading={feedLoading} />

    <!-- Quick Links -->
    <section class="quick-links">
      <h2 class="section-title">Quick Links</h2>
      <div class="ql-grid">
        <a href="/admin/content-decay" class="quick-link"><span class="ql-icon">&#128201;</span><span>Content Decay</span></a>
        <a href="/admin/analytics" class="quick-link"><span class="ql-icon">&#128202;</span><span>Analytics</span></a>
        <a href="/admin/audit-trail" class="quick-link"><span class="ql-icon">&#128203;</span><span>Audit Trail</span></a>
        <a href="/admin/forums" class="quick-link"><span class="ql-icon">&#128260;</span><span>Forum Order</span></a>
        <a href="/admin/plugins" class="quick-link"><span class="ql-icon">&#128268;</span><span>Plugins</span></a>
        <a href="/admin/subscriptions" class="quick-link"><span class="ql-icon">&#11088;</span><span>Subscriptions</span></a>
        <a href="/admin/settings" class="quick-link"><span class="ql-icon">&#9881;</span><span>Settings</span></a>
        <a href="/mod" class="quick-link"><span class="ql-icon">&#128737;</span><span>Mod Panel</span></a>
        <a href="/admin/maintenance" class="quick-link"><span class="ql-icon">&#128295;</span><span>Maintenance</span></a>
      </div>
    </section>
  {/if}
</div>

<style>
  .dashboard { display: flex; flex-direction: column; gap: 20px; }
  .dashboard h1 { font-size: 22px; font-weight: 800; color: var(--text-primary); }
  .dash-header { display: flex; justify-content: space-between; align-items: center; }
  .dash-header-right { display: flex; align-items: center; gap: 10px; }
  .customize-btn { background: none; border: 1px solid var(--border-color); border-radius: var(--radius); padding: 4px 8px; cursor: pointer; font-size: 14px; color: var(--text-muted); }
  .customize-btn:hover { color: var(--text-primary); border-color: var(--accent); }
  .customize-panel { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; }
  .customize-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; font-size: 13px; }
  .reset-btn { background: none; border: none; color: var(--accent); cursor: pointer; font-size: 11px; font-family: inherit; }
  .widget-toggles { display: flex; flex-wrap: wrap; gap: 8px; }
  .widget-toggle { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; padding: 4px 8px; background: var(--bg-primary); border-radius: var(--radius); }
  .widget-toggle input { cursor: pointer; }
  .ws-status { display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 600; color: var(--text-muted); }
  .ws-status.connected { color: #4ade80; }
  .ws-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--text-muted); }
  .ws-status.connected .ws-dot { background: #4ade80; box-shadow: 0 0 6px #4ade80; }

  .section-title { font-size: 13px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.04em; margin: 0 0 12px; }

  /* War Room */
  .war-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }

  /* Comparison + Health side by side */
  .comparison-health-row { display: grid; grid-template-columns: 1fr 300px; gap: 16px; }
  .comparison-section, .health-section {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }
  .comparison-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; }
  .health-layout { display: flex; flex-direction: column; align-items: center; gap: 16px; }
  .health-metrics { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 100%; }
  .metric { display: flex; flex-direction: column; gap: 2px; text-align: center; }
  .metric-label { font-size: 10px; color: var(--text-muted); text-transform: uppercase; }
  .metric-value { font-size: 16px; font-weight: 700; color: var(--text-primary); }

  .placeholder-text { font-size: 12px; color: var(--text-muted); text-align: center; padding: 20px; }

  /* Middle row */
  .mid-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }

  /* Quick links */
  .ql-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .quick-link {
    display: flex; align-items: center; gap: 8px; padding: 12px 16px;
    background: var(--bg-card, var(--bg-secondary)); border: 1px solid var(--border-color); border-radius: var(--radius-lg);
    font-size: 13px; font-weight: 600; color: var(--text-secondary); text-decoration: none;
    transition: all 0.15s;
  }
  .quick-link:hover { border-color: var(--border-accent, var(--text-muted)); color: var(--text-primary); background: var(--bg-hover, rgba(255,255,255,0.02)); }
  .ql-icon { font-size: 18px; }

  .loading { color: var(--text-muted); text-align: center; padding: 32px 0; }

  @media (max-width: 1100px) {
    .comparison-health-row { grid-template-columns: 1fr; }
    .comparison-grid { grid-template-columns: repeat(3, 1fr); }
  }
  @media (max-width: 900px) {
    .war-grid { grid-template-columns: repeat(2, 1fr); }
    .mid-row { grid-template-columns: 1fr; }
    .ql-grid { grid-template-columns: repeat(2, 1fr); }
    .comparison-grid { grid-template-columns: repeat(2, 1fr); }
  }
</style>
