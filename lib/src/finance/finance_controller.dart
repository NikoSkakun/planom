import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/finance_account.dart';
import '../models/finance_budget.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';
import 'finance_format.dart';

/// Totals for one period (a month or a week): money in, money out, and the
/// resulting balance — all in minor units (cents).
class FinanceSummary {
  const FinanceSummary({required this.income, required this.expenses});

  final int income;
  final int expenses;

  int get balance => income - expenses;

  static const empty = FinanceSummary(income: 0, expenses: 0);
}

/// An account paired with its computed balance, in the account's own currency.
class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final FinanceAccount account;
  final int balance;
}

/// One category's slice of a period's spending, used by the breakdown list and
/// the budget rows.
class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.amount,
    required this.count,
  });

  /// null = "Uncategorized".
  final String? categoryId;
  final int amount;
  final int count;
}

/// A budget paired with what has actually been spent against it in the period
/// being viewed.
class BudgetProgress {
  const BudgetProgress({required this.budget, required this.spent});

  final FinanceBudget budget;
  final int spent;

  int get remaining => budget.amount - spent;
  bool get isOver => spent > budget.amount;

  /// 0.0 … 1.0 (clamped) — how full the allowance is.
  double get fraction =>
      budget.amount <= 0 ? 0.0 : (spent / budget.amount).clamp(0.0, 1.0);
}

/// Owns the active space's finance data: transactions, categories and budgets.
///
/// Deletes are permanent (there is no Finance trash) — the UI pairs every
/// delete with an Undo banner that re-inserts the row, the same approach the
/// Calendar takes for events.
class FinanceController with ChangeNotifier {
  FinanceController(this._db);

  final DatabaseService _db;

  List<FinanceTransaction> _transactions = [];
  List<FinanceCategory> _categories = [];
  List<FinanceBudget> _budgets = [];
  List<FinanceAccount> _accounts = [];

  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);
  List<FinanceCategory> get categories => List.unmodifiable(_categories);
  List<FinanceBudget> get budgets => List.unmodifiable(_budgets);

  /// Every account, archived ones included (history still references them).
  List<FinanceAccount> get accounts => List.unmodifiable(_accounts);

  /// Accounts offered in pickers and shown on the tab.
  List<FinanceAccount> get activeAccounts =>
      List.unmodifiable(_accounts.where((a) => !a.isArchived));

  FinanceAccount? accountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The currency an entry is denominated in: its account's, or the space
  /// default when it has no account.
  String currencyOf(FinanceTransaction tx) =>
      accountById(tx.accountId)?.currencyCode ?? FinanceCurrency.code;

  /// Currency codes in play: every active account's, the currency of any
  /// account an entry still points at (archived ones included, or their
  /// entries would show in the ledger with no summary card covering them),
  /// plus the space default when an entry has no account at all. Ordered with
  /// the default first.
  List<String> get currenciesInUse {
    final codes = <String>{};
    if (_transactions.any((t) => t.accountId == null)) {
      codes.add(FinanceCurrency.code);
    }
    for (final a in activeAccounts) {
      codes.add(a.currencyCode);
    }
    for (final t in _transactions) {
      final account = accountById(t.accountId);
      if (account != null) codes.add(account.currencyCode);
    }
    if (codes.isEmpty) codes.add(FinanceCurrency.code);
    final ordered = codes.toList()
      ..sort((a, b) {
        if (a == FinanceCurrency.code) return -1;
        if (b == FinanceCurrency.code) return 1;
        return a.compareTo(b);
      });
    return ordered;
  }

  /// Current balance of [account]: its opening balance plus every entry that
  /// touched it (transfers move value between two accounts).
  int balanceOf(FinanceAccount account) {
    var total = account.initialBalance;
    for (final t in _transactions) {
      switch (t.type) {
        case FinanceEntryType.income:
          if (t.accountId == account.id) total += t.amount;
        case FinanceEntryType.expense:
          if (t.accountId == account.id) total -= t.amount;
        case FinanceEntryType.transfer:
          if (t.accountId == account.id) total -= t.amount;
          if (t.toAccountId == account.id) total += t.creditedAmount;
      }
    }
    return total;
  }

  List<AccountBalance> get accountBalances => [
        for (final a in activeAccounts)
          AccountBalance(account: a, balance: balanceOf(a)),
      ];

  /// Net worth per currency across active accounts — never summed across
  /// currencies, because the app applies no exchange rates.
  Map<String, int> totalsByCurrency() {
    final totals = <String, int>{};
    for (final a in activeAccounts) {
      totals[a.currencyCode] = (totals[a.currencyCode] ?? 0) + balanceOf(a);
    }
    return totals;
  }

  List<FinanceCategory> categoriesOfType(FinanceEntryType type) =>
      _categories.where((c) => c.type == type).toList();

  FinanceCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  FinanceTransaction? transactionById(String id) {
    for (final t in _transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load() async {
    _transactions = await _db.getFinanceTransactions();
    _categories = await _db.getFinanceCategories();
    _budgets = await _db.getFinanceBudgets();
    _accounts = await _db.getFinanceAccounts();
    // One starter account so a first entry has somewhere to live. Same
    // "only when the space is untouched" rule as the categories below.
    if (_accounts.isEmpty && _transactions.isEmpty) {
      final cash = FinanceAccount(
        name: 'Cash',
        type: FinanceAccountType.cash,
        currencyCode: FinanceCurrency.code,
        iconId: 'banknote',
        color: 0xFF34C759,
      );
      await _db.insertFinanceAccount(cash);
      _accounts = await _db.getFinanceAccounts();
    }
    // Seed a starter set of categories the first time this space's Finance
    // data is touched. Only when the space is completely empty, so a user who
    // deliberately deleted every category (but kept entries) doesn't get them
    // back on the next launch.
    if (_categories.isEmpty && _transactions.isEmpty) {
      final seeded = defaultCategories();
      await _db.insertFinanceCategories(seeded);
      _categories = await _db.getFinanceCategories();
    }
    notifyListeners();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Whether [tx] belongs to [accountId] — either side of a transfer counts.
  bool _touchesAccount(FinanceTransaction tx, String accountId) =>
      tx.accountId == accountId || tx.toAccountId == accountId;

  /// Transactions dated within [from] (inclusive) … [to] (exclusive), newest
  /// first. [accountId] narrows to one account (both legs of a transfer);
  /// [currency] narrows to entries denominated in that currency.
  List<FinanceTransaction> transactionsInRange(
    DateTime from,
    DateTime to, {
    String? accountId,
    String? currency,
  }) {
    final result = _transactions
        .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
        .where((t) => accountId == null || _touchesAccount(t, accountId))
        .where((t) => currency == null || currencyOf(t) == currency)
        .toList();
    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.creationDate.compareTo(a.creationDate);
    });
    return result;
  }

  List<FinanceTransaction> transactionsForMonth(
    DateTime month, {
    String? accountId,
    String? currency,
  }) =>
      transactionsInRange(monthStart(month), nextMonthStart(month),
          accountId: accountId, currency: currency);

  /// Money in / out for the range. Transfers are ignored — moving money
  /// between your own accounts is neither income nor spending.
  FinanceSummary summaryInRange(
    DateTime from,
    DateTime to, {
    String? accountId,
    String? currency,
  }) {
    var income = 0;
    var expenses = 0;
    for (final t in transactionsInRange(from, to,
        accountId: accountId, currency: currency)) {
      switch (t.type) {
        case FinanceEntryType.income:
          income += t.amount;
        case FinanceEntryType.expense:
          expenses += t.amount;
        case FinanceEntryType.transfer:
          break;
      }
    }
    return FinanceSummary(income: income, expenses: expenses);
  }

  FinanceSummary summaryForMonth(
    DateTime month, {
    String? accountId,
    String? currency,
  }) =>
      summaryInRange(monthStart(month), nextMonthStart(month),
          accountId: accountId, currency: currency);

  /// Spending (expenses only) per category within the range, biggest first.
  /// Categories with nothing spent are omitted; uncategorized entries are
  /// grouped under a null [CategorySpend.categoryId].
  List<CategorySpend> spendByCategory(
    DateTime from,
    DateTime to, {
    String? accountId,
    String? currency,
  }) {
    final totals = <String?, int>{};
    final counts = <String?, int>{};
    for (final t in transactionsInRange(from, to,
        accountId: accountId, currency: currency)) {
      if (t.type != FinanceEntryType.expense) continue;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }
    final result = [
      for (final entry in totals.entries)
        CategorySpend(
          categoryId: entry.key,
          amount: entry.value,
          count: counts[entry.key] ?? 0,
        ),
    ];
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  List<CategorySpend> spendByCategoryForMonth(
    DateTime month, {
    String? accountId,
    String? currency,
  }) =>
      spendByCategory(monthStart(month), nextMonthStart(month),
          accountId: accountId, currency: currency);

  /// Total spent against [budget] during the period containing [reference].
  /// Monthly budgets measure the calendar month; weekly ones the Mon–Sun week.
  ///
  /// Budgets are denominated in [currency] (the space default unless the UI
  /// says otherwise) — entries in another currency are left out rather than
  /// converted, since the app holds no exchange rates.
  int spentAgainst(
    FinanceBudget budget,
    DateTime reference, {
    String? currency,
    String? accountId,
  }) {
    final (from, to) = budget.period == BudgetPeriod.weekly
        ? (weekStart(reference), weekStart(reference).add(const Duration(days: 7)))
        : (monthStart(reference), nextMonthStart(reference));
    var total = 0;
    for (final t in transactionsInRange(from, to,
        accountId: accountId, currency: currency ?? FinanceCurrency.code)) {
      if (t.type != FinanceEntryType.expense) continue;
      if (budget.categoryId != null && t.categoryId != budget.categoryId) {
        continue;
      }
      total += t.amount;
    }
    return total;
  }

  /// Every budget paired with its spend for the period containing [reference],
  /// overall budget first, then per-category by descending usage.
  List<BudgetProgress> budgetProgress(
    DateTime reference, {
    String? currency,
    String? accountId,
  }) {
    final result = [
      for (final b in _budgets)
        BudgetProgress(
          budget: b,
          spent: spentAgainst(b, reference,
              currency: currency, accountId: accountId),
        ),
    ];
    result.sort((a, b) {
      if (a.budget.isOverall != b.budget.isOverall) {
        return a.budget.isOverall ? -1 : 1;
      }
      return b.fraction.compareTo(a.fraction);
    });
    return result;
  }

  /// The budget for [categoryId] (null = the overall budget), or null when
  /// none is set.
  FinanceBudget? budgetFor(String? categoryId) {
    for (final b in _budgets) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  /// Months (normalized to the 1st) that hold at least one transaction, newest
  /// first. Used to decide how far the month navigator can walk back.
  List<DateTime> monthsWithData() {
    final seen = <String>{};
    final months = <DateTime>[];
    for (final t in _transactions) {
      final key = '${t.date.year}-${t.date.month}';
      if (seen.add(key)) months.add(DateTime(t.date.year, t.date.month));
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addTransaction(FinanceTransaction tx) async {
    await _db.insertFinanceTransaction(tx);
    _transactions = [tx, ..._transactions];
    notifyListeners();
  }

  Future<void> updateTransaction(FinanceTransaction updated) async {
    await _db.updateFinanceTransaction(updated);
    final i = _transactions.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _transactions = [..._transactions]..[i] = updated;
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteFinanceTransaction(id);
    _transactions = _transactions.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> addAccount(FinanceAccount account) async {
    final withOrder = account.sortOrder == 0
        ? account.copyWith(sortOrder: _nextAccountSortOrder())
        : account;
    await _db.insertFinanceAccount(withOrder);
    _accounts = [..._accounts, withOrder]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> updateAccount(FinanceAccount updated) async {
    await _db.updateFinanceAccount(updated);
    final i = _accounts.indexWhere((a) => a.id == updated.id);
    if (i == -1) return;
    _accounts = [..._accounts]..[i] = updated;
    notifyListeners();
  }

  /// Deletes an account. Entries that referenced it survive and fall back to
  /// the space's default currency; a transfer that loses either leg is left
  /// pointing at whichever account remains.
  Future<void> deleteAccount(String id) async {
    await _db.deleteFinanceAccount(id);
    _accounts = _accounts.where((a) => a.id != id).toList();
    _transactions = [
      for (final t in _transactions)
        if (t.accountId == id && t.toAccountId == id)
          t.copyWith(clearAccountId: true, clearToAccountId: true)
        else if (t.accountId == id)
          t.copyWith(clearAccountId: true)
        else if (t.toAccountId == id)
          t.copyWith(clearToAccountId: true)
        else
          t,
    ];
    notifyListeners();
  }

  Future<void> setAccountArchived(String id, bool archived) async {
    final account = accountById(id);
    if (account == null || account.isArchived == archived) return;
    await updateAccount(account.copyWith(isArchived: archived));
  }

  /// ReorderableListView semantics. [visible] is the list the user is
  /// actually dragging in — when archived accounts are hidden, its indices
  /// don't line up with [accounts], so the move is resolved through ids and
  /// then applied to the full list.
  Future<void> reorderAccounts(
    int oldIndex,
    int newIndex, {
    List<FinanceAccount>? visible,
  }) async {
    final shown = visible ?? _accounts;
    if (oldIndex < 0 || oldIndex >= shown.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final movedId = shown[oldIndex].id;
    // Drop it in front of whatever now sits at newIndex among the visible
    // rows; landing past the end means "put it last".
    final rest = [...shown]..removeAt(oldIndex);
    final anchorId =
        newIndex < rest.length ? rest[newIndex.clamp(0, rest.length - 1)].id : null;

    final ordered = [..._accounts];
    final from = ordered.indexWhere((a) => a.id == movedId);
    if (from < 0) return;
    final moved = ordered.removeAt(from);
    final anchorAt =
        anchorId == null ? -1 : ordered.indexWhere((a) => a.id == anchorId);
    ordered.insert(anchorAt < 0 ? ordered.length : anchorAt, moved);
    final renumbered = [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(sortOrder: i),
    ];
    await _db.updateFinanceAccountSortOrders(renumbered);
    _accounts = renumbered;
    notifyListeners();
  }

  int _nextAccountSortOrder() {
    var max = -1;
    for (final a in _accounts) {
      if (a.sortOrder > max) max = a.sortOrder;
    }
    return max + 1;
  }

  Future<void> addCategory(FinanceCategory category) async {
    final withOrder = category.sortOrder == 0
        ? category.copyWith(sortOrder: _nextCategorySortOrder())
        : category;
    await _db.insertFinanceCategory(withOrder);
    _categories = [..._categories, withOrder]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> updateCategory(FinanceCategory updated) async {
    await _db.updateFinanceCategory(updated);
    final i = _categories.indexWhere((c) => c.id == updated.id);
    if (i == -1) return;
    _categories = [..._categories]..[i] = updated;
    notifyListeners();
  }

  /// Deletes a category. Transactions filed under it stay, but become
  /// uncategorized; any budget for it is removed with it.
  Future<void> deleteCategory(String id) async {
    await _db.deleteFinanceCategory(id);
    _categories = _categories.where((c) => c.id != id).toList();
    _budgets = _budgets.where((b) => b.categoryId != id).toList();
    _transactions = [
      for (final t in _transactions)
        if (t.categoryId == id) t.copyWith(clearCategoryId: true) else t,
    ];
    notifyListeners();
  }

  /// Reorders the categories of [type] (ReorderableListView semantics) and
  /// persists the new positions.
  Future<void> reorderCategories(
      FinanceEntryType type, int oldIndex, int newIndex) async {
    final ofType = categoriesOfType(type);
    if (oldIndex < 0 || oldIndex >= ofType.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ofType.removeAt(oldIndex);
    ofType.insert(newIndex.clamp(0, ofType.length), moved);

    // Re-index only the reordered type; the other type keeps its positions,
    // offset so the two blocks never interleave.
    final others = categoriesOfType(type == FinanceEntryType.expense
        ? FinanceEntryType.income
        : FinanceEntryType.expense);
    final renumbered = <FinanceCategory>[];
    for (var i = 0; i < ofType.length; i++) {
      renumbered.add(ofType[i].copyWith(sortOrder: i));
    }
    for (var i = 0; i < others.length; i++) {
      renumbered.add(others[i].copyWith(sortOrder: ofType.length + i));
    }
    await _db.updateFinanceCategorySortOrders(renumbered);
    renumbered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _categories = renumbered;
    notifyListeners();
  }

  /// Sets (or replaces) the budget for [categoryId] — null means the overall
  /// spending budget. An [amount] of 0 or less clears it instead.
  Future<void> setBudget(
    String? categoryId,
    int amount, {
    BudgetPeriod period = BudgetPeriod.monthly,
  }) async {
    final existing = budgetFor(categoryId);
    if (amount <= 0) {
      if (existing != null) await clearBudget(categoryId);
      return;
    }
    if (existing != null) {
      final updated = existing.copyWith(amount: amount, period: period);
      await _db.updateFinanceBudget(updated);
      _budgets = [
        for (final b in _budgets) if (b.id == updated.id) updated else b,
      ];
    } else {
      final created = FinanceBudget(
        categoryId: categoryId,
        amount: amount,
        period: period,
      );
      await _db.insertFinanceBudget(created);
      _budgets = [..._budgets, created];
    }
    notifyListeners();
  }

  Future<void> clearBudget(String? categoryId) async {
    final existing = budgetFor(categoryId);
    if (existing == null) return;
    await _db.deleteFinanceBudget(existing.id);
    _budgets = _budgets.where((b) => b.id != existing.id).toList();
    notifyListeners();
  }

  int _nextCategorySortOrder() {
    var max = -1;
    for (final c in _categories) {
      if (c.sortOrder > max) max = c.sortOrder;
    }
    return max + 1;
  }

  /// Starter categories seeded into an empty space. Names are English by
  /// design — they are user-editable data rows, not UI strings, so they stay
  /// whatever the user renames them to regardless of the app language.
  static List<FinanceCategory> defaultCategories() {
    const expense = <(String, String, int)>[
      ('Groceries', 'cart', 0xFF34C759),
      ('Eating Out', 'flame', 0xFFFF9500),
      ('Transport', 'car', 0xFF007AFF),
      ('Housing', 'house', 0xFFAF52DE),
      ('Bills', 'bolt', 0xFFFFCC00),
      ('Health', 'heart', 0xFFFF2D55),
      ('Shopping', 'bag', 0xFF5856D6),
      ('Fun', 'gamecontroller', 0xFF00C7BE),
      ('Other', 'tag', 0xFF8E8E93),
    ];
    const income = <(String, String, int)>[
      ('Salary', 'briefcase', 0xFF34C759),
      ('Gifts', 'gift', 0xFFFF2D55),
      ('Other Income', 'plus_circle', 0xFF30B0C7),
    ];
    final result = <FinanceCategory>[];
    var order = 0;
    for (final (name, icon, color) in expense) {
      result.add(FinanceCategory(
        name: name,
        iconId: icon,
        color: color,
        type: FinanceEntryType.expense,
        sortOrder: order++,
      ));
    }
    for (final (name, icon, color) in income) {
      result.add(FinanceCategory(
        name: name,
        iconId: icon,
        color: color,
        type: FinanceEntryType.income,
        sortOrder: order++,
      ));
    }
    return result;
  }
}

// ── Period helpers ───────────────────────────────────────────────────────────

/// Midnight on the 1st of [date]'s month.
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

/// Midnight on the 1st of the month after [date]'s (handles the year roll).
DateTime nextMonthStart(DateTime date) => DateTime(date.year, date.month + 1);

/// Midnight on the Monday of [date]'s week.
DateTime weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}
