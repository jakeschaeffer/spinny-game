import { WORLD_W, START_Y, hookRadius } from './engine';

const WALL_W = 7;
const PLAYER_R = 10;
const MAX_PIXELS = 4_000_000;

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.ceil(w));
  c.height = Math.max(1, Math.ceil(h));
  return c;
}

// Nodes are pre-rendered (glow included) once per scale so each frame is a
// single drawImage instead of gradients + shadow blur.
function renderNodeSprite(node, scale) {
  const glow = 14;
  const half = node.radius + glow;
  const c = makeCanvas(half * 2 * scale, half * 2 * scale);
  const ctx = c.getContext('2d');
  const { main, light, dark } = node.scheme;
  ctx.scale(scale, scale);
  ctx.translate(half, half);
  const r = node.radius;

  ctx.shadowColor = main;
  ctx.shadowBlur = glow * scale;
  ctx.fillStyle = main;
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;

  ctx.save();
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.clip();
  if (node.pattern === 0) {
    const grad = ctx.createRadialGradient(-r * 0.3, -r * 0.3, 0, 0, 0, r);
    grad.addColorStop(0, light);
    grad.addColorStop(0.6, main);
    grad.addColorStop(1, dark);
    ctx.fillStyle = grad;
    ctx.fillRect(-r, -r, r * 2, r * 2);
  } else if (node.pattern === 1) {
    const grad = ctx.createLinearGradient(-r, -r, r, r);
    grad.addColorStop(0, light);
    grad.addColorStop(0.5, main);
    grad.addColorStop(1, dark);
    ctx.fillStyle = grad;
    ctx.fillRect(-r, -r, r * 2, r * 2);
  } else {
    ctx.fillStyle = main;
    ctx.fillRect(-r, -r, r * 2, r * 2);
    ctx.strokeStyle = light;
    ctx.lineWidth = 3.5;
    for (let i = -r * 2; i < r * 2; i += 8) {
      ctx.beginPath();
      ctx.moveTo(i, -r);
      ctx.lineTo(i + r * 2, r);
      ctx.stroke();
    }
    const shade = ctx.createRadialGradient(-r * 0.3, -r * 0.3, r * 0.2, 0, 0, r);
    shade.addColorStop(0, 'rgba(255,255,255,0.15)');
    shade.addColorStop(1, 'rgba(0,0,0,0.25)');
    ctx.fillStyle = shade;
    ctx.fillRect(-r, -r, r * 2, r * 2);
  }
  ctx.restore();

  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(0, 0, r - 0.5, Math.PI * 1.05, Math.PI * 1.55);
  ctx.stroke();

  return { canvas: c, half };
}

function renderOrbSprite(scale, color, glowColor) {
  const glow = 18;
  const half = PLAYER_R + glow;
  const c = makeCanvas(half * 2 * scale, half * 2 * scale);
  const ctx = c.getContext('2d');
  ctx.scale(scale, scale);
  ctx.translate(half, half);
  const halo = ctx.createRadialGradient(0, 0, PLAYER_R * 0.5, 0, 0, half);
  halo.addColorStop(0, glowColor);
  halo.addColorStop(1, 'rgba(249,115,22,0)');
  ctx.fillStyle = halo;
  ctx.fillRect(-half, -half, half * 2, half * 2);
  const body = ctx.createRadialGradient(-3, -3, 0, 0, 0, PLAYER_R);
  body.addColorStop(0, '#fff7d6');
  body.addColorStop(0.35, color);
  body.addColorStop(1, '#ea580c');
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.arc(0, 0, PLAYER_R, 0, Math.PI * 2);
  ctx.fill();
  return { canvas: c, half };
}

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d', { alpha: false });
  let scale = 1;
  let H = 600;
  let bgGradient = null;
  let wallGradient = null;
  let orb = null;
  let orbHot = null;
  const nodeSprites = new WeakMap();
  const stars = Array.from({ length: 70 }, () => ({
    x: Math.random() * WORLD_W,
    y: Math.random(),
    r: 0.4 + Math.random() * 1.1,
    a: 0.15 + Math.random() * 0.45,
    depth: 0.15 + Math.random() * 0.35,
    twinkle: Math.random() * Math.PI * 2,
  }));

  function resize(width, height, devicePixelRatio, worldH) {
    let dpr = Math.min(devicePixelRatio || 1, 3);
    while (width * height * dpr * dpr > MAX_PIXELS && dpr > 1) dpr -= 0.25;
    H = worldH;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    const newScale = canvas.width / WORLD_W;
    if (newScale !== scale) {
      scale = newScale;
      orb = renderOrbSprite(scale, '#fbbf24', 'rgba(249,115,22,0.55)');
      orbHot = renderOrbSprite(scale, '#fde68a', 'rgba(251,191,36,0.8)');
    }
    bgGradient = ctx.createLinearGradient(0, 0, 0, H);
    bgGradient.addColorStop(0, '#0b0a1f');
    bgGradient.addColorStop(0.55, '#15123a');
    bgGradient.addColorStop(1, '#1d1447');
    wallGradient = ctx.createLinearGradient(0, 0, 0, H);
    wallGradient.addColorStop(0, '#ec4899');
    wallGradient.addColorStop(1, '#6366f1');
  }

  function spriteFor(node) {
    let sprite = nodeSprites.get(node);
    if (!sprite || sprite.scale !== scale) {
      sprite = { ...renderNodeSprite(node, scale), scale, highlight: 0 };
      nodeSprites.set(node, sprite);
    }
    return sprite;
  }

  function drawBackground(g, now) {
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    ctx.fillStyle = bgGradient;
    ctx.fillRect(0, 0, WORLD_W, H);
    for (const s of stars) {
      const y = (((s.y * H - g.cameraY * s.depth) % H) + H) % H;
      const a = s.a * (0.7 + 0.3 * Math.sin(now * 0.0015 + s.twinkle));
      ctx.globalAlpha = a;
      ctx.fillStyle = '#c7d2fe';
      ctx.fillRect(s.x, y, s.r * 1.4, s.r * 1.4);
    }
    ctx.globalAlpha = 1;
  }

  function drawMarkers(g) {
    const top = g.cameraY;
    const bottom = g.cameraY + H;
    const first = Math.max(1, Math.ceil((START_Y - bottom) / 100));
    const last = Math.floor((START_Y - top) / 100) + 1;
    ctx.font = '600 10px system-ui, -apple-system, sans-serif';
    ctx.textBaseline = 'bottom';
    for (let i = first; i <= last; i++) {
      const y = START_Y - i * 100;
      ctx.fillStyle = 'rgba(255,255,255,0.07)';
      ctx.fillRect(WALL_W, y, WORLD_W - WALL_W * 2, 1);
      ctx.fillStyle = 'rgba(199,210,254,0.35)';
      ctx.fillText(`${i * 10}m`, WALL_W + 8, y - 3);
    }
  }

  function strokeTrail(points) {
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
    ctx.stroke();
  }

  function drawTrail(g, settings) {
    let points = g.trail;
    if (g.status === 'playing' || g.status === 'menu') {
      points = points.concat([{ x: g.player.x, y: g.player.y }]);
    }
    if (settings.infiniteTrail) {
      const minY = g.cameraY - 40;
      const maxY = g.cameraY + H + 40;
      points = points.filter((p) => p.y >= minY && p.y <= maxY);
    }
    if (points.length < 2) return;
    const a = points[0];
    const b = points[points.length - 1];
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.strokeStyle = 'rgba(236,72,153,0.16)';
    ctx.lineWidth = 10;
    strokeTrail(points);

    const grad = ctx.createLinearGradient(a.x, a.y, b.x, b.y || a.y + 1);
    grad.addColorStop(0, settings.infiniteTrail ? 'rgba(99,102,241,0.9)' : 'rgba(99,102,241,0)');
    grad.addColorStop(0.5, 'rgba(168,85,247,0.9)');
    grad.addColorStop(1, '#ec4899');
    ctx.strokeStyle = grad;
    ctx.lineWidth = 3.5;
    strokeTrail(points);
  }

  function drawNodes(g, settings, now) {
    const minY = g.cameraY - 60;
    const maxY = g.cameraY + H + 60;
    const showRing = settings.hookIndicator && g.status === 'playing' && g.nearest && !g.hooked;
    if (showRing) {
      const n = g.nearest;
      const pulse = 0.5 + 0.5 * Math.sin(now * 0.006);
      ctx.save();
      ctx.setLineDash([6, 8]);
      ctx.lineDashOffset = -now * 0.02;
      ctx.strokeStyle = n.scheme.light;
      ctx.globalAlpha = 0.25 + pulse * 0.2;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(n.x, n.y, hookRadius(n), 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
    for (const node of g.nodes) {
      if (node.y < minY || node.y > maxY) continue;
      const sprite = spriteFor(node);
      const isTarget = node === g.hooked || (showRing && node === g.nearest);
      sprite.highlight += ((isTarget ? 1 : 0) - sprite.highlight) * 0.2;
      const size = sprite.half * (1 + sprite.highlight * 0.1);
      ctx.drawImage(sprite.canvas, node.x - size, node.y - size, size * 2, size * 2);
    }
  }

  function drawHookLine(g) {
    if (!g.hooked || !g.holding) return;
    const { x, y } = g.hooked;
    const px = g.player.x;
    const py = g.player.y;
    ctx.lineCap = 'round';
    ctx.strokeStyle = 'rgba(244,114,182,0.2)';
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(px, py);
    ctx.stroke();
    const grad = ctx.createLinearGradient(x, y, px, py);
    grad.addColorStop(0, 'rgba(255,255,255,0.9)');
    grad.addColorStop(1, 'rgba(249,168,212,0.9)');
    ctx.strokeStyle = grad;
    ctx.lineWidth = 1.75;
    ctx.stroke();
  }

  function drawEffects(g) {
    for (const r of g.ripples) {
      ctx.globalAlpha = Math.max(0, r.life) * 0.8;
      ctx.strokeStyle = r.color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r + (1 - r.life) * 26, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (g.particles.length) {
      ctx.globalCompositeOperation = 'lighter';
      for (const p of g.particles) {
        ctx.globalAlpha = Math.max(0, p.life);
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size * (0.5 + p.life * 0.5), 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalCompositeOperation = 'source-over';
    }
    ctx.globalAlpha = 1;
  }

  function drawPlayer(g, now) {
    if (g.status === 'dying' || g.status === 'dead') return;
    let { x, y } = g.player;
    if (g.status === 'menu') y += Math.sin(now * 0.003) * 4;
    const sprite = g.holding ? orbHot : orb;
    const size = sprite.half * (g.holding ? 1.12 : 1);
    ctx.drawImage(sprite.canvas, x - size, y - size, size * 2, size * 2);
  }

  function drawWalls() {
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    ctx.fillStyle = wallGradient;
    ctx.globalAlpha = 0.18;
    ctx.fillRect(0, 0, WALL_W + 6, H);
    ctx.fillRect(WORLD_W - WALL_W - 6, 0, WALL_W + 6, H);
    ctx.globalAlpha = 0.9;
    ctx.fillRect(0, 0, WALL_W - 2, H);
    ctx.fillRect(WORLD_W - WALL_W + 2, 0, WALL_W - 2, H);
    ctx.globalAlpha = 1;
  }

  function draw(g, settings, now) {
    if (!bgGradient) return;
    drawBackground(g, now);

    const shakeX = g.shake ? (Math.random() - 0.5) * g.shake : 0;
    const shakeY = g.shake ? (Math.random() - 0.5) * g.shake : 0;
    ctx.setTransform(scale, 0, 0, scale, shakeX * scale, (shakeY - g.cameraY) * scale);

    drawMarkers(g);
    drawTrail(g, settings);
    drawNodes(g, settings, now);
    drawHookLine(g);
    drawEffects(g);
    drawPlayer(g, now);
    drawWalls();
  }

  return { resize, draw };
}
