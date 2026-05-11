<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { page } from '$app/stores';

  let { children } = $props();

  const navItems = [
    { label: 'Dashboard', href: '/mod' },
    { label: 'Reports', href: '/mod/reports' },
    { label: 'Appeals', href: '/mod/appeals' },
    { label: 'Suspicious', href: '/mod/suspicious' },
    { label: 'Policies', href: '/mod/policies' },
    { label: 'Bans', href: '/mod/bans' },
    { label: 'Mod Log', href: '/mod/logs' }
  ];
</script>

{#if !auth.isStaff}
  <div class="mod-denied">
    <h2>Access Denied</h2>
    <p>You do not have permission to view this page.</p>
    <a href="/">Return to forums</a>
  </div>
{:else}
  <div class="mod-layout">
    <aside class="mod-sidebar">
      <h2 class="sidebar-title">Moderation</h2>
      <nav class="sidebar-nav">
        {#each navItems as item}
          <a
            href={item.href}
            class="nav-item"
            class:active={$page.url.pathname === item.href}
          >{item.label}</a>
        {/each}
      </nav>
    </aside>

    <div class="mod-content">
      {@render children()}
    </div>
  </div>
{/if}

<style>
  .mod-layout {
    display: grid;
    grid-template-columns: 200px 1fr;
    gap: 16px;
    min-height: 60vh;
  }

  .mod-sidebar {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    height: fit-content;
  }

  .sidebar-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
  }

  .sidebar-nav {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .nav-item {
    padding: 8px 12px;
    border-radius: var(--radius);
    font-size: 13px;
    color: var(--text-secondary);
    text-decoration: none;
    transition: all 0.15s;
  }
  .nav-item:hover {
    background: var(--bg-hover);
    color: var(--text-primary);
  }
  .nav-item.active {
    background: var(--accent-glow);
    color: var(--accent);
    font-weight: 600;
  }

  .mod-content {
    min-width: 0;
  }

  .mod-denied {
    text-align: center;
    padding: 60px 0;
    color: var(--text-secondary);
  }
  .mod-denied h2 {
    color: var(--text-primary);
    margin-bottom: 8px;
  }
  .mod-denied a {
    color: var(--accent);
  }

  @media (max-width: 768px) {
    .mod-layout {
      grid-template-columns: 1fr;
    }
  }
</style>
