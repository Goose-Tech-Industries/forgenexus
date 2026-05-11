<script lang="ts">
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  interface NewMember {
    id: string;
    username: string;
    slug: string;
    avatar_url: string | null;
    username_color: string | null;
    username_effect: string | null;
    post_count: number;
    inserted_at: string;
  }

  let { members = [] }: { members: NewMember[] } = $props();

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    const days = Math.floor(diff / 86400);
    return days === 1 ? 'yesterday' : `${days}d ago`;
  }
</script>

<div class="spotlight">
  <h3>New Members</h3>
  {#if members.length === 0}
    <div class="no-members">No recent registrations</div>
  {:else}
    <div class="member-list">
      {#each members as member (member.id)}
        <a href="/admin/users/{member.id}" class="member-row">
          <div class="member-avatar">
            {#if member.avatar_url}
              <img src={member.avatar_url} alt="" />
            {:else}
              <div class="avatar-placeholder">{member.username[0].toUpperCase()}</div>
            {/if}
          </div>
          <div class="member-info">
            <UsernameDisplay
              username={member.username}
              color={member.username_color}
              effect={member.username_effect}
              size="small"
            />
            <span class="member-meta">
              Joined {timeAgo(member.inserted_at)}
              {#if member.post_count > 0}
                &middot; {member.post_count} {member.post_count === 1 ? 'post' : 'posts'}
              {:else}
                &middot; <em>no posts yet</em>
              {/if}
            </span>
          </div>
          <div class="member-status" class:active={member.post_count > 0} class:lurking={member.post_count === 0}>
            {member.post_count > 0 ? 'Active' : 'Lurking'}
          </div>
        </a>
      {/each}
    </div>
  {/if}
</div>

<style>
  .spotlight {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }
  .spotlight h3 {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 0 0 12px;
  }

  .member-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .member-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px;
    border-radius: var(--radius);
    text-decoration: none;
    color: inherit;
    transition: background 0.1s;
  }
  .member-row:hover { background: rgba(255, 255, 255, 0.03); }

  .member-avatar {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
  }
  .member-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    background: var(--accent);
    color: var(--bg-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 14px;
  }

  .member-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .member-meta {
    font-size: 10px;
    color: var(--text-muted);
  }
  .member-meta em { color: #fbbf24; }

  .member-status {
    font-size: 9px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 2px 8px;
    border-radius: 10px;
  }
  .member-status.active { background: rgba(74, 222, 128, 0.1); color: #4ade80; }
  .member-status.lurking { background: rgba(251, 191, 36, 0.1); color: #fbbf24; }

  .no-members {
    font-size: 12px;
    color: var(--text-muted);
    text-align: center;
    padding: 16px;
  }
</style>
