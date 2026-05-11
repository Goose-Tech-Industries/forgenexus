<script lang="ts">
  interface Crumb {
    label: string;
    href?: string;
  }

  let { crumbs = [] }: { crumbs: Crumb[] } = $props();
</script>

<nav class="breadcrumb">
  <a href="/">ForgeNexus</a>
  {#each crumbs as crumb, i}
    <span class="sep">&rsaquo;</span>
    {#if crumb.href && i < crumbs.length - 1}
      <a href={crumb.href}>{crumb.label}</a>
    {:else}
      <span class="current">{crumb.label}</span>
    {/if}
  {/each}
</nav>

<style>
  .breadcrumb {
    padding: 8px 0;
    font-size: 12px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .breadcrumb a {
    color: var(--text-secondary);
  }
  .breadcrumb a:hover {
    color: var(--text-link);
  }
  .sep {
    color: var(--text-muted);
  }
  .current {
    color: var(--text-primary);
    font-weight: 500;
  }
</style>
