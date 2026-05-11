<script lang="ts">
  interface Props {
    songUrl: string | null;
    songTitle: string | null;
    autoplay?: boolean;
  }

  let { songUrl, songTitle, autoplay = false }: Props = $props();
  let audio: HTMLAudioElement;
  let playing = $state(false);
  let progress = $state(0);

  function toggle() {
    if (!audio) return;
    if (playing) {
      audio.pause();
    } else {
      audio.play().catch(() => {});
    }
    playing = !playing;
  }
</script>

{#if songUrl}
  <div class="profile-song glass">
    <button class="song-toggle" onclick={toggle}>
      {playing ? '⏸' : '▶️'}
    </button>
    <div class="song-info">
      <div class="song-label">Now Playing</div>
      <div class="song-title">{songTitle || 'Profile Song'}</div>
      <div class="song-progress">
        <div class="song-bar" style="width: {progress}%"></div>
      </div>
    </div>
    <audio
      bind:this={audio}
      src={songUrl}
      preload="none"
      ontimeupdate={() => { if (audio?.duration) progress = (audio.currentTime / audio.duration) * 100; }}
      onended={() => { playing = false; progress = 0; }}
    ></audio>
  </div>
{/if}

<style>
  .profile-song {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 14px; border-radius: var(--radius-lg);
    border: 1px solid var(--border-accent);
  }

  .song-toggle {
    width: 36px; height: 36px; border-radius: 50%;
    background: var(--accent-gradient); border: none;
    display: flex; align-items: center; justify-content: center;
    font-size: 16px; cursor: pointer;
    box-shadow: 0 2px 8px var(--accent-glow);
    transition: transform var(--transition-fast);
  }

  .song-toggle:hover { transform: scale(1.1); }

  .song-info { flex: 1; min-width: 0; }
  .song-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--accent); font-weight: 700; }
  .song-title { font-size: 13px; color: var(--text-primary); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

  .song-progress {
    height: 3px; background: var(--bg-elevated); border-radius: 2px; margin-top: 6px;
    overflow: hidden;
  }

  .song-bar {
    height: 100%; background: var(--accent-gradient); border-radius: 2px;
    transition: width 0.3s linear;
  }
</style>
