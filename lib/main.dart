import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

// الألوان الرئيسية للتصميم الجديد
class AppColors {
  static const Color primary = Color(0xFF00E676); // أخضر نيون
  static const Color secondary = Color(0xFF2979FF); // أزرق نيون
  static const Color background = Color(0xFF121212); // أسود داكن
  static const Color cardBg = Color(0xFF1E1E1E); // خلفية البطاقات
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color danger = Color(0xFFFF1744); // أحمر نيون
  static Color glass = Colors.white.withOpacity(0.05); // تأثير الزجاج
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Manager Pro',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.cardBg,
          background: AppColors.background,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        cardTheme: CardTheme(
          color: AppColors.cardBg,
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.cardBg.withOpacity(0.8),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.glass,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.glass)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary)),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIconColor: AppColors.primary,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- Data Models (لم تتغير) ---
class Transaction {
  String id, title, type; double amount; String source, category; DateTime date;
  Transaction({required this.id, required this.title, required this.amount, required this.type, required this.source, required this.category, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'type': type, 'source': source, 'category': category, 'date': date.toIso8601String()};
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(id: json['id'], title: json['title'], amount: json['amount'], type: json['type'], source: json['source'], category: json['category'] ?? 'personal', date: DateTime.parse(json['date']));
}

class Debt {
  String id, creditorName; double totalAmount, paidAmount; DateTime date;
  Debt({required this.id, required this.creditorName, required this.totalAmount, required this.paidAmount, required this.date});
  double get remaining => totalAmount - paidAmount;
  double get progress => totalAmount == 0 ? 0 : paidAmount / totalAmount;
  Map<String, dynamic> toJson() => {'id': id, 'creditorName': creditorName, 'totalAmount': totalAmount, 'paidAmount': paidAmount, 'date': date.toIso8601String()};
  factory Debt.fromJson(Map<String, dynamic> json) => Debt(id: json['id'], creditorName: json['creditorName'], totalAmount: json['totalAmount'], paidAmount: json['paidAmount'], date: DateTime.parse(json['date']));
}

// --- Main Screen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  double shopBalance = 0.0, pocketBalance = 0.0, walletBalance = 0.0;
  List<Transaction> transactions = [];
  List<Debt> debts = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      shopBalance = prefs.getDouble('shopBalance') ?? 0.0;
      pocketBalance = prefs.getDouble('pocketBalance') ?? 0.0;
      walletBalance = prefs.getDouble('walletBalance') ?? 0.0;
      final tList = prefs.getString('transactions'); if (tList != null) transactions = (json.decode(tList) as List).map((i) => Transaction.fromJson(i)).toList();
      final dList = prefs.getString('debts'); if (dList != null) debts = (json.decode(dList) as List).map((i) => Debt.fromJson(i)).toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('shopBalance', shopBalance); prefs.setDouble('pocketBalance', pocketBalance); prefs.setDouble('walletBalance', walletBalance);
    prefs.setString('transactions', json.encode(transactions.map((e) => e.toJson()).toList()));
    prefs.setString('debts', json.encode(debts.map((e) => e.toJson()).toList()));
  }

  void _addTransaction(String title, double amount, String type, String source, String category) {
    setState(() {
      transactions.insert(0, Transaction(id: DateTime.now().toString(), title: title, amount: amount, type: type, source: source, category: category, date: DateTime.now()));
      if (type == 'income') { if (source == 'shop') shopBalance += amount; else if (source == 'pocket') pocketBalance += amount; else walletBalance += amount; }
      else { if (source == 'shop') shopBalance -= amount; else if (source == 'pocket') pocketBalance -= amount; else walletBalance -= amount; }
    });
    _saveData();
  }

  void _collectDailyWage() {
    if (shopBalance >= 250) {
      setState(() {
        shopBalance -= 250; pocketBalance += 250;
        transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'استلام يومية', amount: 250, type: 'transfer', source: 'shop_to_pocket', category: 'personal', date: DateTime.now()));
      });
      _saveData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام 250 جنيه ✅'), backgroundColor: AppColors.primary));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيد المحل لا يكفي!'), backgroundColor: AppColors.danger));
    }
  }

  void _deleteTransaction(String id) {
    final t = transactions.firstWhere((e) => e.id == id);
    setState(() {
      if (t.type == 'transfer') { shopBalance += t.amount; pocketBalance -= t.amount; }
      else if (t.type == 'income') { if (t.source == 'shop') shopBalance -= t.amount; else if (t.source == 'pocket') pocketBalance -= t.amount; else walletBalance -= t.amount; }
      else { if (t.source == 'shop') shopBalance += t.amount; else if (t.source == 'pocket') pocketBalance += t.amount; else walletBalance += t.amount; }
      transactions.removeWhere((e) => e.id == id);
    });
    _saveData();
  }

  void _updateBalances(double s, double p, double w) { setState(() { shopBalance = s; pocketBalance = p; walletBalance = w; }); _saveData(); }

  void _addDebt(String name, double total) { setState(() { debts.add(Debt(id: DateTime.now().toString(), creditorName: name, totalAmount: total, paidAmount: 0, date: DateTime.now())); }); _saveData(); }

  void _payDebt(String id, double amount, String source) {
    final index = debts.indexWhere((d) => d.id == id);
    if (index != -1) {
      setState(() {
        debts[index].paidAmount += amount;
        if (source == 'shop') shopBalance -= amount; else if (source == 'pocket') pocketBalance -= amount; else walletBalance -= amount;
        transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'سداد دين: ${debts[index].creditorName}', amount: amount, type: 'expense', source: source, category: 'personal', date: DateTime.now()));
      });
      _saveData();
    }
  }

  void _editDebt(String id, String name, double total) {
    final index = debts.indexWhere((d) => d.id == id);
    if(index != -1) { setState(() { debts[index].creditorName = name; debts[index].totalAmount = total; }); _saveData(); }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(shop: shopBalance, pocket: pocketBalance, wallet: walletBalance, transactions: transactions, onAdd: _addTransaction, onDelete: _deleteTransaction, onWage: _collectDailyWage),
      DebtsTab(debts: debts, onAddDebt: _addDebt, onPay: _payDebt, onEdit: _editDebt),
      ReportsTab(transactions: transactions),
      ControlPanelTab(shop: shopBalance, pocket: pocketBalance, wallet: walletBalance, onUpdate: _updateBalances),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Smart Manager')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)]),
        ),
        child: tabs[_selectedIndex]
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: android.graphics.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.handshake_outlined), activeIcon: Icon(Icons.handshake), label: 'الديون'),
              BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), activeIcon: Icon(Icons.pie_chart), label: 'التقارير'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Custom Widgets for New Design ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool isGlow;
  const GlassCard({super.key, required this.child, this.padding, this.height, this.isGlow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: isGlow ? [
          BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 10)),
        ] : [],
      ),
      child: child,
    );
  }
}

class NeonButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color color;
  const NeonButton({super.key, required this.onPressed, required this.label, required this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: -2, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black),
        label: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      ),
    );
  }
}

// --- TABS ---

class DashboardTab extends StatelessWidget {
  final double shop, pocket, wallet;
  final List<Transaction> transactions;
  final Function(String, double, String, String, String) onAdd;
  final Function(String) onDelete;
  final VoidCallback onWage;

  const DashboardTab({super.key, required this.shop, required this.pocket, required this.wallet, required this.transactions, required this.onAdd, required this.onDelete, required this.onWage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        label: const Text('عملية جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_circle_outline),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الأرصدة
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildBalanceCard('خزينة المحل', shop, AppColors.primary, Icons.store),
                  const SizedBox(width: 15),
                  _buildBalanceCard('في جيبي', pocket, AppColors.secondary, Icons.person),
                  const SizedBox(width: 15),
                  _buildBalanceCard('البنك/المحفظة', wallet, Colors.purpleAccent, Icons.account_balance),
                ],
              ),
            ),
            const SizedBox(height: 25),
            // زر اليومية
            NeonButton(onPressed: onWage, label: 'استلام اليومية (250 ج)', icon: Icons.monetization_on_outlined),
            const SizedBox(height: 25),
            const Text('أحدث العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 15),
            // قائمة العمليات
            ...transactions.take(10).map((t) => _buildTransactionItem(t)).toList(),
            const SizedBox(height: 80), // مساحة للزر العائم وشريط التنقل
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, IconData icon) {
    return GlassCard(
      height: 180,
      padding: const EdgeInsets.all(20),
      isGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 30),
            Icon(Icons.more_vert, color: AppColors.textSecondary),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 5),
            Text('${amount.toStringAsFixed(1)}', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
            Text('ج.م', style: TextStyle(color: color, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final isIncome = t.type == 'income' || t.type == 'transfer';
    final color = isIncome ? AppColors.primary : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(t.type == 'transfer' ? Icons.swap_horiz : (isIncome ? Icons.arrow_downward : Icons.arrow_upward), color: color),
        ),
        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${DateFormat('dd/MM/yyyy').format(t.date)} • ${t.source.toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Text('${t.amount.toStringAsFixed(1)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        onLongPress: () => onDelete(t.id),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); String type = 'expense'; String cat = 'business';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 25, left: 20, right: 20),
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('عملية جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 25),
          Row(children: [
            Expanded(child: _buildOptionBtn('مصروف', type=='expense', AppColors.danger, ()=>setSt(()=>type='expense'))),
            const SizedBox(width: 15),
            Expanded(child: _buildOptionBtn('دخل/مبيعات', type=='income', AppColors.primary, ()=>setSt(()=>type='income'))),
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _buildOptionBtn('للمحل', cat=='business', Colors.orange, ()=>setSt(()=>cat='business'))),
            const SizedBox(width: 15),
            Expanded(child: _buildOptionBtn('شخصي', cat=='personal', AppColors.secondary, ()=>setSt(()=>cat='personal'))),
          ]),
          const SizedBox(height: 25),
          TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.description_outlined))),
          const SizedBox(height: 15),
          TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.attach_money))),
          const SizedBox(height: 30),
          NeonButton(onPressed: (){ 
            if(tCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
              String source = cat == 'business' ? 'shop' : 'pocket';
              onAdd(tCtrl.text, double.parse(aCtrl.text), type, source, cat); Navigator.pop(ctx);
            }
          }, label: 'حفظ العملية', icon: Icons.check_circle_outline),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  Widget _buildOptionBtn(String label, bool isSelected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : AppColors.textSecondary, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class DebtsTab extends StatelessWidget {
  final List<Debt> debts;
  final Function(String, double) onAddDebt;
  final Function(String, double, String) onPay;
  final Function(String, String, double) onEdit;

  const DebtsTab({super.key, required this.debts, required this.onAddDebt, required this.onPay, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebtDialog(context),
        label: const Text('دين جديد (عليا)', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        backgroundColor: AppColors.danger,
      ),
      body: debts.isEmpty ? const Center(child: Text('لا توجد ديون، الحمد لله!', style: TextStyle(color: AppColors.textSecondary)))
      : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: debts.length,
        itemBuilder: (ctx, i) => _buildDebtCard(context, debts[i]),
      ),
    );
  }

  Widget _buildDebtCard(BuildContext context, Debt d) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(d.creditorName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.secondary), onPressed: () => _showEditDialog(context, d)),
        ]),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: d.progress, backgroundColor: AppColors.glass, color: AppColors.primary, minHeight: 10),
        ),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _debtInfo('الإجمالي', d.totalAmount, AppColors.textSecondary),
          _debtInfo('مدفوع', d.paidAmount, AppColors.primary),
          _debtInfo('متبقي', d.remaining, AppColors.danger),
        ]),
        const SizedBox(height: 20),
        if (d.remaining > 0)
          NeonButton(onPressed: () => _showPayDialog(context, d), label: 'سداد دفعة', icon: Icons.payment_outlined, color: AppColors.secondary)
        else
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Center(child: Text('تم السداد بالكامل 🎉', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _debtInfo(String label, double value, Color color) {
    return Column(children: [Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)), const SizedBox(height: 5), Text(value.toStringAsFixed(0), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))]);
  }

  void _showAddDebtDialog(BuildContext context) {
    final nCtrl = TextEditingController(); final aCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تسجيل دين جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'اسم الدائن', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 15),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الكلي', prefixIcon: Icon(Icons.attach_money))),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: (){ if(nCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty){ onAddDebt(nCtrl.text, double.parse(aCtrl.text)); Navigator.pop(ctx); }}, child: const Text('حفظ'))],
    ));
  }

  void _showPayDialog(BuildContext context, Debt d) {
    final aCtrl = TextEditingController(); String src = 'shop';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: Text('سداد لـ ${d.creditorName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ الدفعة', prefixIcon: Icon(Icons.payments_outlined))),
        const SizedBox(height: 15),
        DropdownButtonFormField(value: src, dropdownColor: AppColors.cardBg, items: const [DropdownMenuItem(value: 'shop', child: Text('من المحل')), DropdownMenuItem(value: 'pocket', child: Text('من جيبي')), DropdownMenuItem(value: 'wallet', child: Text('من البنك'))], onChanged: (v)=>setSt(()=>src=v!), decoration: const InputDecoration(labelText: 'مصدر السداد', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: (){ if(aCtrl.text.isNotEmpty){ onPay(d.id, double.parse(aCtrl.text), src); Navigator.pop(ctx); }}, child: const Text('تأكيد السداد'))],
    )));
  }

  void _showEditDialog(BuildContext context, Debt d) {
    final nCtrl = TextEditingController(text: d.creditorName); final aCtrl = TextEditingController(text: d.totalAmount.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تعديل الدين'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.edit_outlined))),
        const SizedBox(height: 15),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الإجمالي', prefixIcon: Icon(Icons.attach_money))),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: (){ onEdit(d.id, nCtrl.text, double.parse(aCtrl.text)); Navigator.pop(ctx); }, child: const Text('تحديث'))],
    ));
  }
}

class ReportsTab extends StatelessWidget {
  final List<Transaction> transactions;
  const ReportsTab({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    Map<String, double> data = {};
    for (var t in transactions) { if (t.type == 'expense') data[t.category] = (data[t.category] ?? 0) + t.amount; }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: data.isEmpty ? const Center(child: Text('لا توجد بيانات مصاريف للتحليل', style: TextStyle(color: AppColors.textSecondary)))
      : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          const Text('تحليل المصاريف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 40),
          Expanded(
            flex: 2,
            child: PieChart(PieChartData(
              sectionsSpace: 5,
              centerSpaceRadius: 50,
              sections: data.entries.map((e) {
                final color = e.key == 'business' ? Colors.orangeAccent : AppColors.secondary;
                return PieChartSectionData(
                  value: e.value,
                  title: '${e.value.toInt()}\n${e.key.toUpperCase()}',
                  color: color,
                  radius: 70,
                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
                  badgeWidget: _buildBadge(e.key == 'business' ? Icons.store : Icons.person, color),
                  badgePositionPercentageOffset: 1.3,
                );
              }).toList(),
            )),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(children: data.entries.map((e) => ListTile(
              leading: Icon(Icons.circle, color: e.key == 'business' ? Colors.orangeAccent : AppColors.secondary),
              title: Text(e.key == 'business' ? 'مصاريف محل' : 'مصاريف شخصية'),
              trailing: Text('${e.value.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
            )).toList()),
          )
        ]),
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]), child: Icon(icon, color: Colors.black, size: 20));
  }
}

class ControlPanelTab extends StatelessWidget {
  final double shop, pocket, wallet;
  final Function(double, double, double) onUpdate;
  ControlPanelTab({super.key, required this.shop, required this.pocket, required this.wallet, required this.onUpdate});
  final sCtrl = TextEditingController(); final pCtrl = TextEditingController(); final wCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    sCtrl.text = shop.toString(); pCtrl.text = pocket.toString(); wCtrl.text = wallet.toString();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          GlassCard(
            child: Column(children: [
              const Text('جرد الأرصدة اليدوي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 10),
              const Text('استخدم هذا القسم لتصحيح الأرصدة إذا اختلفت عن الواقع.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(controller: sCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'فعلي المحل', prefixIcon: Icon(Icons.store_outlined))),
              const SizedBox(height: 15),
              TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'فعلي الجيب', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 15),
              TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'فعلي البنك', prefixIcon: Icon(Icons.account_balance_outlined))),
              const SizedBox(height: 30),
              NeonButton(onPressed: ()=>onUpdate(double.parse(sCtrl.text), double.parse(pCtrl.text), double.parse(wCtrl.text)), label: 'حفظ الجرد وتحديث التطبيق', icon: Icons.save_as_outlined, color: AppColors.secondary),
            ]),
          ),
        ]),
      ),
    );
  }
}
