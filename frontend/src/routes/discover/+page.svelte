<script lang="ts">
  import { api } from '$lib/api/client';

  interface Community {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    logo_url: string | null;
    category: string | null;
    tags: string[];
    member_count: number;
    activity_score: number;
    plan: string;
  }

  let communities = $state<Community[]>([]);
  let loading = $state(true);

  $effect(() => {
    loadCommunities();
  });

  async function loadCommunities() {
    try {
      const data = await api.request('/discover');
      communities = data.communities || [];
    } catch (e) {
      console.error('Failed to load communities:', e);
    }
    loading = false;
  }
</script>

<svelte:head>
  <title>Discover Communities — ForgeNexus</title>
</svelte:head>

<div class="discover-page">
  <div class="discover-header">
    <h1 class="text-glow">Discover Communities</h1>
    <p>Find your people. Join communities that match your interests.</p>
  </div>

  <div class="community-grid stagger">
    {#if loading}
      {#each Array(6) as _}
        <div class="skeleton community-skeleton"></div>
      {/each}
    {:else}
      {#each communities as community (community.id)}
        <a href="/{community.slug}" class="community-card card-elevated card-glow">
          <div class="community-logo">
            {#if community.logo_url}
              <img src={community.logo_url} alt={community.name} />
            {:else}
              <div class="logo-placeholder">{community.name[0]}</div>
            {/if}
          </div>
          <div class="community-info">
            <h3>{community.name}</h3>
            {#if community.description}
              <p class="community-desc">{community.description.slice(0, 120)}</p>
            {/if}
            <div class="community-meta">
              <span>👥 {community.member_count} members</span>
              {#if community.category}
                <span class="badge badge-accent">{community.category}</span>
              {/if}
            </div>
          </div>
        </a>
      {/each}
    {/if}
  </div>
</div>

<style>
  .discover-page { max-width: 1000px; margin: 0 auto; padding: 24px 16px; }

  .discover-header {
    text-align: center; margin-bottom: 32px;
  }

  .discover-header h1 { font-size: 28px; font-weight: 800; color: var(--text-heading); margin-bottom: 8px; }
  .discover-header p { color: var(--text-secondary); font-size: 15px; }

  .community-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }

  .community-skeleton { height: 140px; border-radius: var(--radius-lg); }

  .community-card {
    display: flex; gap: 14px; padding: 18px;
    text-decoration: none; color: var(--text-primary);
  }

  .community-logo img, .logo-placeholder {
    width: 56px; height: 56px; border-radius: var(--radius-md);
    object-fit: cover;
  }

  .logo-placeholder {
    background: var(--accent-gradient); color: var(--bg-primary);
    display: flex; align-items: center; justify-content: center;
    font-size: 24px; font-weight: 800;
  }

  .community-info { flex: 1; min-width: 0; }
  .community-info h3 { font-size: 16px; font-weight: 700; margin-bottom: 4px; }
  .community-desc { font-size: 13px; color: var(--text-secondary); margin-bottom: 8px; line-height: 1.4; }
  .community-meta { display: flex; align-items: center; gap: 10px; font-size: 12px; color: var(--text-muted); }
</style>
