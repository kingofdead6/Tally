double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

enum TxType { income, expense }

TxType txTypeFrom(String? v) => v == 'income' ? TxType.income : TxType.expense;
String txTypeName(TxType t) => t == TxType.income ? 'income' : 'expense';

class AppUser {
  final String id;
  final String name;
  final String email;
  final double monthlyBudget;

  AppUser({required this.id, required this.name, required this.email, required this.monthlyBudget});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        monthlyBudget: _num(j['monthlyBudget']),
      );

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class TxCategory {
  final String id;
  final String name;
  final TxType type;
  final String icon;
  final String color;

  TxCategory({required this.id, required this.name, required this.type, required this.icon, required this.color});

  factory TxCategory.fromJson(Map<String, dynamic> j) => TxCategory(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Unknown',
        type: txTypeFrom(j['type'] as String?),
        icon: j['icon'] as String? ?? 'other',
        color: j['color'] as String? ?? '#64748B',
      );
}

class Wallet {
  final String id;
  final String name;
  final String icon;
  final String color;
  final double initialBalance;
  final double balance;

  Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.initialBalance,
    required this.balance,
  });

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Wallet',
        icon: j['icon'] as String? ?? 'cash',
        color: j['color'] as String? ?? '#0B5D43',
        initialBalance: _num(j['initialBalance']),
        balance: _num(j['balance']),
      );
}

/// Small embedded reference (category / wallet) as returned on a transaction.
class Ref {
  final String id;
  final String name;
  final String icon;
  final String color;
  Ref({required this.id, required this.name, required this.icon, required this.color});

  factory Ref.fromJson(Map<String, dynamic>? j, {String fallbackIcon = 'other'}) => Ref(
        id: (j?['id'] ?? '') as String,
        name: (j?['name'] ?? 'Deleted') as String,
        icon: (j?['icon'] ?? fallbackIcon) as String,
        color: (j?['color'] ?? '#64748B') as String,
      );
}

class Txn {
  final String id;
  final TxType type;
  final double amount;
  final String note;
  final DateTime date;
  final Ref category;
  final Ref wallet;

  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.category,
    required this.wallet,
  });

  bool get isIncome => type == TxType.income;
  double get signed => isIncome ? amount : -amount;

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: txTypeFrom(j['type'] as String?),
        amount: _num(j['amount']),
        note: j['note'] as String? ?? '',
        date: DateTime.parse(j['date'] as String).toLocal(),
        category: Ref.fromJson(j['category'] as Map<String, dynamic>?),
        wallet: Ref.fromJson(j['wallet'] as Map<String, dynamic>?, fallbackIcon: 'cash'),
      );
}

class TxnPage {
  final List<Txn> items;
  final int total;
  final bool hasMore;
  TxnPage(this.items, this.total, this.hasMore);
}

class MoneySummary {
  final double income;
  final double expense;
  final double net;
  final double balance;
  final int count;
  final double monthlyBudget;
  final double spentThisMonth;

  const MoneySummary({
    this.income = 0,
    this.expense = 0,
    this.net = 0,
    this.balance = 0,
    this.count = 0,
    this.monthlyBudget = 0,
    this.spentThisMonth = 0,
  });

  factory MoneySummary.fromJson(Map<String, dynamic> j) => MoneySummary(
        income: _num(j['income']),
        expense: _num(j['expense']),
        net: _num(j['net']),
        balance: _num(j['balance']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        monthlyBudget: _num(j['monthlyBudget']),
        spentThisMonth: _num(j['spentThisMonth']),
      );
}

class CategoryShare {
  final String id;
  final String name;
  final String icon;
  final String color;
  final double total;
  final int count;
  final double percent;

  CategoryShare({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
    required this.count,
    required this.percent,
  });

  factory CategoryShare.fromJson(Map<String, dynamic> j) => CategoryShare(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? 'other',
        color: j['color'] as String? ?? '#64748B',
        total: _num(j['total']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        percent: _num(j['percent']),
      );
}

class MonthPoint {
  final int year;
  final int month;
  final double income;
  final double expense;
  MonthPoint(this.year, this.month, this.income, this.expense);

  factory MonthPoint.fromJson(Map<String, dynamic> j) => MonthPoint(
        (j['year'] as num).toInt(),
        (j['month'] as num).toInt(),
        _num(j['income']),
        _num(j['expense']),
      );

  DateTime get date => DateTime(year, month);
}
