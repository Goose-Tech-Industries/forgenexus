<script lang="ts">
  /** WhatsApp-style voice message recorder using MediaRecorder API */
  let { onSend }: { onSend: (blob: Blob, duration: number) => void } = $props();

  let recording = $state(false);
  let elapsed = $state(0);
  let mediaRecorder: MediaRecorder | null = null;
  let chunks: BlobPart[] = [];
  let timer: ReturnType<typeof setInterval> | null = null;
  let stream: MediaStream | null = null;
  let error = $state('');

  async function startRecording() {
    error = '';
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
      chunks = [];

      mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) chunks.push(e.data); };
      mediaRecorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        onSend(blob, elapsed);
        cleanup();
      };

      mediaRecorder.start();
      recording = true;
      elapsed = 0;
      timer = setInterval(() => { elapsed++; }, 1000);
    } catch (e: any) {
      error = 'Microphone access denied';
    }
  }

  function stopRecording() {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.stop();
    }
  }

  function cancelRecording() {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.ondataavailable = null;
      mediaRecorder.onstop = null;
      mediaRecorder.stop();
    }
    cleanup();
  }

  function cleanup() {
    recording = false;
    elapsed = 0;
    if (timer) { clearInterval(timer); timer = null; }
    if (stream) { stream.getTracks().forEach(t => t.stop()); stream = null; }
    mediaRecorder = null;
    chunks = [];
  }

  function formatTime(s: number): string {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  }
</script>

<div class="voice-recorder">
  {#if recording}
    <div class="recording-indicator">
      <span class="rec-dot"></span>
      <span class="rec-time">{formatTime(elapsed)}</span>
      <button class="rec-cancel" onclick={cancelRecording} title="Cancel">✕</button>
      <button class="rec-stop" onclick={stopRecording} title="Send">▶</button>
    </div>
  {:else}
    <button class="rec-start" onclick={startRecording} title="Record voice message">🎙️</button>
  {/if}
  {#if error}
    <span class="rec-error">{error}</span>
  {/if}
</div>

<style>
  .voice-recorder { display: flex; align-items: center; gap: 4px; }
  .rec-start { background: none; border: none; font-size: 16px; cursor: pointer; padding: 2px 4px; border-radius: 4px; }
  .rec-start:hover { background: var(--bg-hover); }
  .recording-indicator { display: flex; align-items: center; gap: 6px; padding: 2px 8px; background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.3); border-radius: 12px; }
  .rec-dot { width: 8px; height: 8px; border-radius: 50%; background: #ef4444; animation: rec-pulse 1s ease-in-out infinite; }
  @keyframes rec-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
  .rec-time { font-size: 11px; font-weight: 700; color: #ef4444; font-variant-numeric: tabular-nums; min-width: 30px; }
  .rec-cancel, .rec-stop { background: none; border: none; cursor: pointer; font-size: 12px; padding: 2px 4px; border-radius: 3px; }
  .rec-cancel:hover { background: rgba(239,68,68,0.2); }
  .rec-stop { color: #22c55e; font-size: 14px; }
  .rec-stop:hover { background: rgba(34,197,94,0.2); }
  .rec-error { font-size: 10px; color: #ef4444; }
</style>
