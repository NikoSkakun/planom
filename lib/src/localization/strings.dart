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
  String get allTasks => t('allTasks');
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
  String get spaces => t('spaces');
  String get noOptionsYet => t('noOptionsYet');
  String get sectionModules => t('sectionModules');
  String get sectionTaskFields => t('sectionTaskFields');
  String get taskFieldsHint => t('taskFieldsHint');
  String get sectionBody => t('sectionBody');
  String get useMarkdown => t('useMarkdown');
  String get useMarkdownHint => t('useMarkdownHint');
  String get storage => t('storage');
  String get storageSublabel => t('storageSublabel');
  String get storageAppCaches => t('storageAppCaches');
  String get storageCustomIcons => t('storageCustomIcons');
  String get storageFontsCache => t('storageFontsCache');
  String get storageTempCache => t('storageTempCache');
  String get storageClearOrphans => t('storageClearOrphans');
  String get storageFoldersLists => t('storageFoldersLists');
  String get storageTotal => t('storageTotal');
  String get storageItemsSuffix => t('storageItemsSuffix');
  String get storageFilesSuffix => t('storageFilesSuffix');
  String storageDataIn(String space) =>
      t('storageDataIn').replaceFirst('{space}', space);
  String get space => t('space');
  String get clearFontsCacheQ => t('clearFontsCacheQ');
  String get clearFontsCacheBody => t('clearFontsCacheBody');
  String get clearTempCacheQ => t('clearTempCacheQ');
  String get clearTempCacheBody => t('clearTempCacheBody');
  String get clearOrphanIconsQ => t('clearOrphanIconsQ');
  String get clearOrphanIconsBody => t('clearOrphanIconsBody');
  String get showHidePriority => t('showHidePriority');
  String get showHideDate => t('showHideDate');
  String get showHideRepeat => t('showHideRepeat');
  String get showHideList => t('showHideList');
  String get showHideDuration => t('showHideDuration');
  String get showHideTags => t('showHideTags');
  String get showHideReminders => t('showHideReminders');
  String get sectionTasksUi => t('sectionTasksUi');
  String get showAddFolderButton => t('showAddFolderButton');
  String get sectionTaskCounters => t('sectionTaskCounters');
  String get folderCounter => t('folderCounter');
  String get folderCounterDirect => t('folderCounterDirect');
  String get folderCounterRecursive => t('folderCounterRecursive');
  String get folderCounterHidden => t('folderCounterHidden');
  String get checkboxStyle => t('checkboxStyle');
  String get checkboxStyleRoundedRect => t('checkboxStyleRoundedRect');
  String get checkboxStyleSharpRect => t('checkboxStyleSharpRect');
  String get checkboxStyleCircle => t('checkboxStyleCircle');
  String get undoOnComplete => t('undoOnComplete');
  String get undoOnCompleteHint => t('undoOnCompleteHint');
  String get firstDayOfWeek => t('firstDayOfWeek');
  String get calendarView => t('calendarView');
  String get calendarViewMonths => t('calendarViewMonths');
  String get calendarViewContinuous => t('calendarViewContinuous');
  String get appBadge => t('appBadge');
  String get appBadgeMode => t('appBadgeMode');
  String get appBadgeHint => t('appBadgeHint');
  String get appBadgeNone => t('appBadgeNone');
  String get appBadgeTodayTasks => t('appBadgeTodayTasks');
  String get appBadgeTodayTasksAndEvents => t('appBadgeTodayTasksAndEvents');
  String get appBadgeInbox => t('appBadgeInbox');
  String get appBadgeAllUncompleted => t('appBadgeAllUncompleted');
  String get appBadgeIncludeRoutines => t('appBadgeIncludeRoutines');
  String get showRoutinesInToday => t('showRoutinesInToday');
  String get showRoutinesInCalendar => t('showRoutinesInCalendar');
  String get showRoutinesHint => t('showRoutinesHint');
  String get sectionShowRoutines => t('sectionShowRoutines');
  String get sectionDefaults => t('sectionDefaults');
  String get defaultTaskIcon => t('defaultTaskIcon');
  String get defaultListIcon => t('defaultListIcon');
  String get defaultFolderIcon => t('defaultFolderIcon');
  String get defaultNoteFolderIcon => t('defaultNoteFolderIcon');
  String get textSize => t('textSize');
  String get useSystemTextSize => t('useSystemTextSize');
  String get textSizeHint => t('textSizeHint');
  String get animationSpeed => t('animationSpeed');
  String get animationSpeedHint => t('animationSpeedHint');
  String get animationSpeedOff => t('animationSpeedOff');
  String get animationSpeedFast => t('animationSpeedFast');
  String get animationSpeedNormal => t('animationSpeedNormal');
  String get animationSpeedSlow => t('animationSpeedSlow');
  String get tabBarPages => t('tabBarPages');
  String get tabBarPagesHint => t('tabBarPagesHint');
  String get addPage => t('addPage');
  String get removePageTitle => t('removePageTitle');
  String get removePageBody => t('removePageBody');
  String get addTab => t('addTab');
  String get tabKindBuiltin => t('tabKindBuiltin');
  String get tabKindShortcut => t('tabKindShortcut');
  String get tabShortcutList => t('tabShortcutList');
  String get tabShortcutFolder => t('tabShortcutFolder');
  String get tabShortcutNoteFolder => t('tabShortcutNoteFolder');
  String pageNumberLabel(int n) =>
      t('pageNumberLabel').replaceFirst('{n}', n.toString());
  String get showListCount => t('showListCount');
  String get revert => t('revert');
  String get taskCompletedToast => t('taskCompletedToast');
  String get taskTrashedToast => t('taskTrashedToast');
  String get listTrashedToast => t('listTrashedToast');
  String get folderTrashedToast => t('folderTrashedToast');
  String get noteTrashedToast => t('noteTrashedToast');
  String get noteFolderTrashedToast => t('noteFolderTrashedToast');
  String get eventDeletedToast => t('eventDeletedToast');
  String get iconColor => t('iconColor');
  String get useAccentColor => t('useAccentColor');
  String get todayShort => t('todayShort');
  String get tomorrowShort => t('tomorrowShort');
  String get addList => t('addList');
  String get addFolder => t('addFolder');
  String get addNote => t('addNote');
  String get share => t('share');
  String get shareAsText => t('shareAsText');
  String get shareAsPdf => t('shareAsPdf');
  String get shareAsImage => t('shareAsImage');
  String get preparingPdf => t('preparingPdf');
  String get preparingImage => t('preparingImage');
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
  String get useBiometric => t('useBiometric');
  String get unlockPrompt => t('unlockPrompt');
  String get exportPlain => t('exportPlain');
  String get exportEncrypted => t('exportEncrypted');
  String get setPassphrase => t('setPassphrase');
  String get enterPassphrase => t('enterPassphrase');
  String get passwordRequired => t('passwordRequired');
  String get search => t('search');
  String get searchPlaceholder => t('searchPlaceholder');
  String get searchEmptyHint => t('searchEmptyHint');
  String get searchNoResults => t('searchNoResults');

  // ── Sync ──────────────────────────────────────────────────────────────
  String get sync => t('sync');
  String get syncFreeSection => t('syncFreeSection');
  String get syncPaidSection => t('syncPaidSection');
  String get syncStatusSection => t('syncStatusSection');
  String get syncEncryptionSection => t('syncEncryptionSection');
  String get syncEncryptionLabel => t('syncEncryptionLabel');
  String get syncEncryptionOn => t('syncEncryptionOn');
  String get syncEncryptionOff => t('syncEncryptionOff');
  String get removeEncryption => t('removeEncryption');
  String get removeEncryptionBody => t('removeEncryptionBody');
  String get syncDefaultEncryptionHint => t('syncDefaultEncryptionHint');
  String get syncICloudTitle => t('syncICloudTitle');
  String get syncICloudSublabel => t('syncICloudSublabel');
  String get syncPlanomTitle => t('syncPlanomTitle');
  String get syncPlanomSublabel => t('syncPlanomSublabel');
  String get syncCustomTitle => t('syncCustomTitle');
  String get syncCustomSublabel => t('syncCustomSublabel');
  String get tagFree => t('tagFree');
  String get tagComingSoon => t('tagComingSoon');
  String get syncStatusLabel => t('syncStatusLabel');
  String get syncNow => t('syncNow');
  String get syncPullReplace => t('syncPullReplace');
  String get disableSync => t('disableSync');
  String get disableSyncBody => t('disableSyncBody');
  String get pullReplacesLocal => t('pullReplacesLocal');
  String get syncPassphraseHint => t('syncPassphraseHint');
  String get syncPassphraseLossHint => t('syncPassphraseLossHint');
  String get syncNever => t('syncNever');
  String get syncPushing => t('syncPushing');
  String get syncPulling => t('syncPulling');
  String get syncSucceeded => t('syncSucceeded');
  String get syncFailed => t('syncFailed');
  String get syncNotConfigured => t('syncNotConfigured');
  String get syncPassphraseRequired => t('syncPassphraseRequired');
  String get syncNotAvailable => t('syncNotAvailable');
  String syncLastAt(String relative) =>
      t('syncLastAt').replaceAll('{when}', relative);

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
  String get calendarAllowCreatingTasks => t('calendarAllowCreatingTasks');
  String get calendarAllowCreatingEvents => t('calendarAllowCreatingEvents');
  String get calendarDefaultContainer => t('calendarDefaultContainer');
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
  String get repeat => t('repeat');
  String get repeatNone => t('repeatNone');
  String get repeatDaily => t('repeatDaily');
  String get repeatWeekly => t('repeatWeekly');
  String get repeatMonthly => t('repeatMonthly');
  String get repeatYearly => t('repeatYearly');
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
  String get editList => t('editList');
  String get editFolder => t('editFolder');
  String get listColor => t('listColor');
  String get listType => t('listType');
  String get listTypeTasks => t('listTypeTasks');
  String get listTypeBirthdays => t('listTypeBirthdays');
  String get listTypeShopping => t('listTypeShopping');
  String get addBirthday => t('addBirthday');
  String get birthdayName => t('birthdayName');
  String get birthDate => t('birthDate');
  String get includeYear => t('includeYear');
  String get completable => t('completable');
  String get thisYear => t('thisYear');
  String get nextYear => t('nextYear');
  String get addSection => t('addSection');
  String get sectionName => t('sectionName');
  String get sectionCompleted => t('sectionCompleted');
  String get turns => t('turns');
  String get customColor => t('customColor');
  String get selectColor => t('selectColor');
  String get select => t('select');
  String get selectAll => t('selectAll');
  String get deselectAll => t('deselectAll');
  String get selectItems => t('selectItems');
  String selectedCount(int n) => t('selectedCount').replaceFirst('{n}', '$n');
  String get duplicate => t('duplicate');
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
  String get freqSpecificDays => t('freqSpecificDays');
  String get freqInterval => t('freqInterval');
  String get freqDaysAfter => t('freqDaysAfter');
  String get startDate => t('startDate');
  String get routineIntervalEvery => t('routineIntervalEvery');
  String routineIntervalDays(int n) =>
      t('routineIntervalDays').replaceAll('{n}', '$n');
  String get waitForCompletion => t('waitForCompletion');
  String get waitForCompletionInfo => t('waitForCompletionInfo');
  String get addReminder => t('addReminder');
  String get reminderTypeTime => t('reminderTypeTime');
  String get reminderTypeSpread => t('reminderTypeSpread');
  String get reminderTypeAfterEach => t('reminderTypeAfterEach');
  String get reminderEveryLabel => t('reminderEveryLabel');
  String get reminderAfterEachLabel => t('reminderAfterEachLabel');
  String get recordOnOriginalDate => t('recordOnOriginalDate');
  String get completeTodayShift => t('completeTodayShift');
  String get overdueRoutineTitle => t('overdueRoutineTitle');
  String get overdueRoutineBody => t('overdueRoutineBody');
  String get overdueLabel => t('overdueLabel');
  String get daysAfterCompletion => t('daysAfterCompletion');
  String get autoReset => t('autoReset');
  String get autoResetEveryDay => t('autoResetEveryDay');
  String get autoResetNone => t('autoResetNone');
  String get sectionGoal => t('sectionGoal');
  String get goalAchieveAll => t('goalAchieveAll');
  String get goalCertainAmount => t('goalCertainAmount');
  String get dailyGoal => t('dailyGoal');
  String get recordPerTap => t('recordPerTap');
  String get recordManual => t('recordManual');
  String get recordManualInfo => t('recordManualInfo');
  String recordAmountPrompt(String unit) =>
      t('recordAmountPrompt').replaceAll('{unit}', unit);
  String get showEventsInToday => t('showEventsInToday');
  String get includeInTodayCount => t('includeInTodayCount');
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

  // ── Google Calendar integration ──────────────────────────────────────────
  String get sectionIntegrations => t('sectionIntegrations');
  String get googleCalendar => t('googleCalendar');
  String get googleCalendarOn => t('googleCalendarOn');
  String get googleCalendarOff => t('googleCalendarOff');
  String get googleCalendarConnect => t('googleCalendarConnect');
  String get googleCalendarConnected => t('googleCalendarConnected');
  String get googleCalendarDisconnect => t('googleCalendarDisconnect');
  String get googleCalendarDisconnectBody => t('googleCalendarDisconnectBody');
  String get googleCalendarCalendarsSection =>
      t('googleCalendarCalendarsSection');
  String get googleCalendarNoCalendars => t('googleCalendarNoCalendars');
  String get googleCalendarPrimary => t('googleCalendarPrimary');
  String get googleCalendarReadOnly => t('googleCalendarReadOnly');
  String get googleCalendarDefaultBadge => t('googleCalendarDefaultBadge');
  String get googleCalendarDefault => t('googleCalendarDefault');
  String get googleCalendarDefaultSection => t('googleCalendarDefaultSection');
  String get googleCalendarNoDefault => t('googleCalendarNoDefault');
  String get googleCalendarSyncSection => t('googleCalendarSyncSection');
  String get googleCalendarSyncNow => t('googleCalendarSyncNow');
  String get googleCalendarNeverSynced => t('googleCalendarNeverSynced');
  String get googleCalendarLastSynced => t('googleCalendarLastSynced');
  String get googleCalendarSetupRequired => t('googleCalendarSetupRequired');
  String get googleCalendarReadOnlyHint => t('googleCalendarReadOnlyHint');
  String get googleCalendarReminderHint => t('googleCalendarReminderHint');
  String get googleCalendarDeleteBody => t('googleCalendarDeleteBody');
  String get googleCalendarAddAccount => t('googleCalendarAddAccount');
  String get googleCalendarAccountsSection => t('googleCalendarAccountsSection');
  String get googleCalendarRemoveAccount => t('googleCalendarRemoveAccount');
  String get googleCalendarRemoveAccountBody =>
      t('googleCalendarRemoveAccountBody');
  String get googleCalendarReadWrite => t('googleCalendarReadWrite');
  String get googleCalendarReadOnlyMode => t('googleCalendarReadOnlyMode');
  String get googleCalendarChooseMode => t('googleCalendarChooseMode');
  String get googleCalendarReadWriteDesc => t('googleCalendarReadWriteDesc');
  String get googleCalendarReadOnlyDesc => t('googleCalendarReadOnlyDesc');
  String get planomLocal => t('planomLocal');
  String get eventCalendar => t('eventCalendar');

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

/// Reorders a Mon..Sun weekday list so [firstDayOfWeek] (1=Mon..7=Sun) is the
/// first element. Used by the calendar header so the column order matches the
/// user's preference.
List<T> rotateWeekdays<T>(List<T> mondayFirst, int firstDayOfWeek) {
  final shift = ((firstDayOfWeek - 1) % 7 + 7) % 7;
  if (shift == 0) return mondayFirst;
  return [...mondayFirst.sublist(shift), ...mondayFirst.sublist(0, shift)];
}

/// Column index (0..6) for a [DateTime] given [firstDayOfWeek] (1=Mon..7=Sun).
/// E.g. firstDayOfWeek=1 (Mon): Mon→0, Sun→6. firstDayOfWeek=7 (Sun): Sun→0,
/// Sat→6.
int weekdayColumn(DateTime date, int firstDayOfWeek) {
  final mondayIndex = date.weekday - 1; // 0=Mon..6=Sun
  final shift = ((firstDayOfWeek - 1) % 7 + 7) % 7;
  return (mondayIndex - shift + 7) % 7;
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
  'select': 'Select', 'selectAll': 'Select All', 'deselectAll': 'Deselect All',
  'selectItems': 'Select Items', 'selectedCount': '{n} selected',
  'duplicate': 'Duplicate',
  'tabTasks': 'Tasks', 'tabNotes': 'Notes', 'tabCalendar': 'Calendar',
  'tabRoutines': 'Routines', 'tabSettings': 'Settings',
  'inbox': 'Inbox', 'today': 'Today', 'yesterday': 'Yesterday', 'tomorrow': 'Tomorrow', 'upcoming': 'Upcoming',
  'allTasks': 'All Tasks',
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
  'newSpace': 'New Space', 'spaceName': 'Space name', 'spaces': 'Spaces',
  'noOptionsYet': 'No options yet.', 'sectionModules': 'MODULES',
  'appBadgeIncludeRoutines': 'Include today\'s routines', 'showRoutinesInToday': 'Show routines in Today', 'showRoutinesInCalendar': 'Show routines in Calendar', 'showRoutinesHint': 'Today\'s routines appear as a collapsible section in Tasks → Today and in the Calendar day view.', 'sectionShowRoutines': 'SHOW ROUTINES IN',
  'sectionTaskFields': 'TASK FIELDS',
  'taskFieldsHint': 'Hidden fields are not shown when editing a task.',
  'sectionBody': 'BODY', 'useMarkdown': 'Format with Markdown',
  'useMarkdownHint': 'When off, the body is shown and edited as plain text and the formatting toolbar is hidden.',
  'storage': 'Storage',
  'storageSublabel': "Disk usage by category · clear caches",
  'storageAppCaches': 'APP CACHES',
  'storageCustomIcons': 'Custom icons',
  'storageFontsCache': 'Fonts cache',
  'storageTempCache': 'Temporary files',
  'storageClearOrphans': 'Clear orphans',
  'storageFoldersLists': 'Folders & lists',
  'storageTotal': 'Total',
  'storageItemsSuffix': 'items',
  'storageFilesSuffix': 'files',
  'storageDataIn': 'DATA IN {space}',
  'space': 'Space',
  'clearFontsCacheQ': 'Clear fonts cache?',
  'clearFontsCacheBody':
      'Removes cached Google Fonts files. They will be re-downloaded when needed.',
  'clearTempCacheQ': 'Clear temporary files?',
  'clearTempCacheBody':
      'Removes the OS temporary directory. Doesn\'t affect saved data.',
  'clearOrphanIconsQ': 'Clear orphan icons?',
  'clearOrphanIconsBody':
      'Removes custom icon files that are no longer referenced by any folder or list across every space.',
  'showHidePriority': 'Priority', 'showHideDate': 'Date',
  'showHideRepeat': 'Repeat', 'showHideList': 'List',
  'showHideDuration': 'Duration', 'showHideTags': 'Tags',
  'showHideReminders': 'Reminders',
  'sectionTasksUi': 'INTERFACE',
  'showAddFolderButton': 'Add-folder button',
  'sectionTaskCounters': 'COUNTERS',
  'folderCounter': 'Folder counter',
  'folderCounterDirect': 'Direct tasks only',
  'folderCounterRecursive': 'Include nested folders',
  'folderCounterHidden': 'Hidden',
  'checkboxStyle': 'Checkbox style',
  'checkboxStyleRoundedRect': 'Rounded square',
  'checkboxStyleSharpRect': 'Square',
  'checkboxStyleCircle': 'Circle',
  'undoOnComplete': 'Undo on completion',
  'undoOnCompleteHint':
      'Show a brief Undo banner when you check a task off, so an accidental tap is easy to reverse.',
  'firstDayOfWeek': 'First day of week',
  'calendarView': 'View',
  'calendarViewMonths': 'Months',
  'calendarViewContinuous': 'Continuous',
  'appBadge': 'APP ICON BADGE',
  'appBadgeMode': 'Show as badge',
  'appBadgeHint': 'The number shown on the app icon on your home screen.',
  'appBadgeNone': 'None',
  'appBadgeTodayTasks': "Today's uncompleted tasks",
  'appBadgeTodayTasksAndEvents': "Today's tasks + upcoming events",
  'appBadgeInbox': 'Inbox uncompleted',
  'appBadgeAllUncompleted': 'All uncompleted tasks',
  'sectionDefaults': 'DEFAULTS',
  'defaultTaskIcon': 'Default task icon',
  'defaultListIcon': 'Default list icon',
  'defaultFolderIcon': 'Default folder icon',
  'defaultNoteFolderIcon': 'Default folder icon',
  'textSize': 'Text size',
  'useSystemTextSize': 'Use system text size',
  'textSizeHint': 'Scales all text in the app. UI elements next to text grow with the chosen size.',
  'animationSpeed': 'Animation speed',
  'animationSpeedHint': 'Controls how fast page transitions, list reorders, drag and other UI animations play. Choose Off for immediate, snap-style transitions.',
  'animationSpeedOff': 'Off',
  'animationSpeedFast': 'Fast',
  'animationSpeedNormal': 'Normal',
  'animationSpeedSlow': 'Slow',
  'tabBarPages': 'Tab Bar Pages',
  'tabBarPagesHint': 'Add more pages to fit more than 5 tabs. Swipe horizontally on the tab bar to switch between pages.',
  'addPage': 'Add page',
  'removePageTitle': 'Remove page?',
  'removePageBody': 'All tabs on this page will be removed too.',
  'addTab': 'Add tab',
  'tabKindBuiltin': 'Built-in tab',
  'tabKindShortcut': 'Shortcut',
  'tabShortcutList': 'List…',
  'tabShortcutFolder': 'Folder…',
  'tabShortcutNoteFolder': 'Note folder…',
  'pageNumberLabel': 'PAGE {n}',
  'showListCount': 'List counter',
  'revert': 'Undo',
  'taskCompletedToast': 'Task completed',
  'taskTrashedToast': 'Task moved to Trash',
  'listTrashedToast': 'List moved to Trash',
  'folderTrashedToast': 'Folder moved to Trash',
  'noteTrashedToast': 'Note moved to Trash',
  'noteFolderTrashedToast': 'Folder moved to Trash',
  'eventDeletedToast': 'Event deleted',
  'iconColor': 'Icon Color',
  'useAccentColor': 'Use Accent Color',
  'todayShort': 'Today',
  'tomorrowShort': 'Tomorrow',
  'addList': 'Add List', 'addFolder': 'Add Folder', 'addNote': 'Add Note',
  'share': 'Share', 'shareAsText': 'Plain Text',
  'shareAsPdf': 'PDF', 'shareAsImage': 'Image',
  'preparingPdf': 'Preparing PDF…',
  'preparingImage': 'Preparing image…',
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
  'useBiometric': 'Use Face ID / Touch ID',
  'unlockPrompt': 'Unlock Planom',
  'exportPlain': 'Plain backup',
  'exportEncrypted': 'Encrypted with passphrase…',
  'setPassphrase': 'Set passphrase',
  'enterPassphrase': 'Enter passphrase',
  'passwordRequired': 'Password is required',
  'search': 'Search', 'searchPlaceholder': 'Search tasks, notes, events',
  'searchEmptyHint': 'Type to search across tasks, notes, and events.',
  'searchNoResults': 'No matches.',
  'sync': 'Sync',
  'syncFreeSection': 'Free',
  'syncPaidSection': 'Cross-device',
  'syncStatusSection': 'Status',
  'syncEncryptionSection': 'Encryption',
  'syncEncryptionLabel': 'Encryption',
  'syncEncryptionOn': 'End-to-end (passphrase)',
  'syncEncryptionOff': 'Apple-encrypted',
  'removeEncryption': 'Remove passphrase',
  'removeEncryptionBody':
      'Removes the local passphrase. The cloud copy is left as-is until you push again.',
  'syncDefaultEncryptionHint':
      'Apple encrypts your data in transit and at rest, but holds the keys. Set a passphrase below to encrypt on this device first so no one — including Apple — can read it.',
  'syncICloudTitle': 'iCloud',
  'syncICloudSublabel':
      'Free on your iCloud storage. Apple devices only. Apple-encrypted; add a passphrase below for end-to-end.',
  'syncPlanomTitle': 'Planom Account',
  'syncPlanomSublabel':
      'Sync across iOS, Android, and Web with a Planom subscription.',
  'syncCustomTitle': 'Custom Server',
  'syncCustomSublabel':
      'Bring your own PocketBase / WebDAV server. Free; you host it.',
  'tagFree': 'FREE',
  'tagComingSoon': 'SOON',
  'syncStatusLabel': 'Status',
  'syncNow': 'Push now',
  'syncPullReplace': 'Pull from cloud (replaces local)',
  'disableSync': 'Disable sync',
  'disableSyncBody':
      'Stops syncing on this device and removes the cloud copy. Local data is kept.',
  'pullReplacesLocal':
      'Pulling will replace all local data with the cloud copy. This cannot be undone.',
  'syncPassphraseHint':
      'Pick a passphrase. We use it to encrypt your data before it leaves the device. We never see it.',
  'syncPassphraseLossHint':
      'If you forget the passphrase, your cloud backup cannot be decrypted. There is no recovery.',
  'syncNever': 'Never synced',
  'syncPushing': 'Uploading…',
  'syncPulling': 'Downloading…',
  'syncSucceeded': 'Up to date',
  'syncFailed': 'Sync failed',
  'syncNotConfigured': 'Sign into iCloud to enable',
  'syncPassphraseRequired': 'Enter passphrase to continue',
  'syncNotAvailable': 'Not available on this platform',
  'syncLastAt': 'Last sync: {when}',
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
  'calendarAllowCreatingTasks': 'Allow creating tasks',
  'calendarAllowCreatingEvents': 'Allow creating events',
  'calendarDefaultContainer': 'Default for new events',
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
  'repeat': 'Repeat', 'repeatNone': 'No Repeat',
  'repeatDaily': 'Daily', 'repeatWeekly': 'Weekly',
  'repeatMonthly': 'Monthly', 'repeatYearly': 'Yearly',
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
  'editList': 'Edit List', 'editFolder': 'Edit Folder',
  'listColor': 'List Color', 'customColor': 'Custom Color',
  'listType': 'List Type',
  'listTypeTasks': 'Tasks', 'listTypeBirthdays': 'Birthdays',
  'listTypeShopping': 'Shopping',
  'addBirthday': 'Add Birthday', 'birthdayName': 'Name',
  'birthDate': 'Birth Date', 'includeYear': 'Include year',
  'completable': 'Show checkbox', 'thisYear': 'This year',
  'nextYear': 'Next year', 'addSection': 'Add Section',
  'sectionName': 'Section name', 'sectionCompleted': 'Completed',
  'turns': 'turns',
  'selectColor': 'Select Color', 'otherDots': 'Other…',
  'chooseIcon': 'Choose Icon', 'opening': 'Opening…',
  'chooseFromLibrary': 'Choose from Library',
  'createFolder': 'Create Folder', 'createList': 'Create List',
  'folder': 'Folder', 'list': 'List',
  'newRoutine': 'New Routine', 'editRoutine': 'Edit Routine',
  'sectionFrequency': 'FREQUENCY',
  'freqDaily': 'Daily', 'freqSpecificDays': 'Specific Days', 'freqDaysAfter': 'X days after completion',
  'freqInterval': 'Interval', 'startDate': 'Start Date', 'routineIntervalEvery': 'Every', 'routineIntervalDays': '{n} days', 'waitForCompletion': 'Wait for completion', 'waitForCompletionInfo': 'Schedule the next occurrence after you complete this one. Missed days stay overdue.', 'addReminder': 'Add Reminder', 'reminderTypeTime': 'At a time', 'reminderTypeSpread': 'Spread through day', 'reminderTypeAfterEach': 'After each', 'reminderEveryLabel': 'every', 'reminderAfterEachLabel': 'after each', 'recordOnOriginalDate': 'Mark done on its original day', 'completeTodayShift': 'Complete today (shift next)', 'overdueRoutineTitle': 'Overdue routine', 'overdueRoutineBody': 'When did you do this?', 'overdueLabel': 'Overdue',
  'daysAfterCompletion': 'days after completion',
  'autoReset': 'Auto Reset', 'autoResetEveryDay': 'Every day',
  'autoResetNone': 'Do not reset',
  'sectionGoal': 'GOAL',
  'goalAchieveAll': 'Achieve it all', 'goalCertainAmount': 'Reach certain amount',
  'dailyGoal': 'Daily goal', 'recordPerTap': 'Record per tap',
  'recordManual': 'Record manually', 'recordManualInfo': 'Type the amount each time you check this routine', 'recordAmountPrompt': 'Amount in {unit}', 'showEventsInToday': 'Show events in Today', 'includeInTodayCount': 'Include in Today\'s count',
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
  // ── Google Calendar integration ────────────────────────────────────────
  'sectionIntegrations': 'Integrations',
  'googleCalendar': 'Google Calendar',
  'googleCalendarOn': 'On',
  'googleCalendarOff': 'Off',
  'googleCalendarConnect': 'Connect Google account',
  'googleCalendarConnected': 'Connected',
  'googleCalendarDisconnect': 'Disconnect',
  'googleCalendarDisconnectBody':
      'Planom will stop reading and writing your Google Calendar from this device. Your Google data is not changed.',
  'googleCalendarCalendarsSection': 'Calendars',
  'googleCalendarNoCalendars': 'No calendars found.',
  'googleCalendarPrimary': 'Primary',
  'googleCalendarReadOnly': 'Read-only',
  'googleCalendarDefaultBadge': 'Default for new events',
  'googleCalendarDefault': 'Default calendar',
  'googleCalendarDefaultSection': 'New events',
  'googleCalendarNoDefault': 'None',
  'googleCalendarSyncSection': 'Sync',
  'googleCalendarSyncNow': 'Sync now',
  'googleCalendarNeverSynced': 'Never synced',
  'googleCalendarLastSynced': 'Last synced {when}',
  'googleCalendarSetupRequired':
      'Google Calendar is not configured for this build. Add an OAuth client ID in lib/src/integrations/google/oauth_config.dart and set up the platform-specific URL scheme.',
  'googleCalendarReadOnlyHint':
      'This event is on a calendar you only have read access to. To edit it, open Google Calendar.',
  'googleCalendarReminderHint':
      'Reminders are saved on this device only — they notify you in Planom and are not added to the event in Google Calendar.',
  'googleCalendarDeleteBody':
      'This event will be permanently removed from Google Calendar.',
  'googleCalendarAddAccount': 'Add account',
  'googleCalendarAccountsSection': 'Accounts',
  'googleCalendarRemoveAccount': 'Remove account',
  'googleCalendarRemoveAccountBody':
      'Stop syncing this account? Its events will be removed from Planom (they stay in Google).',
  'googleCalendarReadWrite': 'Read & write',
  'googleCalendarReadOnlyMode': 'Read only',
  'googleCalendarChooseMode': 'How should Planom access this account?',
  'googleCalendarReadWriteDesc': 'View, create, edit and delete events',
  'googleCalendarReadOnlyDesc': 'View events only — never change Google',
  'planomLocal': 'Planom (local)',
  'eventCalendar': 'Calendar',
};

const Map<String, String> _uk = {
  'appTitle': 'planom',
  'cancel': 'Скасувати', 'done': 'Готово', 'ok': 'OK', 'add': 'Додати',
  'create': 'Створити', 'save': 'Зберегти', 'delete': 'Видалити',
  'deleteAll': 'Видалити все', 'edit': 'Редагувати', 'rename': 'Перейменувати',
  'select': 'Вибрати', 'selectAll': 'Вибрати все', 'deselectAll': 'Скасувати вибір',
  'selectItems': 'Виберіть елементи', 'selectedCount': 'Вибрано: {n}',
  'duplicate': 'Дублювати',
  'confirm': 'Підтвердити', 'insert': 'Вставити', 'move': 'Перемістити',
  'putBack': 'Відновити', 'clear': 'Очистити', 'untitled': 'Без назви',
  'tabTasks': 'Завдання', 'tabNotes': 'Нотатки', 'tabCalendar': 'Календар',
  'calendarView': 'Вигляд', 'calendarViewMonths': 'Місяці', 'calendarViewContinuous': 'Безперервний',
  'tabRoutines': 'Звички', 'tabSettings': 'Налаштування',
  'inbox': 'Вхідні', 'today': 'Сьогодні', 'yesterday': 'Вчора', 'tomorrow': 'Завтра', 'upcoming': 'Майбутні',
  'allTasks': 'Всі завдання',
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
  'newSpace': 'Новий простір', 'spaceName': 'Назва простору', 'spaces': 'Простори',
  'noOptionsYet': 'Параметрів ще немає.', 'sectionModules': 'МОДУЛІ',
  'appBadgeIncludeRoutines': 'Враховувати звички на сьогодні', 'showRoutinesInToday': 'Показувати звички в «Сьогодні»', 'showRoutinesInCalendar': 'Показувати звички в Календарі', 'showRoutinesHint': 'Звички на сьогодні зʼявляються окремою згортуваною секцією у «Завдання → Сьогодні» та в денному перегляді Календаря.', 'sectionShowRoutines': 'ПОКАЗУВАТИ ЗВИЧКИ В',
  'sectionTaskFields': 'ПОЛЯ ЗАВДАННЯ',
  'taskFieldsHint': 'Приховані поля не показуються при редагуванні завдання.',
  'sectionBody': 'ТІЛО', 'useMarkdown': 'Форматувати з Markdown',
  'useMarkdownHint': 'Коли вимкнено, тіло відображається й редагується як простий текст, а панель форматування прихована.',
  'showHidePriority': 'Пріоритет', 'showHideDate': 'Дата',
  'showHideRepeat': 'Повтор', 'showHideList': 'Список',
  'showHideDuration': 'Тривалість', 'showHideTags': 'Мітки',
  'showHideReminders': 'Нагадування',
  'sectionTasksUi': 'ІНТЕРФЕЙС',
  'showAddFolderButton': 'Кнопка додавання теки',
  'addList': 'Додати список', 'addFolder': 'Додати теку',
  'sortTasks': 'Сортування завдань', 'sortDefault': 'За замовчуванням',
  'sortByCreation': 'За датою створення', 'sortByName': 'За назвою',
  'sortByPriority': 'За пріоритетом', 'sortByDateTime': 'За датою і часом',
  'addToCalendar': 'Додати до календаря', 'taskOption': 'Завдання', 'eventOption': 'Подія',
  'calendarAllowCreatingTasks': 'Дозволити створення завдань',
  'calendarAllowCreatingEvents': 'Дозволити створення подій',
  'calendarDefaultContainer': 'Типовий контейнер для нових подій',
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
  'repeat': 'Повтор', 'repeatNone': 'Без повтору',
  'repeatDaily': 'Щодня', 'repeatWeekly': 'Щотижня',
  'repeatMonthly': 'Щомісяця', 'repeatYearly': 'Щороку',
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
  'editList': 'Редагувати список', 'editFolder': 'Редагувати теку',
  'listColor': 'Колір списку', 'customColor': 'Власний колір',
  'listType': 'Тип списку',
  'listTypeTasks': 'Завдання', 'listTypeBirthdays': 'Дні народження',
  'listTypeShopping': 'Покупки',
  'addBirthday': 'Додати день народження', 'birthdayName': 'Ім\'я',
  'birthDate': 'Дата народження', 'includeYear': 'Включити рік',
  'completable': 'Показати чекбокс', 'thisYear': 'Цей рік',
  'nextYear': 'Наступний рік', 'addSection': 'Додати розділ',
  'sectionName': 'Назва розділу', 'sectionCompleted': 'Виконано',
  'turns': 'виповнюється',
  'selectColor': 'Вибрати колір', 'otherDots': 'Інше…',
  'chooseIcon': 'Вибрати іконку', 'opening': 'Відкриття…',
  'chooseFromLibrary': 'Вибрати з бібліотеки',
  'createFolder': 'Створити папку', 'createList': 'Створити список',
  'folder': 'Папка', 'list': 'Список',
  'newRoutine': 'Нова звичка', 'editRoutine': 'Редагувати звичку',
  'sectionFrequency': 'ЧАСТОТА',
  'freqDaily': 'Щодня', 'freqSpecificDays': 'Певні дні', 'freqDaysAfter': 'Через X днів після виконання',
  'freqInterval': 'Інтервал', 'startDate': 'Дата початку', 'routineIntervalEvery': 'Кожні', 'routineIntervalDays': '{n} дн.', 'waitForCompletion': 'Чекати на виконання', 'waitForCompletionInfo': 'Наступне повторення планується після виконання поточного. Пропущені дні лишаються простроченими.', 'addReminder': 'Додати нагадування', 'reminderTypeTime': 'У певний час', 'reminderTypeSpread': 'Рівномірно за день', 'reminderTypeAfterEach': 'Після кожного', 'reminderEveryLabel': 'кожні', 'reminderAfterEachLabel': 'після кожного', 'recordOnOriginalDate': 'Позначити в початковий день', 'completeTodayShift': 'Виконати сьогодні (зсунути)', 'overdueRoutineTitle': 'Прострочена звичка', 'overdueRoutineBody': 'Коли ви це зробили?', 'overdueLabel': 'Прострочено',
  'daysAfterCompletion': 'днів після виконання',
  'autoReset': 'Автоскидання', 'autoResetEveryDay': 'Щодня',
  'autoResetNone': 'Не скидати',
  'sectionGoal': 'МЕТА',
  'goalAchieveAll': 'Виконати все', 'goalCertainAmount': 'Досягти певної кількості',
  'dailyGoal': 'Денна ціль', 'recordPerTap': 'Запис за натискання',
  'recordManual': 'Ручний запис', 'recordManualInfo': 'Щоразу вводьте кількість, коли позначаєте звичку', 'recordAmountPrompt': 'Кількість у {unit}', 'showEventsInToday': 'Показувати події в «Сьогодні»', 'includeInTodayCount': 'Враховувати в лічильнику «Сьогодні»',
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
  'select': 'Seleccionar', 'selectAll': 'Seleccionar todo',
  'deselectAll': 'Deseleccionar todo', 'selectItems': 'Seleccionar elementos',
  'selectedCount': '{n} seleccionados', 'duplicate': 'Duplicar',
  'confirm': 'Confirmar', 'insert': 'Insertar', 'move': 'Mover',
  'putBack': 'Restaurar', 'clear': 'Borrar', 'untitled': 'Sin título',
  'tabTasks': 'Tareas', 'tabNotes': 'Notas', 'tabCalendar': 'Calendario',
  'calendarView': 'Vista', 'calendarViewMonths': 'Meses', 'calendarViewContinuous': 'Continuo',
  'tabRoutines': 'Rutinas', 'tabSettings': 'Ajustes',
  'inbox': 'Bandeja', 'today': 'Hoy', 'yesterday': 'Ayer', 'tomorrow': 'Mañana', 'upcoming': 'Próximas',
  'allTasks': 'Todas las tareas',
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
  'newSpace': 'Nuevo espacio', 'spaceName': 'Nombre del espacio', 'spaces': 'Espacios',
  'noOptionsYet': 'Aún no hay opciones.', 'sectionModules': 'MÓDULOS',
  'appBadgeIncludeRoutines': 'Incluir las rutinas de hoy', 'showRoutinesInToday': 'Mostrar rutinas en Hoy', 'showRoutinesInCalendar': 'Mostrar rutinas en Calendario', 'showRoutinesHint': 'Las rutinas de hoy aparecen como una sección plegable en Tareas → Hoy y en la vista diaria del Calendario.', 'sectionShowRoutines': 'MOSTRAR RUTINAS EN',
  'sectionTaskFields': 'CAMPOS DE TAREA',
  'taskFieldsHint': 'Los campos ocultos no se muestran al editar una tarea.',
  'sectionBody': 'CUERPO', 'useMarkdown': 'Formatear con Markdown',
  'useMarkdownHint': 'Cuando está desactivado, el cuerpo se muestra y edita como texto plano y la barra de formato queda oculta.',
  'showHidePriority': 'Prioridad', 'showHideDate': 'Fecha',
  'showHideRepeat': 'Repetir', 'showHideList': 'Lista',
  'showHideDuration': 'Duración', 'showHideTags': 'Etiquetas',
  'showHideReminders': 'Recordatorios',
  'sectionTasksUi': 'INTERFAZ',
  'showAddFolderButton': 'Botón Añadir carpeta',
  'addList': 'Añadir lista', 'addFolder': 'Añadir carpeta',
  'sortTasks': 'Ordenar tareas', 'sortDefault': 'Predeterminado',
  'sortByCreation': 'Por fecha de creación', 'sortByName': 'Por nombre',
  'sortByPriority': 'Por prioridad', 'sortByDateTime': 'Por fecha y hora',
  'addToCalendar': 'Añadir al calendario', 'taskOption': 'Tarea', 'eventOption': 'Evento',
  'calendarAllowCreatingTasks': 'Permitir crear tareas',
  'calendarAllowCreatingEvents': 'Permitir crear eventos',
  'calendarDefaultContainer': 'Predeterminado para eventos nuevos',
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
  'repeat': 'Repetir', 'repeatNone': 'Sin repetición',
  'repeatDaily': 'Diariamente', 'repeatWeekly': 'Semanalmente',
  'repeatMonthly': 'Mensualmente', 'repeatYearly': 'Anualmente',
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
  'editList': 'Editar lista', 'editFolder': 'Editar carpeta',
  'listColor': 'Color de la lista', 'customColor': 'Color personalizado',
  'listType': 'Tipo de lista',
  'listTypeTasks': 'Tareas', 'listTypeBirthdays': 'Cumpleaños',
  'listTypeShopping': 'Compras',
  'addBirthday': 'Añadir cumpleaños', 'birthdayName': 'Nombre',
  'birthDate': 'Fecha de nacimiento', 'includeYear': 'Incluir año',
  'completable': 'Mostrar casilla', 'thisYear': 'Este año',
  'nextYear': 'Próximo año', 'addSection': 'Añadir sección',
  'sectionName': 'Nombre de la sección', 'sectionCompleted': 'Completadas',
  'turns': 'cumple',
  'selectColor': 'Seleccionar color', 'otherDots': 'Otro…',
  'chooseIcon': 'Elegir icono', 'opening': 'Abriendo…',
  'chooseFromLibrary': 'Elegir de la biblioteca',
  'createFolder': 'Crear carpeta', 'createList': 'Crear lista',
  'folder': 'Carpeta', 'list': 'Lista',
  'newRoutine': 'Nueva rutina', 'editRoutine': 'Editar rutina',
  'sectionFrequency': 'FRECUENCIA',
  'freqDaily': 'Diario', 'freqSpecificDays': 'Días específicos', 'freqDaysAfter': 'X días después de completar',
  'freqInterval': 'Intervalo', 'startDate': 'Fecha de inicio', 'routineIntervalEvery': 'Cada', 'routineIntervalDays': '{n} días', 'waitForCompletion': 'Esperar a completar', 'waitForCompletionInfo': 'Programa la próxima vez tras completar esta. Los días perdidos quedan vencidos.', 'addReminder': 'Añadir recordatorio', 'reminderTypeTime': 'A una hora', 'reminderTypeSpread': 'Repartido en el día', 'reminderTypeAfterEach': 'Tras cada uno', 'reminderEveryLabel': 'cada', 'reminderAfterEachLabel': 'tras cada uno', 'recordOnOriginalDate': 'Marcar en su día original', 'completeTodayShift': 'Completar hoy (desplazar)', 'overdueRoutineTitle': 'Rutina vencida', 'overdueRoutineBody': '¿Cuándo lo hiciste?', 'overdueLabel': 'Vencido',
  'daysAfterCompletion': 'días después de completar',
  'autoReset': 'Reinicio automático', 'autoResetEveryDay': 'Cada día',
  'autoResetNone': 'No reiniciar',
  'sectionGoal': 'OBJETIVO',
  'goalAchieveAll': 'Lograr todo', 'goalCertainAmount': 'Alcanzar cantidad',
  'dailyGoal': 'Meta diaria', 'recordPerTap': 'Registro por toque',
  'recordManual': 'Registro manual', 'recordManualInfo': 'Escribe la cantidad cada vez que marcas la rutina', 'recordAmountPrompt': 'Cantidad en {unit}', 'showEventsInToday': 'Mostrar eventos en Hoy', 'includeInTodayCount': 'Incluir en el contador de Hoy',
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
  'select': 'Sélectionner', 'selectAll': 'Tout sélectionner',
  'deselectAll': 'Tout désélectionner', 'selectItems': 'Sélectionner des éléments',
  'selectedCount': '{n} sélectionnés', 'duplicate': 'Dupliquer',
  'confirm': 'Confirmer', 'insert': 'Insérer', 'move': 'Déplacer',
  'putBack': 'Restaurer', 'clear': 'Effacer', 'untitled': 'Sans titre',
  'tabTasks': 'Tâches', 'tabNotes': 'Notes', 'tabCalendar': 'Calendrier',
  'calendarView': 'Affichage', 'calendarViewMonths': 'Mois', 'calendarViewContinuous': 'Continu',
  'tabRoutines': 'Routines', 'tabSettings': 'Réglages',
  'inbox': 'Boîte', 'today': "Aujourd'hui", 'yesterday': 'Hier', 'tomorrow': 'Demain', 'upcoming': 'À venir',
  'allTasks': 'Toutes les tâches',
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
  'newSpace': 'Nouvel espace', 'spaceName': 'Nom de l\'espace', 'spaces': 'Espaces',
  'noOptionsYet': 'Aucune option pour le moment.', 'sectionModules': 'MODULES',
  'appBadgeIncludeRoutines': 'Inclure les routines du jour', 'showRoutinesInToday': 'Afficher les routines dans Aujourd\'hui', 'showRoutinesInCalendar': 'Afficher les routines dans le Calendrier', 'showRoutinesHint': 'Les routines du jour apparaissent dans une section repliable dans Tâches → Aujourd\'hui et dans la vue du jour du Calendrier.', 'sectionShowRoutines': 'AFFICHER LES ROUTINES DANS',
  'sectionTaskFields': 'CHAMPS DE TÂCHE',
  'taskFieldsHint': "Les champs masqués ne s'affichent pas lors de l'édition d'une tâche.",
  'sectionBody': 'CORPS', 'useMarkdown': 'Formater en Markdown',
  'useMarkdownHint': "Lorsque désactivé, le corps est affiché et modifié en texte brut, et la barre de mise en forme est masquée.",
  'showHidePriority': 'Priorité', 'showHideDate': 'Date',
  'showHideRepeat': 'Répéter', 'showHideList': 'Liste',
  'showHideDuration': 'Durée', 'showHideTags': 'Étiquettes',
  'showHideReminders': 'Rappels',
  'sectionTasksUi': 'INTERFACE',
  'showAddFolderButton': 'Bouton Ajouter un dossier',
  'addList': 'Ajouter une liste', 'addFolder': 'Ajouter un dossier',
  'sortTasks': 'Trier les tâches', 'sortDefault': 'Par défaut',
  'sortByCreation': 'Par date de création', 'sortByName': 'Par nom',
  'sortByPriority': 'Par priorité', 'sortByDateTime': 'Par date et heure',
  'addToCalendar': 'Ajouter au calendrier', 'taskOption': 'Tâche', 'eventOption': 'Événement',
  'calendarAllowCreatingTasks': 'Autoriser la création de tâches',
  'calendarAllowCreatingEvents': 'Autoriser la création d\'événements',
  'calendarDefaultContainer': 'Par défaut pour les nouveaux événements',
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
  'repeat': 'Répéter', 'repeatNone': 'Aucune répétition',
  'repeatDaily': 'Quotidien', 'repeatWeekly': 'Hebdomadaire',
  'repeatMonthly': 'Mensuel', 'repeatYearly': 'Annuel',
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
  'editList': 'Modifier la liste', 'editFolder': 'Modifier le dossier',
  'listColor': 'Couleur de la liste', 'customColor': 'Couleur personnalisée',
  'listType': 'Type de liste',
  'listTypeTasks': 'Tâches', 'listTypeBirthdays': 'Anniversaires',
  'listTypeShopping': 'Courses',
  'addBirthday': 'Ajouter un anniversaire', 'birthdayName': 'Nom',
  'birthDate': 'Date de naissance', 'includeYear': "Inclure l'année",
  'completable': 'Afficher la case', 'thisYear': 'Cette année',
  'nextYear': 'Année prochaine', 'addSection': 'Ajouter une section',
  'sectionName': 'Nom de la section', 'sectionCompleted': 'Terminé',
  'turns': 'fête',
  'selectColor': 'Sélectionner', 'otherDots': 'Autre…',
  'chooseIcon': 'Choisir une icône', 'opening': 'Ouverture…',
  'chooseFromLibrary': 'Choisir depuis la bibliothèque',
  'createFolder': 'Créer un dossier', 'createList': 'Créer une liste',
  'folder': 'Dossier', 'list': 'Liste',
  'newRoutine': 'Nouvelle routine', 'editRoutine': 'Modifier la routine',
  'sectionFrequency': 'FRÉQUENCE',
  'freqDaily': 'Quotidien', 'freqSpecificDays': 'Jours précis', 'freqDaysAfter': 'X jours après l\'achèvement',
  'freqInterval': 'Intervalle', 'startDate': 'Date de début', 'routineIntervalEvery': 'Tous les', 'routineIntervalDays': '{n} jours', 'waitForCompletion': 'Attendre la réalisation', 'waitForCompletionInfo': 'Planifie la prochaine fois après avoir terminé celle-ci. Les jours manqués restent en retard.', 'addReminder': 'Ajouter un rappel', 'reminderTypeTime': 'À une heure', 'reminderTypeSpread': 'Réparti sur la journée', 'reminderTypeAfterEach': 'Après chacun', 'reminderEveryLabel': 'toutes les', 'reminderAfterEachLabel': 'après chacun', 'recordOnOriginalDate': 'Marquer à sa date initiale', 'completeTodayShift': 'Terminer aujourd\'hui (décaler)', 'overdueRoutineTitle': 'Routine en retard', 'overdueRoutineBody': 'Quand l\'avez-vous fait ?', 'overdueLabel': 'En retard',
  'daysAfterCompletion': 'jours après l\'achèvement',
  'autoReset': 'Réinitialisation auto', 'autoResetEveryDay': 'Chaque jour',
  'autoResetNone': 'Ne pas réinitialiser',
  'sectionGoal': 'OBJECTIF',
  'goalAchieveAll': 'Tout accomplir', 'goalCertainAmount': 'Atteindre un montant',
  'dailyGoal': 'Objectif quotidien', 'recordPerTap': 'Par appui',
  'recordManual': 'Saisie manuelle', 'recordManualInfo': 'Saisissez la quantité à chaque fois que vous cochez la routine', 'recordAmountPrompt': 'Quantité en {unit}', 'showEventsInToday': 'Afficher les événements dans Aujourd\'hui', 'includeInTodayCount': 'Inclure dans le compteur Aujourd\'hui',
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
  'select': 'Auswählen', 'selectAll': 'Alle auswählen',
  'deselectAll': 'Auswahl aufheben', 'selectItems': 'Elemente auswählen',
  'selectedCount': '{n} ausgewählt', 'duplicate': 'Duplizieren',
  'confirm': 'Bestätigen', 'insert': 'Einfügen', 'move': 'Verschieben',
  'putBack': 'Wiederherstellen', 'clear': 'Löschen', 'untitled': 'Ohne Titel',
  'tabTasks': 'Aufgaben', 'tabNotes': 'Notizen', 'tabCalendar': 'Kalender',
  'calendarView': 'Ansicht', 'calendarViewMonths': 'Monate', 'calendarViewContinuous': 'Fortlaufend',
  'tabRoutines': 'Routinen', 'tabSettings': 'Einstellungen',
  'inbox': 'Eingang', 'today': 'Heute', 'yesterday': 'Gestern', 'tomorrow': 'Morgen', 'upcoming': 'Anstehend',
  'allTasks': 'Alle Aufgaben',
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
  'newSpace': 'Neuer Bereich', 'spaceName': 'Bereichsname', 'spaces': 'Bereiche',
  'noOptionsYet': 'Noch keine Optionen.', 'sectionModules': 'MODULE',
  'appBadgeIncludeRoutines': 'Heutige Routinen einbeziehen', 'showRoutinesInToday': 'Routinen in Heute anzeigen', 'showRoutinesInCalendar': 'Routinen im Kalender anzeigen', 'showRoutinesHint': 'Die heutigen Routinen erscheinen als einklappbarer Abschnitt in Aufgaben → Heute und in der Tagesansicht des Kalenders.', 'sectionShowRoutines': 'ROUTINEN ANZEIGEN IN',
  'sectionTaskFields': 'AUFGABENFELDER',
  'taskFieldsHint': 'Ausgeblendete Felder erscheinen nicht beim Bearbeiten einer Aufgabe.',
  'sectionBody': 'KÖRPER', 'useMarkdown': 'Mit Markdown formatieren',
  'useMarkdownHint': 'Wenn aus, wird der Text als Klartext angezeigt und bearbeitet, und die Formatierungsleiste ist ausgeblendet.',
  'showHidePriority': 'Priorität', 'showHideDate': 'Datum',
  'showHideRepeat': 'Wiederholen', 'showHideList': 'Liste',
  'showHideDuration': 'Dauer', 'showHideTags': 'Tags',
  'showHideReminders': 'Erinnerungen',
  'sectionTasksUi': 'OBERFLÄCHE',
  'showAddFolderButton': 'Ordner-hinzufügen-Schaltfläche',
  'addList': 'Liste hinzufügen', 'addFolder': 'Ordner hinzufügen',
  'sortTasks': 'Aufgaben sortieren', 'sortDefault': 'Standard',
  'sortByCreation': 'Nach Erstellungsdatum', 'sortByName': 'Nach Name',
  'sortByPriority': 'Nach Priorität', 'sortByDateTime': 'Nach Datum & Zeit',
  'addToCalendar': 'Zum Kalender hinzufügen', 'taskOption': 'Aufgabe', 'eventOption': 'Ereignis',
  'calendarAllowCreatingTasks': 'Aufgaben erstellen erlauben',
  'calendarAllowCreatingEvents': 'Ereignisse erstellen erlauben',
  'calendarDefaultContainer': 'Standard für neue Ereignisse',
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
  'repeat': 'Wiederholung', 'repeatNone': 'Keine Wiederholung',
  'repeatDaily': 'Täglich', 'repeatWeekly': 'Wöchentlich',
  'repeatMonthly': 'Monatlich', 'repeatYearly': 'Jährlich',
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
  'editList': 'Liste bearbeiten', 'editFolder': 'Ordner bearbeiten',
  'listColor': 'Listenfarbe', 'customColor': 'Eigene Farbe',
  'listType': 'Listentyp',
  'listTypeTasks': 'Aufgaben', 'listTypeBirthdays': 'Geburtstage',
  'listTypeShopping': 'Einkaufen',
  'addBirthday': 'Geburtstag hinzufügen', 'birthdayName': 'Name',
  'birthDate': 'Geburtsdatum', 'includeYear': 'Jahr einschließen',
  'completable': 'Kästchen anzeigen', 'thisYear': 'Dieses Jahr',
  'nextYear': 'Nächstes Jahr', 'addSection': 'Abschnitt hinzufügen',
  'sectionName': 'Abschnittsname', 'sectionCompleted': 'Erledigt',
  'turns': 'wird',
  'selectColor': 'Farbe wählen', 'otherDots': 'Andere…',
  'chooseIcon': 'Symbol wählen', 'opening': 'Öffne…',
  'chooseFromLibrary': 'Aus Bibliothek wählen',
  'createFolder': 'Ordner erstellen', 'createList': 'Liste erstellen',
  'folder': 'Ordner', 'list': 'Liste',
  'newRoutine': 'Neue Routine', 'editRoutine': 'Routine bearbeiten',
  'sectionFrequency': 'HÄUFIGKEIT',
  'freqDaily': 'Täglich', 'freqSpecificDays': 'Bestimmte Tage', 'freqDaysAfter': 'X Tage nach Abschluss',
  'freqInterval': 'Intervall', 'startDate': 'Startdatum', 'routineIntervalEvery': 'Alle', 'routineIntervalDays': '{n} Tage', 'waitForCompletion': 'Auf Abschluss warten', 'waitForCompletionInfo': 'Plant das nächste Mal nach Abschluss dieses. Verpasste Tage bleiben überfällig.', 'addReminder': 'Erinnerung hinzufügen', 'reminderTypeTime': 'Zu einer Zeit', 'reminderTypeSpread': 'Über den Tag verteilt', 'reminderTypeAfterEach': 'Nach jedem', 'reminderEveryLabel': 'alle', 'reminderAfterEachLabel': 'nach jedem', 'recordOnOriginalDate': 'Am ursprünglichen Tag erledigen', 'completeTodayShift': 'Heute erledigen (verschieben)', 'overdueRoutineTitle': 'Überfällige Routine', 'overdueRoutineBody': 'Wann hast du das gemacht?', 'overdueLabel': 'Überfällig',
  'daysAfterCompletion': 'Tage nach Abschluss',
  'autoReset': 'Automatisch zurücksetzen', 'autoResetEveryDay': 'Jeden Tag',
  'autoResetNone': 'Nicht zurücksetzen',
  'sectionGoal': 'ZIEL',
  'goalAchieveAll': 'Alles erreichen', 'goalCertainAmount': 'Bestimmte Menge',
  'dailyGoal': 'Tagesziel', 'recordPerTap': 'Pro Tipp aufzeichnen',
  'recordManual': 'Manuell erfassen', 'recordManualInfo': 'Gib jedes Mal die Menge ein, wenn du die Routine abhakst', 'recordAmountPrompt': 'Menge in {unit}', 'showEventsInToday': 'Termine in Heute anzeigen', 'includeInTodayCount': 'In Heute-Zähler einbeziehen',
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
  'select': 'Seleziona', 'selectAll': 'Seleziona tutto',
  'deselectAll': 'Deseleziona tutto', 'selectItems': 'Seleziona elementi',
  'selectedCount': '{n} selezionati', 'duplicate': 'Duplica',
  'confirm': 'Conferma', 'insert': 'Inserisci', 'move': 'Sposta',
  'putBack': 'Ripristina', 'clear': 'Cancella', 'untitled': 'Senza titolo',
  'tabTasks': 'Attività', 'tabNotes': 'Note', 'tabCalendar': 'Calendario',
  'calendarView': 'Vista', 'calendarViewMonths': 'Mesi', 'calendarViewContinuous': 'Continuo',
  'tabRoutines': 'Abitudini', 'tabSettings': 'Impostazioni',
  'inbox': 'In arrivo', 'today': 'Oggi', 'yesterday': 'Ieri', 'tomorrow': 'Domani', 'upcoming': 'In arrivo',
  'allTasks': 'Tutte le attività',
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
  'newSpace': 'Nuovo spazio', 'spaceName': 'Nome dello spazio', 'spaces': 'Spazi',
  'noOptionsYet': 'Ancora nessuna opzione.', 'sectionModules': 'MODULI',
  'appBadgeIncludeRoutines': 'Includi le routine di oggi', 'showRoutinesInToday': 'Mostra le routine in Oggi', 'showRoutinesInCalendar': 'Mostra le routine nel Calendario', 'showRoutinesHint': 'Le routine di oggi appaiono come sezione comprimibile in Attività → Oggi e nella vista giornaliera del Calendario.', 'sectionShowRoutines': 'MOSTRA LE ROUTINE IN',
  'sectionTaskFields': 'CAMPI ATTIVITÀ',
  'taskFieldsHint': "I campi nascosti non vengono mostrati durante la modifica di un'attività.",
  'sectionBody': 'CORPO', 'useMarkdown': 'Formatta con Markdown',
  'useMarkdownHint': 'Se disattivato, il corpo viene mostrato e modificato come testo semplice e la barra di formattazione è nascosta.',
  'showHidePriority': 'Priorità', 'showHideDate': 'Data',
  'showHideRepeat': 'Ripeti', 'showHideList': 'Elenco',
  'showHideDuration': 'Durata', 'showHideTags': 'Tag',
  'showHideReminders': 'Promemoria',
  'sectionTasksUi': 'INTERFACCIA',
  'showAddFolderButton': 'Pulsante aggiungi cartella',
  'addList': 'Aggiungi elenco', 'addFolder': 'Aggiungi cartella',
  'sortTasks': 'Ordina attività', 'sortDefault': 'Predefinito',
  'sortByCreation': 'Per data creazione', 'sortByName': 'Per nome',
  'sortByPriority': 'Per priorità', 'sortByDateTime': 'Per data e ora',
  'addToCalendar': 'Aggiungi al calendario', 'taskOption': 'Attività', 'eventOption': 'Evento',
  'calendarAllowCreatingTasks': 'Consenti la creazione di attività',
  'calendarAllowCreatingEvents': 'Consenti la creazione di eventi',
  'calendarDefaultContainer': 'Predefinito per nuovi eventi',
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
  'repeat': 'Ripeti', 'repeatNone': 'Nessuna ripetizione',
  'repeatDaily': 'Giornalmente', 'repeatWeekly': 'Settimanalmente',
  'repeatMonthly': 'Mensilmente', 'repeatYearly': 'Annualmente',
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
  'editList': 'Modifica elenco', 'editFolder': 'Modifica cartella',
  'listColor': 'Colore della lista', 'customColor': 'Colore personalizzato',
  'listType': 'Tipo di lista',
  'listTypeTasks': 'Attività', 'listTypeBirthdays': 'Compleanni',
  'listTypeShopping': 'Spesa',
  'addBirthday': 'Aggiungi compleanno', 'birthdayName': 'Nome',
  'birthDate': 'Data di nascita', 'includeYear': 'Includi anno',
  'completable': 'Mostra casella', 'thisYear': "Quest'anno",
  'nextYear': 'Anno prossimo', 'addSection': 'Aggiungi sezione',
  'sectionName': 'Nome sezione', 'sectionCompleted': 'Completate',
  'turns': 'compie',
  'selectColor': 'Seleziona colore', 'otherDots': 'Altro…',
  'chooseIcon': 'Scegli icona', 'opening': 'Apertura…',
  'chooseFromLibrary': 'Scegli dalla libreria',
  'createFolder': 'Crea cartella', 'createList': 'Crea lista',
  'folder': 'Cartella', 'list': 'Lista',
  'newRoutine': 'Nuova abitudine', 'editRoutine': 'Modifica abitudine',
  'sectionFrequency': 'FREQUENZA',
  'freqDaily': 'Giornaliero', 'freqSpecificDays': 'Giorni specifici', 'freqDaysAfter': 'X giorni dopo completamento',
  'freqInterval': 'Intervallo', 'startDate': 'Data di inizio', 'routineIntervalEvery': 'Ogni', 'routineIntervalDays': '{n} giorni', 'waitForCompletion': 'Attendi il completamento', 'waitForCompletionInfo': 'Pianifica la prossima dopo aver completato questa. I giorni saltati restano scaduti.', 'addReminder': 'Aggiungi promemoria', 'reminderTypeTime': 'A un orario', 'reminderTypeSpread': 'Distribuito nel giorno', 'reminderTypeAfterEach': 'Dopo ognuno', 'reminderEveryLabel': 'ogni', 'reminderAfterEachLabel': 'dopo ognuno', 'recordOnOriginalDate': 'Segna nel giorno originale', 'completeTodayShift': 'Completa oggi (sposta)', 'overdueRoutineTitle': 'Routine scaduta', 'overdueRoutineBody': 'Quando lo hai fatto?', 'overdueLabel': 'Scaduto',
  'daysAfterCompletion': 'giorni dopo completamento',
  'autoReset': 'Reset automatico', 'autoResetEveryDay': 'Ogni giorno',
  'autoResetNone': 'Non resettare',
  'sectionGoal': 'OBIETTIVO',
  'goalAchieveAll': 'Realizza tutto', 'goalCertainAmount': 'Raggiungi quantità',
  'dailyGoal': 'Obiettivo giornaliero', 'recordPerTap': 'Registra per tocco',
  'recordManual': 'Inserimento manuale', 'recordManualInfo': 'Inserisci la quantità ogni volta che segni la routine', 'recordAmountPrompt': 'Quantità in {unit}', 'showEventsInToday': 'Mostra gli eventi in Oggi', 'includeInTodayCount': 'Includi nel conteggio di Oggi',
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
  'select': 'Selecionar', 'selectAll': 'Selecionar tudo',
  'deselectAll': 'Desmarcar tudo', 'selectItems': 'Selecionar itens',
  'selectedCount': '{n} selecionados', 'duplicate': 'Duplicar',
  'confirm': 'Confirmar', 'insert': 'Inserir', 'move': 'Mover',
  'putBack': 'Restaurar', 'clear': 'Limpar', 'untitled': 'Sem título',
  'tabTasks': 'Tarefas', 'tabNotes': 'Notas', 'tabCalendar': 'Calendário',
  'calendarView': 'Visualização', 'calendarViewMonths': 'Meses', 'calendarViewContinuous': 'Contínuo',
  'tabRoutines': 'Rotinas', 'tabSettings': 'Ajustes',
  'inbox': 'Caixa', 'today': 'Hoje', 'yesterday': 'Ontem', 'tomorrow': 'Amanhã', 'upcoming': 'Próximas',
  'allTasks': 'Todas as tarefas',
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
  'newSpace': 'Novo espaço', 'spaceName': 'Nome do espaço', 'spaces': 'Espaços',
  'noOptionsYet': 'Ainda sem opções.', 'sectionModules': 'MÓDULOS',
  'appBadgeIncludeRoutines': 'Incluir as rotinas de hoje', 'showRoutinesInToday': 'Mostrar rotinas em Hoje', 'showRoutinesInCalendar': 'Mostrar rotinas no Calendário', 'showRoutinesHint': 'As rotinas de hoje aparecem como uma seção recolhível em Tarefas → Hoje e na vista diária do Calendário.', 'sectionShowRoutines': 'MOSTRAR ROTINAS EM',
  'sectionTaskFields': 'CAMPOS DE TAREFA',
  'taskFieldsHint': 'Os campos ocultos não aparecem ao editar uma tarefa.',
  'sectionBody': 'CORPO', 'useMarkdown': 'Formatar com Markdown',
  'useMarkdownHint': 'Quando desativado, o corpo é exibido e editado como texto simples e a barra de formatação fica oculta.',
  'showHidePriority': 'Prioridade', 'showHideDate': 'Data',
  'showHideRepeat': 'Repetir', 'showHideList': 'Lista',
  'showHideDuration': 'Duração', 'showHideTags': 'Etiquetas',
  'showHideReminders': 'Lembretes',
  'sectionTasksUi': 'INTERFACE',
  'showAddFolderButton': 'Botão Adicionar pasta',
  'addList': 'Adicionar lista', 'addFolder': 'Adicionar pasta',
  'sortTasks': 'Ordenar tarefas', 'sortDefault': 'Padrão',
  'sortByCreation': 'Por data de criação', 'sortByName': 'Por nome',
  'sortByPriority': 'Por prioridade', 'sortByDateTime': 'Por data e hora',
  'addToCalendar': 'Adicionar ao calendário', 'taskOption': 'Tarefa', 'eventOption': 'Evento',
  'calendarAllowCreatingTasks': 'Permitir criar tarefas',
  'calendarAllowCreatingEvents': 'Permitir criar eventos',
  'calendarDefaultContainer': 'Padrão para novos eventos',
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
  'repeat': 'Repetir', 'repeatNone': 'Sem repetição',
  'repeatDaily': 'Diariamente', 'repeatWeekly': 'Semanalmente',
  'repeatMonthly': 'Mensalmente', 'repeatYearly': 'Anualmente',
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
  'editList': 'Editar lista', 'editFolder': 'Editar pasta',
  'listColor': 'Cor da lista', 'customColor': 'Cor personalizada',
  'listType': 'Tipo de lista',
  'listTypeTasks': 'Tarefas', 'listTypeBirthdays': 'Aniversários',
  'listTypeShopping': 'Compras',
  'addBirthday': 'Adicionar aniversário', 'birthdayName': 'Nome',
  'birthDate': 'Data de nascimento', 'includeYear': 'Incluir ano',
  'completable': 'Mostrar caixa', 'thisYear': 'Este ano',
  'nextYear': 'Próximo ano', 'addSection': 'Adicionar seção',
  'sectionName': 'Nome da seção', 'sectionCompleted': 'Concluídas',
  'turns': 'faz',
  'selectColor': 'Selecionar cor', 'otherDots': 'Outro…',
  'chooseIcon': 'Escolher ícone', 'opening': 'Abrindo…',
  'chooseFromLibrary': 'Escolher da biblioteca',
  'createFolder': 'Criar pasta', 'createList': 'Criar lista',
  'folder': 'Pasta', 'list': 'Lista',
  'newRoutine': 'Nova rotina', 'editRoutine': 'Editar rotina',
  'sectionFrequency': 'FREQUÊNCIA',
  'freqDaily': 'Diário', 'freqSpecificDays': 'Dias específicos', 'freqDaysAfter': 'X dias após concluir',
  'freqInterval': 'Intervalo', 'startDate': 'Data de início', 'routineIntervalEvery': 'A cada', 'routineIntervalDays': '{n} dias', 'waitForCompletion': 'Aguardar conclusão', 'waitForCompletionInfo': 'Agenda a próxima após concluir esta. Dias perdidos ficam atrasados.', 'addReminder': 'Adicionar lembrete', 'reminderTypeTime': 'A uma hora', 'reminderTypeSpread': 'Distribuído no dia', 'reminderTypeAfterEach': 'Após cada', 'reminderEveryLabel': 'a cada', 'reminderAfterEachLabel': 'após cada', 'recordOnOriginalDate': 'Marcar no dia original', 'completeTodayShift': 'Concluir hoje (deslocar)', 'overdueRoutineTitle': 'Rotina atrasada', 'overdueRoutineBody': 'Quando você fez isto?', 'overdueLabel': 'Atrasado',
  'daysAfterCompletion': 'dias após concluir',
  'autoReset': 'Reinício automático', 'autoResetEveryDay': 'Todo dia',
  'autoResetNone': 'Não reiniciar',
  'sectionGoal': 'META',
  'goalAchieveAll': 'Concluir tudo', 'goalCertainAmount': 'Atingir quantidade',
  'dailyGoal': 'Meta diária', 'recordPerTap': 'Por toque',
  'recordManual': 'Registro manual', 'recordManualInfo': 'Digite a quantidade sempre que marcar a rotina', 'recordAmountPrompt': 'Quantidade em {unit}', 'showEventsInToday': 'Mostrar eventos em Hoje', 'includeInTodayCount': 'Incluir na contagem de Hoje',
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
  'select': 'Выбрать', 'selectAll': 'Выбрать всё',
  'deselectAll': 'Снять выделение', 'selectItems': 'Выберите элементы',
  'selectedCount': 'Выбрано: {n}', 'duplicate': 'Дублировать',
  'confirm': 'Подтвердить', 'insert': 'Вставить', 'move': 'Переместить',
  'putBack': 'Восстановить', 'clear': 'Очистить', 'untitled': 'Без названия',
  'tabTasks': 'Задачи', 'tabNotes': 'Заметки', 'tabCalendar': 'Календарь',
  'calendarView': 'Вид', 'calendarViewMonths': 'Месяцы', 'calendarViewContinuous': 'Непрерывный',
  'tabRoutines': 'Привычки', 'tabSettings': 'Настройки',
  'inbox': 'Входящие', 'today': 'Сегодня', 'yesterday': 'Вчера', 'tomorrow': 'Завтра', 'upcoming': 'Предстоящие',
  'allTasks': 'Все задачи',
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
  'newSpace': 'Новое пространство', 'spaceName': 'Название пространства', 'spaces': 'Пространства',
  'noOptionsYet': 'Пока нет параметров.', 'sectionModules': 'МОДУЛИ',
  'appBadgeIncludeRoutines': 'Учитывать привычки на сегодня', 'showRoutinesInToday': 'Показывать привычки в «Сегодня»', 'showRoutinesInCalendar': 'Показывать привычки в Календаре', 'showRoutinesHint': 'Привычки на сегодня показываются отдельной сворачиваемой секцией в «Задачи → Сегодня» и в дневном виде Календаря.', 'sectionShowRoutines': 'ПОКАЗЫВАТЬ ПРИВЫЧКИ В',
  'sectionTaskFields': 'ПОЛЯ ЗАДАЧИ',
  'taskFieldsHint': 'Скрытые поля не отображаются при редактировании задачи.',
  'sectionBody': 'ТЕЛО', 'useMarkdown': 'Форматировать с Markdown',
  'useMarkdownHint': 'Если выключено, тело отображается и редактируется как простой текст, панель форматирования скрыта.',
  'showHidePriority': 'Приоритет', 'showHideDate': 'Дата',
  'showHideRepeat': 'Повтор', 'showHideList': 'Список',
  'showHideDuration': 'Длительность', 'showHideTags': 'Метки',
  'showHideReminders': 'Напоминания',
  'sectionTasksUi': 'ИНТЕРФЕЙС',
  'showAddFolderButton': 'Кнопка добавления папки',
  'addList': 'Добавить список', 'addFolder': 'Добавить папку',
  'sortTasks': 'Сортировать задачи', 'sortDefault': 'По умолчанию',
  'sortByCreation': 'По дате создания', 'sortByName': 'По имени',
  'sortByPriority': 'По приоритету', 'sortByDateTime': 'По дате и времени',
  'addToCalendar': 'Добавить в календарь', 'taskOption': 'Задача', 'eventOption': 'Событие',
  'calendarAllowCreatingTasks': 'Разрешить создание задач',
  'calendarAllowCreatingEvents': 'Разрешить создание событий',
  'calendarDefaultContainer': 'По умолчанию для новых событий',
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
  'repeat': 'Повтор', 'repeatNone': 'Без повтора',
  'repeatDaily': 'Ежедневно', 'repeatWeekly': 'Еженедельно',
  'repeatMonthly': 'Ежемесячно', 'repeatYearly': 'Ежегодно',
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
  'editList': 'Изменить список', 'editFolder': 'Изменить папку',
  'listColor': 'Цвет списка', 'customColor': 'Свой цвет',
  'listType': 'Тип списка',
  'listTypeTasks': 'Задачи', 'listTypeBirthdays': 'Дни рождения',
  'listTypeShopping': 'Покупки',
  'addBirthday': 'Добавить день рождения', 'birthdayName': 'Имя',
  'birthDate': 'Дата рождения', 'includeYear': 'Включить год',
  'completable': 'Показывать чекбокс', 'thisYear': 'В этом году',
  'nextYear': 'В следующем году', 'addSection': 'Добавить раздел',
  'sectionName': 'Название раздела', 'sectionCompleted': 'Выполнено',
  'turns': 'исполняется',
  'selectColor': 'Выбрать цвет', 'otherDots': 'Другое…',
  'chooseIcon': 'Выбрать значок', 'opening': 'Открытие…',
  'chooseFromLibrary': 'Выбрать из библиотеки',
  'createFolder': 'Создать папку', 'createList': 'Создать список',
  'folder': 'Папка', 'list': 'Список',
  'newRoutine': 'Новая привычка', 'editRoutine': 'Редактировать',
  'sectionFrequency': 'ЧАСТОТА',
  'freqDaily': 'Ежедневно', 'freqSpecificDays': 'Определённые дни', 'freqDaysAfter': 'Через X дней после выполнения',
  'freqInterval': 'Интервал', 'startDate': 'Дата начала', 'routineIntervalEvery': 'Каждые', 'routineIntervalDays': '{n} дн.', 'waitForCompletion': 'Ждать выполнения', 'waitForCompletionInfo': 'Следующее повторение планируется после выполнения текущего. Пропущенные дни остаются просроченными.', 'addReminder': 'Добавить напоминание', 'reminderTypeTime': 'В заданное время', 'reminderTypeSpread': 'Равномерно за день', 'reminderTypeAfterEach': 'После каждого', 'reminderEveryLabel': 'каждые', 'reminderAfterEachLabel': 'после каждого', 'recordOnOriginalDate': 'Отметить в исходный день', 'completeTodayShift': 'Выполнить сегодня (сдвинуть)', 'overdueRoutineTitle': 'Просроченная привычка', 'overdueRoutineBody': 'Когда вы это сделали?', 'overdueLabel': 'Просрочено',
  'daysAfterCompletion': 'дней после выполнения',
  'autoReset': 'Автосброс', 'autoResetEveryDay': 'Каждый день',
  'autoResetNone': 'Не сбрасывать',
  'sectionGoal': 'ЦЕЛЬ',
  'goalAchieveAll': 'Выполнить всё', 'goalCertainAmount': 'Достичь количества',
  'dailyGoal': 'Дневная цель', 'recordPerTap': 'За одно нажатие',
  'recordManual': 'Ручной ввод', 'recordManualInfo': 'Вводите количество каждый раз при отметке привычки', 'recordAmountPrompt': 'Количество в {unit}', 'showEventsInToday': 'Показывать события в «Сегодня»', 'includeInTodayCount': 'Учитывать в счётчике «Сегодня»',
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
  'select': '选择', 'selectAll': '全选', 'deselectAll': '取消全选',
  'selectItems': '选择项目', 'selectedCount': '已选 {n} 项', 'duplicate': '复制',
  'confirm': '确认', 'insert': '插入', 'move': '移动',
  'putBack': '恢复', 'clear': '清除', 'untitled': '无标题',
  'tabTasks': '任务', 'tabNotes': '笔记', 'tabCalendar': '日历',
  'calendarView': '视图', 'calendarViewMonths': '按月', 'calendarViewContinuous': '连续',
  'tabRoutines': '习惯', 'tabSettings': '设置',
  'inbox': '收件箱', 'today': '今天', 'yesterday': '昨天', 'tomorrow': '明天', 'upcoming': '即将',
  'allTasks': '所有任务',
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
  'newSpace': '新空间', 'spaceName': '空间名称', 'spaces': '空间',
  'noOptionsYet': '尚无选项。', 'sectionModules': '模块',
  'appBadgeIncludeRoutines': '包含今天的习惯', 'showRoutinesInToday': '在“今天”中显示习惯', 'showRoutinesInCalendar': '在日历中显示习惯', 'showRoutinesHint': '今天的习惯会在“任务 → 今天”和日历的当日视图中以可折叠的分区显示。', 'sectionShowRoutines': '显示习惯于',
  'sectionTaskFields': '任务字段',
  'taskFieldsHint': '隐藏的字段在编辑任务时不会显示。',
  'sectionBody': '正文', 'useMarkdown': '使用 Markdown 格式',
  'useMarkdownHint': '关闭时，正文将以纯文本显示和编辑，格式工具栏被隐藏。',
  'showHidePriority': '优先级', 'showHideDate': '日期',
  'showHideRepeat': '重复', 'showHideList': '列表',
  'showHideDuration': '时长', 'showHideTags': '标签',
  'showHideReminders': '提醒',
  'sectionTasksUi': '界面',
  'showAddFolderButton': '添加文件夹按钮',
  'addList': '添加列表', 'addFolder': '添加文件夹',
  'sortTasks': '排序任务', 'sortDefault': '默认',
  'sortByCreation': '按创建日期', 'sortByName': '按名称',
  'sortByPriority': '按优先级', 'sortByDateTime': '按日期和时间',
  'addToCalendar': '添加到日历', 'taskOption': '任务', 'eventOption': '事件',
  'calendarAllowCreatingTasks': '允许创建任务',
  'calendarAllowCreatingEvents': '允许创建事件',
  'calendarDefaultContainer': '新事件的默认位置',
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
  'repeat': '重复', 'repeatNone': '不重复',
  'repeatDaily': '每天', 'repeatWeekly': '每周',
  'repeatMonthly': '每月', 'repeatYearly': '每年',
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
  'editList': '编辑列表', 'editFolder': '编辑文件夹',
  'listColor': '列表颜色', 'customColor': '自定义颜色',
  'listType': '列表类型',
  'listTypeTasks': '任务', 'listTypeBirthdays': '生日',
  'listTypeShopping': '购物',
  'addBirthday': '添加生日', 'birthdayName': '姓名',
  'birthDate': '出生日期', 'includeYear': '包含年份',
  'completable': '显示复选框', 'thisYear': '今年',
  'nextYear': '明年', 'addSection': '添加分组',
  'sectionName': '分组名称', 'sectionCompleted': '已完成',
  'turns': '将满',
  'selectColor': '选择颜色', 'otherDots': '其他…',
  'chooseIcon': '选择图标', 'opening': '打开中…',
  'chooseFromLibrary': '从图库选择',
  'createFolder': '创建文件夹', 'createList': '创建列表',
  'folder': '文件夹', 'list': '列表',
  'newRoutine': '新习惯', 'editRoutine': '编辑习惯',
  'sectionFrequency': '频率',
  'freqDaily': '每天', 'freqSpecificDays': '指定日期', 'freqDaysAfter': '完成后 X 天',
  'freqInterval': '间隔', 'startDate': '开始日期', 'routineIntervalEvery': '每', 'routineIntervalDays': '{n} 天', 'waitForCompletion': '等待完成', 'waitForCompletionInfo': '完成当前后再安排下一次。错过的日子会保持逾期。', 'addReminder': '添加提醒', 'reminderTypeTime': '在某时间', 'reminderTypeSpread': '全天分散', 'reminderTypeAfterEach': '每次之后', 'reminderEveryLabel': '每', 'reminderAfterEachLabel': '每次之后', 'recordOnOriginalDate': '标记在原始日期', 'completeTodayShift': '今天完成（顺延）', 'overdueRoutineTitle': '逾期的习惯', 'overdueRoutineBody': '你是什么时候做的？', 'overdueLabel': '逾期',
  'daysAfterCompletion': '完成后天数',
  'autoReset': '自动重置', 'autoResetEveryDay': '每天',
  'autoResetNone': '不重置',
  'sectionGoal': '目标',
  'goalAchieveAll': '全部完成', 'goalCertainAmount': '达到一定数量',
  'dailyGoal': '每日目标', 'recordPerTap': '每次点击记录',
  'recordManual': '手动记录', 'recordManualInfo': '每次勾选该习惯时输入数量', 'recordAmountPrompt': '数量（{unit}）', 'showEventsInToday': '在“今天”中显示事件', 'includeInTodayCount': '计入“今天”的计数',
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
  'select': '選択', 'selectAll': 'すべて選択', 'deselectAll': 'すべて解除',
  'selectItems': '項目を選択', 'selectedCount': '{n}件選択', 'duplicate': '複製',
  'confirm': '確認', 'insert': '挿入', 'move': '移動',
  'putBack': '戻す', 'clear': 'クリア', 'untitled': '無題',
  'tabTasks': 'タスク', 'tabNotes': 'ノート', 'tabCalendar': 'カレンダー',
  'calendarView': '表示', 'calendarViewMonths': '月別', 'calendarViewContinuous': '連続',
  'tabRoutines': '習慣', 'tabSettings': '設定',
  'inbox': '受信箱', 'today': '今日', 'yesterday': '昨日', 'tomorrow': '明日', 'upcoming': '今後',
  'allTasks': 'すべてのタスク',
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
  'newSpace': '新規スペース', 'spaceName': 'スペース名', 'spaces': 'スペース',
  'noOptionsYet': 'まだ設定はありません。', 'sectionModules': 'モジュール',
  'appBadgeIncludeRoutines': '今日のルーティンを含める', 'showRoutinesInToday': '「今日」にルーティンを表示', 'showRoutinesInCalendar': 'カレンダーにルーティンを表示', 'showRoutinesHint': '今日のルーティンは、タスク → 今日 とカレンダーの日表示に折りたたみ可能なセクションとして表示されます。', 'sectionShowRoutines': 'ルーティンの表示先',
  'sectionTaskFields': 'タスク項目',
  'taskFieldsHint': '非表示の項目はタスク編集時に表示されません。',
  'sectionBody': '本文', 'useMarkdown': 'Markdown でフォーマット',
  'useMarkdownHint': 'オフにすると、本文はプレーンテキストとして表示・編集され、書式バーは非表示になります。',
  'showHidePriority': '優先度', 'showHideDate': '日付',
  'showHideRepeat': '繰り返し', 'showHideList': 'リスト',
  'showHideDuration': '所要時間', 'showHideTags': 'タグ',
  'showHideReminders': 'リマインダー',
  'sectionTasksUi': 'インターフェース',
  'showAddFolderButton': 'フォルダ追加ボタン',
  'addList': 'リストを追加', 'addFolder': 'フォルダを追加',
  'sortTasks': 'タスクを並べ替え', 'sortDefault': 'デフォルト',
  'sortByCreation': '作成日順', 'sortByName': '名前順',
  'sortByPriority': '優先度順', 'sortByDateTime': '日時順',
  'addToCalendar': 'カレンダーに追加', 'taskOption': 'タスク', 'eventOption': 'イベント',
  'calendarAllowCreatingTasks': 'タスクの作成を許可',
  'calendarAllowCreatingEvents': 'イベントの作成を許可',
  'calendarDefaultContainer': '新しいイベントの既定の場所',
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
  'repeat': '繰り返し', 'repeatNone': '繰り返しなし',
  'repeatDaily': '毎日', 'repeatWeekly': '毎週',
  'repeatMonthly': '毎月', 'repeatYearly': '毎年',
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
  'editList': 'リストを編集', 'editFolder': 'フォルダを編集',
  'listColor': 'リストの色', 'customColor': 'カスタムカラー',
  'listType': 'リストの種類',
  'listTypeTasks': 'タスク', 'listTypeBirthdays': '誕生日',
  'listTypeShopping': '買い物',
  'addBirthday': '誕生日を追加', 'birthdayName': '名前',
  'birthDate': '生年月日', 'includeYear': '年を含める',
  'completable': 'チェックボックスを表示', 'thisYear': '今年',
  'nextYear': '来年', 'addSection': 'セクションを追加',
  'sectionName': 'セクション名', 'sectionCompleted': '完了',
  'turns': '歳',
  'selectColor': '色を選択', 'otherDots': 'その他…',
  'chooseIcon': 'アイコンを選択', 'opening': '開いています…',
  'chooseFromLibrary': 'ライブラリから選択',
  'createFolder': 'フォルダを作成', 'createList': 'リストを作成',
  'folder': 'フォルダ', 'list': 'リスト',
  'newRoutine': '新しい習慣', 'editRoutine': '習慣を編集',
  'sectionFrequency': '頻度',
  'freqDaily': '毎日', 'freqSpecificDays': '特定の曜日', 'freqDaysAfter': '完了から X 日後',
  'freqInterval': '間隔', 'startDate': '開始日', 'routineIntervalEvery': '毎', 'routineIntervalDays': '{n} 日', 'waitForCompletion': '完了を待つ', 'waitForCompletionInfo': 'これを完了してから次回を予定します。逃した日は期限切れのまま残ります。', 'addReminder': 'リマインダーを追加', 'reminderTypeTime': '指定時刻', 'reminderTypeSpread': '一日に分散', 'reminderTypeAfterEach': '各回のあと', 'reminderEveryLabel': '毎', 'reminderAfterEachLabel': '各回のあと', 'recordOnOriginalDate': '元の日に記録', 'completeTodayShift': '今日完了（次回をずらす）', 'overdueRoutineTitle': '期限切れの習慣', 'overdueRoutineBody': 'いつ行いましたか？', 'overdueLabel': '期限切れ',
  'daysAfterCompletion': '完了からの日数',
  'autoReset': '自動リセット', 'autoResetEveryDay': '毎日',
  'autoResetNone': 'リセットしない',
  'sectionGoal': '目標',
  'goalAchieveAll': 'すべて達成', 'goalCertainAmount': '一定量に達する',
  'dailyGoal': '1日の目標', 'recordPerTap': 'タップごとに記録',
  'recordManual': '手動で記録', 'recordManualInfo': 'このルーティンをチェックするたびに数量を入力', 'recordAmountPrompt': '数量（{unit}）', 'showEventsInToday': '「今日」にイベントを表示', 'includeInTodayCount': '「今日」のカウントに含める',
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
