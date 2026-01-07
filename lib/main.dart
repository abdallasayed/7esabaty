import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Wallet Pro v2',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        useMaterial3: true,
      ),
      home: const WalletHome(),
    );
  }
}

// --- Data Model ---
class TransactionItem {
  String id;
  String title;
  double amount;
  String type; // 'expense', 'bill', 'rent'
  String source; // 'pocket', 'wallet'
  bool isPaid;
  DateTime date;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.source,
    required this.isPaid,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type,
        'source': source,
        'isPaid': isPaid,
        'date': date.toIso8601String(),
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
        id: json['id'],
        title: json['title'],
        amount: json['amount'],
        type: json['type'],
        source: json['source'],
        isPaid: json['isPaid'],
        date: DateTime.parse(json['date']),
      );
}

class WalletHome extends StatefulWidget {
  const WalletHome({super.key});

  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> {
  double pocketBalance = 0.0;
  double walletBalance = 0.0;
  List<TransactionItem> transactions = [];

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
      final String? transString = prefs.getString('transactions');
      if (transString != null) {
        transactions = (json.decode(transString) as List)
            .map((i) => TransactionItem.fromJson(i))
            .toList();
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('pocketBalance', pocketBalance);
    prefs.setDouble('walletBalance', walletBalance);
    prefs.setString('transactions', json.encode(transactions.map((e) => e.toJson()).toList()));
  }

  void _addTransaction(String title, double amount, String type, String source, bool isPaid) {
    setState(() {
      transactions.insert(0, TransactionItem(
        id: DateTime.now().toString(),
        title: title,
        amount: amount,
        type: type,
        source: source,
        isPaid: isPaid,
        date: DateTime.now(),
      ));

      if (isPaid) {
        if (source == 'pocket') {
          pocketBalance -= amount;
        } else {
          walletBalance -= amount;
        }
      }
    });
    _saveData();
  }

  void _togglePaidStatus(int index) {
    setState(() {
      final item = transactions[index];
      if (item.isPaid) {
        // Was paid, now unpaying (refund balance)
        item.isPaid = false;
        if (item.source == 'pocket') pocketBalance += item.amount;
        else walletBalance += item.amount;
      } else {
        // Was unpaid, now paying (deduct balance)
        item.isPaid = true;
        if (item.source == 'pocket') pocketBalance -= item.amount;
        else walletBalance -= item.amount;
      }
    });
    _saveData();
  }

  void _deleteTransaction(int index) {
    setState(() {
      final item = transactions[index];
      // If it was paid, refund the money before deleting
      if (item.isPaid) {
        if (item.source == 'pocket') pocketBalance += item.amount;
        else walletBalance += item.amount;
      }
      transactions.removeAt(index);
    });
    _saveData();
  }

  void _transferMoney(double amount, bool fromPocketToWallet) {
    setState(() {
      if (fromPocketToWallet) {
        if (pocketBalance >= amount) {
          pocketBalance -= amount;
          walletBalance += amount;
        }
      } else {
        if (walletBalance >= amount) {
          walletBalance -= amount;
          pocketBalance += amount;
        }
      }
    });
    _saveData();
  }

  // --- UI Components ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Wallet Pro v2', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            onPressed: () => _showTransferDialog(),
            tooltip: 'تحويل أموال',
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _showEditBalanceDialog(),
            tooltip: 'تعديل الأرصدة يدوياً',
          )
        ],
      ),
      body: Column(
        children: [
          // Cards Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildBalanceCard('جيبي', pocketBalance, Colors.orange),
                const SizedBox(width: 16),
                _buildBalanceCard('محفظتي', walletBalance, Colors.blue),
              ],
            ),
          ),
          const Divider(),
          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('لا توجد عمليات مسجلة'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final item = transactions[index];
                      return Dismissible(
                        key: Key(item.id),
                        background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                        onDismissed: (direction) => _deleteTransaction(index),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isPaid ? Colors.green[100] : Colors.red[100],
                              child: Icon(
                                _getIconForType(item.type),
                                color: item.isPaid ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${DateFormat('yyyy-MM-dd').format(item.date)} • ${item.source == 'pocket' ? 'من الجيب' : 'من المحفظة'}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${item.amount.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                InkWell(
                                  onTap: () => _togglePaidStatus(index),
                                  child: Text(
                                    item.isPaid ? 'تم الدفع' : 'مستحق (لم يدفع)',
                                    style: TextStyle(
                                      color: item.isPaid ? Colors.green : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(),
        label: const Text('إضافة مصروف / فاتورة'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${amount.toStringAsFixed(1)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'bill': return Icons.receipt_long;
      case 'rent': return Icons.home_work;
      default: return Icons.fastfood;
    }
  }

  // --- Dialogs ---
  void _showAddTransactionDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'expense';
    String source = 'pocket';
    bool markAsPaid = true; // Default to paid for expenses

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تسجيل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'الوصف (مثال: غداء، كهرباء)')),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('مصروف يومي')),
                    DropdownMenuItem(value: 'bill', child: Text('فاتورة عمل')),
                    DropdownMenuItem(value: 'rent', child: Text('إيجار')),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
                DropdownButtonFormField<String>(
                  value: source,
                  items: const [
                    DropdownMenuItem(value: 'pocket', child: Text('من جيبي')),
                    DropdownMenuItem(value: 'wallet', child: Text('من المحفظة')),
                  ],
                  onChanged: (v) => setState(() => source = v!),
                  decoration: const InputDecoration(labelText: 'المصدر'),
                ),
                SwitchListTile(
                  title: const Text('هل تم الدفع وخصم المبلغ؟'),
                  subtitle: Text(markAsPaid ? 'سيتم الخصم الآن' : 'سيبقى "دين" ولن يخصم الآن'),
                  value: markAsPaid,
                  onChanged: (v) => setState(() => markAsPaid = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  _addTransaction(titleController.text, double.parse(amountController.text), type, source, markAsPaid);
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog() {
    final amountController = TextEditingController();
    bool fromPocket = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تحويل أموال'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(fromPocket ? 'من الجيب إلى المحفظة' : 'من المحفظة إلى الجيب'),
                value: fromPocket,
                onChanged: (v) => setState(() => fromPocket = v),
              ),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (amountController.text.isNotEmpty) {
                  _transferMoney(double.parse(amountController.text), fromPocket);
                  Navigator.pop(context);
                }
              },
              child: const Text('تحويل'),
            ),
          ],
        ),
      ),
    );
  }

    void _showEditBalanceDialog() {
    final pocketController = TextEditingController(text: pocketBalance.toString());
    final walletController = TextEditingController(text: walletBalance.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الرصيد يدوياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pocketController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رصيد الجيب الحالي')),
            TextField(controller: walletController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رصيد المحفظة الحالي')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                pocketBalance = double.tryParse(pocketController.text) ?? pocketBalance;
                walletBalance = double.tryParse(walletController.text) ?? walletBalance;
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

