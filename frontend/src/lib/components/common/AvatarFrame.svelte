<script lang="ts">
  let {
    frame = 'none',
    frameColor = null,
    size = 100,
    children
  }: {
    frame?: string | null;
    frameColor?: string | null;
    size?: number;
    children: any;
  } = $props();

  let frameClass = $derived(
    frame && frame !== 'none' ? `avatar-frame avatar-frame-${frame}` : 'avatar-frame'
  );
</script>

<div
  class={frameClass}
  style:width="{size}px"
  style:height="{size}px"
  style:--frame-color={frameColor || 'var(--accent)'}
>
  {@render children()}
</div>

<style>
  .avatar-frame {
    position: relative;
    border-radius: var(--radius-lg);
    overflow: hidden;
    flex-shrink: 0;
  }

  /* Glow frame */
  .avatar-frame-glow {
    box-shadow:
      0 0 6px var(--frame-color),
      0 0 12px var(--frame-color),
      0 0 24px color-mix(in srgb, var(--frame-color) 40%, transparent);
    animation: frame-glow 2s ease-in-out infinite alternate;
  }

  @keyframes frame-glow {
    from {
      box-shadow:
        0 0 4px var(--frame-color),
        0 0 8px var(--frame-color);
    }
    to {
      box-shadow:
        0 0 8px var(--frame-color),
        0 0 16px var(--frame-color),
        0 0 32px color-mix(in srgb, var(--frame-color) 50%, transparent);
    }
  }

  /* Pulse frame */
  .avatar-frame-pulse {
    border: 3px solid var(--frame-color);
    animation: frame-pulse 1.5s ease-in-out infinite;
  }

  @keyframes frame-pulse {
    0%, 100% {
      border-color: var(--frame-color);
      box-shadow: 0 0 0 0 color-mix(in srgb, var(--frame-color) 40%, transparent);
    }
    50% {
      border-color: var(--frame-color);
      box-shadow: 0 0 0 6px transparent;
    }
  }

  /* Fire frame */
  .avatar-frame-fire {
    border: 3px solid #ff4400;
    box-shadow:
      0 -4px 8px rgba(255, 68, 0, 0.5),
      0 -8px 16px rgba(255, 140, 0, 0.3),
      0 0 12px rgba(255, 68, 0, 0.4);
    animation: frame-fire 0.8s ease-in-out infinite alternate;
  }

  @keyframes frame-fire {
    from {
      box-shadow:
        0 -4px 8px rgba(255, 68, 0, 0.5),
        0 -8px 16px rgba(255, 140, 0, 0.3),
        0 0 12px rgba(255, 68, 0, 0.4);
    }
    to {
      box-shadow:
        0 -6px 12px rgba(255, 68, 0, 0.6),
        0 -12px 20px rgba(255, 140, 0, 0.4),
        0 0 16px rgba(255, 68, 0, 0.5);
    }
  }

  /* Frost frame */
  .avatar-frame-frost {
    border: 3px solid #88ccff;
    box-shadow:
      0 0 8px rgba(136, 204, 255, 0.5),
      0 0 16px rgba(136, 204, 255, 0.3),
      inset 0 0 8px rgba(136, 204, 255, 0.1);
    animation: frame-frost 3s ease-in-out infinite alternate;
  }

  @keyframes frame-frost {
    from {
      box-shadow:
        0 0 8px rgba(136, 204, 255, 0.5),
        0 0 16px rgba(136, 204, 255, 0.3);
    }
    to {
      box-shadow:
        0 0 12px rgba(200, 230, 255, 0.6),
        0 0 24px rgba(136, 204, 255, 0.4);
    }
  }

  /* Rainbow frame */
  .avatar-frame-rainbow {
    border: 3px solid transparent;
    background-clip: padding-box;
    position: relative;
  }

  .avatar-frame-rainbow::before {
    content: '';
    position: absolute;
    inset: -3px;
    border-radius: var(--radius-lg);
    background: linear-gradient(
      135deg,
      #ff0000, #ff8800, #ffff00, #00ff00, #0088ff, #8800ff, #ff0000
    );
    background-size: 300% 300%;
    animation: frame-rainbow 3s linear infinite;
    z-index: -1;
  }

  @keyframes frame-rainbow {
    0% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
</style>
