import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/budget.dart';
import '../models/finance_account.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';

/// Owns the Finance domain: accounts, categories, transactions and budgets.
///
/// Money is stored in each account's own currency (minor units). Aggregates
/// that could mix currencies (net worth, monthly totals) are therefore computed
/// **per currency** — no exchange rates are ever applied, so every figure is
/// exact. A transaction's currency is that of its [FinanceTransaction.accountId].
class FinanceController with ChangeNotifier {
  FinanceController(this._db);

  final DatabaseService _db;

  List<FinanceAccount> _accounts = [];
  List<FinanceCategory> _categories = [];
  List<FinanceTransaction> _transactions = [];
  List<Budget> _budgets = [];
  String _defaultCurrency = 'USD';

  List<FinanceAccount> get accounts => List.unmodifiable(_accounts);
  List<FinanceAccount> get activeAccounts =>
      _accounts.where((a) => !a.isArchived).toList();
  List<FinanceCategory> get categories => List.unmodifiable(_categories);
  List<FinanceCategory> get incomeCategories =>
      _categories.where((c) => c.isIncome).toList();
  List<FinanceCategory> get expenseCategories =>
      _categories.where((c) => c.isExpense).toList();
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);
  List<Budget> get budgets => List.unmodifiable(_budgets);
  String get defaultCurrency => _defaultCurrency;

  bool get isEmpty => _accounts.isEmpty && _transactions.isEmpty;

  Future<void> load() async {
    _accounts = await _db.getFinanceAccounts();
    _categories = await _db.getFinanceCategories();
    _transactions = await _db.getFinanceTransactions();
    _budgets = await _db.getBudgets();
    await _loadPrefs();
    await _seedCategoriesIfNeeded();
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    final settings = await _db.getAppSettings();
    for (final row in settings) {
      if (row['key'] == 'finance_default_currency') {
        _defaultCurrency = row['value'] as String;
      }
    }
  }

  /// Sets the currency new accounts default to (the last one the user picked).
  Future<void> setDefaultCurrency(String code) async {
    if (code == _defaultCurrency) return;
    _defaultCurrency = code;
    await _db.setAppSetting('finance_default_currency', code);
  }

  // ── Lookups ────────────────────────────────────────────────────────────────

  FinanceAccount? accountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  FinanceCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String currencyOf(FinanceTransaction txn) =>
      accountById(txn.accountId)?.currencyCode ?? _defaultCurrency;

  /// All currency codes used by at least one account, in display order.
  List<String> get currenciesInUse {
    final seen = <String>[];
    for (final a in activeAccounts) {
      if (!seen.contains(a.currencyCode)) seen.add(a.currencyCode);
    }
    if (seen.isEmpty) seen.add(_defaultCurrency);
    return seen;
  }

  // ── Balances ───────────────────────────────────────────────────────────────

  /// Current balance of [accountId] (opening balance + every transaction that
  /// touches it), in that account's currency.
  int balanceOf(String accountId) {
    final acc = accountById(accountId);
    if (acc == null) return 0;
    var total = acc.openingBalance;
    for (final t in _transactions) {
      total += t.signedFor(accountId);
    }
    return total;
  }

  /// Net worth per currency across non-archived accounts.
  Map<String, int> netWorthByCurrency() {
    final map = <String, int>{};
    for (final a in activeAccounts) {
      map[a.currencyCode] = (map[a.currencyCode] ?? 0) + balanceOf(a.id);
    }
    return map;
  }

  // ── Transaction queries ──────────────────────────────────────────────────

  List<FinanceTransaction> transactionsForAccount(String accountId) =>
      _transactions
          .where((t) => t.accountId == accountId || t.toAccountId == accountId)
          .toList();

  List<FinanceTransaction> recentTransactions({int limit = 50}) {
    final sorted = [..._transactions]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  /// All transactions, newest first (already stored that way, but copied so the
  /// caller can't mutate internal state).
  List<FinanceTransaction> allTransactionsSorted() {
    return [..._transactions]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Total income / expense in [currency] within the period that contains
  /// [anchor] (defaults to now). Transfers never count as income or expense.
  int periodIncome(String currency, String period, [DateTime? anchor]) =>
      _periodSum(currency, period, FinanceTransaction.typeIncome, anchor);

  int periodExpense(String currency, String period, [DateTime? anchor]) =>
      _periodSum(currency, period, FinanceTransaction.typeExpense, anchor);

  int _periodSum(
      String currency, String period, String type, DateTime? anchor) {
    final (start, end) = periodWindow(period, anchor ?? DateTime.now());
    var total = 0;
    for (final t in _transactions) {
      if (t.type != type) continue;
      if (currencyOf(t) != currency) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      total += t.amount;
    }
    return total;
  }

  /// Expense totals per category for [currency] in the period containing
  /// [anchor]. Keyed by categoryId; the empty-string key holds uncategorised
  /// spending.
  Map<String, int> categorySpending(
      String currency, String period, DateTime anchor) {
    final (start, end) = periodWindow(period, anchor);
    final map = <String, int>{};
    for (final t in _transactions) {
      if (!t.isExpense) continue;
      if (currencyOf(t) != currency) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      final key = t.categoryId ?? '';
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  /// Amount spent against [budget] in the period containing [anchor].
  int spentForBudget(Budget budget, [DateTime? anchor]) {
    final (start, end) = periodWindow(budget.period, anchor ?? DateTime.now());
    var total = 0;
    for (final t in _transactions) {
      if (!t.isExpense) continue;
      if (currencyOf(t) != budget.currencyCode) continue;
      if (budget.categoryId != null && t.categoryId != budget.categoryId) {
        continue;
      }
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      total += t.amount;
    }
    return total;
  }

  /// Half-open [start, end) window for a period that contains [anchor].
  static (DateTime, DateTime) periodWindow(String period, DateTime anchor) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    switch (period) {
      case Budget.periodWeekly:
        final start = day.subtract(Duration(days: day.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case Budget.periodYearly:
        return (DateTime(anchor.year), DateTime(anchor.year + 1));
      case Budget.periodMonthly:
      default:
        final start = DateTime(anchor.year, anchor.month);
        final end = DateTime(anchor.year, anchor.month + 1);
        return (start, end);
    }
  }

  // ── Account CRUD ─────────────────────────────────────────────────────────

  Future<void> addAccount(FinanceAccount account) async {
    final maxOrder =
        _accounts.fold<int>(-1, (m, a) => a.sortOrder > m ? a.sortOrder : m);
    final ordered = account.copyWith(sortOrder: maxOrder + 1);
    await _db.insertFinanceAccount(ordered);
    _accounts.add(ordered);
    await setDefaultCurrency(account.currencyCode);
    notifyListeners();
  }

  Future<void> updateAccount(FinanceAccount account) async {
    await _db.updateFinanceAccount(account);
    final i = _accounts.indexWhere((a) => a.id == account.id);
    if (i != -1) _accounts[i] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteFinanceAccount(id);
    _accounts.removeWhere((a) => a.id == id);
    _transactions
        .removeWhere((t) => t.accountId == id || t.toAccountId == id);
    notifyListeners();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final list = activeAccounts;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(target.clamp(0, list.length), moved);
    for (var i = 0; i < list.length; i++) {
      final idx = _accounts.indexWhere((a) => a.id == list[i].id);
      if (idx != -1) _accounts[idx] = _accounts[idx].copyWith(sortOrder: i);
    }
    notifyListeners();
    await _db.updateFinanceAccountSortOrders(_accounts);
  }

  // ── Category CRUD ────────────────────────────────────────────────────────

  Future<void> addCategory(FinanceCategory category) async {
    final maxOrder = _categories.fold<int>(
        -1, (m, c) => c.sortOrder > m ? c.sortOrder : m);
    final ordered = category.copyWith(sortOrder: maxOrder + 1);
    await _db.insertFinanceCategory(ordered);
    _categories.add(ordered);
    notifyListeners();
  }

  Future<void> updateCategory(FinanceCategory category) async {
    await _db.updateFinanceCategory(category);
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i != -1) _categories[i] = category;
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteFinanceCategory(id);
    _categories.removeWhere((c) => c.id == id);
    // Reflect the un-categorisation the DB applied to existing rows.
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].categoryId == id) {
        _transactions[i] = _transactions[i].copyWith(clearCategoryId: true);
      }
    }
    for (var i = 0; i < _budgets.length; i++) {
      if (_budgets[i].categoryId == id) {
        _budgets[i] = _budgets[i].copyWith(clearCategoryId: true);
      }
    }
    notifyListeners();
  }

  // ── Transaction CRUD ───────────────────────────────────────────────────

  Future<void> addTransaction(FinanceTransaction txn) async {
    await _db.insertFinanceTransaction(txn);
    _transactions.insert(0, txn);
    notifyListeners();
  }

  Future<void> updateTransaction(FinanceTransaction txn) async {
    await _db.updateFinanceTransaction(txn);
    final i = _transactions.indexWhere((t) => t.id == txn.id);
    if (i != -1) _transactions[i] = txn;
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteFinanceTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Re-inserts a previously deleted transaction (used by the Undo banner).
  Future<void> restoreTransaction(FinanceTransaction txn) async {
    await _db.insertFinanceTransaction(txn);
    _transactions.insert(0, txn);
    notifyListeners();
  }

  // ── Budget CRUD ──────────────────────────────────────────────────────────

  Future<void> addBudget(Budget budget) async {
    final maxOrder =
        _budgets.fold<int>(-1, (m, b) => b.sortOrder > m ? b.sortOrder : m);
    final ordered = budget.copyWith(sortOrder: maxOrder + 1);
    await _db.insertBudget(ordered);
    _budgets.add(ordered);
    notifyListeners();
  }

  Future<void> updateBudget(Budget budget) async {
    await _db.updateBudget(budget);
    final i = _budgets.indexWhere((b) => b.id == budget.id);
    if (i != -1) _budgets[i] = budget;
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  // ── Seeding ────────────────────────────────────────────────────────────────

  Future<void> _seedCategoriesIfNeeded() async {
    final settings = await _db.getAppSettings();
    final seeded = settings.any((r) => r['key'] == 'finance_seeded');
    if (seeded || _categories.isNotEmpty) return;
    final defaults = <FinanceCategory>[
      FinanceCategory(name: 'Salary', kind: 'income', iconId: 'briefcase', colorValue: 0xFF34C759, sortOrder: 0),
      FinanceCategory(name: 'Business', kind: 'income', iconId: 'chart_bar', colorValue: 0xFF30B0C7, sortOrder: 1),
      FinanceCategory(name: 'Gifts', kind: 'income', iconId: 'gift', colorValue: 0xFFFF2D55, sortOrder: 2),
      FinanceCategory(name: 'Groceries', kind: 'expense', iconId: 'cart', colorValue: 0xFF34C759, sortOrder: 3),
      FinanceCategory(name: 'Dining', kind: 'expense', iconId: 'fork_knife', colorValue: 0xFFFF9500, sortOrder: 4),
      FinanceCategory(name: 'Transport', kind: 'expense', iconId: 'car', colorValue: 0xFF007AFF, sortOrder: 5),
      FinanceCategory(name: 'Housing', kind: 'expense', iconId: 'house', colorValue: 0xFFA2845E, sortOrder: 6),
      FinanceCategory(name: 'Bills', kind: 'expense', iconId: 'bolt', colorValue: 0xFFFFCC00, sortOrder: 7),
      FinanceCategory(name: 'Shopping', kind: 'expense', iconId: 'bag', colorValue: 0xFFAF52DE, sortOrder: 8),
      FinanceCategory(name: 'Health', kind: 'expense', iconId: 'heart', colorValue: 0xFFFF3B30, sortOrder: 9),
      FinanceCategory(name: 'Entertainment', kind: 'expense', iconId: 'film', colorValue: 0xFF5856D6, sortOrder: 10),
    ];
    for (final c in defaults) {
      await _db.insertFinanceCategory(c);
    }
    _categories = defaults;
    await _db.setAppSetting('finance_seeded', 'true');
  }
}
