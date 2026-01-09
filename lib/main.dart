import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مدير الأموال الشامل',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // أخضر مالي
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const MainScreen(),
    );
  }
}

// --- Data Models ---
class Transaction {
  String id, title, type; // type: expense, rent, income
  double amount;
  String source; // pocket, wallet
  DateTime date;

  Transaction({required this.id, required this.title, required this.amount, required this.type, required this.source, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'type': type, 'source': source, 'date': date.toIso8601String()};
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(id: json['id'], title: json['title'], amount: json['amount'], type: json['type'], source: json['source'], date: DateTime.parse(json['date']));
}

class Debt {
  String id, creditorName;
  double totalAmount;
  double paidAmount;
  DateTime date;

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
  
  // Arcida (Balances)
  double pocketBalance = 0.0;
  double walletBalance = 0.0;
  
  List<Transaction> transactions = [];
  List<Debt> debts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Logic & Storage ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pocketBalance = prefs.getDouble('pocketBalance') ?? 0.0;
      walletBalance = prefs.getDouble('walletBalance') ?? 0.0;
      
      final tList = prefs.getString('transactions');
      if (tList != null) transactions = (json.decode(tList) as List).map((i) => Transaction.fromJson(i)).toList();
      
      final dList = prefs.getString('debts');
      if (dList != null) debts = (json.decode(dList) as List).map((i) => Debt.fromJson(i)).toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('pocketBalance', pocketBalance);
    prefs.setDouble('walletBalance', walletBalance);
    prefs.setString('transactions', json.encode(transactions.map((e) => e.toJson()).toList()));
    prefs.setString('debts', json.encode(debts.map((e) => e.toJson()).toList()));
  }

  // --- Actions ---
  void _updateBalanceManually(double newPocket, double newWallet) {
    setState(() {
      pocketBalance = newPocket;
      walletBalance = newWallet;
    });
    _saveData();
  }

  void _addTransaction(String title, double amount, String type, String source) {
    setState(() {
      transactions.insert(0, Transaction(id: DateTime.now().toString(), title: title, amount: amount, type: type, source: source, date: DateTime.now()));
      if (type == 'income') {
        if (source == 'pocket') pocketBalance += amount; else walletBalance += amount;
      } else {
        if (source == 'pocket') pocketBalance -= amount; else walletBalance -= amount;
      }
    });
    _saveData();
  }

  void _deleteTransaction(String id) {
    final t = transactions.firstWhere((e) => e.id == id);
    setState(() {
      // Reverse balance effect
      if (t.type == 'income') {
        if (t.source == 'pocket') pocketBalance -= t.amount; else walletBalance -= t.amount;
      } else {
        if (t.source == 'pocket') pocketBalance += t.amount; else walletBalance += t.amount;
      }
      transactions.removeWhere((e) => e.id == id);
    });
    _saveData();
  }

  // --- Debt Logic ---
  void _addDebt(String name, double total) {
    setState(() {
      debts.add(Debt(id: DateTime.now().toString(), creditorName: name, totalAmount: total, paidAmount: 0, date: DateTime.now()));
    });
    _saveData();
  }

  void _payDebtInstallment(String debtId, double amount, String source) {
    final index = debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      setState(() {
        debts[index].paidAmount += amount;
        // Deduct from balance
        if (source == 'pocket') pocketBalance -= amount; else walletBalance -= amount;
        
        // Record as transaction too for history
        transactions.insert(0, Transaction(
          id: DateTime.now().toString(), 
          title: 'سداد دين: ${debts[index].creditorName}', 
          amount: amount, 
          type: 'expense', 
          source: source, 
          date: DateTime.now()
        ));
      });
      _saveData();
    }
  }

  void _editDebt(String id, String newName, double newTotal) {
    final index = debts.indexWhere((d) => d.id == id);
    if(index != -1) {
      setState(() {
        debts[index].creditorName = newName;
        debts[index].totalAmount = newTotal;
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(pocket: pocketBalance, wallet: walletBalance, transactions: transactions, onAdd: _addTransaction, onDelete: _deleteTransaction),
      DebtsTab(debts: debts, onAddDebt: _addDebt, onPay: _payDebtInstallment, onEdit: _editDebt),
      RentsTab(transactions: transactions, onAdd: _addTransaction),
      ControlPanelTab(pocket: pocketBalance, wallet: walletBalance, onUpdate: _updateBalanceManually),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدير الأموال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        centerTitle: true,
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'الديون'),
          NavigationDestination(icon: Icon(Icons.home_work), label: 'إيجارات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'تحكم'),
        ],
      ),
    );
  }
}

// ================= TABS =================

// --- 1. Dashboard Tab (Wallet & Pocket) ---
class DashboardTab extends StatelessWidget {
  final double pocket, wallet;
  final List<Transaction> transactions;
  final Function(String, double, String, String) onAdd;
  final Function(String) onDelete;

  const DashboardTab({super.key, required this.pocket, required this.wallet, required this.transactions, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        label: const Text('مصروف/دخل'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _balanceCard('في جيبي', pocket, Colors.orange),
                const SizedBox(width: 10),
                _balanceCard('في المحفظة', wallet, Colors.blue),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: transactions.isEmpty 
            ? const Center(child: Text('لا توجد عمليات حديثة'))
            : ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (ctx, i) {
                  final t = transactions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.type == 'income' ? Colors.green[100] : Colors.red[100],
                      child: Icon(t.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, color: t.type == 'income' ? Colors.green : Colors.red),
                    ),
                    title: Text(t.title),
                    subtitle: Text('${DateFormat('yyyy-MM-dd').format(t.date)} • ${t.source == 'pocket' ? 'جيب' : 'محفظة'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${t.amount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 20), onPressed: () => onDelete(t.id)),
                      ],
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.5))),
        child: Column(children: [Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text('$amount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); String type = 'expense'; String src = 'pocket';
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('تسجيل عملية جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
        Row(children: [
          Expanded(child: RadioListTile(title: const Text('مصروف'), value: 'expense', groupValue: type, onChanged: (v)=>setSt(()=>type=v!))),
          Expanded(child: RadioListTile(title: const Text('دخل'), value: 'income', groupValue: type, onChanged: (v)=>setSt(()=>type=v!))),
        ]),
        DropdownButtonFormField(value: src, items: const [DropdownMenuItem(value: 'pocket', child: Text('من جيبي')), DropdownMenuItem(value: 'wallet', child: Text('من المحفظة'))], onChanged: (v)=>src=v!),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: (){ if(tCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) { onAdd(tCtrl.text, double.parse(aCtrl.text), type, src); Navigator.pop(ctx); }}, child: const Text('حفظ')),
        const SizedBox(height: 20),
      ]),
    )));
  }
}

// --- 2. Debts Tab (Full Control) ---
class DebtsTab extends StatelessWidget {
  final List<Debt> debts;
  final Function(String, double) onAddDebt;
  final Function(String, double, String) onPay;
  final Function(String, String, double) onEdit;

  const DebtsTab({super.key, required this.debts, required this.onAddDebt, required this.onPay, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebtDialog(context),
        label: const Text('دين جديد (عليا)'),
        icon: const Icon(Icons.person_add),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: debts.isEmpty 
      ? const Center(child: Text('لا توجد ديون مسجلة، الحمد لله')) 
      : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: debts.length,
        itemBuilder: (ctx, i) {
          final d = debts[i];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(d.creditorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditDialog(context, d)),
                  ]),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(value: d.progress, backgroundColor: Colors.grey[300], color: Colors.green, minHeight: 8),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('الإجمالي: ${d.totalAmount}', style: const TextStyle(color: Colors.red)),
                    Text('تم سداد: ${d.paidAmount}', style: const TextStyle(color: Colors.green)),
                    Text('متبقي: ${d.remaining}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  d.remaining > 0 
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('سداد دفعة'),
                        onPressed: () => _showPayDialog(context, d),
                      ),
                    )
                  : const Center(child: Text('تم السداد بالكامل ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddDebtDialog(BuildContext context) {
    final nCtrl = TextEditingController(); final aCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تسجيل دين جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'اسم الشخص (الدائن)')),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الكلي')),
      ]),
      actions: [ElevatedButton(onPressed: (){ if(nCtrl.text.isNotEmpty){ onAddDebt(nCtrl.text, double.parse(aCtrl.text)); Navigator.pop(ctx); }}, child: const Text('حفظ'))],
    ));
  }

  void _showPayDialog(BuildContext context, Debt d) {
    final aCtrl = TextEditingController(); String src = 'pocket';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: Text('سداد لـ ${d.creditorName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ الدفعة')),
        DropdownButtonFormField(value: src, items: const [DropdownMenuItem(value: 'pocket', child: Text('من جيبي')), DropdownMenuItem(value: 'wallet', child: Text('من المحفظة'))], onChanged: (v)=>src=v!),
      ]),
      actions: [ElevatedButton(onPressed: (){ if(aCtrl.text.isNotEmpty){ onPay(d.id, double.parse(aCtrl.text), src); Navigator.pop(ctx); }}, child: const Text('تأكيد السداد'))],
    )));
  }

  void _showEditDialog(BuildContext context, Debt d) {
    final nCtrl = TextEditingController(text: d.creditorName); final aCtrl = TextEditingController(text: d.totalAmount.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تعديل بيانات الدين'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الإجمالي الصحيح')),
      ]),
      actions: [ElevatedButton(onPressed: (){ onEdit(d.id, nCtrl.text, double.parse(aCtrl.text)); Navigator.pop(ctx); }, child: const Text('تحديث'))],
    ));
  }
}

// --- 3. Rents Tab (Recurring Expenses) ---
class RentsTab extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(String, double, String, String) onAdd;

  const RentsTab({super.key, required this.transactions, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final rents = transactions.where((t) => t.type == 'rent').toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRent(context),
        label: const Text('تسجيل إيجار'),
        icon: const Icon(Icons.home_work),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: rents.length,
        itemBuilder: (ctx, i) {
          final t = rents[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.orange),
              title: Text(t.title),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(t.date)),
              trailing: Text('${t.amount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          );
        },
      ),
    );
  }

  void _showAddRent(BuildContext context) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); String src = 'pocket';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('تسجيل دفع إيجار'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'اسم الإيجار (محل، منزل..)')),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
        DropdownButtonFormField(value: src, items: const [DropdownMenuItem(value: 'pocket', child: Text('من جيبي')), DropdownMenuItem(value: 'wallet', child: Text('من المحفظة'))], onChanged: (v)=>src=v!),
      ]),
      actions: [ElevatedButton(onPressed: (){ if(tCtrl.text.isNotEmpty){ onAdd(tCtrl.text, double.parse(aCtrl.text), 'rent', src); Navigator.pop(ctx); }}, child: const Text('تسجيل'))],
    )));
  }
}

// --- 4. Control Panel Tab (Settings) ---
class ControlPanelTab extends StatefulWidget {
  final double pocket, wallet;
  final Function(double, double) onUpdate;
  const ControlPanelTab({super.key, required this.pocket, required this.wallet, required this.onUpdate});

  @override
  State<ControlPanelTab> createState() => _ControlPanelTabState();
}

class _ControlPanelTabState extends State<ControlPanelTab> {
  late TextEditingController pCtrl;
  late TextEditingController wCtrl;

  @override
  void initState() {
    super.initState();
    pCtrl = TextEditingController(text: widget.pocket.toString());
    wCtrl = TextEditingController(text: widget.wallet.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تعديل الأرصدة يدوياً', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('استخدم هذا القسم إذا وجدت اختلافاً بين التطبيق والواقع', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الفلوس اللي في جيبي حالياً', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money))),
          const SizedBox(height: 15),
          TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الفلوس اللي في المحفظة/البنك حالياً', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              onPressed: () => widget.onUpdate(double.parse(pCtrl.text), double.parse(wCtrl.text)),
              icon: const Icon(Icons.save),
              label: const Text('حفظ التعديلات'),
            ),
          ),
          const Spacer(),
          const Divider(),
          const Center(child: Text('Version 4.0 - Smart Manager', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
