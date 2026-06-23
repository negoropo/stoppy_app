class DateTimeFormatter {
  const DateTimeFormatter._();

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String dateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  static String date(DateTime dateTime) {
    final local = dateTime.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String monthYear(DateTime dateTime) {
    return '${_monthNames[dateTime.month - 1]} ${dateTime.year}';
  }

  static String monthYearList(List<DateTime> months) {
    if (months.isEmpty) {
      return 'No title months recorded';
    }

    return months.map(monthYear).join(', ');
  }
}
