<script lang="ts">
  let {
    width = '100%',
    height = '16px',
    rounded = false,
    circle = false
  }: {
    width?: string;
    height?: string;
    rounded?: boolean;
    circle?: boolean;
  } = $props();

  let borderRadius = $derived(
    circle ? '50%' : rounded ? '8px' : '4px'
  );
</script>

<div
  class="skeleton"
  style="width: {width}; height: {height}; border-radius: {borderRadius};"
></div>

<style>
  .skeleton {
    background: var(--bg-tertiary);
    position: relative;
    overflow: hidden;
  }

  .skeleton::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(
      90deg,
      transparent 0%,
      var(--bg-hover) 50%,
      transparent 100%
    );
    animation: shimmer 1.5s infinite;
  }

  @keyframes shimmer {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(100%);
    }
  }
</style>
