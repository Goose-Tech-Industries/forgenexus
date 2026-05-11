<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { api } from '$lib/api/client';
  import { voiceStore, type VoiceRoom } from '$lib/stores/voice.svelte';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';

  interface RecordingSummary {
    id: string;
    room_id: string;
    title: string | null;
    audio_url: string;
    duration_seconds: number | null;
    started_at: string;
    transcript: string | null;
    transcript_status: string;
    participant_count: number;
  }

  let rooms = $state<VoiceRoom[]>([]);
  let loading = $state(true);
  let error = $state('');
  let pollTimer: ReturnType<typeof setInterval> | null = null;
  let joining = $state<string | null>(null);
  let expandedRoom = $state<string | null>(null);
  let roomRecordings = $state<Record<string, RecordingSummary[]>>({});
  let recordingsLoading = $state<string | null>(null);

  async function joinRoom(room: VoiceRoom) {
    const socket = socketStore.getSocket();
    if (!socket) {
      error = 'Not connected — please log in first.';
      return;
    }
    joining = room.id;
    try {
      await voiceStore.joinRoom(room.id, socket);
      goto('/chat');
    } catch {
      joining = null;
    }
  }

  async function refresh() {
    try {
      const data = await api.getVoiceRooms();
      rooms = (data.rooms || []) as VoiceRoom[];
    } catch (err: any) {
      error = err?.error || 'Failed to load rooms.';
    }
    loading = false;
  }

  onMount(() => {
    refresh();
    // Live-ish polling. For true real-time we'd subscribe to a global voice:activity
    // topic from a PubSub broadcast in RoomServer — deferred follow-up.
    pollTimer = setInterval(refresh, 8000);
  });

  onDestroy(() => {
    if (pollTimer) clearInterval(pollTimer);
  });

  const liveRooms = $derived(rooms.filter((r) => (r.participant_count ?? 0) > 0));
  const idleRooms = $derived(rooms.filter((r) => (r.participant_count ?? 0) === 0));
  const totalLiveUsers = $derived(liveRooms.reduce((n, r) => n + (r.participant_count ?? 0), 0));

  function roomTypeLabel(type: string): string {
    switch (type) {
      case 'lounge': return 'Lounge';
      case 'huddle': return 'Huddle';
      case 'town_hall': return 'Stage';
      default: return type;
    }
  }

  function roomTypeEmoji(type: string): string {
    switch (type) {
      case 'town_hall': return '🎤';
      case 'huddle': return '🎧';
      default: return '🔊';
    }
  }

  async function toggleRecordings(room: VoiceRoom, ev: MouseEvent) {
    ev.stopPropagation();
    if (expandedRoom === room.id) {
      expandedRoom = null;
      return;
    }
    expandedRoom = room.id;
    if (!roomRecordings[room.id]) {
      recordingsLoading = room.id;
      try {
        const data = await api.getRoomRecordings(room.slug);
        roomRecordings = { ...roomRecordings, [room.id]: data.recordings || [] };
      } catch {
        roomRecordings = { ...roomRecordings, [room.id]: [] };
      }
      recordingsLoading = null;
    }
  }

  function formatDuration(seconds: number | null): string {
    if (!seconds) return '—';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m ${s}s`;
    return `${s}s`;
  }

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString();
  }

  function transcriptStatusLabel(status: string): string {
    switch (status) {
      case 'ready': return 'Transcribed';
      case 'processing': return 'Transcribing…';
      case 'pending': return 'Queued';
      case 'failed': return 'Transcribe failed';
      case 'disabled': return 'No transcript';
      default: return status;
    }
  }
</script>

<svelte:head>
  <title>Live Now — ForgeNexus</title>
</svelte:head>

<div class="page">
  <div class="hero">
    <div>
      <h1>
        <span class="dot"></span>
        Live Now
      </h1>
      <p class="sub">
        {#if totalLiveUsers > 0}
          <strong>{totalLiveUsers}</strong> {totalLiveUsers === 1 ? 'person is' : 'people are'}
          in <strong>{liveRooms.length}</strong> {liveRooms.length === 1 ? 'room' : 'rooms'}
        {:else}
          No one is live right now. Be the first to start a room.
        {/if}
      </p>
    </div>
    <button class="refresh-btn" onclick={refresh} title="Refresh">↻</button>
  </div>

  {#if loading}
    <p class="muted center">Loading...</p>
  {:else if error}
    <div class="error">{error}</div>
  {:else}
    {#if liveRooms.length > 0}
      <div class="section-label">
        <span class="label-dot"></span>
        Active rooms
      </div>
      <div class="room-grid">
        {#each liveRooms as room (room.id)}
          <div class="room-card-wrap">
          <div
            class="room-card live"
            role="button"
            tabindex="0"
            onclick={() => joinRoom(room)}
            onkeydown={(e) => { if (e.key === 'Enter') joinRoom(room); }}
            class:disabled={joining === room.id}
          >
            <div class="card-head">
              <span class="type-emoji">{roomTypeEmoji(room.type)}</span>
              <span class="type-label">{roomTypeLabel(room.type)}</span>
              <span class="live-badge">
                <span class="live-dot"></span>
                LIVE
              </span>
            </div>
            <div class="room-title">{room.name}</div>
            {#if room.category_name}<div class="room-category">{room.category_name}</div>{/if}
            <div class="participant-stats">
              <span class="count">{room.participant_count}</span>
              <span class="label">{room.participant_count === 1 ? 'listener' : 'people'}</span>
              <span class="capacity">/ {room.max_participants}</span>
            </div>
            {#if room.participants && room.participants.length > 0}
              <div class="avatar-stack">
                {#each room.participants.slice(0, 5) as p}
                  <div class="mini-avatar" title={p.username}>
                    {#if p.avatar_url}
                      <img src={p.avatar_url} alt={p.username} />
                    {:else}
                      {p.username[0]?.toUpperCase() || '?'}
                    {/if}
                  </div>
                {/each}
                {#if room.participants.length > 5}
                  <div class="mini-avatar more">+{room.participants.length - 5}</div>
                {/if}
              </div>
            {/if}
          </div>
          <button class="recordings-toggle" onclick={(ev) => toggleRecordings(room, ev)}>
            {expandedRoom === room.id ? '▼' : '▶'} Past recordings
          </button>
          </div>

          {#if expandedRoom === room.id}
            <div class="recordings-panel">
              {#if recordingsLoading === room.id}
                <p class="muted">Loading recordings...</p>
              {:else if (roomRecordings[room.id] || []).length === 0}
                <p class="muted">No recordings saved for this room yet.</p>
              {:else}
                {#each roomRecordings[room.id] as rec (rec.id)}
                  <div class="rec-row">
                    <div class="rec-meta">
                      <div class="rec-title">{rec.title || 'Untitled session'}</div>
                      <div class="rec-sub">
                        {formatDate(rec.started_at)} · {formatDuration(rec.duration_seconds)} · {rec.participant_count} participants
                      </div>
                      <div class="rec-status">{transcriptStatusLabel(rec.transcript_status)}</div>
                    </div>
                    <audio controls src={rec.audio_url} preload="none"></audio>
                    {#if rec.transcript}
                      <details class="rec-transcript">
                        <summary>Transcript preview</summary>
                        <p>{rec.transcript}</p>
                      </details>
                    {/if}
                  </div>
                {/each}
              {/if}
            </div>
          {/if}
        {/each}
      </div>
    {/if}

    {#if idleRooms.length > 0}
      <div class="section-label muted-label">Available rooms</div>
      <div class="room-grid">
        {#each idleRooms as room (room.id)}
          <div class="room-card-wrap">
          <div
            class="room-card"
            role="button"
            tabindex="0"
            onclick={() => joinRoom(room)}
            onkeydown={(e) => { if (e.key === 'Enter') joinRoom(room); }}
            class:disabled={joining === room.id}
          >
            <div class="card-head">
              <span class="type-emoji">{roomTypeEmoji(room.type)}</span>
              <span class="type-label">{roomTypeLabel(room.type)}</span>
            </div>
            <div class="room-title">{room.name}</div>
            {#if room.category_name}<div class="room-category">{room.category_name}</div>{/if}
            <div class="participant-stats">
              <span class="empty-label">Empty — start the conversation</span>
            </div>
          </div>
          <button class="recordings-toggle" onclick={(ev) => toggleRecordings(room, ev)}>
            {expandedRoom === room.id ? '▼' : '▶'} Past recordings
          </button>
          </div>

          {#if expandedRoom === room.id}
            <div class="recordings-panel">
              {#if recordingsLoading === room.id}
                <p class="muted">Loading recordings...</p>
              {:else if (roomRecordings[room.id] || []).length === 0}
                <p class="muted">No recordings saved for this room yet.</p>
              {:else}
                {#each roomRecordings[room.id] as rec (rec.id)}
                  <div class="rec-row">
                    <div class="rec-meta">
                      <div class="rec-title">{rec.title || 'Untitled session'}</div>
                      <div class="rec-sub">
                        {formatDate(rec.started_at)} · {formatDuration(rec.duration_seconds)} · {rec.participant_count} participants
                      </div>
                      <div class="rec-status">{transcriptStatusLabel(rec.transcript_status)}</div>
                    </div>
                    <audio controls src={rec.audio_url} preload="none"></audio>
                    {#if rec.transcript}
                      <details class="rec-transcript">
                        <summary>Transcript preview</summary>
                        <p>{rec.transcript}</p>
                      </details>
                    {/if}
                  </div>
                {/each}
              {/if}
            </div>
          {/if}
        {/each}
      </div>
    {/if}

    {#if rooms.length === 0}
      <p class="muted center">No voice rooms have been created yet.</p>
    {/if}
  {/if}
</div>

<style>
  .page { max-width: 1100px; margin: 0 auto; padding: 24px 16px 80px; }

  .hero { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; margin-bottom: 28px; }
  .hero h1 { display: flex; align-items: center; gap: 12px; font-size: 28px; font-weight: 800; color: var(--text-primary); margin: 0; }
  .hero .dot {
    width: 14px; height: 14px; border-radius: 50%;
    background: #f87171;
    box-shadow: 0 0 0 0 rgba(248,113,113,0.6);
    animation: pulse 1.8s ease-out infinite;
  }
  @keyframes pulse {
    0% { box-shadow: 0 0 0 0 rgba(248,113,113,0.7); }
    70% { box-shadow: 0 0 0 12px rgba(248,113,113,0); }
    100% { box-shadow: 0 0 0 0 rgba(248,113,113,0); }
  }
  .sub { font-size: 13px; color: var(--text-muted); margin-top: 6px; }
  .sub strong { color: var(--accent); font-variant-numeric: tabular-nums; }
  .refresh-btn { width: 36px; height: 36px; border-radius: 50%; background: var(--bg-card); border: 1px solid var(--border-color); color: var(--text-secondary); cursor: pointer; font-size: 16px; }
  .refresh-btn:hover { background: var(--bg-hover); color: var(--text-primary); }

  .section-label { display: flex; align-items: center; gap: 8px; font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.08em; color: #f87171; margin: 24px 0 12px; }
  .section-label.muted-label { color: var(--text-muted); }
  .label-dot { width: 8px; height: 8px; border-radius: 50%; background: #f87171; }

  .room-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }

  .room-card-wrap { display: flex; flex-direction: column; }
  .room-card { text-align: left; padding: 16px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg) var(--radius-lg) 0 0; cursor: pointer; transition: transform 0.15s, border-color 0.15s, background 0.15s; font-family: inherit; color: inherit; }
  .room-card:hover { transform: translateY(-2px); border-color: var(--accent); background: var(--bg-hover); }
  .room-card.live { border-color: rgba(248,113,113,0.4); background: linear-gradient(180deg, rgba(248,113,113,0.05), var(--bg-card)); }
  .room-card.live:hover { border-color: #f87171; }
  .room-card.disabled { opacity: 0.6; cursor: wait; }
  .room-card:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

  .card-head { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; font-size: 11px; color: var(--text-muted); font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; }
  .type-emoji { font-size: 16px; }
  .type-label { }
  .live-badge { margin-left: auto; display: inline-flex; align-items: center; gap: 4px; color: #f87171; background: rgba(248,113,113,0.1); padding: 2px 8px; border-radius: 10px; font-size: 10px; letter-spacing: 0.08em; }
  .live-dot { width: 6px; height: 6px; border-radius: 50%; background: #f87171; animation: pulse 1.6s ease-out infinite; }

  .room-title { font-size: 16px; font-weight: 700; color: var(--text-primary); margin-bottom: 2px; }
  .room-category { font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }
  .participant-stats { display: flex; align-items: baseline; gap: 6px; font-size: 12px; color: var(--text-secondary); margin-top: 8px; }
  .participant-stats .count { font-size: 18px; font-weight: 800; color: var(--text-primary); font-variant-numeric: tabular-nums; }
  .participant-stats .label { font-size: 11px; color: var(--text-muted); }
  .participant-stats .capacity { font-size: 11px; color: var(--text-muted); margin-left: auto; }
  .empty-label { font-size: 11px; color: var(--text-muted); font-style: italic; }

  .avatar-stack { display: flex; margin-top: 10px; }
  .mini-avatar { width: 28px; height: 28px; border-radius: 50%; border: 2px solid var(--bg-card); margin-left: -8px; background: var(--accent); color: var(--bg-primary); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; overflow: hidden; }
  .mini-avatar:first-child { margin-left: 0; }
  .mini-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .mini-avatar.more { background: var(--bg-tertiary); color: var(--text-secondary); font-size: 10px; }

  .recordings-toggle {
    display: block;
    width: 100%;
    padding: 6px 12px;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--border-color);
    border-top: none;
    border-radius: 0 0 var(--radius-lg) var(--radius-lg);
    color: var(--text-muted);
    cursor: pointer;
    font-size: 10px;
    font-weight: 700;
    text-align: left;
    font-family: inherit;
  }
  .recordings-toggle:hover { color: var(--text-primary); background: rgba(255, 255, 255, 0.08); }

  .recordings-panel { grid-column: 1 / -1; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px; margin-top: -4px; }
  .rec-row { padding: 10px 0; border-bottom: 1px solid var(--border-color); }
  .rec-row:last-child { border-bottom: none; }
  .rec-meta { margin-bottom: 6px; }
  .rec-title { font-size: 13px; font-weight: 700; color: var(--text-primary); }
  .rec-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .rec-status { display: inline-block; margin-top: 4px; padding: 1px 8px; font-size: 10px; font-weight: 700; border-radius: 10px; background: rgba(156,163,175,0.15); color: #9ca3af; text-transform: uppercase; letter-spacing: 0.05em; }
  .rec-row audio { width: 100%; margin-top: 6px; }
  .rec-transcript { margin-top: 8px; font-size: 12px; color: var(--text-secondary); }
  .rec-transcript summary { cursor: pointer; font-weight: 600; color: var(--text-primary); }
  .rec-transcript p { margin: 6px 0 0; line-height: 1.5; white-space: pre-wrap; }
  .muted { color: var(--text-muted); font-size: 12px; text-align: center; }

  .muted { color: var(--text-muted); }
  .center { text-align: center; padding: 40px 0; }
  .error { padding: 12px; background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.3); border-radius: var(--radius); color: #f87171; }
</style>
