import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import {
  WORLD_W,
  createGame,
  press,
  release,
  resetGame,
  setWorldHeight,
  step,
} from './game/engine';
import { createRenderer } from './game/renderer';
import { setSoundEnabled, sfx, unlockAudio } from './game/audio';

const SETTINGS_KEY = 'oml.settings.v1';
const BEST_KEY = 'oml.best.v1';
const DEFAULT_SETTINGS = {
  sound: true,
  hookIndicator: true,
  gravity: true,
  infiniteTrail: false,
  speed: 1,
};
const SPEED_MIN = 0.25;
const SPEED_MAX = 2;
const MAX_FRAME_STEP = 0.5; // physics substep, in 60fps frames
const RESTART_DELAY_MS = 450;

const isTouchDevice =
  typeof window !== 'undefined' && window.matchMedia?.('(pointer: coarse)').matches;

function loadSettings() {
  try {
    return { ...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem(SETTINGS_KEY)) };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

function loadBest() {
  return parseInt(localStorage.getItem(BEST_KEY) ?? '0', 10) || 0;
}

const clampSpeed = (v) => Math.min(SPEED_MAX, Math.max(SPEED_MIN, Math.round(v * 100) / 100));

// Fit a portrait play area into the available space. Phones get the full
// screen; desktops get a centered portrait card.
function computeLayout(w, h) {
  const compact = w < 640 || h < 560;
  let frameW;
  let frameH;
  if (compact) {
    frameH = h;
    frameW = Math.min(w, Math.round(h / 1.3));
  } else {
    frameH = Math.min(h - 48, 900);
    frameW = Math.min(Math.round(frameH * 0.6), w - 48);
  }
  return { compact, frameW, frameH, fullBleed: compact && frameW === w };
}

export default function App() {
  const [phase, setPhase] = useState('menu'); // menu | playing | paused | gameover
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(loadBest);
  const [isNewBest, setIsNewBest] = useState(false);
  const [combo, setCombo] = useState(0);
  const [hasHooked, setHasHooked] = useState(false);
  const [settings, setSettings] = useState(loadSettings);
  const [showSettings, setShowSettings] = useState(false);
  const [layout, setLayout] = useState(() =>
    computeLayout(window.innerWidth, window.innerHeight)
  );

  const rootRef = useRef(null);
  const canvasRef = useRef(null);
  const gameRef = useRef(null);
  const rendererRef = useRef(null);
  const settingsRef = useRef(settings);
  const bestRef = useRef(best);
  const gameOverAtRef = useRef(0);

  const worldH = (WORLD_W * layout.frameH) / layout.frameW;
  if (!gameRef.current) gameRef.current = createGame(worldH);

  useEffect(() => {
    settingsRef.current = settings;
    setSoundEnabled(settings.sound);
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }, [settings]);

  // --- Layout -------------------------------------------------------------
  useLayoutEffect(() => {
    const root = rootRef.current;
    const observer = new ResizeObserver(([entry]) => {
      const { width, height } = entry.contentRect;
      setLayout((prev) => {
        const next = computeLayout(width, height);
        return next.frameW === prev.frameW && next.frameH === prev.frameH ? prev : next;
      });
    });
    observer.observe(root);
    return () => observer.disconnect();
  }, []);

  useLayoutEffect(() => {
    if (!rendererRef.current) rendererRef.current = createRenderer(canvasRef.current);
    const game = gameRef.current;
    setWorldHeight(game, worldH);
    rendererRef.current.resize(layout.frameW, layout.frameH, window.devicePixelRatio, worldH);
    rendererRef.current.draw(game, settingsRef.current, performance.now());
  }, [layout, worldH]);

  // --- Game flow ----------------------------------------------------------
  const setStatus = useCallback((status) => {
    const game = gameRef.current;
    game.status = status;
    setPhase(status === 'dead' ? 'gameover' : status);
  }, []);

  const startGame = useCallback(() => {
    unlockAudio();
    document.activeElement?.blur?.();
    resetGame(gameRef.current, 'playing');
    setScore(0);
    setCombo(0);
    setIsNewBest(false);
    setHasHooked(false);
    setShowSettings(false);
    setStatus('playing');
  }, [setStatus]);

  const pauseGame = useCallback(() => {
    const game = gameRef.current;
    if (game.status !== 'playing') return;
    // Let go of any swing so resuming is deterministic.
    release(game, true);
    setStatus('paused');
  }, [setStatus]);

  const resumeGame = useCallback(() => {
    if (gameRef.current.status !== 'paused') return;
    unlockAudio();
    document.activeElement?.blur?.();
    setShowSettings(false);
    setStatus('playing');
  }, [setStatus]);

  const goToMenu = useCallback(() => {
    resetGame(gameRef.current, 'menu');
    setShowSettings(false);
    setScore(0);
    setCombo(0);
    setStatus('menu');
  }, [setStatus]);

  const openSettings = useCallback(() => {
    pauseGame();
    setShowSettings(true);
  }, [pauseGame]);

  const canRestart = () => performance.now() - gameOverAtRef.current > RESTART_DELAY_MS;

  const handleEvents = useCallback(
    (game) => {
      for (const event of game.events) {
        if (event.type === 'hook') {
          sfx.hook(event.combo);
          setCombo(event.combo);
          setHasHooked(true);
        } else if (event.type === 'launch') {
          sfx.launch();
        } else if (event.type === 'death') {
          sfx.death();
          navigator.vibrate?.(60);
        } else if (event.type === 'gameover') {
          gameOverAtRef.current = performance.now();
          if (event.score > bestRef.current) {
            bestRef.current = event.score;
            setBest(event.score);
            setIsNewBest(true);
            localStorage.setItem(BEST_KEY, String(event.score));
            sfx.best();
          }
          setStatus('dead');
        }
      }
      game.events.length = 0;
    },
    [setStatus]
  );

  // --- Main loop ----------------------------------------------------------
  useEffect(() => {
    let raf = 0;
    let last = performance.now();
    let shownScore = -1;

    const frame = (now) => {
      raf = requestAnimationFrame(frame);
      const game = gameRef.current;
      const frames = Math.min((now - last) / (1000 / 60), 4);
      last = now;

      if (game.status !== 'paused' && game.status !== 'menu') {
        const substeps = Math.max(1, Math.ceil(frames / MAX_FRAME_STEP));
        for (let i = 0; i < substeps; i++) step(game, frames / substeps, settingsRef.current);
        if (game.events.length) handleEvents(game);
        if (game.score !== shownScore) {
          shownScore = game.score;
          setScore(game.score);
        }
      }
      if (game.status !== 'paused') rendererRef.current.draw(game, settingsRef.current, now);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [handleEvents]);

  // --- Pointer input (canvas) --------------------------------------------
  useEffect(() => {
    const canvas = canvasRef.current;
    const pointers = new Set();

    const onDown = (e) => {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      e.preventDefault();
      canvas.setPointerCapture?.(e.pointerId);
      pointers.add(e.pointerId);
      unlockAudio();
      press(gameRef.current);
    };
    const onUp = (e) => {
      if (!pointers.delete(e.pointerId)) return;
      unlockAudio();
      if (pointers.size === 0) release(gameRef.current);
    };
    const prevent = (e) => e.preventDefault();

    canvas.addEventListener('pointerdown', onDown, { passive: false });
    canvas.addEventListener('pointerup', onUp);
    canvas.addEventListener('pointercancel', onUp);
    canvas.addEventListener('lostpointercapture', onUp);
    canvas.addEventListener('contextmenu', prevent);
    // Blocks iOS double-tap zoom / magnifier on the play surface.
    canvas.addEventListener('touchstart', prevent, { passive: false });
    return () => {
      canvas.removeEventListener('pointerdown', onDown);
      canvas.removeEventListener('pointerup', onUp);
      canvas.removeEventListener('pointercancel', onUp);
      canvas.removeEventListener('lostpointercapture', onUp);
      canvas.removeEventListener('contextmenu', prevent);
      canvas.removeEventListener('touchstart', prevent);
    };
  }, []);

  // iOS needs a touchend/click to unlock audio; catch the first one anywhere.
  useEffect(() => {
    const unlock = () => unlockAudio();
    const opts = { capture: true, passive: true };
    window.addEventListener('touchend', unlock, opts);
    window.addEventListener('click', unlock, opts);
    return () => {
      window.removeEventListener('touchend', unlock, opts);
      window.removeEventListener('click', unlock, opts);
    };
  }, []);

  // --- Keyboard -----------------------------------------------------------
  useEffect(() => {
    const isHoldKey = (e) => e.code === 'Space' || e.code === 'ArrowUp';
    const onKeyDown = (e) => {
      const status = gameRef.current.status;
      if (showSettings) {
        // Let the settings controls keep normal keyboard behavior.
        if (e.code === 'Escape') setShowSettings(false);
        return;
      }
      if (isHoldKey(e) || e.code === 'Enter') {
        e.preventDefault();
        if (e.repeat) return;
        unlockAudio();
        if (status === 'playing' && isHoldKey(e)) press(gameRef.current);
        else if (status === 'menu') startGame();
        else if (status === 'dead' && canRestart()) startGame();
        else if (status === 'paused') resumeGame();
      } else if (e.code === 'Escape' || e.code === 'KeyP') {
        e.preventDefault();
        if (status === 'playing') pauseGame();
        else if (status === 'paused') resumeGame();
      } else if (e.code === 'KeyR' && (status === 'dead' || status === 'paused')) {
        startGame();
      }
    };
    const onKeyUp = (e) => {
      if (isHoldKey(e)) {
        e.preventDefault();
        release(gameRef.current);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
    };
  }, [showSettings, startGame, pauseGame, resumeGame]);

  // Pause when the tab/app goes to the background (home button, app switcher).
  useEffect(() => {
    const onHide = () => {
      if (document.hidden) pauseGame();
    };
    document.addEventListener('visibilitychange', onHide);
    window.addEventListener('blur', pauseGame);
    return () => {
      document.removeEventListener('visibilitychange', onHide);
      window.removeEventListener('blur', pauseGame);
    };
  }, [pauseGame]);

  const updateSetting = (key, value) => setSettings((prev) => ({ ...prev, [key]: value }));

  const holdLabel = isTouchDevice ? 'Touch & hold' : 'Hold Space or click';

  return (
    <div ref={rootRef} className="app-root">
      <div
        className={`game-frame ${layout.fullBleed ? '' : 'game-frame--card'}`}
        style={{ width: layout.frameW, height: layout.frameH }}
      >
        <canvas ref={canvasRef} className="game-canvas" aria-label="Game area" />

        {(phase === 'playing' || phase === 'paused') && (
          <Hud
            score={score}
            best={best}
            combo={combo}
            settings={settings}
            paused={phase === 'paused'}
            onPause={phase === 'paused' ? resumeGame : pauseGame}
            onSettings={openSettings}
          />
        )}

        {phase === 'playing' && !hasHooked && (
          <div className="pointer-events-none absolute inset-x-0 bottom-[12%] flex justify-center anim-fade">
            <div className="rounded-full bg-black/45 px-5 py-2.5 text-center text-sm font-medium text-white/90 ring-1 ring-white/10">
              {holdLabel} to hook · release to fling
            </div>
          </div>
        )}

        {phase === 'menu' && !showSettings && (
          <Overlay>
            <h1 className="title-gradient text-[2.6rem] leading-none font-black tracking-tight">
              ONE MORE <br />
              LINE
            </h1>
            <p className="mt-3 text-sm text-indigo-200/80">Swing your way to the top.</p>
            {best > 0 && (
              <p className="mt-5 text-sm font-semibold text-amber-300">Best · {best}m</p>
            )}
            <PrimaryButton className="mt-7" onClick={startGame}>
              Play
            </PrimaryButton>
            <SecondaryButton className="mt-3" onClick={() => setShowSettings(true)}>
              Settings
            </SecondaryButton>
            <ul className="mt-7 space-y-1.5 text-xs text-indigo-200/70">
              <li>
                <span className="font-semibold text-pink-300">{holdLabel}</span> to hook the nearest orb
              </li>
              <li>
                <span className="font-semibold text-violet-300">Release</span> to fling off it
              </li>
              {!isTouchDevice && (
                <li>
                  <span className="font-semibold text-indigo-300">P / Esc</span> pause ·{' '}
                  <span className="font-semibold text-indigo-300">R</span> restart
                </li>
              )}
            </ul>
          </Overlay>
        )}

        {phase === 'paused' && !showSettings && (
          <Overlay onBackdrop={resumeGame}>
            <h2 className="text-3xl font-black tracking-tight text-white">Paused</h2>
            <p className="mt-2 text-sm text-indigo-200/70">{score}m climbed</p>
            <PrimaryButton className="mt-7" onClick={resumeGame}>
              Resume
            </PrimaryButton>
            <div className="mt-3 grid w-full grid-cols-3 gap-2">
              <SecondaryButton onClick={startGame}>Restart</SecondaryButton>
              <SecondaryButton onClick={() => setShowSettings(true)}>Settings</SecondaryButton>
              <SecondaryButton onClick={goToMenu}>Menu</SecondaryButton>
            </div>
          </Overlay>
        )}

        {phase === 'gameover' && !showSettings && (
          <Overlay onBackdrop={() => canRestart() && startGame()}>
            <p className="text-sm font-bold tracking-[0.2em] text-pink-400">GAME OVER</p>
            <p className="mt-2 text-6xl font-black tabular-nums text-white">
              {score}
              <span className="ml-1 text-2xl text-white/60">m</span>
            </p>
            {isNewBest ? (
              <p className="anim-pop mt-3 rounded-full bg-amber-400/15 px-3 py-1 text-sm font-bold text-amber-300 ring-1 ring-amber-300/30">
                New best!
              </p>
            ) : (
              <p className="mt-3 text-sm text-indigo-200/70">Best · {best}m</p>
            )}
            <PrimaryButton className="mt-7" onClick={startGame}>
              Play again
            </PrimaryButton>
            <div className="mt-3 grid w-full grid-cols-2 gap-2">
              <SecondaryButton onClick={() => setShowSettings(true)}>Settings</SecondaryButton>
              <SecondaryButton onClick={goToMenu}>Menu</SecondaryButton>
            </div>
            <p className="mt-5 text-xs text-white/40">
              {isTouchDevice ? 'Tap anywhere to retry' : 'Press Space to retry'}
            </p>
          </Overlay>
        )}

        {showSettings && (
          <SettingsSheet
            settings={settings}
            onChange={updateSetting}
            onReset={() => setSettings(DEFAULT_SETTINGS)}
            onClose={() => setShowSettings(false)}
          />
        )}
      </div>
    </div>
  );
}

function Hud({ score, best, combo, settings, paused, onPause, onSettings }) {
  return (
    <div className="hud pointer-events-none absolute inset-x-0 top-0 flex items-start justify-between">
      <div>
        <div className="text-[10px] font-bold tracking-[0.2em] text-indigo-200/60">HEIGHT</div>
        <div className="text-4xl leading-none font-black tabular-nums text-white drop-shadow">
          {score}
          <span className="ml-0.5 text-lg text-white/60">m</span>
        </div>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {combo > 1 && (
            <span key={combo} className="anim-pop chip ring-1 bg-amber-400/20 text-amber-200 ring-amber-300/30">
              ×{combo} combo
            </span>
          )}
          {settings.speed !== 1 && (
            <span className="chip ring-1 bg-white/10 text-white/70 ring-white/10">{settings.speed}× speed</span>
          )}
          {!settings.gravity && (
            <span className="chip ring-1 bg-cyan-400/15 text-cyan-200 ring-cyan-300/20">No gravity</span>
          )}
        </div>
      </div>
      <div className="flex items-center gap-2">
        <div className="mr-1 text-right">
          <div className="text-[10px] font-bold tracking-[0.2em] text-indigo-200/60">BEST</div>
          <div className="text-sm font-bold tabular-nums text-amber-300">{best}m</div>
        </div>
        <IconButton label={paused ? 'Resume' : 'Pause'} onClick={onPause}>
          {paused ? (
            <path d="M8 5v14l11-7z" fill="currentColor" />
          ) : (
            <path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z" fill="currentColor" />
          )}
        </IconButton>
        <IconButton label="Settings" onClick={onSettings}>
          <path
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            d="M4 7h10M18 7h2M4 17h2M10 17h10M14 4.5v5M8 14.5v5"
          />
        </IconButton>
      </div>
    </div>
  );
}

function Overlay({ children, onBackdrop }) {
  return (
    <div
      className="overlay anim-fade"
      onClick={(e) => {
        if (onBackdrop && !e.target.closest('button')) onBackdrop();
      }}
    >
      <div className="flex w-full max-w-[18rem] flex-col items-center text-center">{children}</div>
    </div>
  );
}

function SettingsSheet({ settings, onChange, onReset, onClose }) {
  const speedPercent = ((settings.speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)) * 100;
  return (
    <div className="overlay anim-fade" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="sheet w-full max-w-[20rem]" role="dialog" aria-label="Settings">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-bold text-white">Settings</h2>
          <button className="text-xs font-semibold text-indigo-300 hover:text-white" onClick={onReset}>
            Reset all
          </button>
        </div>

        <Toggle
          label="Sound"
          checked={settings.sound}
          onChange={(v) => {
            onChange('sound', v);
            if (v) unlockAudio();
          }}
        />
        <Toggle
          label="Hook indicator"
          hint="Dotted ring around the orb you'll grab"
          checked={settings.hookIndicator}
          onChange={(v) => onChange('hookIndicator', v)}
        />
        <Toggle
          label="Gravity"
          hint="Off = straight-line flight (classic)"
          checked={settings.gravity}
          onChange={(v) => onChange('gravity', v)}
        />
        <Toggle
          label="Infinite trail"
          hint="Keep your whole path on screen"
          checked={settings.infiniteTrail}
          onChange={(v) => onChange('infiniteTrail', v)}
        />

        <div className="mt-4 border-t border-white/10 pt-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-sm font-semibold text-white">Game speed</span>
            <span className="text-sm font-bold tabular-nums text-pink-300">
              {settings.speed.toFixed(2)}×
            </span>
          </div>
          <div className="flex items-center gap-2">
            <StepButton label="Slower" onClick={() => onChange('speed', clampSpeed(settings.speed - 0.25))}>
              −
            </StepButton>
            <input
              type="range"
              min={SPEED_MIN}
              max={SPEED_MAX}
              step="0.05"
              value={settings.speed}
              onChange={(e) => onChange('speed', clampSpeed(parseFloat(e.target.value)))}
              className="speed-slider flex-1"
              style={{ '--fill': `${speedPercent}%` }}
              aria-label="Game speed"
            />
            <StepButton label="Faster" onClick={() => onChange('speed', clampSpeed(settings.speed + 0.25))}>
              +
            </StepButton>
          </div>
          <div className="mt-2 flex items-center justify-between text-[11px] text-white/40">
            <span>0.25×</span>
            <button
              className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-white/80 hover:bg-white/20 disabled:opacity-40"
              disabled={settings.speed === 1}
              onClick={() => onChange('speed', 1)}
            >
              Default (1×)
            </button>
            <span>2×</span>
          </div>
        </div>

        <PrimaryButton className="mt-5" onClick={onClose}>
          Done
        </PrimaryButton>
      </div>
    </div>
  );
}

function Toggle({ label, hint, checked, onChange }) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="flex w-full items-center justify-between gap-4 rounded-xl px-1 py-2.5 text-left"
    >
      <span>
        <span className="block text-sm font-semibold text-white">{label}</span>
        {hint && <span className="block text-xs text-white/45">{hint}</span>}
      </span>
      <span className={`switch ${checked ? 'switch--on' : ''}`} aria-hidden="true">
        <span className="switch-knob" />
      </span>
    </button>
  );
}

function PrimaryButton({ className = '', ...props }) {
  return <button className={`btn-primary ${className}`} {...props} />;
}

function SecondaryButton({ className = '', ...props }) {
  return <button className={`btn-secondary ${className}`} {...props} />;
}

function StepButton({ label, ...props }) {
  return (
    <button
      aria-label={label}
      className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white/10 text-lg font-bold text-white hover:bg-white/20 active:scale-95"
      {...props}
    />
  );
}

function IconButton({ label, onClick, children }) {
  return (
    <button aria-label={label} onClick={onClick} className="icon-btn pointer-events-auto">
      <svg viewBox="0 0 24 24" className="h-5 w-5">
        {children}
      </svg>
    </button>
  );
}
