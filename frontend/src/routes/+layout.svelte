<script lang="ts">
  import '../app.css';
  import { goto } from '$app/navigation';
  import Header from '$lib/components/layout/Header.svelte';
  import ChatBar from '$lib/components/chat/ChatBar.svelte';
  import ImpersonationBanner from '$lib/components/moderation/ImpersonationBanner.svelte';
  import CookieConsent from '$lib/components/common/CookieConsent.svelte';
  import ToastContainer from '$lib/components/common/ToastContainer.svelte';
  import NotificationToaster from '$lib/components/layout/NotificationToaster.svelte';
  import BackToTop from '$lib/components/common/BackToTop.svelte';
  import AnnouncementBanner from '$lib/components/common/AnnouncementBanner.svelte';
  import BanNotice from '$lib/components/common/BanNotice.svelte';
  import OfflineBanner from '$lib/components/common/OfflineBanner.svelte';
  import CommandPalette from '$lib/components/common/CommandPalette.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { siteSettings } from '$lib/stores/settings.svelte';
  import { themeStore } from '$lib/stores/theme.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { api } from '$lib/api/client';
  import { beforeNavigate } from '$app/navigation';
  import { updated } from '$app/state';

  let { children } = $props();
  let userPrefs = $state<Record<string, any> | null>(null);
  let prefsLoadedForUser = $state<string | null>(null);
  let onlineCount = $state<number | null>(null);

  $effect(() => {
    auth.init();
    siteSettings.load();
    themeStore.loadThemes();

    // SW posts this when it detects a stale-chunk 404 — force a hard reload
    // so the page picks up the current build's bundle hashes.
    if (typeof navigator !== 'undefined' && 'serviceWorker' in navigator) {
      const handler = (event: MessageEvent) => {
        if (event.data?.type === 'sw-stale-bundle-reload') {
          location.reload();
        }
      };
      navigator.serviceWorker.addEventListener('message', handler);
      return () => navigator.serviceWorker.removeEventListener('message', handler);
    }
  });

  // SvelteKit version-poll: when the server reports a new build hash, force
  // a full reload on the next navigation so we don't hit chunk-404s from
  // stale dynamic-import filenames.
  beforeNavigate(({ willUnload, to }) => {
    if (updated.current && !willUnload && to?.url) {
      location.href = to.url.href;
    }
  });

  // Connect WebSocket when user is authenticated
  $effect(() => {
    if (auth.user && !auth.loading) {
      socketStore.connect();
    } else if (!auth.user && !auth.loading) {
      socketStore.disconnect();
    }
  });

  // Apply theme when user is loaded
  $effect(() => {
    if (auth.user && themeStore.loaded) {
      themeStore.applyFromUser(auth.user);
    } else if (!auth.user && !auth.loading) {
      themeStore.reset();
    }
  });

  // Load and apply user preferences (only once per user)
  $effect(() => {
    if (auth.user && auth.user.id !== prefsLoadedForUser) {
      loadAndApplyPreferences();
    } else if (!auth.user && !auth.loading) {
      prefsLoadedForUser = null;
      clearPreferenceClasses();
    }
  });

  async function loadAndApplyPreferences() {
    try {
      const data = await api.getPreferences();
      userPrefs = data.preferences;
      prefsLoadedForUser = auth.user?.id ?? null;
      applyPreferenceClasses(data.preferences);
    } catch {
      // preferences not critical
    }
  }

  function applyPreferenceClasses(prefs: Record<string, any>) {
    if (typeof document === 'undefined') return;
    const body = document.body;

    // Accessibility
    body.classList.toggle('reduced-motion', !!prefs.reduced_motion);
    body.classList.toggle('high-contrast', !!prefs.high_contrast);
    body.classList.toggle('dyslexia-font', !!prefs.dyslexia_font);
    body.classList.toggle('text-only-mode', !!prefs.text_only_mode);

    // Colorblind
    body.classList.remove('colorblind-protanopia', 'colorblind-deuteranopia', 'colorblind-tritanopia');
    if (prefs.colorblind_mode && prefs.colorblind_mode !== 'none') {
      body.classList.add(`colorblind-${prefs.colorblind_mode}`);
    }

    // Density
    body.classList.remove('density-compact', 'density-comfortable', 'density-spacious');
    body.classList.add(`density-${prefs.content_density || 'comfortable'}`);

    // Spoilers
    body.classList.toggle('show-spoilers', !!prefs.show_spoilers);
  }

  function clearPreferenceClasses() {
    if (typeof document === 'undefined') return;
    const body = document.body;
    body.classList.remove(
      'reduced-motion', 'high-contrast', 'dyslexia-font', 'text-only-mode',
      'colorblind-protanopia', 'colorblind-deuteranopia', 'colorblind-tritanopia',
      'density-compact', 'density-comfortable', 'density-spacious', 'show-spoilers'
    );
  }

  // Online count: prefer WebSocket presence, fall back to API polling
  $effect(() => {
    if (socketStore.connected && socketStore.onlineUsers.length > 0) {
      onlineCount = socketStore.onlineUsers.length;
    }
  });

  $effect(() => {
    if (!socketStore.connected) {
      loadOnlineCount();
      const interval = setInterval(loadOnlineCount, 60000);
      return () => clearInterval(interval);
    }
  });

  async function loadOnlineCount() {
    try {
      const data = await api.getOnlineUsers();
      onlineCount = data?.stats?.total ?? null;
    } catch {
      // not critical
    }
  }

  // Keyboard shortcut: / to focus search
  function handleGlobalKeydown(e: KeyboardEvent) {
    if (e.key !== '/') return;
    const tag = (e.target as HTMLElement)?.tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || (e.target as HTMLElement)?.isContentEditable) return;
    e.preventDefault();
    const searchInput = document.querySelector<HTMLInputElement>('input[name="search"], input[type="search"]');
    if (searchInput) {
      searchInput.focus();
    } else {
      goto('/search');
    }
  }
</script>

<svelte:window onkeydown={handleGlobalKeydown} />

<svelte:head>
  <title>ForgeNexus</title>
  <meta name="description" content="ForgeNexus — modern community forum platform" />
  <meta property="og:site_name" content="ForgeNexus" />
  <meta property="og:type" content="website" />
  <meta name="theme-color" content="#00d4aa" />
  <link rel="manifest" href="/manifest.json" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="alternate" type="application/rss+xml" title="ForgeNexus - Threads" href="/api/rss/threads" />
  <link rel="alternate" type="application/rss+xml" title="ForgeNexus - Posts" href="/api/rss/posts" />
</svelte:head>

<BanNotice />

<div class="app-shell" class:no-chatbar={!siteSettings.chatBarEnabled}>
  <ImpersonationBanner />
  <Header />
  <NotificationToaster />
  <AnnouncementBanner />

  <main class="content-area">
    {@render children()}
  </main>

  <footer class="site-footer">
    <div class="footer-inner">
      <span class="powered-by">Powered by <strong>ForgeNexus</strong> &mdash; Project: Twisted Calamity Realms</span>
      {#if onlineCount !== null}
        <span class="online-count"><span class="online-dot"></span> {onlineCount} online</span>
      {/if}
      <nav class="footer-links">
        <a href="/terms">Terms</a>
        <a href="/privacy">Privacy</a>
        <a href="/rules">Rules</a>
        <a href="/contact">Contact</a>
        <a href="/stats">Stats</a>
        <a href="/api/rss/threads" title="RSS Feed">RSS</a>
      </nav>
    </div>
  </footer>

  {#if siteSettings.chatBarEnabled}
    <ChatBar />
  {/if}

  <CommandPalette />
  <BackToTop />
  <CookieConsent />
  <ToastContainer />
  <OfflineBanner />
</div>

<style>
  .app-shell {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    padding-bottom: var(--chatbar-height);
  }

  .app-shell.no-chatbar {
    padding-bottom: 0;
  }

  .content-area {
    flex: 1;
    max-width: 1200px;
    width: 100%;
    margin: 0 auto;
    padding: 12px 16px;
  }

  .site-footer {
    background: var(--bg-secondary);
    border-top: 1px solid var(--border-color);
    margin-top: auto;
  }

  .footer-inner {
    max-width: 1200px;
    margin: 0 auto;
    padding: 12px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    color: var(--text-muted);
  }

  .powered-by strong {
    color: var(--accent);
  }

  .footer-links {
    display: flex;
    gap: 12px;
  }
  .footer-links a {
    color: var(--text-muted);
    font-size: 11px;
    text-decoration: none;
  }
  .footer-links a:hover {
    color: var(--accent);
  }

  .online-count {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
    color: var(--text-muted);
  }

  .online-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #22c55e;
    display: inline-block;
    box-shadow: 0 0 4px #22c55e;
  }
</style>
