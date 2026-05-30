import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}

class MyGame extends FlameGame {
  late final SpriteComponent background;
  late final JoystickComponent joystick;
  late final Player player;
  late final Enemy enemy = Enemy(position: Vector2(200, 200), size: Vector2(82, 35));

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
    add(player);
    add(enemy);
    camera.viewport.add(joystick);
  }
}

class Player extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  late ui.Image spriteSheet;
  late JoystickDirection lastDirection;
  double runAnimationTimer = 0.0;
  final double runAnimationSpeed = 0.2;

  final List<double> rowOffsets = [2.0, 83.0, 196.0, 311.0];
  final List<double> rowHeights = [81.0, 113.0, 115.0, 119.0];
  final double colWidth = 74.0;

  Player({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
    spriteSheet = await game.images.load('playerspritesheet.png');
    lastDirection = JoystickDirection.down;
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
  void update(double dt) {
    super.update(dt);
    final currentJoystick = game.joystick;

    if (currentJoystick.direction != JoystickDirection.idle) {
      position.add(currentJoystick.relativeDelta * 200 * dt);
      lastDirection = currentJoystick.direction;
      runAnimationTimer += dt;
      updateSpriteForDirection(currentJoystick.direction, true);
    } else {
      runAnimationTimer = 0.0;
      updateSpriteForDirection(lastDirection, false);
    }
  }
}

class Enemy extends SpriteComponent
    with HasGameReference<MyGame>, CollisionCallbacks {
  late ui.Image spriteSheet;
  double runAnimationTimer = 0.0;
  final double runAnimationSpeed = 0.6;

  Enemy({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
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
    runAnimationTimer += dt;
    double col = (runAnimationTimer ~/ runAnimationSpeed) % 2 == 0 ? 0 : 82;
    sprite = Sprite(
      spriteSheet,
      srcPosition: Vector2(col, 0),
      srcSize: Vector2(82, 35),
    );
  }
}
