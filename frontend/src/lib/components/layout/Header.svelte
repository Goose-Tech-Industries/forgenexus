<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import NotificationBell from '$lib/components/layout/NotificationBell.svelte';
  import StatusSelector from '$lib/components/layout/StatusSelector.svelte';
  import { notificationStore } from '$lib/stores/notifications.svelte';
  import { api } from '$lib/api/client';

  let mobileMenuOpen = $state(false);
  let liveCount = $state(0);
  let liveUserCount = $state(0);
  let livePollTimer: ReturnType<typeof setInterval> | null = null;

  async function refreshLive() {
    try {
      const data = await api.getVoiceRooms();
      const rooms = data.rooms || [];
      liveCount = rooms.filter((r: any) => (r.participant_count ?? 0) > 0).length;
      liveUserCount = rooms.reduce((n: number, r: any) => n + (r.participant_count ?? 0), 0);
    } catch { /* silent */ }
  }

  $effect(() => {
    if (auth.isLoggedIn) {
      refreshLive();
      livePollTimer = setInterval(refreshLive, 20000);
    }
    return () => {
      if (livePollTimer) clearInterval(livePollTimer);
      livePollTimer = null;
    };
  });
  let lightMode = $state(typeof localStorage !== 'undefined' && localStorage.getItem('fn-light-mode') === '1');

  $effect(() => {
    if (typeof document !== 'undefined') {
      document.body.classList.toggle('light-mode', lightMode);
      localStorage.setItem('fn-light-mode', lightMode ? '1' : '0');
    }
  });

  function toggleTheme() {
    lightMode = !lightMode;
  }

  $effect(() => {
    if (auth.isLoggedIn) {
      notificationStore.startPolling();
    }
    return () => notificationStore.stopPolling();
  });

  function closeMobileMenu() {
    mobileMenuOpen = false;
  }
</script>

<header class="site-header">
  <div class="header-inner">
    <a href="/" class="logo">
      <span class="logo-icon">&#9776;</span>
      <span class="logo-text">Forge<span class="accent">Nexus</span></span>
    </a>

    <nav class="main-nav" aria-label="Main navigation">
      <a href="/">Home</a>
      <a href="/chat" class="chat-link">Chat</a>
      <a href="/messages" class="messages-link">Messages</a>
      <a href="/live" class="live-link" class:active={liveCount > 0}>
        {#if liveCount > 0}
          <span class="live-dot"></span>
          <span>Live <strong>{liveUserCount}</strong></span>
        {:else}
          Live
        {/if}
      </a>
      <a href="/discover">Discover</a>
      <a href="/marketplace">Market</a>
      <a href="/trending">Trending</a>
      <a href="/members">Members</a>
      <a href="/search">Search</a>
      {#if auth.isLoggedIn}
        <a href="/creator">Creator</a>
        <a href="/following">Following</a>
      {/if}
      {#if auth.isStaff}
        <a href="/mod" class="mod-link">Mod</a>
        <a href="/admin" class="mod-link">Admin</a>
      {/if}
    </nav>

    <div class="header-right">
      <button class="theme-toggle" onclick={toggleTheme} aria-label="Toggle theme" title={lightMode ? 'Switch to dark mode' : 'Switch to light mode'}>
        {#if lightMode}&#9788;{:else}&#9790;{/if}
      </button>
      {#if auth.isLoggedIn}
        <div class="user-menu" aria-label="User menu">
          <NotificationBell />
          <StatusSelector />
          <a href="/profile/{auth.user?.slug}" class="user-link">
            <span class="username">{auth.user?.username}</span>
          </a>
          <button class="btn" onclick={() => auth.logout()}>Logout</button>
        </div>
      {:else}
        <a href="/auth/login" class="btn">Login</a>
        <a href="/auth/register" class="btn btn-primary">Register</a>
      {/if}
    </div>

    <button
      class="mobile-toggle"
      aria-label="Toggle menu"
      aria-expanded={mobileMenuOpen}
      onclick={() => mobileMenuOpen = !mobileMenuOpen}
    >
      <span class="hamburger-line"></span>
      <span class="hamburger-line"></span>
      <span class="hamburger-line"></span>
    </button>
  </div>

  {#if mobileMenuOpen}
    <button class="mobile-backdrop" onclick={closeMobileMenu} aria-hidden="true"></button>
  {/if}

  <nav
    class="mobile-menu"
    class:open={mobileMenuOpen}
    aria-label="Mobile navigation"
  >
    <a href="/" onclick={closeMobileMenu}>Forums</a>
    <a href="/chat" onclick={closeMobileMenu}>Chat</a>
    <a href="/messages" onclick={closeMobileMenu}>Messages</a>
    <a href="/live" onclick={closeMobileMenu}>
      {#if liveCount > 0}
        <span class="live-dot"></span> Live ({liveUserCount})
      {:else}
        Live
      {/if}
    </a>
    <a href="/new-posts" onclick={closeMobileMenu}>New Posts</a>
    <a href="/trending" onclick={closeMobileMenu}>Trending</a>
    <a href="/members" onclick={closeMobileMenu}>Members</a>
    <a href="/stats" onclick={closeMobileMenu}>Stats</a>
    <a href="/search" onclick={closeMobileMenu}>Search</a>
    {#if auth.isLoggedIn}
      <a href="/following" onclick={closeMobileMenu}>Following</a>
    {/if}
    {#if auth.isStaff}
      <a href="/mod" class="mod-link" onclick={closeMobileMenu}>Mod</a>
      <a href="/admin/plugins" class="mod-link" onclick={closeMobileMenu}>Plugins</a>
    {/if}

    <div class="mobile-menu-divider"></div>

    <button class="mobile-menu-btn" onclick={toggleTheme}>
      <span class="mobile-user-icon">{lightMode ? '☀' : '☾'}</span> {lightMode ? 'Dark Mode' : 'Light Mode'}
    </button>

    {#if auth.isLoggedIn}
      <a href="/profile/{auth.user?.slug}" onclick={closeMobileMenu}>
        <span class="mobile-user-icon">👤</span> {auth.user?.username}
      </a>
      <button class="mobile-menu-btn" onclick={() => { auth.logout(); closeMobileMenu(); }}>
        <span class="mobile-user-icon">➜</span> Logout
      </button>
    {:else}
      <a href="/auth/login" onclick={closeMobileMenu}>Login</a>
      <a href="/auth/register" onclick={closeMobileMenu}>Register</a>
    {/if}
  </nav>
</header>

<style>
  .site-header {
    background: linear-gradient(180deg, var(--bg-secondary) 0%, var(--bg-primary) 100%);
    border-bottom: 1px solid var(--border-color);
    position: sticky;
    top: 0;
    z-index: 100;
  }

  .header-inner {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 16px;
    height: 52px;
    display: flex;
    align-items: center;
    gap: 24px;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 18px;
    font-weight: 800;
    color: var(--text-primary);
    text-decoration: none;
  }
  .logo .accent {
    color: var(--accent);
  }
  .logo-icon {
    font-size: 20px;
    color: var(--accent);
  }

  .main-nav {
    display: flex;
    gap: 4px;
  }
  .main-nav a {
    padding: 6px 14px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary);
    transition: all 0.15s;
  }
  .main-nav a:hover {
    background: var(--bg-tertiary);
    color: var(--text-primary);
  }
  .main-nav :global(.mod-link) {
    color: #fbbf24;
    font-weight: 600;
  }
  .main-nav :global(.live-link) {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }
  .main-nav :global(.live-link.active) {
    color: #f87171;
    background: rgba(248, 113, 113, 0.08);
    font-weight: 700;
  }
  .main-nav :global(.live-link.active strong) {
    font-variant-numeric: tabular-nums;
  }
  :global(.live-dot) {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #f87171;
    box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.6);
    animation: header-live-pulse 1.6s ease-out infinite;
    display: inline-block;
  }
  @keyframes header-live-pulse {
    0% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.7); }
    70% { box-shadow: 0 0 0 6px rgba(248, 113, 113, 0); }
    100% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0); }
  }

  .header-right {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .user-menu {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .notification-bell {
    cursor: pointer;
    font-size: 18px;
    opacity: 0.7;
    transition: opacity 0.15s;
  }
  .notification-bell:hover {
    opacity: 1;
  }

  .theme-toggle {
    background: none;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
    cursor: pointer;
    color: var(--text-secondary);
    transition: all 0.15s;
  }
  .theme-toggle:hover {
    background: var(--bg-tertiary);
    color: var(--accent);
    border-color: var(--accent);
  }

  .user-link {
    font-weight: 600;
    font-size: 13px;
  }

  /* Mobile toggle button */
  .mobile-toggle {
    display: none;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    gap: 4px;
    background: none;
    border: none;
    cursor: pointer;
    padding: 8px;
    margin-left: auto;
  }

  .hamburger-line {
    display: block;
    width: 20px;
    height: 2px;
    background: var(--text-primary);
    border-radius: 1px;
    transition: transform 0.2s, opacity 0.2s;
  }

  /* Mobile backdrop overlay */
  .mobile-backdrop {
    display: none;
    position: fixed;
    inset: 0;
    top: 52px;
    background: rgba(0, 0, 0, 0.5);
    border: none;
    z-index: 98;
    cursor: default;
  }

  /* Mobile dropdown menu */
  .mobile-menu {
    display: none;
    flex-direction: column;
    background: var(--bg-secondary);
    border-top: 1px solid var(--border-color);
    overflow: hidden;
    max-height: 0;
    transition: max-height 0.3s ease;
  }

  .mobile-menu.open {
    /* Cap to viewport height so a long staff menu (Forums/Chat/Messages/Live/
       New Posts/Trending/Members/Stats/Search/Following/Mod/Plugins +
       theme/profile/logout) doesn't clip — scroll inside the menu instead. */
    max-height: calc(100vh - 60px);
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  .mobile-menu a,
  .mobile-menu-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    min-height: 48px;
    padding: 0 20px;
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
    text-decoration: none;
    border: none;
    background: none;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    transition: background 0.1s, color 0.1s;
  }

  .mobile-menu a:hover,
  .mobile-menu-btn:hover {
    background: var(--bg-tertiary);
    color: var(--text-primary);
  }

  .mobile-menu :global(.mod-link) {
    color: #fbbf24;
    font-weight: 600;
  }

  .mobile-menu-divider {
    height: 1px;
    background: var(--border-color);
    margin: 4px 16px;
  }

  .mobile-user-icon {
    font-size: 16px;
    width: 20px;
    flex-shrink: 0;
    text-align: center;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  @media (max-width: 768px) {
    .main-nav {
      display: none;
    }

    .header-right {
      display: none;
    }

    .mobile-toggle {
      display: flex;
    }

    .mobile-backdrop {
      display: block;
    }

    .mobile-menu {
      display: flex;
      position: absolute;
      top: 52px;
      left: 0;
      right: 0;
      z-index: 99;
      border-bottom: 1px solid var(--border-color);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    }
  }
</style>
