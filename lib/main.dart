import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class AppColors {
  static const Color bg = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primary = Color(0xFF00E676); // Green
  static const Color accent = Color(0xFF651FFF);  // Purple
  static const Color error = Color(0xFFFF1744);
  static const Color text = Colors.white;
  static const Color textGrey = Colors.white54;
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainScreen(),
    );
  }
}

// --- Data Models ---
class Transaction {
  String id, title, type, source, category;
  double amount;
  String? imagePath;
  DateTime date;
  Transaction({required this.id, required this.title, required this.amount, required this.type, required this.source, required this.category, this.imagePath, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'type': type, 'source': source, 'category': category, 'imagePath': imagePath, 'date': date.toIso8601String()};
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(id: json['id'], title: json['title'], amount: json['amount'], type: json['type'], source: json['source'], category: json['category'] ?? 'personal', imagePath: json['imagePath'], date: DateTime.parse(json['date']));
}

class Debt {
  String id, creditorName; double totalAmount, paidAmount;
  Debt({required this.id, required this.creditorName, required this.totalAmount, required this.paidAmount});
  Map<String, dynamic> toJson() => {'id': id, 'creditorName': creditorName, 'totalAmount': totalAmount, 'paidAmount': paidAmount};
  factory Debt.fromJson(Map<String, dynamic> json) => Debt(id: json['id'], creditorName: json['creditorName'], totalAmount: json['totalAmount'], paidAmount: json['paidAmount']);
}

// --- Main Screen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  double shop = 0, pocket = 0, wallet = 0;
  List<Transaction> transactions = [];
  List<Debt> debts = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      shop = prefs.getDouble('shop') ?? 0;
      pocket = prefs.getDouble('pocket') ?? 0;
      wallet = prefs.getDouble('wallet') ?? 0;
      final t = prefs.getString('trans'); 
      if (t != null) transactions = (json.decode(t) as List).map((i) => Transaction.fromJson(i)).toList();
      final d = prefs.getString('debts'); 
      if (d != null) debts = (json.decode(d) as List).map((i) => Debt.fromJson(i)).toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('shop', shop); prefs.setDouble('pocket', pocket); prefs.setDouble('wallet', wallet);
    prefs.setString('trans', json.encode(transactions.map((e) => e.toJson()).toList()));
    prefs.setString('debts', json.encode(debts.map((e) => e.toJson()).toList()));
  }

  // --- Core Logic ---
  void _addTransaction(String title, double amt, String type, String src, String cat, String? imgPath) {
    setState(() {
      transactions.insert(0, Transaction(id: DateTime.now().toString(), title: title, amount: amt, type: type, source: src, category: cat, imagePath: imgPath, date: DateTime.now()));
      if (type == 'income') {
        if (src == 'shop') shop += amt; else if (src == 'pocket') pocket += amt; else wallet += amt;
      } else {
        if (src == 'shop') shop -= amt; else if (src == 'pocket') pocket -= amt; else wallet -= amt;
      }
    });
    _save();
  }

  void _collectWage() {
    if (shop >= 250) {
      setState(() {
        shop -= 250; pocket += 250;
        transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'استلام يومية', amount: 250, type: 'transfer', source: 'shop', category: 'personal', date: DateTime.now()));
      });
      _save();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام 250 جنيه ✅'), backgroundColor: AppColors.primary));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيد المحل لا يكفي!'), backgroundColor: AppColors.error));
    }
  }

  void _deleteTransaction(String id) {
    final t = transactions.firstWhere((e) => e.id == id);
    setState(() {
      if (t.type == 'transfer') { shop += t.amount; pocket -= t.amount; }
      else if (t.type == 'income') { if (t.source == 'shop') shop -= t.amount; else if (t.source == 'pocket') pocket -= t.amount; else wallet -= t.amount; }
      else { if (t.source == 'shop') shop += t.amount; else if (t.source == 'pocket') pocket += t.amount; else wallet += t.amount; }
      transactions.removeWhere((e) => e.id == id);
    });
    _save();
  }

  // --- UI Building Blocks ---
  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      _buildDebtsTab(),
      _buildSettingsTab(),
    ];

    return Scaffold(
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'الديون'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  // ================= HOME TAB =================
  Widget _buildHomeTab() {
    double totalWealth = shop + pocket + wallet;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('مرحباً عبد الله 👋', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('${totalWealth.toStringAsFixed(0)} EGP', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                CircleAvatar(backgroundColor: AppColors.surface, child: IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none, color: Colors.white))),
              ],
            ),
            const SizedBox(height: 20),

            // Chart Area (Beautiful Curve)
            Container(
              height: 180,
              padding: const EdgeInsets.only(right: 20, top: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateChartData(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Cards Scroll
            SizedBox(
              height: 170,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCreditCard('خزينة المحل', shop, const Color(0xFFE65100), Icons.store),
                  const SizedBox(width: 15),
                  _buildCreditCard('جيبي (يومية)', pocket, AppColors.accent, Icons.person),
                  const SizedBox(width: 15),
                  _buildCreditCard('البنك/المحفظة', wallet, Colors.teal, Icons.account_balance),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Action Buttons
            const Text('إجراءات سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton('إضافة مصروف', Icons.arrow_upward, AppColors.error, () => _showAddSheet(type: 'expense')),
                _buildActionButton('إضافة دخل', Icons.arrow_downward, AppColors.primary, () => _showAddSheet(type: 'income')),
                _buildActionButton('استلام يومية', Icons.monetization_on, Colors.amber, _collectWage),
              ],
            ),
            const SizedBox(height: 25),

            // Recent Transactions
            const Text('آخر العمليات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
            const SizedBox(height: 10),
            ...transactions.take(5).map((t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.type == 'income' ? AppColors.primary.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                  child: Icon(t.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, color: t.type == 'income' ? AppColors.primary : AppColors.error),
                ),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd/MM - hh:mm a').format(t.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Text('${t.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.type == 'income' ? AppColors.primary : Colors.white)),
                onLongPress: () => _deleteTransaction(t.id),
              ),
            )),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ================= DEBTS TAB =================
  Widget _buildDebtsTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('دفتر الديون'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDebt,
        label: const Text('شخص له مال (عليا)'),
        icon: const Icon(Icons.person_add),
        backgroundColor: AppColors.error,
      ),
      body: debts.isEmpty 
      ? const Center(child: Text('سجل الديون نظيف! 🎉', style: TextStyle(color: Colors.grey)))
      : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: debts.length,
        itemBuilder: (ctx, i) {
          final d = debts[i];
          double progress = d.totalAmount == 0 ? 0 : d.paidAmount / d.totalAmount;
          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(d.creditorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.payment, color: AppColors.primary), onPressed: () => _showPayDebt(d)),
                  ]),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress, color: progress==1?AppColors.primary:Colors.orange, backgroundColor: Colors.grey[800]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('الإجمالي: ${d.totalAmount}', style: const TextStyle(color: Colors.grey)),
                    Text('متبقي: ${d.totalAmount - d.paidAmount}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= SETTINGS TAB =================
  Widget _buildSettingsTab() {
    final sCtrl = TextEditingController(text: shop.toString());
    final pCtrl = TextEditingController(text: pocket.toString());
    final wCtrl = TextEditingController(text: wallet.toString());

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تعديل الأرصدة (الجرد اليدوي)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: sCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'خزينة المحل', prefixIcon: Icon(Icons.store))),
                  const SizedBox(height: 10),
                  TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'جيبي', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 10),
                  TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'البنك', prefixIcon: Icon(Icons.account_balance))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          shop = double.parse(sCtrl.text);
                          pocket = double.parse(pCtrl.text);
                          wallet = double.parse(wCtrl.text);
                        });
                        _save();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الأرصدة'), backgroundColor: Colors.green));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                      child: const Text('حفظ'),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              leading: const Icon(Icons.file_download, color: AppColors.primary),
              title: const Text('تصدير التقرير (Excel)'),
              onTap: _exportExcel,
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildCreditCard(String title, double amount, Color color, IconData icon) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: Colors.white, size: 30),
            const Icon(Icons.wifi, color: Colors.white54),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 5),
            Text('${amount.toStringAsFixed(0)} EGP', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('**** 1234', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
            Text('VISA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          ])
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5))),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ],
    );
  }

  List<FlSpot> _generateChartData() {
    if (transactions.isEmpty) {
      return [const FlSpot(0, 5), const FlSpot(1, 8), const FlSpot(2, 6), const FlSpot(3, 9), const FlSpot(4, 7)];
    }
    List<FlSpot> spots = [];
    double runningBalance = 0;
    int count = 0;
    for (var t in transactions.reversed.take(10)) {
      if (t.type == 'income') runningBalance += t.amount; else runningBalance -= t.amount;
      spots.add(FlSpot(count.toDouble(), runningBalance));
      count++;
    }
    return spots;
  }

  // --- Actions & Dialogs ---
  void _showAddSheet({required String type}) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); 
    String cat = 'business'; File? img;
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(type == 'income' ? 'إضافة دخل' : 'إضافة مصروف', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Center(child: Text('للمحل')), selected: cat=='business', onSelected: (v)=>setSt(()=>cat='business'), selectedColor: Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: ChoiceChip(label: const Center(child: Text('شخصي')), selected: cat=='personal', onSelected: (v)=>setSt(()=>cat='personal'), selectedColor: AppColors.accent)),
          ]),
          const SizedBox(height: 15),
          TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'الوصف (مثال: خامات)')),
          const SizedBox(height: 10),
          TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.camera_alt), title: const Text('صورة الفاتورة'),
            trailing: img != null ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.chevron_right),
            onTap: () async { final x = await ImagePicker().pickImage(source: ImageSource.camera); if(x!=null) setSt(()=>img=File(x.path)); },
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              if (tCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                String src = cat == 'business' ? 'shop' : 'pocket';
                _addTransaction(tCtrl.text, double.parse(aCtrl.text), type, src, cat, img?.path);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(15)),
            child: const Text('حفظ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ))
        ]),
      )),
    );
  }

  void _showAddDebt() {
    final n=TextEditingController(), a=TextEditingController();
    showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text('دين جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'))]), actions: [TextButton(onPressed: (){setState(()=>debts.add(Debt(id: DateTime.now().toString(), creditorName: n.text, totalAmount: double.parse(a.text), paidAmount: 0))); _save(); Navigator.pop(ctx);}, child: const Text('حفظ'))]));
  }

  void _showPayDebt(Debt d) {
    final a=TextEditingController();
    showDialog(context: context, builder: (ctx)=>AlertDialog(title: Text('سداد لـ ${d.creditorName}'), content: TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ الدفعة')), actions: [TextButton(onPressed: (){ 
      setState(() { 
        d.paidAmount += double.parse(a.text); 
        shop -= double.parse(a.text); // Assume paying from shop by default or add selector
        transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'سداد دين: ${d.creditorName}', amount: double.parse(a.text), type: 'expense', source: 'shop', category: 'personal', date: DateTime.now()));
      }); 
      _save(); Navigator.pop(ctx);
    }, child: const Text('سداد'))]));
  }

  Future<void> _exportExcel() async {
    List<List<dynamic>> rows = [["Date", "Title", "Amount", "Type", "Source"]];
    for (var t in transactions) rows.add([DateFormat('yyyy-MM-dd').format(t.date), t.title, t.amount, t.type, t.source]);
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/report.csv");
    await f.writeAsString(csvData);
    await Share.shareXFiles([XFile(f.path)], text: 'تقرير مالي');
  }
}
