// Pattern generation configurations
const patterns = {
  // Gen 1: Honeycomb scales
  honeycomb: (row, col, warp, weft) => {
    const offset = row % 2 === 0 ? 0 : 0.5;
    return (Math.floor(col + offset) % 3) < 2;
  },

  // Gen 2: Diamond mesh
  diamond: (row, col, warp, weft) => {
    const x = (col % 4);
    const y = (row % 4);
    return Math.abs(x - 2) + Math.abs(y - 2) < 2;
  },

  // Gen 3: Serpentine scales
  serpentine: (row, col, warp, weft) => {
    const wave = Math.sin((row + col) * Math.PI / 4) > 0;
    return (row + col) % 2 === (wave ? 0 : 1);
  },

  // Gen 4: Interlocking hexagons
  hexagon: (row, col, warp, weft) => {
    const centerRow = row % 4;
    const centerCol = col % 4;
    const dist = Math.sqrt((centerRow - 2) ** 2 + (centerCol - 2) ** 2);
    return dist < 1.8 || dist > 2.5;
  },

  // Gen 5: Staggered mesh
  staggered: (row, col, warp, weft) => {
    const rowOffset = (Math.floor(row / 2) % 2) * 2;
    return ((col + rowOffset) % 4) < 2;
  },

  // Gen 6: Radial pattern
  radial: (row, col, warp, weft) => {
    const centerRow = weft / 2;
    const centerCol = warp / 2;
    const angle = Math.atan2(row - centerRow, col - centerCol);
    return Math.sin(angle * 6) > 0;
  },

  // Gen 7: Chevron pattern
  chevron: (row, col, warp, weft) => {
    const chevronRow = row % 6;
    const relCol = (col + Math.floor(row / 3)) % 4;
    return (chevronRow < 3) ? (relCol < 2) : (relCol >= 2);
  },

  // Gen 8: Cross-hatch
  crosshatch: (row, col, warp, weft) => {
    const x = row % 6;
    const y = col % 6;
    return (x < 3) === (y < 3);
  },

  // Gen 9: Zigzag pattern
  zigzag: (row, col, warp, weft) => {
    const zigRow = row % 4;
    const shift = Math.floor(col / 2) % 2;
    return (zigRow < 2) === (shift === 0);
  },

  // Gen 10: Spiral pattern
  spiral: (row, col, warp, weft) => {
    const centerRow = weft / 2;
    const centerCol = warp / 2;
    const dist = Math.hypot(row - centerRow, col - centerCol);
    const angle = Math.atan2(row - centerRow, col - centerCol);
    return (dist + angle * 3) % 4 < 2;
  },

  // Gen 11: Layered scales
  layered: (row, col, warp, weft) => {
    const layer = Math.floor(row / 3);
    const inLayer = row % 3;
    return (inLayer === 1) === (Math.floor((col + layer) / 2) % 2 === 0);
  },

  // Gen 12: Crystalline pattern
  crystalline: (row, col, warp, weft) => {
    const seed = (row * 73856093 ^ col * 19349663) % 256;
    return (seed ^ (row * col)) % 2 === 0;
  },

  // Gen 13: Rietveld pattern
  rietveld: (row, col, warp, weft) => {
    const blockSize = 3;
    const rowBlock = Math.floor(row / blockSize);
    const colBlock = Math.floor(col / blockSize);
    const blockPattern = (rowBlock + colBlock) % 3;
    const inBlockRow = row % blockSize;
    const inBlockCol = col % blockSize;
    return blockPattern === 0 ? (inBlockRow < 2) : blockPattern === 1 ? (inBlockCol < 2) : ((inBlockRow + inBlockCol) < 3);
  },
};

const generationConfigs = [
  {
    title: 'Generation 1: Honeycomb Scales',
    desc: 'Organic hexagonal scales in warm amber',
    pattern: 'honeycomb',
    warpColor: '#ff7a18',
    weftColor: '#fff9e6',
    warpCount: 32,
    weftCount: 20,
    speed: 0.85,
  },
  {
    title: 'Generation 2: Diamond Mesh',
    desc: 'Sharp geometric diamonds in cool blue',
    pattern: 'diamond',
    warpColor: '#1d4ed8',
    weftColor: '#38bdf8',
    warpCount: 28,
    weftCount: 18,
    speed: 0.95,
  },
  {
    title: 'Generation 3: Serpentine Scales',
    desc: 'Wavy undulating pattern in emerald',
    pattern: 'serpentine',
    warpColor: '#10b981',
    weftColor: '#a7f3d0',
    warpCount: 30,
    weftCount: 20,
    speed: 1.1,
  },
  {
    title: 'Generation 4: Interlocking Hexagons',
    desc: 'Interlocked geometric forms in violet',
    pattern: 'hexagon',
    warpColor: '#8b5cf6',
    weftColor: '#ede9fe',
    warpCount: 26,
    weftCount: 18,
    speed: 0.88,
  },
  {
    title: 'Generation 5: Staggered Mesh',
    desc: 'Offset grid pattern in coral pink',
    pattern: 'staggered',
    warpColor: '#fb7185',
    weftColor: '#fef2f2',
    warpCount: 34,
    weftCount: 22,
    speed: 0.92,
  },
  {
    title: 'Generation 6: Radial Pattern',
    desc: 'Radiating spokes from center in gold',
    pattern: 'radial',
    warpColor: '#d97706',
    weftColor: '#fef3c7',
    warpCount: 28,
    weftCount: 20,
    speed: 1.02,
  },
  {
    title: 'Generation 7: Chevron Pattern',
    desc: 'V-shaped chevrons in turquoise',
    pattern: 'chevron',
    warpColor: '#0891b2',
    weftColor: '#cffafe',
    warpCount: 32,
    weftCount: 20,
    speed: 0.98,
  },
  {
    title: 'Generation 8: Cross-Hatch',
    desc: 'Dense cross-hatched mesh in indigo',
    pattern: 'crosshatch',
    warpColor: '#4338ca',
    weftColor: '#dbeafe',
    warpCount: 30,
    weftCount: 20,
    speed: 0.89,
  },
  {
    title: 'Generation 9: Zigzag Pattern',
    desc: 'Sawtooth zigzag pattern in rose',
    pattern: 'zigzag',
    warpColor: '#be185d',
    weftColor: '#ffe4e6',
    warpCount: 28,
    weftCount: 18,
    speed: 1.05,
  },
  {
    title: 'Generation 10: Spiral Pattern',
    desc: 'Spiraling vortex effect in lime',
    pattern: 'spiral',
    warpColor: '#16a34a',
    weftColor: '#f0fdf4',
    warpCount: 26,
    weftCount: 22,
    speed: 0.91,
  },
  {
    title: 'Generation 11: Layered Scales',
    desc: 'Stacked overlapping scales in slate',
    pattern: 'layered',
    warpColor: '#475569',
    weftColor: '#e2e8f0',
    warpCount: 32,
    weftCount: 20,
    speed: 0.87,
  },
  {
    title: 'Generation 12: Crystalline Pattern',
    desc: 'Organic crystalline formations in teal',
    pattern: 'crystalline',
    warpColor: '#0d9488',
    weftColor: '#ccfbf1',
    warpCount: 30,
    weftCount: 20,
    speed: 1.0,
  },
  {
    title: 'Generation 13: Rietveld Pattern',
    desc: 'De Stijl geometric blocks in primary colors',
    pattern: 'rietveld',
    warpColor: '#dc2626',
    weftColor: '#fef2f2',
    warpCount: 27,
    weftCount: 18,
    speed: 0.93,
  },
];

class WeaveAnimator {
  constructor(canvas, options) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.options = options;
    this.time = 0;
    this.rafId = null;
    this.lastTimestamp = 0;
    this.boundTick = this.tick.bind(this);
  }

  start() {
    if (this.rafId) return;
    this.lastTimestamp = 0;
    this.rafId = requestAnimationFrame(this.boundTick);
  }

  stop() {
    if (!this.rafId) return;
    cancelAnimationFrame(this.rafId);
    this.rafId = null;
  }

  tick(timestamp) {
    if (!this.lastTimestamp) this.lastTimestamp = timestamp;
    const delta = timestamp - this.lastTimestamp;
    this.lastTimestamp = timestamp;
    this.time += delta;
    drawWeave(this.canvas, this.ctx, this.options, this.time);
    this.rafId = requestAnimationFrame(this.boundTick);
  }
}

function resizeCanvas(canvas, ctx) {
  const pixelRatio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * pixelRatio;
  canvas.height = rect.height * pixelRatio;
  ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
}

function drawWeave(canvas, ctx, options, time = 0) {
  resizeCanvas(canvas, ctx);

  const warpCount = options.warpCount || 24;
  const weftCount = options.weftCount || 16;
  const pattern = options.pattern || 'honeycomb';
  const warpColor = options.warpColor || '#ff7a18';
  const weftColor = options.weftColor || '#1d4ed8';

  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const cellWidth = width / warpCount;
  const cellHeight = height / weftCount;

  const rowDuration = 1200 / (options.speed || 1);
  const totalDuration = rowDuration * weftCount;
  const rawProgress = (time % totalDuration) / totalDuration;
  const activeRow = Math.min(weftCount - 1, Math.floor(rawProgress * weftCount));
  const rowProgress = (rawProgress * weftCount) - activeRow;
  const shuttleDirection = activeRow % 2 === 0 ? 1 : -1;
  const shuttleProgress = shuttleDirection === 1 ? rowProgress : 1 - rowProgress;
  const shuttleX = width * 0.08 + (width * 0.84) * shuttleProgress;
  const shuttleY = activeRow * cellHeight + cellHeight * 0.55;
  const beatOffset = Math.sin(rowProgress * Math.PI) * cellHeight * 0.18;

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = '#0a1120';
  ctx.fillRect(0, 0, width, height);

  function drawThread(color, offset, horizontal = false, alpha = 1) {
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    if (horizontal) {
      ctx.fillRect(0, offset, width, cellHeight * 0.9);
    } else {
      ctx.fillRect(offset, 0, cellWidth * 0.9, height);
    }
    ctx.globalAlpha = 1;
  }

  for (let row = 0; row < weftCount; row += 1) {
    const y = row * cellHeight + (row === activeRow ? beatOffset * 0.25 : 0);
    const alpha = row <= activeRow ? 0.82 : 0.18;
    drawThread(adjustColor(weftColor, 0.05), y, true, alpha);
  }
  for (let col = 0; col < warpCount; col += 1) {
    drawThread(adjustColor(warpColor, 0.05), col * cellWidth, false, 0.62);
  }

  const drawTopCell = (x, y, fillColor, underColor) => {
    ctx.fillStyle = fillColor;
    ctx.fillRect(x, y, cellWidth, cellHeight);
    ctx.globalCompositeOperation = 'destination-over';
    ctx.fillStyle = underColor;
    ctx.fillRect(x, y, cellWidth, cellHeight);
    ctx.globalCompositeOperation = 'source-over';
  };

  for (let row = 0; row < weftCount; row += 1) {
    const rowY = row * cellHeight + (row === activeRow ? beatOffset : 0);
    for (let col = 0; col < warpCount; col += 1) {
      const warpOnTop = patterns[pattern](row, col, warpCount, weftCount);
      const x = col * cellWidth;
      const isWoven = row < activeRow || (row === activeRow && shuttleDirection === 1 ? col / warpCount < rowProgress : (warpCount - col - 1) / warpCount < rowProgress);
      const alpha = row < activeRow ? 1 : row === activeRow ? 0.92 : 0.24;

      ctx.globalAlpha = alpha;
      if (!isWoven && row === activeRow) {
        ctx.globalAlpha = 0.34;
      }
      if (warpOnTop) {
        drawTopCell(x, rowY, warpColor, adjustColor(weftColor, 0.16));
      } else {
        drawTopCell(x, rowY, weftColor, adjustColor(warpColor, 0.16));
      }
      ctx.globalAlpha = 1;

      ctx.strokeStyle = 'rgba(255,255,255,0.08)';
      ctx.lineWidth = 0.38;
      ctx.strokeRect(x + 0.18, rowY + 0.18, cellWidth - 0.36, cellHeight - 0.36);
    }
  }

  drawHighlights(ctx, warpCount, weftCount, cellWidth, cellHeight);
  drawShuttle(ctx, shuttleX, shuttleY, cellWidth, cellHeight, warpColor, weftColor, shuttleDirection);
}

function drawShuttle(ctx, x, y, cellWidth, cellHeight, warpColor, weftColor, direction) {
  ctx.save();
  ctx.fillStyle = '#d48e23';
  ctx.shadowColor = 'rgba(0,0,0,0.28)';
  ctx.shadowBlur = 10;
  ctx.fillRect(x, y, cellWidth * 2.4, cellHeight * 0.28);
  ctx.fillStyle = '#223955';
  ctx.fillRect(x + cellWidth * 0.14, y + cellHeight * 0.06, cellWidth * 2.2, cellHeight * 0.16);
  ctx.fillStyle = '#f0b36b';
  ctx.fillRect(x + (direction === 1 ? cellWidth * 0.95 : cellWidth * 0.2), y + cellHeight * 0.06, cellWidth * 0.35, cellHeight * 0.16);
  ctx.fillStyle = '#1261c4';
  ctx.fillRect(x + (direction === 1 ? cellWidth * 0.8 : cellWidth * 0.4), y + cellHeight * 0.06, cellWidth * 0.35, cellHeight * 0.16);
  ctx.restore();
}

function drawHighlights(ctx, warpCount, weftCount, cellWidth, cellHeight) {
  ctx.save();
  ctx.strokeStyle = 'rgba(255,255,255,0.09)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let col = 0; col <= warpCount; col += 1) {
    ctx.moveTo(col * cellWidth, 0);
    ctx.lineTo(col * cellWidth, weftCount * cellHeight);
  }
  for (let row = 0; row <= weftCount; row += 1) {
    ctx.moveTo(0, row * cellHeight);
    ctx.lineTo(warpCount * cellWidth, row * cellHeight);
  }
  ctx.stroke();
  ctx.restore();
}

function adjustColor(hex, amount) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  const clamp = (value) => Math.min(255, Math.max(0, value));
  return `rgb(${clamp(r + 255 * amount)}, ${clamp(g + 255 * amount)}, ${clamp(b + 255 * amount)})`;
}

// Global animators map
const allAnimators = [];

function initializeGenerations() {
  const container = document.getElementById('generationsContainer');

  generationConfigs.forEach((config, index) => {
    // Create generation card
    const card = document.createElement('div');
    card.className = 'generation';
    card.innerHTML = `
      <div class="generation-header">
        <div class="generation-title">${config.title}</div>
        <div class="generation-desc">${config.desc}</div>
      </div>
      <div class="canvas-wrapper">
        <canvas id="canvas-${index}" width="500" height="280"></canvas>
      </div>
      <div class="generation-footer">
        Pattern: ${config.pattern} | Speed: ${config.speed}x | Grid: ${config.warpCount}×${config.weftCount}
      </div>
    `;
    container.appendChild(card);

    // Create animator
    const canvas = document.getElementById(`canvas-${index}`);
    const animator = new WeaveAnimator(canvas, config);
    allAnimators.push(animator);
    animator.start();
  });
}

// Global control functions
window.startAllAnimations = function () {
  allAnimators.forEach(animator => animator.start());
};

window.stopAllAnimations = function () {
  allAnimators.forEach(animator => animator.stop());
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  window.addEventListener('DOMContentLoaded', initializeGenerations);
} else {
  initializeGenerations();
}

// Handle resize
window.addEventListener('resize', () => {
  allAnimators.forEach(animator => animator.start());
});
