<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';

  type Community = {
    id: string;
    slug: string;
    name: string;
    description: string | null;
    banner_url: string | null;
    logo_url: string | null;
    plan: string;
    member_count: number;
  };

  let community = $state<Community | null>(null);
  let loading = $state(true);
  let notFound = $state(false);

  // Signup form
  let email = $state('');
  let password = $state('');
  let displayName = $state('');
  let acceptTos = $state(false);
  let submitting = $state(false);
  let serverError = $state<string | null>(null);
  let fieldErrors = $state<Record<string, string[]>>({});

  // Success state
  let joined = $state(false);

  let slug = $derived(page.params.slug);

  onMount(() => load());

  async function load() {
    try {
      const res = await fetch(`/api/communities/${encodeURIComponent(slug ?? '')}`, {
        credentials: 'include'
      });
      if (res.status === 404) {
        notFound = true;
        loading = false;
        return;
      }
      const body = await res.json();
      community = body.community;
    } catch (err) {
      notFound = true;
    }
    loading = false;
  }

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
      const res = await fetch(`/api/communities/${encodeURIComponent(slug ?? '')}/members/signup`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password,
          display_name: displayName
        })
      });
      const body = await res.json();

      if (!res.ok) {
        if (body.errors) fieldErrors = body.errors;
        serverError = body.error || 'Signup failed — review the form.';
        submitting = false;
        return;
      }

      joined = true;
      submitting = false;
    } catch (err) {
      serverError = 'Network error — try again in a moment.';
      submitting = false;
    }
  }
</script>

<svelte:head>
  <title>{community ? `Join ${community.name} — ForgeNexus` : 'ForgeNexus'}</title>
  {#if community?.description}
    <meta name="description" content={community.description} />
  {/if}
</svelte:head>

<div class="cj-page">
  {#if loading}
    <div class="cj-loading">⚜ Loading…</div>
  {:else if notFound}
    <div class="cj-notfound">
      <h1>Community not found</h1>
      <p>No community at <code>{slug}</code> on ForgeNexus.</p>
      <a href="/" class="cj-btn cj-btn-primary">▸ HOME</a>
    </div>
  {:else if community}
    <header class="cj-banner" style:background-image={community.banner_url ? `url(${community.banner_url})` : null}>
      <div class="cj-banner-inner">
        {#if community.logo_url}
          <img src={community.logo_url} alt="" class="cj-logo" />
        {:else}
          <div class="cj-logo cj-logo-fleur">⚜</div>
        {/if}
        <h1 class="cj-name">{community.name}</h1>
        {#if community.description}
          <p class="cj-desc">{community.description}</p>
        {/if}
        <p class="cj-meta">
          {community.member_count.toLocaleString()} member{community.member_count === 1 ? '' : 's'}
        </p>
      </div>
    </header>

    <section class="cj-signup">
      {#if joined}
        <div class="cj-success">
          <p class="cj-eyebrow"><span class="cj-fleur">⚜</span> Welcome</p>
          <h2>You're in.</h2>
          <p class="cj-success-line">
            You've joined the {community.name} community. Step in and look
            around — the hearth is lit.
          </p>
          <a href="/forums" class="cj-btn cj-btn-primary">▸ ENTER</a>
        </div>
      {:else}
        <div class="cj-signup-inner">
          <p class="cj-eyebrow"><span class="cj-fleur">⚜</span> Free to join</p>
          <h2>Join {community.name}</h2>
          <p class="cj-signup-sub">
            Create a free account scoped to this community. No card required.
          </p>

          <form class="cj-form" onsubmit={submit}>
            <fieldset disabled={submitting}>
              <div class="cj-field">
                <label for="email">Your email</label>
                <input id="email" type="email" required bind:value={email} autocomplete="email" />
                {#if fieldErrors.email}<p class="cj-err">{fieldErrors.email.join(', ')}</p>{/if}
              </div>

              <div class="cj-field">
                <label for="display_name">Display name</label>
                <input id="display_name" type="text" required bind:value={displayName} maxlength="40" />
                <p class="cj-hint">How you'll appear inside {community.name}.</p>
              </div>

              <div class="cj-field">
                <label for="password">Password</label>
                <input id="password" type="password" required bind:value={password} minlength="8" autocomplete="new-password" />
                {#if fieldErrors.password}<p class="cj-err">{fieldErrors.password.join(', ')}</p>{/if}
              </div>

              <label class="cj-tos">
                <input type="checkbox" bind:checked={acceptTos} />
                <span>I agree to the <a href="/terms" target="_blank">Terms</a> and <a href="/privacy" target="_blank">Privacy Policy</a>.</span>
              </label>

              {#if serverError}<p class="cj-err cj-err-top">{serverError}</p>{/if}

              <button type="submit" class="cj-btn cj-btn-primary cj-submit" disabled={submitting}>
                {submitting ? '▸ JOINING…' : '▸ JOIN ' + community.name.toUpperCase()}
              </button>
            </fieldset>
          </form>
        </div>
      {/if}
    </section>
  {/if}
</div>

<style>
  .cj-page {
    min-height: 100vh;
    background: var(--bg-primary);
    color: var(--text-primary);
    font-family: 'EB Garamond', Georgia, 'Times New Roman', serif;
  }

  .cj-fleur { color: #d4af6a; text-shadow: 0 0 12px rgba(212, 175, 106, 0.4); }

  .cj-loading,
  .cj-notfound {
    min-height: 60vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: 16px;
    padding: 36px;
  }
  .cj-notfound h1 {
    font-family: 'Cinzel', serif;
    font-size: 28px;
    margin: 0;
  }
  .cj-notfound code {
    background: rgba(255, 255, 255, 0.05);
    padding: 2px 8px;
    border-radius: 2px;
  }

  .cj-banner {
    position: relative;
    padding: 88px 24px 56px;
    background-color: rgba(15, 23, 38, 0.6);
    background-size: cover;
    background-position: center;
    text-align: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .cj-banner::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(180deg, rgba(6, 9, 15, 0.5), rgba(6, 9, 15, 0.85));
    pointer-events: none;
  }
  .cj-banner-inner {
    position: relative;
    z-index: 1;
    max-width: 720px;
    margin: 0 auto;
  }

  .cj-logo {
    width: 72px;
    height: 72px;
    object-fit: cover;
    border-radius: 50%;
    border: 2px solid rgba(212, 175, 106, 0.4);
    background: var(--bg-secondary);
    margin-bottom: 18px;
    display: inline-block;
  }
  .cj-logo-fleur {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 38px;
    color: #d4af6a;
  }

  .cj-name {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(28px, 4.5vw, 42px);
    color: var(--text-heading);
    margin: 0 0 12px;
    letter-spacing: 0.04em;
  }
  .cj-desc {
    font-size: 17px;
    color: var(--text-secondary);
    line-height: 1.55;
    margin: 0 0 16px;
  }
  .cj-meta {
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--text-muted);
    margin: 0;
  }

  .cj-signup {
    padding: 56px 24px 96px;
  }
  .cj-signup-inner,
  .cj-success {
    max-width: 480px;
    margin: 0 auto;
  }

  .cj-eyebrow {
    font-family: 'Cinzel', serif;
    font-size: 11px;
    letter-spacing: 0.22em;
    text-transform: uppercase;
    color: var(--text-secondary);
    text-align: center;
    margin-bottom: 16px;
  }

  .cj-signup h2,
  .cj-success h2 {
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(24px, 3.5vw, 32px);
    color: var(--text-heading);
    text-align: center;
    margin: 0 0 12px;
  }

  .cj-signup-sub,
  .cj-success-line {
    font-size: 16px;
    color: var(--text-secondary);
    text-align: center;
    margin-bottom: 32px;
    line-height: 1.55;
  }

  .cj-form fieldset {
    border: 0;
    padding: 0;
    margin: 0;
  }
  .cj-form fieldset[disabled] { opacity: 0.55; }

  .cj-field { margin-bottom: 18px; }
  .cj-field label {
    display: block;
    font-family: 'Cinzel', serif;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }
  .cj-field input {
    width: 100%;
    padding: 12px 14px;
    background: var(--bg-input);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    color: var(--text-primary);
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 16px;
    box-sizing: border-box;
  }
  .cj-field input:focus {
    outline: 0;
    border-color: #d4af6a;
    box-shadow: 0 0 0 3px rgba(212, 175, 106, 0.12);
  }

  .cj-hint {
    font-size: 13px;
    color: var(--text-muted);
    margin-top: 6px;
  }

  .cj-tos {
    display: flex;
    gap: 10px;
    margin: 12px 0 22px;
    font-size: 14px;
    color: var(--text-secondary);
  }
  .cj-tos a { color: #d4af6a; }

  .cj-err {
    font-size: 13px;
    color: #ef4444;
    margin-top: 6px;
  }
  .cj-err-top {
    padding: 10px 12px;
    margin: 12px 0;
    background: rgba(239, 68, 68, 0.06);
    border: 1px solid rgba(239, 68, 68, 0.2);
    border-radius: 2px;
  }

  .cj-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-family: 'Cinzel', serif;
    font-size: 12px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    padding: 14px 26px;
    border: 1px solid;
    border-radius: 2px;
    text-decoration: none;
    cursor: pointer;
    transition: all 0.2s;
  }
  .cj-btn-primary {
    background: rgba(212, 175, 106, 0.1);
    border-color: #d4af6a;
    color: #d4af6a;
  }
  .cj-btn-primary:hover:not(:disabled) {
    background: rgba(212, 175, 106, 0.2);
    box-shadow: 0 0 24px rgba(212, 175, 106, 0.2);
  }
  .cj-btn-primary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .cj-submit { width: 100%; }

  .cj-success {
    text-align: center;
  }
</style>
