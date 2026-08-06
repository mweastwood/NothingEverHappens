    test(
      'Skip (Drop Occurrence): Overdue Monday task is automatically skipped/expired and rescheduled to next calendar occurrence',
      () {
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'skip-task',
          title: 'Take out trash',
          description: 'Every day',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
        );
        
        final mondayInst = TaskInstance(
          id: 'monday',
          scheduleId: task.id,
          ruleId: task.schedules[0].id,
          title: task.title,
          description: task.description,
          scheduledDate: monday,
          startRelativeTime: task.schedules[0].startRelativeTime,
          dueRelativeTime: task.schedules[0].dueRelativeTime,
          status: 'pending',
        );

        final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);

        final action = SchedulerEngine.evaluate(task, [mondayInst], tuesdayDateTime);

        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.id, 'monday');
        expect(action.instancesToUpdate.first.status, 'skipped');

        expect(action.instancesToSpawn, isNotEmpty);
        expect(action.instancesToSpawn.first.scheduledDate.day, 26);
        expect(action.instancesToSpawn.first.status, 'pending');
      },
    );

    test(
      'Auto-dismiss with zero grace period on mixed task drops passed one-off schedules',
      () {
        final monday = const CivilDay(year: 2026, month: 5, day: 25);

        final mixedTask = TaskSchedule(
          id: 'mixed-skip-task',
          title: 'Mixed skip task',
          description: 'Testing skip policy on mixed task',
          schedules: [
            OneOffSchedule(
              date: monday,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
            DailySchedule(
              startDate: monday,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
        );
        
        final mondayOneOffInst = TaskInstance(
          id: 'mon-oneoff',
          scheduleId: mixedTask.id,
          ruleId: mixedTask.schedules[0].id,
          title: mixedTask.title,
          description: mixedTask.description,
          scheduledDate: monday,
          startRelativeTime: mixedTask.schedules[0].startRelativeTime,
          dueRelativeTime: mixedTask.schedules[0].dueRelativeTime,
          status: 'pending',
        );

        final mondayDailyInst = TaskInstance(
          id: 'mon-daily',
          scheduleId: mixedTask.id,
          ruleId: mixedTask.schedules[1].id,
          title: mixedTask.title,
          description: mixedTask.description,
          scheduledDate: monday,
          startRelativeTime: mixedTask.schedules[1].startRelativeTime,
          dueRelativeTime: mixedTask.schedules[1].dueRelativeTime,
          status: 'pending',
        );

        final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);

        final action = SchedulerEngine.evaluate(mixedTask, [mondayOneOffInst, mondayDailyInst], tuesdayDateTime);

        expect(action.instancesToUpdate, hasLength(2));
        final updatedOneOff = action.instancesToUpdate.firstWhere((i) => i.ruleId == mixedTask.schedules[0].id);
        final updatedDaily = action.instancesToUpdate.firstWhere((i) => i.ruleId == mixedTask.schedules[1].id);
        
        expect(updatedOneOff.status, 'skipped');
        expect(updatedDaily.status, 'skipped');

        expect(action.instancesToSpawn, isNotEmpty);
        expect(action.instancesToSpawn.first.ruleId, mixedTask.schedules[1].id);
        expect(action.instancesToSpawn.first.scheduledDate.day, 26);
        expect(action.instancesToSpawn.first.status, 'pending');
      },
    );

    test(
      'Auto-dismiss with zero grace period with daily cross-midnight due time does not skip early',
      () {
        final task = TaskSchedule(
          id: 'cross-midnight-task',
          title: 'Cross Midnight Task',
          description: 'Testing skip policy cross midnight',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 18),
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 5, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 11, minute: 0),
              ),
            ),
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 18),
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 20, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 1,
                time: TimeOfDay(hour: 2, minute: 0),
              ),
            ),
          ],
        );

        final sched0Inst = TaskInstance(
          id: 's0-18',
          scheduleId: task.id,
          ruleId: task.schedules[0].id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 18),
          startRelativeTime: task.schedules[0].startRelativeTime,
          dueRelativeTime: task.schedules[0].dueRelativeTime,
          status: 'pending',
        );

        final sched1Inst = TaskInstance(
          id: 's1-18',
          scheduleId: task.id,
          ruleId: task.schedules[1].id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 18),
          startRelativeTime: task.schedules[1].startRelativeTime,
          dueRelativeTime: task.schedules[1].dueRelativeTime,
          status: 'pending',
        );

        // Move to Thursday June 18th 10:00 PM (past sched0 due, before sched1 due)
        final thurs10pm = DateTime(2026, 6, 18, 22, 0);
        
        var action = SchedulerEngine.evaluate(task, [sched0Inst, sched1Inst], thurs10pm);
        
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.ruleId, task.schedules[0].id);
        expect(action.instancesToUpdate.first.status, 'skipped');
        
        // Move to Friday June 19th 12:05 AM (past midnight, but BEFORE due time 2:00 AM)
        final fri1205am = DateTime(2026, 6, 19, 0, 5);
        // Sched1 inst should still be pending, and Friday's instance should spawn.
        
        action = SchedulerEngine.evaluate(task, [sched0Inst.copyWith(status: 'skipped'), sched1Inst], fri1205am);
        
        expect(action.instancesToUpdate, isEmpty);
        expect(action.instancesToSpawn.any((i) => i.ruleId == task.schedules[1].id && i.scheduledDate.day == 19), isTrue);
        
        // Move to Friday June 19th 2:05 AM (AFTER due time 2:00 AM)
        final fri205am = DateTime(2026, 6, 19, 2, 5);
        
        action = SchedulerEngine.evaluate(task, [sched0Inst.copyWith(status: 'skipped'), sched1Inst], fri205am);
        
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.ruleId, task.schedules[1].id);
        expect(action.instancesToUpdate.first.status, 'skipped');
      },
    );

    test(
      'Auto-Dismiss missed policy respects custom grace period and auto-dismisses after grace period passes',
      () {
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'grace-skip-task',
          title: 'Grace Skip Task',
          description: 'Testing grace period skip policy',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration(hours: 3),
              ),
            ),
          ],
        );
        
        final mondayInst = TaskInstance(
          id: 'mon-grace',
          scheduleId: task.id,
          ruleId: task.schedules[0].id,
          title: task.title,
          description: task.description,
          scheduledDate: monday,
          startRelativeTime: task.schedules[0].startRelativeTime,
          dueRelativeTime: task.schedules[0].dueRelativeTime,
          status: 'pending',
        );

        // Move time to 6:00 PM (past due time of 5:00 PM, but within 3-hour grace period)
        final withinGrace = DateTime(2026, 5, 25, 18, 0);
        
        var action = SchedulerEngine.evaluate(task, [mondayInst], withinGrace);
        expect(action.instancesToUpdate, isEmpty);

        // Move time to 8:05 PM (past 3-hour grace period)
        final pastGrace = DateTime(2026, 5, 25, 20, 5);
        
        action = SchedulerEngine.evaluate(task, [mondayInst], pastGrace);
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.status, 'skipped');
      },
    );

    test(
      'Stack/Overlap (Allow Concurrency): Master task missed for Monday and Tuesday spawns separate cards on Wednesday',
      () {
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'stack-task',
          title: 'Read a book',
          description: 'Every day',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
          missedPolicy: MissedPolicy.stack,
          isMaster: true,
        );

        // Wednesday
        final wednesdayDateTime = DateTime(2026, 5, 27, 10, 0);

        final action = SchedulerEngine.evaluate(task, [], wednesdayDateTime, futureInstancesCount: 10);

        expect(action.instancesToSpawn.length, 13);
        
        final spawnedDates = action.instancesToSpawn.map((i) => i.scheduledDate.day).toSet();
        expect(spawnedDates.containsAll([25, 26, 27]), isTrue);
        
        expect(action.updatedSchedule?.lastSpawnedDate, const CivilDay(year: 2026, month: 5, day: 27));
      },
    );
