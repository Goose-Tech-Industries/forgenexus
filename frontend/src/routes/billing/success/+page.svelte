<script lang="ts">
  import { page } from '$app/state';
  let sessionId = $derived(page.url.searchParams.get('session_id'));
</script>

<svelte:head><title>Subscription active — ForgeNexus</title></svelte:head>

<div class="success-page">
  <div class="card">
    <div class="check">✓</div>
    <h1>You're subscribed.</h1>
    <p>Thanks for backing this. Your community is now on the new plan.</p>
    {#if sessionId}<p class="muted">Stripe session: <code>{sessionId.slice(0, 24)}…</code></p>{/if}
    <div class="actions">
      <a class="btn" href="/billing">Back to billing</a>
      <a class="btn btn-primary" href="/">Home</a>
    </div>
  </div>
</div>

<style>
  .success-page { max-width: 520px; margin: 60px auto; padding: 0 16px; text-align: center; }
  .card { background: var(--bg-card); border: 1px solid var(--accent); border-radius: var(--radius-lg); padding: 36px 24px; }
  .check { font-size: 56px; color: var(--accent); margin-bottom: 12px; }
  h1 { font-size: 24px; font-weight: 800; margin: 0 0 8px; }
  .muted { color: var(--text-muted); font-size: 12px; margin-top: 14px; }
  .actions { display: flex; gap: 8px; justify-content: center; margin-top: 18px; }
  .btn { padding: 8px 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color); background: var(--bg-input); color: var(--text-primary); font-weight: 600; text-decoration: none; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
</style>
