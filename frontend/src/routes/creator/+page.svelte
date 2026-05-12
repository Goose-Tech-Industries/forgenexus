<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import AffiliateGate from '$lib/components/creator/AffiliateGate.svelte';

  let dashboard = $state<any>(null);
  let loading = $state(true);

  $effect(() => {
    if (auth.isLoggedIn) loadDashboard();
  });

  async function loadDashboard() {
    try {
      const data = await api.request('/creator/dashboard');
      dashboard = data.dashboard;
    } catch (e) {
      console.error('Failed to load dashboard:', e);
    }
    loading = false;
  }

  function formatCents(cents: number): string {
    return `$${(cents / 100).toFixed(2)}`;
  }
</script>

<svelte:head>
  <title>Creator Dashboard — ForgeNexus</title>
</svelte:head>

<div class="creator-page">
  <h1 class="text-glow">Creator Dashboard</h1>

  {#if import.meta.env.VITE_PAYMENTS_LIVE !== 'true'}
    <div class="payments-pending-banner">
      <strong>Creator payments are not yet live.</strong>
      The earnings shown below are placeholders. Real money will only flow once
      Stripe Connect is wired and we've completed test-mode validation.
    </div>
  {/if}

  <AffiliateGate />

  {#if loading}
    <div class="skeleton-grid">
      {#each Array(4) as _}
        <div class="skeleton stat-skeleton"></div>
      {/each}
    </div>
  {:else if dashboard}
    <!-- Earnings overview -->
    <div class="stat-grid">
      <div class="stat-card glass glow-accent">
        <div class="stat-label">Period Earnings</div>
        <div class="stat-value">{formatCents(dashboard.earnings?.tips?.total_cents || 0)}</div>
        <div class="stat-sub">{dashboard.earnings?.tips?.count || 0} tips</div>
      </div>
      <div class="stat-card glass">
        <div class="stat-label">All-Time Earnings</div>
        <div class="stat-value">{formatCents(dashboard.earnings?.all_time_cents || 0)}</div>
      </div>
      <div class="stat-card glass">
        <div class="stat-label">Redemptions</div>
        <div class="stat-value">{dashboard.activity?.redemptions || 0}</div>
        <div class="stat-sub">This period</div>
      </div>
      <div class="stat-card glass">
        <div class="stat-label">Sessions</div>
        <div class="stat-value">{dashboard.activity?.room_sessions?.count || 0}</div>
        <div class="stat-sub">Peak: {dashboard.activity?.room_sessions?.peak_viewers || 0} viewers</div>
      </div>
    </div>

    <!-- Top supporters -->
    {#if dashboard.top_supporters?.length > 0}
      <div class="section">
        <h2>Top Supporters</h2>
        <div class="supporters-list">
          {#each dashboard.top_supporters as supporter, i}
            <div class="supporter-row card">
              <span class="supporter-rank">#{i + 1}</span>
              <span class="supporter-name">{supporter.user_id}</span>
              <span class="supporter-amount">{formatCents(supporter.total_cents)}</span>
              <span class="supporter-count">{supporter.tip_count} tips</span>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Recent tips -->
    {#if dashboard.recent_tips?.length > 0}
      <div class="section">
        <h2>Recent Tips</h2>
        {#each dashboard.recent_tips as tip}
          <div class="tip-row card">
            <span class="tip-amount">{formatCents(tip.amount_cents)}</span>
            <span class="tip-from">{tip.is_anonymous ? 'Anonymous' : tip.sender_id}</span>
            {#if tip.message}
              <span class="tip-message">"{tip.message}"</span>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  {:else}
    <div class="empty glass">
      <p>Start streaming and accepting tips to see your dashboard!</p>
    </div>
  {/if}
</div>

<style>
  .creator-page { max-width: 900px; margin: 0 auto; padding: 24px 16px; }
  .creator-page h1 { font-size: 28px; font-weight: 800; margin-bottom: 24px; }

  .payments-pending-banner {
    background: rgba(245, 158, 11, 0.10);
    border: 1px solid rgba(245, 158, 11, 0.35);
    color: #fbbf24;
    padding: 10px 14px;
    border-radius: var(--radius-md);
    font-size: 13px;
    margin-bottom: 16px;
    line-height: 1.5;
  }
  .payments-pending-banner strong { display: block; margin-bottom: 2px; color: #f59e0b; }

  .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .skeleton-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
  .stat-skeleton { height: 100px; border-radius: var(--radius-lg); }

  .stat-card { padding: 18px; text-align: center; }
  .stat-label { font-size: 12px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
  .stat-value { font-size: 28px; font-weight: 800; color: var(--text-heading); }
  .stat-sub { font-size: 12px; color: var(--text-muted); margin-top: 4px; }

  .section { margin-bottom: 24px; }
  .section h2 { font-size: 18px; font-weight: 700; margin-bottom: 12px; color: var(--text-heading); }

  .supporters-list { display: flex; flex-direction: column; gap: 6px; }
  .supporter-row { display: flex; align-items: center; gap: 12px; padding: 10px 14px; font-size: 14px; }
  .supporter-rank { font-weight: 700; color: var(--accent); width: 30px; }
  .supporter-name { flex: 1; }
  .supporter-amount { font-weight: 700; color: var(--accent); }
  .supporter-count { font-size: 12px; color: var(--text-muted); }

  .tip-row { display: flex; align-items: center; gap: 10px; padding: 10px 14px; font-size: 14px; margin-bottom: 6px; }
  .tip-amount { font-weight: 700; color: var(--accent); }
  .tip-from { color: var(--text-secondary); }
  .tip-message { font-style: italic; color: var(--text-muted); font-size: 13px; }

  .empty { padding: 40px; text-align: center; color: var(--text-muted); }
</style>
