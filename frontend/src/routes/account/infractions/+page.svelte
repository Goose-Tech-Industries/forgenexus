<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  let loaded = $state(false);
  let loading = $state(true);
  let data = $state<any>({ bans: [], warnings: [], active_points: 0, appeals: [] });

  // Appeal form
  let appealType = $state<'ban' | 'warning' | null>(null);
  let appealTargetId = $state<string>('');
  let appealReason = $state('');
  let appealSubmitting = $state(false);

  $effect(() => {
    if (!loaded && auth.isLoggedIn) {
      loadData();
      loaded = true;
    }
  });

  async function loadData() {
    loading = true;
    try {
      data = await api.getMyInfractions();
    } catch (e: any) {
      toast.error(e?.error || 'Failed to load infractions');
    }
    loading = false;
  }

  function startAppeal(type: 'ban' | 'warning', id: string) {
    appealType = type;
    appealTargetId = id;
    appealReason = '';
  }

  function cancelAppeal() {
    appealType = null;
    appealTargetId = '';
    appealReason = '';
  }

  async function submitAppeal() {
    if (!appealReason.trim() || appealReason.trim().length < 10) {
      toast.error('Please provide at least 10 characters of reasoning.');
      return;
    }
    if (!appealType) return;

    appealSubmitting = true;
    try {
      await api.createAppeal({
        type: appealType,
        target_id: appealTargetId,
        reason: appealReason.trim()
      });
      toast.success('Appeal submitted — a senior moderator will review within 72 hours.');
      cancelAppeal();
      await loadData();
    } catch (e: any) {
      toast.error(e?.error || 'Failed to submit appeal');
    }
    appealSubmitting = false;
  }

  function existingAppealFor(type: string, targetId: string) {
    return (data.appeals || []).find((a: any) => a.type === type && a.target_id === targetId);
  }

  function fmtDate(iso: string | null) {
    if (!iso) return 'never';
    return new Date(iso).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }
</script>

{#if !auth.isLoggedIn}
  <div class="auth-prompt">
    <p>You need to <a href="/auth/login">log in</a> to view your infractions.</p>
  </div>
{:else}
  <div class="infractions-page">
    <header class="page-head">
      <h1>Account Infractions & Appeals</h1>
      <p class="subtitle">Every warning or ban issued to your account appears here, along with a one-click appeal path.</p>
    </header>

    {#if loading}
      <div class="loading">Loading…</div>
    {:else}
      <!-- Bans -->
      <section class="section">
        <h2>Bans</h2>
        {#if data.bans.length === 0}
          <div class="empty">No bans on your account. ✨</div>
        {:else}
          {#each data.bans as ban (ban.id)}
            {@const existing = existingAppealFor('ban', ban.id)}
            <article class="card ban-card" class:inactive={!ban.is_active}>
              <div class="card-head">
                <span class="chip chip-{ban.type}">{ban.type}</span>
                <span class="date">issued {fmtDate(ban.inserted_at)}</span>
                {#if ban.expires_at}<span class="date">· expires {fmtDate(ban.expires_at)}</span>{/if}
                {#if !ban.is_active}<span class="chip chip-lifted">LIFTED</span>{/if}
              </div>
              <div class="reason"><strong>Reason:</strong> {ban.reason}</div>

              {#if ban.is_active}
                {#if existing}
                  <div class="appeal-status appeal-{existing.status}">
                    Appeal {existing.status.replace('_', ' ')} — submitted {fmtDate(existing.inserted_at)}
                    {#if existing.decision_note}<br /><em>Moderator note: {existing.decision_note}</em>{/if}
                  </div>
                {:else}
                  <button class="btn-primary" onclick={() => startAppeal('ban', ban.id)}>Appeal this ban</button>
                {/if}
              {/if}
            </article>
          {/each}
        {/if}
      </section>

      <!-- Warnings -->
      <section class="section">
        <h2>Warnings <span class="points-badge">{data.active_points} active points</span></h2>
        {#if data.warnings.length === 0}
          <div class="empty">No warnings on your account. ✨</div>
        {:else}
          {#each data.warnings as w (w.id)}
            {@const existing = existingAppealFor('warning', w.id)}
            <article class="card warning-card" class:inactive={!w.is_active}>
              <div class="card-head">
                <span class="chip chip-warning">+{w.points} pts</span>
                <span class="date">issued {fmtDate(w.inserted_at)}</span>
                {#if !w.is_active}<span class="chip chip-lifted">REVOKED</span>{/if}
              </div>
              <div class="reason"><strong>Reason:</strong> {w.reason}</div>

              {#if w.is_active}
                {#if existing}
                  <div class="appeal-status appeal-{existing.status}">
                    Appeal {existing.status.replace('_', ' ')} — submitted {fmtDate(existing.inserted_at)}
                    {#if existing.decision_note}<br /><em>Moderator note: {existing.decision_note}</em>{/if}
                  </div>
                {:else}
                  <button class="btn-primary" onclick={() => startAppeal('warning', w.id)}>Appeal this warning</button>
                {/if}
              {/if}
            </article>
          {/each}
        {/if}
      </section>

      <p class="footer-note">
        See all your submitted appeals at <a href="/account/appeals">/account/appeals</a>.
      </p>
    {/if}
  </div>

  <!-- Appeal form modal -->
  {#if appealType}
    <div class="modal-backdrop" onclick={cancelAppeal} role="presentation">
      <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog">
        <h2>Appeal this {appealType}</h2>
        <p class="modal-help">Explain why you believe this decision should be reconsidered. A senior moderator (not the one who issued it) will review. Be honest and specific — appeals based on blaming others or denying facts the mod team can verify are typically denied.</p>
        <textarea bind:value={appealReason} rows="6" placeholder="Your appeal (min 10 characters)"></textarea>
        <div class="modal-actions">
          <button class="btn-ghost" onclick={cancelAppeal}>Cancel</button>
          <button class="btn-primary" onclick={submitAppeal} disabled={appealSubmitting || appealReason.trim().length < 10}>
            {appealSubmitting ? 'Submitting…' : 'Submit Appeal'}
          </button>
        </div>
      </div>
    </div>
  {/if}
{/if}

<style>
  .infractions-page { max-width: 760px; margin: 0 auto; padding: 24px 16px; display: flex; flex-direction: column; gap: 24px; }
  .page-head h1 { margin: 0 0 6px; font-size: 1.6rem; }
  .subtitle { color: var(--text-secondary, #8a94a6); margin: 0; }

  .section h2 {
    font-size: 1.1rem;
    margin: 0 0 10px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .points-badge {
    font-size: 0.75rem;
    padding: 2px 8px;
    background: var(--bg-tertiary, #1a2030);
    border-radius: 999px;
    color: var(--text-tertiary, #6a748a);
    font-weight: 400;
  }

  .card {
    padding: 14px 16px;
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 10px;
    margin-bottom: 10px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .card.inactive { opacity: 0.6; }
  .ban-card { border-left: 3px solid #ff4444; }
  .warning-card { border-left: 3px solid #ffb347; }

  .card-head { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 0.8rem; color: var(--text-tertiary, #6a748a); }
  .chip { padding: 2px 8px; border-radius: 3px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; }
  .chip-temporary { background: #ff8844; color: #000; }
  .chip-permanent { background: #ff4444; color: #fff; }
  .chip-warning { background: #ffcc33; color: #000; }
  .chip-lifted { background: var(--bg-tertiary, #1a2030); color: #6a748a; }

  .reason { color: var(--text-primary, #e8eaed); }

  .appeal-status {
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 0.88rem;
    background: rgba(59, 130, 246, 0.12);
    color: #60a5fa;
  }
  .appeal-pending, .appeal-under_review { background: rgba(250, 204, 21, 0.12); color: #facc15; }
  .appeal-approved { background: rgba(34, 197, 94, 0.12); color: #4ade80; }
  .appeal-denied { background: rgba(220, 38, 38, 0.12); color: #f87171; }

  .btn-primary { background: var(--accent, #00d4aa); color: #000; padding: 6px 14px; border: none; border-radius: 6px; font-weight: 600; cursor: pointer; font-size: 0.88rem; align-self: flex-start; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-ghost { background: transparent; border: 1px solid var(--border, #2a3040); color: var(--text-primary, #e8eaed); padding: 6px 14px; border-radius: 6px; cursor: pointer; }

  .empty { padding: 16px; color: var(--text-tertiary, #6a748a); text-align: center; font-style: italic; }
  .loading { padding: 40px; text-align: center; color: var(--text-secondary, #8a94a6); }
  .auth-prompt { text-align: center; padding: 60px 20px; color: var(--text-secondary, #8a94a6); }
  .auth-prompt a { color: var(--accent, #00d4aa); }

  .footer-note { text-align: center; font-size: 0.85rem; color: var(--text-tertiary, #6a748a); }
  .footer-note a { color: var(--accent, #00d4aa); }

  .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.75); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 20px; }
  .modal { width: min(92vw, 560px); background: var(--bg-secondary, #121826); border: 1px solid var(--border, #2a3040); border-radius: 12px; padding: 24px; display: flex; flex-direction: column; gap: 12px; }
  .modal h2 { margin: 0; }
  .modal-help { margin: 0; color: var(--text-secondary, #8a94a6); font-size: 0.9rem; line-height: 1.5; }
  .modal textarea {
    padding: 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 6px;
    color: var(--text-primary, #e8eaed);
    font-family: inherit;
    resize: vertical;
  }
  .modal-actions { display: flex; justify-content: flex-end; gap: 8px; }
</style>
