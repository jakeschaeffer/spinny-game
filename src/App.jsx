import * as React from 'react';
const { useState, useEffect, useRef, useCallback, useMemo } = React;

// Web Audio API sound generator
const createAudioContext = () => {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  return new AudioContext();
};

let audioCtx = null;

const getAudioContext = () => {
  if (!audioCtx) {
    audioCtx = createAudioContext();
  }
  return audioCtx;
};

const playTone = (frequency, duration, type = 'sine', volume = 0.3) => {
  try {
    const ctx = getAudioContext();
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const oscillator = ctx.createOscillator();
    const gainNode = ctx.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, ctx.currentTime);

    gainNode.gain.setValueAtTime(volume, ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);

    oscillator.start(ctx.currentTime);
    oscillator.stop(ctx.currentTime + duration);
  } catch (e) {
    // Audio not supported
  }
};

const sounds = {
  hook: () => {
    playTone(880, 0.1, 'sine', 0.2);
    playTone(1100, 0.15, 'sine', 0.15);
  },
  launch: () => {
    playTone(440, 0.1, 'triangle', 0.2);
    playTone(660, 0.15, 'triangle', 0.15);
  },
  gameOver: () => {
    playTone(300, 0.2, 'sawtooth', 0.2);
    setTimeout(() => playTone(200, 0.3, 'sawtooth', 0.15), 150);
  },
  combo: (level) => {
    const baseFreq = 600 + (level * 100);
    playTone(baseFreq, 0.1, 'sine', 0.15);
  }
};

const OneMoreLine = () => {
  // UI State (things that need to trigger re-renders)
  const [gameState, setGameState] = useState('menu');
  const [score, setScore] = useState(0);
  const [highScore, setHighScore] = useState(() => {
    const saved = localStorage.getItem('oneMoreLineHighScore');
    return saved ? parseInt(saved, 10) : 0;
  });
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [showTutorial, setShowTutorial] = useState(true);
  const [combo, setCombo] = useState(0);
  const [screenSize, setScreenSize] = useState({ width: 400, height: 600 });
  const [gameScale, setGameScale] = useState(1);
  const [, forceRender] = useState(0);

  // Game state refs (mutable, don't trigger re-renders)
  const gameRef = useRef({
    playerPos: { x: 200, y: 500 },
    playerVelocity: { x: 0, y: -4 },
    cameraY: 0,
    hookedNode: null,
    hookAngle: 0,
    hookDistance: 0,
    isHolding: false,
    gameNodes: [],
    startGracePeriod: true,
    spinDirection: 1,
    infiniteTrail: false,
    nearestHookableNode: null,
    lastHookTime: 0,
    combo: 0,
  });

  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const trailPoints = useRef([]);
  const gameLoopRef = useRef(null);
  const lastFrameTime = useRef(0);
  const renderFrameRef = useRef(null);

  const baseGameBounds = useMemo(() => ({ width: 400, height: 600 }), []);
  const gameBounds = baseGameBounds;

  const colorSchemes = useMemo(() => [
    { main: '#4ade80', light: '#86efac', dark: '#16a34a' },
    { main: '#38bdf8', light: '#7dd3fc', dark: '#0284c7' },
    { main: '#818cf8', light: '#a5b4fc', dark: '#4f46e5' },
    { main: '#fb7185', light: '#fda4af', dark: '#e11d48' },
    { main: '#facc15', light: '#fde047', dark: '#ca8a04' },
    { main: '#f97316', light: '#fdba74', dark: '#c2410c' },
    { main: '#c084fc', light: '#d8b4fe', dark: '#9333ea' },
    { main: '#34d399', light: '#6ee7b7', dark: '#059669' },
  ], []);

  // Responsive sizing
  useEffect(() => {
    const updateSize = () => {
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const maxWidth = Math.min(vw - 32, 500);
      const maxHeight = vh - 160;
      const scaleX = maxWidth / baseGameBounds.width;
      const scaleY = maxHeight / baseGameBounds.height;
      const scale = Math.min(scaleX, scaleY, 1.2);
      setGameScale(scale);
      setScreenSize({
        width: baseGameBounds.width * scale,
        height: baseGameBounds.height * scale,
      });
    };

    updateSize();
    window.addEventListener('resize', updateSize);
    window.addEventListener('orientationchange', updateSize);
    return () => {
      window.removeEventListener('resize', updateSize);
      window.removeEventListener('orientationchange', updateSize);
    };
  }, [baseGameBounds]);

  // Prevent default touch behaviors
  useEffect(() => {
    const preventDefaults = (e) => {
      if (gameState === 'playing' || gameState === 'paused') {
        e.preventDefault();
      }
    };
    document.addEventListener('touchmove', preventDefaults, { passive: false });
    document.addEventListener('gesturestart', preventDefaults);
    document.addEventListener('gesturechange', preventDefaults);
    return () => {
      document.removeEventListener('touchmove', preventDefaults);
      document.removeEventListener('gesturestart', preventDefaults);
      document.removeEventListener('gesturechange', preventDefaults);
    };
  }, [gameState]);

  const playSound = useCallback((soundName, ...args) => {
    if (soundEnabled && sounds[soundName]) {
      sounds[soundName](...args);
    }
  }, [soundEnabled]);

  const generateInitialNodes = useCallback(() => {
    const initialNodes = [];
    for (let i = 0; i < 12; i++) {
      const sizeFactor = 0.7 + Math.random() * 1.1;
      const baseRadius = 18;
      const colorScheme = colorSchemes[Math.floor(Math.random() * colorSchemes.length)];
      initialNodes.push({
        id: i + 1,
        x: 60 + Math.random() * (gameBounds.width - 120),
        y: 500 - i * 90,
        radius: Math.round(baseRadius * sizeFactor),
        colorScheme,
        brightnessOffset: Math.random() * 10,
        patternType: Math.floor(Math.random() * 3),
      });
    }
    return initialNodes;
  }, [colorSchemes, gameBounds.width]);

  const generateNewNodes = useCallback((currentNodes, viewportTop) => {
    const generationTop = viewportTop - 400;
    const highestNodeY = Math.min(...currentNodes.map((node) => node.y));

    if (highestNodeY > generationTop + 120) {
      const newNodes = [];
      const numNewNodes = Math.floor(Math.random() * 2) + 2;

      for (let i = 0; i < numNewNodes; i++) {
        const sizeFactor = 0.7 + Math.random() * 1.1;
        const baseRadius = 18;
        const colorScheme = colorSchemes[Math.floor(Math.random() * colorSchemes.length)];
        const nodeY = generationTop - i * 90 - Math.random() * 40;
        newNodes.push({
          id: Date.now() + i + Math.random(),
          x: 50 + Math.random() * (gameBounds.width - 100),
          y: nodeY,
          radius: Math.round(baseRadius * sizeFactor),
          colorScheme,
          brightnessOffset: Math.random() * 10,
          patternType: Math.floor(Math.random() * 3),
        });
      }

      const cutoffY = viewportTop + gameBounds.height + 300;
      const filteredOldNodes = currentNodes.filter((node) => node.y < cutoffY);
      return [...filteredOldNodes, ...newNodes];
    }
    return currentNodes;
  }, [colorSchemes, gameBounds.width, gameBounds.height]);

  const drawTrail = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const game = gameRef.current;
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (trailPoints.current.length >= 2) {
      const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
      gradient.addColorStop(0, '#ec4899');
      gradient.addColorStop(0.5, '#a855f7');
      gradient.addColorStop(1, '#6366f1');

      const visibleYMin = game.cameraY - 100;
      const visibleYMax = game.cameraY + canvas.height + 100;
      const visiblePoints = game.infiniteTrail
        ? trailPoints.current.filter((pt) => pt.y >= visibleYMin && pt.y <= visibleYMax)
        : trailPoints.current;

      if (visiblePoints.length < 2) return;

      ctx.beginPath();
      ctx.moveTo(visiblePoints[0].x, visiblePoints[0].y - game.cameraY);

      for (let i = 1; i < visiblePoints.length; i++) {
        ctx.lineTo(visiblePoints[i].x, visiblePoints[i].y - game.cameraY);
      }

      ctx.strokeStyle = gradient;
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.stroke();

      ctx.shadowColor = '#ec4899';
      ctx.shadowBlur = 12;
      ctx.strokeStyle = 'rgba(236, 72, 153, 0.6)';
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.shadowBlur = 0;
    }
  }, []);

  const startGame = useCallback(() => {
    const game = gameRef.current;
    game.playerPos = { x: 200, y: 500 };
    game.playerVelocity = { x: 0, y: -4 };
    game.cameraY = 0;
    game.hookedNode = null;
    game.hookAngle = 0;
    game.hookDistance = 0;
    game.isHolding = false;
    game.startGracePeriod = true;
    game.combo = 0;
    game.lastHookTime = 0;
    trailPoints.current = [];

    const initialNodes = generateInitialNodes();
    game.gameNodes = initialNodes.filter((node) => {
      const dx = node.x - 200;
      const dy = node.y - 500;
      return Math.sqrt(dx * dx + dy * dy) > 60;
    });

    setGameState('playing');
    setScore(0);
    setCombo(0);
    setShowTutorial(true);

    setTimeout(() => {
      game.startGracePeriod = false;
      setShowTutorial(false);
    }, 2000);

    // Initialize audio context on user interaction
    getAudioContext();
  }, [generateInitialNodes]);

  const pauseGame = useCallback(() => {
    if (gameState === 'playing') {
      setGameState('paused');
    } else if (gameState === 'paused') {
      setGameState('playing');
    }
  }, [gameState]);

  const endGame = useCallback((currentScore) => {
    setGameState('gameover');
    playSound('gameOver');

    if (currentScore > highScore) {
      setHighScore(currentScore);
      localStorage.setItem('oneMoreLineHighScore', currentScore.toString());
    }
  }, [highScore, playSound]);

  const findClosestHookableNode = useCallback((pos, nodes) => {
    let closestNode = null;
    let closestDistance = Infinity;

    for (const node of nodes) {
      const dx = node.x - pos.x;
      const dy = node.y - pos.y;
      const distance = Math.sqrt(dx * dx + dy * dy);
      const nodeHookRadius = 180 * (node.radius / 16);

      if (distance < nodeHookRadius && distance < closestDistance) {
        closestNode = { node, distance };
        closestDistance = distance;
      }
    }
    return closestNode;
  }, []);

  const handleHoldStart = useCallback((e) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    if (gameState === 'gameover' || gameState === 'menu') {
      startGame();
      return;
    }

    if (gameState === 'paused') {
      pauseGame();
      return;
    }

    const game = gameRef.current;
    game.isHolding = true;

    if (!game.hookedNode && gameState === 'playing') {
      const closestNode = findClosestHookableNode(game.playerPos, game.gameNodes);

      if (closestNode) {
        game.hookedNode = closestNode.node;
        playSound('hook');

        const dx = game.playerPos.x - closestNode.node.x;
        const dy = game.playerPos.y - closestNode.node.y;
        game.hookAngle = Math.atan2(dy, dx);
        game.hookDistance = closestNode.distance;

        const crossProduct = dx * game.playerVelocity.y - dy * game.playerVelocity.x;
        game.spinDirection = Math.sign(crossProduct) || 1;

        // Combo system
        const now = Date.now();
        if (now - game.lastHookTime < 2000) {
          game.combo++;
          playSound('combo', game.combo);
        } else {
          game.combo = 1;
        }
        game.lastHookTime = now;
        setCombo(game.combo);
      }
    }
  }, [gameState, findClosestHookableNode, playSound, startGame, pauseGame]);

  const handleHoldEnd = useCallback((e) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    const game = gameRef.current;
    game.isHolding = false;

    if (game.hookedNode && gameState === 'playing') {
      playSound('launch');

      const tangentOffset = game.spinDirection * Math.PI / 2;
      const angle = game.hookAngle + tangentOffset;
      const baseSpeed = 5.5;
      const comboBonus = Math.min(game.combo * 0.1, 1.0);
      const speed = baseSpeed + comboBonus;

      game.playerVelocity = {
        x: Math.cos(angle) * speed,
        y: Math.sin(angle) * speed,
      };

      game.hookedNode = null;
    }
  }, [gameState, playSound]);

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.code === 'Space') {
        handleHoldStart();
        e.preventDefault();
      } else if (e.code === 'Escape' || e.code === 'KeyP') {
        if (gameState === 'playing' || gameState === 'paused') {
          pauseGame();
        }
        e.preventDefault();
      } else if (e.code === 'KeyR' && gameState === 'gameover') {
        startGame();
        e.preventDefault();
      }
    };

    const handleKeyUp = (e) => {
      if (e.code === 'Space') {
        handleHoldEnd();
        e.preventDefault();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [handleHoldStart, handleHoldEnd, pauseGame, startGame, gameState]);

  // Main game loop - runs physics at fixed timestep
  useEffect(() => {
    if (gameState !== 'playing') {
      if (gameLoopRef.current) {
        cancelAnimationFrame(gameLoopRef.current);
        gameLoopRef.current = null;
      }
      return;
    }

    const game = gameRef.current;
    lastFrameTime.current = performance.now();

    const gameLoop = (currentTime) => {
      const deltaMs = currentTime - lastFrameTime.current;
      lastFrameTime.current = currentTime;

      // Cap delta to prevent huge jumps (e.g., after tab switch)
      const delta = Math.min(deltaMs / 16.67, 3);

      let newX, newY;

      if (game.hookedNode && game.isHolding) {
        // Swinging around node
        const distanceFactor = Math.max(0.5, Math.min(1.5, game.hookDistance / 100));
        const spinSpeed = 0.055 / distanceFactor;
        const finalSpinSpeed = spinSpeed * game.spinDirection * delta;

        game.hookAngle += finalSpinSpeed;
        newX = game.hookedNode.x + Math.cos(game.hookAngle) * game.hookDistance;
        newY = game.hookedNode.y + Math.sin(game.hookAngle) * game.hookDistance;
      } else {
        // Free flight with gravity
        game.playerVelocity.y += 0.015 * delta;
        newX = game.playerPos.x + game.playerVelocity.x * delta;
        newY = game.playerPos.y + game.playerVelocity.y * delta;
      }

      // Collision detection
      let collision = false;
      if (!game.startGracePeriod) {
        for (const node of game.gameNodes) {
          if (game.hookedNode && node.id === game.hookedNode.id) continue;

          const dx = newX - node.x;
          const dy = newY - node.y;
          const distance = Math.sqrt(dx * dx + dy * dy);

          if (distance < node.radius + 6) {
            collision = true;
            break;
          }
        }

        // Wall collision
        if (!game.hookedNode && (newX < 12 || newX > gameBounds.width - 12)) {
          collision = true;
        }

        // Bottom boundary
        if (newY > game.cameraY + gameBounds.height + 80) {
          collision = true;
        }
      }

      if (collision) {
        const currentScore = Math.max(0, Math.floor(-game.cameraY / 8));
        endGame(currentScore);
        return;
      }

      // Update position
      game.playerPos.x = newX;
      game.playerPos.y = newY;

      // Add trail point
      trailPoints.current.push({ x: newX, y: newY });
      if (!game.infiniteTrail && trailPoints.current.length > 50) {
        trailPoints.current = trailPoints.current.slice(-50);
      }

      // Camera follow (smooth)
      const targetY = game.playerPos.y - gameBounds.height / 2.5;
      game.cameraY += (targetY - game.cameraY) * 0.1 * delta;

      // Generate new nodes
      game.gameNodes = generateNewNodes(game.gameNodes, game.cameraY);

      // Find nearest hookable node
      game.nearestHookableNode = findClosestHookableNode(game.playerPos, game.gameNodes)?.node || null;

      // Update score
      const newScore = Math.max(0, Math.floor(-game.cameraY / 8));
      setScore(newScore);

      // Draw trail on canvas
      drawTrail();

      // Trigger render for visual updates
      forceRender(n => n + 1);

      gameLoopRef.current = requestAnimationFrame(gameLoop);
    };

    gameLoopRef.current = requestAnimationFrame(gameLoop);

    return () => {
      if (gameLoopRef.current) {
        cancelAnimationFrame(gameLoopRef.current);
        gameLoopRef.current = null;
      }
    };
  }, [gameState, gameBounds, generateNewNodes, findClosestHookableNode, endGame, drawTrail]);

  // Canvas setup
  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas) {
      canvas.width = gameBounds.width;
      canvas.height = gameBounds.height;
    }
  }, [gameBounds]);

  const toggleTrailMode = useCallback(() => {
    gameRef.current.infiniteTrail = !gameRef.current.infiniteTrail;
    forceRender(n => n + 1);
  }, []);

  const toggleSound = useCallback(() => {
    setSoundEnabled(prev => !prev);
  }, []);

  // Get current game state for rendering
  const game = gameRef.current;
  const playerSpeed = Math.sqrt(game.playerVelocity.x ** 2 + game.playerVelocity.y ** 2).toFixed(1);

  return (
    <div
      className="flex flex-col items-center justify-center min-h-screen bg-gradient-to-b from-gray-900 via-indigo-950 to-gray-900 p-2 sm:p-4 select-none overflow-hidden"
      style={{ touchAction: 'none' }}
    >
      {/* Header */}
      <div className="w-full max-w-lg flex items-center justify-between px-2 mb-2">
        <div className="text-xl sm:text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">
          ONE MORE LINE
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={toggleSound}
            className="p-2 rounded-full bg-gray-800/50 hover:bg-gray-700/50 transition-colors"
            aria-label={soundEnabled ? 'Mute' : 'Unmute'}
          >
            {soundEnabled ? (
              <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
              </svg>
            ) : (
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
              </svg>
            )}
          </button>

          {(gameState === 'playing' || gameState === 'paused') && (
            <button
              onClick={pauseGame}
              className="p-2 rounded-full bg-gray-800/50 hover:bg-gray-700/50 transition-colors"
              aria-label={gameState === 'paused' ? 'Resume' : 'Pause'}
            >
              {gameState === 'paused' ? (
                <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
              ) : (
                <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                </svg>
              )}
            </button>
          )}
        </div>
      </div>

      {/* Score bar */}
      <div className="w-full max-w-lg flex items-center justify-between px-2 mb-2">
        <div className="flex items-center gap-4">
          <div className="text-lg font-semibold text-white">
            <span className="text-pink-400">SCORE:</span> {score}
          </div>
          {combo > 1 && (
            <div className="text-sm font-bold text-yellow-400 animate-pulse">
              x{combo} COMBO!
            </div>
          )}
        </div>
        <div className="text-sm text-indigo-300">
          BEST: {highScore}
        </div>
      </div>

      {/* Game container */}
      <div
        ref={containerRef}
        className="relative bg-gray-900 border-2 border-indigo-500/50 rounded-xl overflow-hidden shadow-2xl shadow-indigo-500/20"
        style={{
          width: screenSize.width,
          height: screenSize.height,
          touchAction: 'none',
        }}
        onMouseDown={handleHoldStart}
        onMouseUp={handleHoldEnd}
        onMouseLeave={handleHoldEnd}
        onTouchStart={handleHoldStart}
        onTouchEnd={handleHoldEnd}
        onTouchCancel={handleHoldEnd}
      >
        <div
          style={{
            transform: `scale(${gameScale})`,
            transformOrigin: 'top left',
            width: gameBounds.width,
            height: gameBounds.height,
          }}
        >
          {/* Side borders */}
          <div className="absolute top-0 left-0 w-2 h-full bg-gradient-to-b from-pink-500 to-indigo-500 opacity-80" style={{ zIndex: 9 }} />
          <div className="absolute top-0 right-0 w-2 h-full bg-gradient-to-b from-pink-500 to-indigo-500 opacity-80" style={{ zIndex: 9 }} />

          {/* Trail canvas */}
          <canvas ref={canvasRef} className="absolute top-0 left-0" style={{ zIndex: 8, pointerEvents: 'none', width: gameBounds.width, height: gameBounds.height }} />

          {/* Game world */}
          <div className="absolute left-0 w-full" style={{ transform: `translateY(${-game.cameraY}px)` }}>
            {/* Height markers */}
            {[...Array(100)].map((_, i) => (
              i > 5 && (
                <div key={i} className="absolute left-0 w-full h-px bg-white/10" style={{ top: -i * 100 + 500 }}>
                  <span className="absolute text-xs text-white/30 left-4">{i * 10}m</span>
                </div>
              )
            ))}

            {/* Nodes */}
            {game.gameNodes.map((node) => {
              const isNearestHookable = game.nearestHookableNode?.id === node.id;
              const hookRadius = 180 * (node.radius / 16);

              return (
                <React.Fragment key={node.id}>
                  {isNearestHookable && !game.hookedNode && (
                    <div
                      className="absolute rounded-full"
                      style={{
                        left: node.x - hookRadius,
                        top: node.y - hookRadius,
                        width: hookRadius * 2,
                        height: hookRadius * 2,
                        border: `2px dashed ${node.colorScheme.light}`,
                        opacity: 0.4,
                        zIndex: 3,
                        animation: 'pulse 1s infinite',
                      }}
                    />
                  )}

                  <div
                    className="absolute rounded-full"
                    style={{
                      left: node.x - node.radius,
                      top: node.y - node.radius,
                      width: node.radius * 2,
                      height: node.radius * 2,
                      boxShadow: `0 0 ${isNearestHookable ? 20 : 12}px ${node.colorScheme.main}`,
                      zIndex: 5,
                      background:
                        node.patternType === 0
                          ? `radial-gradient(circle at 35% 35%, ${node.colorScheme.light} 0%, ${node.colorScheme.main} 60%, ${node.colorScheme.dark} 100%)`
                          : node.patternType === 1
                          ? `linear-gradient(135deg, ${node.colorScheme.light} 0%, ${node.colorScheme.main} 50%, ${node.colorScheme.dark} 100%)`
                          : `repeating-linear-gradient(45deg, ${node.colorScheme.main}, ${node.colorScheme.main} 4px, ${node.colorScheme.light} 4px, ${node.colorScheme.light} 8px)`,
                      filter: `brightness(${1 + node.brightnessOffset / 100})`,
                      transform: isNearestHookable ? 'scale(1.1)' : 'scale(1)',
                      transition: 'transform 0.15s ease-out',
                    }}
                  />
                </React.Fragment>
              );
            })}

            {/* Hook line */}
            {game.hookedNode && game.isHolding && (
              <div
                className="absolute bg-gradient-to-r from-white to-pink-300"
                style={{
                  left: game.hookedNode.x,
                  top: game.hookedNode.y,
                  width: `${game.hookDistance}px`,
                  height: '2px',
                  transform: `rotate(${game.hookAngle * (180 / Math.PI)}deg)`,
                  transformOrigin: '0 0',
                  boxShadow: '0 0 8px rgba(255,255,255,0.5)',
                  zIndex: 9,
                }}
              />
            )}

            {/* Player */}
            <div
              className="absolute rounded-full"
              style={{
                left: game.playerPos.x - 10,
                top: game.playerPos.y - 10,
                width: 20,
                height: 20,
                background: 'radial-gradient(circle at 35% 35%, #fbbf24 0%, #f97316 50%, #ea580c 100%)',
                boxShadow: `0 0 ${game.isHolding ? 24 : 16}px ${game.isHolding ? '#fbbf24' : '#f97316'}, 0 0 ${game.isHolding ? 40 : 28}px rgba(249, 115, 22, 0.5)`,
                zIndex: 10,
              }}
            />
          </div>

          {/* Tutorial overlay */}
          {showTutorial && gameState === 'playing' && (
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none" style={{ zIndex: 20 }}>
              <div className="bg-black/60 px-6 py-4 rounded-xl text-center">
                <p className="text-white text-lg font-medium">HOLD to hook</p>
                <p className="text-indigo-300 text-sm mt-1">RELEASE to launch</p>
              </div>
            </div>
          )}

          {/* Pause overlay */}
          {gameState === 'paused' && (
            <div className="absolute inset-0 bg-black/70 backdrop-blur-sm flex flex-col items-center justify-center" style={{ zIndex: 50 }}>
              <div className="text-white text-4xl font-bold mb-4">PAUSED</div>
              <p className="text-indigo-300 mb-6">Tap or press SPACE to continue</p>
              <div className="flex gap-4">
                <button
                  className="px-6 py-3 bg-gradient-to-r from-pink-500 to-purple-600 text-white font-bold rounded-full shadow-lg hover:from-pink-600 hover:to-purple-700 transform transition hover:scale-105 active:scale-95"
                  onClick={pauseGame}
                >
                  RESUME
                </button>
                <button
                  className="px-6 py-3 bg-gray-700 text-white font-bold rounded-full shadow-lg hover:bg-gray-600 transform transition hover:scale-105 active:scale-95"
                  onClick={() => setGameState('menu')}
                >
                  MENU
                </button>
              </div>
            </div>
          )}

          {/* Game over overlay */}
          {gameState === 'gameover' && (
            <div className="absolute inset-0 bg-black/80 backdrop-blur-sm flex flex-col items-center justify-center" style={{ zIndex: 50 }}>
              <div className="text-pink-400 text-4xl font-bold mb-2">GAME OVER</div>
              <div className="text-white text-2xl mb-2">
                <span className="text-indigo-400">SCORE:</span> {score}
              </div>
              {score >= highScore && score > 0 && (
                <div className="text-yellow-400 text-lg font-bold mb-4 animate-bounce">
                  NEW HIGH SCORE!
                </div>
              )}
              <div className="text-gray-400 text-sm mb-6">
                Best: {highScore}
              </div>
              <button
                className="px-8 py-4 bg-gradient-to-r from-pink-500 to-purple-600 text-white font-bold text-lg rounded-full shadow-lg hover:from-pink-600 hover:to-purple-700 transform transition hover:scale-105 active:scale-95"
                onClick={startGame}
              >
                PLAY AGAIN
              </button>
              <p className="text-gray-500 text-sm mt-4">
                Press R or tap to restart
              </p>
            </div>
          )}

          {/* Menu overlay */}
          {gameState === 'menu' && (
            <div className="absolute inset-0 bg-gradient-to-b from-gray-900/95 to-indigo-900/95 backdrop-blur-sm flex flex-col items-center justify-center" style={{ zIndex: 50 }}>
              <div className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500 mb-2">
                ONE MORE LINE
              </div>
              <p className="text-indigo-300 text-sm mb-8">Swing your way to the top!</p>

              <button
                className="px-10 py-5 bg-gradient-to-r from-pink-500 to-purple-600 text-white font-bold text-xl rounded-full shadow-lg hover:from-pink-600 hover:to-purple-700 transform transition hover:scale-105 active:scale-95 mb-6"
                onClick={startGame}
              >
                PLAY
              </button>

              <div className="text-center text-gray-400 text-sm max-w-xs">
                <p className="mb-2"><span className="text-pink-400">HOLD</span> Space/Click/Tap to hook</p>
                <p className="mb-2"><span className="text-purple-400">RELEASE</span> to launch</p>
                <p><span className="text-indigo-400">ESC/P</span> to pause</p>
              </div>

              {highScore > 0 && (
                <div className="mt-6 text-yellow-400">
                  High Score: {highScore}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Bottom info bar */}
      {gameState === 'playing' && (
        <div className="w-full max-w-lg flex items-center justify-between px-4 mt-2 text-xs text-gray-500">
          <span>Speed: {playerSpeed}</span>
          <button
            onClick={toggleTrailMode}
            className={`px-3 py-1 rounded-full transition-colors ${
              game.infiniteTrail
                ? 'bg-pink-600/50 text-pink-200'
                : 'bg-gray-800/50 text-gray-400'
            }`}
          >
            {game.infiniteTrail ? 'Trail: ON' : 'Trail: OFF'}
          </button>
        </div>
      )}

      <div className="mt-3 text-center text-gray-500 text-xs max-w-xs">
        {gameState === 'playing' && (
          <p>Tap and hold anywhere to hook onto nearby circles</p>
        )}
      </div>
    </div>
  );
};

export default OneMoreLine;
