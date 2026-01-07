import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Wallet Ultra',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        textTheme: GoogleFonts.cairoTextTheme(),
      ),
      home: const AuthCheck(),
    );
  }
}

// --- Auth Check & Lock Screen ---
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLocked = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedPin = prefs.getString('user_pin');
    if (storedPin == null || storedPin.isEmpty) {
      setState(() => _isLocked = false); // لا يوجد رمز، افتح التطبيق
    } else {
      setState(() => _hasPin = true);
      _authenticate(); // حاول استخدام البصمة فوراً
    }
  }

  final LocalAuthentication auth = LocalAuthentication();

  Future<void> _authenticate() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'يرجى استخدام البصمة للدخول',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (authenticated) {
        setState(() => _isLocked = false);
      }
    } catch (e) {
      // إذا فشلت البصمة، سيبقى في شاشة الرمز
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) return const MainScreen();
    return LockScreen(onUnlock: () => setState(() => _isLocked = false));
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String inputPin = "";
  
  void _onNumTap(String num) async {
    setState(() => inputPin += num);
    if (inputPin.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      if (inputPin == prefs.getString('user_pin')) {
        widget.onUnlock();
      } else {
        setState(() => inputPin = "");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز خطأ!'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text('أدخل رمز المرور', style: GoogleFonts.cairo(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => Container(
                margin: const EdgeInsets.all(8),
                width: 15, height: 15,
                decoration: BoxDecoration(shape: BoxShape.circle, color: index < inputPin.length ? Colors.white : Colors.white24),
              )),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20),
                itemCount: 12,
                itemBuilder: (ctx, i) {
                  if (i == 9) return const SizedBox(); // Empty
                  if (i == 11) return IconButton(onPressed: () => setState(() => inputPin = inputPin.isNotEmpty ? inputPin.substring(0, inputPin.length-1) : ""), icon: const Icon(Icons.backspace, color: Colors.white));
                  String num = i == 10 ? "0" : "${i + 1}";
                  return GestureDetector(
                    onTap: () => _onNumTap(num),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                      alignment: Alignment.center,
                      child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
             TextButton.icon(
              onPressed: () => (context.findAncestorStateOfType<_AuthCheckState>())?._authenticate(),
              icon: const Icon(Icons.fingerprint, color: Colors.white),
              label: const Text('استخدم البصمة', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- Main App Logic (Same as before + Export) ---
class TransactionItem {
  String id, title, type, source, category;
  double amount;
  bool isPaid;
  DateTime date;

  TransactionItem({required this.id, required this.title, required this.amount, required this.type, required this.source, required this.category, required this.isPaid, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'type': type, 'source': source, 'category': category, 'isPaid': isPaid, 'date': date.toIso8601String()};
  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(id: json['id'], title: json['title'], amount: json['amount'], type: json['type'], source: json['source'], category: json['category'] ?? 'other', isPaid: json['isPaid'], date: DateTime.parse(json['date']));
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  double pocketBalance = 0.0, walletBalance = 0.0;
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
      if (transString != null) transactions = (json.decode(transString) as List).map((i) => TransactionItem.fromJson(i)).toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('pocketBalance', pocketBalance);
    prefs.setDouble('walletBalance', walletBalance);
    prefs.setString('transactions', json.encode(transactions.map((e) => e.toJson()).toList()));
  }

  void _addTransaction(String title, double amount, String type, String source, String category, bool isPaid) {
    setState(() {
      transactions.insert(0, TransactionItem(id: DateTime.now().toString(), title: title, amount: amount, type: type, source: source, category: category, isPaid: isPaid, date: DateTime.now()));
      if (isPaid) {
        if (source == 'pocket') pocketBalance -= amount; else walletBalance -= amount;
      }
    });
    _saveData();
  }

  void _transferMoney(double amount, bool fromPocketToWallet) {
    setState(() {
      if (fromPocketToWallet) { if (pocketBalance >= amount) { pocketBalance -= amount; walletBalance += amount; } }
      else { if (walletBalance >= amount) { walletBalance -= amount; pocketBalance += amount; } }
    });
    _saveData();
  }

  Future<void> _exportExcel() async {
    List<List<dynamic>> rows = [];
    rows.add(["التاريخ", "العنوان", "المبلغ", "المصدر", "الفئة", "الحالة"]);
    for (var t in transactions) {
      rows.add([DateFormat('yyyy-MM-dd').format(t.date), t.title, t.amount, t.source, t.category, t.isPaid ? "مدفوع" : "غير مدفوع"]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/wallet_report.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'تقرير المحفظة الذكية');
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SettingsSheet(onExport: _exportExcel));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(pocketBalance: pocketBalance, walletBalance: walletBalance, transactions: transactions, onAdd: _addTransaction, onTransfer: _transferMoney, onSettings: () => _openSettings(context)),
      StatsScreen(transactions: transactions),
    ];
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex, onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [NavigationDestination(icon: Icon(Icons.wallet), label: 'محفظتي'), NavigationDestination(icon: Icon(Icons.pie_chart), label: 'إحصائيات')],
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  final VoidCallback onExport;
  const SettingsSheet({super.key, required this.onExport});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final pinCtrl = TextEditingController();
  
  void _savePin() async {
    if(pinCtrl.text.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', pinCtrl.text);
      if(mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل الحماية بنجاح'))); }
    }
  }

  void _removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');
    if(mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الحماية'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          ListTile(leading: const Icon(Icons.file_download), title: const Text('تصدير البيانات (Excel)'), onTap: widget.onExport),
          const Divider(),
          const Text('إعدادات الأمان (PIN + بصمة)'),
          const SizedBox(height: 10),
          TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'تعيين رمز مرور جديد (4 أرقام)', border: OutlineInputBorder())),
          ElevatedButton(onPressed: _savePin, child: const Text('حفظ الرمز وتفعيل الحماية')),
          TextButton(onPressed: _removePin, child: const Text('إلغاء الحماية', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final double pocketBalance, walletBalance;
  final List<TransactionItem> transactions;
  final Function onAdd, onTransfer;
  final VoidCallback onSettings;

  const HomeScreen({super.key, required this.pocketBalance, required this.walletBalance, required this.transactions, required this.onAdd, required this.onTransfer, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddSheet(context), label: const Text('عملية جديدة'), icon: const Icon(Icons.add), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80.0, floating: true, backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(title: Text('Smart Wallet', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)), centerTitle: true),
            actions: [
               IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: onSettings),
               IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.indigo, size: 30), onPressed: () => _showTransferDialog(context))
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [_buildCreditCard('رصيد الجيب', pocketBalance, [const Color(0xFF43A047), const Color(0xFF1B5E20)], Icons.money), const SizedBox(height: 12), _buildCreditCard('رصيد المحفظة', walletBalance, [const Color(0xFF1A237E), const Color(0xFF0D47A1)], Icons.account_balance_wallet)]),
            ),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('أحدث العمليات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)))),
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final item = transactions[index];
                return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: ListTile(leading: CircleAvatar(backgroundColor: item.isPaid ? Colors.green[100] : Colors.red[100], child: Icon(_getIconForCategory(item.category), color: item.isPaid ? Colors.green : Colors.red)), title: Text(item.title), subtitle: Text(DateFormat('yyyy-MM-dd').format(item.date)), trailing: Text('${item.amount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold))));
              }, childCount: transactions.length)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  // Helper Widgets & Methods (Simplified for brevity)
  Widget _buildCreditCard(String title, double balance, List<Color> colors, IconData icon) {
    return Container(width: double.infinity, height: 150, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: Colors.white70, size: 30), const Icon(Icons.wifi, color: Colors.white30)]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70)), Text('$balance EGP', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))])]));
  }
  
  IconData _getIconForCategory(String cat) {
    switch (cat) { case 'food': return Icons.fastfood; case 'transport': return Icons.directions_car; case 'work': return Icons.work; case 'shopping': return Icons.shopping_bag; default: return Icons.category; }
  }

  void _showAddSheet(BuildContext context) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); String cat = 'food'; String src = 'pocket';
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('عملية جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'الوصف')), TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
      Row(children: [Expanded(child: DropdownButtonFormField(value: cat, items: ['food','transport','work','shopping'].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>cat=v!)), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField(value: src, items: ['pocket','wallet'].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>src=v!))]),
      const SizedBox(height: 20), ElevatedButton(onPressed: (){ if(tCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) { onAdd(tCtrl.text, double.parse(aCtrl.text), 'expense', src, cat, true); Navigator.pop(ctx); } }, child: const Text('حفظ')), const SizedBox(height: 20)
    ])));
  }

  void _showTransferDialog(BuildContext context) {
    final c = TextEditingController(); bool p = true;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, st) => AlertDialog(title: const Text('تحويل'), content: Column(mainAxisSize: MainAxisSize.min, children: [SwitchListTile(title: Text(p?'من الجيب للمحفظة':'من المحفظة للجيب'), value: p, onChanged: (v)=>st(()=>p=v)), TextField(controller: c, keyboardType: TextInputType.number)]), actions: [ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { onTransfer(double.parse(c.text), p); Navigator.pop(ctx); } }, child: const Text('تحويل'))])));
  }
}

class StatsScreen extends StatelessWidget {
  final List<TransactionItem> transactions;
  const StatsScreen({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) {
    Map<String, double> data = {}; for (var t in transactions) { if (t.isPaid) data[t.category] = (data[t.category] ?? 0) + t.amount; }
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: data.isEmpty ? const Center(child: Text('لا توجد بيانات')) : Padding(padding: const EdgeInsets.all(16), child: Column(children: [AspectRatio(aspectRatio: 1.3, child: PieChart(PieChartData(sections: data.entries.map((e) => PieChartSectionData(value: e.value, title: '${e.value.toInt()}', color: Colors.blue, radius: 50)).toList()))), Expanded(child: ListView(children: data.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value}'))).toList()))])),
    );
  }
}
