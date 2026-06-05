import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  final game = MyGame();
  runApp(
    GameWidget(
      game: game,
      overlayBuilderMap: {
        'GameOverOverlay': (BuildContext context, MyGame game) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Game Over',
                  style: TextStyle(fontSize: 48, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: () => game.restartGame(),
                  child: Text('Restart'),
                ),
              ],
            ),
          );
        },
      },
    ),
  );
}

class MyGame extends FlameGame with HasCollisionDetection {
  late final SpriteComponent background;
  late final JoystickComponent joystick;
  late final Player player;
  late HealthBarDisplay healthBarDisplay;
  final random = Random();
  final gameoverOverlayIdentifier = 'GameOverOverlay';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    background = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size;
    final knobPaint = BasicPalette.gray.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.gray.withAlpha(100).paint();

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 30, paint: knobPaint),
      background: CircleComponent(radius: 70, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );

    player = Player(position: size / 2, size: Vector2(55, 105));

    add(background);

    final random = Random();
    for (int i = 0; i < 10; i++) {
      add(
        Enemy(
          position: Vector2(
            random.nextDouble() * size.x,
            random.nextDouble() * size.y,
          ),
          size: Vector2(82, 35),
          targetPlayer: player,
        ),
      );
    }
    add(player);
    add(FireButton(player: player));
    camera.viewport.add(joystick);
  }

  void restartGame() {
    children.whereType<Enemy>().forEach((enemy) => enemy.removeFromParent());
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    player.position = size / 2;
    player.health = 5;
    overlays.remove(gameoverOverlayIdentifier);
    for (int i = 0; i < 10; i++) {
      add(
        Enemy(
          position: Vector2(
            random.nextDouble() * size.x,
            random.nextDouble() * size.y,
          ),
          size: Vector2(82, 35),
          targetPlayer: player,
        ),
      );
      resumeEngine();
    }
  }
}

class Player extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  late ui.Image spriteSheet;
  late JoystickDirection lastDirection;
  double runAnimationTimer = 0.0;
  final double runAnimationSpeed = 0.2;
  int health = 5;
  double damageCooldown = 0.0;
  final double damageCooldownDuration = 0.2;
  bool isDead = false;

  final List<double> rowOffsets = [2.0, 83.0, 196.0, 311.0];
  final List<double> rowHeights = [81.0, 113.0, 115.0, 119.0];
  final double colWidth = 74.0;
  double speed = 200.0;

  Player({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox()..collisionType = CollisionType.active);
    spriteSheet = await game.images.load('playerspritesheet.png');
    final healthBarSheet = await game.images.load('healthbarspritesheet.png');
    lastDirection = JoystickDirection.down;

    game.camera.viewport.add(
      HealthBarDisplay(player: this, healthBarImage: healthBarSheet),
    );

    sprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(0, rowOffsets[0]),
      srcSize: Vector2(colWidth, rowHeights[0]),
    );
  }

  int getRowForDirection(JoystickDirection direction) {
    switch (direction) {
      case JoystickDirection.down:
      case JoystickDirection.downLeft:
      case JoystickDirection.downRight:
        return 0;
      case JoystickDirection.left:
      case JoystickDirection.upLeft:
        return 1;
      case JoystickDirection.right:
      case JoystickDirection.upRight:
        return 2;
      case JoystickDirection.up:
        return 3;
      case JoystickDirection.idle:
        return getRowForDirection(lastDirection);
    }
  }

  void updateSpriteForDirection(JoystickDirection direction, bool isRunning) {
    int row = getRowForDirection(direction);
    int col = 0;

    if (isRunning) {
      col = (runAnimationTimer ~/ runAnimationSpeed) % 2 == 0 ? 1 : 3;
    } else {
      col = 0;
    }

    sprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(col * colWidth, rowOffsets[row]),
      srcSize: Vector2(colWidth, rowHeights[row]),
    );
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    final enemy = other is Enemy
        ? other
        : (other.parent is Enemy ? other.parent as Enemy : null);
    if (enemy != null && damageCooldown <= 0) {
      health -= 1;
      damageCooldown = damageCooldownDuration;
      if (health <= 0) {
        isDead = true;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (damageCooldown > 0) {
      damageCooldown -= dt;
    }

    if (isDead) {
      isDead = false;
      game.pauseEngine();
      game.overlays.toggle(game.gameoverOverlayIdentifier);
    }

    final currentJoystick = game.joystick;

    if (currentJoystick.direction != JoystickDirection.idle) {
      position.add(currentJoystick.relativeDelta * speed * dt);
      lastDirection = currentJoystick.direction;
      runAnimationTimer += dt;
      updateSpriteForDirection(currentJoystick.direction, true);
    } else {
      runAnimationTimer = 0.0;
      updateSpriteForDirection(lastDirection, false);
    }

    for (var enemy in game.children.whereType<Enemy>()) {
      final distance = position.distanceTo(enemy.position);
      if (distance < 45) {
        final offset = position - enemy.position;

        if (offset.length2 > 0.01) {
          final pushBack = offset.normalized();
          position += pushBack * speed * 0.8 * dt;
        }
      }
    }
  }
}

class Enemy extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  late ui.Image spriteSheet;
  double runAnimationTimer = 0.0;
  final double runAnimationSpeed = 0.6;
  final speed = 50.0;
  late SpriteComponent targetPlayer;

  Enemy({
    required Vector2 position,
    required Vector2 size,
    required this.targetPlayer,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(CircleHitbox()..collisionType = CollisionType.passive);

    spriteSheet = await game.images.load('enemyspritesheet.png');

    sprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(82, 35),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final toPlayer = targetPlayer.position - position;

    if (toPlayer.length2 > 0.01) {
      final direction = toPlayer.normalized();
      position += direction * speed * dt;
    }

    for (var enemy in parent!.children.whereType<Enemy>()) {
      if (enemy == this) continue;

      final offset = position - enemy.position;
      final distance = offset.length;

      if (distance < 25 && offset.length2 > 0.01) {
        final pushBack = offset.normalized();
        position += pushBack * speed * 1.5 * dt;
      }
    }

    runAnimationTimer += dt;

    double col = (runAnimationTimer ~/ runAnimationSpeed) % 2 == 0 ? 0 : 82;

    sprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(col, 0),
      srcSize: Vector2(82, 35),
    );
  }
}

class Bullet extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  final Vector2 direction;
  final double speed = 400.0;

  Bullet({
    required Vector2 position,
    required Vector2 size,
    required this.direction,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(CircleHitbox()..collisionType = CollisionType.active);

    sprite = Sprite(await game.images.load('bullet.png'));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * speed * dt;

    if (position.x < -size.x ||
        position.x > game.size.x + size.x ||
        position.y < -size.y ||
        position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Enemy) {
      other.removeFromParent();
      removeFromParent();
      game.add(
        Enemy(
          position: Vector2(
            game.random.nextDouble() * game.size.x,
            game.random.nextDouble() * game.size.y,
          ),
          size: Vector2(82, 35),
          targetPlayer: game.player,
        ),
      );
    }
  }
}

class FireButton extends SpriteComponent
    with HasGameReference<MyGame>, TapCallbacks {
  final Player player;

  FireButton({required this.player})
    : super(position: Vector2(0, 0), size: Vector2(80, 80));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final backgroundPaint = BasicPalette.lightOrange.withAlpha(150).paint();
    add(CircleComponent(radius: size.x / 2, paint: backgroundPaint));

    add(CircleHitbox());
    sprite = Sprite(await game.images.load('firebutton.png'));
    position = Vector2(game.size.x - size.x - 40, game.size.y - size.y - 40);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final bulletDirection = _joystickDirectionToVector(player.lastDirection);
    game.add(
      Bullet(
        position: player.position + bulletDirection * player.size.y / 2,
        size: Vector2(20, 20),
        direction: bulletDirection,
      ),
    );
  }
}

Vector2 _joystickDirectionToVector(JoystickDirection direction) {
  switch (direction) {
    case JoystickDirection.up:
      return Vector2(0, -1);
    case JoystickDirection.down:
      return Vector2(0, 1);
    case JoystickDirection.left:
      return Vector2(-1, 0);
    case JoystickDirection.right:
      return Vector2(1, 0);
    case JoystickDirection.upLeft:
      return Vector2(-1, -1).normalized();
    case JoystickDirection.upRight:
      return Vector2(1, -1).normalized();
    case JoystickDirection.downLeft:
      return Vector2(-1, 1).normalized();
    case JoystickDirection.downRight:
      return Vector2(1, 1).normalized();
    case JoystickDirection.idle:
      return Vector2(0, -1);
  }
}

class HealthBarDisplay extends SpriteComponent {
  final Player player;
  final ui.Image healthBarImage;

  final double healthBarStartX = 17.0;
  final double healthBarStartY = 103.0;
  final double frameWidth = 415.0;
  final double frameHeight = 90.0;

  HealthBarDisplay({required this.player, required this.healthBarImage})
    : super(size: Vector2(200, 43));

  @override
  void onLoad() {
    position = Vector2(20, 20);
    updateHealthDisplay();
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateHealthDisplay();
  }

  void updateHealthDisplay() {
    int col = 0;
    int row = 0;
    switch (player.health) {
      case 5:
        col = 0;
        row = 0;
        break;
      case 4:
        col = 0;
        row = 1;
        break;
      case 3:
        col = 0;
        row = 2;
        break;
      case 2:
        col = 1;
        row = 0;
        break;
      case 1:
        col = 1;
        row = 1;
        break;
      case 0:
        col = 1;
        row = 2;
        break;
      default:
        col = 0;
        row = 0;
    }

    sprite = Sprite(
      healthBarImage,
      srcPosition: Vector2(col * 412.0, row * 101.0),
      srcSize: Vector2(412.0, 101.0),
    );
  }
}
