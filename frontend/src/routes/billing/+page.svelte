<script lang="ts">
  import { onMount } from 'svelte';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  interface Plan {
    plan: string;
    name: string;
    monthly_cents: number;
    monthly_price: string;
    available: boolean;
  }

  interface Community {
    id: string;
    name: string;
    slug: string;
  }

  interface Subscription {
    plan: string;
    plan_status: string;
    current_period_end: string | null;
    cancel_at: string | null;
  }

  let plans = $state<Plan[]>([]);
  let myCommunities = $state<Community[]>([]);
  let selectedCommunity = $state<Community | null>(null);
  let currentSub = $state<Subscription | null>(null);
  let loading = $state(true);
  let checkingOut = $state<string | null>(null);

  onMount(async () => {
    try {
      const plansData = await api.getBillingPlans();
      plans = plansData.plans || [];

      if (auth.isLoggedIn) {
        // Communities owned by this user (uses existing endpoint if available;
        // falls back to empty array if not — owners can also reach billing
        // via /communities/<slug>/billing).
        try {
          const communitiesData = await api.request('/communities/mine');
          myCommunities = communitiesData.communities || [];
          if (myCommunities.length === 1) {
            selectCommunity(myCommunities[0]);
          }
        } catch { /* user owns no communities yet */ }
      }
    } catch (err) {
      console.error('Failed to load billing data', err);
    }
    loading = false;
  });

  async function selectCommunity(community: Community) {
    selectedCommunity = community;
    currentSub = null;
    try {
      currentSub = await api.getCommunitySubscription(community.id);
    } catch { /* not yet subscribed */ }
  }

  async function subscribe(plan: string) {
    if (!selectedCommunity) {
      toast.error('Pick a community first');
      return;
    }
    checkingOut = plan;
    try {
      const data = await api.createCommunityCheckout(selectedCommunity.id, plan);
      if (data.checkout_url) {
        window.location.href = data.checkout_url;
        return;
      }
      toast.error('No checkout URL returned');
    } catch (err: any) {
      toast.error(err?.error || 'Checkout failed');
    }
    checkingOut = null;
  }
</script>

<svelte:head>
  <title>Billing — ForgeNexus</title>
</svelte:head>

<div class="billing-page">
  <h1>Billing & Plans</h1>
  <p class="lead">Pick a tier to unlock features for your community. Stripe-secured. Cancel anytime.</p>

  {#if !auth.isLoggedIn}
    <div class="card">
      <p>You'll need to <a href="/auth/login">log in</a> to manage billing.</p>
    </div>
  {:else if loading}
    <p class="muted">Loading…</p>
  {:else}
    {#if myCommunities.length > 1}
      <div class="card">
        <h2>Your Communities</h2>
        <div class="community-picker">
          {#each myCommunities as c (c.id)}
            <button
              class="community-pick"
              class:active={selectedCommunity?.id === c.id}
              onclick={() => selectCommunity(c)}
            >
              {c.name}
            </button>
          {/each}
        </div>
      </div>
    {:else if myCommunities.length === 0}
      <div class="card">
        <p>You don't own a community yet. <a href="/communities/new">Create one</a> to subscribe to a plan.</p>
      </div>
    {/if}

    {#if selectedCommunity}
      <div class="card current-plan">
        <h2>{selectedCommunity.name}</h2>
        {#if currentSub && currentSub.plan_status === 'active'}
          <p>
            Currently on <strong>{currentSub.plan}</strong> ·
            <span class="status status-{currentSub.plan_status}">{currentSub.plan_status}</span>
            {#if currentSub.current_period_end}
              · renews {new Date(currentSub.current_period_end).toLocaleDateString()}
            {/if}
          </p>
        {:else}
          <p class="muted">No active subscription. Pick a plan below to start.</p>
        {/if}
      </div>
    {/if}

    <div class="plans-grid">
      {#each plans as p (p.plan)}
        <div class="plan-card" class:current={currentSub?.plan === p.plan}>
          <h3>{p.name}</h3>
          <div class="price">
            <span class="amount">{p.monthly_price}</span>
            <span class="period">/month</span>
          </div>
          {#if !p.available}
            <p class="muted">Coming soon</p>
          {:else if currentSub?.plan === p.plan && currentSub?.plan_status === 'active'}
            <button class="btn btn-secondary" disabled>Current Plan</button>
          {:else}
            <button
              class="btn btn-primary"
              onclick={() => subscribe(p.plan)}
              disabled={!selectedCommunity || checkingOut === p.plan}
            >
              {checkingOut === p.plan ? 'Redirecting…' : 'Subscribe'}
            </button>
          {/if}
        </div>
      {/each}
    </div>

    <p class="footer-note">
      Payments processed by Stripe. ForgeNexus never sees your card details.
      Stripe's standard fee (2.9% + $0.30) is deducted before any creator splits.
    </p>
  {/if}
</div>

<style>
  .billing-page { max-width: 980px; margin: 0 auto; padding: 24px 16px; }
  h1 { font-size: 28px; font-weight: 800; margin: 0 0 6px; }
  .lead { color: var(--text-secondary); margin: 0 0 24px; font-size: 15px; }
  .card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px 20px; margin-bottom: 16px; }
  .card h2 { font-size: 18px; margin: 0 0 8px; }
  .muted { color: var(--text-muted); }
  .community-picker { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
  .community-pick { padding: 6px 14px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 13px; cursor: pointer; }
  .community-pick.active { border-color: var(--accent); color: var(--accent); }
  .current-plan { background: var(--bg-secondary); }
  .status { padding: 2px 8px; border-radius: 999px; font-size: 11px; text-transform: uppercase; }
  .status-active { background: rgba(16,185,129,0.15); color: #10b981; }
  .status-past_due { background: rgba(239,68,68,0.15); color: #ef4444; }
  .status-canceled { background: rgba(156,163,175,0.15); color: #9ca3af; }
  .plans-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
  .plan-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 18px; text-align: center; }
  .plan-card.current { border-color: var(--accent); }
  .plan-card h3 { font-size: 15px; font-weight: 700; margin: 0 0 8px; }
  .price { margin: 8px 0 14px; }
  .amount { font-size: 28px; font-weight: 800; color: var(--accent); }
  .period { font-size: 13px; color: var(--text-muted); margin-left: 2px; }
  .btn { width: 100%; padding: 8px 14px; border-radius: var(--radius-md); border: 1px solid var(--border-color); background: var(--bg-input); color: var(--text-primary); font-weight: 600; cursor: pointer; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-primary:hover:not(:disabled) { filter: brightness(1.08); }
  .btn-secondary { background: var(--bg-tertiary); color: var(--text-secondary); }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .footer-note { font-size: 12px; color: var(--text-muted); margin-top: 24px; }

  @media (max-width: 768px) {
    .billing-page { padding: 12px 10px; }
    .plans-grid { grid-template-columns: 1fr; }
  }
</style>
