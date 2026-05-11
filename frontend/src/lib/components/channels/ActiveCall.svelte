<script lang="ts">
  import { api } from '$lib/api/client';

  let {
    callId,
    callType,
    peerUsername,
    peerAvatarUrl,
    localStream,
    remoteStream,
    isMuted,
    isVideoOn,
    onToggleMute,
    onToggleVideo,
    onHangUp
  }: {
    callId: string;
    callType: string;
    peerUsername: string;
    peerAvatarUrl: string | null;
    localStream: MediaStream | null;
    remoteStream: MediaStream | null;
    isMuted: boolean;
    isVideoOn: boolean;
    onToggleMute: () => void;
    onToggleVideo: () => void;
    onHangUp: () => void;
  } = $props();

  let elapsed = $state(0);
  let timer: ReturnType<typeof setInterval>;

  $effect(() => {
    timer = setInterval(() => { elapsed++; }, 1000);
    return () => clearInterval(timer);
  });

  function formatDuration(secs: number): string {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }
</script>

<div class="active-call-overlay">
  <div class="call-content">
    {#if (isVideoOn || remoteStream) && (callType === 'video' || isVideoOn)}
      <!-- Video view -->
      <div class="video-container">
        {#if remoteStream}
          <video class="remote-video" autoplay playsinline srcObject={remoteStream}></video>
        {:else}
          <div class="video-placeholder">
            <span class="placeholder-text">Waiting for video...</span>
          </div>
        {/if}

        {#if isVideoOn && localStream}
          <video class="local-video" autoplay muted playsinline srcObject={localStream}></video>
        {/if}
      </div>
    {:else}
      <!-- Audio-only view -->
      <div class="audio-view">
        <div class="peer-avatar-large">
          {#if peerAvatarUrl}
            <img src={peerAvatarUrl} alt={peerUsername} />
          {:else}
            <span class="avatar-letter-lg">{peerUsername[0]?.toUpperCase() || '?'}</span>
          {/if}
        </div>
        <div class="peer-name">{peerUsername}</div>
        <div class="call-timer">{formatDuration(elapsed)}</div>
      </div>
    {/if}
  </div>

  <div class="call-controls">
    <button
      class="call-ctrl-btn"
      class:off={isMuted}
      onclick={onToggleMute}
      title={isMuted ? 'Unmute' : 'Mute'}
    >
      {isMuted ? '\u{1F507}' : '\u{1F3A4}'}
    </button>

    <button
      class="call-ctrl-btn"
      class:active={isVideoOn}
      onclick={onToggleVideo}
      title={isVideoOn ? 'Camera off' : 'Camera on'}
    >
      {'\u{1F4F7}'}
    </button>

    <button
      class="call-ctrl-btn hangup"
      onclick={onHangUp}
      title="Hang up"
    >
      {'\u{1F4DE}'}
    </button>
  </div>
</div>

<style>
  .active-call-overlay {
    position: fixed;
    inset: 0;
    z-index: 900;
    background: rgba(0, 0, 0, 0.85);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  .call-content {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
  }

  /* Video */
  .video-container {
    position: relative;
    width: 100%;
    height: 100%;
    max-width: 900px;
    max-height: 600px;
  }
  .remote-video {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: var(--radius-lg);
  }
  .local-video {
    position: absolute;
    bottom: 16px;
    right: 16px;
    width: 180px;
    height: 135px;
    object-fit: cover;
    border-radius: var(--radius);
    border: 2px solid rgba(255, 255, 255, 0.2);
    transform: scaleX(-1);
  }
  .video-placeholder {
    width: 640px;
    height: 480px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.03);
    border-radius: var(--radius-lg);
  }
  .placeholder-text { color: var(--text-muted); font-size: 14px; }

  /* Audio-only */
  .audio-view {
    text-align: center;
  }
  .peer-avatar-large {
    width: 120px;
    height: 120px;
    border-radius: 50%;
    margin: 0 auto 16px;
    overflow: hidden;
  }
  .peer-avatar-large img { width: 100%; height: 100%; object-fit: cover; }
  .avatar-letter-lg {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--accent);
    color: var(--bg-primary);
    font-weight: 800;
    font-size: 48px;
  }
  .peer-name { font-size: 20px; font-weight: 700; color: #fff; margin-bottom: 8px; }
  .call-timer { font-size: 14px; color: rgba(255, 255, 255, 0.5); font-variant-numeric: tabular-nums; }

  /* Controls */
  .call-controls {
    display: flex;
    gap: 12px;
    padding: 24px;
  }
  .call-ctrl-btn {
    width: 52px;
    height: 52px;
    border-radius: 50%;
    border: none;
    cursor: pointer;
    font-size: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.1);
    color: white;
    transition: all 0.15s;
  }
  .call-ctrl-btn:hover { background: rgba(255, 255, 255, 0.2); }
  .call-ctrl-btn.off { background: rgba(248, 113, 113, 0.3); color: #f87171; }
  .call-ctrl-btn.active { background: rgba(74, 222, 128, 0.2); color: #4ade80; }
  .call-ctrl-btn.hangup {
    background: #dc2626;
    transform: rotate(135deg);
  }
  .call-ctrl-btn.hangup:hover { background: #ef4444; }
</style>
