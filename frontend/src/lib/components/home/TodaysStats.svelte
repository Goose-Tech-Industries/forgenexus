<script lang="ts">
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  let {
    stats
  }: {
    stats: {
      total_members: number;
      total_threads: number;
      total_posts: number;
      posts_today: number;
      threads_today: number;
      new_members_today: number;
      newest_member: {
        username: string;
        slug: string;
        username_color: string | null;
        username_effect: string | null;
      } | null;
    } | null;
  } = $props();
</script>

{#if stats}
  <div class="todays-stats">
    <div class="stats-strip">
      <div class="stat-chip">
        <span class="chip-value">{stats.posts_today ?? 0}</span>
        <span class="chip-label">Posts Today</span>
      </div>
      <div class="stat-divider"></div>
      <div class="stat-chip">
        <span class="chip-value">{stats.threads_today ?? 0}</span>
        <span class="chip-label">New Threads</span>
      </div>
      <div class="stat-divider"></div>
      <div class="stat-chip">
        <span class="chip-value">{stats.new_members_today ?? 0}</span>
        <span class="chip-label">New Members</span>
      </div>
      <div class="stat-divider"></div>
      <div class="stat-chip">
        <span class="chip-value">{(stats.total_members ?? 0).toLocaleString()}</span>
        <span class="chip-label">Total Members</span>
      </div>
      <div class="stat-divider"></div>
      <div class="stat-chip">
        <span class="chip-value">{(stats.total_posts ?? 0).toLocaleString()}</span>
        <span class="chip-label">Total Posts</span>
      </div>
      {#if stats.newest_member}
        <div class="stat-divider"></div>
        <div class="stat-chip newest">
          <span class="chip-label">Newest Member</span>
          <a href="/profile/{stats.newest_member.slug}" class="newest-link">
            <UsernameDisplay
              username={stats.newest_member.username}
              color={stats.newest_member.username_color}
              effect={stats.newest_member.username_effect}
              size="small"
            />
          </a>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .todays-stats {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 10px 16px;
  }

  .stats-strip {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    flex-wrap: wrap;
  }

  .stat-chip {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1px;
  }
  .stat-chip.newest {
    flex-direction: row;
    gap: 6px;
  }

  .chip-value {
    font-size: 15px;
    font-weight: 800;
    color: var(--accent);
  }

  .chip-label {
    font-size: 10px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .stat-divider {
    width: 1px;
    height: 24px;
    background: var(--border-color);
  }

  .newest-link {
    text-decoration: none;
    color: inherit;
  }

  @media (max-width: 640px) {
    .stats-strip {
      gap: 8px;
    }
    .stat-divider { display: none; }
    .stat-chip {
      min-width: 70px;
    }
  }
</style>
