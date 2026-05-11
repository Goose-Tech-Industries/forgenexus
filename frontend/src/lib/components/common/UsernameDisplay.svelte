<script lang="ts">
  let {
    username,
    color = null,
    effect = 'none',
    href = '',
    size = 'normal',
    customTitle = null,
    nameplateColor = null,
    nameplateImageUrl = null,
    badge = null,
    badgeColor = null,
    groupName = null,
    groupColor = null
  }: {
    username: string;
    color?: string | null;
    effect?: string | null;
    href?: string;
    size?: 'small' | 'normal' | 'large';
    customTitle?: string | null;
    nameplateColor?: string | null;
    nameplateImageUrl?: string | null;
    badge?: string | null;
    badgeColor?: string | null;
    groupName?: string | null;
    groupColor?: string | null;
  } = $props();

  let effectClass = $derived(
    effect && effect !== 'none' ? `effect-${effect}` : ''
  );

  let sizeClass = $derived(`size-${size}`);
  let hasNameplate = $derived(!!(nameplateColor || nameplateImageUrl));
</script>

<span class="username-wrapper">
  {#if hasNameplate}
    <span class="nameplate-strip" style:position="relative">
      {#if nameplateImageUrl}
        <span
          class="nameplate-bg nameplate-image"
          style="background-image: url({nameplateImageUrl});"
        ></span>
      {:else if nameplateColor}
        <span
          class="nameplate-bg nameplate-color"
          style:background={nameplateColor}
        ></span>
      {/if}
      <span class="nameplate-content">
        {#if href}
          <a
            {href}
            class="username-display {effectClass} {sizeClass}"
            style:color={color || undefined}
            style:--username-color={color || 'var(--text-primary)'}
          >{username}</a>
        {:else}
          <span
            class="username-display {effectClass} {sizeClass}"
            style:color={color || undefined}
            style:--username-color={color || 'var(--text-primary)'}
          >{username}</span>
        {/if}
      </span>
    </span>
  {:else}
    {#if href}
      <a
        {href}
        class="username-display {effectClass} {sizeClass}"
        style:color={color || undefined}
        style:--username-color={color || 'var(--text-primary)'}
      >{username}</a>
    {:else}
      <span
        class="username-display {effectClass} {sizeClass}"
        style:color={color || undefined}
        style:--username-color={color || 'var(--text-primary)'}
      >{username}</span>
    {/if}
  {/if}

  {#if badge}
    <span class="sub-badge" style="background: {badgeColor || 'var(--accent)'}">{badge}</span>
  {/if}

  {#if customTitle}
    <span class="custom-title">{customTitle}</span>
  {:else if groupName}
    <span class="group-tag" style:color={groupColor || 'var(--text-muted)'}>{groupName}</span>
  {/if}
</span>

<style>
  .username-wrapper {
    display: inline-flex;
    flex-direction: column;
    align-items: inherit;
  }

  .username-display {
    font-weight: 700;
    transition: color 0.15s;
  }

  .size-small { font-size: 12px; }
  .size-normal { font-size: 13px; }
  .size-large { font-size: 15px; }

  .custom-title {
    font-size: 10px;
    color: var(--text-muted);
    font-style: italic;
    margin-top: 1px;
  }

  .group-tag {
    font-size: 9px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-top: 1px;
  }

  .sub-badge {
    font-size: 8px;
    font-weight: 800;
    color: white;
    padding: 1px 5px;
    border-radius: 3px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-top: 2px;
    align-self: flex-start;
  }

  /* Nameplate */
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
    padding: 1px 6px;
  }

  /* Glow effect */
  .effect-glow {
    text-shadow:
      0 0 4px var(--username-color),
      0 0 8px var(--username-color),
      0 0 16px color-mix(in srgb, var(--username-color) 40%, transparent);
    animation: glow-pulse 2s ease-in-out infinite alternate;
  }

  @keyframes glow-pulse {
    from {
      text-shadow:
        0 0 4px var(--username-color),
        0 0 8px var(--username-color);
    }
    to {
      text-shadow:
        0 0 6px var(--username-color),
        0 0 12px var(--username-color),
        0 0 20px color-mix(in srgb, var(--username-color) 50%, transparent);
    }
  }

  /* Rainbow effect */
  .effect-rainbow {
    background: linear-gradient(
      90deg,
      #ff0000, #ff8800, #ffff00, #00ff00, #0088ff, #8800ff, #ff0000
    );
    background-size: 200% 100%;
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    animation: rainbow-shift 3s linear infinite;
  }

  @keyframes rainbow-shift {
    0% { background-position: 0% 50%; }
    100% { background-position: 200% 50%; }
  }

  /* Pulse effect */
  .effect-pulse {
    animation: pulse-opacity 1.5s ease-in-out infinite;
  }

  @keyframes pulse-opacity {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  /* Shimmer effect (Ember+ / Ascended) */
  .effect-shimmer {
    background: linear-gradient(
      90deg,
      var(--username-color) 0%,
      color-mix(in srgb, var(--username-color) 60%, white) 25%,
      var(--username-color) 50%,
      color-mix(in srgb, var(--username-color) 60%, white) 75%,
      var(--username-color) 100%
    );
    background-size: 200% 100%;
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    animation: shimmer-slide 2.5s linear infinite;
  }

  @keyframes shimmer-slide {
    0% { background-position: 200% 50%; }
    100% { background-position: -200% 50%; }
  }

  /* Gradient effect (Ascended) */
  .effect-gradient {
    background: linear-gradient(
      135deg,
      var(--username-color),
      color-mix(in srgb, var(--username-color) 50%, #ff6b35),
      var(--username-color)
    );
    background-size: 300% 300%;
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    animation: gradient-flow 4s ease infinite;
  }

  @keyframes gradient-flow {
    0% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }

  /* Fire effect (Ascended) */
  .effect-fire {
    background: linear-gradient(
      0deg,
      #ff4500 0%,
      #ff8c00 30%,
      #ffd700 60%,
      #ffffff 100%
    );
    background-size: 100% 200%;
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    animation: fire-flicker 1.5s ease-in-out infinite alternate;
    filter: drop-shadow(0 0 3px rgba(255, 69, 0, 0.5));
  }

  @keyframes fire-flicker {
    0% { background-position: 50% 100%; }
    100% { background-position: 50% 60%; }
  }
</style>
