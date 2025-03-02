import * as React from 'react';
const { useState, useEffect, useRef } = React;

const OneMoreLine = () => {
  // Game state
  const [gameState, setGameState] = useState('playing');
  const [score, setScore] = useState(0);
  const [isHolding, setIsHolding] = useState(false);
  const [cameraY, setCameraY] = useState(0);

  // Refs
  const gameSettings = useRef({ infiniteTrail: false, spinDirection: 1 });
  const canvasRef = useRef(null);
  const trailPoints = useRef([]);

  // Audio refs
  const hookSoundRef = useRef(new Audio('/sounds/hook.mp3'));
  const swingSoundRef = useRef(new Audio('/sounds/swing.mp3'));
  const launchSoundRef = useRef(new Audio('/sounds/launch.mp3'));
  const gameOverSoundRef = useRef(new Audio('/sounds/gameover.mp3'));
  const backgroundMusicRef = useRef(new Audio('/sounds/background.mp3'));
  swingSoundRef.current.loop = true;
  backgroundMusicRef.current.loop = true;

  // Player state
  const [playerPos, setPlayerPos] = useState({ x: 200, y: 450 });
  const [playerVelocity, setPlayerVelocity] = useState({ x: 0, y: -3.6 });

  // Hook state
  const [hookedNode, setHookedNode] = useState(null);
  const [hookAngle, setHookAngle] = useState(0);
  const [hookDistance, setHookDistance] = useState(0);

  // Nodes state
  const [gameNodes, setGameNodes] = useState([]);
  const [startGracePeriod, setStartGracePeriod] = useState(true);

  const gameBounds = { width: 400, height: 500 };

  const toggleTrailMode = () => {
    gameSettings.current.infiniteTrail = !gameSettings.current.infiniteTrail;
    setGameState((prev) => (prev === 'playing' ? 'playing-update' : 'playing'));
  };

  const generateInitialNodes = () => {
    const initialNodes = [];
    for (let i = 0; i < 9; i++) {
      const sizeFactor = 0.69 + Math.random() * 1.19;
      const baseRadius = 16;
      const colorSchemes = [
        { main: '#4ade80', light: '#86efac', dark: '#16a34a' },
        { main: '#38bdf8', light: '#7dd3fc', dark: '#0284c7' },
        { main: '#818cf8', light: '#a5b4fc', dark: '#4f46e5' },
        { main: '#fb7185', light: '#fda4af', dark: '#e11d48' },
        { main: '#facc15', light: '#fde047', dark: '#ca8a04' },
        { main: '#f97316', light: '#fdba74', dark: '#c2410c' },
        { main: '#c084fc', light: '#d8b4fe', dark: '#9333ea' },
        { main: '#34d399', light: '#6ee7b7', dark: '#059669' },
      ];
      const colorScheme = colorSchemes[Math.floor(Math.random() * colorSchemes.length)];
      const brightnessOffset = Math.random() * 10;

      initialNodes.push({
        id: i + 1,
        x: 80 + Math.random() * (gameBounds.width - 160),
        y: 450 - i * 100,
        radius: Math.round(baseRadius * sizeFactor),
        colorScheme,
        brightnessOffset,
        patternType: Math.floor(Math.random() * 3),
      });
    }
    return initialNodes;
  };

  const generateNewNodes = (currentNodes, viewportTop) => {
    const visibleTop = viewportTop;
    const generationTop = visibleTop - 300;
    const highestNodeY = Math.min(...currentNodes.map((node) => node.y));

    if (highestNodeY > generationTop + 100) {
      const newNodes = [];
      const numNewNodes = Math.floor(Math.random() * 2) + 2;

      for (let i = 0; i < numNewNodes; i++) {
        const sizeFactor = 0.69 + Math.random() * 1.19;
        const baseRadius = 16;
        const colorSchemes = [
          { main: '#4ade80', light: '#86efac', dark: '#16a34a' },
          { main: '#38bdf8', light: '#7dd3fc', dark: '#0284c7' },
          { main: '#818cf8', light: '#a5b4fc', dark: '#4f46e5' },
          { main: '#fb7185', light: '#fda4af', dark: '#e11d48' },
          { main: '#facc15', light: '#fde047', dark: '#ca8a04' },
          { main: '#f97316', light: '#fdba74', dark: '#c2410c' },
          { main: '#c084fc', light: '#d8b4fe', dark: '#9333ea' },
          { main: '#34d399', light: '#6ee7b7', dark: '#059669' },
        ];
        const colorScheme = colorSchemes[Math.floor(Math.random() * colorSchemes.length)];
        const brightnessOffset = Math.random() * 10;

        const nodeY = generationTop - i * 100 - Math.random() * 50;
        newNodes.push({
          id: Date.now() + i,
          x: 40 + Math.random() * (gameBounds.width - 80),
          y: nodeY,
          radius: Math.round(baseRadius * sizeFactor),
          colorScheme,
          brightnessOffset,
          patternType: Math.floor(Math.random() * 3),
        });
      }

      const cutoffY = viewportTop + gameBounds.height + 200;
      const filteredOldNodes = currentNodes.filter((node) => node.y < cutoffY);
      return [...filteredOldNodes, ...newNodes];
    }
    return currentNodes;
  };

  const drawTrail = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (trailPoints.current.length >= 2) {
      const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
      gradient.addColorStop(0, '#ec4899');
      gradient.addColorStop(1, '#8b5cf6');

      const visibleYMin = cameraY - 100;
      const visibleYMax = cameraY + canvas.height + 100;
      const visiblePoints = gameSettings.current.infiniteTrail
        ? trailPoints.current.filter((pt) => pt.y >= visibleYMin && pt.y <= visibleYMax)
        : trailPoints.current;

      if (visiblePoints.length < 2) return;

      ctx.beginPath();
      const startPoint = visiblePoints[0];
      ctx.moveTo(startPoint.x, startPoint.y - cameraY);

      for (let i = 1; i < visiblePoints.length; i++) {
        const point = visiblePoints[i];
        ctx.lineTo(point.x, point.y - cameraY);
      }

      ctx.strokeStyle = gradient;
      ctx.lineWidth = 5;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.stroke();

      ctx.shadowColor = '#ec4899';
      ctx.shadowBlur = 10;
      ctx.strokeStyle = 'rgba(236, 72, 153, 0.7)';
      ctx.lineWidth = 3;
      ctx.stroke();
    }
  };

  const addTrailPoint = (x, y) => {
    trailPoints.current.push({ x, y });
    if (!gameSettings.current.infiniteTrail && trailPoints.current.length > 30) {
      trailPoints.current = trailPoints.current.slice(-30);
    }
    drawTrail();
  };

  const resetGame = () => {
    setGameState('playing');
    setScore(0);
    setCameraY(0);
    setPlayerPos({ x: 200, y: 450 });
    setPlayerVelocity({ x: 0, y: -3.6 });
    trailPoints.current = [];
    setHookedNode(null);
    setIsHolding(false);

    const initialNodes = generateInitialNodes();
    const safeNodes = initialNodes.filter((node) => {
      const dx = node.x - 200;
      const dy = node.y - 450;
      const distance = Math.sqrt(dx * dx + dy * dy);
      return distance > 50;
    });

    setGameNodes(safeNodes);
    setStartGracePeriod(true);
    setTimeout(() => setStartGracePeriod(false), 1000);
  };

  useEffect(() => {
    const initialNodes = generateInitialNodes();
    const safeNodes = initialNodes.filter((node) => {
      const dx = node.x - 200;
      const dy = node.y - 450;
      const distance = Math.sqrt(dx * dx + dy * dy);
      return distance > 50;
    });
    setGameNodes(safeNodes);

    setStartGracePeriod(true);
    const graceTimer = setTimeout(() => setStartGracePeriod(false), 1000);
    return () => clearTimeout(graceTimer);
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas) {
      canvas.width = gameBounds.width;
      canvas.height = gameBounds.height;
      drawTrail();
    }
  }, [cameraY]);

  const handleHoldStart = () => {
    if (gameState === 'gameover') {
      resetGame();
      return;
    }

    setIsHolding(true);

    if (!hookedNode) {
      const findClosestNode = () => {
        let closestNode = null;
        let closestDistance = Infinity;

        for (const node of gameNodes) {
          const dx = node.x - playerPos.x;
          const dy = node.y - playerPos.y;
          const distance = Math.sqrt(dx * dx + dy * dy);
          const nodeHookRadius = 200 * (node.radius / 16);

          if (distance < nodeHookRadius && (!closestNode || distance < closestDistance)) {
            closestNode = { node, distance };
            closestDistance = distance;
          }
        }

        return closestNode;
      };

      const closestNode = findClosestNode();

      if (closestNode) {
        setHookedNode(closestNode.node);
        hookSoundRef.current.play();
        swingSoundRef.current.play();

        const dx = playerPos.x - closestNode.node.x;
        const dy = playerPos.y - closestNode.node.y;
        const initialAngle = Math.atan2(dy, dx);
        setHookAngle(initialAngle);
        setHookDistance(closestNode.distance);

        const crossProduct = dx * playerVelocity.y - dy * playerVelocity.x;
        gameSettings.current.spinDirection = Math.sign(crossProduct) || 1;
      }
    }
  };

  const handleHoldEnd = () => {
    setIsHolding(false);

    if (hookedNode) {
      launchSoundRef.current.play();
      swingSoundRef.current.pause();
      swingSoundRef.current.currentTime = 0;

      const tangentOffset = gameSettings.current.spinDirection * Math.PI / 2;
      const angle = hookAngle + tangentOffset;
      const speed = 6;

      setPlayerVelocity({
        x: Math.cos(angle) * speed,
        y: Math.sin(angle) * speed,
      });

      setHookedNode(null);
    }
  };

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.code === 'Space') {
        handleHoldStart();
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
  }, [playerPos, hookedNode, hookAngle, gameState]);

  useEffect(() => {
    if (gameState !== 'playing' && gameState !== 'playing-update') return;

    const gameLoop = setInterval(() => {
      setPlayerPos((prevPos) => {
        let newX, newY;

        if (hookedNode && isHolding) {
          const distanceFactor = Math.max(0.5, Math.min(1.5, hookDistance / 100));
          const spinSpeed = 0.06 / distanceFactor;
          const oscillation = Math.sin(Date.now() * 0.003) * 0.008;
          const finalSpinSpeed = (spinSpeed + oscillation) * gameSettings.current.spinDirection;

          const newAngle = hookAngle + finalSpinSpeed;
          setHookAngle(newAngle);

          newX = hookedNode.x + Math.cos(newAngle) * hookDistance;
          newY = hookedNode.y + Math.sin(newAngle) * hookDistance;
        } else {
          newX = prevPos.x + playerVelocity.x;
          newY = prevPos.y + playerVelocity.y;
        }

        if (!startGracePeriod) {
          for (const node of gameNodes) {
            if (hookedNode && node.id === hookedNode.id) continue;

            const dx = newX - node.x;
            const dy = newY - node.y;
            const distance = Math.sqrt(dx * dx + dy * dy);
            const collisionDistance = node.radius + 2;

            if (distance < collisionDistance) {
              setGameState('gameover');
              return prevPos;
            }
          }
        }

        if (!hookedNode && (newX < 10 || newX > gameBounds.width - 10)) {
          setGameState('gameover');
          return prevPos;
        }

        if (newY > cameraY + gameBounds.height + 50) {
          setGameState('gameover');
          return prevPos;
        }

        addTrailPoint(newX, newY);
        return { x: newX, y: newY };
      });

      setCameraY((prevCameraY) => {
        const screenMiddle = prevCameraY + gameBounds.height / 2;
        return playerPos.y < screenMiddle ? playerPos.y - gameBounds.height / 2 : prevCameraY;
      });

      setGameNodes((prevNodes) => generateNewNodes(prevNodes, cameraY));

      const baseY = 0;
      const climbHeight = baseY - cameraY;
      const heightScore = Math.max(0, Math.floor(climbHeight / 10));
      setScore(heightScore);
    }, 16);

    return () => clearInterval(gameLoop);
  }, [playerPos, playerVelocity, hookedNode, hookAngle, hookDistance, isHolding, gameState, cameraY, startGracePeriod, gameNodes]);

  useEffect(() => {
    if (gameState === 'playing' || gameState === 'playing-update') {
      backgroundMusicRef.current.play().catch(() => {});
    } else if (gameState === 'gameover') {
      backgroundMusicRef.current.pause();
      swingSoundRef.current.pause();
      swingSoundRef.current.currentTime = 0;
      gameOverSoundRef.current.play().catch(() => {});
    }
  }, [gameState]);

  return (
    <div className="flex flex-col items-center justify-center h-full min-h-full bg-gradient-to-b from-gray-900 to-indigo-900 p-6 rounded-lg">
      <div className="mb-6 text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-600 tracking-wider">
        ONE MORE LINE
      </div>

      <div className="mb-4 px-4 py-2 rounded-full bg-gray-800 bg-opacity-70 text-center flex items-center justify-between">
        <div className="text-xl font-semibold text-white">
          <span className="text-pink-400">SCORE:</span> {score}
        </div>

        <div
          className={`ml-4 px-3 py-1 rounded-full cursor-pointer transition-colors flex items-center ${
            gameSettings.current.infiniteTrail ? 'bg-pink-600 text-white' : 'bg-gray-700 text-gray-300'
          }`}
          onClick={toggleTrailMode}
        >
          <span className="text-sm font-medium mr-2">Infinite Trail</span>
          <div className={`w-10 h-5 rounded-full relative ${gameSettings.current.infiniteTrail ? 'bg-indigo-300' : 'bg-gray-600'}`}>
            <div
              className={`absolute w-4 h-4 rounded-full top-0.5 transition-transform ${
                gameSettings.current.infiniteTrail ? 'bg-pink-600 transform translate-x-5' : 'bg-gray-400 translate-x-0.5'
              }`}
            ></div>
          </div>
        </div>
      </div>

      <div
        className="relative w-full max-w-md bg-gray-900 border-2 border-indigo-500 rounded-lg overflow-hidden shadow-lg shadow-indigo-500/30"
        style={{ width: gameBounds.width, height: gameBounds.height }}
        onMouseDown={handleHoldStart}
        onMouseUp={handleHoldEnd}
        onTouchStart={handleHoldStart}
        onTouchEnd={handleHoldEnd}
      >
        <div className="absolute top-0 left-0 w-2 h-full bg-gradient-to-b from-pink-500 to-indigo-500 opacity-90" style={{ zIndex: 9 }} />
        <div className="absolute top-0 right-0 w-2 h-full bg-gradient-to-b from-pink-500 to-indigo-500 opacity-90" style={{ zIndex: 9 }} />

        <canvas ref={canvasRef} className="absolute top-0 left-0 w-full h-full" style={{ zIndex: 8, pointerEvents: 'none' }} />

        <div className="absolute left-0 w-full" style={{ transform: `translateY(${-cameraY}px)` }}>
          {[...Array(50)].map(
            (_, i) =>
              i > 4 && (
                <div key={i} className="absolute left-0 w-full h-px bg-white opacity-20" style={{ top: i * 100 }}>
                  <span className="absolute text-xs text-white opacity-40 left-4">{i * 10}m</span>
                </div>
              )
          )}

          {gameNodes.map((node) => (
            <React.Fragment key={node.id}>
              <div
                className="absolute rounded-full"
                style={{
                  left: node.x - node.radius,
                  top: node.y - node.radius,
                  width: node.radius * 2,
                  height: node.radius * 2,
                  boxShadow: `0 0 12px ${node.colorScheme.main}`,
                  zIndex: 5,
                  background:
                    node.patternType === 0
                      ? `radial-gradient(circle at 35% 35%, ${node.colorScheme.light} 0%, ${node.colorScheme.main} 60%, ${node.colorScheme.dark} 100%)`
                      : node.patternType === 1
                      ? `linear-gradient(135deg, ${node.colorScheme.light} 0%, ${node.colorScheme.main} 50%, ${node.colorScheme.dark} 100%)`
                      : `repeating-linear-gradient(45deg, ${node.colorScheme.main}, ${node.colorScheme.main} 5px, ${node.colorScheme.light} 5px, ${node.colorScheme.light} 10px)`,
                  filter: `brightness(${1 + node.brightnessOffset / 100})`,
                  transition: 'transform 0.1s ease-out',
                  transform: isHolding && !hookedNode ? 'scale(1.05)' : 'scale(1)',
                }}
              />

              <div
                className="absolute rounded-full border"
                style={{
                  left: node.x - 200 * (node.radius / 16),
                  top: node.y - 200 * (node.radius / 16),
                  width: 400 * (node.radius / 16),
                  height: 400 * (node.radius / 16),
                  opacity: 0.05,
                  borderColor: node.colorScheme.main,
                }}
              />

              {isHolding && !hookedNode && (
                <div
                  className="absolute rounded-full border"
                  style={{
                    left: node.x - 200 * (node.radius / 16),
                    top: node.y - 200 * (node.radius / 16),
                    width: 400 * (node.radius / 16),
                    height: 400 * (node.radius / 16),
                    opacity: 0.15,
                    borderColor: node.colorScheme.light,
                    borderWidth: '2px',
                  }}
                />
              )}
            </React.Fragment>
          ))}

          {hookedNode && isHolding && (
            <div
              className="absolute bg-white opacity-30"
              style={{
                left: hookedNode.x,
                top: hookedNode.y,
                width: `${hookDistance}px`,
                height: '1px',
                transform: `rotate(${hookAngle * (180 / Math.PI)}deg)`,
                transformOrigin: '0 0',
              }}
            />
          )}

          <div
            className="absolute rounded-full shadow-glow"
            style={{
              left: playerPos.x - 8,
              top: playerPos.y - 8,
              width: 16,
              height: 16,
              background: 'radial-gradient(circle at 35% 35%, #fb7185 0%, #ec4899 70%, #be185d 100%)',
              boxShadow: '0 0 16px #ec4899, 0 0 24px rgba(236, 72, 153, 0.5)',
              zIndex: 10,
            }}
          />
        </div>

        {gameState === 'gameover' && (
          <div className="absolute inset-0 bg-black bg-opacity-80 backdrop-blur-sm flex flex-col items-center justify-center">
            <div className="text-pink-400 text-4xl font-bold mb-2">GAME OVER</div>
            <div className="text-white text-2xl mb-8">
              <span className="text-indigo-400">SCORE:</span> {score}
            </div>
            <button
              className="px-6 py-3 bg-gradient-to-r from-pink-500 to-purple-600 text-white font-bold rounded-full shadow-lg hover:from-pink-600 hover:to-purple-700 transform transition hover:scale-105 focus:outline-none"
              onClick={resetGame}
            >
              PLAY AGAIN
            </button>
          </div>
        )}
      </div>

      <div className="mt-6 px-6 py-4 bg-gray-800 bg-opacity-50 rounded-xl shadow-md max-w-md">
        <div className="text-center text-white">
          <p className="mb-2 font-medium">
            {gameState === 'playing' || gameState === 'playing-update'
              ? 'Hold SPACE or click to hook onto circles. Release to launch!'
              : 'Press SPACE or click to play again'}
          </p>
          <div className="mt-2 text-sm text-indigo-300 flex flex-col gap-1">
            <p>🚀 The higher you climb, the more points you earn!</p>
            <p>🛡️ You're safe from walls while swinging!</p>
            <p>⚠️ Don't hit the nodes directly!</p>
            <p>🔄 Closer swing = faster rotation!</p>
            <p>💎 Node sizes range from tiny (11px) to huge (30px)!</p>
            <p>🎨 Each node has a unique color and texture!</p>
            <p>✏️ Toggle "Infinite Trail" to see your entire path!</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default OneMoreLine;