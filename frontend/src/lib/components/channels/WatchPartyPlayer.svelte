<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { voiceStore, type WatchPartyMedia } from '$lib/stores/voice.svelte';

  // Drift tolerance in seconds; viewers seek when they fall this far from the host.
  const DRIFT_SECONDS = 2.0;

  let ytPlayer: any = null;
  let ytContainer: HTMLDivElement | null = null;
  let ytReady = $state(false);
  let urlInput = $state('');
  let lastAppliedUpdate: string | null = null;

  // Re-embed whenever the active media changes
  let lastMediaKey = $state<string | null>(null);

  $effect(() => {
    const party = voiceStore.watchParty;
    const key = party ? `${party.media.type}:${party.media.id}` : null;
    if (key !== lastMediaKey) {
      lastMediaKey = key;
      teardownPlayer();
      if (party && party.media.type === 'youtube') {
        mountYouTube(party.media);
      }
      // Twitch and Vimeo use a simple iframe; nothing to mount programmatically.
    }
  });

  // React to play/pause/seek updates from the host
  $effect(() => {
    const party = voiceStore.watchParty;
    if (!party) return;
    const key = `${party.updated_at}:${party.current_time}:${party.is_playing}`;
    if (key === lastAppliedUpdate) return;
    lastAppliedUpdate = key;
    if (voiceStore.isWatchPartyHost) return; // host's actions originate locally, no echo apply
    applyRemoteState(party.current_time, party.is_playing);
  });

  onMount(() => {
    loadYouTubeAPI();
  });

  onDestroy(() => {
    teardownPlayer();
  });

  async function loadYouTubeAPI() {
    if ((window as any).YT?.Player) return;
    if (document.querySelector('script[src*="youtube.com/iframe_api"]')) {
      waitForYT();
      return;
    }
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);
    waitForYT();
  }

  function waitForYT() {
    const check = () => {
      if ((window as any).YT?.Player) {
        const party = voiceStore.watchParty;
        if (party && party.media.type === 'youtube') {
          mountYouTube(party.media);
        }
      } else {
        setTimeout(check, 100);
      }
    };
    check();
  }

  function mountYouTube(media: WatchPartyMedia) {
    if (!ytContainer) return;
    const YT = (window as any).YT;
    if (!YT?.Player) {
      waitForYT();
      return;
    }
    ytContainer.innerHTML = '<div id="yt-player-target"></div>';
    ytPlayer = new YT.Player('yt-player-target', {
      height: '100%',
      width: '100%',
      videoId: media.id,
      playerVars: { playsinline: 1, rel: 0, modestbranding: 1 },
      events: {
        onReady: (e: any) => {
          ytReady = true;
          const party = voiceStore.watchParty;
          if (party) {
            try { e.target.seekTo(party.current_time, true); } catch {}
            if (party.is_playing) {
              try { e.target.playVideo(); } catch {}
            }
          }
        },
        onStateChange: (e: any) => {
          if (!voiceStore.isWatchPartyHost) return;
          const S = YT.PlayerState;
          if (e.data === S.PLAYING) {
            voiceStore.watchSync(e.target.getCurrentTime(), true);
          } else if (e.data === S.PAUSED) {
            voiceStore.watchSync(e.target.getCurrentTime(), false);
          }
        }
      }
    });
  }

  function applyRemoteState(time: number, playing: boolean) {
    if (!ytPlayer || !ytReady) return;
    try {
      const current = ytPlayer.getCurrentTime?.() ?? 0;
      if (Math.abs(current - time) > DRIFT_SECONDS) {
        ytPlayer.seekTo(time, true);
      }
      if (playing) {
        ytPlayer.playVideo();
      } else {
        ytPlayer.pauseVideo();
      }
    } catch (e) {
      console.warn('[watch-party] applyRemoteState failed', e);
    }
  }

  function teardownPlayer() {
    if (ytPlayer) {
      try { ytPlayer.destroy(); } catch {}
      ytPlayer = null;
    }
    ytReady = false;
    if (ytContainer) ytContainer.innerHTML = '';
  }

  async function handleStart() {
    const url = urlInput.trim();
    if (!url) return;
    await voiceStore.startWatchParty(url);
    urlInput = '';
  }

  async function handleStop() {
    if (!confirm('End the watch party for everyone?')) return;
    await voiceStore.stopWatchParty();
  }

  function hostControl(action: 'play' | 'pause') {
    if (!voiceStore.isWatchPartyHost) return;
    if (action === 'play') voiceStore.watchPlay();
    else voiceStore.watchPause();
  }

  function twitchEmbedSrc(media: WatchPartyMedia): string {
    const parent = typeof window !== 'undefined' ? window.location.hostname : 'localhost';
    switch (media.type) {
      case 'twitch_video':
        return `https://player.twitch.tv/?video=v${media.id}&parent=${parent}&autoplay=true`;
      case 'twitch_clip':
        return `https://clips.twitch.tv/embed?clip=${media.id}&parent=${parent}&autoplay=true`;
      case 'twitch_channel':
        return `https://player.twitch.tv/?channel=${media.id}&parent=${parent}&autoplay=true&muted=false`;
      default:
        return '';
    }
  }
</script>

{#if voiceStore.isInRoom}
  <div class="watch-party">
    {#if !voiceStore.watchParty}
      <div class="start-form">
        <div class="start-header">
          <span class="icon">📺</span>
          <span>Start a watch party</span>
        </div>
        <div class="start-row">
          <input
            type="text"
            bind:value={urlInput}
            placeholder="Paste a YouTube, Twitch, or Vimeo URL"
            onkeydown={(e) => { if (e.key === 'Enter') handleStart(); }}
          />
          <button class="btn-primary" onclick={handleStart} disabled={!urlInput.trim()}>Start</button>
        </div>
        {#if voiceStore.watchPartyError}
          <div class="error">{voiceStore.watchPartyError}</div>
        {/if}
        <div class="hint">
          Hosts control playback — everyone else's player follows along. For Netflix/Disney+ etc., share your browser tab with audio instead.
        </div>
      </div>
    {:else}
      {@const party = voiceStore.watchParty}
      <div class="player-wrap">
        <div class="player-head">
          <span class="tag">{party.media.label}</span>
          <span class="host-label">
            {voiceStore.isWatchPartyHost ? 'You are hosting' : 'Watching along'}
          </span>
          {#if voiceStore.isWatchPartyHost || voiceStore.isHost}
            <button class="btn-stop" onclick={handleStop}>End watch party</button>
          {/if}
        </div>

        {#if party.media.type === 'youtube'}
          <div class="player-frame" bind:this={ytContainer}></div>
          {#if voiceStore.isWatchPartyHost}
            <div class="host-controls">
              <button class="btn-ctrl" onclick={() => hostControl('play')} disabled={party.is_playing}>▶ Play</button>
              <button class="btn-ctrl" onclick={() => hostControl('pause')} disabled={!party.is_playing}>⏸ Pause</button>
              <span class="ctrl-note">Use the player's scrub bar to seek; everyone follows automatically.</span>
            </div>
          {:else}
            <div class="viewer-note">
              {party.is_playing ? '▶ Playing' : '⏸ Paused'} · following host at {Math.floor(party.current_time)}s
            </div>
          {/if}
        {:else if party.media.type === 'twitch_video' || party.media.type === 'twitch_clip' || party.media.type === 'twitch_channel'}
          <div class="player-frame">
            <iframe
              title={party.media.label}
              src={twitchEmbedSrc(party.media)}
              allowfullscreen
              frameborder="0"
              scrolling="no"
            ></iframe>
          </div>
          <div class="viewer-note">
            Twitch playback syncs via the host's player. Live streams are real-time for everyone; VODs follow the host's timestamp.
          </div>
        {:else if party.media.type === 'vimeo'}
          <div class="player-frame">
            <iframe
              title={party.media.label}
              src="https://player.vimeo.com/video/{party.media.id}"
              allow="autoplay; fullscreen; picture-in-picture"
              allowfullscreen
              frameborder="0"
            ></iframe>
          </div>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .watch-party {
    border-top: 1px solid var(--border-color);
    background: var(--bg-secondary);
    padding: 12px 16px;
  }

  .start-form { display: flex; flex-direction: column; gap: 8px; }
  .start-header { display: flex; align-items: center; gap: 8px; font-size: 12px; font-weight: 800; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
  .start-header .icon { font-size: 16px; }
  .start-row { display: flex; gap: 8px; }
  .start-row input {
    flex: 1;
    padding: 8px 10px;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    color: var(--text-primary);
    font-family: inherit;
    font-size: 13px;
  }
  .btn-primary {
    padding: 8px 16px;
    background: var(--accent);
    color: var(--bg-primary);
    border: none;
    border-radius: var(--radius);
    font-weight: 700;
    cursor: pointer;
    font-family: inherit;
    font-size: 13px;
  }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .hint { font-size: 11px; color: var(--text-muted); line-height: 1.4; }
  .error { font-size: 12px; color: #f87171; padding: 6px 8px; background: rgba(248,113,113,0.1); border-radius: var(--radius); }

  .player-wrap { display: flex; flex-direction: column; gap: 8px; }
  .player-head { display: flex; align-items: center; gap: 12px; font-size: 11px; }
  .tag {
    padding: 2px 8px;
    background: rgba(99, 102, 241, 0.15);
    color: #a5b4fc;
    border-radius: 10px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .host-label { color: var(--text-muted); font-weight: 600; }
  .btn-stop {
    margin-left: auto;
    padding: 4px 10px;
    background: rgba(248, 113, 113, 0.12);
    color: #f87171;
    border: 1px solid rgba(248, 113, 113, 0.3);
    border-radius: var(--radius);
    cursor: pointer;
    font-family: inherit;
    font-size: 11px;
    font-weight: 700;
  }

  .player-frame {
    position: relative;
    width: 100%;
    aspect-ratio: 16/9;
    background: #000;
    border-radius: var(--radius);
    overflow: hidden;
  }
  .player-frame :global(iframe),
  .player-frame iframe {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    border: 0;
  }

  .host-controls { display: flex; gap: 6px; align-items: center; font-size: 11px; }
  .btn-ctrl {
    padding: 4px 12px;
    background: var(--bg-tertiary, var(--bg-primary));
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    border-radius: var(--radius);
    cursor: pointer;
    font-family: inherit;
    font-size: 11px;
    font-weight: 700;
  }
  .btn-ctrl:disabled { opacity: 0.4; cursor: not-allowed; }
  .ctrl-note { color: var(--text-muted); margin-left: 6px; }
  .viewer-note { font-size: 11px; color: var(--text-muted); text-align: center; }
</style>
