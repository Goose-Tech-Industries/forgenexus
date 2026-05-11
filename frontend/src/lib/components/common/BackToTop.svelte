<script lang="ts">
  let visible = $state(false);

  function handleScroll() {
    visible = window.scrollY > 400;
  }

  function scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  $effect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  });
</script>

<button
  class="back-to-top"
  class:visible
  onclick={scrollToTop}
  aria-label="Back to top"
  title="Back to top"
>
  &#9650;
</button>

<style>
  .back-to-top {
    position: fixed;
    bottom: 24px;
    right: 24px;
    z-index: 50;
    width: 42px;
    height: 42px;
    border-radius: 50%;
    border: none;
    background: var(--accent);
    color: var(--bg-primary);
    font-size: 18px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    opacity: 0;
    pointer-events: none;
    transform: translateY(12px);
    transition: opacity 0.25s ease, transform 0.25s ease, background 0.15s ease;
  }

  .back-to-top.visible {
    opacity: 1;
    pointer-events: auto;
    transform: translateY(0);
  }

  .back-to-top:hover {
    background: var(--accent-hover);
  }

  /* Shift up when chatbar is present */
  :global(.app-shell:not(.no-chatbar)) .back-to-top {
    bottom: calc(var(--chatbar-height, 48px) + 24px);
  }
</style>
