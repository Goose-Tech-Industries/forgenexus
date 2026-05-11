<script lang="ts">
  import { api } from '$lib/api/client';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface OnlineUser {
    id: string;
    username: string;
    slug: string;
    avatar_url: string | null;
    username_color: string | null;
    username_effect: string | null;
    primary_group: {
      name: string;
      slug: string;
      color: string;
    } | null;
    last_seen_at: string;
    presence_status: string | null;
    custom_status_text: string | null;
  }

  interface OnlineData {
    users: OnlineUser[];
    stats: {
      members: number;
      guests: number;
      total: number;
      record_count: number;
      record_date: string | null;
    };
    groups: Array<{
      name: string;
      slug: string;
      color: string;
    }>;
  }

  let data = $state<OnlineData | null>(null);
  let loading = $state(true);
  let expanded = $state(true);
  let timeRange = $state<'15m' | '1h' | '24h'>('15m');

  $effect(() => {
    loadOnline();
    // Refresh every 30 seconds
    const interval = setInterval(loadOnline, 30000);
    return () => clearInterval(interval);
  });

  async function loadOnline() {
    try {
      const result = await api.getOnlineUsers();
      data = result;
    } catch {
      // Non-critical
    }
    loading = false;
  }

  function toggleExpand() {
    expanded = !expanded;
  }

  // Group legend — collect unique groups from online users
  let groupLegend = $derived.by(() => {
    if (!data?.groups) return [];
    return data.groups;
  });
</script>

<div class="whos-online">
  <button class="online-header" onclick={toggleExpand} aria-expanded={expanded}>
    <div class="online-title-row">
      <h3>
        <span class="online-dot"></span>
        Who's Online
        {#if data}
          <span class="online-count">
            {data.stats.members} {data.stats.members === 1 ? 'Member' : 'Members'}{#if data.stats.guests > 0}, {data.stats.guests} {data.stats.guests === 1 ? 'Guest' : 'Guests'}{/if}
          </span>
        {/if}
      </h3>
      <span class="collapse-icon" class:rotated={!expanded}>&#9660;</span>
    </div>
  </button>

  {#if expanded}
    <div class="online-body">
      {#if loading}
        <div class="online-loading">Loading...</div>
      {:else if data}
        <!-- Online user list -->
        {#if data.users.length > 0}
          <div class="online-users-list">
            {#each data.users as user (user.id)}
              <a href="/profile/{user.slug}" class="online-user" title="{user.username}">
                <UsernameDisplay
                  username={user.username}
                  color={user.username_color}
                  effect={user.username_effect}
                  size="small"
                />
              </a>
              {#if data.users.indexOf(user) < data.users.length - 1}
                <span class="user-separator">,</span>
              {/if}
            {/each}
          </div>
        {:else}
          <div class="no-users">No members currently online</div>
        {/if}

        <!-- Group legend -->
        {#if groupLegend.length > 0}
          <div class="group-legend">
            {#each groupLegend as group}
              <span class="legend-item">
                <span class="legend-dot" style="background: {group.color}"></span>
                <span class="legend-label">{group.name}</span>
              </span>
            {/each}
            <span class="legend-item">
              <span class="legend-dot" style="background: var(--text-primary)"></span>
              <span class="legend-label">Member</span>
            </span>
          </div>
        {/if}

        <!-- Stats bar -->
        <div class="online-stats-bar">
          <div class="stats-row">
            <span class="stat-item">
              <strong>{data.stats.total}</strong> total online
            </span>
            {#if data.stats.record_count > 0}
              <span class="stat-item record">
                Record: <strong>{data.stats.record_count}</strong>
                {#if data.stats.record_date}
                  on {new Date(data.stats.record_date).toLocaleDateString()}
                {/if}
              </span>
            {/if}
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .whos-online {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .online-header {
    display: flex;
    width: 100%;
    padding: 12px 16px;
    background: none;
    border: none;
    border-bottom: 1px solid var(--border-color);
    cursor: pointer;
    color: inherit;
    font-family: inherit;
    text-align: left;
  }
  .online-header:hover { background: rgba(255, 255, 255, 0.02); }

  .online-title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
  }

  .online-title-row h3 {
    font-size: 13px;
    font-weight: 700;
    margin: 0;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .online-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--online, #22c55e);
    box-shadow: 0 0 6px var(--online, #22c55e);
    animation: dot-pulse 2s ease-in-out infinite;
  }

  @keyframes dot-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  .online-count {
    font-weight: 400;
    color: var(--text-secondary);
    font-size: 12px;
  }

  .collapse-icon {
    font-size: 10px;
    color: var(--text-muted);
    transition: transform 0.2s;
  }
  .collapse-icon.rotated { transform: rotate(-90deg); }

  .online-body {
    padding: 12px 16px;
  }

  .online-loading {
    text-align: center;
    color: var(--text-muted);
    font-size: 12px;
    padding: 8px 0;
  }

  .online-users-list {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 2px 4px;
    margin-bottom: 10px;
    max-height: 120px;
    overflow-y: auto;
  }

  .online-user {
    text-decoration: none;
    color: inherit;
    transition: opacity 0.15s;
  }
  .online-user:hover { opacity: 0.8; }

  .user-separator {
    color: var(--text-muted);
    font-size: 12px;
    margin-right: 2px;
  }

  .no-users {
    font-size: 12px;
    color: var(--text-muted);
    font-style: italic;
    text-align: center;
    padding: 8px 0;
  }

  /* Group legend */
  .group-legend {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    padding: 8px 0;
    border-top: 1px solid var(--border-color);
    margin-top: 4px;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .legend-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .legend-label {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  /* Stats bar */
  .online-stats-bar {
    padding-top: 8px;
    border-top: 1px solid var(--border-color);
    margin-top: 8px;
  }

  .stats-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .stat-item {
    font-size: 11px;
    color: var(--text-muted);
  }
  .stat-item strong {
    color: var(--text-secondary);
  }
  .stat-item.record {
    font-style: italic;
  }

  /* Scrollbar styling for online list */
  .online-users-list::-webkit-scrollbar {
    width: 4px;
  }
  .online-users-list::-webkit-scrollbar-track {
    background: transparent;
  }
  .online-users-list::-webkit-scrollbar-thumb {
    background: var(--border-color);
    border-radius: 2px;
  }

  @media (max-width: 640px) {
    .stats-row { flex-direction: column; gap: 4px; text-align: center; }
    .group-legend { justify-content: center; }
  }
</style>
