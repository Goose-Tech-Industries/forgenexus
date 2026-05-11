<script lang="ts">
  import { api } from '$lib/api/client';

  let {
    callId,
    callerUsername,
    callerAvatarUrl,
    callType,
    onAnswered,
    onDismissed
  }: {
    callId: string;
    callerUsername: string;
    callerAvatarUrl: string | null;
    callType: string;
    onAnswered: (callId: string) => void;
    onDismissed: () => void;
  } = $props();

  let answering = $state(false);
  let declining = $state(false);

  async function answer() {
    answering = true;
    try {
      await api.answerCall(callId);
      onAnswered(callId);
    } catch { /* silent */ }
    answering = false;
  }

  async function decline() {
    declining = true;
    try {
      await api.declineCall(callId);
      onDismissed();
    } catch { /* silent */ }
    declining = false;
  }
</script>

<div class="incoming-call-overlay">
  <div class="call-card">
    <div class="call-avatar">
      {#if callerAvatarUrl}
        <img src={callerAvatarUrl} alt={callerUsername} />
      {:else}
        <span class="avatar-letter">{callerUsername[0]?.toUpperCase() || '?'}</span>
      {/if}
      <div class="pulse-ring"></div>
      <div class="pulse-ring delay"></div>
    </div>

    <div class="call-info">
      <div class="call-label">Incoming {callType === 'video' ? 'Video' : ''} Call</div>
      <div class="caller-name">{callerUsername}</div>
    </div>

    <div class="call-actions">
      <button class="call-btn decline" onclick={decline} disabled={declining} title="Decline">
        &#128308;
      </button>
      <button class="call-btn answer" onclick={answer} disabled={answering} title="Answer">
        &#128994;
      </button>
    </div>
  </div>
</div>

<style>
  .incoming-call-overlay {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 1000;
    animation: slideIn 0.3s ease-out;
  }

  @keyframes slideIn {
    from { transform: translateX(120%); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }

  .call-card {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
    padding: 20px 24px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    min-width: 240px;
  }

  .call-avatar {
    width: 64px;
    height: 64px;
    border-radius: 50%;
    overflow: visible;
    position: relative;
  }
  .call-avatar img {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    object-fit: cover;
    position: relative;
    z-index: 1;
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
    font-size: 24px;
    border-radius: 50%;
    position: relative;
    z-index: 1;
  }

  .pulse-ring {
    position: absolute;
    inset: -8px;
    border-radius: 50%;
    border: 2px solid #4ade80;
    animation: pulse 2s ease-out infinite;
  }
  .pulse-ring.delay { animation-delay: 1s; }

  @keyframes pulse {
    0% { transform: scale(0.8); opacity: 0.8; }
    100% { transform: scale(1.4); opacity: 0; }
  }

  .call-info { text-align: center; }
  .call-label {
    font-size: 11px;
    text-transform: uppercase;
    font-weight: 700;
    color: #4ade80;
    letter-spacing: 0.05em;
    margin-bottom: 4px;
  }
  .caller-name {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .call-actions {
    display: flex;
    gap: 16px;
  }

  .call-btn {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    border: none;
    cursor: pointer;
    font-size: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.15s;
  }
  .call-btn:hover { transform: scale(1.1); }
  .call-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .call-btn.decline { background: #dc2626; }
  .call-btn.answer { background: #16a34a; }
</style>
