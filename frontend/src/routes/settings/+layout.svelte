<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { page } from '$app/stores';

  let { children } = $props();

  const navItems: { label: string; href: string; disabled?: boolean }[] = [
    { label: 'Profile Customization', href: '/settings/profile' },
    { label: 'Account', href: '/settings/account' },
    { label: 'Notifications', href: '/settings/notifications' },
    { label: 'Preferences', href: '/settings/preferences' },
    { label: 'Muted Content', href: '/settings/muted' },
    { label: 'Infractions & Appeals', href: '/account/infractions' }
  ];
</script>

{#if !auth.isLoggedIn && !auth.loading}
  <div class="settings-auth-prompt">
    <p>You need to <a href="/auth/login">log in</a> to access settings.</p>
  </div>
{:else}
  <div class="settings-layout">
    <aside class="settings-sidebar">
      <h2 class="sidebar-title">Settings</h2>
      <nav class="sidebar-nav">
        {#each navItems as item}
          {#if item.disabled}
            <span class="nav-item disabled">{item.label}</span>
          {:else}
            <a
              href={item.href}
              class="nav-item"
              class:active={$page.url.pathname === item.href}
            >{item.label}</a>
          {/if}
        {/each}
      </nav>
    </aside>

    <div class="settings-content">
      {@render children()}
    </div>
  </div>
{/if}

<style>
  .settings-layout {
    display: grid;
    grid-template-columns: 220px 1fr;
    gap: 16px;
    min-height: 60vh;
  }

  .settings-sidebar {
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
  .nav-item:hover:not(.disabled) {
    background: var(--bg-hover);
    color: var(--text-primary);
  }
  .nav-item.active {
    background: var(--accent-glow);
    color: var(--accent);
    font-weight: 600;
  }
  .nav-item.disabled {
    opacity: 0.4;
    cursor: default;
  }

  .settings-content {
    min-width: 0;
  }

  .settings-auth-prompt {
    text-align: center;
    padding: 60px 0;
    color: var(--text-secondary);
    font-size: 14px;
  }

  @media (max-width: 768px) {
    .settings-layout {
      grid-template-columns: 1fr;
    }
  }
</style>
