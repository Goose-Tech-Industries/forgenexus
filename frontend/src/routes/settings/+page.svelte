<script lang="ts">
  import { goto } from '$app/navigation';

  // Redirect to profile settings by default
  $effect(() => {
    goto('/settings/profile', { replaceState: true });
  });
</script>

<div class="settings-redirect">
  Redirecting to profile settings...
</div>

<style>
  .settings-redirect {
    padding: 40px;
    text-align: center;
    color: var(--text-muted);
  }
</style>
