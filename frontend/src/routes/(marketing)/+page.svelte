<script lang="ts">
  // Forum-first launch copy. Voice register: Bran :restrained.
  const pillars = [
    {
      sigil: '✦',
      title: 'Forums',
      line: 'Threaded talk that does not vanish. Searchable, archived, yours.'
    },
    {
      sigil: '◈',
      title: 'Real-time Chat',
      line: 'Discord-style channels. Same community, same login, no second tab.'
    },
    {
      sigil: '◐',
      title: 'Voice Rooms',
      line: 'Drop in, talk, leave. No scheduling, no install, no Discord invite.'
    },
    {
      sigil: '◇',
      title: 'Plugins',
      line: 'Extend the platform. Install, configure, ship. Your community, your shape.'
    }
  ];

  const tierPeek = [
    { name: 'Forum', price: 19, blurb: 'Forum + chat + voice. One community.' },
    { name: 'Community', price: 39, blurb: 'Subscriptions, custom roles, more storage.' }
  ];

  const whyStack = [
    {
      title: 'One login. One feed. One community.',
      line: 'Discord + Discourse + Twitch is three accounts, three notification streams, three places to lose your members. We are one.'
    },
    {
      title: 'Built on Phoenix / Elixir.',
      line: 'The same stack WhatsApp and Discord chose for chat at scale. Real-time, fault-tolerant, cheap to run.'
    },
    {
      title: 'We host. You build.',
      line: 'No servers to patch, no Postgres to back up, no Docker compose to debug at 2am. You write the rules; we keep the lights on.'
    },
    {
      title: 'Plugins, not lock-in.',
      line: 'Need a custom feature? Install one, or write one. Public marketplace, open extension points. Your data exports anytime.'
    }
  ];
</script>

<svelte:head>
  <title>ForgeNexus — Forum, chat, and voice for your community</title>
  <meta
    name="description"
    content="A modern community platform: forums + Discord-style chat + voice rooms + plugin marketplace, all under one login. We host. From $19/mo."
  />
  <meta property="og:title" content="ForgeNexus" />
  <meta
    property="og:description"
    content="Forum + chat + voice in one platform. Discord and Discourse, replaced. From $19/mo."
  />
</svelte:head>

<section class="gl-hero">
  <div class="gl-hero-inner">
    <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> A community platform, in one place</p>
    <h1 class="gl-h1">Your forum. Your chat. Your voice rooms. One login.</h1>
    <p class="gl-lede">
      For creators who want Discord and a forum without juggling two tools.
      For builders who want a community that doesn't disappear with the next
      platform's tide. We host. You shape it.
    </p>
    <div class="gl-hero-cta">
      <a href="/signup?tier=forum" class="gl-btn gl-btn-primary">▸ START FREE — 1 COMMUNITY</a>
      <a href="/pricing" class="gl-btn gl-btn-ghost">▸ SEE PRICING</a>
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

<section class="gl-why">
  <div class="gl-why-inner">
    <h2 class="gl-h2">Why this, not the others.</h2>
    <div class="gl-why-grid">
      {#each whyStack as w}
        <article class="gl-why-card">
          <h3 class="gl-why-title">{w.title}</h3>
          <p class="gl-why-line">{w.line}</p>
        </article>
      {/each}
    </div>
  </div>
</section>

<section class="gl-tier-peek">
  <div class="gl-tier-peek-inner">
    <h2 class="gl-h2">Two ways to start. Move when ready.</h2>
    <p class="gl-tier-peek-sub">
      Forum gets you running today. Community unlocks subscriptions, custom
      roles, and the dials creators reach for second.
    </p>
    <div class="gl-tier-row">
      {#each tierPeek as t}
        <div class="gl-tier-chip">
          <span class="gl-tier-chip-name">{t.name}</span>
          <span class="gl-tier-chip-price">${t.price}<span class="gl-mo">/mo</span></span>
          <span class="gl-tier-chip-blurb">{t.blurb}</span>
        </div>
      {/each}
    </div>
    <a href="/pricing" class="gl-btn gl-btn-primary gl-tier-peek-cta">▸ COMPARE PLANS</a>
  </div>
</section>

<section class="gl-close">
  <div class="gl-close-inner">
    <p class="gl-close-line">
      Live streaming and short-form video are on the roadmap, not the
      landing. We ship what works first, and only what works.
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

  .gl-tier-chip-blurb {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 13px;
    line-height: 1.45;
    color: var(--text-muted);
    margin-top: 10px;
    text-align: center;
    max-width: 180px;
  }

  /* Why-this */
  .gl-why {
    padding: 80px 36px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
    background: rgba(212, 175, 106, 0.015);
  }

  .gl-why-inner {
    max-width: 1100px;
    margin: 0 auto;
    text-align: center;
  }

  .gl-why-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 28px;
    margin-top: 40px;
    text-align: left;
  }

  .gl-why-card {
    padding: 22px 24px;
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 2px;
    background: rgba(0, 0, 0, 0.18);
  }

  .gl-why-title {
    font-family: 'Cinzel', serif;
    font-weight: 600;
    font-size: 15px;
    letter-spacing: 0.08em;
    color: #d4af6a;
    margin-bottom: 12px;
    line-height: 1.3;
  }

  .gl-why-line {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 15px;
    line-height: 1.55;
    color: var(--text-secondary);
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
    .gl-why { padding: 48px 18px; }
    .gl-tier-peek { padding: 48px 18px; }
    .gl-close { padding: 56px 18px 80px; }
    .gl-hero-cta { flex-direction: column; }
    .gl-hero-cta :global(.gl-btn) { width: 100%; justify-content: center; }
  }
</style>
