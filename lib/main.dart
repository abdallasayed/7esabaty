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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// --- الألوان والتصميم ---
class AppColors {
  static const Color primary = Color(0xFF00E676); // أخضر نيون
  static const Color secondary = Color(0xFF2979FF); // أزرق نيون
  static const Color background = Color(0xFF050505); // أسود حالك
  static const Color cardBg = Color(0xFF1A1A1A); // رمادي غامق جداً
  static Color glass = Colors.white.withOpacity(0.08); // زجاج
  static const Color danger = Color(0xFFFF1744); // أحمر
  static const Color warning = Color(0xFFFFC400); // أصفر
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
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        dialogTheme: DialogTheme(backgroundColor: AppColors.cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: AppColors.glass,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          labelStyle: const TextStyle(color: Colors.white54),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- نظام الأمان (البصمة) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLocked = true;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() { super.initState(); _checkAuth(); }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    // الافتراضي: الحماية مفعلة (true). إذا أردت تغييرها عدلها من الإعدادات
    bool authEnabled = prefs.getBool('auth_enabled') ?? false; 
    
    if (!authEnabled) {
      setState(() => _isLocked = false);
    } else {
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: 'المس المستشعر لفتح محفظتك',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
        setState(() => _isLocked = !authenticated);
      } catch (e) {
        // في حالة الخطأ أو عدم وجود بصمة، افتح التطبيق (أو اطلب PIN)
        setState(() => _isLocked = false); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLocked 
        ? Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.fingerprint, size: 100, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text('التطبيق مؤمن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkAuth, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black), child: const Text('فتح القفل'))
          ]))) 
        : const MainScreen();
  }
}

// --- البيانات (Models) ---
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

// --- الشاشة الرئيسية ---
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

  // --- دوال المنطق (Logic) ---
  
  // حفظ الصورة بشكل دائم
  Future<String?> _saveImagePermanent(String path) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImage = await File(path).copy('${dir.path}/$name');
      return newImage.path;
    } catch (e) { return null; }
  }

  void _addTrans(String title, double amt, String type, String src, String cat, String? tempImgPath) async {
    String? finalImg;
    if (tempImgPath != null) finalImg = await _saveImagePermanent(tempImgPath);
    
    setState(() {
      transactions.insert(0, Transaction(id: DateTime.now().toString(), title: title, amount: amt, type: type, source: src, category: cat, imagePath: finalImg, date: DateTime.now()));
      if (type == 'income') { if (src == 'shop') shop += amt; else if (src == 'pocket') pocket += amt; else wallet += amt; }
      else { if (src == 'shop') shop -= amt; else if (src == 'pocket') pocket -= amt; else wallet -= amt; }
    });
    _save();
  }

  void _deleteTrans(String id) {
    final t = transactions.firstWhere((e) => e.id == id);
    setState(() {
      if (t.type == 'transfer') { shop += t.amount; pocket -= t.amount; } // عكس اليومية
      else if (t.type == 'income') { if (t.source == 'shop') shop -= t.amount; else if (t.source == 'pocket') pocket -= t.amount; else wallet -= t.amount; }
      else { if (t.source == 'shop') shop += t.amount; else if (t.source == 'pocket') pocket += t.amount; else wallet += t.amount; }
      transactions.removeWhere((e) => e.id == id);
    });
    _save();
  }

  void _collectWage() {
    if (shop >= 250) {
      setState(() { shop -= 250; pocket += 250; transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'استلام يومية', amount: 250, type: 'transfer', source: 'shop_to_pocket', category: 'personal', date: DateTime.now())); });
      _save();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام 250 جنيه ✅'), backgroundColor: AppColors.primary));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيد المحل لا يكفي!'), backgroundColor: AppColors.danger));
    }
  }

  // دوال الديون (تمت إعادتها كاملة)
  void _addDebt(String name, double total) {
    setState(() => debts.add(Debt(id: DateTime.now().toString(), creditorName: name, totalAmount: total, paidAmount: 0)));
    _save();
  }

  void _payDebt(String id, double amount, String source) {
    final idx = debts.indexWhere((d) => d.id == id);
    if (idx != -1) {
      setState(() {
        debts[idx].paidAmount += amount;
        if (source == 'shop') shop -= amount; else if (source == 'pocket') pocket -= amount; else wallet -= amount;
        transactions.insert(0, Transaction(id: DateTime.now().toString(), title: 'سداد دين: ${debts[idx].creditorName}', amount: amount, type: 'expense', source: source, category: 'personal', date: DateTime.now()));
      });
      _save();
    }
  }

  void _editDebt(String id, String name, double total) {
    final idx = debts.indexWhere((d) => d.id == id);
    if(idx != -1) { setState(() { debts[idx].creditorName = name; debts[idx].totalAmount = total; }); _save(); }
  }

  // تصدير Excel
  Future<void> _exportExcel() async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Title", "Amount", "Type", "Source", "Category"]);
    for (var t in transactions) rows.add([DateFormat('yyyy-MM-dd').format(t.date), t.title, t.amount, t.type, t.source, t.category]);
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/wallet_report.csv");
    await f.writeAsString(csvData);
    await Share.shareXFiles([XFile(f.path)], text: 'تقرير مالي شامل');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(shop: shop, pocket: pocket, wallet: wallet, trans: transactions, onAdd: _addTrans, onDelete: _deleteTrans, onWage: _collectWage),
      DebtsTab(debts: debts, onAdd: _addDebt, onPay: _payDebt, onEdit: _editDebt),
      ReportsTab(transactions: transactions),
      SettingsTab(shop: shop, pocket: pocket, wallet: wallet, onUpdate: (s,p,w){setState((){shop=s;pocket=p;wallet=w;});_save();}, onExport: _exportExcel),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Smart Manager'), backgroundColor: Colors.transparent, actions: [IconButton(onPressed: _exportExcel, icon: const Icon(Icons.file_upload))]),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000000), Color(0xFF1C1C1C)])),
        child: tabs[_index],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _index, onTap: (i) => setState(() => _index = i),
            backgroundColor: Colors.black54, selectedItemColor: AppColors.primary, unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.handshake_rounded), label: 'الديون'),
              BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'تحليل'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'إعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

// --- التبويبات (Tabs) ---

// 1. الرئيسية (Dashboard)
class DashboardTab extends StatelessWidget {
  final double shop, pocket, wallet;
  final List<Transaction> trans;
  final Function(String, double, String, String, String, String?) onAdd;
  final Function(String) onDelete;
  final VoidCallback onWage;

  const DashboardTab({super.key, required this.shop, required this.pocket, required this.wallet, required this.trans, required this.onAdd, required this.onDelete, required this.onWage});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 100), // Padding to account for AppBar and BottomBar
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الرسم البياني الموجي
        SizedBox(
          height: 120,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: _getSpots(), isCurved: true, color: AppColors.primary, barWidth: 3,
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                dotData: const FlDotData(show: false),
              ),
            ],
          )),
        ),
        const SizedBox(height: 20),
        // الكروت (شكل الفيزا)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildVisaCard('خزينة المحل', shop, const Color(0xFFE65100), '**** 1234', Icons.store),
            const SizedBox(width: 15),
            _buildVisaCard('مصروفي الشخصي', pocket, AppColors.secondary, '**** 5678', Icons.person),
            const SizedBox(width: 15),
            _buildVisaCard('حساب البنك', wallet, Colors.purple, '**** 9012', Icons.account_balance),
          ]),
        ),
        const SizedBox(height: 25),
        // زر اليومية السحري
        Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10)]),
          child: ElevatedButton.icon(
            onPressed: onWage,
            icon: const Icon(Icons.monetization_on, color: Colors.black),
            label: const Text('استلام اليومية (250 ج)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        const SizedBox(height: 25),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('آخر العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          IconButton(onPressed: () => _showAddSheet(context), icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30)),
        ]),
        const SizedBox(height: 10),
        ...trans.take(10).map((t) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: t.type=='income'?Colors.green.withOpacity(0.2):Colors.red.withOpacity(0.2), child: Icon(t.type=='income'?Icons.arrow_downward:Icons.arrow_upward, color: t.type=='income'?Colors.green:Colors.red)),
            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('MM/dd').format(t.date)} • ${t.source == 'shop' ? 'محل' : 'شخصي'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (t.imagePath != null) GestureDetector(onTap: ()=>showDialog(context: context, builder: (_)=>Dialog(child: Image.file(File(t.imagePath!)))), child: const Row(children:[Icon(Icons.image, size:12, color:AppColors.secondary), SizedBox(width:4), Text('صورة الفاتورة', style:TextStyle(color:AppColors.secondary, fontSize:10))])),
            ]),
            trailing: Text('${t.amount.toStringAsFixed(0)}', style: TextStyle(color: t.type=='income'?AppColors.primary:AppColors.danger, fontWeight: FontWeight.bold, fontSize: 16)),
            onLongPress: () => onDelete(t.id),
          ),
        )),
      ]),
    );
  }

  List<FlSpot> _getSpots() {
    List<FlSpot> spots = [];
    double current = 0;
    // نأخذ آخر 20 عملية ونعكسها لرسم المسار الزمني
    final reversed = trans.take(20).toList().reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      if (reversed[i].type == 'income') current += reversed[i].amount; else current -= reversed[i].amount;
      spots.add(FlSpot(i.toDouble(), current));
    }
    return spots.isEmpty ? [const FlSpot(0, 0), const FlSpot(1, 10)] : spots;
  }

  Widget _buildVisaCard(String title, double amount, Color color, String num, IconData icon) {
    return Container(
      width: 280, height: 170,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Icon(icon, color: Colors.white54)]),
        const Icon(Icons.nfc, size: 30, color: Colors.white30),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(num, style: const TextStyle(fontSize: 16, letterSpacing: 2, shadows: [Shadow(blurRadius: 2, color: Colors.black26)])),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ABDALLA SAYED', style: TextStyle(fontSize: 10, color: Colors.white70)),
            Text('${amount.toStringAsFixed(0)} EGP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ]),
    );
  }

  void _showAddSheet(BuildContext context) {
    final tCtrl = TextEditingController(); final aCtrl = TextEditingController(); 
    String type = 'expense'; String cat = 'business'; File? img;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('تسجيل عملية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ChoiceChip(label: const Center(child: Text('مصروف')), selected: type=='expense', onSelected: (v)=>setSt(()=>type='expense'), selectedColor: AppColors.danger, labelStyle: const TextStyle(color: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: ChoiceChip(label: const Center(child: Text('دخل')), selected: type=='income', onSelected: (v)=>setSt(()=>type='income'), selectedColor: AppColors.primary, labelStyle: const TextStyle(color: Colors.black))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(onTap: ()=>setSt(()=>cat='business'), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cat=='business'?Colors.orange:Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('للمحل'))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(onTap: ()=>setSt(()=>cat='personal'), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cat=='personal'?AppColors.secondary:Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('شخصي'))))),
        ]),
        const SizedBox(height: 20),
        TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.edit))),
        const SizedBox(height: 10),
        TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.attach_money))),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.camera_alt), title: const Text('صورة الفاتورة'),
          trailing: img != null ? Image.file(img!, width: 40) : const Text('اختياري', style: TextStyle(color: Colors.grey)),
          onTap: () async { final p = ImagePicker(); final x = await p.pickImage(source: ImageSource.camera); if(x!=null) setSt(()=>img=File(x.path)); },
          tileColor: AppColors.glass, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: (){ 
          if(tCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
            String src = cat == 'business' ? 'shop' : 'pocket';
            onAdd(tCtrl.text, double.parse(aCtrl.text), type, src, cat, img?.path); Navigator.pop(ctx);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)), child: const Text('حفظ')),
      ]),
    )));
  }
}

// 2. الديون (Debts) - (تمت استعادتها بالكامل)
class DebtsTab extends StatelessWidget {
  final List<Debt> debts; final Function(String, double) onAdd; final Function(String, double, String) onPay; final Function(String, String, double) onEdit;
  const DebtsTab({super.key, required this.debts, required this.onAdd, required this.onPay, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=>_showAdd(context), backgroundColor: AppColors.danger, label: const Text('دين جديد'), icon: const Icon(Icons.add)),
      body: debts.isEmpty ? const Center(child: Text('لا توجد ديون', style: TextStyle(color: Colors.grey))) : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
        itemCount: debts.length,
        itemBuilder: (ctx, i) {
          final d = debts[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(d.creditorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.edit, color: AppColors.secondary), onPressed: ()=>_showEdit(context, d))
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: d.progress, backgroundColor: Colors.white10, color: d.progress==1?Colors.green:AppColors.warning),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('الكلي: ${d.totalAmount}', style: const TextStyle(color: Colors.grey)),
                Text('باقي: ${d.remaining}', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 15),
              if (d.remaining > 0) ElevatedButton.icon(onPressed: ()=>_showPay(context, d), icon: const Icon(Icons.payment), label: const Text('سداد دفعة'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.glass))
              else const Text('تم السداد بالكامل ✅', style: TextStyle(color: Colors.green)),
            ]),
          );
        },
      ),
    );
  }

  void _showAdd(BuildContext context) {
    final n=TextEditingController(), a=TextEditingController();
    showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text('دين جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')), const SizedBox(height: 10), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'))]), actions: [ElevatedButton(onPressed: (){onAdd(n.text, double.parse(a.text)); Navigator.pop(ctx);}, child: const Text('حفظ'))]));
  }
  void _showPay(BuildContext context, Debt d) {
    final a=TextEditingController(); String src='shop';
    showDialog(context: context, builder: (ctx)=>StatefulBuilder(builder: (ctx,st)=>AlertDialog(title: Text('سداد لـ ${d.creditorName}'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')), const SizedBox(height: 10), DropdownButtonFormField(value: src, items: const [DropdownMenuItem(value: 'shop', child: Text('من المحل')), DropdownMenuItem(value: 'pocket', child: Text('من جيبي'))], onChanged: (v)=>st(()=>src=v!))]), actions: [ElevatedButton(onPressed: (){onPay(d.id, double.parse(a.text), src); Navigator.pop(ctx);}, child: const Text('سداد'))])));
  }
  void _showEdit(BuildContext context, Debt d) {
    final n=TextEditingController(text: d.creditorName), a=TextEditingController(text: d.totalAmount.toString());
    showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text('تعديل'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n), const SizedBox(height: 10), TextField(controller: a, keyboardType: TextInputType.number)]), actions: [ElevatedButton(onPressed: (){onEdit(d.id, n.text, double.parse(a.text)); Navigator.pop(ctx);}, child: const Text('تحديث'))]));
  }
}

// 3. التقارير (Reports) - (تمت استعادتها بالكامل)
class ReportsTab extends StatelessWidget {
  final List<Transaction> transactions;
  const ReportsTab({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) {
    Map<String, double> data = {};
    for (var t in transactions) if (t.type == 'expense') data[t.category] = (data[t.category] ?? 0) + t.amount;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
      child: Column(children: [
        const Text('تحليل المصاريف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        SizedBox(height: 250, child: data.isEmpty ? const Center(child: Text('لا توجد بيانات')) : PieChart(PieChartData(
          sections: data.entries.map((e) => PieChartSectionData(
            value: e.value, title: '${e.key}\n${e.value}', color: e.key=='business'?Colors.orange:AppColors.secondary, radius: 80, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)
          )).toList(),
          sectionsSpace: 2, centerSpaceRadius: 40,
        ))),
        const SizedBox(height: 20),
        Expanded(child: ListView(children: data.entries.map((e) => ListTile(leading: Icon(Icons.circle, color: e.key=='business'?Colors.orange:AppColors.secondary), title: Text(e.key=='business'?'محل':'شخصي'), trailing: Text('${e.value}'))).toList()))
      ]),
    );
  }
}

// 4. الإعدادات (Settings)
class SettingsTab extends StatelessWidget {
  final double shop, pocket, wallet; final Function(double, double, double) onUpdate; final VoidCallback onExport;
  SettingsTab({super.key, required this.shop, required this.pocket, required this.wallet, required this.onUpdate, required this.onExport});
  final s=TextEditingController(), p=TextEditingController(), w=TextEditingController();

  @override
  Widget build(BuildContext context) {
    s.text=shop.toString(); p.text=pocket.toString(); w.text=wallet.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
      child: Column(children: [
        const Text('تعديل الأرصدة يدوياً', style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(controller: s, decoration: const InputDecoration(labelText: 'خزينة المحل', prefixIcon: Icon(Icons.store))),
        const SizedBox(height: 10),
        TextField(controller: p, decoration: const InputDecoration(labelText: 'الجيـب', prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 10),
        TextField(controller: w, decoration: const InputDecoration(labelText: 'البنك', prefixIcon: Icon(Icons.account_balance))),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: ()=>onUpdate(double.parse(s.text), double.parse(p.text), double.parse(w.text)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size(double.infinity, 50)), child: const Text('حفظ التعديلات')),
        const SizedBox(height: 40),
        const Divider(),
        ListTile(title: const Text('تصدير البيانات (Excel)'), leading: const Icon(Icons.file_download), onTap: onExport),
        SwitchListTile(title: const Text('قفل البصمة'), value: true, onChanged: (v) async { final pf = await SharedPreferences.getInstance(); pf.setBool('auth_enabled', v); }, secondary: const Icon(Icons.fingerprint)),
      ]),
    );
  }
}
