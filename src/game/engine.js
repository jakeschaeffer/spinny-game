// Pure game simulation. Everything is in world units (400 wide) and time is
// measured in "frames" at 60fps so tuning constants match the original feel.

export const WORLD_W = 400;
export const START_Y = 500;
export const METERS_PER_UNIT = 0.1; // height markers: 100 units = 10m

const WALL = 12;
const PLAYER_R = 6;
const BASE_LAUNCH_SPEED = 5.5;
const START_SPEED = 4;
const HOOK_RANGE = 180; // hook radius for a 16px node; scales with node size
const GRAVITY = 0.015;
const COMBO_WINDOW = 120; // frames between launch and next hook
const GRACE_FRAMES = 30;
const DEATH_ANIM_FRAMES = 50;
const TRAIL_SPACING = 4;
const TRAIL_LENGTH = 55;

export const COLOR_SCHEMES = [
  { main: '#4ade80', light: '#86efac', dark: '#16a34a' },
  { main: '#38bdf8', light: '#7dd3fc', dark: '#0284c7' },
  { main: '#818cf8', light: '#a5b4fc', dark: '#4f46e5' },
  { main: '#fb7185', light: '#fda4af', dark: '#e11d48' },
  { main: '#facc15', light: '#fde047', dark: '#ca8a04' },
  { main: '#f97316', light: '#fdba74', dark: '#c2410c' },
  { main: '#c084fc', light: '#d8b4fe', dark: '#9333ea' },
  { main: '#34d399', light: '#6ee7b7', dark: '#059669' },
];

export const hookRadius = (node) => HOOK_RANGE * (node.radius / 16);

export function createGame(worldH) {
  const g = { H: worldH, events: [] };
  resetGame(g, 'menu');
  return g;
}

export function resetGame(g, status = 'playing') {
  g.status = status;
  g.time = 0;
  g.player = { x: WORLD_W / 2, y: START_Y };
  g.vel = { x: 0, y: -START_SPEED };
  g.cameraY = START_Y - g.H * 0.8;
  g.bestY = START_Y;
  g.score = 0;
  g.hooked = null;
  g.hookAngle = 0;
  g.hookDistance = 0;
  g.spinDir = 1;
  g.holding = false;
  g.nearest = null;
  g.combo = 0;
  g.lastLaunchTime = -Infinity;
  g.grace = GRACE_FRAMES;
  g.deathTimer = 0;
  g.shake = 0;
  g.trail = [{ x: g.player.x, y: g.player.y }];
  g.particles = [];
  g.ripples = [];
  g.nodes = [];
  g.nextId = 1;
  g.nextNodeY = START_Y - 20;
  g.events.length = 0;
  spawnNodes(g);
}

export function setWorldHeight(g, worldH) {
  g.H = worldH;
  if (g.status === 'menu') resetGame(g, 'menu');
  else spawnNodes(g);
}

function makeNode(g, y) {
  const radius = Math.round(18 * (0.7 + Math.random() * 1.1));
  const recent = g.nodes.slice(-3);
  let x = 0;
  // Try a few spots so nodes don't overlap and the launch column stays clear.
  for (let attempt = 0; attempt < 10; attempt++) {
    x = 50 + Math.random() * (WORLD_W - 100);
    const clearOfStart = y < START_Y - 260 || Math.abs(x - WORLD_W / 2) > radius + 30;
    const clearOfOthers = recent.every(
      (n) => Math.hypot(n.x - x, n.y - y) > n.radius + radius + 36
    );
    if (clearOfStart && clearOfOthers) break;
  }
  return {
    id: g.nextId++,
    x,
    y,
    radius,
    scheme: COLOR_SCHEMES[Math.floor(Math.random() * COLOR_SCHEMES.length)],
    pattern: Math.floor(Math.random() * 3),
  };
}

function spawnNodes(g) {
  while (g.nextNodeY > g.cameraY - 300) {
    g.nodes.push(makeNode(g, g.nextNodeY));
    g.nextNodeY -= 80 + Math.random() * 45;
  }
  const cutoff = g.cameraY + g.H + 200;
  if (g.nodes.length && g.nodes[0].y - g.nodes[0].radius > cutoff) {
    g.nodes = g.nodes.filter((n) => n === g.hooked || n.y - n.radius <= cutoff);
  }
}

function findNearest(g) {
  let best = null;
  let bestDist = Infinity;
  for (const node of g.nodes) {
    const d = Math.hypot(node.x - g.player.x, node.y - g.player.y);
    if (d < hookRadius(node) && d < bestDist) {
      best = node;
      bestDist = d;
    }
  }
  return best ? { node: best, distance: bestDist } : null;
}

export function press(g) {
  if (g.status !== 'playing') return;
  g.holding = true;
  if (g.hooked) return;

  const target = findNearest(g);
  if (!target) return;

  const { node, distance } = target;
  const dx = g.player.x - node.x;
  const dy = g.player.y - node.y;
  g.hooked = node;
  g.hookAngle = Math.atan2(dy, dx);
  g.hookDistance = distance;
  g.spinDir = Math.sign(dx * g.vel.y - dy * g.vel.x) || 1;
  g.combo = g.time - g.lastLaunchTime < COMBO_WINDOW ? g.combo + 1 : 1;
  g.ripples.push({ x: node.x, y: node.y, r: node.radius, life: 1, color: node.scheme.light });
  g.events.push({ type: 'hook', combo: g.combo });
}

export function release(g, silent = false) {
  g.holding = false;
  if (!g.hooked) return;
  const angle = g.hookAngle + (g.spinDir * Math.PI) / 2;
  const speed = BASE_LAUNCH_SPEED + Math.min(g.combo * 0.1, 1);
  g.vel = { x: Math.cos(angle) * speed, y: Math.sin(angle) * speed };
  g.hooked = null;
  g.lastLaunchTime = g.time;
  if (!silent) g.events.push({ type: 'launch' });
}

function die(g) {
  g.status = 'dying';
  g.deathTimer = DEATH_ANIM_FRAMES;
  g.shake = 12;
  g.hooked = null;
  g.holding = false;
  const colors = ['#fbbf24', '#f97316', '#ec4899', '#ffffff'];
  for (let i = 0; i < 36; i++) {
    const a = Math.random() * Math.PI * 2;
    const s = 1 + Math.random() * 5;
    g.particles.push({
      x: g.player.x,
      y: g.player.y,
      vx: Math.cos(a) * s,
      vy: Math.sin(a) * s,
      life: 1,
      decay: 0.015 + Math.random() * 0.02,
      size: 1.5 + Math.random() * 2.5,
      color: colors[i % colors.length],
    });
  }
  g.events.push({ type: 'death' });
}

function collides(g, x, y) {
  if (g.grace > 0) return false;
  for (const node of g.nodes) {
    if (node === g.hooked) continue;
    const r = node.radius + PLAYER_R;
    const dx = x - node.x;
    const dy = y - node.y;
    if (dx * dx + dy * dy < r * r) return true;
  }
  if (!g.hooked && (x < WALL || x > WORLD_W - WALL)) return true;
  return y > g.cameraY + g.H + 40;
}

// Advance the simulation by `dt` frames. `settings.speed` scales time, so the
// same trajectories play out faster or slower.
export function step(g, dt, settings) {
  updateEffects(g, dt);
  if (g.status === 'dying') {
    g.deathTimer -= dt;
    if (g.deathTimer <= 0) {
      g.status = 'dead';
      g.events.push({ type: 'gameover', score: g.score });
    }
    return;
  }
  if (g.status !== 'playing') return;

  const sdt = dt * settings.speed;
  g.time += sdt;
  g.grace = Math.max(0, g.grace - sdt);

  let x;
  let y;
  if (g.hooked && g.holding) {
    const distanceFactor = Math.min(1.5, Math.max(0.5, g.hookDistance / 100));
    g.hookAngle += (0.055 / distanceFactor) * g.spinDir * sdt;
    x = g.hooked.x + Math.cos(g.hookAngle) * g.hookDistance;
    y = g.hooked.y + Math.sin(g.hookAngle) * g.hookDistance;
  } else {
    if (settings.gravity) g.vel.y += GRAVITY * sdt;
    x = g.player.x + g.vel.x * sdt;
    y = g.player.y + g.vel.y * sdt;
  }

  if (collides(g, x, y)) {
    die(g);
    return;
  }
  g.player.x = x;
  g.player.y = y;

  const last = g.trail[g.trail.length - 1];
  if (!last || Math.hypot(x - last.x, y - last.y) >= TRAIL_SPACING) {
    g.trail.push({ x, y });
    if (!settings.infiniteTrail && g.trail.length > TRAIL_LENGTH) {
      g.trail.splice(0, g.trail.length - TRAIL_LENGTH);
    }
  }
  if (settings.infiniteTrail) {
    // Points far below the camera can never be seen again (falling there is fatal).
    const cutoff = g.cameraY + g.H + 150;
    let drop = 0;
    while (drop < g.trail.length - 2 && g.trail[drop].y > cutoff) drop++;
    if (drop) g.trail.splice(0, drop);
  }

  // Camera only ever moves up, easing toward the player.
  const target = y - g.H * 0.45;
  if (target < g.cameraY) g.cameraY += (target - g.cameraY) * (1 - Math.pow(0.88, dt));

  if (y < g.bestY) {
    g.bestY = y;
    g.score = Math.max(0, Math.floor((START_Y - y) * METERS_PER_UNIT));
  }

  spawnNodes(g);
  g.nearest = g.hooked ? null : findNearest(g)?.node ?? null;
}

function updateEffects(g, dt) {
  if (g.shake > 0) g.shake = Math.max(0, g.shake - dt * 0.6);
  for (const p of g.particles) {
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vx *= Math.pow(0.96, dt);
    p.vy = p.vy * Math.pow(0.96, dt) + 0.05 * dt;
    p.life -= p.decay * dt;
  }
  if (g.particles.length) g.particles = g.particles.filter((p) => p.life > 0);
  for (const r of g.ripples) r.life -= 0.045 * dt;
  if (g.ripples.length) g.ripples = g.ripples.filter((r) => r.life > 0);
}
