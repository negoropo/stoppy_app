class LeagueDivision {
  const LeagueDivision({required this.number, int? capacity})
    : assert(number > 0),
      assert(capacity == null || capacity > 0),
      capacity = capacity ?? 10 * (1 << (number - 1));

  final int number;
  final int capacity;

  bool get isFirstDivision => number == 1;

  LeagueDivision nextDivision() {
    return LeagueDivision(number: number + 1, capacity: capacity * 2);
  }
}
