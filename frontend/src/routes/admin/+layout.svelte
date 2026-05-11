<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { page } from '$app/stores';
  let { children } = $props();

  const navItems = [
    { label: 'Dashboard', href: '/admin' },
    { label: 'Settings', href: '/admin/settings' },
    { label: 'Users', href: '/admin/users' },
    { label: 'Groups', href: '/admin/groups' },
    { label: 'Ranks', href: '/admin/ranks' },
    { label: 'Promotion Rules', href: '/admin/promotions' },
    { label: 'Forums', href: '/admin/forums' },
    { label: 'Themes', href: '/admin/themes' },
    { label: 'Announcements', href: '/admin/announcements' },
    { label: 'Chat Channels', href: '/admin/chat' },
    { label: 'Slash Commands', href: '/admin/slash-commands' },
    { label: 'Voice Rooms', href: '/admin/voice' },
    { label: 'Custom Emojis', href: '/admin/emojis' },
    { label: 'Custom BBCodes', href: '/admin/bbcodes' },
    { label: 'Achievements', href: '/admin/achievements' },
    { label: 'Chat Webhooks', href: '/admin/webhooks' },
    { label: 'Forum Webhooks', href: '/admin/forum-webhooks' },
    { label: 'Subscriptions', href: '/admin/subscriptions' },
    { label: 'Plugins', href: '/admin/plugins' },
    { label: 'Plugin Pages', href: '/admin/pages' },
    { label: 'Analytics', href: '/admin/analytics' },
    { label: 'Content Decay', href: '/admin/content-decay' },
    { label: 'Audit Trail', href: '/admin/audit-trail' },
    { label: 'Staff Performance', href: '/admin/staff-performance' },
    { label: 'Engagement', href: '/admin/engagement' },
    { label: 'Toxic Warning', href: '/admin/toxic-warning' },
    { label: 'Quarantine', href: '/admin/quarantine' },
    { label: 'Login Events', href: '/admin/login-events' },
    { label: 'Impersonation', href: '/admin/impersonation' },
    { label: 'Content Quality', href: '/admin/content-quality' },
    { label: 'Growth', href: '/admin/growth' },
    { label: 'Re-engagement', href: '/admin/re-engagement' },
    { label: 'SEO Health', href: '/admin/seo' },
    { label: 'Cleanup', href: '/admin/cleanup' },
    { label: 'Permission Sandbox', href: '/admin/permission-sandbox' },
    { label: 'Import Data', href: '/admin/import' },
    { label: 'Maintenance', href: '/admin/maintenance' },
    { label: 'Mass Email', href: '/admin/mass-email' },
  ];

  const isPluginPage = $derived($page.url.pathname.startsWith('/admin/plugins'));
</script>

{#if !auth.isStaff}
  <div class="denied"><h2>Access Denied</h2><p>Administrator access required.</p><a href="/">Return to forums</a></div>
{:else}
  {#if isPluginPage}
    <!-- Plugin pages have their own layout -->
    {@render children()}
  {:else}
    <div class="admin-layout">
      <aside class="admin-sidebar">
        <h2 class="sidebar-title">Admin Panel</h2>
        <nav class="sidebar-nav">
          {#each navItems as item}
            <a
              href={item.href}
              class="nav-item"
              class:active={item.href === '/admin' ? String($page.url.pathname) === String(item.href) : $page.url.pathname.startsWith(item.href)}
            >{item.label}</a>
          {/each}
        </nav>
      </aside>
      <div class="admin-content">{@render children()}</div>
    </div>
  {/if}
{/if}

<style>
  .admin-layout { display: grid; grid-template-columns: 200px 1fr; gap: 16px; min-height: 60vh; }
  .admin-sidebar { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; height: fit-content; }
  .sidebar-title { font-size: 14px; font-weight: 700; color: var(--accent); text-transform: uppercase; letter-spacing: 0.03em; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border-color); }
  .sidebar-nav { display: flex; flex-direction: column; gap: 2px; }
  .nav-item { padding: 8px 12px; border-radius: var(--radius); font-size: 13px; color: var(--text-secondary); text-decoration: none; transition: all 0.15s; }
  .nav-item:hover { background: var(--bg-hover); color: var(--text-primary); }
  .nav-item.active { background: var(--accent-glow); color: var(--accent); font-weight: 600; }
  .admin-content { min-width: 0; }
  .denied { text-align: center; padding: 60px 0; color: var(--text-secondary); }
  .denied h2 { color: var(--text-primary); margin-bottom: 8px; }
  .denied a { color: var(--accent); }
  @media (max-width: 768px) { .admin-layout { grid-template-columns: 1fr; } }
</style>
