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
  String get scheduleHeader => 'Calendario';

  @override
  String get oneOffLabel => 'Una vez';

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
  String everyNDays(int count) {
    return 'Cada $count días';
  }

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
  String get rolloverLabel => 'Reasignar (Pasar al día siguiente)';

  @override
  String get rolloverDescription =>
      'La tarea atrasada se pasa a hoy y sigue atrasada hasta que se complete.';

  @override
  String get skipLabel => 'Omitir (Descartar ocurrencia)';

  @override
  String get skipDescription =>
      'La tarea atrasada se omite automáticamente, se registra en el historial y se reprograma.';

  @override
  String get shiftLabel => 'Cambiar calendario (Retrasar fechas futuras)';

  @override
  String get shiftDescription =>
      'La siguiente ocurrencia se calcula en relación a cuándo se completó tarde la tarea.';

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
  String get dayOfMonthFieldLabel => 'Día del Mes (1-28, o -1 a -28)';

  @override
  String get dayOfMonthValidationError =>
      'Por favor ingresa un número de día válido: 1 a 28, o -1 a -28';

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
  String get everyYear => 'Cada año';

  @override
  String everyNYears(int count) {
    return 'Cada $count años';
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
  String get notInFamilyBody =>
      'Actualmente no estás en una unidad familiar. Puedes crear una nueva familia o aceptar una invitación pendiente a continuación.';

  @override
  String get noPendingInvites => 'Sin invitaciones pendientes';

  @override
  String get inviteSentSuccess => 'Invitación enviada exitosamente';

  @override
  String invitedBy(String name, String email) {
    return 'Invitado por $name ($email)';
  }

  @override
  String get leaveFamilyConfirmTitle => '¿Salir de la Familia?';

  @override
  String get leaveFamilyConfirmBody =>
      '¿Estás seguro de que deseas salir de la familia?';
}
