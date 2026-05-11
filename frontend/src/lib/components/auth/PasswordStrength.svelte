<script lang="ts">
  let { password }: { password: string } = $props();

  let strength = $derived.by(() => {
    if (!password) return { score: 0, label: "", color: "" };
    let score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (/[a-z]/.test(password)) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;

    if (score <= 2) return { score: 1, label: "Weak", color: "var(--danger, #ef4444)" };
    if (score <= 3) return { score: 2, label: "Fair", color: "var(--warning, #f59e0b)" };
    if (score <= 4) return { score: 3, label: "Good", color: "#eab308" };
    return { score: 4, label: "Strong", color: "var(--online, #22c55e)" };
  });
</script>

{#if password}
  <div class="password-strength">
    <div class="strength-bar">
      {#each [1, 2, 3, 4] as segment}
        <div
          class="strength-segment"
          style:background={segment <= strength.score ? strength.color : "var(--bg-tertiary, #2a2a2e)"}
        ></div>
      {/each}
    </div>
    <span class="strength-label" style:color={strength.color}>{strength.label}</span>
  </div>
{/if}

<style>
  .password-strength {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
  }
  .strength-bar {
    display: flex;
    gap: 3px;
    flex: 1;
    max-width: 160px;
  }
  .strength-segment {
    height: 4px;
    flex: 1;
    border-radius: 2px;
    transition: background 0.2s;
  }
  .strength-label {
    font-size: 11px;
    font-weight: 600;
    min-width: 40px;
  }
</style>
