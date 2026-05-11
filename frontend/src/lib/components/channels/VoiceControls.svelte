<script lang="ts">
  import { voiceStore, type VoiceParticipant } from '$lib/stores/voice.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import WatchPartyPlayer from '$lib/components/channels/WatchPartyPlayer.svelte';

  let videoContainer: HTMLDivElement;
  let selfHandRaised = $state(false);

  async function toggleHand() {
    if (selfHandRaised) {
      await voiceStore.lowerHand();
      selfHandRaised = false;
    } else {
      await voiceStore.raiseHand();
      selfHandRaised = true;
    }
  }

  async function promote(userId: string) {
    try { await voiceStore.promoteUser(userId); } catch {}
  }

  async function demote(userId: string) {
    if (!confirm('Move this speaker to the audience?')) return;
    try { await voiceStore.demoteUser(userId); } catch {}
  }

  function isSelf(p: VoiceParticipant): boolean {
    return p.user_id === auth.user?.id;
  }

  function isHost(p: VoiceParticipant): boolean {
    return p.user_id === voiceStore.hostId;
  }

  const canModerate = $derived(voiceStore.isHost || voiceStore.yourRole === 'speaker');
</script>

{#if voiceStore.isInRoom}
  <WatchPartyPlayer />

  <!-- Video grid (only when someone has video on) -->
  {#if voiceStore.isVideoOn || voiceStore.participants.some(p => p.video || p.screen_share)}
    <div class="video-grid" bind:this={videoContainer}>
      {#if voiceStore.isVideoOn && voiceStore.localStream}
        <div class="video-tile self">
          <video
            autoplay
            muted
            playsinline
            srcObject={voiceStore.localStream}
          ></video>
          <span class="video-label">You</span>
        </div>
      {/if}

      {#each [...voiceStore.remoteStreams.entries()] as [userId, stream]}
        {@const participant = voiceStore.participants.find(p => p.user_id === userId)}
        {#if participant && (participant.video || participant.screen_share)}
          <div class="video-tile">
            <video
              autoplay
              playsinline
              srcObject={stream}
            ></video>
            <span class="video-label">{participant.username}</span>
          </div>
        {/if}
      {/each}
    </div>
  {/if}

  {#if voiceStore.isStageRoom}
    <!-- Stage layout: speakers on top, audience below -->
    <div class="stage-layout">
      <div class="stage-section">
        <div class="stage-section-header">
          <span>Speakers</span>
          <span class="count">{voiceStore.speakers.length}</span>
        </div>
        <div class="stage-avatars">
          {#each voiceStore.speakers as p (p.user_id)}
            <div class="stage-avatar-wrap">
              <div
                class="voice-avatar large"
                class:speaking={voiceStore.speakingUsers.has(p.user_id)}
                class:muted={p.muted}
                title="{p.username}{isHost(p) ? ' (host)' : ''}{p.muted ? ' (muted)' : ''}"
              >
                {#if p.avatar_url}
                  <img src={p.avatar_url} alt={p.username} />
                {:else}
                  <span class="avatar-letter">{p.username[0]?.toUpperCase() || '?'}</span>
                {/if}
                {#if isHost(p)}
                  <span class="status-badge host-badge" title="Host">&#128081;</span>
                {:else if p.muted}
                  <span class="status-badge muted-badge">&#128263;</span>
                {/if}
              </div>
              <div class="stage-name">{p.username}</div>
              {#if voiceStore.isHost && !isHost(p) && !isSelf(p)}
                <button class="stage-action-btn" onclick={() => demote(p.user_id)} title="Move to audience">Step down</button>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      {#if voiceStore.audience.length > 0}
        <div class="stage-section audience">
          <div class="stage-section-header">
            <span>Audience</span>
            <span class="count">{voiceStore.audience.length}</span>
            {#if voiceStore.raisedHands.length > 0}
              <span class="raised-count">&#9995; {voiceStore.raisedHands.length} raised</span>
            {/if}
          </div>
          <div class="stage-avatars small">
            {#each voiceStore.audience as p (p.user_id)}
              <div class="stage-avatar-wrap audience-wrap">
                <div
                  class="voice-avatar"
                  class:hand-raised={p.hand_raised}
                  title="{p.username}{p.hand_raised ? ' (hand raised)' : ''}"
                >
                  {#if p.avatar_url}
                    <img src={p.avatar_url} alt={p.username} />
                  {:else}
                    <span class="avatar-letter">{p.username[0]?.toUpperCase() || '?'}</span>
                  {/if}
                  {#if p.hand_raised}
                    <span class="status-badge hand-badge">&#9995;</span>
                  {/if}
                </div>
                <div class="stage-name small-name">{p.username}</div>
                {#if canModerate && !isSelf(p)}
                  <button class="stage-action-btn promote" onclick={() => promote(p.user_id)} title="Promote to speaker">&uarr; Promote</button>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  {:else}
    <!-- Lounge / Huddle layout: flat avatar bar -->
    <div class="voice-participants-bar">
      {#each voiceStore.participants as p}
        <div
          class="voice-avatar"
          class:speaking={voiceStore.speakingUsers.has(p.user_id)}
          class:muted={p.muted}
          title="{p.username}{p.muted ? ' (muted)' : ''}{p.deafened ? ' (deafened)' : ''}"
        >
          {#if p.avatar_url}
            <img src={p.avatar_url} alt={p.username} />
          {:else}
            <span class="avatar-letter">{p.username[0]?.toUpperCase() || '?'}</span>
          {/if}
          {#if p.muted}
            <span class="status-badge muted-badge">&#128263;</span>
          {/if}
          {#if p.deafened}
            <span class="status-badge deaf-badge">&#128264;</span>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <!-- Control bar -->
  <div class="voice-control-bar">
    <div class="control-info">
      <span class="room-indicator">&#128266;</span>
      <span class="room-name">{voiceStore.activeRoom?.name}</span>
      <span class="participant-count">{voiceStore.participants.length}</span>
    </div>

    <div class="control-buttons">
      {#if voiceStore.isStageRoom && voiceStore.yourRole === 'audience'}
        <button
          class="ctrl-btn"
          class:active={selfHandRaised}
          onclick={toggleHand}
          title={selfHandRaised ? 'Lower hand' : 'Raise hand'}
        >
          &#9995;
        </button>
        <button class="ctrl-btn off locked" disabled title="Audience is muted by the host">
          &#128263;
        </button>
      {:else}
        <button
          class="ctrl-btn"
          class:active={!voiceStore.isMuted}
          class:off={voiceStore.isMuted}
          onclick={() => voiceStore.toggleMute()}
          title={voiceStore.isMuted ? 'Unmute' : 'Mute'}
        >
          {voiceStore.isMuted ? '\u{1F507}' : '\u{1F3A4}'}
        </button>
      {/if}

      <button
        class="ctrl-btn"
        class:off={voiceStore.isDeafened}
        onclick={() => voiceStore.toggleDeafen()}
        title={voiceStore.isDeafened ? 'Undeafen' : 'Deafen'}
      >
        {voiceStore.isDeafened ? '\u{1F515}' : '\u{1F50A}'}
      </button>

      <button
        class="ctrl-btn"
        class:active={voiceStore.isVideoOn}
        onclick={() => voiceStore.toggleVideo()}
        title={voiceStore.isVideoOn ? 'Turn off camera' : 'Turn on camera'}
      >
        {voiceStore.isVideoOn ? '\u{1F4F7}' : '\u{1F4F7}'}
      </button>

      <button
        class="ctrl-btn"
        class:active={voiceStore.isScreenSharing}
        onclick={() => voiceStore.toggleScreenShare()}
        title={voiceStore.isScreenSharing ? 'Stop sharing' : 'Share screen'}
      >
        {'\u{1F4BB}'}
      </button>

      {#if voiceStore.isHost}
        {#if voiceStore.isRecording}
          <button
            class="ctrl-btn recording-btn live"
            onclick={() => voiceStore.stopRecording()}
            title="Stop recording ({Math.floor(voiceStore.recordingElapsed / 60)}:{String(voiceStore.recordingElapsed % 60).padStart(2, '0')})"
            disabled={voiceStore.recordingUploading}
          >
            <span class="rec-dot"></span>
            <span class="rec-time">{Math.floor(voiceStore.recordingElapsed / 60)}:{String(voiceStore.recordingElapsed % 60).padStart(2, '0')}</span>
          </button>
        {:else}
          <button
            class="ctrl-btn recording-btn"
            onclick={() => voiceStore.startRecording()}
            title="Record session"
            disabled={voiceStore.recordingUploading}
          >
            {voiceStore.recordingUploading ? '\u{23F3}' : '\u{23FA}'}
          </button>
        {/if}
      {/if}

      <button
        class="ctrl-btn disconnect"
        onclick={() => voiceStore.leaveRoom()}
        title="Leave"
      >
        {'\u{1F4DE}'}
      </button>
    </div>
  </div>
{/if}

<style>
  /* Video grid */
  .video-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 6px;
    padding: 8px;
    max-height: 300px;
    overflow-y: auto;
    background: rgba(0, 0, 0, 0.3);
    border-bottom: 1px solid var(--border-color);
  }
  .video-tile {
    position: relative;
    border-radius: var(--radius);
    overflow: hidden;
    background: #000;
    aspect-ratio: 16/9;
  }
  .video-tile video {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .video-tile.self video { transform: scaleX(-1); }
  .video-label {
    position: absolute;
    bottom: 4px;
    left: 6px;
    font-size: 10px;
    font-weight: 600;
    color: #fff;
    background: rgba(0, 0, 0, 0.6);
    padding: 1px 6px;
    border-radius: 3px;
  }

  /* Participant avatars */
  .voice-participants-bar {
    display: flex;
    gap: 8px;
    padding: 8px 16px;
    justify-content: center;
    flex-wrap: wrap;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-secondary);
  }

  .voice-avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    overflow: visible;
    position: relative;
    border: 2px solid transparent;
    transition: border-color 0.15s;
  }
  .voice-avatar.speaking {
    border-color: #4ade80;
    box-shadow: 0 0 8px rgba(74, 222, 128, 0.4);
  }
  .voice-avatar.muted { opacity: 0.6; }

  .voice-avatar img {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    object-fit: cover;
  }
  .avatar-letter {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--accent);
    color: var(--bg-primary);
    font-weight: 800;
    font-size: 16px;
    border-radius: 50%;
  }

  .status-badge {
    position: absolute;
    bottom: -2px;
    right: -2px;
    font-size: 10px;
    background: var(--bg-secondary);
    border-radius: 50%;
    padding: 1px;
    line-height: 1;
  }

  /* Control bar */
  .voice-control-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 16px;
    background: var(--bg-tertiary, var(--bg-secondary));
    border-top: 1px solid var(--border-color);
  }

  .control-info {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: #4ade80;
    font-weight: 600;
  }
  .room-indicator { font-size: 14px; }
  .room-name { color: var(--text-primary); }
  .participant-count {
    font-size: 10px;
    background: rgba(255, 255, 255, 0.08);
    padding: 1px 5px;
    border-radius: 8px;
    color: var(--text-muted);
  }

  .control-buttons {
    display: flex;
    gap: 4px;
  }

  .ctrl-btn {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    border: none;
    cursor: pointer;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-secondary);
    transition: all 0.15s;
  }
  .ctrl-btn:hover { background: rgba(255, 255, 255, 0.12); }
  .ctrl-btn.active { background: rgba(74, 222, 128, 0.15); color: #4ade80; }
  .ctrl-btn.off { background: rgba(248, 113, 113, 0.15); color: #f87171; }
  .ctrl-btn.disconnect {
    background: #dc2626;
    color: white;
    transform: rotate(135deg);
  }
  .ctrl-btn.disconnect:hover { background: #ef4444; }
  .ctrl-btn.locked { cursor: not-allowed; opacity: 0.55; }

  /* Stage layout (town_hall rooms) */
  .stage-layout {
    display: flex;
    flex-direction: column;
    gap: 0;
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border-color);
  }
  .stage-section {
    padding: 12px 16px;
  }
  .stage-section.audience {
    border-top: 1px dashed var(--border-color);
    background: rgba(0, 0, 0, 0.12);
  }
  .stage-section-header {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-muted);
    margin-bottom: 8px;
  }
  .stage-section-header .count {
    background: rgba(255, 255, 255, 0.08);
    padding: 1px 6px;
    border-radius: 8px;
    font-size: 9px;
    color: var(--text-secondary);
  }
  .stage-section-header .raised-count {
    margin-left: auto;
    font-size: 10px;
    color: #facc15;
    font-weight: 700;
  }
  .stage-avatars {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    justify-content: center;
  }
  .stage-avatars.small { gap: 8px; }
  .stage-avatar-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    min-width: 60px;
  }
  .voice-avatar.large {
    width: 56px;
    height: 56px;
  }
  .voice-avatar.hand-raised {
    box-shadow: 0 0 0 2px #facc15;
  }
  .stage-name {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-primary);
    max-width: 80px;
    text-align: center;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .stage-name.small-name {
    font-size: 10px;
    color: var(--text-secondary);
    max-width: 60px;
  }
  .stage-action-btn {
    font-size: 10px;
    padding: 2px 8px;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    color: var(--text-secondary);
    cursor: pointer;
    font-family: inherit;
  }
  .stage-action-btn:hover { background: rgba(255, 255, 255, 0.12); color: var(--text-primary); }
  .stage-action-btn.promote { color: #4ade80; border-color: rgba(74, 222, 128, 0.3); }
  .status-badge.host-badge { background: #facc15; font-size: 9px; padding: 2px; }
  .status-badge.hand-badge { background: #facc15; font-size: 9px; padding: 2px; }

  .recording-btn { width: auto; min-width: 36px; padding: 0 10px; gap: 6px; }
  .recording-btn.live {
    background: rgba(248,113,113,0.15);
    color: #f87171;
  }
  .recording-btn .rec-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #f87171;
    box-shadow: 0 0 0 0 rgba(248,113,113,0.6);
    animation: rec-pulse 1.6s ease-out infinite;
  }
  .recording-btn .rec-time {
    font-size: 11px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  @keyframes rec-pulse {
    0% { box-shadow: 0 0 0 0 rgba(248,113,113,0.7); }
    70% { box-shadow: 0 0 0 6px rgba(248,113,113,0); }
    100% { box-shadow: 0 0 0 0 rgba(248,113,113,0); }
  }
</style>
