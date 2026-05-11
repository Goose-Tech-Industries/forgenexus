<script lang="ts">
  interface Props {
    profile: any;
  }

  let { profile }: Props = $props();

  const blurbs = [
    { key: 'interests', label: 'Interests', icon: '💡' },
    { key: 'favorite_music', label: 'Music', icon: '🎵' },
    { key: 'favorite_movies', label: 'Movies', icon: '🎬' },
    { key: 'favorite_tv', label: 'TV Shows', icon: '📺' },
    { key: 'favorite_games', label: 'Games', icon: '🎮' },
    { key: 'favorite_books', label: 'Books', icon: '📚' },
    { key: 'heroes', label: 'Heroes', icon: '🦸' },
    { key: 'who_id_like_to_meet', label: "Who I'd Like to Meet", icon: '🤝' },
  ];

</script>

{#if profile}
  {@const activeBlurbs = blurbs.filter(b => profile[b.key])}
  {#if activeBlurbs.length > 0}
    <div class="blurbs-section">
      {#each activeBlurbs as blurb}
        <div class="blurb glass">
          <h4 class="blurb-heading">
            <span>{blurb.icon}</span>
            {blurb.label}
          </h4>
          <p class="blurb-text">{profile[blurb.key]}</p>
        </div>
      {/each}
    </div>
  {/if}
{/if}

<style>
  .blurbs-section {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 10px;
  }

  .blurb { padding: 12px 14px; }

  .blurb-heading {
    display: flex; align-items: center; gap: 6px;
    font-size: 12px; font-weight: 700; text-transform: uppercase;
    letter-spacing: 0.04em; color: var(--accent); margin-bottom: 6px;
  }

  .blurb-text {
    font-size: 13px; color: var(--text-secondary); line-height: 1.5;
    white-space: pre-wrap;
  }
</style>
