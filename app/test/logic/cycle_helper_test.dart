import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/cycle_helper.dart';

void main() {
  group('CycleHelper Unit Tests', () {
    test('getIsoWeekNumber returns correct ISO week numbers', () {
      // 2026-06-01 is a Monday
      expect(CycleHelper.getIsoWeekNumber(DateTime(2026, 6, 1)), 23);
      // 2026-06-07 is a Sunday (same week)
      expect(CycleHelper.getIsoWeekNumber(DateTime(2026, 6, 7)), 23);
      // 2026-06-08 is a Monday (next week)
      expect(CycleHelper.getIsoWeekNumber(DateTime(2026, 6, 8)), 24);
      // 2026-01-01 is a Thursday (week 1 of 2026)
      expect(CycleHelper.getIsoWeekNumber(DateTime(2026, 1, 1)), 1);
    });

    test('getCycleId formats cycle ID correctly', () {
      expect(CycleHelper.getCycleId(DateTime(2026, 6, 1)), '2026-W23');
      expect(CycleHelper.getCycleId(DateTime(2026, 6, 7)), '2026-W23');
      expect(CycleHelper.getCycleId(DateTime(2026, 6, 8)), '2026-W24');
    });

    test('getCycleRange returns start and end range for default Monday start', () {
      // 2026-06-03 is a Wednesday
      final range = CycleHelper.getCycleRange(DateTime(2026, 6, 3));
      // Start should be Monday 2026-06-01 00:00:00
      expect(range.start, DateTime(2026, 6, 1));
      // End should be Sunday 2026-06-07 23:59:59.999
      expect(range.end, DateTime(2026, 6, 7, 23, 59, 59, 999));
    });

    test('getCycleRange allows customizable starting weekday', () {
      // 2026-06-03 is a Wednesday
      // Let's set start weekday to Wednesday (3)
      final range = CycleHelper.getCycleRange(DateTime(2026, 6, 3), startWeekday: DateTime.wednesday);
      expect(range.start, DateTime(2026, 6, 3));
      expect(range.end, DateTime(2026, 6, 9, 23, 59, 59, 999));
    });
  });
}
