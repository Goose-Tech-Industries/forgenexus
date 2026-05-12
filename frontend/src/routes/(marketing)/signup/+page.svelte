<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { goto } from '$app/navigation';

  // Plan slug -> display labels. Tiers 3-5 names are placeholders pending
  // marketing confirmation; backend plan slug stays canonical.
  const tierMeta: Record<string, { name: string; price: number; trialLabel: string }> = {
    forum:      { name: 'Forum',      price: 19,  trialLabel: '30-day free start' },
    community:  { name: 'Community',  price: 39,  trialLabel: '14-day free trial' },
    creator:    { name: 'Studio',     price: 79,  trialLabel: '14-day free trial' },
    platform:   { name: 'Network',    price: 225, trialLabel: '14-day free trial' },
    enterprise: { name: 'Fellowship', price: 350, trialLabel: '14-day free trial' }
  };

  let tier = $state('forum');
  let email = $state('');
  let password = $state('');
  let username = $state('');
  let communityName = $state('');
  let communitySlug = $state('');
  let acceptTos = $state(false);
  let submitting = $state(false);
  let serverError = $state<string | null>(null);
  let fieldErrors = $state<Record<string, string[]>>({});

  onMount(() => {
    const t = page.url.searchParams.get('tier');
    if (t && tierMeta[t]) tier = t;
  });

  // Auto-derive slug from community name. User can still edit it directly.
  let slugDirty = $state(false);
  $effect(() => {
    if (!slugDirty) {
      communitySlug = communityName
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .slice(0, 63);
    }
  });

  let meta = $derived(tierMeta[tier] ?? tierMeta.forum);

  async function submit(e: Event) {
    e.preventDefault();
    serverError = null;
    fieldErrors = {};

    if (!acceptTos) {
      serverError = 'You must accept the terms to continue.';
      return;
    }

    submitting = true;
    try {
      const res = await fetch('/api/signup/tier', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password,
          username,
          community_slug: communitySlug,
          community_name: communityName,
          plan: tier
        })
      });

      const body = await res.json();

      if (!res.ok) {
        if (body.errors) fieldErrors = body.errors;
        serverError = body.error || 'Signup failed — review the form and try again.';
        submitting = false;
        return;
      }

      // Stripe Checkout takes precedence — payment trial starts there. If
      // Stripe isn't wired for this plan, drop into the community itself.
      if (body.checkout_url) {
        window.location.href = body.checkout_url;
      } else {
        const url = body.community_url || `/c/${body.community_slug}`;
        window.location.href = url;
      }
    } catch (err) {
      serverError = 'Network error — try again in a moment.';
      submitting = false;
    }
  }
</script>

<svelte:head>
  <title>Begin — ForgeNexus</title>
  <meta name="description" content="Stand up your community. Free start, no card required up front." />
</svelte:head>

<section class="gl-su">
  <div class="gl-su-inner">
    <header class="gl-su-head">
      <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> Step one</p>
      <h1 class="gl-h1">Light the hearth.</h1>
      <div class="gl-su-tier-pill">
        <span class="gl-su-tier-name">{meta.name}</span>
        <span class="gl-su-tier-sep">·</span>
        <span class="gl-su-tier-price">${meta.price}/mo</span>
        <span class="gl-su-tier-sep">·</span>
        <span class="gl-su-tier-trial">{meta.trialLabel}</span>
        <a href="/pricing" class="gl-su-tier-change">change</a>
      </div>
    </header>

    <form class="gl-su-form" onsubmit={submit}>
      <fieldset disabled={submitting}>
        <div class="gl-su-field">
          <label for="email">Your email</label>
          <input id="email" type="email" required bind:value={email} autocomplete="email" />
          {#if fieldErrors.email}<p class="gl-su-err">{fieldErrors.email.join(', ')}</p>{/if}
        </div>

        <div class="gl-su-field">
          <label for="username">Your username</label>
          <input id="username" type="text" required bind:value={username} pattern="[a-zA-Z0-9_-]+" autocomplete="username" />
          <p class="gl-su-hint">Letters, numbers, underscore, hyphen. 3–25 chars.</p>
          {#if fieldErrors.username}<p class="gl-su-err">{fieldErrors.username.join(', ')}</p>{/if}
        </div>

        <div class="gl-su-field">
          <label for="password">Password</label>
          <input id="password" type="password" required bind:value={password} minlength="8" autocomplete="new-password" />
          <p class="gl-su-hint">8+ characters. Avoid passwords you've used elsewhere.</p>
          {#if fieldErrors.password}<p class="gl-su-err">{fieldErrors.password.join(', ')}</p>{/if}
        </div>

        <div class="gl-su-divider"><span>Your community</span></div>

        <div class="gl-su-field">
          <label for="community_name">Community name</label>
          <input id="community_name" type="text" required bind:value={communityName} />
          {#if fieldErrors.name}<p class="gl-su-err">{fieldErrors.name.join(', ')}</p>{/if}
        </div>

        <div class="gl-su-field">
          <label for="community_slug">Subdomain</label>
          <div class="gl-su-slug-row">
            <input
              id="community_slug"
              type="text"
              required
              pattern="[a-z0-9-]+"
              minlength="3"
              maxlength="63"
              bind:value={communitySlug}
              oninput={() => (slugDirty = true)}
            />
            <span class="gl-su-slug-suffix">.forgenexus.com</span>
          </div>
          {#if fieldErrors.slug}<p class="gl-su-err">{fieldErrors.slug.join(', ')}</p>{/if}
          {#if fieldErrors.subdomain}<p class="gl-su-err">subdomain: {fieldErrors.subdomain.join(', ')}</p>{/if}
        </div>

        <label class="gl-su-tos">
          <input type="checkbox" bind:checked={acceptTos} />
          <span>I agree to the <a href="/terms" target="_blank">Terms</a> and <a href="/privacy" target="_blank">Privacy Policy</a>.</span>
        </label>

        {#if serverError}<p class="gl-su-err gl-su-err-top">{serverError}</p>{/if}

        <button type="submit" class="gl-btn gl-btn-primary gl-su-submit" disabled={submitting}>
          {#if submitting}
            ▸ STANDING UP YOUR COMMUNITY…
          {:else if tier === 'forum'}
            ▸ START FREE — 1 COMMUNITY
          {:else}
            ▸ START 14-DAY FREE TRIAL
          {/if}
        </button>

        <p class="gl-su-foot-note">
          You'll be redirected to Stripe to add a payment method (no charge
          during trial). Cancel any time before the trial ends.
        </p>
      </fieldset>
    </form>
  </div>
</section>

<style>
  .gl-fleur { color: #d4af6a; text-shadow: 0 0 12px rgba(212, 175, 106, 0.4); }
  .gl-eyebrow {
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.24em;
    text-transform: uppercase;
    color: var(--text-secondary);
    margin-bottom: 22px;
  }
  .gl-h1 {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(30px, 4.5vw, 44px);
    color: var(--text-heading);
    margin-bottom: 22px;
  }

  .gl-su { padding: 64px 24px 120px; }
  .gl-su-inner { max-width: 540px; margin: 0 auto; }
  .gl-su-head { text-align: center; margin-bottom: 36px; }

  .gl-su-tier-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border: 1px solid rgba(212, 175, 106, 0.3);
    border-radius: 2px;
    background: rgba(212, 175, 106, 0.05);
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 15px;
    color: var(--text-secondary);
  }

  .gl-su-tier-name { color: #d4af6a; font-weight: 600; }
  .gl-su-tier-sep { color: var(--text-muted); }
  .gl-su-tier-change { color: var(--text-muted); font-size: 12px; margin-left: 6px; }
  .gl-su-tier-change:hover { color: #d4af6a; }

  .gl-su-form fieldset { border: 0; padding: 0; margin: 0; }
  .gl-su-form fieldset[disabled] { opacity: 0.55; }

  .gl-su-field { margin-bottom: 18px; }
  .gl-su-field label {
    display: block;
    font-family: 'Cinzel', serif;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }

  .gl-su-field input[type="text"],
  .gl-su-field input[type="email"],
  .gl-su-field input[type="password"] {
    width: 100%;
    padding: 12px 14px;
    background: var(--bg-input);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    color: var(--text-primary);
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 16px;
  }

  .gl-su-field input:focus {
    outline: 0;
    border-color: #d4af6a;
    box-shadow: 0 0 0 3px rgba(212, 175, 106, 0.12);
  }

  .gl-su-slug-row {
    display: flex;
    align-items: stretch;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    overflow: hidden;
  }
  .gl-su-slug-row input {
    flex: 1;
    border: 0 !important;
    border-radius: 0 !important;
  }
  .gl-su-slug-suffix {
    padding: 12px 14px;
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-muted);
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 14px;
    border-left: 1px solid rgba(255, 255, 255, 0.1);
  }

  .gl-su-hint {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 13px;
    color: var(--text-muted);
    margin-top: 6px;
  }

  .gl-su-divider {
    text-align: center;
    margin: 28px 0 18px;
    position: relative;
  }
  .gl-su-divider::before {
    content: '';
    position: absolute;
    left: 0; right: 0; top: 50%;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
  }
  .gl-su-divider span {
    position: relative;
    background: var(--bg-primary);
    padding: 0 14px;
    font-family: 'Cinzel', serif;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--text-muted);
  }

  .gl-su-tos {
    display: flex;
    gap: 10px;
    margin: 14px 0 22px;
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 14px;
    color: var(--text-secondary);
  }
  .gl-su-tos a { color: #d4af6a; }

  .gl-su-err {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 13px;
    color: #ef4444;
    margin-top: 6px;
  }
  .gl-su-err-top {
    margin: 12px 0 0;
    padding: 10px 12px;
    background: rgba(239, 68, 68, 0.06);
    border: 1px solid rgba(239, 68, 68, 0.2);
    border-radius: 2px;
  }

  .gl-su-submit {
    width: 100%;
    justify-content: center;
    margin-top: 8px;
  }

  .gl-su-foot-note {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 13px;
    color: var(--text-muted);
    text-align: center;
    margin-top: 18px;
    line-height: 1.5;
  }
</style>
