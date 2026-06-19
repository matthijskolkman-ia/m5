const warpCountInput = document.getElementById('warpCount');
const weftCountInput = document.getElementById('weftCount');
const patternSelect = document.getElementById('patternSelect');
const warpColorInput = document.getElementById('warpColor');
const weftColorInput = document.getElementById('weftColor');
const showGridInput = document.getElementById('showGrid');
const redrawButton = document.getElementById('redraw');
const canvas = document.getElementById('weaveCanvas');
const ctx = canvas.getContext('2d');

const patterns = {
  plain: (row, col) => (row + col) % 2 === 0,
  twill: (row, col) => ((row + col) % 4) < 2,
  basket: (row, col) => (Math.floor(row / 2) + Math.floor(col / 2)) % 2 === 0,
  herringbone: (row, col) => ((row + col) % 4) < 2 ? (row % 2 === 0) : (col % 2 === 0),
  diamond: (row, col, warp, weft) => {
    const half = Math.min(warp, weft) / 2;
    const x = col - warp / 2;
    const y = row - weft / 2;
    return Math.abs(x) + Math.abs(y) < half;
  },
};

const animationState = {
  time: 0,
  lastTimestamp: 0,
  rafId: null,
};

function startAnimation() {
  if (animationState.rafId) return;
  animationState.lastTimestamp = 0;
  animationState.rafId = requestAnimationFrame(animateLoop);
}

function animateLoop(timestamp) {
  if (!animationState.lastTimestamp) animationState.lastTimestamp = timestamp;
  const delta = timestamp - animationState.lastTimestamp;
  animationState.lastTimestamp = timestamp;
  animationState.time += delta;
  drawWeave(animationState.time);
  animationState.rafId = requestAnimationFrame(animateLoop);
}

function resizeCanvas() {
  const pixelRatio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * pixelRatio;
  canvas.height = rect.height * pixelRatio;
  ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
}

function drawWeave(time = 0) {
  resizeCanvas();

  const warpCount = Math.max(4, Math.min(80, Number(warpCountInput.value)));
  const weftCount = Math.max(4, Math.min(80, Number(weftCountInput.value)));
  const pattern = patternSelect.value;
  const warpColor = warpColorInput.value;
  const weftColor = weftColorInput.value;
  const showGrid = showGridInput.checked;

  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const cellWidth = width / warpCount;
  const cellHeight = height / weftCount;

  const rowDuration = 900;
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
  ctx.fillStyle = '#0b101c';
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
    const alpha = row <= activeRow ? 0.85 : 0.18;
    drawThread(adjustColor(weftColor, 0.06), y, true, alpha);
  }
  for (let col = 0; col < warpCount; col += 1) {
    drawThread(adjustColor(warpColor, 0.06), col * cellWidth, false, 0.65);
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
      const alpha = row < activeRow ? 1 : row === activeRow ? 0.95 : 0.22;
      const faded = row > activeRow && showGrid ? 0.15 : 0;

      ctx.globalAlpha = alpha;
      if (!isWoven && row === activeRow) {
        ctx.globalAlpha = 0.35;
      }
      if (warpOnTop) {
        drawTopCell(x, rowY, warpColor, adjustColor(weftColor, 0.15));
      } else {
        drawTopCell(x, rowY, weftColor, adjustColor(warpColor, 0.15));
      }
      ctx.globalAlpha = 1;

      if (showGrid) {
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(x + 0.25, rowY + 0.25, cellWidth - 0.5, cellHeight - 0.5);
      }
    }
  }

  drawHighlights(warpCount, weftCount, cellWidth, cellHeight);
  drawShuttle(shuttleX, shuttleY, cellWidth, cellHeight, warpColor, weftColor, shuttleDirection);
}

function drawShuttle(x, y, cellWidth, cellHeight, warpColor, weftColor, direction) {
  ctx.save();
  ctx.fillStyle = '#d48e23';
  ctx.shadowColor = 'rgba(0,0,0,0.3)';
  ctx.shadowBlur = 10;
  ctx.fillRect(x, y, cellWidth * 2.4, cellHeight * 0.28);
  ctx.fillStyle = '#2c3f61';
  ctx.fillRect(x + cellWidth * 0.14, y + cellHeight * 0.06, cellWidth * 2.2, cellHeight * 0.16);
  ctx.fillStyle = '#f0b36b';
  ctx.fillRect(x + (direction === 1 ? cellWidth * 0.95 : cellWidth * 0.2), y + cellHeight * 0.06, cellWidth * 0.35, cellHeight * 0.16);
  ctx.fillStyle = '#1261c4';
  ctx.fillRect(x + (direction === 1 ? cellWidth * 0.8 : cellWidth * 0.4), y + cellHeight * 0.06, cellWidth * 0.35, cellHeight * 0.16);
  ctx.restore();
}

function drawHighlights(warpCount, weftCount, cellWidth, cellHeight) {
  ctx.save();
  ctx.strokeStyle = 'rgba(255,255,255,0.1)';
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

redrawButton.addEventListener('click', () => drawWeave(animationState.time));
window.addEventListener('resize', () => drawWeave(animationState.time));
window.addEventListener('DOMContentLoaded', () => {
  drawWeave(0);
  startAnimation();
});
