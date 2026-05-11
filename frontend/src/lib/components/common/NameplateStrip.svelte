<script lang="ts">
  let {
    color = null,
    imageUrl = null,
    children
  }: {
    color?: string | null;
    imageUrl?: string | null;
    children: any;
  } = $props();

  let hasNameplate = $derived(!!(color || imageUrl));
</script>

{#if hasNameplate}
  <div class="nameplate-strip" style:position="relative">
    {#if imageUrl}
      <div
        class="nameplate-bg nameplate-image"
        style="background-image: url({imageUrl});"
      ></div>
    {:else if color}
      <div
        class="nameplate-bg nameplate-color"
        style:background={color}
      ></div>
    {/if}
    <div class="nameplate-content">
      {@render children()}
    </div>
  </div>
{:else}
  {@render children()}
{/if}

<style>
  .nameplate-strip {
    border-radius: var(--radius);
    overflow: hidden;
    display: inline-flex;
    align-items: center;
  }

  .nameplate-bg {
    position: absolute;
    inset: 0;
    opacity: 0.3;
    pointer-events: none;
  }

  .nameplate-image {
    background-size: cover;
    background-position: center;
  }

  .nameplate-content {
    position: relative;
    z-index: 1;
    padding: 2px 8px;
  }
</style>
