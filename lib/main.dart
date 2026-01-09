import 'dart:convert';
import 'dart:ui';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class AppColors {
  static const Color primary = Color(0xFF00E676);
  static const Color secondary = Color(0xFF2979FF);
  static const Color background = Color(0xFF121212);
  static const Color cardBg = Color(0xFF1E1E1E);
  static const Color glass = Color(0x1AFFFFFF);
  static const Color danger = Color(0xFFFF1744);
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
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, background: AppColors.background),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: AppColors.glass,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- Auth & Security ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLocked = true;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    bool authEnabled = prefs.getBool('auth_enabled') ?? false;
    if (!authEnabled) {
      setState(() => _isLocked = false);
    } else {
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: 'يرجى تأكيد الهوية للدخول',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        setState(() => _isLocked = !authenticated);
      } catch (e) {
        setState(() => _isLocked = false); // Fallback if error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLocked 
        ? Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkAuth, child: const Text('افتح التطبيق'))
          ]))) 
        : const MainScreen();
  }
}

// --- Models ---
class Transaction {
  String id, title, type; double amount; String source, category; String? imagePath; DateTime date;
  Transaction({required this.id, required this.title, required this.amount, required this.type, required this.source, required this.category, this.imagePath, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'type': type, 'source': source, 'category': category, 'imagePath': imagePath, 'date': date.toIso8601String()};
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(id: json['id'], title: json['title'], amount: json['amount'], type: json['type'], source: json['source'], category: json['category'] ?? 'personal', imagePath: json['imagePath'], date: DateTime.parse(json['date']));
}

class Debt {
  String id, creditorName; double totalAmount, paidAmount;
  Debt({required this.id, required this.creditorName, required this.totalAmount, required this.paidAmount});
  Map<String, dynamic> toJson() => {'id': id, 'creditorName': creditorName, 'totalAmount': totalAmount, 'paidAmount': paidAmount};
  factory Debt.fromJson(Map<String, dynamic> json) => Debt(id: json['id'], creditorName: json['creditorName'], totalAmount: json['totalAmount'], paidAmount: json['paidAmount']);
  double get progress => totalAmount == 0 ? 0 : paidAmount / totalAmount;
  double get remaining => totalAmount - paidAmount;
}

// --- Main Screen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
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
      final t = prefs.getString('trans'); if (t != null) transactions = (json.decode(t) as List).map((i) => Transaction.fromJson(i)).toList();
      final d = prefs.getString('debts'); if (d != null) debts = (json.decode(d) as List).map((i) => Debt.fromJson(i)).toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('shop', shop); prefs.setDouble('pocket', pocket); prefs.setDouble('wallet', wallet);
    prefs.setString('trans', json.encode(transactions.map((e) => e.toJson()).toList()));
    prefs.setString('debts', json.encode(debts.map((e) => e.toJson()).toList()));
  }

  // --- Logic ---
  Future<String?> _saveImage(String path) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImage = await File(path).copy('${dir.path}/$name');
      return newImage.path;
    } catch (e) { return null; }
  }

  void _addTrans(String title, double amt, String type, String src, String cat, String? imgPath) async {
    String? finalImg;
    if (imgPath != null) finalImg = await _saveImage(imgPath);
    
    setState(() {
      transactions.insert(0, Transaction(id: DateTime.now().toString(), title: title, amount: amt, type: type, source: src, category: cat, imagePath: finalImg, date: DateTime.now()));
      if (type == 'income') { if (src == 'shop') shop += amt; else if (src == 'pocket') pocket += amt; else wallet += amt; }
      else { if (src == 'shop') shop -= amt; else if (src == 'pocket') pocket -= amt; else wallet -= amt; }
    });
    _save();
  }

  void _wage() {
    if (shop >= 250) {
      setState(() { shop -= 250; pocket += 250; transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'يومية', amount: 250, type: 'transfer', source: 'shop_to_pocket', category: 'personal', date: DateTime.now())); });
      _save();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام اليومية'), backgroundColor: AppColors.primary));
    }
  }

  Future<void> _exportExcel() async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Title", "Amount", "Type", "Source"]);
    for (var t in transactions) rows.add([DateFormat('yyyy-MM-dd').format(t.date), t.title, t.amount, t.type, t.source]);
    String csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/report.csv");
    await f.writeAsString(csv);
    await Share.shareXFiles([XFile(f.path)], text: 'تقرير مالي');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(shop: shop, pocket: pocket, wallet: wallet, trans: transactions, onAdd: _addTrans, onWage: _wage),
      DebtsTab(debts: debts, onAdd: (n,t){setState(()=>debts.add(Debt(id: DateTime.now().toString(), creditorName: n, totalAmount: t, paidAmount: 0))); _save();}, onPay: (id,amt){ /*Logic simplified*/ }),
      ReportsTab(transactions: transactions),
      SettingsTab(onExport: _exportExcel),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Smart Manager'), backgroundColor: Colors.transparent),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000000), Color(0xFF1A1A1A)])),
        child: tabs[_index],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _index, onTap: (i) => setState(() => _index = i),
            backgroundColor: Colors.black54, selectedItemColor: AppColors.primary, unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.handshake), label: 'الديون'),
              BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'تحليل'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'إعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TABS (Updated Design) ---

class DashboardTab extends StatelessWidget {
  final double shop, pocket, wallet;
  final List<Transaction> trans;
  final Function(String, double, String, String, String, String?) onAdd;
  final VoidCallback onWage;

  const DashboardTab({super.key, required this.shop, required this.pocket, required this.wallet, required this.trans, required this.onAdd, required this.onWage});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wave Chart (New!)
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _getSpots(),
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.2)),
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Real Visa Cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildRealCard('Shop Treasury', shop, const Color(0xFFD84315), '**** 1234'),
            const SizedBox(width: 15),
            _buildRealCard('My Pocket', pocket, AppColors.secondary, '**** 5678'),
            const SizedBox(width: 15),
            _buildRealCard('Bank Wallet', wallet, Colors.purple, '**** 9012'),
          ]),
        ),
        const SizedBox(height: 25),
        // Magic Wage Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onWage,
            icon: const Icon(Icons.monetization_on, color: Colors.black),
            label: const Text('استلام اليومية (250 ج)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(15)),
          ),
        ),
        const SizedBox(height: 25),
        const Text('Recent Transactions', style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 10),
        ...trans.take(8).map((t) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Icon(t.type=='income'?Icons.arrow_downward:Icons.arrow_upward, color: t.type=='income'?AppColors.primary:AppColors.danger),
            title: Text(t.title),
            subtitle: t.imagePath != null ? const Row(children:[Icon(Icons.image, size:12, color:Colors.grey), Text(' Attached', style:TextStyle(color:Colors.grey))]) : Text(t.source),
            trailing: Text('${t.amount}', style: TextStyle(color: t.type=='income'?AppColors.primary:AppColors.danger, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )),
        const SizedBox(height: 60),
      ]),
    );
  }

  // Generate dummy spots for the chart based on transaction history
  List<FlSpot> _getSpots() {
    List<FlSpot> spots = [];
    double current = 0;
    for (int i = 0; i < trans.take(10).length; i++) {
      if (trans[i].type == 'income') current += trans[i].amount; else current -= trans[i].amount;
      spots.add(FlSpot(i.toDouble(), current));
    }
    return spots.isEmpty ? [const FlSpot(0, 0), const FlSpot(1, 10)] : spots;
  }

  Widget _buildRealCard(String title, double amount, Color color, String number) {
    return Container(
      width: 300, height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Icon(Icons.contactless, color: Colors.white70),
          ]),
          const Icon(Icons.sim_card, color: Colors.amber, size: 40),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(number, style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('ABDULLAH SAYED', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('${amount.toStringAsFixed(0)} EGP', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ],
      ),
    );
  }
}

// --- Other Tabs (Simplified for length) ---
class DebtsTab extends StatelessWidget {
  final List<Debt> debts; final Function(String, double) onAdd; final Function(String, double) onPay;
  const DebtsTab({super.key, required this.debts, required this.onAdd, required this.onPay});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: (){/*Show Dialog*/}, backgroundColor: AppColors.danger, child: const Icon(Icons.person_add)),
      body: ListView.builder(itemCount: debts.length, itemBuilder: (ctx, i) => ListTile(title: Text(debts[i].creditorName), trailing: Text('${debts[i].totalAmount}'))),
    );
  }
}

class ReportsTab extends StatelessWidget {
  final List<Transaction> transactions;
  const ReportsTab({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('التقارير هنا', style: TextStyle(color: Colors.white)));
  }
}

class SettingsTab extends StatelessWidget {
  final VoidCallback onExport;
  const SettingsTab({super.key, required this.onExport});
  @override
  Widget build(BuildContext context) {
    return Center(child: ElevatedButton.icon(onPressed: onExport, icon: const Icon(Icons.file_download), label: const Text('تصدير Excel')));
  }
}
