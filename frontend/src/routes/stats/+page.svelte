<script lang="ts">
  import { api } from "$lib/api/client";

  let stats = $state<any>(null);
  let loading = $state(true);
  let error = $state("");

  $effect(() => {
    loadStats();
  });

  async function loadStats() {
    try {
      const data = await api.getStats();
      stats = data.stats;
    } catch (err: any) {
      error = err?.error || "Failed to load statistics";
    }
    loading = false;
  }

  function formatNumber(n: number): string {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
    if (n >= 1000) return (n / 1000).toFixed(1) + "K";
    return String(n);
  }

  function getMaxValue(data: any[], key: string): number {
    return Math.max(1, ...data.map((d: any) => d[key] || 0));
  }

  function monthLabel(m: string): string {
    const [year, month] = m.split("-");
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[parseInt(month) - 1] + " " + year.slice(2);
  }
</script>

<svelte:head>
  <title>Forum Statistics - ForgeNexus</title>
  <meta name="description" content="ForgeNexus forum statistics and activity data" />
</svelte:head>

<div class="stats-page">
  <h1 class="page-title">Forum Statistics</h1>

  {#if loading}
    <div class="loading">Loading statistics...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if stats}
    <div class="summary-cards">
      <div class="stat-card">
        <div class="stat-value">{formatNumber(stats.total_members)}</div>
        <div class="stat-label">Total Members</div>
        <div class="stat-sub">+{stats.new_members_this_month} this month</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">{formatNumber(stats.total_threads)}</div>
        <div class="stat-label">Total Threads</div>
        <div class="stat-sub">+{stats.new_threads_this_month} this month</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">{formatNumber(stats.total_posts)}</div>
        <div class="stat-label">Total Posts</div>
        <div class="stat-sub">+{stats.new_posts_this_month} this month</div>
      </div>
      <div class="stat-card accent">
        <div class="stat-value">{stats.online_count}</div>
        <div class="stat-label">Online Now</div>
        <div class="stat-sub"><span class="online-dot"></span> active users</div>
      </div>
    </div>

    {#if stats.monthly_growth && stats.monthly_growth.length > 0}
      <div class="section">
        <h2 class="section-title">Monthly Growth</h2>
        <div class="growth-charts">
          <div class="chart-block">
            <h3 class="chart-label">New Members</h3>
            <div class="bar-chart">
              {#each stats.monthly_growth as row (row.month)}
                {@const maxMembers = getMaxValue(stats.monthly_growth, "members")}
                <div class="bar-row">
                  <span class="bar-month">{monthLabel(row.month)}</span>
                  <div class="bar-track">
                    <div class="bar-fill members" style="width: {Math.max(2, (row.members / maxMembers) * 100)}%"></div>
                  </div>
                  <span class="bar-count">{row.members}</span>
                </div>
              {/each}
            </div>
          </div>
          <div class="chart-block">
            <h3 class="chart-label">New Threads</h3>
            <div class="bar-chart">
              {#each stats.monthly_growth as row (row.month)}
                {@const maxThreads = getMaxValue(stats.monthly_growth, "threads")}
                <div class="bar-row">
                  <span class="bar-month">{monthLabel(row.month)}</span>
                  <div class="bar-track">
                    <div class="bar-fill threads" style="width: {Math.max(2, (row.threads / maxThreads) * 100)}%"></div>
                  </div>
                  <span class="bar-count">{row.threads}</span>
                </div>
              {/each}
            </div>
          </div>
          <div class="chart-block">
            <h3 class="chart-label">New Posts</h3>
            <div class="bar-chart">
              {#each stats.monthly_growth as row (row.month)}
                {@const maxPosts = getMaxValue(stats.monthly_growth, "posts")}
                <div class="bar-row">
                  <span class="bar-month">{monthLabel(row.month)}</span>
                  <div class="bar-track">
                    <div class="bar-fill posts" style="width: {Math.max(2, (row.posts / maxPosts) * 100)}%"></div>
                  </div>
                  <span class="bar-count">{row.posts}</span>
                </div>
              {/each}
            </div>
          </div>
        </div>
      </div>
    {/if}

    {#if stats.most_active_users && stats.most_active_users.length > 0}
      <div class="section">
        <h2 class="section-title">Most Active Members</h2>
        <div class="stats-table-wrap">
          <table class="stats-table">
            <thead>
              <tr>
                <th class="rank-col">#</th>
                <th>Member</th>
                <th class="num-col">Posts</th>
              </tr>
            </thead>
            <tbody>
              {#each stats.most_active_users as user, i (user.id)}
                <tr>
                  <td class="rank-col">
                    <span class="rank-badge" class:gold={i === 0} class:silver={i === 1} class:bronze={i === 2}>{i + 1}</span>
                  </td>
                  <td>
                    <a href="/profile/{user.slug}" class="user-link" style:color={user.username_color || undefined}>
                      {#if user.avatar_url}
                        <img src={user.avatar_url} alt="" class="mini-avatar" />
                      {:else}
                        <span class="mini-avatar placeholder">{user.username.charAt(0).toUpperCase()}</span>
                      {/if}
                      {user.username}
                    </a>
                  </td>
                  <td class="num-col">{formatNumber(user.post_count)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}

    {#if stats.most_popular_threads && stats.most_popular_threads.length > 0}
      <div class="section">
        <h2 class="section-title">Most Popular Threads</h2>
        <div class="stats-table-wrap">
          <table class="stats-table">
            <thead>
              <tr>
                <th>Thread</th>
                <th class="num-col">Views</th>
                <th class="num-col">Replies</th>
                <th class="forum-col">Forum</th>
              </tr>
            </thead>
            <tbody>
              {#each stats.most_popular_threads as thread (thread.id)}
                <tr>
                  <td>
                    <a href="/threads/{thread.slug}" class="thread-link">{thread.title}</a>
                    <span class="thread-author">by {thread.user.username}</span>
                  </td>
                  <td class="num-col">{formatNumber(thread.view_count)}</td>
                  <td class="num-col">{formatNumber(thread.reply_count)}</td>
                  <td class="forum-col">
                    <a href="/forums/{thread.forum_slug}" class="forum-link">{thread.forum_name}</a>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .stats-page { max-width: 960px; margin: 0 auto; }
  .page-title { font-size: 22px; font-weight: 800; margin-bottom: 16px; color: var(--text-primary); }
  .loading { text-align: center; padding: 60px 0; color: var(--text-muted); }
  .error-box { padding: 16px; background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: var(--radius-lg); color: var(--danger); text-align: center; }

  .summary-cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; }
  .stat-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; text-align: center; transition: border-color 0.15s; }
  .stat-card:hover { border-color: var(--accent); }
  .stat-card.accent { border-color: var(--accent); background: var(--accent-glow); }
  .stat-value { font-size: 28px; font-weight: 800; color: var(--text-primary); line-height: 1.2; }
  .stat-card.accent .stat-value { color: var(--accent); }
  .stat-label { font-size: 12px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 4px; }
  .stat-sub { font-size: 11px; color: var(--text-muted); margin-top: 4px; display: flex; align-items: center; justify-content: center; gap: 4px; }
  .online-dot { width: 6px; height: 6px; border-radius: 50%; background: #22c55e; box-shadow: 0 0 4px #22c55e; display: inline-block; }

  .section { margin-bottom: 24px; }
  .section-title { font-size: 16px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid var(--border-color); }

  .growth-charts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
  .chart-block { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 14px 16px; }
  .chart-label { font-size: 13px; font-weight: 700; color: var(--text-secondary); margin-bottom: 10px; }
  .bar-chart { display: flex; flex-direction: column; gap: 4px; }
  .bar-row { display: flex; align-items: center; gap: 6px; }
  .bar-month { font-size: 10px; color: var(--text-muted); width: 44px; flex-shrink: 0; text-align: right; }
  .bar-track { flex: 1; height: 14px; background: var(--bg-tertiary); border-radius: 3px; overflow: hidden; }
  .bar-fill { height: 100%; border-radius: 3px; transition: width 0.3s ease; }
  .bar-fill.members { background: linear-gradient(90deg, #6366f1, #818cf8); }
  .bar-fill.threads { background: linear-gradient(90deg, #00d4aa, #34d399); }
  .bar-fill.posts { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
  .bar-count { font-size: 10px; color: var(--text-muted); width: 30px; text-align: right; font-variant-numeric: tabular-nums; }

  .stats-table-wrap { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: hidden; }
  .stats-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .stats-table thead { background: var(--bg-secondary); }
  .stats-table th { padding: 8px 12px; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; text-align: left; border-bottom: 1px solid var(--border-color); }
  .stats-table td { padding: 10px 12px; border-bottom: 1px solid var(--border-color); color: var(--text-secondary); }
  .stats-table tbody tr:hover { background: var(--bg-hover); }
  .stats-table tbody tr:last-child td { border-bottom: none; }

  .rank-col { width: 40px; text-align: center; }
  .num-col { width: 70px; text-align: right; font-variant-numeric: tabular-nums; }
  .forum-col { width: 140px; }

  .rank-badge { display: inline-flex; align-items: center; justify-content: center; width: 22px; height: 22px; border-radius: 50%; font-size: 11px; font-weight: 700; background: var(--bg-tertiary); color: var(--text-muted); }
  .rank-badge.gold { background: linear-gradient(135deg, #fbbf24, #f59e0b); color: #1a1a1a; }
  .rank-badge.silver { background: linear-gradient(135deg, #d1d5db, #9ca3af); color: #1a1a1a; }
  .rank-badge.bronze { background: linear-gradient(135deg, #d97706, #b45309); color: #1a1a1a; }

  .user-link { display: inline-flex; align-items: center; gap: 6px; color: var(--text-primary); text-decoration: none; font-weight: 600; }
  .user-link:hover { color: var(--accent); }
  .mini-avatar { width: 22px; height: 22px; border-radius: var(--radius); object-fit: cover; }
  .mini-avatar.placeholder { background: var(--bg-tertiary); color: var(--text-muted); display: inline-flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; }

  .thread-link { color: var(--text-primary); text-decoration: none; font-weight: 600; }
  .thread-link:hover { color: var(--accent); }
  .thread-author { font-size: 11px; color: var(--text-muted); margin-left: 6px; }
  .forum-link { color: var(--text-secondary); text-decoration: none; font-size: 12px; }
  .forum-link:hover { color: var(--accent); }

  @media (max-width: 768px) {
    .summary-cards { grid-template-columns: repeat(2, 1fr); }
    .growth-charts { grid-template-columns: 1fr; }
    .forum-col { display: none; }
  }
  @media (max-width: 480px) {
    .summary-cards { grid-template-columns: 1fr; }
  }
</style>
