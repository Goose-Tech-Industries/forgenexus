<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';

  let pageData = $state<any>(null);
  let loading = $state(true);
  let error = $state('');

  $effect(() => {
    loadPage();
  });

  async function loadPage() {
    loading = true;
    error = '';
    try {
      const slug = $page.params.slug;
      const data = await api.request(`/pages/${slug}`);
      pageData = data.page;
    } catch (e: any) {
      error = e.error || 'Page not found';
    }
    loading = false;
  }
</script>

<div class="custom-page">
  {#if loading}
    <div class="loading">Loading...</div>
  {:else if error}
    <div class="error-page">
      <h1>Page Not Found</h1>
      <p>{error}</p>
      <a href="/">Back to Home</a>
    </div>
  {:else if pageData}
    <div class="page-content">
      <h1>{pageData.title}</h1>
      {#if pageData.description}
        <p class="page-description">{pageData.description}</p>
      {/if}

      {#if pageData.template?.blocks}
        {#each pageData.template.blocks as block}
          {#if block.type === 'html'}
            <div class="block-html">{@html block.content}</div>
          {:else if block.type === 'text'}
            <div class="block-text">{block.content}</div>
          {:else if block.type === 'heading'}
            <h2>{block.content}</h2>
          {:else if block.type === 'image'}
            <img src={block.url} alt={block.alt || ''} class="block-image" />
          {:else if block.type === 'embed'}
            <div class="block-embed">{@html block.content}</div>
          {/if}
        {/each}
      {:else if pageData.template?.html}
        <div class="page-html">{@html pageData.template.html}</div>
      {:else}
        <div class="page-empty">This page has no content yet.</div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .custom-page { max-width: 900px; margin: 0 auto; }
  .custom-page h1 { font-size: 24px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px; }
  .page-description { font-size: 14px; color: var(--text-secondary); margin-bottom: 24px; }
  .page-content { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 24px; }
  .block-html, .block-text { margin-bottom: 16px; line-height: 1.6; color: var(--text-primary); }
  .block-image { max-width: 100%; border-radius: var(--radius); margin-bottom: 16px; }
  .loading { text-align: center; padding: 60px; color: var(--text-muted); }
  .error-page { text-align: center; padding: 60px; }
  .error-page h1 { color: var(--text-primary); }
  .error-page p { color: var(--text-secondary); margin: 8px 0 16px; }
  .page-empty { text-align: center; padding: 40px; color: var(--text-muted); }
</style>
