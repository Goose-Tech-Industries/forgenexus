<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  interface PointPack {
    id: string;
    name: string;
    points: number;
    bonus_points: number;
    price_cents: number;
    emoji: string | null;
  }

  let balance = $state(0);
  let packs = $state<PointPack[]>([]);
  let loading = $state(true);
  let purchasing = $state<string | null>(null);

  $effect(() => {
    if (auth.isLoggedIn) loadData();
  });

  async function loadData() {
    const [b, p] = await Promise.allSettled([
      api.request('/economy/balance'),
      api.request('/points/leaderboard')
    ]);
    if (b.status === 'fulfilled') balance = b.value.points || 0;
    loading = false;
  }

  function formatPrice(cents: number): string {
    return `$${(cents / 100).toFixed(2)}`;
  }

  async function purchasePack(pack: PointPack) {
    if (purchasing || !auth.isLoggedIn) return;

    // SAFETY LOCK (2026-05-04): the /economy/purchase backend endpoint inserts
    // a PointPackPurchase row WITHOUT going through Stripe. Granting points
    // for free would violate the revenue model and look like fraud if real
    // currency labels are shown. Lock until VITE_PAYMENTS_LIVE=true.
    if (import.meta.env.VITE_PAYMENTS_LIVE !== 'true') {
      alert('Point purchases are not yet available — payment integration pending.');
      return;
    }

    purchasing = pack.id;
    try {
      await api.request('/economy/purchase', {
        method: 'POST',
        body: JSON.stringify({ pack_id: pack.id, amount_cents: pack.price_cents })
      });
      balance += pack.points + pack.bonus_points;
    } catch {
      // silent — Stripe/payment integration needed for real purchases
    }
    purchasing = null;
  }

  const defaultPacks: PointPack[] = [
    { id: '1', name: 'Starter', points: 100, bonus_points: 0, price_cents: 99, emoji: '💰' },
    { id: '2', name: 'Popular', points: 500, bonus_points: 50, price_cents: 399, emoji: '⭐' },
    { id: '3', name: 'Value', points: 1000, bonus_points: 150, price_cents: 699, emoji: '💎' },
    { id: '4', name: 'Premium', points: 5000, bonus_points: 1000, price_cents: 2999, emoji: '👑' },
    { id: '5', name: 'Mega', points: 10000, bonus_points: 3000, price_cents: 4999, emoji: '🌌' },
  ];
</script>

<svelte:head>
  <title>Points — ForgeNexus</title>
</svelte:head>

<div class="points-page">
  <div class="points-header">
    <h1 class="text-glow">Points Store</h1>
    <p>Buy points to redeem channel rewards, tip creators, and unlock perks.</p>
  </div>

  {#if auth.isLoggedIn}
    <div class="balance-card glass glow-accent">
      <div class="balance-label">Your Balance</div>
      <div class="balance-value">{balance.toLocaleString()}</div>
      <div class="balance-unit">points</div>
    </div>
  {/if}

  <h2>Point Packs</h2>
  <div class="packs-grid stagger">
    {#each defaultPacks as pack (pack.id)}
      <div class="pack-card card-elevated card-glow">
        <div class="pack-emoji">{pack.emoji}</div>
        <div class="pack-name">{pack.name}</div>
        <div class="pack-points">
          <span class="pack-amount">{pack.points.toLocaleString()}</span>
          {#if pack.bonus_points > 0}
            <span class="pack-bonus">+{pack.bonus_points} bonus</span>
          {/if}
        </div>
        <div class="pack-price">{formatPrice(pack.price_cents)}</div>
        <button
          class="btn btn-primary pack-buy"
          disabled={purchasing === pack.id || !auth.isLoggedIn}
          onclick={() => purchasePack(pack)}
        >
          {purchasing === pack.id ? 'Processing...' : 'Buy Now'}
        </button>
      </div>
    {/each}
  </div>

  <div class="points-info glass">
    <h3>How Points Work</h3>
    <div class="info-grid">
      <div class="info-item">
        <span class="info-icon">🎙</span>
        <strong>Voice Rewards</strong>
        <p>Earn points just by participating in voice rooms</p>
      </div>
      <div class="info-item">
        <span class="info-icon">💬</span>
        <strong>Posting</strong>
        <p>Create threads and replies to earn points</p>
      </div>
      <div class="info-item">
        <span class="info-icon">🎯</span>
        <strong>Redeem</strong>
        <p>Spend on channel points: TTS, effects, raids, and more</p>
      </div>
      <div class="info-item">
        <span class="info-icon">🎁</span>
        <strong>Gift</strong>
        <p>Tip creators and gift points to friends</p>
      </div>
    </div>
  </div>
</div>

<style>
  .points-page { max-width: 900px; margin: 0 auto; padding: 24px 16px; }
  .points-header { text-align: center; margin-bottom: 24px; }
  .points-header h1 { font-size: 28px; font-weight: 800; }
  .points-header p { color: var(--text-secondary); }

  .balance-card {
    text-align: center; padding: 24px; margin-bottom: 28px;
    border-radius: var(--radius-xl);
  }
  .balance-label { font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-muted); }
  .balance-value { font-size: 48px; font-weight: 800; color: var(--accent); text-shadow: 0 0 20px var(--accent-glow); }
  .balance-unit { font-size: 14px; color: var(--text-secondary); }

  h2 { font-size: 18px; font-weight: 700; margin-bottom: 16px; color: var(--text-heading); }

  .packs-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 12px; margin-bottom: 28px;
  }

  .pack-card {
    text-align: center; padding: 20px 14px;
    display: flex; flex-direction: column; align-items: center; gap: 6px;
  }

  .pack-emoji { font-size: 36px; margin-bottom: 4px; }
  .pack-name { font-size: 14px; font-weight: 700; color: var(--text-heading); }
  .pack-points { display: flex; flex-direction: column; align-items: center; }
  .pack-amount { font-size: 22px; font-weight: 800; color: var(--accent); }
  .pack-bonus { font-size: 11px; color: var(--success); font-weight: 600; }
  .pack-price { font-size: 16px; font-weight: 700; color: var(--text-primary); margin: 4px 0; }
  .pack-buy { width: 100%; margin-top: 8px; }

  .points-info { padding: 20px; margin-top: 16px; }
  .points-info h3 { font-size: 16px; font-weight: 700; margin-bottom: 14px; color: var(--text-heading); }

  .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; }
  .info-item { text-align: center; }
  .info-icon { font-size: 28px; display: block; margin-bottom: 6px; }
  .info-item strong { display: block; font-size: 14px; margin-bottom: 4px; }
  .info-item p { font-size: 12px; color: var(--text-muted); line-height: 1.4; }
</style>
