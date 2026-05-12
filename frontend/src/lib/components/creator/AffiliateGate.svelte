<script lang="ts">
  import { api } from '$lib/api/client';
  import { onMount } from 'svelte';

  type Metric = {
    current: number;
    target: number;
    percent: number;
    met: boolean;
  };

  type Progress = {
    followers: Metric;
    days_active: Metric;
    stream_minutes: Metric;
    all_met: boolean;
    subscriptions_enabled: boolean;
    subscriptions_enabled_at: string | null;
  };

  let progress = $state<Progress | null>(null);
  let loading = $state(true);
  let enabling = $state(false);
  let serverError = $state<string | null>(null);

  onMount(() => load());

  async function load() {
    try {
      const data = await api.request('/creator/affiliate-progress');
      progress = data.progress;
    } catch (err) {
      console.error('Failed to load affiliate progress:', err);
    }
    loading = false;
  }

  async function enable() {
    if (!progress?.all_met || enabling) return;
    serverError = null;
    enabling = true;

    try {
      const data = await api.request('/creator/enable-subscriptions', {
        method: 'POST'
      });
      progress = data.progress;
    } catch (err: any) {
      serverError = err?.message || 'Could not enable subscriptions. Try again.';
    }
    enabling = false;
  }
</script>

<section class="ag-card">
  <header class="ag-head">
    <h2>Affiliate gate</h2>
    {#if progress?.subscriptions_enabled}
      <span class="ag-badge ag-badge-enabled">✓ subscriptions enabled</span>
    {:else if progress?.all_met}
      <span class="ag-badge ag-badge-ready">✶ ready to enable</span>
    {:else}
      <span class="ag-badge ag-badge-pending">⏳ in progress</span>
    {/if}
  </header>

  <p class="ag-sub">
    Three thresholds, one gate. Cross all three and you can turn on paid
    subscriptions for your channel.
  </p>

  {#if loading}
    <div class="ag-loading">Loading progress…</div>
  {:else if progress}
    <div class="ag-bars">
      <div class="ag-bar">
        <div class="ag-bar-label">
          <span>Followers</span>
          <strong class:ag-met={progress.followers.met}>
            {progress.followers.current.toLocaleString()} / {progress.followers.target}
          </strong>
        </div>
        <div class="ag-bar-track">
          <div
            class="ag-bar-fill"
            class:ag-bar-met={progress.followers.met}
            style="width: {progress.followers.percent}%"
          ></div>
        </div>
      </div>

      <div class="ag-bar">
        <div class="ag-bar-label">
          <span>Days active</span>
          <strong class:ag-met={progress.days_active.met}>
            {progress.days_active.current} / {progress.days_active.target}
          </strong>
        </div>
        <div class="ag-bar-track">
          <div
            class="ag-bar-fill"
            class:ag-bar-met={progress.days_active.met}
            style="width: {progress.days_active.percent}%"
          ></div>
        </div>
      </div>

      <div class="ag-bar">
        <div class="ag-bar-label">
          <span>Minutes streamed</span>
          <strong class:ag-met={progress.stream_minutes.met}>
            {progress.stream_minutes.current.toLocaleString()} / {progress.stream_minutes.target.toLocaleString()}
          </strong>
        </div>
        <div class="ag-bar-track">
          <div
            class="ag-bar-fill"
            class:ag-bar-met={progress.stream_minutes.met}
            style="width: {progress.stream_minutes.percent}%"
          ></div>
        </div>
      </div>
    </div>

    {#if serverError}
      <p class="ag-err">{serverError}</p>
    {/if}

    {#if progress.subscriptions_enabled}
      <p class="ag-enabled-note">
        Subscriptions enabled
        {#if progress.subscriptions_enabled_at}
          on {new Date(progress.subscriptions_enabled_at).toLocaleDateString()}
        {/if}
        .
      </p>
    {:else if progress.all_met}
      <button class="ag-cta" disabled={enabling} onclick={enable}>
        {enabling ? 'ENABLING…' : '▸ ENABLE SUBSCRIPTIONS'}
      </button>
    {:else}
      <button class="ag-cta" disabled>▸ ENABLE SUBSCRIPTIONS (locked)</button>
      <p class="ag-pending-note">Cross all three thresholds to unlock.</p>
    {/if}
  {/if}
</section>

<style>
  .ag-card {
    border: 1px solid rgba(212, 175, 106, 0.18);
    background: linear-gradient(180deg, rgba(212, 175, 106, 0.03), rgba(15, 23, 38, 0.4));
    border-radius: var(--radius-md, 10px);
    padding: 22px 24px;
    margin-bottom: 18px;
  }

  .ag-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }

  .ag-head h2 {
    font-size: 16px;
    font-weight: 700;
    letter-spacing: 0.06em;
    color: var(--text-heading);
    margin: 0;
  }

  .ag-badge {
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 12px;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  .ag-badge-enabled { background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3); }
  .ag-badge-ready { background: rgba(212, 175, 106, 0.15); color: #d4af6a; border: 1px solid rgba(212, 175, 106, 0.4); }
  .ag-badge-pending { background: rgba(255, 255, 255, 0.05); color: var(--text-muted); border: 1px solid rgba(255, 255, 255, 0.1); }

  .ag-sub {
    font-size: 13px;
    color: var(--text-muted);
    margin: 0 0 18px;
  }

  .ag-loading {
    text-align: center;
    color: var(--text-muted);
    padding: 24px 0;
    font-size: 13px;
  }

  .ag-bars { display: flex; flex-direction: column; gap: 16px; margin-bottom: 18px; }

  .ag-bar-label {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
    color: var(--text-secondary);
    margin-bottom: 6px;
  }
  .ag-bar-label strong { color: var(--text-primary); font-weight: 600; }
  .ag-bar-label strong.ag-met { color: #4ade80; }

  .ag-bar-track {
    height: 8px;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    overflow: hidden;
  }
  .ag-bar-fill {
    height: 100%;
    background: linear-gradient(90deg, rgba(212, 175, 106, 0.5), #d4af6a);
    transition: width 0.4s ease;
  }
  .ag-bar-fill.ag-bar-met {
    background: linear-gradient(90deg, rgba(34, 197, 94, 0.6), #22c55e);
  }

  .ag-cta {
    width: 100%;
    padding: 12px 18px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    cursor: pointer;
    border: 1px solid #d4af6a;
    background: rgba(212, 175, 106, 0.12);
    color: #d4af6a;
    transition: all 0.2s;
  }
  .ag-cta:hover:not(:disabled) {
    background: rgba(212, 175, 106, 0.22);
    box-shadow: 0 0 20px rgba(212, 175, 106, 0.2);
  }
  .ag-cta:disabled {
    border-color: rgba(255, 255, 255, 0.1);
    color: var(--text-muted);
    background: rgba(255, 255, 255, 0.02);
    cursor: not-allowed;
  }

  .ag-pending-note,
  .ag-enabled-note {
    text-align: center;
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 8px;
  }

  .ag-enabled-note { color: #4ade80; }

  .ag-err {
    background: rgba(239, 68, 68, 0.08);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #f87171;
    padding: 10px 12px;
    border-radius: 4px;
    font-size: 13px;
    margin-bottom: 12px;
  }
</style>
