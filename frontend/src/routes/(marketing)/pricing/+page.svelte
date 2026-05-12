<script lang="ts">
  // Tier 1 / 2: labels CONFIRMED. Tiers 3-5: placeholder names — TODO
  // confirm with marketing before launch. Plan slugs (forum/community/
  // creator/platform/enterprise) match Communities.Community @plans
  // already in the schema, so no migration churn.
  type Tier = {
    slug: string;
    name: string;
    nameTodo?: string;
    price: number;
    tagline: string;
    features: string[];
    cta: string;
    accent?: boolean;
  };

  const tiers: Tier[] = [
    {
      slug: 'forum',
      name: 'Forum',
      price: 19,
      tagline: 'A long table. One forum, one voice.',
      features: [
        'One community, one forum',
        'Threaded talk, no time limit',
        'Member profiles + custom themes',
        '50-member soft cap',
        'Custom subdomain'
      ],
      cta: '▸ START FREE — 1 COMMUNITY'
    },
    {
      slug: 'community',
      name: 'Community',
      price: 39,
      tagline: 'When the hearth needs more rooms.',
      features: [
        'Everything in Forum',
        'Multi-forum + sub-forums',
        'Voice rooms (live or scheduled)',
        'Custom emojis, badges, roles',
        '500-member soft cap',
        'Polls, reactions, reputation'
      ],
      cta: '▸ START 14-DAY FREE TRIAL'
    },
    {
      // TODO: label TBD — placeholder 'Studio'. Plan slug remains 'creator'.
      slug: 'creator',
      name: 'Studio',
      nameTodo: 'tier-3 label',
      price: 79,
      tagline: 'For the creator who broadcasts.',
      features: [
        'Everything in Community',
        'Calamity TV streaming (RTMP in, HLS out)',
        'Pulse short-form video',
        'Channel-point economy',
        'Affiliate gate → enable subscriptions',
        'Voice room recordings + clipping',
        '2 500-member soft cap'
      ],
      cta: '▸ START 14-DAY FREE TRIAL',
      accent: true
    },
    {
      // TODO: label TBD — placeholder 'Network'. Plan slug remains 'platform'.
      slug: 'platform',
      name: 'Network',
      nameTodo: 'tier-4 label',
      price: 225,
      tagline: 'A federation under one banner.',
      features: [
        'Everything in Studio',
        'Cross-community syndication',
        'No-code automation flows',
        'JS/Deno plugin runtime',
        'Marketplace listings + revenue share',
        '10 000-member soft cap',
        'Priority support'
      ],
      cta: '▸ START 14-DAY FREE TRIAL'
    },
    {
      // TODO: label TBD — placeholder 'Fellowship'. Plan slug remains 'enterprise'.
      slug: 'enterprise',
      name: 'Fellowship',
      nameTodo: 'tier-5 label',
      price: 350,
      tagline: 'White-label, no ceiling.',
      features: [
        'Everything in Network',
        'White-label (your brand, our spine)',
        'Custom domain + SSO',
        'ActivityPub federation',
        'Unlimited members',
        'Dedicated success contact',
        'Custom integrations'
      ],
      cta: '▸ START 14-DAY FREE TRIAL'
    }
  ];
</script>

<svelte:head>
  <title>Pricing — ForgeNexus</title>
  <meta name="description" content="Five tiers, one ladder. From $19/mo forum to $350/mo white-label. Or a House — multi-creator collective from $149/mo." />
</svelte:head>

<section class="gl-px-hero">
  <div class="gl-px-hero-inner">
    <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> The ladder</p>
    <h1 class="gl-h1">Pick the tier the hearth can hold.</h1>
    <p class="gl-lede">
      Each tier inherits the one below. You can climb when the community
      grows; you can step down when it does not. 14-day trial on every
      paid tier. No card on the free start.
    </p>
  </div>
</section>

<section class="gl-px-grid-section">
  <div class="gl-px-grid">
    {#each tiers as t}
      <article class="gl-px-card" class:gl-px-accent={t.accent}>
        <header class="gl-px-card-head">
          <h3 class="gl-px-card-name">
            {t.name}
            {#if t.nameTodo}<!-- TODO: {t.nameTodo} pending marketing -->{/if}
          </h3>
          <p class="gl-px-card-tagline">{t.tagline}</p>
          <div class="gl-px-card-price">
            <span class="gl-px-dollar">$</span>{t.price}<span class="gl-px-mo">/mo</span>
          </div>
        </header>
        <ul class="gl-px-features">
          {#each t.features as feat}
            <li><span class="gl-px-bullet">⚜</span>{feat}</li>
          {/each}
        </ul>
        <a href="/signup?tier={t.slug}" class="gl-btn gl-btn-primary gl-px-card-cta">
          {t.cta}
        </a>
      </article>
    {/each}
  </div>
</section>

<section class="gl-px-houses">
  <div class="gl-px-houses-inner">
    <div class="gl-px-houses-meta">
      <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> A different shape</p>
      <h2 class="gl-h2">Houses — for collectives.</h2>
      <p class="gl-px-houses-body">
        A House is a multi-creator collective under one banner. One billing
        spine, many voices. Founders set the rules; invited creators share
        the hearth. Built for the kind of work that doesn't fit a single
        name above the door.
      </p>
      <ul class="gl-px-houses-features">
        <li><span class="gl-px-bullet">⚜</span>$149/mo base — founder + first creator</li>
        <li><span class="gl-px-bullet">⚜</span>$25/mo per additional creator</li>
        <li><span class="gl-px-bullet">⚜</span>Shared revenue split across the collective</li>
        <li><span class="gl-px-bullet">⚜</span>One forum, one voice presence, many faces</li>
        <li><span class="gl-px-bullet">⚜</span>Enterprise Houses from $450/mo — talk to us</li>
      </ul>
      <div class="gl-px-houses-cta">
        <a href="/signup/houses" class="gl-btn gl-btn-primary">▸ FOUND A HOUSE</a>
        <a href="/contact" class="gl-btn gl-btn-ghost">▸ ENTERPRISE</a>
      </div>
    </div>
    <div class="gl-px-houses-sigil" aria-hidden="true">
      <span class="gl-px-big-fleur">⚜</span>
    </div>
  </div>
</section>

<style>
  .gl-fleur { color: #d4af6a; text-shadow: 0 0 12px rgba(212, 175, 106, 0.4); }

  .gl-px-hero { padding: 80px 36px 48px; text-align: center; }
  .gl-px-hero-inner { max-width: 820px; margin: 0 auto; }

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
    font-size: clamp(32px, 5vw, 52px);
    line-height: 1.15;
    color: var(--text-heading);
    margin-bottom: 22px;
  }

  .gl-h2 {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(28px, 4vw, 40px);
    color: var(--text-heading);
    margin-bottom: 16px;
  }

  .gl-lede {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 18px;
    line-height: 1.6;
    color: var(--text-secondary);
    max-width: 680px;
    margin: 0 auto;
  }

  /* Tier grid */
  .gl-px-grid-section { padding: 32px 36px 80px; }

  .gl-px-grid {
    max-width: 1320px;
    margin: 0 auto;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(232px, 1fr));
    gap: 16px;
  }

  .gl-px-card {
    border: 1px solid rgba(255, 255, 255, 0.06);
    background: rgba(15, 23, 38, 0.4);
    border-radius: 3px;
    padding: 28px 22px;
    display: flex;
    flex-direction: column;
    transition: all 0.25s;
  }

  .gl-px-card:hover {
    border-color: rgba(212, 175, 106, 0.3);
    background: rgba(212, 175, 106, 0.03);
  }

  .gl-px-card.gl-px-accent {
    border-color: rgba(212, 175, 106, 0.4);
    background: linear-gradient(180deg, rgba(212, 175, 106, 0.06), rgba(15, 23, 38, 0.4));
    box-shadow: 0 0 32px rgba(212, 175, 106, 0.08);
  }

  .gl-px-card-head {
    margin-bottom: 22px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    padding-bottom: 18px;
  }

  .gl-px-card-name {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: 20px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--text-heading);
    margin-bottom: 8px;
  }

  .gl-px-card-tagline {
    font-family: 'EB Garamond', Georgia, serif;
    font-style: italic;
    font-size: 14px;
    color: var(--text-secondary);
    margin-bottom: 18px;
    min-height: 2.6em;
  }

  .gl-px-card-price {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 44px;
    font-weight: 600;
    color: var(--text-heading);
    line-height: 1;
  }

  .gl-px-dollar {
    font-size: 24px;
    color: var(--text-secondary);
    vertical-align: top;
    margin-right: 2px;
  }

  .gl-px-mo {
    font-size: 14px;
    color: var(--text-muted);
    font-weight: 400;
    margin-left: 4px;
  }

  .gl-px-features {
    list-style: none;
    margin: 0 0 28px;
    padding: 0;
    flex: 1;
  }

  .gl-px-features li {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 15px;
    line-height: 1.5;
    color: var(--text-secondary);
    padding: 6px 0;
    display: flex;
    gap: 10px;
    align-items: flex-start;
  }

  .gl-px-bullet {
    color: #d4af6a;
    font-size: 12px;
    line-height: 1.6;
    flex-shrink: 0;
  }

  .gl-px-card-cta {
    width: 100%;
    justify-content: center;
    font-size: 11px !important;
  }

  /* Houses */
  .gl-px-houses {
    padding: 64px 36px 120px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
    background: radial-gradient(ellipse at center, rgba(212, 175, 106, 0.04), transparent 70%);
  }

  .gl-px-houses-inner {
    max-width: 1100px;
    margin: 0 auto;
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 56px;
    align-items: center;
  }

  .gl-px-houses-body {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 17px;
    line-height: 1.6;
    color: var(--text-secondary);
    margin-bottom: 24px;
  }

  .gl-px-houses-features {
    list-style: none;
    padding: 0;
    margin: 0 0 32px;
  }

  .gl-px-houses-features li {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 16px;
    color: var(--text-secondary);
    padding: 5px 0;
    display: flex;
    gap: 10px;
  }

  .gl-px-houses-cta { display: flex; gap: 14px; flex-wrap: wrap; }

  .gl-px-houses-sigil {
    text-align: center;
  }

  .gl-px-big-fleur {
    font-size: 200px;
    color: #d4af6a;
    text-shadow: 0 0 64px rgba(212, 175, 106, 0.3);
    line-height: 1;
    opacity: 0.7;
  }

  @media (max-width: 900px) {
    .gl-px-houses-inner { grid-template-columns: 1fr; }
    .gl-px-houses-sigil { display: none; }
  }

  @media (max-width: 720px) {
    .gl-px-hero { padding: 48px 18px 32px; }
    .gl-px-grid-section { padding: 24px 18px 56px; }
    .gl-px-houses { padding: 48px 18px 80px; }
  }
</style>
