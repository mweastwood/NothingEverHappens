// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Nunca Pasa Nada';

  @override
  String get errorOccurred => 'Ocurrió un error';

  @override
  String get somethingWentWrong =>
      'Algo salió mal. Por favor comparte este código de error con el desarrollador:';

  @override
  String get details => 'Detalles:';

  @override
  String get close => 'Cerrar';

  @override
  String get pleaseSignInToContinue => 'Por favor inicia sesión para continuar';

  @override
  String get signingIn => 'Iniciando sesión...';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get tasksTab => 'Tareas';

  @override
  String get scheduleTab => 'Calendario';

  @override
  String get dashboardTab => 'Panel';

  @override
  String get capacityPromptTitle => 'Ajusta tu capacidad semanal';

  @override
  String get capacityPromptSubtitle =>
      'Define tus horas disponibles para los próximos días.';

  @override
  String get historyTab => 'Historial';

  @override
  String get addTaskTooltip => 'Agregar Tarea';

  @override
  String get menu => 'Menú';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get editTaskTitle => 'Editar Tarea';

  @override
  String get newTaskTitle => 'Nueva Tarea';

  @override
  String get titleFieldLabel => 'Título';

  @override
  String get titleRequiredError => 'Por favor ingresa un título';

  @override
  String get descriptionFieldLabel => 'Descripción';

  @override
  String get estimatedEffortFieldLabel => 'Esfuerzo Estimado (Minutos)';

  @override
  String get estimatedEffortHelper =>
      'Opcional. Ingresa el tiempo estimado en minutos.';

  @override
  String get estimatedEffortValidationError =>
      'Por favor ingresa un número positivo de minutos';

  @override
  String estimatedEffortLabel(String duration) {
    return 'Esfuerzo Estimado: $duration';
  }

  @override
  String get scheduleHeader => 'Calendario';

  @override
  String get oneOffLabel => 'Única vez';

  @override
  String get dailyLabel => 'Diario';

  @override
  String get weeklyLabel => 'Semanal';

  @override
  String get discardButton => 'Descartar';

  @override
  String get saveButton => 'Guardar';

  @override
  String get selectAtLeastOneDayError =>
      'Por favor selecciona al menos un día de la semana';

  @override
  String get dueLabel => 'Vence: ';

  @override
  String get startLabel => 'Inicio';

  @override
  String get dueWithoutColon => 'Vence';

  @override
  String get dueDescription =>
      '¿Cuándo debe completarse esta tarea antes de considerarse atrasada?';

  @override
  String get advancedHeader => 'Avanzado';

  @override
  String get snoozeUntilLabel => 'Posponer hasta: ';

  @override
  String get snoozeUntilDescription =>
      'La tarea estará oculta de tu lista principal de tareas hasta esta hora.';

  @override
  String get startDateLabel => 'Fecha de inicio';

  @override
  String get intervalLabel => 'Intervalo';

  @override
  String everyNDays(int count) {
    return 'Cada $count días';
  }

  @override
  String everyNDaysSinceLastScheduled(int count) {
    return 'Cada $count día(s) (desde la última programada)';
  }

  @override
  String everyNDaysSinceLastCompletion(int count) {
    return 'Cada $count día(s) (desde el último completado)';
  }

  @override
  String everyNWeeksSinceLastScheduled(int count) {
    return 'Cada $count semana(s) (desde la última programada)';
  }

  @override
  String everyNWeeksSinceLastCompletion(int count) {
    return 'Cada $count semana(s) (desde el último completado)';
  }

  @override
  String get daysIntervalLabel => 'Intervalo de días';

  @override
  String get daysIntervalHelper => 'Ej., 1 para cada día, 2 para días alternos';

  @override
  String get weeksIntervalLabel => 'Intervalo de semanas';

  @override
  String get weeksIntervalHelper => 'Ej., 1 para cada semana';

  @override
  String get repeatsOnLabel => 'Se repite en';

  @override
  String get dailyOccurrencesHeader => 'Ocurrencias Diarias';

  @override
  String get startTimeLabel => 'Hora de inicio';

  @override
  String get dueTimeLabel => 'Hora de vencimiento';

  @override
  String get notificationTimeLabel => 'Hora de notificación';

  @override
  String get noneLabel => 'Ninguna';

  @override
  String get clearNotificationTimeTooltip => 'Borrar hora de notificación';

  @override
  String get removeTimeSlotTooltip => 'Eliminar intervalo de tiempo';

  @override
  String get addTimeSlotButton => 'Agregar intervalo de tiempo';

  @override
  String get noTasksYet => 'No hay tareas aún. ¡Agrega una!';

  @override
  String get noHistoryYet => 'No hay historial aún';

  @override
  String get noRecurringTasksScheduled =>
      'No hay tareas recurrentes programadas';

  @override
  String get copiedToClipboard => 'Tarea copiada al portapapeles';

  @override
  String get deleteTaskConfirmTitle => '¿Eliminar Tarea?';

  @override
  String deleteTaskConfirmBody(String title) {
    return '¿Estás seguro de que quieres eliminar \"$title\"? Esta acción eliminará permanentemente la tarea.';
  }

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get editScheduleTooltip => 'Editar Calendario';

  @override
  String get deleteTaskTooltip => 'Eliminar Tarea';

  @override
  String get dailyRecurrence => 'Diario';

  @override
  String get weeklyRecurrence => 'Semanal';

  @override
  String get everyDay => 'Todos los días';

  @override
  String get everyWeek => 'Cada semana';

  @override
  String everyNWeeks(int count) {
    return 'Cada $count semanas';
  }

  @override
  String startingDate(String date) {
    return 'Comenzando: $date';
  }

  @override
  String onDaysOfWeek(String days) {
    return 'En: $days';
  }

  @override
  String get missedPolicyHeader => 'Política de Ocurrencias Perdidas';

  @override
  String get missedPolicyHelper =>
      'Define qué pasa si una tarea recurrente no se completa a su hora de vencimiento.';

  @override
  String get stackLabel => 'Acumular (Permitir concurrencia)';

  @override
  String get stackDescription =>
      'Las ocurrencias perdidas siguen activas, permitiendo que se acumulen múltiples instancias.';

  @override
  String get monthlyLabel => 'Mensual';

  @override
  String get yearlyLabel => 'Anual';

  @override
  String get repeatingLabel => 'Repetitiva';

  @override
  String get sinceLastScheduledLabel => 'Desde la última programada';

  @override
  String get sinceLastCompletionLabel => 'Desde el último completado';

  @override
  String get intervalTypeLabel => 'Tipo de intervalo';

  @override
  String get startRecurrenceDateLabel => 'Fecha de inicio de recurrencia';

  @override
  String get addNotificationLabel => 'Añadir notificación';

  @override
  String get dayOfMonthLabel => 'Día del Mes';

  @override
  String get nthDayOfWeekLabel => 'N-ésimo Día de la Semana';

  @override
  String get monthlyRecurrenceTypeLabel => 'Regla de Recurrencia';

  @override
  String get monthsIntervalLabel => 'Intervalo de Meses';

  @override
  String get yearsIntervalLabel => 'Intervalo de Años';

  @override
  String get dayOfMonthFieldLabel => 'Día del Mes';

  @override
  String get dayOfMonthValidationError =>
      'Por favor ingresa un número de día válido: 1 a 28';

  @override
  String get monthlyFromStart => 'Desde el inicio del mes';

  @override
  String get monthlyFromEnd => 'Desde el final del mes';

  @override
  String get dayOfMonthStepperLabel => 'Día';

  @override
  String get nthOccurrenceLabel => 'Ocurrencia';

  @override
  String get firstOccurrence => '1ro';

  @override
  String get secondOccurrence => '2do';

  @override
  String get thirdOccurrence => '3ro';

  @override
  String get fourthOccurrence => '4to';

  @override
  String get lastOccurrence => 'Último';

  @override
  String get dayOfWeekLabel => 'Día de la Semana';

  @override
  String get monthLabel => 'Mes';

  @override
  String get dayLabel => 'Día';

  @override
  String get everyMonth => 'Cada mes';

  @override
  String everyNMonths(int count) {
    return 'Cada $count meses';
  }

  @override
  String everyNMonthsSinceLastScheduled(int count) {
    return 'Cada $count meses (desde la última programada)';
  }

  @override
  String everyNMonthsSinceLastCompletion(int count) {
    return 'Cada $count meses (desde el último completado)';
  }

  @override
  String get everyYear => 'Cada año';

  @override
  String everyNYears(int count) {
    return 'Cada $count años';
  }

  @override
  String everyNYearsSinceLastScheduled(int count) {
    return 'Cada $count años (desde la última programada)';
  }

  @override
  String everyNYearsSinceLastCompletion(int count) {
    return 'Cada $count años (desde el último completado)';
  }

  @override
  String dayOfMonthOnDay(Object day) {
    return 'El día $day';
  }

  @override
  String dayOfMonthFromEnd(Object day) {
    return 'El día $day desde el final';
  }

  @override
  String repeatsOnDayOfMonthHelp(Object day) {
    return 'Se repite el día $day del mes.';
  }

  @override
  String repeatsOnDayFromEndHelp(Object day) {
    return 'Se repite el día $day desde el final del mes.';
  }

  @override
  String repeatsOnNthWeekdayHelp(Object dayOfWeek, Object occurrence) {
    return 'Se repite el $occurrence $dayOfWeek del mes.';
  }

  @override
  String nthDayOfWeekOccurrence(Object dayOfWeek, Object occurrence) {
    return 'El $occurrence $dayOfWeek';
  }

  @override
  String yearlyOn(Object day, Object month) {
    return 'En: $month $day';
  }

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get hoursAvailableLabel => 'Horas Disponibles por Día';

  @override
  String get hoursAvailableHelper =>
      'Número de horas disponibles para la programación ágil.';

  @override
  String get hoursAvailableValidationError =>
      'Por favor ingresa un número entre 0 y 24';

  @override
  String get settingsSavedSuccessfully => 'Configuración guardada exitosamente';

  @override
  String get showPendingTasksLabel => 'Mostrar tareas pendientes';

  @override
  String get showPendingTasksHelper =>
      'Mostrar tareas en la lista principal cuya hora de inicio sea en el futuro.';

  @override
  String get showLastSpawnedDateLabel => 'Mostrar fecha de último spawn';

  @override
  String get showLastSpawnedDateHelper =>
      'Mostrar la fecha del último spawn en cada tarjeta de programación de tareas para depuración.';

  @override
  String get pendingBadge => 'Pendiente';

  @override
  String get familyTab => 'Familia';

  @override
  String get familyScreenTitle => 'Familia';

  @override
  String get createFamilyTitle => 'Crear Familia';

  @override
  String get createFamilyButton => 'Crear Familia';

  @override
  String get familyUnitNameLabel => 'Nombre de la Familia';

  @override
  String get inviteMemberButton => 'Invitar Miembro';

  @override
  String get inviteMemberTitle => 'Invitar Miembro de la Familia';

  @override
  String get inviteMemberEmailLabel => 'Dirección de Correo Electrónico';

  @override
  String get inviteMemberRoleLabel => 'Rol';

  @override
  String get parentRole => 'Padre/Madre';

  @override
  String get nonParentRole => 'No Padre/Madre';

  @override
  String get pendingInvitesHeader => 'Invitaciones Pendientes';

  @override
  String get acceptInviteButton => 'Aceptar';

  @override
  String get declineInviteButton => 'Rechazar';

  @override
  String get leaveFamilyButton => 'Salir de la Familia';

  @override
  String get membersHeader => 'Miembros de la Familia';

  @override
  String familyMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get notInFamilyBody =>
      'Actualmente no estás en una unidad familiar. Puedes crear una nueva familia o aceptar una invitación pendiente a continuación.';

  @override
  String get noPendingInvites => 'Sin invitaciones pendientes';

  @override
  String get inviteSentSuccess => 'Invitación enviada exitosamente';

  @override
  String get outstandingInvitesHeader => 'Invitaciones Pendientes Enviadas';

  @override
  String get revokeInviteButton => 'Revocar';

  @override
  String get inviteRevokedSuccess => 'Invitación revocada exitosamente';

  @override
  String get noOutstandingInvites => 'Sin invitaciones pendientes enviadas';

  @override
  String get revokeInviteConfirmTitle => '¿Revocar Invitación?';

  @override
  String revokeInviteConfirmBody(String email) {
    return '¿Estás seguro de que deseas revocar la invitación para $email?';
  }

  @override
  String invitedBy(String name, String email) {
    return 'Invitado por $name ($email)';
  }

  @override
  String get leaveFamilyConfirmTitle => '¿Salir de la Familia?';

  @override
  String get leaveFamilyConfirmBody =>
      '¿Estás seguro de que deseas salir de la familia?';

  @override
  String get taskPriorityLabel => 'Prioridad';

  @override
  String get priorityLow => 'Baja';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get familyTaskLabel => 'Tarea Familiar';

  @override
  String get familyTaskHelper =>
      'Comparte esta tarea con todos los miembros de la familia.';

  @override
  String get viewTaskTitle => 'Ver Tarea';

  @override
  String get onlyParentsCanEditFamilyTasks =>
      'Solo los padres pueden editar tareas familiares';

  @override
  String get sprintDashboardTitle => 'Panel del Sprint';

  @override
  String get autoAllocateButton => 'Asignar Tareas Automáticamente';

  @override
  String get choresAllocatedSuccess =>
      '¡Tareas asignadas automáticamente con éxito!';

  @override
  String get removeFromCycleTooltip => 'Eliminar del ciclo';

  @override
  String get addToCycleTooltip => 'Agregar al ciclo';

  @override
  String get backlogTab => 'Lista de Espera';

  @override
  String get activeCycleTab => 'Ciclo Activo';

  @override
  String get weeklyCapacityLabel => 'Capacidad Semanal';

  @override
  String personalTasksLabel(int effort) {
    return 'Tareas Personales: $effort min';
  }

  @override
  String familyChoresLabel(int effort) {
    return 'Tareas Familiares: $effort min';
  }

  @override
  String remainingCapacityLabel(int effort) {
    return 'Capacidad Restante: $effort min';
  }

  @override
  String get noActiveTasks =>
      'No hay tareas activas en este ciclo. ¡Mueve algunas de la lista de espera!';

  @override
  String get noBacklogTasks => 'No hay tareas en la lista de espera.';

  @override
  String get unassigned => 'Sin asignar';

  @override
  String assignedTo(String name) {
    return 'Asignado a $name';
  }

  @override
  String get starTooltip => 'Alternar preferencia';

  @override
  String get familyCapacityPool => 'Capacidad del Grupo Familiar';

  @override
  String memberRemainingTotal(int remaining, int total) {
    return '$remaining min restantes / $total min en total';
  }

  @override
  String memberPersonalChores(int personal, int family) {
    return 'Personal: $personal min | Tareas Familiares: $family min';
  }

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpTooltip => 'Ayuda';

  @override
  String get helpTabInteractions => 'Completado Básico de Tareas';

  @override
  String get practiceHelpContent =>
      '# Práctica de Completado Básico de Tareas\n\nHay dos formas de completar una tarea:\n\n1. Tocar la casilla de verificación a la izquierda marca la tarea como completada.\n2. Tocar el botón x a la derecha descarta la tarea, indicando que no la completarás (por cualquier motivo).\n\nUsa el espacio a continuación para practicar cómo marcar tareas como completadas o descartadas.';

  @override
  String get helpTabScheduling => 'Planificación de Tareas';

  @override
  String get schedulingPlaygroundHelpContent =>
      '# Práctica de Planificación de Tareas\n\nUsa los controles de abajo para configurar diferentes opciones de planificación en tiempo real.\n\n- El **calendario** resalta los días en que ocurrirá la tarea en un período de 3 meses (actual, siguiente y posterior).\n- La **lista de ocurrencias** muestra las siguientes 10 fechas calculadas.\n\n*Intenta cambiar el intervalo, seleccionar diferentes días de la semana o elegir diferentes opciones mensuales/anuales para ver cómo se actualizan las ocurrencias.*';

  @override
  String occurrenceAppears(String dateTime) {
    return 'Aparece: $dateTime';
  }

  @override
  String occurrenceDue(String dateTime) {
    return 'Vence: $dateTime';
  }

  @override
  String get invalidIntervalError =>
      'Por favor, introduce un intervalo válido mayor que 0';

  @override
  String get occurrencesHeader => 'Próximas 10 Ocurrencias';

  @override
  String get noOccurrencesPlaceholder =>
      'No hay ocurrencias programadas. Asegúrate de que todos los datos sean válidos.';

  @override
  String get pastOccurrencesHeader => 'Últimas 10 ocurrencias';

  @override
  String get noPastOccurrencesPlaceholder => 'No hay ocurrencias pasadas.';

  @override
  String occurrenceCompleted(String dateTime) {
    return 'Completada: $dateTime';
  }

  @override
  String get occurrenceSkipped => 'Omitida';

  @override
  String occurrenceMissed(String dateTime) {
    return 'Atrasada (Vence: $dateTime)';
  }

  @override
  String occurrenceActive(String dateTime) {
    return 'Activa (Vence: $dateTime)';
  }

  @override
  String get visualCalendarGridHeader => 'Cuadrícula de Calendario Visual';

  @override
  String get dayIsRequiredError => 'El día es requerido';

  @override
  String dayMustBeBetweenError(int max) {
    return 'El día debe estar entre 1 y $max';
  }

  @override
  String calculationError(String error) {
    return 'Error de cálculo: $error';
  }

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get weekdayHeaderMonday => 'L';

  @override
  String get weekdayHeaderTuesday => 'M';

  @override
  String get weekdayHeaderWednesday => 'X';

  @override
  String get weekdayHeaderThursday => 'J';

  @override
  String get weekdayHeaderFriday => 'V';

  @override
  String get weekdayHeaderSaturday => 'S';

  @override
  String get weekdayHeaderSunday => 'D';

  @override
  String get monthJanuary => 'Enero';

  @override
  String get monthFebruary => 'Febrero';

  @override
  String get monthMarch => 'Marzo';

  @override
  String get monthApril => 'Abril';

  @override
  String get monthMay => 'Mayo';

  @override
  String get monthJune => 'Junio';

  @override
  String get monthJuly => 'Julio';

  @override
  String get monthAugust => 'Agosto';

  @override
  String get monthSeptember => 'Septiembre';

  @override
  String get monthOctober => 'Octubre';

  @override
  String get monthNovember => 'Noviembre';

  @override
  String get monthDecember => 'Diciembre';

  @override
  String get helpTabMissedPolicies => 'Políticas de Omisión';

  @override
  String get missedPoliciesIntro =>
      '### Políticas de Ocurrencias Perdidas\n\nCuando una tarea recurrente no se completa a su hora de vencimiento, la aplicación aplica una **Política de Ocurrencias Perdidas** para manejar la instancia vencida.\n\nUsa el simulador de abajo para ver cómo cada política maneja las tareas vencidas a lo largo del tiempo.';

  @override
  String get stackSimTip =>
      '### Política de Stack (Acumular)\n\n**Comportamiento:** Las ocurrencias perdidas permanecen activas y generan una instancia de tarea separada para cada día, dejando que se acumulen múltiples instancias. Todas aparecen en tu lista de tareas al mismo tiempo hasta que se completen o descarten.\n\n**Prueba esto:**\n1. Toca **Avanzar 1 Día** 3 veces.\n2. Observa que aparecen 3 tareas independientes en tu lista (una por cada día perdido).\n3. Complétalas o descártacas individualmente para limpiar la acumulación.';

  @override
  String get advanceDayButton => 'Avanzar 1 Día';

  @override
  String get resetSimButton => 'Reiniciar Simulación';

  @override
  String simulatedTodayLabel(String date) {
    return 'Hoy Simulado: $date';
  }

  @override
  String activeTasksHeader(int count) {
    return 'Tareas Simuladas ($count)';
  }

  @override
  String get historyLogHeader => 'Historial de Simulación';

  @override
  String get undoButton => 'Deshacer';

  @override
  String get actionUndone => 'Acción deshecha';

  @override
  String taskCompleted(String title) {
    return '\"$title\" completada';
  }

  @override
  String taskDismissed(String title) {
    return '\"$title\" descartada';
  }

  @override
  String scheduleDeleted(String title) {
    return 'Se eliminó \"$title\"';
  }

  @override
  String taskEditsSaved(String title) {
    return 'Se guardó \"$title\"';
  }

  @override
  String taskRestored(String title) {
    return '\"$title\" restaurada';
  }

  @override
  String editsReverted(String title) {
    return 'Se deshicieron los cambios en \"$title\"';
  }

  @override
  String dueTodayAt(String time) {
    return 'Vence hoy a las $time';
  }

  @override
  String overdueTodayAt(String time) {
    return 'Atrasado: hoy a las $time';
  }

  @override
  String overdueYesterdayAt(String time) {
    return 'Atrasado: ayer a las $time';
  }

  @override
  String dueTomorrowAt(String time) {
    return 'Vence mañana a las $time';
  }

  @override
  String dueAt(String date, String time) {
    return 'Vence el $date a las $time';
  }

  @override
  String overdueAt(String date, String time) {
    return 'Atrasado: el $date a las $time';
  }

  @override
  String get loadingBadge => 'Cargando...';

  @override
  String get assignedBadge => 'Asignado';

  @override
  String get recurringLabel => 'Recurrente';

  @override
  String get searchTasksPlaceholder => 'Buscar tareas...';

  @override
  String noTasksMatching(String query) {
    return 'No se encontraron tareas coincidentes para \"$query\"';
  }

  @override
  String get clearSearchButton => 'Limpiar búsqueda';

  @override
  String get presetWeekdays => 'Entre semana';

  @override
  String get presetWeekends => 'Fin de semana';

  @override
  String get presetAll => 'Todos';

  @override
  String get presetClear => 'Limpiar';

  @override
  String get presetMonthSingular => 'mes';

  @override
  String get presetMonthPlural => 'meses';

  @override
  String get presetYearSingular => 'año';

  @override
  String get presetYearPlural => 'años';

  @override
  String get scheduleSortByLabel => 'Ordenar por';

  @override
  String get scheduleGridTypeHeader => 'Tipo';

  @override
  String get scheduleSortNextStartLabel => 'Próximo Inicio';

  @override
  String get scheduleSortNextDueLabel => 'Próximo Vencimiento';

  @override
  String get scheduleGridTimeWindowHeader => 'Horario';

  @override
  String get scheduleGridActionsHeader => 'Acciones';

  @override
  String get searchSchedulesPlaceholder => 'Buscar horarios...';

  @override
  String noSchedulesMatching(String query) {
    return 'No se encontraron horarios coincidentes para \"$query\"';
  }

  @override
  String get scheduleRequiredError => 'Se requiere al menos un horario.';

  @override
  String get capacityDependentEffortRequiredError =>
      'El esfuerzo estimado es obligatorio para tareas dependientes de capacidad.';

  @override
  String get familyTaskToggleLabel => 'Tarea Familiar';

  @override
  String get personalTaskToggleLabel => 'Tarea Personal';

  @override
  String get effortAndPriorityLabel => 'Esfuerzo y Prioridad';

  @override
  String get addScheduleButton => 'Agregar Horario';

  @override
  String get saveTimeoutError =>
      'La operación de guardado expiró. Por favor, verifique su conexión.';

  @override
  String get hoursSuffix => 'horas';

  @override
  String get futureOccurrencesLabel => 'Próximas Ocurrencias';

  @override
  String get preCreatedFutureTasksHelper =>
      'Tareas futuras creadas previamente (1-10)';

  @override
  String get resetPracticeButton => 'Restablecer Práctica';

  @override
  String practiceTasksRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tareas de práctica ($count restantes)',
      one: 'Tareas de práctica (1 restante)',
    );
    return '$_temp0';
  }

  @override
  String get practiceTasksCompleted =>
      '¡Todas las tareas han sido completadas o descartadas!';

  @override
  String get practiceTasksResetPrompt =>
      'Toque \"Restablecer Práctica\" para intentar de nuevo.';

  @override
  String get unitLabel => 'Unidad';

  @override
  String get unitHours => 'Hora(s)';

  @override
  String get unitDays => 'Día(s)';

  @override
  String get unitWeeks => 'Semana(s)';

  @override
  String get unitMinutes => 'Minuto(s)';

  @override
  String get targetStartTimeLabel => 'Hora de Inicio Objetivo';

  @override
  String get selectMissedPolicyTitle =>
      'Seleccione la Política de Ocurrencia Omitida';

  @override
  String get immediatelyPolicy => 'Inmediatamente';

  @override
  String get oneHourPolicy => '1 Hora';

  @override
  String get sixHoursPolicy => '6 Horas';

  @override
  String get twelveHoursPolicy => '12 Horas';

  @override
  String get twentyFourHoursPolicy => '24 Horas (1 Día)';

  @override
  String get customDurationPolicy => 'Duración Personalizada...';

  @override
  String get addNotificationButton => 'Agregar notificación';

  @override
  String get selectDayTitle => 'Seleccionar Día';

  @override
  String get okButton => 'Aceptar';

  @override
  String get fixedCalendarLabel => 'Calendario Fijo';

  @override
  String get completionRelativeLabel => 'Relativo al Cumplimiento';

  @override
  String get capacityDependentLabel => 'Dependiente de Capacidad';

  @override
  String get capacityDependentTitle => 'Basado en la capacidad restante';

  @override
  String get capacityDependentSubtitle =>
      'Programado solo si la capacidad lo permite, de lo contrario se pospone día a día';

  @override
  String get taskTypeLabel => 'Tipo de Tarea';

  @override
  String get simulationPresetDaily =>
      'Preestablecido Diario (Alimentar Mascotas)';

  @override
  String get simulationPresetWeekly =>
      'Preestablecido Semanal (Cortar el Césped)';

  @override
  String simulatedTimeLabel(String time) {
    return 'Tiempo Simulado: $time';
  }

  @override
  String get simulationOneHour => '1 Hora';

  @override
  String get simulationSixHours => '6 Horas';

  @override
  String get simulationTwentyFourHours => '24 Horas';

  @override
  String get noActivePlaygroundTasks => 'No hay tareas activas.';

  @override
  String autoDismissPolicyHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get missedPolicyDialogIntro =>
      'En los ejemplos que se muestran a continuación, suponga que tenemos una tarea diaria que no completamos, marcamos ni descartamos de ninguna manera el lunes o el martes. Ahora es miércoles, ¿qué se debe hacer con las tareas anteriores?';

  @override
  String get dismissAfterLabel => 'Descartar Después De';

  @override
  String get durationLabel => 'Duración';

  @override
  String get presetsLabel => 'Preestablecidos';

  @override
  String get presetDaySingular => 'día';

  @override
  String get presetDayPlural => 'días';

  @override
  String get presetWeekSingular => 'semana';

  @override
  String get presetWeekPlural => 'semanas';

  @override
  String get taskAppearanceHelpText =>
      '¿Cuándo aparece la tarea en tu lista de tareas?';

  @override
  String get enableNotificationReminderLabel =>
      'Activar recordatorio de notificación';

  @override
  String get notificationWindowLabel => 'Ventana de notificación';

  @override
  String get repeatIntervalLabel => 'Intervalo de repetición';

  @override
  String completionRelativeSummary(String val, String unit, String time) {
    return 'Relativo a la finalización: cada $val $unit @ $time';
  }

  @override
  String oneOffSummary(String date) {
    return 'Única vez el $date';
  }

  @override
  String dailySummary(String count) {
    return 'Diario, cada $count día(s)';
  }

  @override
  String weeklySummary(String count, String days) {
    return 'Semanal, cada $count semana(s) los $days';
  }

  @override
  String monthlySummaryDay(String count, String day) {
    return 'Mensual, cada $count mes(es) el día $day';
  }

  @override
  String monthlySummaryNth(String count, String occurrence, String weekday) {
    return 'Mensual, cada $count mes(es) el $occurrence $weekday';
  }

  @override
  String yearlySummary(String count, String month, String day) {
    return 'Anual, cada $count año(s) el $day de $month';
  }

  @override
  String get customScheduleSummary => 'Programación personalizada';

  @override
  String get deleteScheduleTooltip => 'Eliminar programación';

  @override
  String get weekdayShortMonday => 'Lun';

  @override
  String get weekdayShortTuesday => 'Mar';

  @override
  String get weekdayShortWednesday => 'Mié';

  @override
  String get weekdayShortThursday => 'Jue';

  @override
  String get weekdayShortFriday => 'Vie';

  @override
  String get weekdayShortSaturday => 'Sáb';

  @override
  String get weekdayShortSunday => 'Dom';

  @override
  String get monthShortJanuary => 'Ene';

  @override
  String get monthShortFebruary => 'Feb';

  @override
  String get monthShortMarch => 'Mar';

  @override
  String get monthShortApril => 'Abr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJune => 'Jun';

  @override
  String get monthShortJuly => 'Jul';

  @override
  String get monthShortAugust => 'Ago';

  @override
  String get monthShortSeptember => 'Sep';

  @override
  String get monthShortOctober => 'Oct';

  @override
  String get monthShortNovember => 'Nov';

  @override
  String get monthShortDecember => 'Dic';

  @override
  String completionRelativeHelpDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días después de que la tarea se completó por última vez.',
      one: '1 día después de que la tarea se completó por última vez.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count semanas después de que la tarea se completó por última vez.',
      one: '1 semana después de que la tarea se completó por última vez.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses después de que la tarea se completó por última vez.',
      one: '1 mes después de que la tarea se completó por última vez.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpYearly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años después de que la tarea se completó por última vez.',
      one: '1 año después de que la tarea se completó por última vez.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryDayHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se repite cada $count días a partir del $date.',
      one: 'Se repite cada día a partir del $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryWeekHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se repite cada $count semanas a partir del $date.',
      one: 'Se repite cada semana a partir del $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryMonthHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se repite cada $count meses a partir del $date.',
      one: 'Se repite cada mes a partir del $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryYearHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se repite cada $count años a partir del $date.',
      one: 'Se repite cada año a partir del $date.',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceTypeHeader => 'TIPO DE RECURRENCIA';

  @override
  String get dailyFixedTitle => 'En un horario fijo';

  @override
  String get dailyFixedSubtitle =>
      'Se repite cada N días desde la última programada (ej. cada 3 días)';

  @override
  String get dailyCompletionRelativeTitle => 'Basado en el último completado';

  @override
  String get dailyCompletionRelativeSubtitle =>
      'Se repite N días después de terminarlo (ej. 3 días después de completarlo)';

  @override
  String get weeklyFixedTitle => 'En días fijos de la semana';

  @override
  String get weeklyFixedSubtitle =>
      'Se repite en días específicos de la semana (ej. todos los lunes y viernes)';

  @override
  String get weeklyCompletionRelativeTitle => 'Basado en el último completado';

  @override
  String get weeklyCompletionRelativeSubtitle =>
      'Se repite N semanas después de terminarlo (ej. 2 semanas después de completarlo)';

  @override
  String get monthlyFixedDayTitle => 'En un día fijo del mes';

  @override
  String get monthlyFixedDaySubtitle =>
      'Se repite en un día calendario específico (ej. el día 15 del mes)';

  @override
  String get monthlyNthWeekdayTitle =>
      'En un día de la semana específico del mes';

  @override
  String get monthlyNthWeekdaySubtitle =>
      'Se repite en un día de la semana relativo (ej. el segundo martes)';

  @override
  String get monthlyCompletionRelativeTitle => 'Basado en el último completado';

  @override
  String get monthlyCompletionRelativeSubtitle =>
      'Se repite N meses después de terminarlo (ej. 1 mes después de completarlo)';

  @override
  String get yearlyFixedTitle => 'En una fecha fija del año';

  @override
  String get yearlyFixedSubtitle =>
      'Se repite en una fecha calendario específica (ej. cada 12 de octubre)';

  @override
  String get yearlyCompletionRelativeTitle => 'Basado en el último completado';

  @override
  String get yearlyCompletionRelativeSubtitle =>
      'Se repite N años después de terminarlo (ej. 1 año después de completarlo)';

  @override
  String get dayOfLabel => 'Mismo día';

  @override
  String get timeLabel => 'Hora';

  @override
  String get adjustOffsetLabel => 'Ajustar desfase';

  @override
  String get oneDayAfterLabel => '1 día después';

  @override
  String get oneDayBeforeLabel => '1 día antes';

  @override
  String nDaysLaterLabel(int count) {
    return '$count días después';
  }

  @override
  String nDaysBeforeLabel(int count) {
    return '$count días antes';
  }

  @override
  String get familyNameRequiredError =>
      'Por favor ingresa un nombre de familia';

  @override
  String get emailRequiredError =>
      'Por favor ingresa una dirección de correo electrónico';

  @override
  String get emailInvalidError =>
      'Por favor ingresa una dirección de correo electrónico válida';

  @override
  String get practiceTaskTitle0 => 'Regar las plantas de interior';

  @override
  String get practiceTaskDesc0 => 'Dales la cantidad justa de agua.';

  @override
  String get practiceTaskTitle1 => 'Sacar la basura';

  @override
  String get practiceTaskDesc1 => 'No olvides el reciclaje.';

  @override
  String get practiceTaskTitle2 => 'Lavar los platos';

  @override
  String get practiceTaskDesc2 => 'Limpia las ollas y sartenes primero.';

  @override
  String get practiceTaskTitle3 => 'Cortar el césped';

  @override
  String get practiceTaskDesc3 => 'Recorta los bordes también.';

  @override
  String get practiceTaskTitle4 => 'Alimentar al perro';

  @override
  String get practiceTaskDesc4 => 'Asegúrate de que tenga agua fresca.';

  @override
  String get practiceTaskTitle5 => 'Aspirar la sala';

  @override
  String get practiceTaskDesc5 => 'Pasa la aspiradora debajo del sofá.';

  @override
  String get practiceTaskTitle6 => 'Limpiar el ático';

  @override
  String get practiceTaskDesc6 => 'Ordena las cajas viejas.';

  @override
  String get practiceTaskTitle7 => 'Doblar la ropa';

  @override
  String get practiceTaskDesc7 => 'Dóblala cuidadosamente y guárdala.';

  @override
  String get practiceTaskTitle8 => 'Sacudir los estantes';

  @override
  String get practiceTaskDesc8 => 'Usa un paño de microfibra.';

  @override
  String get practiceTaskTitle9 => 'Comprar comida';

  @override
  String get practiceTaskDesc9 => 'Leche, huevos y pan.';

  @override
  String get preferNewerTitle => 'Preferir más nueva';

  @override
  String get preferNewerDesc =>
      'Solo la última ocurrencia permanece activa. Las ocurrencias omitidas anteriores se saltan automáticamente para que pueda comenzar de nuevo.';

  @override
  String get preferOlderTitle => 'Preferir más antigua';

  @override
  String get preferOlderDesc =>
      'Solo la ocurrencia inacabada más antigua permanece activa. Las ocurrencias posteriores se saltan hasta que se complete.';

  @override
  String get stackPolicyTitle => 'Acumular';

  @override
  String get stackPolicyDesc =>
      'Mantener todas las ocurrencias activas. Las ocurrencias omitidas se acumulan en una lista de espera y deben completarse individualmente.';

  @override
  String get autoDismissPolicyTitle => 'Descarte automático';

  @override
  String get autoDismissPolicyDesc =>
      'Las ocurrencias se acumulan pero se descartan/saltan automáticamente después de un período de gracia configurable.';

  @override
  String get monShort => 'Lun';

  @override
  String get tueShort => 'Mar';

  @override
  String get wedTodayShort => 'Mié (Hoy)';

  @override
  String get activeLabel => 'Activa';

  @override
  String get expiredLabel => 'Vencida';

  @override
  String get skippedLabel => 'Omitida';

  @override
  String get pastTabLabel => 'Pasadas';

  @override
  String get currentTabLabel => 'Actuales';

  @override
  String get futureTabLabel => 'Futuras';

  @override
  String get noCurrentOccurrencesPlaceholder => 'No hay ocurrencias activas.';

  @override
  String get skipIfNoCapacityLabel => 'Omitir si se supera la capacidad';

  @override
  String get skipIfNoCapacityHelper =>
      'Omitir esta ocurrencia de la tarea si se supera la capacidad diaria disponible';
}
