import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Wallet Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // كحلي ملكي
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.cairoTextTheme(), // خط عربي جميل
      ),
      home: const MainScreen(),
    );
  }
}

// --- Data Model ---
class TransactionItem {
  String id;
  String title;
  double amount;
  String type; // 'expense', 'income', 'bill'
  String source; // 'pocket', 'wallet'
  String category; // 'food', 'transport', 'work', 'other'
  bool isPaid;
  DateTime date;

  TransactionItem({
    required this.id, required this.title, required this.amount,
    required this.type, required this.source, required this.category,
    required this.isPaid, required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'amount': amount, 'type': type,
    'source': source, 'category': category, 'isPaid': isPaid,
    'date': date.toIso8601String(),
  };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
    id: json['id'], title: json['title'], amount: json['amount'],
    type: json['type'], source: json['source'], category: json['category'] ?? 'other',
    isPaid: json['isPaid'], date: DateTime.parse(json['date']),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  // Data
  double pocketBalance = 0.0;
  double walletBalance = 0.0;
  List<TransactionItem> transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pocketBalance = prefs.getDouble('pocketBalance') ?? 0.0;
      walletBalance = prefs.getDouble('walletBalance') ?? 0.0;
      final String? transString = prefs.getString('transactions');
      if (transString != null) {
        transactions = (json.decode(transString) as List)
            .map((i) => TransactionItem.fromJson(i)).toList();
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('pocketBalance', pocketBalance);
    prefs.setDouble('walletBalance', walletBalance);
    prefs.setString('transactions', json.encode(transactions.map((e) => e.toJson()).toList()));
  }

  // Logic Handlers
  void _addTransaction(String title, double amount, String type, String source, String category, bool isPaid) {
    setState(() {
      transactions.insert(0, TransactionItem(
        id: DateTime.now().toString(), title: title, amount: amount,
        type: type, source: source, category: category, isPaid: isPaid, date: DateTime.now(),
      ));
      if (isPaid) {
        if (source == 'pocket') pocketBalance -= amount;
        else walletBalance -= amount;
      }
    });
    _saveData();
  }

  void _transferMoney(double amount, bool fromPocketToWallet) {
    setState(() {
      if (fromPocketToWallet) {
        if (pocketBalance >= amount) { pocketBalance -= amount; walletBalance += amount; }
      } else {
        if (walletBalance >= amount) { walletBalance -= amount; pocketBalance += amount; }
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        pocketBalance: pocketBalance, walletBalance: walletBalance,
        transactions: transactions,
        onAdd: _addTransaction, onTransfer: _transferMoney,
      ),
      StatsScreen(transactions: transactions),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wallet), label: 'محفظتي'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'إحصائيات'),
        ],
      ),
    );
  }
}

// --- Home Screen (Beautiful Cards) ---
class HomeScreen extends StatelessWidget {
  final double pocketBalance;
  final double walletBalance;
  final List<TransactionItem> transactions;
  final Function onAdd;
  final Function onTransfer;

  const HomeScreen({super.key, required this.pocketBalance, required this.walletBalance, required this.transactions, required this.onAdd, required this.onTransfer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        label: const Text('عملية جديدة'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80.0,
            floating: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Smart Wallet', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
              centerTitle: true,
            ),
            actions: [
               IconButton(
                // تم التصحيح هنا: استخدام swap_horiz بدلاً من swap_horiz_circle
                icon: const Icon(Icons.swap_horiz, color: Colors.indigo, size: 30),
                onPressed: () => _showTransferDialog(context),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCreditCard('رصيد الجيب (الكاش)', pocketBalance, [const Color(0xFF43A047), const Color(0xFF1B5E20)], Icons.money),
                  const SizedBox(height: 12),
                  _buildCreditCard('رصيد المحفظة (البنك)', walletBalance, [const Color(0xFF1A237E), const Color(0xFF0D47A1)], Icons.account_balance_wallet),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('أحدث العمليات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = transactions[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))]),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Icon(_getIconForCategory(item.category), color: item.isPaid ? Colors.green : Colors.red),
                    ),
                    title: Text(item.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(item.date)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${item.amount.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(item.source == 'pocket' ? 'من الجيب' : 'من المحفظة', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                );
              },
              childCount: transactions.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String title, double balance, List<Color> colors, IconData icon) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 30),
              const Icon(Icons.wifi, color: Colors.white30),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
              Text('${balance.toStringAsFixed(1)} EGP', style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String cat) {
    switch (cat) {
      case 'food': return Icons.fastfood;
      case 'transport': return Icons.directions_car;
      case 'work': return Icons.work;
      case 'shopping': return Icons.shopping_bag;
      default: return Icons.category;
    }
  }

  void _showAddSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'food';
    String source = 'pocket';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('عملية جديدة', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.edit), border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: DropdownButtonFormField(value: category, items: const [
                  DropdownMenuItem(value: 'food', child: Text('طعام')),
                  DropdownMenuItem(value: 'transport', child: Text('مواصلات')),
                  DropdownMenuItem(value: 'work', child: Text('عمل')),
                  DropdownMenuItem(value: 'shopping', child: Text('تسوق')),
                ], onChanged: (v) => category = v!, decoration: const InputDecoration(border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField(value: source, items: const [
                  DropdownMenuItem(value: 'pocket', child: Text('من الجيب')),
                  DropdownMenuItem(value: 'wallet', child: Text('من المحفظة')),
                ], onChanged: (v) => source = v!, decoration: const InputDecoration(border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                  onAdd(titleCtrl.text, double.parse(amountCtrl.text), 'expense', source, category, true);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ العملية'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    bool fromPocket = true;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('تحويل رصيد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(title: Text(fromPocket ? 'من الجيب -> المحفظة' : 'من المحفظة -> الجيب'), value: fromPocket, onChanged: (v) => setSt(() => fromPocket = v)),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
        ],
      ),
      actions: [ElevatedButton(onPressed: (){ 
        if(amountCtrl.text.isNotEmpty) { onTransfer(double.parse(amountCtrl.text), fromPocket); Navigator.pop(ctx); }
      }, child: const Text('تحويل'))],
    )));
  }
}

// --- Stats Screen (Smart Charts) ---
class StatsScreen extends StatelessWidget {
  final List<TransactionItem> transactions;
  const StatsScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    Map<String, double> data = {};
    for (var t in transactions) {
      if (t.isPaid) {
        data[t.category] = (data[t.category] ?? 0) + t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تحليل المصاريف'), centerTitle: true),
      body: data.isEmpty 
      ? const Center(child: Text('لا توجد بيانات كافية للتحليل'))
      : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sections: data.entries.map((e) => PieChartSectionData(
                    value: e.value,
                    title: '${e.value.toInt()}',
                    color: _getColor(e.key),
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  )).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: data.entries.map((e) => ListTile(
                  leading: CircleAvatar(backgroundColor: _getColor(e.key), radius: 10),
                  title: Text(_getName(e.key)),
                  trailing: Text('${e.value} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getColor(String key) {
    switch(key) {
      case 'food': return Colors.orange;
      case 'transport': return Colors.blue;
      case 'work': return Colors.red;
      default: return Colors.green;
    }
  }
  String _getName(String key) {
    switch(key) {
      case 'food': return 'طعام ومشروبات';
      case 'transport': return 'مواصلات ونقل';
      case 'work': return 'مصاريف عمل';
      default: return 'أخرى';
    }
  }
}
