<script lang="ts">
  import { onMount } from 'svelte';
  import Shoutbox from '$lib/components/chat/Shoutbox.svelte';
  import { auth } from '$lib/stores/auth.svelte';

  const owncastUrl = import.meta.env.VITE_OWNCAST_URL || 'http://localhost:8088';

  let isLive = $state(false);
  let streamTitle = $state('Calamity TV');
  let creatorName = $state('Calamity');
  let creatorAvatar = $state<string | null>(null);

  onMount(async () => {
    try {
      const res = await fetch(`${owncastUrl}/api/status`);
      if (res.ok) {
        const data = await res.json();
        isLive = data.online === true;
        if (data.streamTitle) streamTitle = data.streamTitle;
        if (data.broadcaster?.displayName) {
          creatorName = data.broadcaster.displayName;
          creatorAvatar = data.broadcaster?.avatar || null;
        }
      }
    } catch {
      isLive = false;
    }
    if (auth.user?.username && creatorName === 'Calamity') {
      creatorName = auth.user.username;
      creatorAvatar = creatorAvatar || auth.user.avatar_url || null;
    }
  });
</script>

<svelte:head>
  <title>Calamity TV — ForgeNexus</title>
</svelte:head>

<div class="tv-portal">
  <div class="tv-bg-glow tv-glow-top"></div>
  <div class="tv-bg-glow tv-glow-bottom"></div>

  <div class="tv-hero">
    <div class="tv-hero-left">
      <h1 class="tv-title">
        <span class="title-icon">&#x1F4FA;</span>
        Calamity TV
      </h1>
      <p class="tv-subtitle">{streamTitle}</p>
    </div>
    <div class="tv-hero-badge">
      {#if isLive}
        <span class="badge badge-live tv-live-badge">&#x25CF; LIVE</span>
      {:else}
        <span class="tv-offline-badge">&#x25CF; OFFLINE</span>
      {/if}
    </div>
  </div>

  <div class="tv-split">
    <div class="tv-player-col">
      <div class="player-container glass">
        <iframe
          src={`${owncastUrl}/embed/video`}
          title="Calamity TV Stream"
          class="player-iframe"
          allow="autoplay; fullscreen"
          allowfullscreen
        ></iframe>
      </div>

      <div class="creator-card glass">
        <div class="creator-card-inner">
          <div class="creator-avatar-wrapper">
            {#if creatorAvatar}
              <img src={creatorAvatar} alt={creatorName} class="avatar avatar-live" />
            {:else}
              <div class="avatar avatar-live creator-avatar-placeholder">
                {creatorName[0]?.toUpperCase() || 'C'}
              </div>
            {/if}
          </div>
          <div class="creator-info">
            <div class="creator-name">{creatorName}</div>
            <div class="creator-role">Streamer</div>
          </div>
          <a href="/creator" class="creator-support-btn">
            <span class="support-icon">&#x2764;&#xFE0F;</span>
            Support Creator
          </a>
        </div>
      </div>
    </div>

    <div class="tv-chat-col">
      <div class="chat-wrapper glass">
        <div class="chat-header">
          <span>&#x1F4AC; Live Chat</span>
        </div>
        <div class="shoutbox-container">
          <Shoutbox />
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .tv-portal {
    position: relative;
    max-width: 1400px;
    margin: 0 auto;
    padding: 24px 20px 80px;
    min-height: 100vh;
    overflow: hidden;
  }

  .tv-bg-glow {
    position: fixed;
    border-radius: 50%;
    filter: blur(120px);
    opacity: 0.12;
    pointer-events: none;
    z-index: 0;
  }

  .tv-glow-top {
    top: -200px;
    left: 10%;
    width: 600px;
    height: 600px;
    background: radial-gradient(circle, #ef4444 0%, transparent 70%);
  }

  .tv-glow-bottom {
    bottom: -200px;
    right: 10%;
    width: 500px;
    height: 500px;
    background: radial-gradient(circle, #8b5cf6 0%, transparent 70%);
  }

  .tv-hero {
    position: relative;
    z-index: 1;
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 28px;
  }

  .tv-hero-left {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .tv-title {
    font-size: 32px;
    font-weight: 900;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 0;
    letter-spacing: -0.02em;
  }

  .title-icon {
    font-size: 28px;
  }

  .tv-subtitle {
    font-size: 14px;
    color: var(--text-muted);
    margin: 0;
  }

  .tv-live-badge {
    font-size: 13px;
    padding: 4px 14px;
    letter-spacing: 0.08em;
    box-shadow: 0 0 20px rgba(239, 68, 68, 0.3);
  }

  .tv-offline-badge {
    display: inline-flex;
    align-items: center;
    padding: 4px 14px;
    border-radius: 100px;
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.08em;
    background: rgba(100, 116, 139, 0.15);
    color: #64748b;
  }

  .tv-split {
    position: relative;
    z-index: 1;
    display: grid;
    grid-template-columns: 1fr 380px;
    gap: 20px;
    min-height: 65vh;
  }

  .tv-player-col {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .player-container {
    position: relative;
    width: 100%;
    aspect-ratio: 16 / 9;
    border-radius: var(--radius-lg);
    overflow: hidden;
    background: #000;
    box-shadow: 0 0 40px rgba(239, 68, 68, 0.08), 0 0 80px rgba(139, 92, 246, 0.05), var(--glass-shadow);
    border: 1px solid rgba(239, 68, 68, 0.15);
  }

  .player-iframe {
    width: 100%;
    height: 100%;
    border: none;
  }

  .creator-card {
    border-radius: var(--radius-lg);
    border: 1px solid rgba(139, 92, 246, 0.15);
    box-shadow: 0 0 30px rgba(139, 92, 246, 0.06);
  }

  .creator-card-inner {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 16px;
  }

  .creator-avatar-wrapper {
    flex-shrink: 0;
  }

  .creator-avatar-wrapper :global(.avatar) {
    width: 48px;
    height: 48px;
  }

  .creator-avatar-placeholder {
    background: var(--accent2);
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 20px;
  }

  .creator-info {
    flex: 1;
    min-width: 0;
  }

  .creator-name {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .creator-role {
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .creator-support-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 18px;
    border-radius: 100px;
    background: linear-gradient(135deg, rgba(139, 92, 246, 0.2), rgba(239, 68, 68, 0.15));
    border: 1px solid rgba(139, 92, 246, 0.3);
    color: var(--text-primary);
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    white-space: nowrap;
    transition: all var(--transition-fast);
  }

  .creator-support-btn:hover {
    background: linear-gradient(135deg, rgba(139, 92, 246, 0.35), rgba(239, 68, 68, 0.25));
    border-color: rgba(139, 92, 246, 0.5);
    box-shadow: 0 0 20px rgba(139, 92, 246, 0.2);
  }

  .support-icon {
    font-size: 14px;
  }

  .tv-chat-col {
    min-height: 0;
  }

  .chat-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .chat-header {
    padding: 10px 16px;
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-secondary);
    background: linear-gradient(180deg, rgba(139, 92, 246, 0.1), rgba(239, 68, 68, 0.05));
    border-bottom: 1px solid rgba(139, 92, 246, 0.2);
  }

  .shoutbox-container {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  .shoutbox-container :global(.shoutbox) {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  .shoutbox-container :global(.shoutbox-header) {
    pointer-events: none;
  }

  .shoutbox-container :global(.toggle-icon) {
    display: none;
  }

  .shoutbox-container :global(.shoutbox-messages) {
    flex: 1;
    height: auto;
  }

  @media (max-width: 900px) {
    .tv-split {
      grid-template-columns: 1fr;
    }

    .tv-chat-col {
      min-height: 420px;
    }

    .chat-wrapper {
      height: 420px;
    }

    .tv-title {
      font-size: 24px;
    }

    .player-container {
      aspect-ratio: auto;
      min-height: 240px;
    }
  }
</style>
