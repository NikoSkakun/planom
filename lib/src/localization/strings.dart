import 'package:flutter/widgets.dart';

/// Supported app locales. The order here is also the order shown in the
/// language picker.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('uk'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
  Locale('it'),
  Locale('pt'),
  Locale('ru'),
  Locale('zh'),
  Locale('ja'),
];

/// Display name for each supported language, in its own language.
const Map<String, String> kLanguageNames = {
  'en': 'English',
  'uk': 'Українська',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'ru': 'Русский',
  'zh': '中文',
  'ja': '日本語',
};

/// Resolves a locale string (`en`, `uk`, etc.) to a [Locale]. Falls back to
/// English if the code is unknown.
Locale localeFromCode(String? code) {
  if (code == null) return const Locale('en');
  for (final l in kSupportedLocales) {
    if (l.languageCode == code) return l;
  }
  return const Locale('en');
}

/// Localized string lookup. Use [S.of] to retrieve the instance for the
/// current locale and access individual keys via the named getters below.
class S {
  S(this.locale);

  final Locale locale;

  static S of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    assert(() {
      _debugReportMissingKeys();
      return true;
    }());
    return S(locale);
  }

  String t(String key) {
    final table = _translations[locale.languageCode] ?? _translations['en']!;
    return table[key] ?? _translations['en']![key] ?? key;
  }

  static bool _completenessChecked = false;

  /// Debug-only: logs any locale whose table is missing keys that exist in
  /// English. Such keys silently fall back to English at runtime (see [t]), so
  /// without this they slip past QA unnoticed. Runs once; no release-mode cost
  /// because the call site is wrapped in an `assert`.
  static void _debugReportMissingKeys() {
    if (_completenessChecked) return;
    _completenessChecked = true;
    final en = _translations['en']!;
    _translations.forEach((code, table) {
      if (code == 'en') return;
      final missing = en.keys.where((k) => !table.containsKey(k)).toList();
      if (missing.isNotEmpty) {
        debugPrint(
            '[i18n] "$code" missing ${missing.length} key(s): ${missing.join(', ')}');
      }
    });
  }

  // ── Common ────────────────────────────────────────────────────────────────
  String get appTitle => t('appTitle');
  String get a11yToggleComplete => t('a11yToggleComplete');
  String get cancel => t('cancel');
  String get done => t('done');
  String get ok => t('ok');
  String get add => t('add');
  String get create => t('create');
  String get save => t('save');
  String get delete => t('delete');
  String get deleteAll => t('deleteAll');
  String get edit => t('edit');
  String get rename => t('rename');
  String get confirm => t('confirm');
  String get insert => t('insert');
  String get move => t('move');
  String get putBack => t('putBack');
  String get clear => t('clear');
  String get untitled => t('untitled');

  // ── Tabs ──────────────────────────────────────────────────────────────────
  String get tabTasks => t('tabTasks');
  String get tabNotes => t('tabNotes');
  String get tabCalendar => t('tabCalendar');
  String get tabRoutines => t('tabRoutines');
  String get tabSettings => t('tabSettings');

  // ── Smart lists ───────────────────────────────────────────────────────────
  String get inbox => t('inbox');
  String get today => t('today');
  String get yesterday => t('yesterday');
  String get tomorrow => t('tomorrow');
  String get upcoming => t('upcoming');
  String get completed => t('completed');
  String get trash => t('trash');

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settings => t('settings');
  String get sectionAppearance => t('sectionAppearance');
  String get themeLight => t('themeLight');
  String get themeSystem => t('themeSystem');
  String get themeDark => t('themeDark');
  String get theme => t('theme');
  String get accentColor => t('accentColor');
  String get completionColor => t('completionColor');
  String get sectionSmartLists => t('sectionSmartLists');
  String get sectionCustomization => t('sectionCustomization');
  String get tabBar => t('tabBar');
  String get sectionLanguage => t('sectionLanguage');
  String get language => t('language');
  String get font => t('font');
  String get searchFonts => t('searchFonts');
  String get systemFont => t('systemFont');
  String get fontOfflineWarning => t('fontOfflineWarning');
  String get editPreviewText => t('editPreviewText');
  String get previewText => t('previewText');
  String get sectionData => t('sectionData');
  String get exportBackup => t('exportBackup');
  String get importBackup => t('importBackup');
  String get exportBackupSublabel => t('exportBackupSublabel');
  String get importBackupSublabel => t('importBackupSublabel');
  String get display => t('display');
  String get hideLabels => t('hideLabels');
  String get visibleTabs => t('visibleTabs');
  String get settingsAccessibleHint => t('settingsAccessibleHint');
  String get startup => t('startup');
  String get defaultTab => t('defaultTab');
  String get lastOpenedTab => t('lastOpenedTab');
  String get visibility => t('visibility');
  String get visibilityShow => t('visibilityShow');
  String get visibilityIfNotEmpty => t('visibilityIfNotEmpty');
  String get visibilityHidden => t('visibilityHidden');
  String get visibilityAlwaysShown => t('visibilityAlwaysShown');
  String get replaceAllData => t('replaceAllData');
  String get replaceAllDataBody => t('replaceAllDataBody');
  String get importSuccessful => t('importSuccessful');
  String get importSuccessfulBody => t('importSuccessfulBody');
  String get importFailed => t('importFailed');
  String get importFailedInvalid => t('importFailedInvalid');
  String get importFailedRead => t('importFailedRead');
  String get exportFailed => t('exportFailed');
  String get exportFailedBody => t('exportFailedBody');
  String get newSpace => t('newSpace');
  String get spaceName => t('spaceName');
  String get deleteSpace => t('deleteSpace');
  String get deleteSpaceBody => t('deleteSpaceBody');

  // ── Security ──────────────────────────────────────────────────────────────
  String get sectionSecurity => t('sectionSecurity');
  String get appLock => t('appLock');
  String get enableLock => t('enableLock');
  String get changeLock => t('changeLock');
  String get removeLock => t('removeLock');
  String get lockType => t('lockType');
  String get lockTypePin4 => t('lockTypePin4');
  String get lockTypePin5 => t('lockTypePin5');
  String get lockTypePin6 => t('lockTypePin6');
  String get lockTypePin7 => t('lockTypePin7');
  String get lockTypePin8 => t('lockTypePin8');
  String get lockTypeCustom => t('lockTypeCustom');
  String get enterPassword => t('enterPassword');
  String get enterNewPassword => t('enterNewPassword');
  String get confirmPassword => t('confirmPassword');
  String get confirmNewPassword => t('confirmNewPassword');
  String get currentPassword => t('currentPassword');
  String get wrongPassword => t('wrongPassword');
  String get passwordsDoNotMatch => t('passwordsDoNotMatch');
  String get forgotPasswordHint => t('forgotPasswordHint');
  String get lockEnabled => t('lockEnabled');
  String get lockDisabled => t('lockDisabled');
  String get verifyToDisable => t('verifyToDisable');
  String get verifyToChange => t('verifyToChange');

  // ── Notifications ─────────────────────────────────────────────────────────
  String get sectionNotifications => t('sectionNotifications');
  String get notificationsEnabled => t('notificationsEnabled');
  String get notificationsPermissionHint => t('notificationsPermissionHint');
  String get reminders => t('reminders');
  String get noReminders => t('noReminders');
  String get reminderAtTime => t('reminderAtTime');
  String get reminder5MinBefore => t('reminder5MinBefore');
  String get reminder10MinBefore => t('reminder10MinBefore');
  String get reminder15MinBefore => t('reminder15MinBefore');
  String get reminder30MinBefore => t('reminder30MinBefore');
  String get reminder1HBefore => t('reminder1HBefore');
  String get reminder2HBefore => t('reminder2HBefore');
  String get reminder1DBefore => t('reminder1DBefore');
  String get reminder1HAfter => t('reminder1HAfter');
  String get reminder1DAfter => t('reminder1DAfter');
  String get reminderCustomBefore => t('reminderCustomBefore');
  String get reminderCustomAfter => t('reminderCustomAfter');

  // ── Data reset ────────────────────────────────────────────────────────────
  String get resetAllData => t('resetAllData');
  String get resetAllDataQuestion => t('resetAllDataQuestion');
  String get resetAllDataBody => t('resetAllDataBody');

  // ── Tasks ─────────────────────────────────────────────────────────────────
  String get sortTasks => t('sortTasks');
  String get sortDefault => t('sortDefault');
  String get sortByCreation => t('sortByCreation');
  String get sortByName => t('sortByName');
  String get sortByPriority => t('sortByPriority');
  String get sortByDateTime => t('sortByDateTime');
  String get addToCalendar => t('addToCalendar');
  String get taskOption => t('taskOption');
  String get eventOption => t('eventOption');
  String get noTasks => t('noTasks');
  String get noTasksForToday => t('noTasksForToday');
  String get noUpcomingTasks => t('noUpcomingTasks');
  String get noCompletedTasks => t('noCompletedTasks');
  String get noItems => t('noItems');
  String get noNotes => t('noNotes');
  String get noListsInFolder => t('noListsInFolder');
  String get trashIsEmpty => t('trashIsEmpty');
  String get emptyTrash => t('emptyTrash');
  String get emptyTrashQuestion => t('emptyTrashQuestion');
  String get emptyTrashBody => t('emptyTrashBody');
  String get cannotBeUndone => t('cannotBeUndone');
  String get moveToTrashAction => t('moveToTrashAction');
  String get moveToTrashFolderBody => t('moveToTrashFolderBody');
  String get moveToTrashListBody => t('moveToTrashListBody');
  String get moveToTrashItemBody => t('moveToTrashItemBody');
  String get taskName => t('taskName');
  String get eventName => t('eventName');
  String get note => t('note');
  String get subtasks => t('subtasks');
  String get addSubtask => t('addSubtask');
  String get tags => t('tags');
  String get noTags => t('noTags');
  String get addTag => t('addTag');
  String get createTag => t('createTag');
  String get searchOrCreateTag => t('searchOrCreateTag');
  String get title => t('title');
  String get folderName => t('folderName');
  String get listName => t('listName');
  String get routineName => t('routineName');
  String get duration => t('duration');
  String get noDuration => t('noDuration');
  String get noDate => t('noDate');
  String get setTime => t('setTime');
  String get dateLabel => t('dateLabel');
  String get priority => t('priority');
  String get noFolder => t('noFolder');
  String get current => t('current');
  String get moveTo => t('moveTo');
  String get info => t('info');
  String get created => t('created');
  String get modified => t('modified');
  String get completedLabel => t('completedLabel');
  String get priorityNone => t('priorityNone');
  String get priorityLow => t('priorityLow');
  String get priorityMed => t('priorityMed');
  String get priorityHigh => t('priorityHigh');
  String get changeIcon => t('changeIcon');
  String get changeColor => t('changeColor');
  String get listColor => t('listColor');
  String get customColor => t('customColor');
  String get selectColor => t('selectColor');
  String get otherDots => t('otherDots');
  String get chooseIcon => t('chooseIcon');
  String get opening => t('opening');
  String get chooseFromLibrary => t('chooseFromLibrary');
  String get createFolder => t('createFolder');
  String get createList => t('createList');
  String get folder => t('folder');
  String get list => t('list');

  // ── Routines ──────────────────────────────────────────────────────────────
  String get newRoutine => t('newRoutine');
  String get editRoutine => t('editRoutine');
  String get sectionFrequency => t('sectionFrequency');
  String get freqDaily => t('freqDaily');
  String get freqDaysAfter => t('freqDaysAfter');
  String get daysAfterCompletion => t('daysAfterCompletion');
  String get autoReset => t('autoReset');
  String get autoResetEveryDay => t('autoResetEveryDay');
  String get autoResetNone => t('autoResetNone');
  String get sectionGoal => t('sectionGoal');
  String get goalAchieveAll => t('goalAchieveAll');
  String get goalCertainAmount => t('goalCertainAmount');
  String get dailyGoal => t('dailyGoal');
  String get recordPerTap => t('recordPerTap');
  String get unitName => t('unitName');
  String get unitEgGlass => t('unitEgGlass');
  String get noRoutinesToday => t('noRoutinesToday');
  String get noRoutinesYet => t('noRoutinesYet');
  String get tapPlusFirstAdd => t('tapPlusFirstAdd');
  String get tapPlusFirstCreate => t('tapPlusFirstCreate');
  String get routinesToday => t('routinesToday');
  String get routinesAll => t('routinesAll');
  String get routinesTodaySection => t('routinesTodaySection');
  String get deleteRoutine => t('deleteRoutine');
  String get deleteRoutineBody => t('deleteRoutineBody');
  String get everyDayLabel => t('everyDayLabel');
  String get chooseUnit => t('chooseUnit');
  String get customDots => t('customDots');

  // ── Calendar ──────────────────────────────────────────────────────────────
  String get noTasksOrEvents => t('noTasksOrEvents');
  String get deleteEventQuestion => t('deleteEventQuestion');
  String get deleteEventBody => t('deleteEventBody');

  // ── Markdown toolbar ──────────────────────────────────────────────────────
  String get insertLink => t('insertLink');
  String get insertLinkTextPlaceholder => t('insertLinkTextPlaceholder');

  // ── Parameterized helpers ────────────────────────────────────────────────
  String moveToTrashQuestion(String name) =>
      t('moveToTrashQuestion').replaceAll('{name}', name);
  String restoreQuestion(String name) =>
      t('restoreQuestion').replaceAll('{name}', name);
  String restoreBody(String destination) =>
      t('restoreBody').replaceAll('{destination}', destination);
  String deletePermanentlyQuestion(String name) =>
      t('deletePermanentlyQuestion').replaceAll('{name}', name);
  String deleteRoutineConfirm(String name) =>
      t('deleteRoutineConfirm').replaceAll('{name}', name);
  String daysAfterCount(int days) =>
      t(days == 1 ? 'dayAfterCompletion' : 'daysAfterCompletionN')
          .replaceAll('{n}', '$days');
}

// ── Localized weekday / month names (short + long) ───────────────────────────

const Map<String, List<String>> kWeekdaysShort = {
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'uk': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
  'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
  'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
  'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
  'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
  'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
  'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  'zh': ['一', '二', '三', '四', '五', '六', '日'],
  'ja': ['月', '火', '水', '木', '金', '土', '日'],
};

const Map<String, List<String>> kWeekdaysLong = {
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'uk': ['Понеділок', 'Вівторок', 'Середа', 'Четвер', "П'ятниця", 'Субота', 'Неділя'],
  'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
  'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
  'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
  'it': ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'],
  'pt': ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'],
  'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
  'zh': ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
  'ja': ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'],
};

const Map<String, List<String>> kMonthsShort = {
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'uk': ['Січ', 'Лют', 'Бер', 'Кві', 'Тра', 'Чер', 'Лип', 'Сер', 'Вер', 'Жов', 'Лис', 'Гру'],
  'es': ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'],
  'fr': ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'],
  'de': ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'],
  'it': ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'],
  'pt': ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'],
  'ru': ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'],
  'zh': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
  'ja': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
};

const Map<String, List<String>> kMonthsLong = {
  'en': ['January', 'February', 'March', 'April', 'May', 'June',
         'July', 'August', 'September', 'October', 'November', 'December'],
  'uk': ['Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
         'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень'],
  'es': ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
         'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'],
  'fr': ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
         'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'],
  'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
         'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
  'it': ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
         'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'],
  'pt': ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
         'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'],
  'ru': ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
         'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
  'zh': ['一月', '二月', '三月', '四月', '五月', '六月',
         '七月', '八月', '九月', '十月', '十一月', '十二月'],
  'ja': ['1月', '2月', '3月', '4月', '5月', '6月',
         '7月', '8月', '9月', '10月', '11月', '12月'],
};

List<String> weekdaysShort(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  return kWeekdaysShort[code] ?? kWeekdaysShort['en']!;
}

List<String> weekdaysLong(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  return kWeekdaysLong[code] ?? kWeekdaysLong['en']!;
}

List<String> monthsShort(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  return kMonthsShort[code] ?? kMonthsShort['en']!;
}

List<String> monthsLong(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  return kMonthsLong[code] ?? kMonthsLong['en']!;
}

// ── Translation tables ───────────────────────────────────────────────────────

const Map<String, Map<String, String>> _translations = {
  'en': _en,
  'uk': _uk,
  'es': _es,
  'fr': _fr,
  'de': _de,
  'it': _it,
  'pt': _pt,
  'ru': _ru,
  'zh': _zh,
  'ja': _ja,
};

const Map<String, String> _en = {
  'appTitle': 'planom',
  'cancel': 'Cancel', 'done': 'Done', 'ok': 'OK', 'add': 'Add',
  'create': 'Create', 'save': 'Save', 'delete': 'Delete', 'deleteAll': 'Delete All',
  'edit': 'Edit', 'rename': 'Rename', 'confirm': 'Confirm', 'insert': 'Insert',
  'move': 'Move', 'putBack': 'Put Back', 'clear': 'Clear', 'untitled': 'Untitled',
  'tabTasks': 'Tasks', 'tabNotes': 'Notes', 'tabCalendar': 'Calendar',
  'tabRoutines': 'Routines', 'tabSettings': 'Settings',
  'inbox': 'Inbox', 'today': 'Today', 'yesterday': 'Yesterday', 'tomorrow': 'Tomorrow', 'upcoming': 'Upcoming',
  'completed': 'Completed', 'trash': 'Trash',
  'settings': 'Settings',
  'sectionAppearance': 'Appearance', 'themeLight': 'Light',
  'themeSystem': 'System', 'themeDark': 'Dark',
  'theme': 'Theme', 'accentColor': 'Accent Color', 'completionColor': 'Completion Color',
  'sectionSmartLists': 'Smart Lists', 'sectionCustomization': 'Customization',
  'tabBar': 'Tab Bar', 'sectionLanguage': 'Language', 'language': 'Language', 'font': 'Font', 'searchFonts': 'Search fonts', 'systemFont': 'System', 'fontOfflineWarning': 'Offline — only cached fonts show previews', 'editPreviewText': 'Edit Preview Text', 'previewText': 'Preview Text',
  'sectionData': 'Data',
  'exportBackup': 'Export Backup', 'importBackup': 'Import Backup',
  'exportBackupSublabel': 'Planom (.planom) · full restore',
  'importBackupSublabel': 'Planom (.planom) · replaces all data',
  'display': 'Display', 'hideLabels': 'Hide Labels', 'visibleTabs': 'Visible Tabs',
  'settingsAccessibleHint': 'Settings is accessible from the options menu (⋯) in every other tab.',
  'startup': 'Startup', 'defaultTab': 'Default Tab', 'lastOpenedTab': 'Last Opened',
  'visibility': 'Visibility',
  'visibilityShow': 'Show', 'visibilityIfNotEmpty': 'If not empty',
  'visibilityHidden': 'Hidden', 'visibilityAlwaysShown': 'Always shown',
  'replaceAllData': 'Replace All Data?',
  'replaceAllDataBody': 'Importing will permanently replace all current data with the backup. This cannot be undone.',
  'importSuccessful': 'Import Successful',
  'importSuccessfulBody': 'Your data has been restored from the backup.',
  'importFailed': 'Import Failed',
  'importFailedInvalid': 'The selected file is not a valid Planom backup.',
  'importFailedRead': 'An error occurred while reading the file.',
  'exportFailed': 'Export Failed',
  'exportFailedBody': 'An error occurred while creating the backup.',
  'newSpace': 'New Space', 'spaceName': 'Space name',
  'a11yToggleComplete': 'Toggle completion',
  'deleteSpace': 'Delete Space?',
  'deleteSpaceBody':
      'This permanently deletes the space and all of its data. This cannot be undone.',
  'sectionSecurity': 'Privacy & Security',
  'appLock': 'App Lock', 'enableLock': 'Enable Lock', 'changeLock': 'Change Lock', 'removeLock': 'Remove Lock',
  'lockType': 'Lock Type',
  'lockTypePin4': '4-digit PIN', 'lockTypePin5': '5-digit PIN', 'lockTypePin6': '6-digit PIN',
  'lockTypePin7': '7-digit PIN', 'lockTypePin8': '8-digit PIN', 'lockTypeCustom': 'Custom Password',
  'enterPassword': 'Enter password', 'enterNewPassword': 'Enter new password',
  'confirmPassword': 'Confirm password', 'confirmNewPassword': 'Confirm new password',
  'currentPassword': 'Current password',
  'wrongPassword': 'Wrong password', 'passwordsDoNotMatch': 'Passwords do not match',
  'forgotPasswordHint': 'If you forget your password, the only way to access the app is to reinstall it.',
  'lockEnabled': 'Lock enabled', 'lockDisabled': 'Lock disabled',
  'verifyToDisable': 'Enter current password to disable lock',
  'verifyToChange': 'Enter current password to change lock',
  'sectionNotifications': 'Notifications',
  'notificationsEnabled': 'Notifications Enabled',
  'notificationsPermissionHint': 'Open Settings to allow notifications for Planom.',
  'reminders': 'Reminders', 'noReminders': 'No Reminders',
  'reminderAtTime': 'At time',
  'reminder5MinBefore': '5 min before', 'reminder10MinBefore': '10 min before',
  'reminder15MinBefore': '15 min before', 'reminder30MinBefore': '30 min before',
  'reminder1HBefore': '1 hour before', 'reminder2HBefore': '2 hours before',
  'reminder1DBefore': '1 day before',
  'reminder1HAfter': '1 hour after', 'reminder1DAfter': '1 day after',
  'reminderCustomBefore': 'Custom before…', 'reminderCustomAfter': 'Custom after…',
  'resetAllData': 'Reset All Data',
  'resetAllDataQuestion': 'Reset All Data?',
  'resetAllDataBody': 'All tasks, notes, events, and routines will be permanently deleted. Your preferences and settings will be preserved. This cannot be undone.',
  'sortTasks': 'Sort Tasks', 'sortDefault': 'Default',
  'sortByCreation': 'By Creation Date', 'sortByName': 'By Name',
  'sortByPriority': 'By Priority', 'sortByDateTime': 'By Date & Time',
  'addToCalendar': 'Add to Calendar', 'taskOption': 'Task', 'eventOption': 'Event',
  'noTasks': 'No tasks', 'noTasksForToday': 'No tasks for today',
  'noUpcomingTasks': 'No upcoming tasks', 'noCompletedTasks': 'No completed tasks',
  'noItems': 'No items', 'noNotes': 'No notes',
  'noListsInFolder': 'No lists in this folder',
  'trashIsEmpty': 'Trash is empty',
  'emptyTrash': 'Empty Trash', 'emptyTrashQuestion': 'Empty Trash?',
  'emptyTrashBody': 'All items in Trash will be permanently deleted. This cannot be undone.',
  'cannotBeUndone': 'This cannot be undone.',
  'moveToTrashAction': 'Move to Trash',
  'moveToTrashQuestion': 'Move "{name}" to Trash?',
  'moveToTrashFolderBody': 'This folder and all its contents will be moved to Trash.',
  'moveToTrashListBody': 'This list and all its tasks will be moved to Trash.',
  'moveToTrashItemBody': 'This item and any related data will be moved to Trash.',
  'restoreQuestion': 'Restore "{name}"?',
  'restoreBody': 'This will be moved back to {destination}.',
  'deletePermanentlyQuestion': 'Delete "{name}" permanently?',
  'taskName': 'Task name', 'eventName': 'Event name', 'note': 'Note',
  'subtasks': 'Subtasks', 'addSubtask': 'Add subtask',
  'tags': 'Tags', 'noTags': 'No tags yet', 'addTag': 'Add tag',
  'createTag': 'Create', 'searchOrCreateTag': 'Search or create tag',
  'title': 'Title', 'folderName': 'Folder name', 'listName': 'List name',
  'routineName': 'Routine name',
  'duration': 'Duration', 'noDuration': 'No Duration', 'noDate': 'No Date',
  'setTime': 'Set time', 'dateLabel': 'Date', 'priority': 'Priority',
  'noFolder': 'No Folder', 'current': 'Current', 'moveTo': 'Move to',
  'info': 'Info', 'created': 'Created', 'modified': 'Modified',
  'completedLabel': 'Completed',
  'priorityNone': 'None', 'priorityLow': 'Low',
  'priorityMed': 'Med', 'priorityHigh': 'High',
  'changeIcon': 'Change Icon', 'changeColor': 'Change Color',
  'listColor': 'List Color', 'customColor': 'Custom Color',
  'selectColor': 'Select Color', 'otherDots': 'Other…',
  'chooseIcon': 'Choose Icon', 'opening': 'Opening…',
  'chooseFromLibrary': 'Choose from Library',
  'createFolder': 'Create Folder', 'createList': 'Create List',
  'folder': 'Folder', 'list': 'List',
  'newRoutine': 'New Routine', 'editRoutine': 'Edit Routine',
  'sectionFrequency': 'FREQUENCY',
  'freqDaily': 'Daily', 'freqDaysAfter': 'X days after completion',
  'daysAfterCompletion': 'days after completion',
  'autoReset': 'Auto Reset', 'autoResetEveryDay': 'Every day',
  'autoResetNone': 'Do not reset',
  'sectionGoal': 'GOAL',
  'goalAchieveAll': 'Achieve it all', 'goalCertainAmount': 'Reach certain amount',
  'dailyGoal': 'Daily goal', 'recordPerTap': 'Record per tap',
  'unitName': 'Unit name', 'unitEgGlass': 'e.g. glass',
  'noRoutinesToday': 'No routines today', 'noRoutinesYet': 'No routines yet',
  'tapPlusFirstAdd': 'Tap + to add your first routine',
  'tapPlusFirstCreate': 'Tap + to create your first routine',
  'routinesToday': 'Today', 'routinesAll': 'All',
  'routinesTodaySection': 'TODAY',
  'deleteRoutine': 'Delete Routine',
  'deleteRoutineConfirm': 'Delete "{name}"? This will also remove all recorded history.',
  'deleteRoutineBody': 'This will also remove all recorded history.',
  'everyDayLabel': 'Every day',
  'chooseUnit': 'Choose unit', 'customDots': 'Custom…',
  'dayAfterCompletion': '{n} day after completion',
  'daysAfterCompletionN': '{n} days after completion',
  'noTasksOrEvents': 'No tasks or events',
  'deleteEventQuestion': 'Delete Event?',
  'deleteEventBody': 'This event will be permanently removed.',
  'insertLink': 'Insert Link',
  'insertLinkTextPlaceholder': 'Link text (optional)',
};

const Map<String, String> _uk = {
  'appTitle': 'planom',
  'cancel': 'Скасувати', 'done': 'Готово', 'ok': 'OK', 'add': 'Додати',
  'create': 'Створити', 'save': 'Зберегти', 'delete': 'Видалити',
  'deleteAll': 'Видалити все', 'edit': 'Редагувати', 'rename': 'Перейменувати',
  'confirm': 'Підтвердити', 'insert': 'Вставити', 'move': 'Перемістити',
  'putBack': 'Відновити', 'clear': 'Очистити', 'untitled': 'Без назви',
  'tabTasks': 'Завдання', 'tabNotes': 'Нотатки', 'tabCalendar': 'Календар',
  'tabRoutines': 'Звички', 'tabSettings': 'Налаштування',
  'inbox': 'Вхідні', 'today': 'Сьогодні', 'yesterday': 'Вчора', 'tomorrow': 'Завтра', 'upcoming': 'Майбутні',
  'completed': 'Виконані', 'trash': 'Кошик',
  'settings': 'Налаштування',
  'sectionAppearance': 'Зовнішній вигляд', 'themeLight': 'Світла',
  'themeSystem': 'Системна', 'themeDark': 'Темна',
  'theme': 'Тема', 'accentColor': 'Акцентний колір', 'completionColor': 'Колір завершення',
  'sectionSmartLists': 'Розумні списки', 'sectionCustomization': 'Налаштування',
  'tabBar': 'Панель вкладок', 'sectionLanguage': 'Мова', 'language': 'Мова', 'font': 'Шрифт', 'searchFonts': 'Пошук шрифтів', 'systemFont': 'Системний', 'fontOfflineWarning': 'Офлайн — лише завантажені шрифти', 'editPreviewText': 'Змінити текст прикладу', 'previewText': 'Текст прикладу',
  'sectionData': 'Дані',
  'exportBackup': 'Експорт резервної копії', 'importBackup': 'Імпорт резервної копії',
  'exportBackupSublabel': 'Planom (.planom) · повне відновлення',
  'importBackupSublabel': 'Planom (.planom) · замінює всі дані',
  'display': 'Відображення', 'hideLabels': 'Сховати підписи',
  'visibleTabs': 'Видимі вкладки',
  'settingsAccessibleHint': 'Налаштування доступні з меню (⋯) у кожній іншій вкладці.',
  'visibility': 'Видимість',
  'visibilityShow': 'Показувати', 'visibilityIfNotEmpty': 'Якщо не порожнє',
  'visibilityHidden': 'Сховано', 'visibilityAlwaysShown': 'Завжди показано',
  'replaceAllData': 'Замінити всі дані?',
  'replaceAllDataBody': 'Імпорт назавжди замінить усі поточні дані резервною копією. Цю дію не можна скасувати.',
  'importSuccessful': 'Імпорт успішний',
  'importSuccessfulBody': 'Ваші дані відновлено з резервної копії.',
  'importFailed': 'Помилка імпорту',
  'importFailedInvalid': 'Вибраний файл не є дійсною резервною копією Planom.',
  'importFailedRead': 'Сталася помилка під час читання файлу.',
  'exportFailed': 'Помилка експорту',
  'exportFailedBody': 'Сталася помилка під час створення резервної копії.',
  'newSpace': 'Новий простір', 'spaceName': 'Назва простору',
  'sortTasks': 'Сортування завдань', 'sortDefault': 'За замовчуванням',
  'sortByCreation': 'За датою створення', 'sortByName': 'За назвою',
  'sortByPriority': 'За пріоритетом', 'sortByDateTime': 'За датою і часом',
  'addToCalendar': 'Додати до календаря', 'taskOption': 'Завдання', 'eventOption': 'Подія',
  'noTasks': 'Немає завдань', 'noTasksForToday': 'Немає завдань на сьогодні',
  'noUpcomingTasks': 'Немає майбутніх завдань',
  'noCompletedTasks': 'Немає виконаних завдань',
  'noItems': 'Немає елементів', 'noNotes': 'Немає нотаток',
  'noListsInFolder': 'У цій папці немає списків',
  'trashIsEmpty': 'Кошик порожній',
  'emptyTrash': 'Очистити кошик', 'emptyTrashQuestion': 'Очистити кошик?',
  'emptyTrashBody': 'Усі елементи в кошику буде видалено назавжди. Цю дію не можна скасувати.',
  'cannotBeUndone': 'Цю дію не можна скасувати.',
  'moveToTrashAction': 'Перемістити в кошик',
  'moveToTrashQuestion': 'Перемістити «{name}» у кошик?',
  'moveToTrashFolderBody': 'Цю папку з усім вмістом буде переміщено до кошика.',
  'moveToTrashListBody': 'Цей список і всі його завдання буде переміщено до кошика.',
  'moveToTrashItemBody': 'Цей елемент і пов’язані з ним дані буде переміщено до кошика.',
  'restoreQuestion': 'Відновити «{name}»?',
  'restoreBody': 'Буде повернуто до {destination}.',
  'deletePermanentlyQuestion': 'Видалити «{name}» назавжди?',
  'taskName': 'Назва завдання', 'eventName': 'Назва події', 'note': 'Нотатка',
  'subtasks': 'Підзавдання', 'addSubtask': 'Додати підзавдання',
  'tags': 'Теги', 'noTags': 'Тегів ще немає', 'addTag': 'Додати тег',
  'createTag': 'Створити', 'searchOrCreateTag': 'Пошук або створення тегу',
  'title': 'Заголовок', 'folderName': 'Назва папки', 'listName': 'Назва списку',
  'routineName': 'Назва звички',
  'duration': 'Тривалість', 'noDuration': 'Без тривалості', 'noDate': 'Без дати',
  'setTime': 'Встановити час', 'dateLabel': 'Дата', 'priority': 'Пріоритет',
  'noFolder': 'Без папки', 'current': 'Поточне', 'moveTo': 'Перемістити в',
  'info': 'Інформація', 'created': 'Створено', 'modified': 'Змінено',
  'completedLabel': 'Виконано',
  'priorityNone': 'Немає', 'priorityLow': 'Низький',
  'priorityMed': 'Середній', 'priorityHigh': 'Високий',
  'changeIcon': 'Змінити іконку', 'changeColor': 'Змінити колір',
  'listColor': 'Колір списку', 'customColor': 'Власний колір',
  'selectColor': 'Вибрати колір', 'otherDots': 'Інше…',
  'chooseIcon': 'Вибрати іконку', 'opening': 'Відкриття…',
  'chooseFromLibrary': 'Вибрати з бібліотеки',
  'createFolder': 'Створити папку', 'createList': 'Створити список',
  'folder': 'Папка', 'list': 'Список',
  'newRoutine': 'Нова звичка', 'editRoutine': 'Редагувати звичку',
  'sectionFrequency': 'ЧАСТОТА',
  'freqDaily': 'Щодня', 'freqDaysAfter': 'Через X днів після виконання',
  'daysAfterCompletion': 'днів після виконання',
  'autoReset': 'Автоскидання', 'autoResetEveryDay': 'Щодня',
  'autoResetNone': 'Не скидати',
  'sectionGoal': 'МЕТА',
  'goalAchieveAll': 'Виконати все', 'goalCertainAmount': 'Досягти певної кількості',
  'dailyGoal': 'Денна ціль', 'recordPerTap': 'Запис за натискання',
  'unitName': 'Одиниця', 'unitEgGlass': 'напр. склянка',
  'noRoutinesToday': 'Сьогодні звичок немає', 'noRoutinesYet': 'Ще немає звичок',
  'tapPlusFirstAdd': 'Натисніть +, щоб додати першу звичку',
  'tapPlusFirstCreate': 'Натисніть +, щоб створити першу звичку',
  'routinesToday': 'Сьогодні', 'routinesAll': 'Усі',
  'routinesTodaySection': 'СЬОГОДНІ',
  'deleteRoutine': 'Видалити звичку',
  'deleteRoutineConfirm': 'Видалити «{name}»? Також буде видалено всю історію.',
  'deleteRoutineBody': 'Також буде видалено всю історію.',
  'everyDayLabel': 'Щодня',
  'chooseUnit': 'Вибрати одиницю', 'customDots': 'Власна…',
  'dayAfterCompletion': '{n} день після виконання',
  'daysAfterCompletionN': '{n} днів після виконання',
  'noTasksOrEvents': 'Немає завдань або подій',
  'deleteEventQuestion': 'Видалити подію?',
  'deleteEventBody': 'Цю подію буде видалено назавжди.',
  'insertLink': 'Вставити посилання',
  'insertLinkTextPlaceholder': 'Текст посилання (необов’язково)',
};

const Map<String, String> _es = {
  'appTitle': 'planom',
  'cancel': 'Cancelar', 'done': 'Listo', 'ok': 'OK', 'add': 'Añadir',
  'create': 'Crear', 'save': 'Guardar', 'delete': 'Eliminar',
  'deleteAll': 'Eliminar todo', 'edit': 'Editar', 'rename': 'Renombrar',
  'confirm': 'Confirmar', 'insert': 'Insertar', 'move': 'Mover',
  'putBack': 'Restaurar', 'clear': 'Borrar', 'untitled': 'Sin título',
  'tabTasks': 'Tareas', 'tabNotes': 'Notas', 'tabCalendar': 'Calendario',
  'tabRoutines': 'Rutinas', 'tabSettings': 'Ajustes',
  'inbox': 'Bandeja', 'today': 'Hoy', 'yesterday': 'Ayer', 'tomorrow': 'Mañana', 'upcoming': 'Próximas',
  'completed': 'Completadas', 'trash': 'Papelera',
  'settings': 'Ajustes',
  'sectionAppearance': 'Apariencia', 'themeLight': 'Claro',
  'themeSystem': 'Sistema', 'themeDark': 'Oscuro',
  'theme': 'Tema', 'accentColor': 'Color de acento', 'completionColor': 'Color de completado',
  'sectionSmartLists': 'Listas inteligentes', 'sectionCustomization': 'Personalización',
  'tabBar': 'Barra de pestañas', 'sectionLanguage': 'Idioma', 'language': 'Idioma', 'font': 'Fuente', 'searchFonts': 'Buscar fuentes', 'systemFont': 'Sistema', 'fontOfflineWarning': 'Sin conexión — solo fuentes en caché', 'editPreviewText': 'Editar texto de vista previa', 'previewText': 'Texto de vista previa',
  'sectionData': 'Datos',
  'exportBackup': 'Exportar copia', 'importBackup': 'Importar copia',
  'exportBackupSublabel': 'Planom (.planom) · restauración completa',
  'importBackupSublabel': 'Planom (.planom) · reemplaza todos los datos',
  'display': 'Mostrar', 'hideLabels': 'Ocultar etiquetas',
  'visibleTabs': 'Pestañas visibles',
  'settingsAccessibleHint': 'Los ajustes son accesibles desde el menú (⋯) en las demás pestañas.',
  'visibility': 'Visibilidad',
  'visibilityShow': 'Mostrar', 'visibilityIfNotEmpty': 'Si no está vacío',
  'visibilityHidden': 'Oculto', 'visibilityAlwaysShown': 'Siempre visible',
  'replaceAllData': '¿Reemplazar todos los datos?',
  'replaceAllDataBody': 'La importación reemplazará permanentemente todos los datos. Esto no se puede deshacer.',
  'importSuccessful': 'Importación exitosa',
  'importSuccessfulBody': 'Tus datos se han restaurado desde la copia.',
  'importFailed': 'Error al importar',
  'importFailedInvalid': 'El archivo seleccionado no es una copia válida de Planom.',
  'importFailedRead': 'Ocurrió un error al leer el archivo.',
  'exportFailed': 'Error al exportar',
  'exportFailedBody': 'Ocurrió un error al crear la copia.',
  'newSpace': 'Nuevo espacio', 'spaceName': 'Nombre del espacio',
  'sortTasks': 'Ordenar tareas', 'sortDefault': 'Predeterminado',
  'sortByCreation': 'Por fecha de creación', 'sortByName': 'Por nombre',
  'sortByPriority': 'Por prioridad', 'sortByDateTime': 'Por fecha y hora',
  'addToCalendar': 'Añadir al calendario', 'taskOption': 'Tarea', 'eventOption': 'Evento',
  'noTasks': 'Sin tareas', 'noTasksForToday': 'Sin tareas para hoy',
  'noUpcomingTasks': 'Sin tareas próximas',
  'noCompletedTasks': 'Sin tareas completadas',
  'noItems': 'Sin elementos', 'noNotes': 'Sin notas',
  'noListsInFolder': 'No hay listas en esta carpeta',
  'trashIsEmpty': 'Papelera vacía',
  'emptyTrash': 'Vaciar papelera', 'emptyTrashQuestion': '¿Vaciar papelera?',
  'emptyTrashBody': 'Todos los elementos serán eliminados permanentemente. Esto no se puede deshacer.',
  'cannotBeUndone': 'Esto no se puede deshacer.',
  'moveToTrashAction': 'Mover a papelera',
  'moveToTrashQuestion': '¿Mover "{name}" a la papelera?',
  'moveToTrashFolderBody': 'Esta carpeta y todo su contenido se moverán a la papelera.',
  'moveToTrashListBody': 'Esta lista y todas sus tareas se moverán a la papelera.',
  'moveToTrashItemBody': 'Este elemento y sus datos se moverán a la papelera.',
  'restoreQuestion': '¿Restaurar "{name}"?',
  'restoreBody': 'Se moverá a {destination}.',
  'deletePermanentlyQuestion': '¿Eliminar "{name}" permanentemente?',
  'taskName': 'Nombre de la tarea', 'eventName': 'Nombre del evento', 'note': 'Nota',
  'subtasks': 'Subtareas', 'addSubtask': 'Añadir subtarea',
  'tags': 'Etiquetas', 'noTags': 'Sin etiquetas aún', 'addTag': 'Añadir etiqueta',
  'createTag': 'Crear', 'searchOrCreateTag': 'Buscar o crear etiqueta',
  'title': 'Título', 'folderName': 'Nombre de la carpeta', 'listName': 'Nombre de la lista',
  'routineName': 'Nombre de la rutina',
  'duration': 'Duración', 'noDuration': 'Sin duración', 'noDate': 'Sin fecha',
  'setTime': 'Establecer hora', 'dateLabel': 'Fecha', 'priority': 'Prioridad',
  'noFolder': 'Sin carpeta', 'current': 'Actual', 'moveTo': 'Mover a',
  'info': 'Información', 'created': 'Creado', 'modified': 'Modificado',
  'completedLabel': 'Completado',
  'priorityNone': 'Ninguna', 'priorityLow': 'Baja',
  'priorityMed': 'Media', 'priorityHigh': 'Alta',
  'changeIcon': 'Cambiar icono', 'changeColor': 'Cambiar color',
  'listColor': 'Color de la lista', 'customColor': 'Color personalizado',
  'selectColor': 'Seleccionar color', 'otherDots': 'Otro…',
  'chooseIcon': 'Elegir icono', 'opening': 'Abriendo…',
  'chooseFromLibrary': 'Elegir de la biblioteca',
  'createFolder': 'Crear carpeta', 'createList': 'Crear lista',
  'folder': 'Carpeta', 'list': 'Lista',
  'newRoutine': 'Nueva rutina', 'editRoutine': 'Editar rutina',
  'sectionFrequency': 'FRECUENCIA',
  'freqDaily': 'Diario', 'freqDaysAfter': 'X días después de completar',
  'daysAfterCompletion': 'días después de completar',
  'autoReset': 'Reinicio automático', 'autoResetEveryDay': 'Cada día',
  'autoResetNone': 'No reiniciar',
  'sectionGoal': 'OBJETIVO',
  'goalAchieveAll': 'Lograr todo', 'goalCertainAmount': 'Alcanzar cantidad',
  'dailyGoal': 'Meta diaria', 'recordPerTap': 'Registro por toque',
  'unitName': 'Unidad', 'unitEgGlass': 'ej. vaso',
  'noRoutinesToday': 'Sin rutinas hoy', 'noRoutinesYet': 'Aún sin rutinas',
  'tapPlusFirstAdd': 'Toca + para añadir tu primera rutina',
  'tapPlusFirstCreate': 'Toca + para crear tu primera rutina',
  'routinesToday': 'Hoy', 'routinesAll': 'Todas',
  'routinesTodaySection': 'HOY',
  'deleteRoutine': 'Eliminar rutina',
  'deleteRoutineConfirm': '¿Eliminar "{name}"? También se eliminará todo el historial.',
  'deleteRoutineBody': 'También se eliminará todo el historial.',
  'everyDayLabel': 'Cada día',
  'chooseUnit': 'Elegir unidad', 'customDots': 'Personalizada…',
  'dayAfterCompletion': '{n} día después de completar',
  'daysAfterCompletionN': '{n} días después de completar',
  'noTasksOrEvents': 'Sin tareas ni eventos',
  'deleteEventQuestion': '¿Eliminar evento?',
  'deleteEventBody': 'Este evento se eliminará permanentemente.',
  'insertLink': 'Insertar enlace',
  'insertLinkTextPlaceholder': 'Texto del enlace (opcional)',
};

const Map<String, String> _fr = {
  'appTitle': 'planom',
  'cancel': 'Annuler', 'done': 'Terminé', 'ok': 'OK', 'add': 'Ajouter',
  'create': 'Créer', 'save': 'Enregistrer', 'delete': 'Supprimer',
  'deleteAll': 'Tout supprimer', 'edit': 'Modifier', 'rename': 'Renommer',
  'confirm': 'Confirmer', 'insert': 'Insérer', 'move': 'Déplacer',
  'putBack': 'Restaurer', 'clear': 'Effacer', 'untitled': 'Sans titre',
  'tabTasks': 'Tâches', 'tabNotes': 'Notes', 'tabCalendar': 'Calendrier',
  'tabRoutines': 'Routines', 'tabSettings': 'Réglages',
  'inbox': 'Boîte', 'today': "Aujourd'hui", 'yesterday': 'Hier', 'tomorrow': 'Demain', 'upcoming': 'À venir',
  'completed': 'Terminé', 'trash': 'Corbeille',
  'settings': 'Réglages',
  'sectionAppearance': 'Apparence', 'themeLight': 'Clair',
  'themeSystem': 'Système', 'themeDark': 'Sombre',
  'theme': 'Thème', 'accentColor': "Couleur d'accent", 'completionColor': 'Couleur de complétion',
  'sectionSmartLists': 'Listes intelligentes', 'sectionCustomization': 'Personnalisation',
  'tabBar': "Barre d'onglets", 'sectionLanguage': 'Langue', 'language': 'Langue', 'font': 'Police', 'searchFonts': 'Rechercher des polices', 'systemFont': 'Système', 'fontOfflineWarning': 'Hors ligne — aperçu des polices en cache uniquement', 'editPreviewText': "Modifier le texte d'aperçu", 'previewText': "Texte d'aperçu",
  'sectionData': 'Données',
  'exportBackup': 'Exporter la sauvegarde', 'importBackup': 'Importer la sauvegarde',
  'exportBackupSublabel': 'Planom (.planom) · restauration complète',
  'importBackupSublabel': 'Planom (.planom) · remplace toutes les données',
  'display': 'Affichage', 'hideLabels': 'Masquer les libellés',
  'visibleTabs': 'Onglets visibles',
  'settingsAccessibleHint': 'Les réglages sont accessibles depuis le menu (⋯) dans tous les autres onglets.',
  'visibility': 'Visibilité',
  'visibilityShow': 'Afficher', 'visibilityIfNotEmpty': 'Si non vide',
  'visibilityHidden': 'Masqué', 'visibilityAlwaysShown': 'Toujours visible',
  'replaceAllData': 'Remplacer toutes les données ?',
  'replaceAllDataBody': 'L\'import remplacera définitivement toutes les données actuelles. Cette action est irréversible.',
  'importSuccessful': 'Import réussi',
  'importSuccessfulBody': 'Vos données ont été restaurées.',
  'importFailed': 'Échec de l\'import',
  'importFailedInvalid': 'Le fichier sélectionné n\'est pas une sauvegarde Planom valide.',
  'importFailedRead': 'Une erreur est survenue lors de la lecture du fichier.',
  'exportFailed': 'Échec de l\'export',
  'exportFailedBody': 'Une erreur est survenue lors de la création de la sauvegarde.',
  'newSpace': 'Nouvel espace', 'spaceName': 'Nom de l\'espace',
  'sortTasks': 'Trier les tâches', 'sortDefault': 'Par défaut',
  'sortByCreation': 'Par date de création', 'sortByName': 'Par nom',
  'sortByPriority': 'Par priorité', 'sortByDateTime': 'Par date et heure',
  'addToCalendar': 'Ajouter au calendrier', 'taskOption': 'Tâche', 'eventOption': 'Événement',
  'noTasks': 'Aucune tâche', 'noTasksForToday': 'Aucune tâche aujourd\'hui',
  'noUpcomingTasks': 'Aucune tâche à venir',
  'noCompletedTasks': 'Aucune tâche terminée',
  'noItems': 'Aucun élément', 'noNotes': 'Aucune note',
  'noListsInFolder': 'Aucune liste dans ce dossier',
  'trashIsEmpty': 'Corbeille vide',
  'emptyTrash': 'Vider la corbeille', 'emptyTrashQuestion': 'Vider la corbeille ?',
  'emptyTrashBody': 'Tous les éléments seront supprimés définitivement. Cette action est irréversible.',
  'cannotBeUndone': 'Cette action est irréversible.',
  'moveToTrashAction': 'Mettre à la corbeille',
  'moveToTrashQuestion': 'Mettre « {name} » à la corbeille ?',
  'moveToTrashFolderBody': 'Ce dossier et tout son contenu seront mis à la corbeille.',
  'moveToTrashListBody': 'Cette liste et toutes ses tâches seront mises à la corbeille.',
  'moveToTrashItemBody': 'Cet élément et ses données associées seront mis à la corbeille.',
  'restoreQuestion': 'Restaurer « {name} » ?',
  'restoreBody': 'Sera déplacé vers {destination}.',
  'deletePermanentlyQuestion': 'Supprimer « {name} » définitivement ?',
  'taskName': 'Nom de la tâche', 'eventName': 'Nom de l\'événement', 'note': 'Note',
  'subtasks': 'Sous-tâches', 'addSubtask': 'Ajouter une sous-tâche',
  'tags': 'Étiquettes', 'noTags': 'Aucune étiquette', 'addTag': 'Ajouter une étiquette',
  'createTag': 'Créer', 'searchOrCreateTag': 'Rechercher ou créer une étiquette',
  'title': 'Titre', 'folderName': 'Nom du dossier', 'listName': 'Nom de la liste',
  'routineName': 'Nom de la routine',
  'duration': 'Durée', 'noDuration': 'Sans durée', 'noDate': 'Sans date',
  'setTime': 'Définir l\'heure', 'dateLabel': 'Date', 'priority': 'Priorité',
  'noFolder': 'Aucun dossier', 'current': 'Actuel', 'moveTo': 'Déplacer vers',
  'info': 'Informations', 'created': 'Créé', 'modified': 'Modifié',
  'completedLabel': 'Terminé',
  'priorityNone': 'Aucune', 'priorityLow': 'Basse',
  'priorityMed': 'Moyenne', 'priorityHigh': 'Haute',
  'changeIcon': 'Changer l\'icône', 'changeColor': 'Changer la couleur',
  'listColor': 'Couleur de la liste', 'customColor': 'Couleur personnalisée',
  'selectColor': 'Sélectionner', 'otherDots': 'Autre…',
  'chooseIcon': 'Choisir une icône', 'opening': 'Ouverture…',
  'chooseFromLibrary': 'Choisir depuis la bibliothèque',
  'createFolder': 'Créer un dossier', 'createList': 'Créer une liste',
  'folder': 'Dossier', 'list': 'Liste',
  'newRoutine': 'Nouvelle routine', 'editRoutine': 'Modifier la routine',
  'sectionFrequency': 'FRÉQUENCE',
  'freqDaily': 'Quotidien', 'freqDaysAfter': 'X jours après l\'achèvement',
  'daysAfterCompletion': 'jours après l\'achèvement',
  'autoReset': 'Réinitialisation auto', 'autoResetEveryDay': 'Chaque jour',
  'autoResetNone': 'Ne pas réinitialiser',
  'sectionGoal': 'OBJECTIF',
  'goalAchieveAll': 'Tout accomplir', 'goalCertainAmount': 'Atteindre un montant',
  'dailyGoal': 'Objectif quotidien', 'recordPerTap': 'Par appui',
  'unitName': 'Unité', 'unitEgGlass': 'ex. verre',
  'noRoutinesToday': 'Aucune routine aujourd\'hui', 'noRoutinesYet': 'Aucune routine',
  'tapPlusFirstAdd': 'Appuyez sur + pour ajouter votre première routine',
  'tapPlusFirstCreate': 'Appuyez sur + pour créer votre première routine',
  'routinesToday': 'Aujourd\'hui', 'routinesAll': 'Toutes',
  'routinesTodaySection': 'AUJOURD\'HUI',
  'deleteRoutine': 'Supprimer la routine',
  'deleteRoutineConfirm': 'Supprimer « {name} » ? Tout l\'historique sera également supprimé.',
  'deleteRoutineBody': 'Tout l\'historique sera également supprimé.',
  'everyDayLabel': 'Chaque jour',
  'chooseUnit': 'Choisir l\'unité', 'customDots': 'Personnalisé…',
  'dayAfterCompletion': '{n} jour après l\'achèvement',
  'daysAfterCompletionN': '{n} jours après l\'achèvement',
  'noTasksOrEvents': 'Aucune tâche ni événement',
  'deleteEventQuestion': 'Supprimer l\'événement ?',
  'deleteEventBody': 'Cet événement sera supprimé définitivement.',
  'insertLink': 'Insérer un lien',
  'insertLinkTextPlaceholder': 'Texte du lien (optionnel)',
};

const Map<String, String> _de = {
  'appTitle': 'planom',
  'cancel': 'Abbrechen', 'done': 'Fertig', 'ok': 'OK', 'add': 'Hinzufügen',
  'create': 'Erstellen', 'save': 'Speichern', 'delete': 'Löschen',
  'deleteAll': 'Alle löschen', 'edit': 'Bearbeiten', 'rename': 'Umbenennen',
  'confirm': 'Bestätigen', 'insert': 'Einfügen', 'move': 'Verschieben',
  'putBack': 'Wiederherstellen', 'clear': 'Löschen', 'untitled': 'Ohne Titel',
  'tabTasks': 'Aufgaben', 'tabNotes': 'Notizen', 'tabCalendar': 'Kalender',
  'tabRoutines': 'Routinen', 'tabSettings': 'Einstellungen',
  'inbox': 'Eingang', 'today': 'Heute', 'yesterday': 'Gestern', 'tomorrow': 'Morgen', 'upcoming': 'Anstehend',
  'completed': 'Erledigt', 'trash': 'Papierkorb',
  'settings': 'Einstellungen',
  'sectionAppearance': 'Erscheinungsbild', 'themeLight': 'Hell',
  'themeSystem': 'System', 'themeDark': 'Dunkel',
  'theme': 'Thema', 'accentColor': 'Akzentfarbe', 'completionColor': 'Abschlussfarbe',
  'sectionSmartLists': 'Intelligente Listen', 'sectionCustomization': 'Anpassung',
  'tabBar': 'Tab-Leiste', 'sectionLanguage': 'Sprache', 'language': 'Sprache', 'font': 'Schrift', 'searchFonts': 'Schriften suchen', 'systemFont': 'System', 'fontOfflineWarning': 'Offline — nur gecachte Schriften', 'editPreviewText': 'Vorschautext bearbeiten', 'previewText': 'Vorschautext',
  'sectionData': 'Daten',
  'exportBackup': 'Backup exportieren', 'importBackup': 'Backup importieren',
  'exportBackupSublabel': 'Planom (.planom) · vollständige Wiederherstellung',
  'importBackupSublabel': 'Planom (.planom) · ersetzt alle Daten',
  'display': 'Anzeige', 'hideLabels': 'Beschriftungen ausblenden',
  'visibleTabs': 'Sichtbare Tabs',
  'settingsAccessibleHint': 'Einstellungen sind über das Menü (⋯) in jedem anderen Tab erreichbar.',
  'visibility': 'Sichtbarkeit',
  'visibilityShow': 'Anzeigen', 'visibilityIfNotEmpty': 'Falls nicht leer',
  'visibilityHidden': 'Ausgeblendet', 'visibilityAlwaysShown': 'Immer sichtbar',
  'replaceAllData': 'Alle Daten ersetzen?',
  'replaceAllDataBody': 'Beim Import werden alle aktuellen Daten dauerhaft ersetzt. Dies kann nicht rückgängig gemacht werden.',
  'importSuccessful': 'Import erfolgreich',
  'importSuccessfulBody': 'Ihre Daten wurden aus dem Backup wiederhergestellt.',
  'importFailed': 'Import fehlgeschlagen',
  'importFailedInvalid': 'Die ausgewählte Datei ist kein gültiges Planom-Backup.',
  'importFailedRead': 'Beim Lesen der Datei ist ein Fehler aufgetreten.',
  'exportFailed': 'Export fehlgeschlagen',
  'exportFailedBody': 'Beim Erstellen des Backups ist ein Fehler aufgetreten.',
  'newSpace': 'Neuer Bereich', 'spaceName': 'Bereichsname',
  'sortTasks': 'Aufgaben sortieren', 'sortDefault': 'Standard',
  'sortByCreation': 'Nach Erstellungsdatum', 'sortByName': 'Nach Name',
  'sortByPriority': 'Nach Priorität', 'sortByDateTime': 'Nach Datum & Zeit',
  'addToCalendar': 'Zum Kalender hinzufügen', 'taskOption': 'Aufgabe', 'eventOption': 'Ereignis',
  'noTasks': 'Keine Aufgaben', 'noTasksForToday': 'Keine Aufgaben für heute',
  'noUpcomingTasks': 'Keine anstehenden Aufgaben',
  'noCompletedTasks': 'Keine erledigten Aufgaben',
  'noItems': 'Keine Einträge', 'noNotes': 'Keine Notizen',
  'noListsInFolder': 'Keine Listen in diesem Ordner',
  'trashIsEmpty': 'Papierkorb ist leer',
  'emptyTrash': 'Papierkorb leeren', 'emptyTrashQuestion': 'Papierkorb leeren?',
  'emptyTrashBody': 'Alle Einträge werden dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.',
  'cannotBeUndone': 'Dies kann nicht rückgängig gemacht werden.',
  'moveToTrashAction': 'In den Papierkorb',
  'moveToTrashQuestion': '„{name}" in den Papierkorb verschieben?',
  'moveToTrashFolderBody': 'Dieser Ordner und sein gesamter Inhalt werden in den Papierkorb verschoben.',
  'moveToTrashListBody': 'Diese Liste und alle Aufgaben werden in den Papierkorb verschoben.',
  'moveToTrashItemBody': 'Dieser Eintrag und zugehörige Daten werden in den Papierkorb verschoben.',
  'restoreQuestion': '„{name}" wiederherstellen?',
  'restoreBody': 'Wird zurück nach {destination} verschoben.',
  'deletePermanentlyQuestion': '„{name}" endgültig löschen?',
  'taskName': 'Aufgabenname', 'eventName': 'Ereignisname', 'note': 'Notiz',
  'subtasks': 'Unteraufgaben', 'addSubtask': 'Unteraufgabe hinzufügen',
  'tags': 'Tags', 'noTags': 'Noch keine Tags', 'addTag': 'Tag hinzufügen',
  'createTag': 'Erstellen', 'searchOrCreateTag': 'Tag suchen oder erstellen',
  'title': 'Titel', 'folderName': 'Ordnername', 'listName': 'Listenname',
  'routineName': 'Routinename',
  'duration': 'Dauer', 'noDuration': 'Keine Dauer', 'noDate': 'Kein Datum',
  'setTime': 'Zeit festlegen', 'dateLabel': 'Datum', 'priority': 'Priorität',
  'noFolder': 'Kein Ordner', 'current': 'Aktuell', 'moveTo': 'Verschieben nach',
  'info': 'Info', 'created': 'Erstellt', 'modified': 'Geändert',
  'completedLabel': 'Erledigt',
  'priorityNone': 'Keine', 'priorityLow': 'Niedrig',
  'priorityMed': 'Mittel', 'priorityHigh': 'Hoch',
  'changeIcon': 'Symbol ändern', 'changeColor': 'Farbe ändern',
  'listColor': 'Listenfarbe', 'customColor': 'Eigene Farbe',
  'selectColor': 'Farbe wählen', 'otherDots': 'Andere…',
  'chooseIcon': 'Symbol wählen', 'opening': 'Öffne…',
  'chooseFromLibrary': 'Aus Bibliothek wählen',
  'createFolder': 'Ordner erstellen', 'createList': 'Liste erstellen',
  'folder': 'Ordner', 'list': 'Liste',
  'newRoutine': 'Neue Routine', 'editRoutine': 'Routine bearbeiten',
  'sectionFrequency': 'HÄUFIGKEIT',
  'freqDaily': 'Täglich', 'freqDaysAfter': 'X Tage nach Abschluss',
  'daysAfterCompletion': 'Tage nach Abschluss',
  'autoReset': 'Automatisch zurücksetzen', 'autoResetEveryDay': 'Jeden Tag',
  'autoResetNone': 'Nicht zurücksetzen',
  'sectionGoal': 'ZIEL',
  'goalAchieveAll': 'Alles erreichen', 'goalCertainAmount': 'Bestimmte Menge',
  'dailyGoal': 'Tagesziel', 'recordPerTap': 'Pro Tipp aufzeichnen',
  'unitName': 'Einheit', 'unitEgGlass': 'z. B. Glas',
  'noRoutinesToday': 'Heute keine Routinen', 'noRoutinesYet': 'Noch keine Routinen',
  'tapPlusFirstAdd': 'Tippe +, um deine erste Routine hinzuzufügen',
  'tapPlusFirstCreate': 'Tippe +, um deine erste Routine zu erstellen',
  'routinesToday': 'Heute', 'routinesAll': 'Alle',
  'routinesTodaySection': 'HEUTE',
  'deleteRoutine': 'Routine löschen',
  'deleteRoutineConfirm': '„{name}" löschen? Auch der gesamte Verlauf wird entfernt.',
  'deleteRoutineBody': 'Auch der gesamte Verlauf wird entfernt.',
  'everyDayLabel': 'Jeden Tag',
  'chooseUnit': 'Einheit wählen', 'customDots': 'Eigene…',
  'dayAfterCompletion': '{n} Tag nach Abschluss',
  'daysAfterCompletionN': '{n} Tage nach Abschluss',
  'noTasksOrEvents': 'Keine Aufgaben oder Ereignisse',
  'deleteEventQuestion': 'Ereignis löschen?',
  'deleteEventBody': 'Dieses Ereignis wird dauerhaft entfernt.',
  'insertLink': 'Link einfügen',
  'insertLinkTextPlaceholder': 'Linktext (optional)',
};

const Map<String, String> _it = {
  'appTitle': 'planom',
  'cancel': 'Annulla', 'done': 'Fatto', 'ok': 'OK', 'add': 'Aggiungi',
  'create': 'Crea', 'save': 'Salva', 'delete': 'Elimina',
  'deleteAll': 'Elimina tutto', 'edit': 'Modifica', 'rename': 'Rinomina',
  'confirm': 'Conferma', 'insert': 'Inserisci', 'move': 'Sposta',
  'putBack': 'Ripristina', 'clear': 'Cancella', 'untitled': 'Senza titolo',
  'tabTasks': 'Attività', 'tabNotes': 'Note', 'tabCalendar': 'Calendario',
  'tabRoutines': 'Abitudini', 'tabSettings': 'Impostazioni',
  'inbox': 'In arrivo', 'today': 'Oggi', 'yesterday': 'Ieri', 'tomorrow': 'Domani', 'upcoming': 'In arrivo',
  'completed': 'Completate', 'trash': 'Cestino',
  'settings': 'Impostazioni',
  'sectionAppearance': 'Aspetto', 'themeLight': 'Chiaro',
  'themeSystem': 'Sistema', 'themeDark': 'Scuro',
  'theme': 'Tema', 'accentColor': 'Colore accento', 'completionColor': 'Colore completamento',
  'sectionSmartLists': 'Liste intelligenti', 'sectionCustomization': 'Personalizzazione',
  'tabBar': 'Barra schede', 'sectionLanguage': 'Lingua', 'language': 'Lingua', 'font': 'Carattere', 'searchFonts': 'Cerca caratteri', 'systemFont': 'Sistema', 'fontOfflineWarning': 'Offline — solo caratteri nella cache', 'editPreviewText': 'Modifica testo di anteprima', 'previewText': 'Testo di anteprima',
  'sectionData': 'Dati',
  'exportBackup': 'Esporta backup', 'importBackup': 'Importa backup',
  'exportBackupSublabel': 'Planom (.planom) · ripristino completo',
  'importBackupSublabel': 'Planom (.planom) · sostituisce tutti i dati',
  'display': 'Visualizzazione', 'hideLabels': 'Nascondi etichette',
  'visibleTabs': 'Schede visibili',
  'settingsAccessibleHint': 'Le impostazioni sono accessibili dal menu (⋯) in ogni altra scheda.',
  'visibility': 'Visibilità',
  'visibilityShow': 'Mostra', 'visibilityIfNotEmpty': 'Se non vuoto',
  'visibilityHidden': 'Nascosto', 'visibilityAlwaysShown': 'Sempre visibile',
  'replaceAllData': 'Sostituire tutti i dati?',
  'replaceAllDataBody': 'L\'importazione sostituirà permanentemente tutti i dati. Questa azione non può essere annullata.',
  'importSuccessful': 'Importazione riuscita',
  'importSuccessfulBody': 'I tuoi dati sono stati ripristinati dal backup.',
  'importFailed': 'Importazione fallita',
  'importFailedInvalid': 'Il file selezionato non è un backup Planom valido.',
  'importFailedRead': 'Si è verificato un errore durante la lettura del file.',
  'exportFailed': 'Esportazione fallita',
  'exportFailedBody': 'Si è verificato un errore durante la creazione del backup.',
  'newSpace': 'Nuovo spazio', 'spaceName': 'Nome dello spazio',
  'sortTasks': 'Ordina attività', 'sortDefault': 'Predefinito',
  'sortByCreation': 'Per data creazione', 'sortByName': 'Per nome',
  'sortByPriority': 'Per priorità', 'sortByDateTime': 'Per data e ora',
  'addToCalendar': 'Aggiungi al calendario', 'taskOption': 'Attività', 'eventOption': 'Evento',
  'noTasks': 'Nessuna attività', 'noTasksForToday': 'Nessuna attività per oggi',
  'noUpcomingTasks': 'Nessuna attività in arrivo',
  'noCompletedTasks': 'Nessuna attività completata',
  'noItems': 'Nessun elemento', 'noNotes': 'Nessuna nota',
  'noListsInFolder': 'Nessuna lista in questa cartella',
  'trashIsEmpty': 'Cestino vuoto',
  'emptyTrash': 'Svuota cestino', 'emptyTrashQuestion': 'Svuotare il cestino?',
  'emptyTrashBody': 'Tutti gli elementi saranno eliminati permanentemente. Questa azione non può essere annullata.',
  'cannotBeUndone': 'Questa azione non può essere annullata.',
  'moveToTrashAction': 'Sposta nel cestino',
  'moveToTrashQuestion': 'Spostare "{name}" nel cestino?',
  'moveToTrashFolderBody': 'Questa cartella e tutto il suo contenuto verranno spostati nel cestino.',
  'moveToTrashListBody': 'Questa lista e tutte le sue attività verranno spostate nel cestino.',
  'moveToTrashItemBody': 'Questo elemento e i dati correlati verranno spostati nel cestino.',
  'restoreQuestion': 'Ripristinare "{name}"?',
  'restoreBody': 'Verrà ripristinato in {destination}.',
  'deletePermanentlyQuestion': 'Eliminare "{name}" definitivamente?',
  'taskName': 'Nome attività', 'eventName': 'Nome evento', 'note': 'Nota',
  'subtasks': 'Sotto-attività', 'addSubtask': 'Aggiungi sotto-attività',
  'tags': 'Tag', 'noTags': 'Nessun tag', 'addTag': 'Aggiungi tag',
  'createTag': 'Crea', 'searchOrCreateTag': 'Cerca o crea tag',
  'title': 'Titolo', 'folderName': 'Nome cartella', 'listName': 'Nome lista',
  'routineName': 'Nome abitudine',
  'duration': 'Durata', 'noDuration': 'Nessuna durata', 'noDate': 'Nessuna data',
  'setTime': 'Imposta ora', 'dateLabel': 'Data', 'priority': 'Priorità',
  'noFolder': 'Nessuna cartella', 'current': 'Attuale', 'moveTo': 'Sposta in',
  'info': 'Info', 'created': 'Creato', 'modified': 'Modificato',
  'completedLabel': 'Completato',
  'priorityNone': 'Nessuna', 'priorityLow': 'Bassa',
  'priorityMed': 'Media', 'priorityHigh': 'Alta',
  'changeIcon': 'Cambia icona', 'changeColor': 'Cambia colore',
  'listColor': 'Colore della lista', 'customColor': 'Colore personalizzato',
  'selectColor': 'Seleziona colore', 'otherDots': 'Altro…',
  'chooseIcon': 'Scegli icona', 'opening': 'Apertura…',
  'chooseFromLibrary': 'Scegli dalla libreria',
  'createFolder': 'Crea cartella', 'createList': 'Crea lista',
  'folder': 'Cartella', 'list': 'Lista',
  'newRoutine': 'Nuova abitudine', 'editRoutine': 'Modifica abitudine',
  'sectionFrequency': 'FREQUENZA',
  'freqDaily': 'Giornaliero', 'freqDaysAfter': 'X giorni dopo completamento',
  'daysAfterCompletion': 'giorni dopo completamento',
  'autoReset': 'Reset automatico', 'autoResetEveryDay': 'Ogni giorno',
  'autoResetNone': 'Non resettare',
  'sectionGoal': 'OBIETTIVO',
  'goalAchieveAll': 'Realizza tutto', 'goalCertainAmount': 'Raggiungi quantità',
  'dailyGoal': 'Obiettivo giornaliero', 'recordPerTap': 'Registra per tocco',
  'unitName': 'Unità', 'unitEgGlass': 'es. bicchiere',
  'noRoutinesToday': 'Nessuna abitudine oggi', 'noRoutinesYet': 'Nessuna abitudine',
  'tapPlusFirstAdd': 'Tocca + per aggiungere la prima abitudine',
  'tapPlusFirstCreate': 'Tocca + per creare la prima abitudine',
  'routinesToday': 'Oggi', 'routinesAll': 'Tutte',
  'routinesTodaySection': 'OGGI',
  'deleteRoutine': 'Elimina abitudine',
  'deleteRoutineConfirm': 'Eliminare "{name}"? Anche la cronologia sarà rimossa.',
  'deleteRoutineBody': 'Anche la cronologia sarà rimossa.',
  'everyDayLabel': 'Ogni giorno',
  'chooseUnit': 'Scegli unità', 'customDots': 'Personalizzata…',
  'dayAfterCompletion': '{n} giorno dopo completamento',
  'daysAfterCompletionN': '{n} giorni dopo completamento',
  'noTasksOrEvents': 'Nessuna attività o evento',
  'deleteEventQuestion': 'Eliminare evento?',
  'deleteEventBody': 'Questo evento sarà rimosso definitivamente.',
  'insertLink': 'Inserisci link',
  'insertLinkTextPlaceholder': 'Testo del link (opzionale)',
};

const Map<String, String> _pt = {
  'appTitle': 'planom',
  'cancel': 'Cancelar', 'done': 'Concluído', 'ok': 'OK', 'add': 'Adicionar',
  'create': 'Criar', 'save': 'Salvar', 'delete': 'Excluir',
  'deleteAll': 'Excluir tudo', 'edit': 'Editar', 'rename': 'Renomear',
  'confirm': 'Confirmar', 'insert': 'Inserir', 'move': 'Mover',
  'putBack': 'Restaurar', 'clear': 'Limpar', 'untitled': 'Sem título',
  'tabTasks': 'Tarefas', 'tabNotes': 'Notas', 'tabCalendar': 'Calendário',
  'tabRoutines': 'Rotinas', 'tabSettings': 'Ajustes',
  'inbox': 'Caixa', 'today': 'Hoje', 'yesterday': 'Ontem', 'tomorrow': 'Amanhã', 'upcoming': 'Próximas',
  'completed': 'Concluídas', 'trash': 'Lixeira',
  'settings': 'Ajustes',
  'sectionAppearance': 'Aparência', 'themeLight': 'Claro',
  'themeSystem': 'Sistema', 'themeDark': 'Escuro',
  'theme': 'Tema', 'accentColor': 'Cor de destaque', 'completionColor': 'Cor de conclusão',
  'sectionSmartLists': 'Listas inteligentes', 'sectionCustomization': 'Personalização',
  'tabBar': 'Barra de abas', 'sectionLanguage': 'Idioma', 'language': 'Idioma', 'font': 'Fonte', 'searchFonts': 'Pesquisar fontes', 'systemFont': 'Sistema', 'fontOfflineWarning': 'Offline — apenas fontes em cache', 'editPreviewText': 'Editar texto de previsualização', 'previewText': 'Texto de previsualização',
  'sectionData': 'Dados',
  'exportBackup': 'Exportar backup', 'importBackup': 'Importar backup',
  'exportBackupSublabel': 'Planom (.planom) · restauração completa',
  'importBackupSublabel': 'Planom (.planom) · substitui todos os dados',
  'display': 'Exibição', 'hideLabels': 'Ocultar rótulos',
  'visibleTabs': 'Abas visíveis',
  'settingsAccessibleHint': 'Ajustes podem ser acessados pelo menu (⋯) em cada outra aba.',
  'visibility': 'Visibilidade',
  'visibilityShow': 'Mostrar', 'visibilityIfNotEmpty': 'Se não vazio',
  'visibilityHidden': 'Oculto', 'visibilityAlwaysShown': 'Sempre visível',
  'replaceAllData': 'Substituir todos os dados?',
  'replaceAllDataBody': 'A importação substituirá permanentemente todos os dados. Isso não pode ser desfeito.',
  'importSuccessful': 'Importação concluída',
  'importSuccessfulBody': 'Seus dados foram restaurados do backup.',
  'importFailed': 'Falha na importação',
  'importFailedInvalid': 'O arquivo não é um backup Planom válido.',
  'importFailedRead': 'Ocorreu um erro ao ler o arquivo.',
  'exportFailed': 'Falha na exportação',
  'exportFailedBody': 'Ocorreu um erro ao criar o backup.',
  'newSpace': 'Novo espaço', 'spaceName': 'Nome do espaço',
  'sortTasks': 'Ordenar tarefas', 'sortDefault': 'Padrão',
  'sortByCreation': 'Por data de criação', 'sortByName': 'Por nome',
  'sortByPriority': 'Por prioridade', 'sortByDateTime': 'Por data e hora',
  'addToCalendar': 'Adicionar ao calendário', 'taskOption': 'Tarefa', 'eventOption': 'Evento',
  'noTasks': 'Sem tarefas', 'noTasksForToday': 'Sem tarefas para hoje',
  'noUpcomingTasks': 'Sem tarefas próximas',
  'noCompletedTasks': 'Sem tarefas concluídas',
  'noItems': 'Sem itens', 'noNotes': 'Sem notas',
  'noListsInFolder': 'Sem listas nesta pasta',
  'trashIsEmpty': 'Lixeira vazia',
  'emptyTrash': 'Esvaziar lixeira', 'emptyTrashQuestion': 'Esvaziar lixeira?',
  'emptyTrashBody': 'Todos os itens serão excluídos permanentemente. Isso não pode ser desfeito.',
  'cannotBeUndone': 'Isso não pode ser desfeito.',
  'moveToTrashAction': 'Mover para lixeira',
  'moveToTrashQuestion': 'Mover "{name}" para a lixeira?',
  'moveToTrashFolderBody': 'Esta pasta e todo o conteúdo serão movidos para a lixeira.',
  'moveToTrashListBody': 'Esta lista e todas as tarefas serão movidas para a lixeira.',
  'moveToTrashItemBody': 'Este item e dados relacionados serão movidos para a lixeira.',
  'restoreQuestion': 'Restaurar "{name}"?',
  'restoreBody': 'Será movido de volta para {destination}.',
  'deletePermanentlyQuestion': 'Excluir "{name}" permanentemente?',
  'taskName': 'Nome da tarefa', 'eventName': 'Nome do evento', 'note': 'Nota',
  'subtasks': 'Subtarefas', 'addSubtask': 'Adicionar subtarefa',
  'tags': 'Etiquetas', 'noTags': 'Sem etiquetas', 'addTag': 'Adicionar etiqueta',
  'createTag': 'Criar', 'searchOrCreateTag': 'Buscar ou criar etiqueta',
  'title': 'Título', 'folderName': 'Nome da pasta', 'listName': 'Nome da lista',
  'routineName': 'Nome da rotina',
  'duration': 'Duração', 'noDuration': 'Sem duração', 'noDate': 'Sem data',
  'setTime': 'Definir hora', 'dateLabel': 'Data', 'priority': 'Prioridade',
  'noFolder': 'Sem pasta', 'current': 'Atual', 'moveTo': 'Mover para',
  'info': 'Info', 'created': 'Criado', 'modified': 'Modificado',
  'completedLabel': 'Concluído',
  'priorityNone': 'Nenhuma', 'priorityLow': 'Baixa',
  'priorityMed': 'Média', 'priorityHigh': 'Alta',
  'changeIcon': 'Mudar ícone', 'changeColor': 'Mudar cor',
  'listColor': 'Cor da lista', 'customColor': 'Cor personalizada',
  'selectColor': 'Selecionar cor', 'otherDots': 'Outro…',
  'chooseIcon': 'Escolher ícone', 'opening': 'Abrindo…',
  'chooseFromLibrary': 'Escolher da biblioteca',
  'createFolder': 'Criar pasta', 'createList': 'Criar lista',
  'folder': 'Pasta', 'list': 'Lista',
  'newRoutine': 'Nova rotina', 'editRoutine': 'Editar rotina',
  'sectionFrequency': 'FREQUÊNCIA',
  'freqDaily': 'Diário', 'freqDaysAfter': 'X dias após concluir',
  'daysAfterCompletion': 'dias após concluir',
  'autoReset': 'Reinício automático', 'autoResetEveryDay': 'Todo dia',
  'autoResetNone': 'Não reiniciar',
  'sectionGoal': 'META',
  'goalAchieveAll': 'Concluir tudo', 'goalCertainAmount': 'Atingir quantidade',
  'dailyGoal': 'Meta diária', 'recordPerTap': 'Por toque',
  'unitName': 'Unidade', 'unitEgGlass': 'ex. copo',
  'noRoutinesToday': 'Sem rotinas hoje', 'noRoutinesYet': 'Ainda sem rotinas',
  'tapPlusFirstAdd': 'Toque + para adicionar sua primeira rotina',
  'tapPlusFirstCreate': 'Toque + para criar sua primeira rotina',
  'routinesToday': 'Hoje', 'routinesAll': 'Todas',
  'routinesTodaySection': 'HOJE',
  'deleteRoutine': 'Excluir rotina',
  'deleteRoutineConfirm': 'Excluir "{name}"? Todo o histórico também será removido.',
  'deleteRoutineBody': 'Todo o histórico também será removido.',
  'everyDayLabel': 'Todo dia',
  'chooseUnit': 'Escolher unidade', 'customDots': 'Personalizada…',
  'dayAfterCompletion': '{n} dia após concluir',
  'daysAfterCompletionN': '{n} dias após concluir',
  'noTasksOrEvents': 'Sem tarefas ou eventos',
  'deleteEventQuestion': 'Excluir evento?',
  'deleteEventBody': 'Este evento será removido permanentemente.',
  'insertLink': 'Inserir link',
  'insertLinkTextPlaceholder': 'Texto do link (opcional)',
};

const Map<String, String> _ru = {
  'appTitle': 'planom',
  'cancel': 'Отмена', 'done': 'Готово', 'ok': 'OK', 'add': 'Добавить',
  'create': 'Создать', 'save': 'Сохранить', 'delete': 'Удалить',
  'deleteAll': 'Удалить всё', 'edit': 'Изменить', 'rename': 'Переименовать',
  'confirm': 'Подтвердить', 'insert': 'Вставить', 'move': 'Переместить',
  'putBack': 'Восстановить', 'clear': 'Очистить', 'untitled': 'Без названия',
  'tabTasks': 'Задачи', 'tabNotes': 'Заметки', 'tabCalendar': 'Календарь',
  'tabRoutines': 'Привычки', 'tabSettings': 'Настройки',
  'inbox': 'Входящие', 'today': 'Сегодня', 'yesterday': 'Вчера', 'tomorrow': 'Завтра', 'upcoming': 'Предстоящие',
  'completed': 'Выполненные', 'trash': 'Корзина',
  'settings': 'Настройки',
  'sectionAppearance': 'Внешний вид', 'themeLight': 'Светлая',
  'themeSystem': 'Системная', 'themeDark': 'Тёмная',
  'theme': 'Тема', 'accentColor': 'Цвет акцента', 'completionColor': 'Цвет завершения',
  'sectionSmartLists': 'Умные списки', 'sectionCustomization': 'Настройка',
  'tabBar': 'Панель вкладок', 'sectionLanguage': 'Язык', 'language': 'Язык', 'font': 'Шрифт', 'searchFonts': 'Поиск шрифтов', 'systemFont': 'Системный', 'fontOfflineWarning': 'Офлайн — только кешированные шрифты', 'editPreviewText': 'Изменить текст примера', 'previewText': 'Текст примера',
  'sectionData': 'Данные',
  'exportBackup': 'Экспорт резервной копии', 'importBackup': 'Импорт резервной копии',
  'exportBackupSublabel': 'Planom (.planom) · полное восстановление',
  'importBackupSublabel': 'Planom (.planom) · заменяет все данные',
  'display': 'Отображение', 'hideLabels': 'Скрыть подписи',
  'visibleTabs': 'Видимые вкладки',
  'settingsAccessibleHint': 'Настройки доступны через меню (⋯) в каждой другой вкладке.',
  'visibility': 'Видимость',
  'visibilityShow': 'Показывать', 'visibilityIfNotEmpty': 'Если не пусто',
  'visibilityHidden': 'Скрыто', 'visibilityAlwaysShown': 'Всегда видно',
  'replaceAllData': 'Заменить все данные?',
  'replaceAllDataBody': 'Импорт навсегда заменит все текущие данные резервной копией. Это нельзя отменить.',
  'importSuccessful': 'Импорт успешен',
  'importSuccessfulBody': 'Ваши данные восстановлены из резервной копии.',
  'importFailed': 'Ошибка импорта',
  'importFailedInvalid': 'Выбранный файл не является действительной резервной копией Planom.',
  'importFailedRead': 'Произошла ошибка при чтении файла.',
  'exportFailed': 'Ошибка экспорта',
  'exportFailedBody': 'Произошла ошибка при создании резервной копии.',
  'newSpace': 'Новое пространство', 'spaceName': 'Название пространства',
  'sortTasks': 'Сортировать задачи', 'sortDefault': 'По умолчанию',
  'sortByCreation': 'По дате создания', 'sortByName': 'По имени',
  'sortByPriority': 'По приоритету', 'sortByDateTime': 'По дате и времени',
  'addToCalendar': 'Добавить в календарь', 'taskOption': 'Задача', 'eventOption': 'Событие',
  'noTasks': 'Нет задач', 'noTasksForToday': 'Нет задач на сегодня',
  'noUpcomingTasks': 'Нет предстоящих задач',
  'noCompletedTasks': 'Нет выполненных задач',
  'noItems': 'Нет элементов', 'noNotes': 'Нет заметок',
  'noListsInFolder': 'В этой папке нет списков',
  'trashIsEmpty': 'Корзина пуста',
  'emptyTrash': 'Очистить корзину', 'emptyTrashQuestion': 'Очистить корзину?',
  'emptyTrashBody': 'Все элементы в корзине будут удалены навсегда. Это нельзя отменить.',
  'cannotBeUndone': 'Это нельзя отменить.',
  'moveToTrashAction': 'В корзину',
  'moveToTrashQuestion': 'Переместить «{name}» в корзину?',
  'moveToTrashFolderBody': 'Папка и всё её содержимое будут перемещены в корзину.',
  'moveToTrashListBody': 'Список и все его задачи будут перемещены в корзину.',
  'moveToTrashItemBody': 'Элемент и связанные данные будут перемещены в корзину.',
  'restoreQuestion': 'Восстановить «{name}»?',
  'restoreBody': 'Будет восстановлено в {destination}.',
  'deletePermanentlyQuestion': 'Удалить «{name}» навсегда?',
  'taskName': 'Название задачи', 'eventName': 'Название события', 'note': 'Заметка',
  'subtasks': 'Подзадачи', 'addSubtask': 'Добавить подзадачу',
  'tags': 'Теги', 'noTags': 'Тегов пока нет', 'addTag': 'Добавить тег',
  'createTag': 'Создать', 'searchOrCreateTag': 'Найти или создать тег',
  'title': 'Заголовок', 'folderName': 'Название папки', 'listName': 'Название списка',
  'routineName': 'Название привычки',
  'duration': 'Длительность', 'noDuration': 'Без длительности', 'noDate': 'Без даты',
  'setTime': 'Указать время', 'dateLabel': 'Дата', 'priority': 'Приоритет',
  'noFolder': 'Без папки', 'current': 'Текущее', 'moveTo': 'Переместить в',
  'info': 'Информация', 'created': 'Создано', 'modified': 'Изменено',
  'completedLabel': 'Выполнено',
  'priorityNone': 'Нет', 'priorityLow': 'Низкий',
  'priorityMed': 'Средний', 'priorityHigh': 'Высокий',
  'changeIcon': 'Изменить значок', 'changeColor': 'Изменить цвет',
  'listColor': 'Цвет списка', 'customColor': 'Свой цвет',
  'selectColor': 'Выбрать цвет', 'otherDots': 'Другое…',
  'chooseIcon': 'Выбрать значок', 'opening': 'Открытие…',
  'chooseFromLibrary': 'Выбрать из библиотеки',
  'createFolder': 'Создать папку', 'createList': 'Создать список',
  'folder': 'Папка', 'list': 'Список',
  'newRoutine': 'Новая привычка', 'editRoutine': 'Редактировать',
  'sectionFrequency': 'ЧАСТОТА',
  'freqDaily': 'Ежедневно', 'freqDaysAfter': 'Через X дней после выполнения',
  'daysAfterCompletion': 'дней после выполнения',
  'autoReset': 'Автосброс', 'autoResetEveryDay': 'Каждый день',
  'autoResetNone': 'Не сбрасывать',
  'sectionGoal': 'ЦЕЛЬ',
  'goalAchieveAll': 'Выполнить всё', 'goalCertainAmount': 'Достичь количества',
  'dailyGoal': 'Дневная цель', 'recordPerTap': 'За одно нажатие',
  'unitName': 'Единица', 'unitEgGlass': 'напр. стакан',
  'noRoutinesToday': 'Сегодня привычек нет', 'noRoutinesYet': 'Пока нет привычек',
  'tapPlusFirstAdd': 'Нажмите +, чтобы добавить первую привычку',
  'tapPlusFirstCreate': 'Нажмите +, чтобы создать первую привычку',
  'routinesToday': 'Сегодня', 'routinesAll': 'Все',
  'routinesTodaySection': 'СЕГОДНЯ',
  'deleteRoutine': 'Удалить привычку',
  'deleteRoutineConfirm': 'Удалить «{name}»? Также будет удалена вся история.',
  'deleteRoutineBody': 'Также будет удалена вся история.',
  'everyDayLabel': 'Каждый день',
  'chooseUnit': 'Выбрать единицу', 'customDots': 'Свой…',
  'dayAfterCompletion': '{n} день после выполнения',
  'daysAfterCompletionN': '{n} дней после выполнения',
  'noTasksOrEvents': 'Нет задач или событий',
  'deleteEventQuestion': 'Удалить событие?',
  'deleteEventBody': 'Это событие будет удалено навсегда.',
  'insertLink': 'Вставить ссылку',
  'insertLinkTextPlaceholder': 'Текст ссылки (необязательно)',
};

const Map<String, String> _zh = {
  'appTitle': 'planom',
  'cancel': '取消', 'done': '完成', 'ok': '好', 'add': '添加',
  'create': '创建', 'save': '保存', 'delete': '删除',
  'deleteAll': '全部删除', 'edit': '编辑', 'rename': '重命名',
  'confirm': '确认', 'insert': '插入', 'move': '移动',
  'putBack': '恢复', 'clear': '清除', 'untitled': '无标题',
  'tabTasks': '任务', 'tabNotes': '笔记', 'tabCalendar': '日历',
  'tabRoutines': '习惯', 'tabSettings': '设置',
  'inbox': '收件箱', 'today': '今天', 'yesterday': '昨天', 'tomorrow': '明天', 'upcoming': '即将',
  'completed': '已完成', 'trash': '垃圾箱',
  'settings': '设置',
  'sectionAppearance': '外观', 'themeLight': '浅色',
  'themeSystem': '系统', 'themeDark': '深色',
  'theme': '主题', 'accentColor': '强调色', 'completionColor': '完成颜色',
  'sectionSmartLists': '智能列表', 'sectionCustomization': '自定义',
  'tabBar': '标签栏', 'sectionLanguage': '语言', 'language': '语言', 'font': '字体', 'searchFonts': '搜索字体', 'systemFont': '系统', 'fontOfflineWarning': '离线 — 仅显示已缓存字体', 'editPreviewText': '编辑预览文字', 'previewText': '预览文字',
  'sectionData': '数据',
  'exportBackup': '导出备份', 'importBackup': '导入备份',
  'exportBackupSublabel': 'Planom (.planom) · 完整恢复',
  'importBackupSublabel': 'Planom (.planom) · 替换所有数据',
  'display': '显示', 'hideLabels': '隐藏标签',
  'visibleTabs': '可见标签',
  'settingsAccessibleHint': '可从其他标签的菜单 (⋯) 中访问设置。',
  'visibility': '可见性',
  'visibilityShow': '显示', 'visibilityIfNotEmpty': '非空时显示',
  'visibilityHidden': '隐藏', 'visibilityAlwaysShown': '始终显示',
  'replaceAllData': '替换所有数据？',
  'replaceAllDataBody': '导入将永久替换所有当前数据。此操作无法撤销。',
  'importSuccessful': '导入成功',
  'importSuccessfulBody': '已从备份恢复您的数据。',
  'importFailed': '导入失败',
  'importFailedInvalid': '所选文件不是有效的 Planom 备份。',
  'importFailedRead': '读取文件时出错。',
  'exportFailed': '导出失败',
  'exportFailedBody': '创建备份时出错。',
  'newSpace': '新空间', 'spaceName': '空间名称',
  'sortTasks': '排序任务', 'sortDefault': '默认',
  'sortByCreation': '按创建日期', 'sortByName': '按名称',
  'sortByPriority': '按优先级', 'sortByDateTime': '按日期和时间',
  'addToCalendar': '添加到日历', 'taskOption': '任务', 'eventOption': '事件',
  'noTasks': '没有任务', 'noTasksForToday': '今天没有任务',
  'noUpcomingTasks': '没有即将到来的任务',
  'noCompletedTasks': '没有已完成的任务',
  'noItems': '没有项目', 'noNotes': '没有笔记',
  'noListsInFolder': '此文件夹中没有列表',
  'trashIsEmpty': '垃圾箱为空',
  'emptyTrash': '清空垃圾箱', 'emptyTrashQuestion': '清空垃圾箱？',
  'emptyTrashBody': '垃圾箱中的所有项目将被永久删除。此操作无法撤销。',
  'cannotBeUndone': '此操作无法撤销。',
  'moveToTrashAction': '移到垃圾箱',
  'moveToTrashQuestion': '将"{name}"移到垃圾箱？',
  'moveToTrashFolderBody': '此文件夹及其全部内容将被移到垃圾箱。',
  'moveToTrashListBody': '此列表及其所有任务将被移到垃圾箱。',
  'moveToTrashItemBody': '此项目及相关数据将被移到垃圾箱。',
  'restoreQuestion': '恢复"{name}"？',
  'restoreBody': '将被恢复到 {destination}。',
  'deletePermanentlyQuestion': '永久删除"{name}"？',
  'taskName': '任务名称', 'eventName': '事件名称', 'note': '笔记',
  'subtasks': '子任务', 'addSubtask': '添加子任务',
  'tags': '标签', 'noTags': '暂无标签', 'addTag': '添加标签',
  'createTag': '创建', 'searchOrCreateTag': '搜索或创建标签',
  'title': '标题', 'folderName': '文件夹名称', 'listName': '列表名称',
  'routineName': '习惯名称',
  'duration': '时长', 'noDuration': '无时长', 'noDate': '无日期',
  'setTime': '设置时间', 'dateLabel': '日期', 'priority': '优先级',
  'noFolder': '无文件夹', 'current': '当前', 'moveTo': '移动到',
  'info': '信息', 'created': '创建于', 'modified': '修改于',
  'completedLabel': '完成于',
  'priorityNone': '无', 'priorityLow': '低',
  'priorityMed': '中', 'priorityHigh': '高',
  'changeIcon': '更改图标', 'changeColor': '更改颜色',
  'listColor': '列表颜色', 'customColor': '自定义颜色',
  'selectColor': '选择颜色', 'otherDots': '其他…',
  'chooseIcon': '选择图标', 'opening': '打开中…',
  'chooseFromLibrary': '从图库选择',
  'createFolder': '创建文件夹', 'createList': '创建列表',
  'folder': '文件夹', 'list': '列表',
  'newRoutine': '新习惯', 'editRoutine': '编辑习惯',
  'sectionFrequency': '频率',
  'freqDaily': '每天', 'freqDaysAfter': '完成后 X 天',
  'daysAfterCompletion': '完成后天数',
  'autoReset': '自动重置', 'autoResetEveryDay': '每天',
  'autoResetNone': '不重置',
  'sectionGoal': '目标',
  'goalAchieveAll': '全部完成', 'goalCertainAmount': '达到一定数量',
  'dailyGoal': '每日目标', 'recordPerTap': '每次点击记录',
  'unitName': '单位', 'unitEgGlass': '例如：杯',
  'noRoutinesToday': '今天没有习惯', 'noRoutinesYet': '还没有习惯',
  'tapPlusFirstAdd': '点击 + 添加第一个习惯',
  'tapPlusFirstCreate': '点击 + 创建第一个习惯',
  'routinesToday': '今天', 'routinesAll': '全部',
  'routinesTodaySection': '今天',
  'deleteRoutine': '删除习惯',
  'deleteRoutineConfirm': '删除"{name}"？所有记录历史也将被删除。',
  'deleteRoutineBody': '所有记录历史也将被删除。',
  'everyDayLabel': '每天',
  'chooseUnit': '选择单位', 'customDots': '自定义…',
  'dayAfterCompletion': '完成后 {n} 天',
  'daysAfterCompletionN': '完成后 {n} 天',
  'noTasksOrEvents': '没有任务或事件',
  'deleteEventQuestion': '删除事件？',
  'deleteEventBody': '此事件将被永久删除。',
  'insertLink': '插入链接',
  'insertLinkTextPlaceholder': '链接文本（可选）',
};

const Map<String, String> _ja = {
  'appTitle': 'planom',
  'cancel': 'キャンセル', 'done': '完了', 'ok': 'OK', 'add': '追加',
  'create': '作成', 'save': '保存', 'delete': '削除',
  'deleteAll': 'すべて削除', 'edit': '編集', 'rename': '名前変更',
  'confirm': '確認', 'insert': '挿入', 'move': '移動',
  'putBack': '戻す', 'clear': 'クリア', 'untitled': '無題',
  'tabTasks': 'タスク', 'tabNotes': 'ノート', 'tabCalendar': 'カレンダー',
  'tabRoutines': '習慣', 'tabSettings': '設定',
  'inbox': '受信箱', 'today': '今日', 'yesterday': '昨日', 'tomorrow': '明日', 'upcoming': '今後',
  'completed': '完了済み', 'trash': 'ゴミ箱',
  'settings': '設定',
  'sectionAppearance': '外観', 'themeLight': 'ライト',
  'themeSystem': 'システム', 'themeDark': 'ダーク',
  'theme': 'テーマ', 'accentColor': 'アクセントカラー', 'completionColor': '完了カラー',
  'sectionSmartLists': 'スマートリスト', 'sectionCustomization': 'カスタマイズ',
  'tabBar': 'タブバー', 'sectionLanguage': '言語', 'language': '言語', 'font': 'フォント', 'searchFonts': 'フォントを検索', 'systemFont': 'システム', 'fontOfflineWarning': 'オフライン — キャッシュ済みフォントのみ', 'editPreviewText': 'プレビューテキストを編集', 'previewText': 'プレビューテキスト',
  'sectionData': 'データ',
  'exportBackup': 'バックアップを書き出す', 'importBackup': 'バックアップを読み込む',
  'exportBackupSublabel': 'Planom (.planom) · 完全復元',
  'importBackupSublabel': 'Planom (.planom) · 全データを置換',
  'display': '表示', 'hideLabels': 'ラベルを隠す',
  'visibleTabs': '表示するタブ',
  'settingsAccessibleHint': '設定は他のタブのメニュー (⋯) からアクセスできます。',
  'visibility': '表示',
  'visibilityShow': '表示', 'visibilityIfNotEmpty': '空でない場合',
  'visibilityHidden': '非表示', 'visibilityAlwaysShown': '常に表示',
  'replaceAllData': 'すべてのデータを置き換えますか？',
  'replaceAllDataBody': '読み込むと現在のすべてのデータが完全に置き換えられます。元に戻せません。',
  'importSuccessful': '読み込み完了',
  'importSuccessfulBody': 'バックアップからデータを復元しました。',
  'importFailed': '読み込み失敗',
  'importFailedInvalid': '選択したファイルは有効な Planom バックアップではありません。',
  'importFailedRead': 'ファイルの読み込み中にエラーが発生しました。',
  'exportFailed': '書き出し失敗',
  'exportFailedBody': 'バックアップの作成中にエラーが発生しました。',
  'newSpace': '新規スペース', 'spaceName': 'スペース名',
  'sortTasks': 'タスクを並べ替え', 'sortDefault': 'デフォルト',
  'sortByCreation': '作成日順', 'sortByName': '名前順',
  'sortByPriority': '優先度順', 'sortByDateTime': '日時順',
  'addToCalendar': 'カレンダーに追加', 'taskOption': 'タスク', 'eventOption': 'イベント',
  'noTasks': 'タスクなし', 'noTasksForToday': '今日のタスクなし',
  'noUpcomingTasks': '今後のタスクなし',
  'noCompletedTasks': '完了したタスクなし',
  'noItems': '項目なし', 'noNotes': 'ノートなし',
  'noListsInFolder': 'このフォルダにリストはありません',
  'trashIsEmpty': 'ゴミ箱は空です',
  'emptyTrash': 'ゴミ箱を空にする', 'emptyTrashQuestion': 'ゴミ箱を空にしますか？',
  'emptyTrashBody': 'ゴミ箱内のすべての項目が完全に削除されます。元に戻せません。',
  'cannotBeUndone': 'この操作は元に戻せません。',
  'moveToTrashAction': 'ゴミ箱へ移動',
  'moveToTrashQuestion': '「{name}」をゴミ箱へ移動しますか？',
  'moveToTrashFolderBody': 'このフォルダとすべての内容がゴミ箱へ移動されます。',
  'moveToTrashListBody': 'このリストとすべてのタスクがゴミ箱へ移動されます。',
  'moveToTrashItemBody': 'この項目と関連データがゴミ箱へ移動されます。',
  'restoreQuestion': '「{name}」を復元しますか？',
  'restoreBody': '{destination} に戻されます。',
  'deletePermanentlyQuestion': '「{name}」を完全に削除しますか？',
  'taskName': 'タスク名', 'eventName': 'イベント名', 'note': 'ノート',
  'subtasks': 'サブタスク', 'addSubtask': 'サブタスクを追加',
  'tags': 'タグ', 'noTags': 'タグがありません', 'addTag': 'タグを追加',
  'createTag': '作成', 'searchOrCreateTag': 'タグを検索または作成',
  'title': 'タイトル', 'folderName': 'フォルダ名', 'listName': 'リスト名',
  'routineName': '習慣名',
  'duration': '所要時間', 'noDuration': '所要時間なし', 'noDate': '日付なし',
  'setTime': '時刻を設定', 'dateLabel': '日付', 'priority': '優先度',
  'noFolder': 'フォルダなし', 'current': '現在', 'moveTo': '移動先',
  'info': '情報', 'created': '作成日', 'modified': '更新日',
  'completedLabel': '完了日',
  'priorityNone': 'なし', 'priorityLow': '低',
  'priorityMed': '中', 'priorityHigh': '高',
  'changeIcon': 'アイコンを変更', 'changeColor': '色を変更',
  'listColor': 'リストの色', 'customColor': 'カスタムカラー',
  'selectColor': '色を選択', 'otherDots': 'その他…',
  'chooseIcon': 'アイコンを選択', 'opening': '開いています…',
  'chooseFromLibrary': 'ライブラリから選択',
  'createFolder': 'フォルダを作成', 'createList': 'リストを作成',
  'folder': 'フォルダ', 'list': 'リスト',
  'newRoutine': '新しい習慣', 'editRoutine': '習慣を編集',
  'sectionFrequency': '頻度',
  'freqDaily': '毎日', 'freqDaysAfter': '完了から X 日後',
  'daysAfterCompletion': '完了からの日数',
  'autoReset': '自動リセット', 'autoResetEveryDay': '毎日',
  'autoResetNone': 'リセットしない',
  'sectionGoal': '目標',
  'goalAchieveAll': 'すべて達成', 'goalCertainAmount': '一定量に達する',
  'dailyGoal': '1日の目標', 'recordPerTap': 'タップごとに記録',
  'unitName': '単位', 'unitEgGlass': '例: グラス',
  'noRoutinesToday': '今日の習慣はありません', 'noRoutinesYet': 'まだ習慣がありません',
  'tapPlusFirstAdd': '＋ をタップして最初の習慣を追加',
  'tapPlusFirstCreate': '＋ をタップして最初の習慣を作成',
  'routinesToday': '今日', 'routinesAll': 'すべて',
  'routinesTodaySection': '今日',
  'deleteRoutine': '習慣を削除',
  'deleteRoutineConfirm': '「{name}」を削除しますか？記録もすべて削除されます。',
  'deleteRoutineBody': '記録もすべて削除されます。',
  'everyDayLabel': '毎日',
  'chooseUnit': '単位を選択', 'customDots': 'カスタム…',
  'dayAfterCompletion': '完了から {n} 日後',
  'daysAfterCompletionN': '完了から {n} 日後',
  'noTasksOrEvents': 'タスクやイベントはありません',
  'deleteEventQuestion': 'イベントを削除しますか？',
  'deleteEventBody': 'このイベントは完全に削除されます。',
  'insertLink': 'リンクを挿入',
  'insertLinkTextPlaceholder': 'リンクテキスト（任意）',
};
