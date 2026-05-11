<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { socketStore } from '$lib/stores/socket.svelte';
  import { voiceStore, type VoiceRoom } from '$lib/stores/voice.svelte';

  interface UpcomingRoom extends VoiceRoom {
    scheduled_at?: string | null;
    description?: string | null;
  }

  interface Clip {
    id: string;
    title: string | null;
    created_by_username: string | null;
    duration_ms: number;
    view_count: number;
    inserted_at: string;
  }

  let liveRooms = $state<VoiceRoom[]>([]);
  let upcoming = $state<UpcomingRoom[]>([]);
  let clips = $state<Clip[]>([]);
  let loading = $state(true);
  let joining = $state<string | null>(null);
  let pollTimer: ReturnType<typeof setInterval> | null = null;

  let featured = $derived(liveRooms[0] ?? null);
  let liveGrid = $derived(liveRooms.slice(1));
  let totalViewers = $derived(liveRooms.reduce((sum, r) => sum + (r.participant_count || 0), 0));

  async function refresh() {
    try {
      const [roomsRes, upcomingRes, clipsRes] = await Promise.allSettled([
        api.getVoiceRooms(),
        api.request('/voice/rooms/upcoming'),
        api.request('/voice/clips/recent')
      ]);

      if (roomsRes.status === 'fulfilled') {
        const all = (roomsRes.value.rooms || []) as VoiceRoom[];
        liveRooms = all
          .filter(r => (r.participant_count || 0) > 0 && !r.is_private)
          .sort((a, b) => (b.participant_count || 0) - (a.participant_count || 0));
      }
      if (upcomingRes.status === 'fulfilled') {
        upcoming = (upcomingRes.value.rooms || []) as UpcomingRoom[];
      }
      if (clipsRes.status === 'fulfilled') {
        clips = (clipsRes.value.clips || []) as Clip[];
      }
    } finally {
      loading = false;
    }
  }

  async function watch(room: VoiceRoom) {
    if (!auth.user) {
      goto(`/auth/login?next=${encodeURIComponent('/live')}`);
      return;
    }
    const socket = socketStore.getSocket();
    if (!socket) {
      goto('/live');
      return;
    }
    joining = room.id;
    try {
      await voiceStore.joinRoom(room.id, socket);
      goto('/chat');
    } finally {
      joining = null;
    }
  }

  function formatDuration(ms: number): string {
    const s = Math.round(ms / 1000);
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    return `${m}m ${s % 60}s`;
  }

  function formatScheduled(iso: string | null | undefined): string {
    if (!iso) return '';
    const d = new Date(iso);
    const now = new Date();
    const diffMs = d.getTime() - now.getTime();
    const diffH = Math.round(diffMs / 3_600_000);
    if (diffH < 1) return 'Starting soon';
    if (diffH < 24) return `in ${diffH}h`;
    const diffD = Math.round(diffH / 24);
    return `in ${diffD}d`;
  }

  onMount(() => {
    refresh();
    pollTimer = setInterval(refresh, 15_000);
  });

  onDestroy(() => {
    if (pollTimer) clearInterval(pollTimer);
  });
</script>

<svelte:head>
  <title>Calamity TV — Live Now</title>
  <meta name="description" content="Live voice rooms, streams and clips on Calamity TV." />
</svelte:head>

<div class="calamity-page">
  <header class="ct-header">
    <div class="ct-brand">
      <span class="ct-logo-mark">◆</span>
      <div class="ct-logo-text">
        <span class="ct-title">CALAMITY <span class="ct-title-accent">TV</span></span>
        <span class="ct-tagline">Live voice rooms · streams · clips</span>
      </div>
    </div>
    <div class="ct-stats">
      <div class="ct-stat">
        <span class="ct-stat-dot live"></span>
        <span class="ct-stat-num">{liveRooms.length}</span>
        <span class="ct-stat-label">live</span>
      </div>
      <div class="ct-stat">
        <span class="ct-stat-num">{totalViewers}</span>
        <span class="ct-stat-label">in rooms</span>
      </div>
    </div>
  </header>

  {#if loading}
    <div class="ct-loading">Loading the scene…</div>
  {:else if liveRooms.length === 0 && upcoming.length === 0 && clips.length === 0}
    <div class="ct-empty">
      <h2>The stage is quiet</h2>
      <p>No one is live right now. Check back soon — or <a href="/live">start a room</a>.</p>
    </div>
  {:else}
    {#if featured}
      <section class="ct-featured">
        <div class="ct-featured-card" onclick={() => watch(featured)} role="button" tabindex="0"
             onkeydown={(e) => e.key === 'Enter' && watch(featured)}>
          <div class="ct-featured-inner">
            <div class="ct-live-badge"><span class="dot"></span> LIVE</div>
            <h2 class="ct-featured-title">{featured.name}</h2>
            {#if featured.category_name}
              <div class="ct-featured-cat">{featured.category_name}</div>
            {/if}
            <div class="ct-featured-meta">
              <span class="ct-viewers">👥 {featured.participant_count} in room</span>
              {#if featured.participants?.length}
                <div class="ct-avatars">
                  {#each featured.participants.slice(0, 5) as p (p.user_id)}
                    <div class="ct-avatar" title={p.username}>
                      {#if p.avatar_url}
                        <img src={p.avatar_url} alt={p.username} />
                      {:else}
                        <span>{p.username?.[0]?.toUpperCase() ?? '?'}</span>
                      {/if}
                    </div>
                  {/each}
                  {#if featured.participants.length > 5}
                    <div class="ct-avatar more">+{featured.participants.length - 5}</div>
                  {/if}
                </div>
              {/if}
            </div>
            <button class="ct-watch-btn" disabled={joining === featured.id}>
              {joining === featured.id ? 'Joining…' : 'Watch now'}
            </button>
          </div>
        </div>
      </section>
    {/if}

    {#if liveGrid.length > 0}
      <section class="ct-section">
        <header class="ct-section-head">
          <h3>Live now</h3>
          <a href="/live" class="ct-see-all">See all →</a>
        </header>
        <div class="ct-grid">
          {#each liveGrid as room (room.id)}
            <article class="ct-card" onclick={() => watch(room)} role="button" tabindex="0"
                     onkeydown={(e) => e.key === 'Enter' && watch(room)}>
              <div class="ct-card-thumb">
                <span class="ct-live-badge small"><span class="dot"></span>LIVE</span>
                <span class="ct-viewers-chip">👥 {room.participant_count}</span>
              </div>
              <div class="ct-card-body">
                <div class="ct-card-title">{room.name}</div>
                {#if room.category_name}
                  <div class="ct-card-cat">{room.category_name}</div>
                {/if}
              </div>
            </article>
          {/each}
        </div>
      </section>
    {/if}

    {#if upcoming.length > 0}
      <section class="ct-section">
        <header class="ct-section-head">
          <h3>Upcoming shows</h3>
        </header>
        <div class="ct-upcoming">
          {#each upcoming as room (room.id)}
            <div class="ct-upcoming-item">
              <div class="ct-upcoming-when">{formatScheduled(room.scheduled_at)}</div>
              <div class="ct-upcoming-title">{room.name}</div>
              {#if room.description}
                <div class="ct-upcoming-desc">{room.description}</div>
              {/if}
            </div>
          {/each}
        </div>
      </section>
    {/if}

    {#if clips.length > 0}
      <section class="ct-section">
        <header class="ct-section-head">
          <h3>Recent clips</h3>
          <a href="/clips" class="ct-see-all">All clips →</a>
        </header>
        <div class="ct-clips">
          {#each clips.slice(0, 8) as clip (clip.id)}
            <a class="ct-clip" href="/clips#{clip.id}">
              <div class="ct-clip-thumb">
                <span class="ct-clip-duration">{formatDuration(clip.duration_ms)}</span>
              </div>
              <div class="ct-clip-title">{clip.title || 'Untitled clip'}</div>
              <div class="ct-clip-meta">
                <span>{clip.created_by_username ?? 'unknown'}</span>
                <span>· {clip.view_count} views</span>
              </div>
            </a>
          {/each}
        </div>
      </section>
    {/if}
  {/if}
</div>

<style>
  .calamity-page {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1.5rem 1.25rem 4rem;
    color: var(--text-primary, #f5f5f5);
  }

  .ct-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1.5rem;
    padding: 1.25rem 1.5rem;
    margin-bottom: 1.75rem;
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.08), rgba(99, 102, 241, 0.08));
    border: 1px solid var(--border-color, #2a2a2a);
    border-radius: 16px;
  }

  .ct-brand {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .ct-logo-mark {
    font-size: 2.5rem;
    color: #ef4444;
    text-shadow: 0 0 20px rgba(239, 68, 68, 0.6);
    animation: pulse 2.5s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.6; }
  }

  .ct-logo-text {
    display: flex;
    flex-direction: column;
  }

  .ct-title {
    font-size: 1.75rem;
    font-weight: 900;
    letter-spacing: 0.08em;
    line-height: 1;
  }

  .ct-title-accent {
    color: #ef4444;
  }

  .ct-tagline {
    font-size: 0.8rem;
    color: var(--text-muted, #737373);
    margin-top: 0.25rem;
    letter-spacing: 0.02em;
  }

  .ct-stats {
    display: flex;
    gap: 1.75rem;
  }

  .ct-stat {
    display: flex;
    align-items: baseline;
    gap: 0.4rem;
  }

  .ct-stat-dot.live {
    width: 8px;
    height: 8px;
    background: #ef4444;
    border-radius: 50%;
    animation: pulse 1.5s ease-in-out infinite;
    align-self: center;
  }

  .ct-stat-num {
    font-size: 1.5rem;
    font-weight: 800;
  }

  .ct-stat-label {
    font-size: 0.8rem;
    color: var(--text-muted, #737373);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .ct-loading, .ct-empty {
    text-align: center;
    padding: 4rem 1rem;
    color: var(--text-muted, #737373);
  }
  .ct-empty h2 { color: var(--text-primary, #f5f5f5); margin-bottom: 0.5rem; }
  .ct-empty a { color: var(--accent, #6366f1); }

  .ct-featured {
    margin-bottom: 2rem;
  }

  .ct-featured-card {
    position: relative;
    border-radius: 16px;
    padding: 2.5rem;
    min-height: 280px;
    background:
      radial-gradient(ellipse at top right, rgba(239, 68, 68, 0.25), transparent 60%),
      radial-gradient(ellipse at bottom left, rgba(99, 102, 241, 0.2), transparent 60%),
      linear-gradient(135deg, #1a1a1a, #0f0f0f);
    border: 1px solid rgba(239, 68, 68, 0.3);
    cursor: pointer;
    transition: transform 0.2s, border-color 0.2s;
    overflow: hidden;
  }

  .ct-featured-card:hover {
    transform: translateY(-2px);
    border-color: rgba(239, 68, 68, 0.6);
  }

  .ct-live-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    background: #ef4444;
    color: white;
    padding: 0.3rem 0.7rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    margin-bottom: 1rem;
  }
  .ct-live-badge.small { font-size: 0.65rem; padding: 0.2rem 0.5rem; }
  .ct-live-badge .dot {
    width: 6px; height: 6px; background: white; border-radius: 50%;
    animation: pulse 1.2s ease-in-out infinite;
  }

  .ct-featured-title {
    font-size: 2rem;
    font-weight: 800;
    margin: 0 0 0.25rem;
  }

  .ct-featured-cat {
    color: var(--text-secondary, #a3a3a3);
    font-size: 0.95rem;
    margin-bottom: 1rem;
  }

  .ct-featured-meta {
    display: flex;
    align-items: center;
    gap: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .ct-viewers {
    color: var(--text-secondary, #a3a3a3);
    font-size: 0.9rem;
  }

  .ct-avatars {
    display: flex;
  }
  .ct-avatar {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    border: 2px solid #0f0f0f;
    margin-left: -8px;
    background: var(--bg-tertiary, #252525);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 600;
  }
  .ct-avatar:first-child { margin-left: 0; }
  .ct-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .ct-avatar.more { background: var(--accent, #6366f1); color: white; }

  .ct-watch-btn {
    background: #ef4444;
    color: white;
    border: none;
    padding: 0.7rem 1.75rem;
    border-radius: 8px;
    font-weight: 700;
    font-size: 0.95rem;
    cursor: pointer;
    transition: background 0.15s;
  }
  .ct-watch-btn:hover { background: #dc2626; }
  .ct-watch-btn:disabled { opacity: 0.6; cursor: wait; }

  .ct-section {
    margin-bottom: 2.5rem;
  }

  .ct-section-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    margin-bottom: 1rem;
  }
  .ct-section-head h3 {
    font-size: 1.25rem;
    font-weight: 700;
    margin: 0;
  }
  .ct-see-all {
    color: var(--text-secondary, #a3a3a3);
    font-size: 0.85rem;
    text-decoration: none;
  }
  .ct-see-all:hover { color: var(--accent, #6366f1); }

  .ct-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 1rem;
  }

  .ct-card {
    background: var(--bg-card, #1e1e1e);
    border: 1px solid var(--border-color, #2a2a2a);
    border-radius: 12px;
    overflow: hidden;
    cursor: pointer;
    transition: transform 0.15s, border-color 0.15s;
  }
  .ct-card:hover {
    transform: translateY(-2px);
    border-color: var(--accent, #6366f1);
  }

  .ct-card-thumb {
    aspect-ratio: 16 / 9;
    background: linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(139, 92, 246, 0.15));
    position: relative;
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 0.6rem;
  }
  .ct-viewers-chip {
    background: rgba(0, 0, 0, 0.6);
    color: white;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .ct-card-body { padding: 0.8rem 1rem 1rem; }
  .ct-card-title {
    font-weight: 600;
    margin-bottom: 0.2rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ct-card-cat {
    font-size: 0.8rem;
    color: var(--text-muted, #737373);
  }

  .ct-upcoming {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 0.75rem;
  }
  .ct-upcoming-item {
    background: var(--bg-card, #1e1e1e);
    border: 1px solid var(--border-color, #2a2a2a);
    border-radius: 10px;
    padding: 0.9rem 1.1rem;
  }
  .ct-upcoming-when {
    font-size: 0.75rem;
    color: var(--accent, #6366f1);
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    margin-bottom: 0.3rem;
  }
  .ct-upcoming-title { font-weight: 600; margin-bottom: 0.2rem; }
  .ct-upcoming-desc {
    font-size: 0.85rem;
    color: var(--text-muted, #737373);
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .ct-clips {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 0.75rem;
  }
  .ct-clip {
    text-decoration: none;
    color: inherit;
    display: block;
    background: var(--bg-card, #1e1e1e);
    border: 1px solid var(--border-color, #2a2a2a);
    border-radius: 10px;
    overflow: hidden;
    transition: transform 0.15s, border-color 0.15s;
  }
  .ct-clip:hover {
    transform: translateY(-2px);
    border-color: var(--accent, #6366f1);
  }
  .ct-clip-thumb {
    aspect-ratio: 16 / 9;
    background: linear-gradient(135deg, rgba(139, 92, 246, 0.2), rgba(236, 72, 153, 0.15));
    position: relative;
  }
  .ct-clip-duration {
    position: absolute;
    bottom: 0.4rem;
    right: 0.4rem;
    background: rgba(0, 0, 0, 0.7);
    color: white;
    padding: 0.15rem 0.4rem;
    border-radius: 3px;
    font-size: 0.7rem;
    font-weight: 600;
  }
  .ct-clip-title {
    padding: 0.6rem 0.8rem 0.2rem;
    font-size: 0.9rem;
    font-weight: 600;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ct-clip-meta {
    padding: 0 0.8rem 0.8rem;
    font-size: 0.75rem;
    color: var(--text-muted, #737373);
    display: flex;
    gap: 0.3rem;
  }

  @media (max-width: 640px) {
    .ct-header { flex-direction: column; align-items: flex-start; }
    .ct-featured-card { padding: 1.5rem; min-height: auto; }
    .ct-featured-title { font-size: 1.4rem; }
  }
</style>
