<script lang="ts">
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface FeedEvent {
    type: string;
    description: string;
    user: {
      username: string;
      slug: string;
      avatar_url: string | null;
      username_color: string | null;
    } | null;
    link: string | null;
    inserted_at: string;
  }

  let { events = [], loading = false }: {
    events: FeedEvent[];
    loading?: boolean;
  } = $props();

  const typeIcons: Record<string, string> = {
    post: '\u{1F4AC}',
    thread: '\u{1F4DD}',
    registration: '\u{1F44B}',
    mod_action: '\u{1F6E1}',
    report: '\u{1F6A9}',
  };

  const typeColors: Record<string, string> = {
    post: '#3b82f6',
    thread: '#06b6d4',
    registration: '#4ade80',
    mod_action: '#f97316',
    report: '#f87171',
  };

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 10) return 'just now';
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="live-feed">
  <div class="feed-header">
    <h3>Live Activity</h3>
    <span class="feed-live-dot"></span>
  </div>

  {#if loading}
    <div class="feed-loading">Loading feed...</div>
  {:else if events.length === 0}
    <div class="feed-empty">No recent activity</div>
  {:else}
    <div class="feed-list">
      {#each events as event, i (event.inserted_at + i)}
        <div class="feed-item" style="--type-color: {typeColors[event.type] || 'var(--text-muted)'}">
          <div class="feed-icon">{typeIcons[event.type] || '\u{2022}'}</div>
          <div class="feed-content">
            <div class="feed-text">
              {#if event.user}
                <UsernameDisplay
                  username={event.user.username}
                  color={event.user.username_color}
                  href="/profile/{event.user.slug}"
                  size="small"
                />
              {/if}
              {#if event.link}
                <a href={event.link} class="feed-link">{event.description}</a>
              {:else}
                <span class="feed-desc">{event.description}</span>
              {/if}
            </div>
            <span class="feed-time">{timeAgo(event.inserted_at)}</span>
          </div>
          <div class="feed-type-bar"></div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .live-feed {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .feed-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
  }
  .feed-header h3 {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 0;
  }

  .feed-live-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #4ade80;
    box-shadow: 0 0 6px #4ade80;
    animation: live-pulse 2s ease-in-out infinite;
  }
  @keyframes live-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }

  .feed-list {
    max-height: 360px;
    overflow-y: auto;
  }

  .feed-item {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 8px 16px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    position: relative;
    transition: background 0.1s;
  }
  .feed-item:hover { background: rgba(255, 255, 255, 0.02); }
  .feed-item:last-child { border-bottom: none; }

  .feed-type-bar {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    background: var(--type-color);
    opacity: 0.5;
  }

  .feed-icon {
    font-size: 14px;
    margin-top: 2px;
    flex-shrink: 0;
    width: 20px;
    text-align: center;
  }

  .feed-content {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .feed-text {
    font-size: 12px;
    color: var(--text-secondary);
    display: flex;
    align-items: baseline;
    gap: 4px;
    flex-wrap: wrap;
  }

  .feed-link {
    color: var(--text-primary);
    text-decoration: none;
    font-weight: 500;
  }
  .feed-link:hover { color: var(--accent); }

  .feed-desc { color: var(--text-secondary); }

  .feed-time {
    font-size: 10px;
    color: var(--text-muted);
  }

  .feed-loading, .feed-empty {
    padding: 24px 16px;
    text-align: center;
    font-size: 12px;
    color: var(--text-muted);
  }

  .feed-list::-webkit-scrollbar { width: 4px; }
  .feed-list::-webkit-scrollbar-track { background: transparent; }
  .feed-list::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 2px; }
</style>
