const config = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  physics: {
    default: "matter",
    matter: {
      gravity: { y: 1 },
      debug: {
        showBounds: false,
        showVelocity: false,
        showCollisions: false,
        showAxes: false,
        showPositions: false,
        showAngleIndicator: false,
        showIds: false,
        showSeparation: false,
        showSleeping: false,
      },
    },
  },
  scene: {
    preload: preload,
    create: create,
    update: update,
  },
};

const game = new Phaser.Game(config);

let platform;
let leftPin;
let rightPin;
let ball;
let hazards = [];
let cursors;
let angleText;
let leftPinText;
let rightPinText;
let keys;
let gameOver = false;
let hazardRadius;
let gameOverText;

function preload() {
  // Load any assets if needed
}

function create() {
  // Create graphics for the pins
  const pinGraphics = this.add.graphics();
  pinGraphics.lineStyle(4, 0xff0000);
  pinGraphics.fillStyle(0xff0000);
  pinGraphics.fillCircle(10, 10, 10);
  pinGraphics.strokeCircle(10, 10, 10);

  const pinTexture = pinGraphics.generateTexture("pin", 20, 20);
  pinGraphics.destroy();

  // Add pins
  leftPin = this.matter.add.image(200, 300, "pin", null, { isStatic: true });
  rightPin = this.matter.add.image(600, 300, "pin", null, { isStatic: true });

  // Create hazards
  hazardRadius = Math.ceil(12 * 1.1); // 10% larger than ball radius
  const hazardPositions = [
    // Original hazards
    { x: 300, y: 200 },
    { x: 500, y: 200 },
    { x: 400, y: 400 },
    // New hazards
    { x: 250, y: 150 },
    { x: 350, y: 150 },
    { x: 450, y: 150 },
    { x: 550, y: 150 },
    { x: 250, y: 250 },
    { x: 350, y: 250 },
    { x: 450, y: 250 },
    { x: 550, y: 250 },
    { x: 250, y: 350 },
    { x: 350, y: 350 },
    { x: 450, y: 350 },
    { x: 550, y: 350 },
    { x: 250, y: 450 },
    { x: 350, y: 450 },
    { x: 450, y: 450 },
    { x: 550, y: 450 },
    // Corner hazards
    { x: 220, y: 120 },
    { x: 580, y: 120 },
    { x: 220, y: 480 },
    { x: 580, y: 480 },
    // Center hazards
    { x: 400, y: 200 },
    { x: 400, y: 300 }
  ];

  hazardPositions.forEach((pos) => {
    const hazard = this.matter.add.circle(pos.x, pos.y, hazardRadius, {
      isStatic: true,
      isSensor: true, // Makes it not physically collide but still detect overlap
      render: { fillStyle: "#ff0000" },
      collisionFilter: {
        category: 0x0008, // Hazard category
        mask: 0x0004, // Only detect ball category
      },
    });
    hazards.push(hazard);
  });

  // Add walls that only interact with the ball
  const wallOptions = {
    isStatic: true,
    render: { fillStyle: "#666666" },
    collisionFilter: {
      category: 0x0002, // Wall category
      mask: 0x0004, // Only collide with ball category
    },
  };

  // Position walls at the ends of the platform's range
  this.matter.add.rectangle(200, 300, 20, 600, wallOptions); // Left wall
  this.matter.add.rectangle(600, 300, 20, 600, wallOptions); // Right wall

  // Function to update platform graphics based on pin positions
  const updatePlatformGraphics = () => {
    // Calculate platform dimensions based on pin positions
    const dx = rightPin.x - leftPin.x;
    const dy = rightPin.y - leftPin.y;
    const length = Math.sqrt(dx * dx + dy * dy);
    const angle = Math.atan2(dy, dx);

    // Remove old platform and constraints
    if (platform) {
      this.matter.world.remove(platform);
    }
    if (this.leftConstraint) {
      this.matter.world.removeConstraint(this.leftConstraint);
    }
    if (this.rightConstraint) {
      this.matter.world.removeConstraint(this.rightConstraint);
    }

    // Create new platform with correct position and rotation
    const midX = leftPin.x + dx / 2;
    const midY = leftPin.y + dy / 2;

    // Create platform as a physics rectangle
    platform = this.matter.bodies.rectangle(midX, midY, length, 10, {
      chamfer: { radius: 5 },
      render: { fillStyle: "#666666" },
      friction: 0.001, // Almost no friction
      isStatic: true, // Make the platform static for better collision
      collisionFilter: {
        category: 0x0001, // Platform category
        mask: 0x0004, // Collide with ball category
      },
    });

    // Set the rotation
    this.matter.body.setAngle(platform, angle);

    // Add the platform to the world
    this.matter.world.add(platform);

    // Create constraints at the ends of the platform
    this.leftConstraint = this.matter.add.constraint(platform, leftPin, 0, 1, {
      pointA: { x: -length / 2, y: 0 },
      pointB: { x: 0, y: 0 },
    });
    this.rightConstraint = this.matter.add.constraint(
      platform,
      rightPin,
      0,
      1,
      {
        pointA: { x: length / 2, y: 0 },
        pointB: { x: 0, y: 0 },
      }
    );
  };

  // Initial platform creation
  updatePlatformGraphics();

  // Update platform when pins move
  this.events.on("update", () => {
    updatePlatformGraphics();
  });

  // Add ball
  const ballGraphics = this.add.graphics();
  ballGraphics.lineStyle(2, 0x888888);
  ballGraphics.fillStyle(0x888888);
  ballGraphics.fillCircle(10, 10, 10);
  ballGraphics.strokeCircle(10, 10, 10);

  ballGraphics.generateTexture("ball", 20, 20);
  ballGraphics.destroy();

  // Create the ball with proper collision radius and position it above the platform
  const ballRadius = 12;
  const platformY = (leftPin.y + rightPin.y) / 2; // Get the middle Y position of the platform
  ball = this.matter.add.circle(400, platformY - 30, ballRadius, {
    restitution: 0.001, // Extremely low bounce
    friction: 0.001, // Almost no friction
    density: 0.001, // Light
    frictionAir: 0.0005, // Reduced air friction
    render: { fillStyle: "#888888" }, // Gray color
    collisionFilter: {
      category: 0x0004, // Ball category
      mask: 0xffff, // Collide with everything
    },
    slop: 0, // Prevent sinking into surfaces
    circleRadius: ballRadius, // Set the collision radius explicitly
  });

  // Add text displays
  angleText = this.add.text(16, 16, "Angle: 0°", {
    fontSize: "18px",
    fill: "#fff",
  });

  leftPinText = this.add.text(16, 40, "Left Pin Height: 300", {
    fontSize: "18px",
    fill: "#fff",
  });

  rightPinText = this.add.text(16, 64, "Right Pin Height: 300", {
    fontSize: "18px",
    fill: "#fff",
  });

  // Setup keyboard controls
  cursors = this.input.keyboard.createCursorKeys();
  keys = this.input.keyboard.addKeys("W,S,I,K,ESC");

  // Add escape key handler for restart
  keys.ESC.on("down", () => {
    gameOver = false;
    this.scene.restart();
  });

  // Add instructions
  this.add.text(16, 520, "W/S: Move Left Pin Up/Down", {
    fontSize: "18px",
    fill: "#fff",
  });
  this.add.text(16, 550, "I/K: Move Right Pin Up/Down", {
    fontSize: "18px",
    fill: "#fff",
  });
}

function update() {
  const moveSpeed = 1;

  // Calculate current angle
  const currentAngle =
    (Math.atan2(rightPin.y - leftPin.y, rightPin.x - leftPin.x) * 180) /
    Math.PI;
  const maxAngle = 30; // Maximum tilt in degrees
  const isTooLeftAngled = currentAngle <= -maxAngle;
  const isTooRightAngled = currentAngle >= maxAngle;

  // Move left pin up/down with W/S keys
  if (keys.W.isDown && leftPin.y > 100 && !isTooRightAngled) {
    leftPin.y -= moveSpeed;
  }
  if (keys.S.isDown && leftPin.y < 500 && !isTooLeftAngled) {
    leftPin.y += moveSpeed;
  }

  // Move right pin up/down with I/K keys
  if (keys.I.isDown && rightPin.y > 100 && !isTooLeftAngled) {
    rightPin.y -= moveSpeed;
  }
  if (keys.K.isDown && rightPin.y < 500 && !isTooRightAngled) {
    rightPin.y += moveSpeed;
  }

  // Update text displays
  const angle = Math.atan2(rightPin.y - leftPin.y, rightPin.x - leftPin.x);
  angleText.setText(`Angle: ${Math.round((angle * 180) / Math.PI)}°`);
  leftPinText.setText(`Left Pin Height: ${Math.round(leftPin.y)}`);
  rightPinText.setText(`Right Pin Height: ${Math.round(rightPin.y)}`);

  if (!gameOver) {
    // Check hazard collisions
    hazards.forEach((hazard) => {
      const dx = ball.position.x - hazard.position.x;
      const dy = ball.position.y - hazard.position.y;
      const ballRadius = 12;

      // Calculate distance between centers
      const distance = Math.sqrt(dx * dx + dy * dy);

      // Only check overlap if circles are close enough
      if (distance < hazardRadius + ballRadius) {
        // Calculate area of intersection between circles
        const d = distance;
        const r1 = ballRadius;
        const r2 = hazardRadius;

        // Calculate overlap area
        let overlap = 0;
        if (d <= Math.abs(r2 - r1)) {
          // One circle is completely inside the other
          overlap = Math.PI * Math.min(r1, r2) ** 2;
        } else if (d < r1 + r2) {
          // Circles partially overlap
          const a = Math.acos((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d));
          const b = Math.acos((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d));
          overlap =
            r1 * r1 * (a - Math.sin(2 * a) / 2) +
            r2 * r2 * (b - Math.sin(2 * b) / 2);
        }

        const ballArea = Math.PI * ballRadius * ballRadius;
        const overlapPercentage = overlap / ballArea;

        // Check if ball is mostly inside hazard
        if (overlapPercentage > 0.8) {
          // Game over
          gameOver = true;

          // Create game over text
          gameOverText = this.add.text(
            400,
            300,
            "GAME OVER\nPress ESC to restart",
            {
              fontSize: "32px",
              fill: "#ff0000",
              align: "center",
            }
          );
          gameOverText.setOrigin(0.5);

          // Animate ball fading into hazard
          const targetX = hazard.position.x;
          const targetY = hazard.position.y;
          const duration = 500; // milliseconds

          // Stop physics on the ball
          this.matter.body.setStatic(ball, true);

          // Create a sprite at ball's position for fade animation
          const ballSprite = this.add.circle(
            ball.position.x,
            ball.position.y,
            12,
            0x888888
          );

          // Animate the sprite
          this.tweens.add({
            targets: ballSprite,
            x: targetX,
            y: targetY,
            scale: 0,
            alpha: 0,
            duration: duration,
            ease: "Power2",
            onComplete: () => {
              ballSprite.destroy();
            },
          });

          // Hide the actual physics ball
          ball.render.visible = false;
        }
      }
    });
  }

  // Reset ball if it falls off
  if (ball.y > 600) {
    this.matter.body.setPosition(ball, {
      x: platform.position.x,
      y: platform.position.y - 30,
    });
    this.matter.body.setVelocity(ball, { x: 0, y: 0 });
  }
}
