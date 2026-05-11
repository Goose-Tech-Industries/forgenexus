<svelte:head><title>Checkout cancelled — ForgeNexus</title></svelte:head>

<div class="cancel-page">
  <div class="card">
    <h1>Checkout cancelled</h1>
    <p>No charge was made. Come back anytime.</p>
    <a class="btn" href="/billing">Back to plans</a>
  </div>
</div>

<style>
  .cancel-page { max-width: 480px; margin: 80px auto; padding: 0 16px; text-align: center; }
  .card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 28px 20px; }
  h1 { font-size: 22px; font-weight: 800; margin: 0 0 8px; }
  p { color: var(--text-secondary); margin: 0 0 16px; }
  .btn { display: inline-block; padding: 8px 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color); background: var(--bg-input); color: var(--text-primary); font-weight: 600; text-decoration: none; }
</style>
