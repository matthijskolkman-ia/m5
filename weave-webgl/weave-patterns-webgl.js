const generationConfigs = [
  {
    title: 'Generation 1: Honeycomb Scales',
    desc: 'Organic hexagonal scales in warm amber',
    pattern: 0,
    warpColor: '#ff7a18',
    weftColor: '#fff9e6',
    warpCount: 32,
    weftCount: 20,
    speed: 0.85,
  },
  {
    title: 'Generation 2: Diamond Mesh',
    desc: 'Sharp geometric diamonds in cool blue',
    pattern: 1,
    warpColor: '#1d4ed8',
    weftColor: '#38bdf8',
    warpCount: 28,
    weftCount: 18,
    speed: 0.95,
  },
  {
    title: 'Generation 3: Serpentine Scales',
    desc: 'Wavy undulating pattern in emerald',
    pattern: 2,
    warpColor: '#10b981',
    weftColor: '#a7f3d0',
    warpCount: 30,
    weftCount: 20,
    speed: 1.1,
  },
  {
    title: 'Generation 4: Interlocking Hexagons',
    desc: 'Interlocked geometric forms in violet',
    pattern: 3,
    warpColor: '#8b5cf6',
    weftColor: '#ede9fe',
    warpCount: 26,
    weftCount: 18,
    speed: 0.88,
  },
  {
    title: 'Generation 5: Staggered Mesh',
    desc: 'Offset grid pattern in coral pink',
    pattern: 4,
    warpColor: '#fb7185',
    weftColor: '#fef2f2',
    warpCount: 34,
    weftCount: 22,
    speed: 0.92,
  },
  {
    title: 'Generation 6: Radial Pattern',
    desc: 'Radiating spokes from center in gold',
    pattern: 5,
    warpColor: '#d97706',
    weftColor: '#fef3c7',
    warpCount: 28,
    weftCount: 20,
    speed: 1.02,
  },
  {
    title: 'Generation 7: Chevron Pattern',
    desc: 'V-shaped chevrons in turquoise',
    pattern: 6,
    warpColor: '#0891b2',
    weftColor: '#cffafe',
    warpCount: 32,
    weftCount: 20,
    speed: 0.98,
  },
  {
    title: 'Generation 8: Cross-Hatch',
    desc: 'Dense cross-hatched mesh in indigo',
    pattern: 7,
    warpColor: '#4338ca',
    weftColor: '#dbeafe',
    warpCount: 30,
    weftCount: 20,
    speed: 0.89,
  },
  {
    title: 'Generation 9: Zigzag Pattern',
    desc: 'Sawtooth zigzag pattern in rose',
    pattern: 8,
    warpColor: '#be185d',
    weftColor: '#ffe4e6',
    warpCount: 28,
    weftCount: 18,
    speed: 1.05,
  },
  {
    title: 'Generation 10: Spiral Pattern',
    desc: 'Spiraling vortex effect in lime',
    pattern: 9,
    warpColor: '#16a34a',
    weftColor: '#f0fdf4',
    warpCount: 26,
    weftCount: 22,
    speed: 0.91,
  },
  {
    title: 'Generation 11: Layered Scales',
    desc: 'Stacked overlapping scales in slate',
    pattern: 10,
    warpColor: '#475569',
    weftColor: '#e2e8f0',
    warpCount: 32,
    weftCount: 20,
    speed: 0.87,
  },
  {
    title: 'Generation 12: Crystalline Pattern',
    desc: 'Organic crystalline formations in teal',
    pattern: 11,
    warpColor: '#0d9488',
    weftColor: '#ccfbf1',
    warpCount: 30,
    weftCount: 20,
    speed: 1.0,
  },
  {
    title: 'Generation 13: Rietveld Pattern',
    desc: 'De Stijl geometric blocks in primary colors',
    pattern: 12,
    warpColor: '#dc2626',
    weftColor: '#fef2f2',
    warpCount: 27,
    weftCount: 18,
    speed: 0.93,
  },
];

const vertexShaderSource = `
attribute vec2 a_position;
varying vec2 v_uv;
void main() {
  v_uv = a_position * 0.5 + 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}
`;

const fragmentShaderSource = `
precision mediump float;
varying vec2 v_uv;
uniform vec2 u_resolution;
uniform float u_time;
uniform float u_warpCount;
uniform float u_weftCount;
uniform vec3 u_warpColor;
uniform vec3 u_weftColor;
uniform float u_speed;
uniform int u_pattern;
uniform float u_networkShade;
uniform float u_networkStrength;

const float PI = 3.141592653589793;

float modPos(float value, float divisor) {
  return mod(mod(value, divisor) + divisor, divisor);
}

float honeycomb(float row, float col) {
  float offset = mod(row, 2.0) < 0.5 ? 0.0 : 0.5;
  return step(modPos(floor(col + offset), 3.0), 1.999);
}

float diamond(float row, float col) {
  float x = modPos(col, 4.0);
  float y = modPos(row, 4.0);
  return step(abs(x - 2.0) + abs(y - 2.0), 1.999);
}

float serpentine(float row, float col) {
  float wave = sin((row + col) * PI / 4.0);
  float parity = modPos(row + col, 2.0);
  return wave > 0.0 ? step(parity, 0.5) : step(0.5, parity);
}

float hexagon(float row, float col) {
  float centerRow = modPos(row, 4.0);
  float centerCol = modPos(col, 4.0);
  float dist = length(vec2(centerRow - 2.0, centerCol - 2.0));
  return step(dist, 1.8) + step(2.5, dist);
}

float staggered(float row, float col) {
  float rowOffset = floor(row / 2.0);
  return step(modPos(col + rowOffset * 2.0, 4.0), 1.999);
}

float radial(float row, float col) {
  float centerRow = u_weftCount * 0.5;
  float centerCol = u_warpCount * 0.5;
  float angle = atan(row - centerRow, col - centerCol);
  return step(sin(angle * 6.0), 0.0);
}

float chevron(float row, float col) {
  float chevronRow = modPos(row, 6.0);
  float relCol = modPos(col + floor(row / 3.0), 4.0);
  return chevronRow < 3.0 ? step(relCol, 1.999) : step(1.999, relCol);
}

float crosshatch(float row, float col) {
  float x = modPos(row, 6.0);
  float y = modPos(col, 6.0);
  return step(abs(sign(x - 3.0) - sign(y - 3.0)), 0.5);
}

float zigzag(float row, float col) {
  float zigRow = modPos(row, 4.0);
  float shift = floor(col / 2.0);
  return step(abs(sign(zigRow - 2.0) - sign(modPos(shift, 2.0))), 0.5);
}

float spiral(float row, float col) {
  float centerRow = u_weftCount * 0.5;
  float centerCol = u_warpCount * 0.5;
  float dist = length(vec2(row - centerRow, col - centerCol));
  float angle = atan(row - centerRow, col - centerCol);
  return step(mod(dist + angle * 3.0, 4.0), 2.0);
}

float layered(float row, float col) {
  float layer = floor(row / 3.0);
  float inLayer = modPos(row, 3.0);
  float base = modPos(floor((col + layer) / 2.0), 2.0);
  return inLayer == 1.0 ? step(base, 0.5) : step(0.5, base);
}

float crystalline(float row, float col) {
  float seed = modPos(row * 738.56093 + col * 193.49663, 256.0);
  return step(mod(seed + row * col, 2.0), 0.5);
}

float rietveld(float row, float col) {
  float blockSize = 3.0;
  float rowBlock = floor(row / blockSize);
  float colBlock = floor(col / blockSize);
  float blockPattern = modPos(rowBlock + colBlock, 3.0);
  float inBlockRow = modPos(row, blockSize);
  float inBlockCol = modPos(col, blockSize);
  if (blockPattern < 0.5) {
    return step(inBlockRow, 1.999);
  }
  if (blockPattern < 1.5) {
    return step(inBlockCol, 1.999);
  }
  return step(inBlockRow + inBlockCol, 2.999);
}

float evaluatePattern(float row, float col) {
  if (u_pattern == 0) return honeycomb(row, col);
  if (u_pattern == 1) return diamond(row, col);
  if (u_pattern == 2) return serpentine(row, col);
  if (u_pattern == 3) return hexagon(row, col);
  if (u_pattern == 4) return staggered(row, col);
  if (u_pattern == 5) return radial(row, col);
  if (u_pattern == 6) return chevron(row, col);
  if (u_pattern == 7) return crosshatch(row, col);
  if (u_pattern == 8) return zigzag(row, col);
  if (u_pattern == 9) return spiral(row, col);
  if (u_pattern == 10) return layered(row, col);
  if (u_pattern == 11) return crystalline(row, col);
  if (u_pattern == 12) return rietveld(row, col);
  return 0.0;
}

vec3 adjustColor(vec3 color, float amount) {
  return clamp(color + vec3(amount), 0.0, 1.0);
}

void main() {
  vec2 fragCoord = v_uv * u_resolution;
  vec2 cellSize = vec2(u_resolution.x / u_warpCount, u_resolution.y / u_weftCount);
  vec2 cell = floor(fragCoord / cellSize);
  float row = cell.y;
  float col = cell.x;

  float rowDuration = 1200.0 / u_speed;
  float totalDuration = rowDuration * u_weftCount;
  float rawProgress = mod(u_time, totalDuration) / totalDuration;
  float activeRow = min(u_weftCount - 1.0, floor(rawProgress * u_weftCount));
  float rowProgress = rawProgress * u_weftCount - activeRow;
  float shuttleDirection = mod(activeRow, 2.0) < 0.5 ? 1.0 : -1.0;
  float shuttleRatio = shuttleDirection > 0.0 ? rowProgress : 1.0 - rowProgress;
  float rowAlpha = row < activeRow ? 1.0 : row == activeRow ? 0.92 : 0.24;

  float weaveProgress = 0.0;
  if (row < activeRow) {
    weaveProgress = 1.0;
  } else if (row == activeRow) {
    float threshold = shuttleRatio * u_warpCount;
    weaveProgress = step(col, threshold);
  }

  float warpOnTop = evaluatePattern(row, col);
  vec3 topColor = warpOnTop > 0.5 ? u_warpColor : u_weftColor;
  vec3 underColor = warpOnTop > 0.5 ? u_weftColor : u_warpColor;
  vec3 cellColor = mix(underColor, topColor, rowAlpha);

  if (row == activeRow && weaveProgress < 0.5) {
    cellColor = mix(cellColor, vec3(0.05, 0.08, 0.14), 0.55);
  }
  if (row > activeRow) {
    cellColor = mix(vec3(0.05, 0.08, 0.14), cellColor, 0.38);
  }

  vec2 local = fract(fragCoord / cellSize);
  float line = smoothstep(0.03, 0.05, min(local.x, local.y));
  vec3 lineColor = mix(cellColor, vec3(1.0), 0.04 * (1.0 - line));

  float highlight = smoothstep(0.02, 0.06, abs(local.x - 0.5)) * smoothstep(0.02, 0.06, abs(local.y - 0.5));
  vec3 finalColor = mix(lineColor, adjustColor(cellColor, 0.12), highlight * 0.08);

  float netPulse = sin((v_uv.x + v_uv.y) * 20.0 + u_time * 2.0) * 0.5 + 0.5;
  float netGrid = smoothstep(0.42, 0.48, fract(v_uv.x * 12.0 + u_time * 0.4));
  netGrid += smoothstep(0.42, 0.48, fract(v_uv.y * 12.0 + u_time * 0.45));
  netGrid = clamp(netGrid * 0.65 + netPulse * 0.35, 0.0, 1.0);
  vec3 networkOverlay = mix(finalColor * 0.7, vec3(0.08, 0.42, 0.82), 0.55);
  finalColor = mix(finalColor, networkOverlay, u_networkShade * u_networkStrength * netGrid * 0.25);

  gl_FragColor = vec4(finalColor, 1.0);
}
`;

function createShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const info = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(`Shader compile failed: ${info}`);
  }
  return shader;
}

function createProgram(gl, vertexSrc, fragmentSrc) {
  const program = gl.createProgram();
  const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexSrc);
  const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentSrc);
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(program);
    gl.deleteProgram(program);
    throw new Error(`Program link failed: ${info}`);
  }
  return program;
}

class WeaveAnimator {
  constructor(canvas, options) {
    this.canvas = canvas;
    this.options = { ...options };
    this.time = 0;
    this.paused = false;
    this.rafId = null;
    this.lastTimestamp = 0;
    this.boundTick = this.tick.bind(this);
    this.initGL();
  }

  initGL() {
    const gl = this.canvas.getContext('webgl') || this.canvas.getContext('experimental-webgl');
    if (!gl) {
      this.canvas.parentNode.innerHTML = '<div style="color:#fff;padding:16px;font-family:sans-serif;">WebGL not supported</div>';
      return;
    }

    this.gl = gl;
    this.program = createProgram(gl, vertexShaderSource, fragmentShaderSource);
    this.positionAttribute = gl.getAttribLocation(this.program, 'a_position');
    this.uniforms = {
      resolution: gl.getUniformLocation(this.program, 'u_resolution'),
      time: gl.getUniformLocation(this.program, 'u_time'),
      warpCount: gl.getUniformLocation(this.program, 'u_warpCount'),
      weftCount: gl.getUniformLocation(this.program, 'u_weftCount'),
      warpColor: gl.getUniformLocation(this.program, 'u_warpColor'),
      weftColor: gl.getUniformLocation(this.program, 'u_weftColor'),
      speed: gl.getUniformLocation(this.program, 'u_speed'),
      pattern: gl.getUniformLocation(this.program, 'u_pattern'),
      networkShade: gl.getUniformLocation(this.program, 'u_networkShade'),
      networkStrength: gl.getUniformLocation(this.program, 'u_networkStrength'),
    };

    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
      -1, -1,
      1, -1,
      -1, 1,
      1, 1,
    ]), gl.STATIC_DRAW);

    this.positionBuffer = positionBuffer;
    gl.useProgram(this.program);
    gl.enableVertexAttribArray(this.positionAttribute);
    gl.vertexAttribPointer(this.positionAttribute, 2, gl.FLOAT, false, 0, 0);
    gl.clearColor(0.04, 0.06, 0.12, 1.0);
  }

  resize() {
    if (!this.gl) return;
    const pixelRatio = window.devicePixelRatio || 1;
    const rect = this.canvas.getBoundingClientRect();
    const width = Math.max(1, Math.floor(rect.width * pixelRatio));
    const height = Math.max(1, Math.floor(rect.height * pixelRatio));
    if (this.canvas.width === width && this.canvas.height === height) return;
    this.canvas.width = width;
    this.canvas.height = height;
    this.gl.viewport(0, 0, width, height);
  }

  start() {
    if (!this.gl) return;
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
    if (!this.paused) {
      this.time += delta;
    }
    this.render();
    this.rafId = requestAnimationFrame(this.boundTick);
  }

  togglePause() {
    this.paused = !this.paused;
    return this.paused;
  }

  setPattern(newPattern) {
    this.options.pattern = newPattern;
  }

  cyclePattern(direction) {
    const newPattern = (this.options.pattern + direction + generationConfigs.length) % generationConfigs.length;
    this.options.pattern = newPattern;
  }

  adjustSpeed(delta) {
    this.options.speed = Math.max(0.2, Math.min(3.0, this.options.speed + delta));
  }

  setSpeed(value) {
    this.options.speed = Math.max(0.2, Math.min(3.0, value));
  }

  render() {
    if (!this.gl) return;
    this.resize();

    const gl = this.gl;
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(this.program);
    gl.uniform2f(this.uniforms.resolution, this.canvas.width, this.canvas.height);
    gl.uniform1f(this.uniforms.time, this.time);
    gl.uniform1f(this.uniforms.warpCount, this.options.warpCount);
    gl.uniform1f(this.uniforms.weftCount, this.options.weftCount);
    gl.uniform3fv(this.uniforms.warpColor, hexToRGB(this.options.warpColor));
    gl.uniform3fv(this.uniforms.weftColor, hexToRGB(this.options.weftColor));
    gl.uniform1f(this.uniforms.speed, this.options.speed);
    gl.uniform1i(this.uniforms.pattern, this.options.pattern);
    gl.uniform1f(this.uniforms.networkShade, networkState.shade);
    gl.uniform1f(this.uniforms.networkStrength, networkState.strength);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
}

function hexToRGB(hex) {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  return new Float32Array([r, g, b]);
}

const networkState = {
  shade: 0.0,
  strength: 0.0,
  status: 'unknown',
  details: 'not discovered',
};

const allAnimators = [];

function updateNetworkStatusDisplay() {
  const statusEl = document.getElementById('networkStatus');
  const shadeEl = document.getElementById('networkShade');
  if (statusEl) statusEl.textContent = networkState.status;
  if (shadeEl) shadeEl.textContent = networkState.shade > 0.0 ? 'on' : 'off';
}

function discoverLocalNetworks() {
  const button = document.getElementById('discoverNetworkBtn');
  if (button) button.disabled = true;

  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  const isOnline = navigator.onLine;
  let shade = 0.0;
  let strength = 0.0;
  let status = 'network unavailable';
  let details = 'no connection info';

  if (!isOnline) {
    status = 'offline';
    details = 'offline';
  } else if (connection) {
    const type = connection.type || 'unknown';
    const effectiveType = connection.effectiveType || 'unknown';
    const downlink = connection.downlink || 0;
    const rtt = connection.rtt || 0;
    status = `${type}/${effectiveType}`;
    details = `downlink ${downlink.toFixed(1)} Mbps, rtt ${rtt.toFixed(0)} ms`;
    strength = Math.min(1.0, Math.max(0.1, downlink / 12));
    shade = effectiveType.includes('wifi') || type === 'wifi' || effectiveType === '4g' ? 1.0 : 0.55;
  } else {
    status = 'unsupported';
    details = 'Network Information API unavailable';
    shade = 0.45;
    strength = 0.35;
  }

  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    status = 'local host';
    details = 'running locally';
    shade = 1.0;
    strength = 0.85;
  }

  networkState.status = status;
  networkState.details = details;
  networkState.shade = shade;
  networkState.strength = strength;
  updateNetworkStatusDisplay();
  if (button) button.disabled = false;
}

function initializeGenerations() {
  const container = document.getElementById('generationsContainer');
  if (!container) return;

  generationConfigs.forEach((config, index) => {
    const card = document.createElement('div');
    card.className = 'generation';
    card.innerHTML = `
      <div class="generation-header">
        <div class="generation-title">${config.title}</div>
        <div class="generation-desc">${config.desc}</div>
      </div>
      <div class="canvas-wrapper">
        <div class="hud-panel">
          <button class="hud-button hud-toggle" title="Pause / Resume">⏸</button>
          <button class="hud-button hud-prev" title="Previous pattern">◀</button>
          <button class="hud-button hud-next" title="Next pattern">▶</button>
          <button class="hud-button hud-slower" title="Slower">−</button>
          <button class="hud-button hud-faster" title="Faster">+</button>
          <div class="hud-info">
            <div>Pattern <strong class="hud-pattern">${getPatternName(config.pattern)}</strong></div>
            <div>Speed <strong class="hud-speed">${config.speed.toFixed(1)}x</strong></div>
          </div>
        </div>
        <canvas id="canvas-${index}" width="500" height="280"></canvas>
      </div>
      <div class="generation-footer">
        <span>${getPatternName(config.pattern)}</span>
        <span>${config.warpCount}×${config.weftCount}</span>
      </div>
    `;
    container.appendChild(card);

    const canvas = document.getElementById(`canvas-${index}`);
    const animator = new WeaveAnimator(canvas, config);
    allAnimators.push(animator);
    animator.start();

    const hud = card.querySelector('.hud-panel');
    const patternLabel = hud.querySelector('.hud-pattern');
    const speedLabel = hud.querySelector('.hud-speed');
    const pauseButton = hud.querySelector('.hud-toggle');
    const prevButton = hud.querySelector('.hud-prev');
    const nextButton = hud.querySelector('.hud-next');
    const slowerButton = hud.querySelector('.hud-slower');
    const fasterButton = hud.querySelector('.hud-faster');

    const refreshHud = () => {
      patternLabel.textContent = getPatternName(animator.options.pattern);
      speedLabel.textContent = `${animator.options.speed.toFixed(1)}x`;
      pauseButton.textContent = animator.paused ? '▶' : '⏸';
    };

    prevButton.addEventListener('click', () => {
      animator.cyclePattern(-1);
      refreshHud();
    });
    nextButton.addEventListener('click', () => {
      animator.cyclePattern(1);
      refreshHud();
    });
    slowerButton.addEventListener('click', () => {
      animator.adjustSpeed(-0.1);
      refreshHud();
    });
    fasterButton.addEventListener('click', () => {
      animator.adjustSpeed(0.1);
      refreshHud();
    });
    pauseButton.addEventListener('click', () => {
      animator.togglePause();
      refreshHud();
    });

    refreshHud();
  });

  const networkButton = document.getElementById('discoverNetworkBtn');
  if (networkButton) {
    networkButton.addEventListener('click', discoverLocalNetworks);
  }
  updateNetworkStatusDisplay();
}

function getPatternName(index) {
  const names = [
    'honeycomb', 'diamond', 'serpentine', 'hexagon', 'staggered', 'radial',
    'chevron', 'crosshatch', 'zigzag', 'spiral', 'layered', 'crystalline', 'rietveld',
  ];
  return names[index] || 'unknown';
}

function updateAverageSpeedDisplay() {
  const averageEl = document.getElementById('averageSpeed');
  if (!averageEl) return;
  if (allAnimators.length === 0) {
    averageEl.textContent = '0.00x';
    return;
  }
  const total = allAnimators.reduce((sum, animator) => sum + animator.options.speed, 0);
  const average = total / allAnimators.length;
  averageEl.textContent = `${average.toFixed(2)}x`;
}

window.startAllAnimations = function () {
  allAnimators.forEach(animator => animator.start());
};

window.stopAllAnimations = function () {
  allAnimators.forEach(animator => animator.stop());
};

window.toggleAllPaused = function () {
  allAnimators.forEach(animator => animator.togglePause());
};

window.prevPatternAll = function () {
  allAnimators.forEach(animator => animator.cyclePattern(-1));
};

window.nextPatternAll = function () {
  allAnimators.forEach(animator => animator.cyclePattern(1));
};

window.slowerAll = function () {
  allAnimators.forEach(animator => animator.adjustSpeed(-0.1));
  updateAverageSpeedDisplay();
};

window.fasterAll = function () {
  allAnimators.forEach(animator => animator.adjustSpeed(0.1));
  updateAverageSpeedDisplay();
};

if (document.readyState === 'loading') {
  window.addEventListener('DOMContentLoaded', initializeGenerations);
} else {
  initializeGenerations();
}

window.addEventListener('resize', () => {
  allAnimators.forEach(animator => animator.resize());
});
