enum MovementDirection { clockwise, counterClockwise }

MovementDirection oppositeMovementDirection(MovementDirection direction) {
  return switch (direction) {
    MovementDirection.clockwise => MovementDirection.counterClockwise,
    MovementDirection.counterClockwise => MovementDirection.clockwise,
  };
}
