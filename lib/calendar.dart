import 'dart:math';

import 'core.dart';
// TODO: use this
abstract class CalendarSystem {
  String durationName(Uint64 durationInMs);
  String dateName(Uint64 msSinceSystemStart);
  String timeName(Uint64 msSinceSystemStart);
}

// day, hour, minute, second
class DHMSCalendarSystem extends CalendarSystem {
  final Uint64 epoch;
  final int secondsPerMinute;
  final int minutesPerHour;
  final int hoursPerDay;

  DHMSCalendarSystem(
      this.epoch, this.secondsPerMinute, this.minutesPerHour, this.hoursPerDay);

  Uint64 getDayNumber(Uint64 msSinceSystemStart) =>
      (msSinceSystemStart - epoch) ~/
      (1000 * secondsPerMinute * minutesPerHour * hoursPerDay).toDouble();

  @override
  String dateName(Uint64 msSinceSystemStart) {
    Uint64 dayNumber = getDayNumber(msSinceSystemStart);
    return 'Day $dayNumber';
  }

  @override
  String durationName(Uint64 durationInMs) {
    int milliseconds = (durationInMs % 1000).toInt();
    int seconds = ((durationInMs / 1000) % secondsPerMinute).floor();
    int minutes = ((durationInMs / (1000 * secondsPerMinute)) % minutesPerHour).floor();
    int hours = ((durationInMs / (1000 * secondsPerMinute * minutesPerHour)) % hoursPerDay).floor();
    int days = (durationInMs / (1000 * secondsPerMinute * minutesPerHour * hoursPerDay)).floor();
    if (days > 0) return '$days days and $hours hours';
    if (hours > 0)
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (minutes > 0)
      return '$minutes:${seconds.toString().padLeft(2, '0')}${(milliseconds / 1000).toString().substring(1)}';
    if (seconds > 0)
      return '$seconds${(milliseconds / 1000).toString().substring(1)} seconds';
    return '$milliseconds milliseconds';
  }

  @override
  String timeName(Uint64 msSinceSystemStart) {
    Uint64 msSinceEpoch = msSinceSystemStart - epoch;
    int minutes = ((msSinceEpoch / (1000 * secondsPerMinute)) % minutesPerHour).floor();
    int hours = ((msSinceEpoch / (1000 * secondsPerMinute * minutesPerHour)) % hoursPerDay).floor();
    return '$hours:${minutes.toString().padLeft((log(minutesPerHour)*ln10).floor(), '0')}';
  }
}

class YearDHMSCalendarSystem extends DHMSCalendarSystem {
  final int daysPerYear;
  Uint64 getYearNumber(Uint64 msSinceSystemStart) =>
      (msSinceSystemStart - epoch) ~/
      (1000 * secondsPerMinute * minutesPerHour * hoursPerDay * daysPerYear).toDouble();
  
  @override
  String dateName(Uint64 msSinceSystemStart) {
    return '${getYearNumber(msSinceSystemStart)} day ${getDayNumber(msSinceSystemStart)}';
  }

  @override
  String durationName(Uint64 durationInMs) {
    int days = ((durationInMs / (1000 * secondsPerMinute * minutesPerHour * hoursPerDay)) % daysPerYear).floor();
    int years = (durationInMs / (1000 * secondsPerMinute * minutesPerHour * hoursPerDay * daysPerYear)).floor();
    if (years == 0) return super.durationName(durationInMs);
    return '$years years and $days days';
  }

  YearDHMSCalendarSystem(super.epoch, super.secondsPerMinute, super.minutesPerHour, super.hoursPerDay, this.daysPerYear);
}