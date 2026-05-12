<script lang="ts">
  let founderEmail = $state('');
  let founderPassword = $state('');
  let founderUsername = $state('');
  let houseName = $state('');
  let houseSlug = $state('');
  let creatorEmails = $state(''); // newline / comma separated
  let acceptTos = $state(false);

  let submitting = $state(false);
  let serverError = $state<string | null>(null);
  let fieldErrors = $state<Record<string, string[]>>({});

  // Result panel state
  let result = $state<null | {
    community_slug: string;
    monthly_cents: number;
    creator_count: number;
    invitations: Array<{ email: string; accept_url: string }>;
    stripe_status: string;
  }>(null);

  // Auto-derive slug from house name
  let slugDirty = $state(false);
  $effect(() => {
    if (!slugDirty) {
      houseSlug = houseName
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .slice(0, 63);
    }
  });

  let parsedEmails = $derived(
    creatorEmails
      .split(/[,\n;]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0)
  );

  let pricePreview = $derived.by(() => {
    const base = 149;
    const extra = parsedEmails.length;
    return { base, extra, total: base + extra * 25 };
  });

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
      const res = await fetch('/api/signup/houses', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          founder_email: founderEmail,
          founder_password: founderPassword,
          founder_username: founderUsername,
          house_name: houseName,
          house_slug: houseSlug,
          creator_emails: parsedEmails
        })
      });
      const body = await res.json();

      if (!res.ok) {
        if (body.errors) fieldErrors = body.errors;
        serverError = body.error || 'House signup failed — review the form.';
        submitting = false;
        return;
      }

      result = body;
      submitting = false;
    } catch (err) {
      serverError = 'Network error — try again in a moment.';
      submitting = false;
    }
  }

  function copy(url: string) {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      navigator.clipboard.writeText(url).catch(() => {});
    }
  }
</script>

<svelte:head>
  <title>Found a House — ForgeNexus</title>
  <meta name="description" content="Stand up a multi-creator collective. Shared hearth, many faces." />
</svelte:head>

<section class="gl-hs">
  <div class="gl-hs-inner">
    {#if !result}
      <header class="gl-hs-head">
        <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> Houses</p>
        <h1 class="gl-h1">Found a House.</h1>
        <p class="gl-lede">
          One banner, many voices. You set the rules. Invited creators share
          the hearth. Pricing is $149/mo for the founder plus $25/mo for
          each additional creator you invite.
        </p>
      </header>

      <form class="gl-hs-form" onsubmit={submit}>
        <fieldset disabled={submitting}>
          <div class="gl-hs-section">
            <h3>Founder</h3>
            <div class="gl-hs-field">
              <label for="f_email">Your email</label>
              <input id="f_email" type="email" required bind:value={founderEmail} autocomplete="email" />
              {#if fieldErrors.email}<p class="gl-su-err">{fieldErrors.email.join(', ')}</p>{/if}
            </div>
            <div class="gl-hs-field">
              <label for="f_username">Your username</label>
              <input id="f_username" type="text" required bind:value={founderUsername} pattern="[a-zA-Z0-9_-]+" autocomplete="username" />
            </div>
            <div class="gl-hs-field">
              <label for="f_password">Password</label>
              <input id="f_password" type="password" required bind:value={founderPassword} minlength="8" autocomplete="new-password" />
            </div>
          </div>

          <div class="gl-hs-section">
            <h3>House</h3>
            <div class="gl-hs-field">
              <label for="h_name">House name</label>
              <input id="h_name" type="text" required bind:value={houseName} />
            </div>
            <div class="gl-hs-field">
              <label for="h_slug">Subdomain</label>
              <div class="gl-hs-slug-row">
                <input
                  id="h_slug"
                  type="text"
                  required
                  pattern="[a-z0-9-]+"
                  minlength="3"
                  maxlength="63"
                  bind:value={houseSlug}
                  oninput={() => (slugDirty = true)}
                />
                <span class="gl-hs-slug-suffix">.forgenexus.com</span>
              </div>
            </div>
          </div>

          <div class="gl-hs-section">
            <h3>Additional creators (optional)</h3>
            <p class="gl-hs-section-hint">
              One email per line, or comma-separated. Each creator gets a
              tokenized invite link valid for 14 days.
            </p>
            <textarea
              bind:value={creatorEmails}
              rows="4"
              placeholder="alice@example.com&#10;bob@example.com"
            ></textarea>
          </div>

          <div class="gl-hs-price-preview">
            <div class="gl-hs-pp-line">
              <span>Base (founder + 1 slot)</span>
              <strong>${pricePreview.base}/mo</strong>
            </div>
            <div class="gl-hs-pp-line">
              <span>Additional creators ({pricePreview.extra} × $25)</span>
              <strong>${pricePreview.extra * 25}/mo</strong>
            </div>
            <div class="gl-hs-pp-total">
              <span>Estimated total</span>
              <strong>${pricePreview.total}/mo</strong>
            </div>
          </div>

          <label class="gl-su-tos">
            <input type="checkbox" bind:checked={acceptTos} />
            <span>I agree to the <a href="/terms" target="_blank">Terms</a> and <a href="/privacy" target="_blank">Privacy Policy</a>.</span>
          </label>

          {#if serverError}<p class="gl-su-err gl-su-err-top">{serverError}</p>{/if}

          <button type="submit" class="gl-btn gl-btn-primary gl-su-submit" disabled={submitting}>
            {#if submitting}
              ▸ FOUNDING…
            {:else}
              ▸ FOUND THE HOUSE
            {/if}
          </button>
        </fieldset>
      </form>
    {:else}
      <header class="gl-hs-head">
        <p class="gl-eyebrow"><span class="gl-fleur">⚜</span> Founded</p>
        <h1 class="gl-h1">The hearth is lit.</h1>
        <p class="gl-lede">
          Your House at <strong>{result.community_slug}.forgenexus.com</strong> is live in
          trial mode. Hand each creator their link below — invitations also
          went out by email (best-effort). Each link expires in 14 days.
        </p>
        {#if result.stripe_status === 'not_configured'}
          <p class="gl-hs-banner">
            ⚜ Billing for Houses isn't wired through Stripe yet. Your House is
            in trial. Finish billing setup from the dashboard once your
            estimated <strong>${(result.monthly_cents / 100).toFixed(0)}/mo</strong> price
            ({result.creator_count} additional creators) is approved.
          </p>
        {/if}
      </header>

      {#if result.invitations.length === 0}
        <p class="gl-hs-no-invites">
          No additional creators yet — you can invite them later from the
          House dashboard.
        </p>
      {:else}
        <div class="gl-hs-invites">
          <h3>Invitation links</h3>
          {#each result.invitations as inv}
            <div class="gl-hs-invite">
              <div class="gl-hs-invite-meta">
                <strong>{inv.email}</strong>
                <code>{inv.accept_url}</code>
              </div>
              <button type="button" onclick={() => copy(inv.accept_url)} class="gl-btn gl-btn-ghost gl-hs-copy">
                ▸ COPY
              </button>
            </div>
          {/each}
        </div>
      {/if}

      <div class="gl-hs-result-cta">
        <a href="/c/{result.community_slug}" class="gl-btn gl-btn-primary">
          ▸ ENTER {result.community_slug.toUpperCase()}
        </a>
        <a href="/home" class="gl-btn gl-btn-ghost">▸ DASHBOARD</a>
      </div>
    {/if}
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
  .gl-lede {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 17px;
    line-height: 1.6;
    color: var(--text-secondary);
    max-width: 620px;
    margin: 0 auto;
  }

  .gl-hs { padding: 64px 24px 120px; }
  .gl-hs-inner { max-width: 640px; margin: 0 auto; }
  .gl-hs-head { text-align: center; margin-bottom: 36px; }

  .gl-hs-section { margin-bottom: 28px; }
  .gl-hs-section h3 {
    font-family: 'Cinzel', serif;
    font-size: 13px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: #d4af6a;
    margin-bottom: 14px;
    border-bottom: 1px solid rgba(212, 175, 106, 0.2);
    padding-bottom: 6px;
  }

  .gl-hs-section-hint {
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 14px;
    color: var(--text-muted);
    margin-bottom: 10px;
  }

  .gl-hs-field { margin-bottom: 16px; }
  .gl-hs-field label {
    display: block;
    font-family: 'Cinzel', serif;
    font-size: 11px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--text-secondary);
    margin-bottom: 6px;
  }

  .gl-hs-field input,
  .gl-hs-form textarea {
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
  .gl-hs-form textarea { resize: vertical; min-height: 92px; }

  .gl-hs-field input:focus,
  .gl-hs-form textarea:focus {
    outline: 0;
    border-color: #d4af6a;
    box-shadow: 0 0 0 3px rgba(212, 175, 106, 0.12);
  }

  .gl-hs-slug-row {
    display: flex;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    overflow: hidden;
  }
  .gl-hs-slug-row input { flex: 1; border: 0 !important; }
  .gl-hs-slug-suffix {
    padding: 12px 14px;
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-muted);
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 14px;
    border-left: 1px solid rgba(255, 255, 255, 0.1);
  }

  .gl-hs-price-preview {
    border: 1px solid rgba(212, 175, 106, 0.25);
    background: rgba(212, 175, 106, 0.04);
    border-radius: 2px;
    padding: 18px;
    margin: 12px 0 22px;
    font-family: 'EB Garamond', Georgia, serif;
  }
  .gl-hs-pp-line {
    display: flex;
    justify-content: space-between;
    padding: 4px 0;
    color: var(--text-secondary);
    font-size: 15px;
  }
  .gl-hs-pp-total {
    display: flex;
    justify-content: space-between;
    padding: 10px 0 0;
    margin-top: 8px;
    border-top: 1px solid rgba(212, 175, 106, 0.2);
    color: #d4af6a;
    font-size: 17px;
    font-weight: 600;
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

  .gl-su-submit { width: 100%; justify-content: center; margin-top: 8px; }

  /* Result view */
  .gl-hs-banner {
    background: rgba(245, 158, 11, 0.08);
    border: 1px solid rgba(245, 158, 11, 0.3);
    border-radius: 2px;
    padding: 14px 18px;
    margin: 18px auto 0;
    max-width: 600px;
    font-family: 'EB Garamond', Georgia, serif;
    font-size: 14px;
    color: var(--text-secondary);
    line-height: 1.55;
  }

  .gl-hs-no-invites {
    text-align: center;
    font-family: 'EB Garamond', Georgia, serif;
    color: var(--text-muted);
    margin: 36px 0;
  }

  .gl-hs-invites h3 {
    font-family: 'Cinzel', serif;
    font-size: 13px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: #d4af6a;
    margin-bottom: 14px;
  }

  .gl-hs-invite {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 14px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 2px;
    margin-bottom: 10px;
  }

  .gl-hs-invite-meta {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .gl-hs-invite-meta strong {
    font-family: 'EB Garamond', Georgia, serif;
    color: var(--text-primary);
    font-size: 15px;
  }
  .gl-hs-invite-meta code {
    font-family: monospace;
    font-size: 11px;
    color: var(--text-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .gl-hs-copy {
    flex-shrink: 0;
    padding: 8px 14px !important;
    font-size: 10px !important;
  }

  .gl-hs-result-cta {
    margin-top: 28px;
    display: flex;
    gap: 14px;
    justify-content: center;
    flex-wrap: wrap;
  }
</style>
