<script lang="ts">
  // Tier preview is intentionally short — full grid lives at /pricing.
  // Voice register: Bran :restrained — observation over menace, no full
  // godswood. Acquisition copy, not the deeper script.
  const pillars = [
    {
      sigil: '✦',
      title: 'Forums',
      line: 'A long table. Threaded talk that does not vanish at the end of the day.'
    },
    {
      sigil: '◐',
      title: 'Voice Rooms',
      line: 'Spaces to gather and speak — recorded if you say so, gone if you say not.'
    },
    {
      sigil: '▸',
      title: 'Calamity TV',
      line: 'Live streams from your hearth. The signal carries; the viewers remain.'
    },
    {
      sigil: '◊',
      title: 'Pulse',
      line: 'Short-form clips for what the hour demanded. Quick to share, slow to forget.'
    }
  ];

  const tierPeek = [
    { name: 'Forum', price: 19 },
    { name: 'Community', price: 39 },
    // TODO: tier-3 label TBD — placeholder 'Studio' until confirmed
    { name: 'Studio', price: 79 },
    // TODO: tier-4 label TBD — placeholder 'Network'
    { name: 'Network', price: 225 },
    // TODO: tier-5 label TBD — placeholder 'Fellowship'
    { name: 'Fellowship', price: 350 }
  ];
</script>

<svelte:head>
  <title>ForgeNexus — A place for communities that mean to stay</title>
  <meta
    name="description"
    content="ForgeNexus is a community platform: forums, voice rooms, live streaming, and short-form video — under one roof, for creators who plan to keep the hearth lit."
  />
  <meta property="og:title" content="ForgeNexus" />
  <meta
    property="og:description"
    content="Forums, voice, streams, and short clips — one community, four ways to gather."
  />
</svelte:head>

<section class="gl-hero">
  <div class="gl-hero-inner">
    <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> A community platform, built for permanence</p>
    <h1 class="gl-h1">Build a place where the hearth stays lit.</h1>
    <p class="gl-lede">
      Four ways to gather. Forums for the slow talk. Voice rooms for the long
      evenings. Calamity TV when the moment is worth watching. Pulse for what
      the hour demanded. One community, four shapes of presence.
    </p>
    <div class="gl-hero-cta">
      <a href="/pricing" class="gl-btn gl-btn-primary">▸ SEE PRICING</a>
      <a href="/signup?tier=forum" class="gl-btn gl-btn-ghost">▸ START FREE — 1 COMMUNITY</a>
    </div>
  </div>
</section>

<section class="gl-pillars">
  <div class="gl-pillars-inner">
    {#each pillars as p}
      <article class="gl-pillar">
        <span class="gl-pillar-sigil">{p.sigil}</span>
        <h3 class="gl-pillar-title">{p.title}</h3>
        <p class="gl-pillar-line">{p.line}</p>
      </article>
    {/each}
  </div>
</section>

<section class="gl-tier-peek">
  <div class="gl-tier-peek-inner">
    <h2 class="gl-h2">Five tiers. One ladder.</h2>
    <p class="gl-tier-peek-sub">
      From a single forum to a federation of houses. The price grows with
      what you can hold; the foundation does not change.
    </p>
    <div class="gl-tier-row">
      {#each tierPeek as t}
        <div class="gl-tier-chip">
          <span class="gl-tier-chip-name">{t.name}</span>
          <span class="gl-tier-chip-price">${t.price}<span class="gl-mo">/mo</span></span>
        </div>
      {/each}
    </div>
    <p class="gl-houses-line">
      Or a <a href="/signup/houses">House</a> — multi-creator from $149/mo.
    </p>
    <a href="/pricing" class="gl-btn gl-btn-primary gl-tier-peek-cta">▸ COMPARE THE LADDER</a>
  </div>
</section>

<section class="gl-close">
  <div class="gl-close-inner">
    <p class="gl-close-line">
      The godswoods remembered what was spoken under their leaves. We aim for
      the same — a place where what you build is not erased by the next
      platform's tide.
    </p>
    <div class="gl-close-cta">
      <a href="/signup?tier=forum" class="gl-btn gl-btn-primary">▸ BEGIN</a>
    </div>
  </div>
</section>

<style>
  .gl-fleur {
    color: #d4af6a;
    text-shadow: 0 0 12px rgba(212, 175, 106, 0.4);
  }

  /* Hero */
  .gl-hero {
    padding: 96px 36px 72px;
  }

  .gl-hero-inner {
    max-width: 920px;
    margin: 0 auto;
    text-align: center;
  }

  .gl-eyebrow {
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.24em;
    text-transform: uppercase;
    color: var(--text-secondary);
    margin-bottom: 28px;
  }

  .gl-h1 {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(36px, 6vw, 64px);
    line-height: 1.1;
    letter-spacing: 0.01em;
    color: var(--text-heading);
    margin-bottom: 24px;
    text-wrap: balance;
  }

  .gl-lede {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: clamp(17px, 1.6vw, 21px);
    line-height: 1.6;
    color: var(--text-secondary);
    max-width: 720px;
    margin: 0 auto 44px;
    text-wrap: pretty;
  }

  .gl-hero-cta {
    display: flex;
    gap: 14px;
    justify-content: center;
    flex-wrap: wrap;
  }

  /* Buttons */
  :global(.gl-btn) {
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.18em;
    padding: 14px 26px;
    border: 1px solid;
    border-radius: 2px;
    text-decoration: none;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    text-transform: uppercase;
  }

  :global(.gl-btn-primary) {
    background: rgba(212, 175, 106, 0.08);
    border-color: #d4af6a;
    color: #d4af6a;
  }

  :global(.gl-btn-primary:hover) {
    background: rgba(212, 175, 106, 0.18);
    box-shadow: 0 0 24px rgba(212, 175, 106, 0.2);
  }

  :global(.gl-btn-ghost) {
    border-color: rgba(255, 255, 255, 0.18);
    color: var(--text-secondary);
    background: transparent;
  }

  :global(.gl-btn-ghost:hover) {
    border-color: var(--text-primary);
    color: var(--text-primary);
  }

  /* Pillars */
  .gl-pillars {
    padding: 56px 36px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
  }

  .gl-pillars-inner {
    max-width: 1100px;
    margin: 0 auto;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 32px;
  }

  .gl-pillar {
    text-align: center;
  }

  .gl-pillar-sigil {
    display: inline-block;
    font-size: 28px;
    color: #d4af6a;
    margin-bottom: 14px;
  }

  .gl-pillar-title {
    font-family: 'Cinzel', serif;
    font-weight: 600;
    font-size: 18px;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--text-heading);
    margin-bottom: 12px;
  }

  .gl-pillar-line {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 16px;
    line-height: 1.5;
    color: var(--text-secondary);
  }

  /* Tier peek */
  .gl-tier-peek {
    padding: 80px 36px;
  }

  .gl-tier-peek-inner {
    max-width: 1100px;
    margin: 0 auto;
    text-align: center;
  }

  .gl-h2 {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(28px, 4vw, 40px);
    color: var(--text-heading);
    margin-bottom: 14px;
  }

  .gl-tier-peek-sub {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 17px;
    color: var(--text-secondary);
    max-width: 640px;
    margin: 0 auto 36px;
  }

  .gl-tier-row {
    display: flex;
    gap: 12px;
    justify-content: center;
    flex-wrap: wrap;
    margin-bottom: 28px;
  }

  .gl-tier-chip {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px 22px;
    border: 1px solid rgba(212, 175, 106, 0.2);
    border-radius: 2px;
    background: rgba(212, 175, 106, 0.03);
    min-width: 130px;
  }

  .gl-tier-chip-name {
    font-family: 'Cinzel', serif;
    font-size: 13px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: #d4af6a;
    margin-bottom: 8px;
  }

  .gl-tier-chip-price {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 24px;
    font-weight: 600;
    color: var(--text-heading);
  }

  .gl-mo {
    font-size: 12px;
    color: var(--text-muted);
    margin-left: 2px;
  }

  .gl-houses-line {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 16px;
    color: var(--text-secondary);
    margin-bottom: 28px;
  }

  .gl-houses-line :global(a) {
    color: #d4af6a;
    text-decoration: underline;
    text-decoration-color: rgba(212, 175, 106, 0.4);
  }

  /* Close */
  .gl-close {
    padding: 80px 36px 120px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
  }

  .gl-close-inner {
    max-width: 760px;
    margin: 0 auto;
    text-align: center;
  }

  .gl-close-line {
    font-family: 'EB Garamond', Georgia, serif;
    font-style: italic;
    font-size: 19px;
    line-height: 1.65;
    color: var(--text-secondary);
    margin-bottom: 36px;
  }

  @media (max-width: 720px) {
    .gl-hero { padding: 56px 18px 48px; }
    .gl-pillars { padding: 36px 18px; }
    .gl-tier-peek { padding: 48px 18px; }
    .gl-close { padding: 56px 18px 80px; }
    .gl-hero-cta { flex-direction: column; }
    .gl-hero-cta :global(.gl-btn) { width: 100%; justify-content: center; }
  }
</style>
