<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let tournaments = $state<any[]>([]);
  let loading = $state(true);

  $effect(() => { loadTournaments(); });

  let registering = $state<string | null>(null);

  async function loadTournaments() {
    try {
      const data = await api.request('/events?type=tournament');
      tournaments = data.events || [];
    } catch (e) { console.error(e); }
    loading = false;
  }

  async function register(tournament: any) {
    if (registering) return;
    registering = tournament.id;
    try {
      await api.request(`/events/${tournament.id}/rsvp`, { method: 'POST', body: JSON.stringify({ status: 'registered' }) });
      // Update local state
      tournaments = tournaments.map(t => t.id === tournament.id ? { ...t, registered: true } : t);
    } catch { /* silent */ }
    registering = null;
  }
</script>

<svelte:head><title>Tournaments — ForgeNexus</title></svelte:head>

<div class="tournaments-page">
  <h1 class="text-glow">Tournaments</h1>
  <p class="subtitle">Compete, watch, and win.</p>

  <div class="tournament-list stagger">
    {#if loading}
      {#each Array(3) as _}<div class="skeleton tourney-skeleton"></div>{/each}
    {:else if tournaments.length === 0}
      <div class="empty glass">
        <h3>No tournaments yet</h3>
        <p>Check back soon or create one from the admin panel.</p>
      </div>
    {:else}
      {#each tournaments as t (t.id)}
        <div class="tourney-card card-elevated card-glow">
          <div class="tourney-header">
            <h2>{t.name || t.title}</h2>
            <span class="badge" class:badge-accent={t.status === 'upcoming'} class:badge-live={t.status === 'live'}>
              {t.status}
            </span>
          </div>
          <div class="tourney-meta">
            {#if t.bracket_type}
              <span>🏆 {t.bracket_type.replace('_', ' ')}</span>
            {/if}
            {#if t.prize_pool_points}
              <span>💰 {t.prize_pool_points} points</span>
            {/if}
            {#if t.entry_fee_points}
              <span>🎫 {t.entry_fee_points} entry fee</span>
            {/if}
          </div>
          {#if auth.isLoggedIn && t.status === 'upcoming'}
            {#if t.registered}
              <button class="btn btn-secondary" disabled>Registered</button>
            {:else}
              <button class="btn btn-primary" disabled={registering === t.id} onclick={() => register(t)}>
                {registering === t.id ? 'Registering...' : 'Register'}
              </button>
            {/if}
          {/if}
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .tournaments-page { max-width: 800px; margin: 0 auto; padding: 24px 16px; }
  h1 { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { color: var(--text-secondary); margin-bottom: 24px; }
  .tournament-list { display: flex; flex-direction: column; gap: 12px; }
  .tourney-skeleton { height: 120px; border-radius: var(--radius-lg); }
  .tourney-card { padding: 18px; }
  .tourney-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .tourney-header h2 { font-size: 18px; font-weight: 700; }
  .tourney-meta { display: flex; gap: 14px; font-size: 13px; color: var(--text-secondary); margin-bottom: 12px; }
  .empty { padding: 40px; text-align: center; }
  .empty h3 { margin-bottom: 6px; }
  .empty p { color: var(--text-muted); }
</style>
