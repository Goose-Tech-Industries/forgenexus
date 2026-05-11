<script lang="ts">
  import { api } from "$lib/api/client";

  interface Props {
    url: string;
  }

  let { url }: Props = $props();

  let preview = $state<{
    url: string;
    title: string | null;
    description: string | null;
    image: string | null;
    site_name: string | null;
  } | null>(null);
  let loading = $state(true);
  let failed = $state(false);

  $effect(() => {
    if (url) {
      loading = true;
      failed = false;
      api
        .getLinkPreview(url)
        .then((data: any) => {
          preview = data.preview || null;
          if (!preview) failed = true;
        })
        .catch(() => {
          failed = true;
        })
        .finally(() => {
          loading = false;
        });
    }
  });
</script>

{#if loading}
  <a href={url} target="_blank" rel="noopener noreferrer" class="link-preview-url">{url}</a>
{:else if failed || !preview}
  <a href={url} target="_blank" rel="noopener noreferrer" class="link-preview-url">{url}</a>
{:else}
  <a
    href={preview.url}
    target="_blank"
    rel="noopener noreferrer"
    class="link-preview-card"
  >
    {#if preview.image}
      <div class="link-preview-thumbnail">
        <img src={preview.image} alt="" loading="lazy" />
      </div>
    {/if}
    <div class="link-preview-content">
      {#if preview.site_name}
        <div class="link-preview-site">{preview.site_name}</div>
      {/if}
      {#if preview.title}
        <div class="link-preview-title">{preview.title}</div>
      {/if}
      {#if preview.description}
        <div class="link-preview-description">{preview.description}</div>
      {/if}
      <div class="link-preview-link">{url}</div>
    </div>
  </a>
{/if}

<style>
  .link-preview-url {
    color: var(--accent, #5865f2);
    word-break: break-all;
  }

  .link-preview-card {
    display: flex;
    border-left: 4px solid var(--accent, #5865f2);
    background: var(--card-bg, #2b2d31);
    border-radius: 4px;
    overflow: hidden;
    margin: 8px 0;
    max-width: 520px;
    text-decoration: none;
    color: inherit;
    transition: background 0.15s ease;
  }

  .link-preview-card:hover {
    background: var(--card-bg-hover, #323438);
  }

  .link-preview-thumbnail {
    flex-shrink: 0;
    width: 80px;
    min-height: 80px;
    overflow: hidden;
  }

  .link-preview-thumbnail img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .link-preview-content {
    padding: 10px 14px;
    min-width: 0;
    flex: 1;
  }

  .link-preview-site {
    font-size: 0.75rem;
    color: var(--text-muted, #949ba4);
    text-transform: uppercase;
    letter-spacing: 0.02em;
    margin-bottom: 2px;
  }

  .link-preview-title {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--accent, #5865f2);
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .link-preview-description {
    font-size: 0.85rem;
    color: var(--text-secondary, #b5bac1);
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    line-height: 1.4;
  }

  .link-preview-link {
    font-size: 0.75rem;
    color: var(--text-muted, #949ba4);
    margin-top: 6px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  @media (max-width: 480px) {
    .link-preview-card {
      flex-direction: column;
      max-width: 100%;
    }

    .link-preview-thumbnail {
      width: 100%;
      height: 150px;
    }
  }
</style>
