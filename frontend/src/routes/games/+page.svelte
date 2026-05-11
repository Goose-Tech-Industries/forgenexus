<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';

  const gameTypes = [
    { key: 'cards_against_humanity', name: 'Cards Against Humanity', icon: '🃏', desc: 'Fill in the blank with the funniest answer. Judge picks the winner.', players: '3-10' },
    { key: 'trivia', name: 'Trivia', icon: '🧠', desc: 'Test your knowledge across categories. Fastest buzzer wins!', players: '2-50' },
    { key: 'would_you_rather', name: 'Would You Rather', icon: '🤔', desc: 'Pick between two options and see how the room splits.', players: '2-50' },
    { key: 'hot_takes', name: 'Hot Takes', icon: '🔥', desc: 'Post a statement. The room votes agree or disagree.', players: '2-50' },
    { key: 'word_chain', name: 'Word Chain', icon: '🔗', desc: 'Keep the chain going! Each player adds a word before the timer runs out.', players: '2-20' },
    { key: 'story_builder', name: 'Story Builder', icon: '📖', desc: 'Each player adds a sentence. What story will you create together?', players: '3-15' },
    { key: 'mafia', name: 'Mafia', icon: '🕵️', desc: 'Social deduction — find the mafia before they eliminate everyone.', players: '5-15' },
    { key: 'drawing_guess', name: 'Drawing & Guessing', icon: '🎨', desc: 'One person describes, everyone else guesses. Hilarity ensues.', players: '3-20' },
  ];
</script>

<svelte:head><title>Party Games — ForgeNexus</title></svelte:head>

<div class="games-page">
  <h1 class="text-glow">Party Games</h1>
  <p class="subtitle">Play with your community in voice rooms. Start a game from any room!</p>

  <div class="games-grid stagger">
    {#each gameTypes as game}
      <div class="game-card card-elevated card-glow">
        <div class="game-icon">{game.icon}</div>
        <div class="game-info">
          <h3>{game.name}</h3>
          <p>{game.desc}</p>
          <div class="game-meta">
            <span class="badge badge-accent">{game.players} players</span>
          </div>
        </div>
      </div>
    {/each}
  </div>

  <div class="games-note glass">
    <h3>How to Play</h3>
    <ol>
      <li>Join a voice room from the <a href="/live">Live</a> page</li>
      <li>The host starts a game from the room controls</li>
      <li>Everyone in the room can join the lobby</li>
      <li>Play, laugh, and earn points!</li>
    </ol>
  </div>
</div>

<style>
  .games-page { max-width: 900px; margin: 0 auto; padding: 24px 16px; }
  h1 { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { color: var(--text-secondary); margin-bottom: 24px; }

  .games-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; margin-bottom: 24px; }

  .game-card { display: flex; gap: 14px; padding: 18px; }
  .game-icon { font-size: 40px; flex-shrink: 0; }
  .game-info { flex: 1; }
  .game-info h3 { font-size: 16px; font-weight: 700; margin-bottom: 4px; }
  .game-info p { font-size: 13px; color: var(--text-secondary); line-height: 1.4; margin-bottom: 8px; }
  .game-meta { display: flex; gap: 8px; }

  .games-note { padding: 18px; }
  .games-note h3 { font-size: 16px; font-weight: 700; margin-bottom: 10px; }
  .games-note ol { padding-left: 20px; font-size: 14px; color: var(--text-secondary); line-height: 1.8; }
  .games-note a { color: var(--text-link); }
</style>
