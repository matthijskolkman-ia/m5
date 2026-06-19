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

function resizeCanvas() {
  const pixelRatio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * pixelRatio;
  canvas.height = rect.height * pixelRatio;
  ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
}

function drawWeave() {
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

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = '#0b101c';
  ctx.fillRect(0, 0, width, height);

  function drawThread(color, offset, horizontal = false) {
    ctx.fillStyle = color;
    if (horizontal) {
      ctx.fillRect(0, offset, width, cellHeight * 0.9);
    } else {
      ctx.fillRect(offset, 0, cellWidth * 0.9, height);
    }
  }

  for (let row = 0; row < weftCount; row += 1) {
    drawThread(adjustColor(weftColor, 0.06), row * cellHeight, true);
  }
  for (let col = 0; col < warpCount; col += 1) {
    drawThread(adjustColor(warpColor, 0.06), col * cellWidth, false);
  }

  for (let row = 0; row < weftCount; row += 1) {
    for (let col = 0; col < warpCount; col += 1) {
      const warpOnTop = patterns[pattern](row, col, warpCount, weftCount);
      const x = col * cellWidth;
      const y = row * cellHeight;

      if (warpOnTop) {
        ctx.fillStyle = warpColor;
        ctx.fillRect(x, y, cellWidth, cellHeight);
        ctx.globalCompositeOperation = 'destination-over';
        ctx.fillStyle = adjustColor(weftColor, 0.15);
        ctx.fillRect(x, y, cellWidth, cellHeight);
        ctx.globalCompositeOperation = 'source-over';
      } else {
        ctx.fillStyle = weftColor;
        ctx.fillRect(x, y, cellWidth, cellHeight);
        ctx.globalCompositeOperation = 'destination-over';
        ctx.fillStyle = adjustColor(warpColor, 0.15);
        ctx.fillRect(x, y, cellWidth, cellHeight);
        ctx.globalCompositeOperation = 'source-over';
      }

      if (showGrid) {
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(x + 0.25, y + 0.25, cellWidth - 0.5, cellHeight - 0.5);
      }
    }
  }

  drawHighlights(warpCount, weftCount, cellWidth, cellHeight);
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

redrawButton.addEventListener('click', drawWeave);
window.addEventListener('resize', drawWeave);
window.addEventListener('DOMContentLoaded', drawWeave);
