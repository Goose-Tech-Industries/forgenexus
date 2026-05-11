<script lang="ts">
  let { src = '', alt = '' }: { src: string; alt?: string } = $props();
  let open = $state(false);
</script>

<!-- svelte-ignore a11y-click-events-have-key-events -->
<img
  {src}
  {alt}
  class="lightbox-thumb"
  onclick={() => open = true}
  loading="lazy"
  role="button"
  tabindex="0"
/>

{#if open}
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div class="lightbox-overlay" onclick={() => open = false} role="dialog" tabindex="-1">
    <button class="lightbox-close" onclick={() => open = false}>&times;</button>
    <img {src} {alt} class="lightbox-full" />
  </div>
{/if}

<style>
  .lightbox-thumb { cursor: zoom-in; max-width: 100%; height: auto; border-radius: var(--radius); }
  .lightbox-overlay {
    position: fixed; inset: 0; z-index: 1000;
    background: rgba(0,0,0,0.9); display: flex; align-items: center; justify-content: center;
    cursor: zoom-out;
  }
  .lightbox-full { max-width: 90vw; max-height: 90vh; object-fit: contain; border-radius: var(--radius-lg); }
  .lightbox-close {
    position: absolute; top: 16px; right: 16px;
    background: none; border: none; color: white; font-size: 32px; cursor: pointer;
    width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;
  }
</style>
