<script lang="ts">
  import '../../app.css';
  import { auth } from '$lib/stores/auth.svelte';
  import { onMount } from 'svelte';

  let { children } = $props();

  onMount(() => {
    auth.init();
  });
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link
    href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;500;600;700;800;900&family=EB+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap"
    rel="stylesheet"
  />
</svelte:head>

<div class="gl-marketing">
  <header class="gl-mast">
    <a href="/" class="gl-brand">
      <span class="gl-fleur">⚜</span>
      <span class="gl-brand-name">ForgeNexus</span>
    </a>
    <nav class="gl-mast-nav">
      <a href="/pricing">Pricing</a>
      <a href="/live">Calamity TV</a>
      {#if auth.isLoggedIn}
        <a href="/home" class="gl-cta-thin">▸ ENTER</a>
      {:else}
        <a href="/auth/login">Sign in</a>
        <a href="/signup?tier=forum" class="gl-cta-thin">▸ START FREE</a>
      {/if}
    </nav>
  </header>

  {@render children()}

  <footer class="gl-foot">
    <div class="gl-foot-inner">
      <span class="gl-foot-mark"><span class="gl-fleur">⚜</span> ForgeNexus</span>
      <nav>
        <a href="/pricing">Pricing</a>
        <a href="/terms">Terms</a>
        <a href="/privacy">Privacy</a>
        <a href="/contact">Contact</a>
      </nav>
    </div>
  </footer>
</div>

<style>
  :global(body) {
    background: var(--bg-primary);
  }

  .gl-marketing {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    font-family: 'EB Garamond', Georgia, serif;
    color: var(--text-primary);
    background:
      radial-gradient(ellipse at top, rgba(139, 92, 246, 0.08), transparent 60%),
      radial-gradient(ellipse at bottom, rgba(0, 229, 184, 0.06), transparent 60%),
      var(--bg-primary);
  }

  .gl-mast {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 18px 36px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    position: sticky;
    top: 0;
    backdrop-filter: blur(12px);
    background: rgba(6, 9, 15, 0.7);
    z-index: 50;
  }

  .gl-brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: 18px;
    letter-spacing: 0.12em;
    color: var(--text-heading);
    text-decoration: none;
  }

  .gl-fleur {
    color: #d4af6a;
    font-size: 22px;
    line-height: 1;
    text-shadow: 0 0 12px rgba(212, 175, 106, 0.4);
  }

  .gl-brand-name {
    text-transform: uppercase;
  }

  .gl-mast-nav {
    display: flex;
    gap: 28px;
    align-items: center;
    font-family: 'Cinzel', serif;
    font-size: 13px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }

  .gl-mast-nav :global(a) {
    color: var(--text-secondary);
    text-decoration: none;
    transition: color 0.2s;
  }

  .gl-mast-nav :global(a:hover) {
    color: var(--text-heading);
  }

  .gl-cta-thin {
    color: #d4af6a !important;
    border: 1px solid rgba(212, 175, 106, 0.5);
    padding: 6px 14px;
    border-radius: 2px;
  }

  .gl-cta-thin:hover {
    background: rgba(212, 175, 106, 0.1);
    border-color: #d4af6a;
  }

  .gl-foot {
    margin-top: auto;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
    padding: 24px 36px;
  }

  .gl-foot-inner {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.1em;
    color: var(--text-muted);
  }

  .gl-foot-mark {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    text-transform: uppercase;
  }

  .gl-foot nav {
    display: flex;
    gap: 24px;
  }

  .gl-foot nav :global(a) {
    color: var(--text-muted);
    text-decoration: none;
  }

  .gl-foot nav :global(a:hover) {
    color: #d4af6a;
  }

  @media (max-width: 720px) {
    .gl-mast { padding: 14px 18px; }
    .gl-mast-nav { gap: 14px; font-size: 11px; }
    .gl-foot-inner { flex-direction: column; gap: 12px; }
  }
</style>
