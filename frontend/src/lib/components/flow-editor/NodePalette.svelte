<script lang="ts">
  import { canvasState } from './canvas-state.svelte';
  import { categoryColor } from './category-colors';

  let search = $state('');

  const CATEGORY_ORDER = [
    // Core
    'trigger', 'logic', 'math', 'data', 'action', 'text', 'ui',
    // Moderation & Safety
    'moderation', 'automod',
    // Community
    'user_management', 'notification', 'verification', 'content', 'ticket', 'poll', 'approval',
    // Economy & Commerce
    'economy', 'gambling', 'inventory', 'collection',
    // Gamification
    'stats', 'achievement', 'reputation', 'tournament', 'quest', 'pet',
    // Scheduling & Integration
    'scheduling', 'integration',
    // Analytics & Profile
    'analytics', 'profile',
  ];
  const CATEGORY_LABELS: Record<string, string> = {
    trigger: 'Triggers', logic: 'Logic', math: 'Math',
    data: 'Data', action: 'Actions', text: 'Text', ui: 'UI',
    moderation: 'Moderation', automod: 'AutoMod',
    user_management: 'User Management', notification: 'Notifications',
    verification: 'Verification', content: 'Content', ticket: 'Tickets',
    poll: 'Polls & Voting', approval: 'Approval',
    economy: 'Economy', gambling: 'Gambling & Chance',
    inventory: 'Inventory', collection: 'Collections',
    stats: 'User Stats', achievement: 'Achievements',
    reputation: 'Reputation', tournament: 'Tournaments',
    quest: 'Quests', pet: 'Pets',
    scheduling: 'Scheduling', integration: 'Integrations',
    analytics: 'Analytics', profile: 'Profile & Display',
  };

  let collapsed = $state<Record<string, boolean>>({});

  const filtered = $derived(() => {
    const q = search.toLowerCase().trim();
    const map = canvasState.nodesByCategory;
    const result: [string, typeof canvasState.nodeTypes][] = [];
    // Show categories in defined order first
    for (const cat of CATEGORY_ORDER) {
      const types = map.get(cat) ?? [];
      const matching = q
        ? types.filter((t) => t.label.toLowerCase().includes(q) || t.type.toLowerCase().includes(q) || t.description.toLowerCase().includes(q))
        : types;
      if (matching.length > 0) result.push([cat, matching]);
    }
    // Then any extra categories not in the order list
    for (const [cat, types] of map.entries()) {
      if (!CATEGORY_ORDER.includes(cat)) {
        const matching = q
          ? types.filter((t: any) => t.label.toLowerCase().includes(q) || t.type.toLowerCase().includes(q) || t.description.toLowerCase().includes(q))
          : types;
        if (matching.length > 0) result.push([cat, matching]);
      }
    }
    return result;
  });

  function addNode(type: string) {
    // Add node at center of current viewport
    const vp = canvasState.viewport;
    const cx = (window.innerWidth / 2 - 240 - vp.panX) / vp.zoom;
    const cy = (window.innerHeight / 2 - vp.panY) / vp.zoom;
    const id = canvasState.addNode(type, cx - 100, cy - 40);
    canvasState.selectNode(id);
  }

  function toggleCategory(cat: string) {
    collapsed = { ...collapsed, [cat]: !collapsed[cat] };
  }
</script>

<div class="palette">
  <div class="palette-header">
    <span class="palette-title">Nodes</span>
  </div>

  <div class="search-box">
    <input
      type="text"
      bind:value={search}
      placeholder="Search nodes..."
    />
  </div>

  <div class="palette-list">
    {#each filtered() as [category, types] (category)}
      <button class="category-row" onclick={() => toggleCategory(category)}>
        <span class="cat-dot" style="background: {categoryColor(category)}"></span>
        <span class="cat-label">{CATEGORY_LABELS[category] ?? category}</span>
        <span class="cat-count">{types.length}</span>
        <span class="cat-chevron" class:open={!collapsed[category]}>&#9662;</span>
      </button>

      {#if !collapsed[category]}
        {#each types as nt (nt.type)}
          <button class="node-item" onclick={() => addNode(nt.type)}>
            <span class="node-item-label">{nt.label}</span>
            <span class="node-item-desc">{nt.description.slice(0, 50)}</span>
          </button>
        {/each}
      {/if}
    {/each}
  </div>
</div>

<style>
  .palette {
    width: 240px;
    height: 100%;
    background: var(--bg-secondary);
    border-right: 1px solid var(--border-color);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .palette-header {
    padding: 12px 14px;
    border-bottom: 1px solid var(--border-color);
  }

  .palette-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .search-box {
    padding: 8px 10px;
    border-bottom: 1px solid var(--border-color);
  }

  .search-box input {
    width: 100%;
    padding: 6px 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 12px;
    font-family: inherit;
  }

  .search-box input:focus {
    outline: none;
    border-color: var(--accent);
  }

  .palette-list {
    flex: 1;
    overflow-y: auto;
    padding: 4px 0;
  }

  .category-row {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 14px;
    border: none;
    background: var(--bg-tertiary);
    cursor: pointer;
    font-family: inherit;
    border-bottom: 1px solid var(--border-color);
  }

  .category-row:hover {
    background: var(--bg-hover);
  }

  .cat-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .cat-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    flex: 1;
    text-align: left;
  }

  .cat-count {
    font-size: 10px;
    color: var(--text-muted);
    background: var(--bg-primary);
    padding: 1px 5px;
    border-radius: 8px;
  }

  .cat-chevron {
    font-size: 10px;
    color: var(--text-muted);
    transition: transform 0.15s;
  }

  .cat-chevron.open {
    transform: rotate(0deg);
  }

  .cat-chevron:not(.open) {
    transform: rotate(-90deg);
  }

  .node-item {
    display: flex;
    flex-direction: column;
    gap: 1px;
    width: 100%;
    padding: 6px 14px 6px 30px;
    border: none;
    background: transparent;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    border-bottom: 1px solid rgba(30, 41, 59, 0.4);
  }

  .node-item:hover {
    background: var(--bg-hover);
  }

  .node-item-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-primary);
  }

  .node-item-desc {
    font-size: 10px;
    color: var(--text-muted);
    line-height: 1.3;
  }
</style>
