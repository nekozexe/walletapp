import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(WalletApp());
}

class WalletApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet App For Layla <3',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[1000],
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
        ),
      ),
      home: WalletHomePage(),
    );
  }
}

class WalletHomePage extends StatefulWidget {
  @override
  _WalletHomePageState createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage>
    with TickerProviderStateMixin {
  Map<String, int> euroDenominations = {
    '50.00€': 0,
    '20.00€': 0,
    '10.00€': 0,
    '5.00€': 0,
    '2.00€': 0,
    '1.00€': 0,
    '0.50€': 0,
    '0.20€': 0,
    '0.10€': 0,
    '0.05€': 0,
    '0.02€': 0,
    '0.01€': 0
  };
  double totalAmount = 0.0;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  TabController? _tabController;
  Map<String, int> optimalPayment = {};
  List<Map<String, String>> transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadData();
    loadHistory(); // Load history on initialization
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      euroDenominations.keys.forEach((denomination) {
        euroDenominations[denomination] =
            prefs.getInt(denomination) ?? 0; // Ensure no null values
      });
      totalAmount = calculateTotal();
    });
  }

  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    euroDenominations.forEach((denomination, count) async {
      await prefs.setInt(denomination, count);
    });
    loadData();
  }

  void increment(String denomination) {
    setState(() {
      euroDenominations[denomination] =
          (euroDenominations[denomination] ?? 0) + 1; // Use ?? 0
      totalAmount = calculateTotal();
    });
    saveData();
  }

  void decrement(String denomination) {
    setState(() {
      if ((euroDenominations[denomination] ?? 0) > 0) {
        euroDenominations[denomination] =
            (euroDenominations[denomination] ?? 0) - 1; // Use ?? 0
        totalAmount = calculateTotal();
      }
    });
    saveData();
  }

  double calculateTotal() {
    double total = 0.0;
    euroDenominations.forEach((key, value) {
      total += (value ?? 0) *
          double.parse(
              key.replaceAll('€', '')); // Default to 0 if value is null
    });
    return total;
  }

  void calculateOptimalPayment() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Invalid amount entered.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    List<MapEntry<double, int>> denominations = euroDenominations.entries
        .map((entry) =>
            MapEntry(double.parse(entry.key.replaceAll('€', '')), entry.value))
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // Largest to smallest

    double calculateTotal(Map<String, int> combination) {
      return combination.entries.fold(0.0, (sum, entry) {
        double denomValue = double.parse(entry.key.replaceAll('€', ''));
        return sum + entry.value * denomValue;
      });
    }

    void findCombinations(double remainingAmount,
        Map<String, int> currentCombination, int index) {
      if (remainingAmount <= 0 || index >= denominations.length) {
        double totalUsed = calculateTotal(currentCombination);
        if (totalUsed >= amount &&
            (optimalPayment.isEmpty ||
                totalUsed < calculateTotal(optimalPayment))) {
          optimalPayment = Map.from(currentCombination);
        }
        return;
      }

      var denom = denominations[index];
      double denomValue = denom.key;
      int denomCount = denom.value;

      for (int count = 0; count <= denomCount; count++) {
        double newRemainingAmount = remainingAmount - count * denomValue;
        String denomKey = '${denomValue.toStringAsFixed(2)}€';

        if (count > 0) {
          currentCombination[denomKey] = count;
        }

        findCombinations(newRemainingAmount, currentCombination, index + 1);

        if (count > 0) {
          currentCombination.remove(denomKey);
        }
      }
    }

    optimalPayment = {};
    findCombinations(amount, {}, 0);

    if (optimalPayment.isNotEmpty) {
      double totalUsed = calculateTotal(optimalPayment);
      double overpay = totalUsed - amount;
      double remainingBalance = totalAmount - totalUsed;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Optimal Payment Breakdown'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...optimalPayment.entries.map((entry) {
                  return Text('${entry.key}: ${entry.value}');
                }).toList(),
                Divider(color: Colors.grey),
                Text('Total Used: ${totalUsed.toStringAsFixed(2)}€'),
                Text('Total Overpaid: ${overpay.toStringAsFixed(2)}€'),
                Text(
                    'Remaining Wallet Balance: ${remainingBalance.toStringAsFixed(2)}€'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  await removeOptimalPayment();
                  Navigator.of(context).pop();
                },
                child: Text('Remove'),
              ),
              TextButton(
                onPressed: () {
                  _showSaveToHistoryDialog(totalUsed);
                },
                child: Text('Save to History'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Optimal Payment Breakdown'),
            content: Text('Insufficient funds or no valid combination found.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> removeOptimalPayment() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    optimalPayment.forEach((denomination, count) {
      int currentCount = euroDenominations[denomination] ?? 0;
      euroDenominations[denomination] =
          (currentCount - count).clamp(0, currentCount);
    });
    await saveData();
  }

  Future<void> saveToHistory(String name, double value, DateTime time) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? history = prefs.getStringList('history') ?? [];
    String transaction =
        '$name|${value.toStringAsFixed(2)}€|${formatDateTime(time)}';
    history.add(transaction);
    await prefs.setStringList('history', history);
    loadHistory(); // Refresh history list
  }

  String formatDateTime(DateTime dateTime) {
    // Format the date and time
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? history = prefs.getStringList('history') ?? [];
    setState(() {
      transactionHistory = history.map((entry) {
        var parts = entry.split('|');
        return {
          'name': parts[0],
          'price': parts[1],
          'time': parts[2],
        };
      }).toList();
    });
  }

  void _showSaveToHistoryDialog(double totalUsed) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Save to History'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Text('Value: ${totalUsed.toStringAsFixed(2)}€'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  saveToHistory(name, totalUsed, DateTime.now());
                  Navigator.of(context).pop();
                } else {
                  // Show error if name is empty
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Error'),
                        content: Text('Please enter a name.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditOrDeleteDialog(int index) {
    final transaction = transactionHistory[index];
    final nameController = TextEditingController(text: transaction['name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Edit Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Text('Current Price: ${transaction['price']}'),
              SizedBox(height: 16),
              Text('Date/Time: ${transaction['time']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await editTransaction(index, newName);
                  Navigator.of(context).pop();
                } else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Error'),
                        content: Text('Name cannot be empty.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: Text('Save Changes'),
            ),
            TextButton(
              onPressed: () async {
                await deleteTransaction(index);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> editTransaction(int index, String newName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? history = prefs.getStringList('history') ?? [];
    String transaction = history[index];
    var parts = transaction.split('|');
    parts[0] = newName; // Update the name
    history[index] = parts.join('|');
    await prefs.setStringList('history', history);
    loadHistory(); // Refresh history list
  }

  Future<void> deleteTransaction(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? history = prefs.getStringList('history') ?? [];
    history.removeAt(index);
    await prefs.setStringList('history', history);
    loadHistory(); // Refresh history list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet App For Layla <3'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Wallet'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWalletTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildWalletTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: euroDenominations.keys.map((denomination) {
              return ListTile(
                title: Text(denomination),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () => decrement(denomination),
                    ),
                    Text('${euroDenominations[denomination]}'),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => increment(denomination),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(5.0),
          child: Text('Total Amount: ${totalAmount.toStringAsFixed(2)}€'),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            onPressed: calculateOptimalPayment,
            child: Text('Calculate Optimal Payment'),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      itemCount: transactionHistory.length,
      itemBuilder: (context, index) {
        final transaction = transactionHistory[index];
        return ListTile(
          title: Text(transaction['name'] ?? ''),
          subtitle: Text('${transaction['price']} - ${transaction['time']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _showEditOrDeleteDialog(index),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await deleteTransaction(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
