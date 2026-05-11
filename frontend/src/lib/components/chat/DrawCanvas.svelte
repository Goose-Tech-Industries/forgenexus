<script lang="ts">
  /** MSN-style drawing canvas — draw and send as an image */
  let { onSend, onClose }: { onSend: (dataUrl: string) => void; onClose: () => void } = $props();

  let canvasEl: HTMLCanvasElement;
  let drawing = $state(false);
  let color = $state('#00d4aa');
  let brushSize = $state(3);
  let lastX = 0;
  let lastY = 0;

  const COLORS = ['#00d4aa', '#ef4444', '#3b82f6', '#f59e0b', '#8b5cf6', '#ec4899', '#22c55e', '#ffffff', '#000000'];

  $effect(() => {
    if (canvasEl) {
      const ctx = canvasEl.getContext('2d');
      if (ctx) {
        ctx.fillStyle = '#1a1a2e';
        ctx.fillRect(0, 0, canvasEl.width, canvasEl.height);
      }
    }
  });

  function startDraw(e: MouseEvent | TouchEvent) {
    drawing = true;
    const pos = getPos(e);
    lastX = pos.x;
    lastY = pos.y;
  }

  function draw(e: MouseEvent | TouchEvent) {
    if (!drawing) return;
    e.preventDefault();
    const ctx = canvasEl.getContext('2d');
    if (!ctx) return;
    const pos = getPos(e);
    ctx.beginPath();
    ctx.moveTo(lastX, lastY);
    ctx.lineTo(pos.x, pos.y);
    ctx.strokeStyle = color;
    ctx.lineWidth = brushSize;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();
    lastX = pos.x;
    lastY = pos.y;
  }

  function stopDraw() { drawing = false; }

  function getPos(e: MouseEvent | TouchEvent): { x: number; y: number } {
    const rect = canvasEl.getBoundingClientRect();
    if ('touches' in e) {
      const t = e.touches[0];
      return { x: t.clientX - rect.left, y: t.clientY - rect.top };
    }
    return { x: (e as MouseEvent).clientX - rect.left, y: (e as MouseEvent).clientY - rect.top };
  }

  function clear() {
    const ctx = canvasEl.getContext('2d');
    if (ctx) {
      ctx.fillStyle = '#1a1a2e';
      ctx.fillRect(0, 0, canvasEl.width, canvasEl.height);
    }
  }

  function send() {
    const dataUrl = canvasEl.toDataURL('image/png');
    onSend(dataUrl);
  }
</script>

<div class="draw-canvas">
  <div class="draw-header">
    <span>Draw</span>
    <button class="draw-close" onclick={onClose}>✕</button>
  </div>
  <canvas
    bind:this={canvasEl}
    width="260" height="180"
    onmousedown={startDraw}
    onmousemove={draw}
    onmouseup={stopDraw}
    onmouseleave={stopDraw}
    ontouchstart={startDraw}
    ontouchmove={draw}
    ontouchend={stopDraw}
  ></canvas>
  <div class="draw-tools">
    <div class="color-row">
      {#each COLORS as c}
        <button
          class="color-btn"
          class:active={color === c}
          style:background={c}
          onclick={() => { color = c; }}
        ></button>
      {/each}
    </div>
    <div class="brush-row">
      <input type="range" min="1" max="12" bind:value={brushSize} class="brush-slider" />
      <button class="tool-btn" onclick={clear}>Clear</button>
      <button class="tool-btn send-btn" onclick={send}>Send</button>
    </div>
  </div>
</div>

<style>
  .draw-canvas { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); box-shadow: 0 8px 24px rgba(0,0,0,0.4); overflow: hidden; }
  .draw-header { display: flex; justify-content: space-between; align-items: center; padding: 4px 8px; background: var(--bg-secondary); border-bottom: 1px solid var(--border-color); font-size: 11px; font-weight: 700; color: var(--text-primary); }
  .draw-close { background: none; border: none; color: var(--text-muted); cursor: pointer; font-size: 12px; }
  canvas { display: block; cursor: crosshair; }
  .draw-tools { padding: 6px; border-top: 1px solid var(--border-color); }
  .color-row { display: flex; gap: 3px; margin-bottom: 4px; }
  .color-btn { width: 18px; height: 18px; border-radius: 50%; border: 2px solid transparent; cursor: pointer; }
  .color-btn.active { border-color: white; box-shadow: 0 0 4px rgba(255,255,255,0.3); }
  .brush-row { display: flex; align-items: center; gap: 6px; }
  .brush-slider { flex: 1; height: 4px; accent-color: var(--accent); }
  .tool-btn { padding: 3px 8px; font-size: 10px; font-weight: 600; border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-primary); border-radius: 4px; cursor: pointer; }
  .tool-btn:hover { background: var(--bg-hover); }
  .send-btn { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .send-btn:hover { opacity: 0.9; }
</style>
