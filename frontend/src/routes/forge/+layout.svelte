<script lang="ts">
  let { children } = $props();
</script>

<div class="forge-shell">
  {@render children?.()}
</div>

<style>
  .forge-shell {
    max-width: 1200px;
    margin: 0 auto;
    padding: 24px 16px 80px;
  }
</style>
