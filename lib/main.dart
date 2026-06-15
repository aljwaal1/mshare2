import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustomersServicesApp());
}

class CustomersServicesApp extends StatelessWidget {
  const CustomersServicesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3E6E72);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دفتر العملاء والخدمات',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFFCFDFB),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFFF4F7F6),
          foregroundColor: Color(0xFF203135),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFCFDFB),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE2EAE7)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDCE6E3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDCE6E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.4),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: seed.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: CustomersHomeScreen(),
      ),
    );
  }
}

enum ServiceStatus { planned, inProgress, completed, canceled }

extension ServiceStatusText on ServiceStatus {
  String get label {
    switch (this) {
      case ServiceStatus.planned:
        return 'موعد';
      case ServiceStatus.inProgress:
        return 'قيد العمل';
      case ServiceStatus.completed:
        return 'منجزة';
      case ServiceStatus.canceled:
        return 'ملغاة';
    }
  }

  Color get color {
    switch (this) {
      case ServiceStatus.planned:
        return const Color(0xFF315F72);
      case ServiceStatus.inProgress:
        return const Color(0xFF8A6A20);
      case ServiceStatus.completed:
        return const Color(0xFF2F7D68);
      case ServiceStatus.canceled:
        return const Color(0xFF8B8F89);
    }
  }
}

class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.serviceTitle,
    required this.serviceDate,
    required this.amount,
    required this.paid,
    required this.status,
    required this.note,
  });

  final String id;
  final String customerName;
  final String phone;
  final String serviceTitle;
  final DateTime serviceDate;
  final double amount;
  final double paid;
  final ServiceStatus status;
  final String note;

  double get balance => amount - paid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'phone': phone,
      'serviceTitle': serviceTitle,
      'serviceDate': serviceDate.toIso8601String(),
      'amount': amount,
      'paid': paid,
      'status': status.name,
      'note': note,
    };
  }

  factory ServiceRecord.fromJson(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      customerName: map['customerName'] as String? ?? 'بدون اسم',
      phone: map['phone'] as String? ?? '',
      serviceTitle: map['serviceTitle'] as String? ?? 'خدمة',
      serviceDate: DateTime.tryParse(map['serviceDate'] as String? ?? '') ?? DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paid: (map['paid'] as num?)?.toDouble() ?? 0,
      status: ServiceStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => ServiceStatus.planned,
      ),
      note: map['note'] as String? ?? '',
    );
  }
}

class CustomerSummary {
  const CustomerSummary({
    required this.name,
    required this.phone,
    required this.total,
    required this.paid,
    required this.count,
    required this.lastDate,
  });

  final String name;
  final String phone;
  final double total;
  final double paid;
  final int count;
  final DateTime lastDate;

  double get balance => total - paid;
}

class CustomersHomeScreen extends StatefulWidget {
  const CustomersHomeScreen({super.key});

  @override
  State<CustomersHomeScreen> createState() => _CustomersHomeScreenState();
}

class _CustomersHomeScreenState extends State<CustomersHomeScreen> {
  static const _storageKey = 'customers_services_records_v1';

  final List<ServiceRecord> _records = [];
  final _searchController = TextEditingController();
  int _tab = 0;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      final decoded = jsonDecode(saved) as List<dynamic>;
      _records
        ..clear()
        ..addAll(decoded.map((item) => ServiceRecord.fromJson(item as Map<String, dynamic>)));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_records.map((item) => item.toJson()).toList()));
  }

  List<CustomerSummary> get _allCustomers {
    final grouped = <String, List<ServiceRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.customerName, () => []).add(record);
    }

    final customers = grouped.entries.map((entry) {
      final list = entry.value..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
      final phone = list.firstWhere((item) => item.phone.trim().isNotEmpty, orElse: () => list.first).phone;
      return CustomerSummary(
        name: entry.key,
        phone: phone,
        total: list.fold(0, (sum, item) => sum + item.amount),
        paid: list.fold(0, (sum, item) => sum + item.paid),
        count: list.length,
        lastDate: list.first.serviceDate,
      );
    }).toList();

    customers.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return customers;
  }

  List<CustomerSummary> get _customers {
    if (_query.isEmpty) return _allCustomers;
    return _allCustomers.where((item) {
      return item.name.contains(_query) || item.phone.contains(_query);
    }).toList();
  }

  List<ServiceRecord> get _services {
    final list = [..._records]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    if (_query.isEmpty) return list;
    return list.where((item) {
      return item.customerName.contains(_query) ||
          item.phone.contains(_query) ||
          item.serviceTitle.contains(_query) ||
          item.note.contains(_query);
    }).toList();
  }

  double get _totalServices => _records.fold(0, (sum, item) => sum + item.amount);

  double get _totalPaid => _records.fold(0, (sum, item) => sum + item.paid);

  double get _totalBalance => _totalServices - _totalPaid;

  int get _upcomingCount {
    final today = DateTime.now();
    return _records.where((item) {
      final diff = _dayDifference(item.serviceDate, today);
      return diff >= 0 && diff <= 7 && item.status != ServiceStatus.completed && item.status != ServiceStatus.canceled;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _tab,
            children: [
              _CustomersView(
                customers: _customers,
                searchController: _searchController,
                totalServices: _totalServices,
                totalPaid: _totalPaid,
                totalBalance: _totalBalance,
                upcomingCount: _upcomingCount,
                onOpen: _openCustomer,
                onAdd: _openRecordSheet,
                onCopyMessage: _copyCustomerMessage,
              ),
              _ServicesView(
                records: _services,
                searchController: _searchController,
                onDelete: _deleteRecord,
                onOpenCustomer: (name) => _openCustomer(_allCustomers.firstWhere((item) => item.name == name)),
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'دفتر العملاء والخدمات',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة خدمة',
            onPressed: () => _openRecordSheet(),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecordSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('خدمة جديدة'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2_rounded),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: 'الخدمات',
          ),
        ],
      ),
    );
  }

  Future<void> _openRecordSheet({String? customerName, String? phone}) async {
    final record = await showModalBottomSheet<ServiceRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceSheet(customerName: customerName, phone: phone),
    );
    if (record == null) return;
    setState(() => _records.add(record));
    await _saveRecords();
  }

  Future<void> _deleteRecord(ServiceRecord record) async {
    setState(() => _records.removeWhere((item) => item.id == record.id));
    await _saveRecords();
  }

  void _openCustomer(CustomerSummary customer) {
    final records = _records.where((item) => item.customerName == customer.name).toList()
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: CustomerDetailsScreen(
            customer: customer,
            records: records,
            onAdd: () => _openRecordSheet(customerName: customer.name, phone: customer.phone),
            onDelete: _deleteRecord,
            onCopyMessage: () => _copyCustomerMessage(customer),
          ),
        ),
      ),
    );
  }

  Future<void> _copyCustomerMessage(CustomerSummary customer) async {
    await Clipboard.setData(ClipboardData(text: followUpMessage(customer)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رسالة المتابعة')),
    );
  }
}

class _CustomersView extends StatelessWidget {
  const _CustomersView({
    required this.customers,
    required this.searchController,
    required this.totalServices,
    required this.totalPaid,
    required this.totalBalance,
    required this.upcomingCount,
    required this.onOpen,
    required this.onAdd,
    required this.onCopyMessage,
  });

  final List<CustomerSummary> customers;
  final TextEditingController searchController;
  final double totalServices;
  final double totalPaid;
  final double totalBalance;
  final int upcomingCount;
  final ValueChanged<CustomerSummary> onOpen;
  final void Function({String? customerName, String? phone}) onAdd;
  final ValueChanged<CustomerSummary> onCopyMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        const Text(
          'ملخص العمل',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF203135)),
        ),
        const SizedBox(height: 6),
        const Text(
          'تابع العملاء والخدمات والدفعات من مكان واحد.',
          style: TextStyle(color: Color(0xFF647477), height: 1.45),
        ),
        const SizedBox(height: 14),
        _HeroBalance(totalBalance: totalBalance, upcomingCount: upcomingCount),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MetricTile(title: 'إجمالي الخدمات', value: totalServices, color: const Color(0xFF3E6E72))),
            const SizedBox(width: 8),
            Expanded(child: _MetricTile(title: 'المقبوض', value: totalPaid, color: const Color(0xFF2F7D68))),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'بحث باسم العميل أو الهاتف',
          ),
        ),
        const SizedBox(height: 14),
        if (customers.isEmpty)
          const _EmptyState(
            title: 'لا يوجد عملاء بعد',
            subtitle: 'أضف أول خدمة، وسيظهر العميل هنا تلقائيًا.',
          )
        else
          ...customers.map(
            (customer) => _CustomerTile(
              customer: customer,
              onOpen: () => onOpen(customer),
              onAdd: () => onAdd(customerName: customer.name, phone: customer.phone),
              onCopyMessage: () => onCopyMessage(customer),
            ),
          ),
      ],
    );
  }
}

class _ServicesView extends StatelessWidget {
  const _ServicesView({
    required this.records,
    required this.searchController,
    required this.onDelete,
    required this.onOpenCustomer,
  });

  final List<ServiceRecord> records;
  final TextEditingController searchController;
  final ValueChanged<ServiceRecord> onDelete;
  final ValueChanged<String> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        const Text(
          'الخدمات',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF203135)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'بحث في الخدمات',
          ),
        ),
        const SizedBox(height: 14),
        if (records.isEmpty)
          const _EmptyState(
            title: 'لا توجد خدمات',
            subtitle: 'أضف خدمة أو موعدًا جديدًا.',
          )
        else
          ...records.map(
            (record) => _ServiceTile(
              record: record,
              onDelete: () => onDelete(record),
              onOpenCustomer: () => onOpenCustomer(record.customerName),
            ),
          ),
      ],
    );
  }
}

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    required this.records,
    required this.onAdd,
    required this.onDelete,
    required this.onCopyMessage,
  });

  final CustomerSummary customer;
  final List<ServiceRecord> records;
  final VoidCallback onAdd;
  final ValueChanged<ServiceRecord> onDelete;
  final VoidCallback onCopyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'نسخ متابعة',
            onPressed: onCopyMessage,
            icon: const Icon(Icons.content_copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
        children: [
          _CustomerBalancePanel(customer: customer),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة خدمة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyMessage,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ متابعة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'سجل الخدمات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF203135)),
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const _EmptyState(title: 'لا توجد خدمات', subtitle: 'أضف أول خدمة لهذا العميل.')
          else
            ...records.map(
              (record) => _ServiceTile(
                record: record,
                onDelete: () => onDelete(record),
                onOpenCustomer: () {},
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('خدمة'),
      ),
    );
  }
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({
    this.customerName,
    this.phone,
  });

  final String? customerName;
  final String? phone;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _serviceController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidController = TextEditingController(text: '0');
  final _noteController = TextEditingController();

  DateTime _serviceDate = DateTime.now();
  ServiceStatus _status = ServiceStatus.planned;

  @override
  void initState() {
    super.initState();
    _customerController.text = widget.customerName ?? '';
    _phoneController.text = widget.phone ?? '';
  }

  @override
  void dispose() {
    _customerController.dispose();
    _phoneController.dispose();
    _serviceController.dispose();
    _amountController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFDFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2EAE7)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'خدمة جديدة',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customerController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم العميل'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'اكتب اسم العميل';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف اختياري'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _serviceController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم الخدمة', hintText: 'مثال: صيانة مكيف، تصميم شعار'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'اكتب اسم الخدمة';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('تاريخ الخدمة أو الموعد: ${formatDate(_serviceDate)}'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ServiceStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'حالة الخدمة'),
                  items: ServiceStatus.values
                      .map((status) => DropdownMenuItem(value: status, child: Text(status.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'مبلغ الخدمة', suffixText: 'د.أ'),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null || amount < 0) return 'اكتب مبلغًا صحيحًا';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'الدفعة', suffixText: 'د.أ'),
                  validator: (value) {
                    final paid = double.tryParse(value ?? '0');
                    if (paid == null || paid < 0) return 'اكتب دفعة صحيحة';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظ الخدمة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _serviceDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text);
    final paid = double.parse(_paidController.text.isEmpty ? '0' : _paidController.text);
    final record = ServiceRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      customerName: _customerController.text.trim(),
      phone: _phoneController.text.trim(),
      serviceTitle: _serviceController.text.trim(),
      serviceDate: _serviceDate,
      amount: amount,
      paid: paid > amount ? amount : paid,
      status: _status,
      note: _noteController.text.trim(),
    );
    Navigator.pop(context, record);
  }
}

class _HeroBalance extends StatelessWidget {
  const _HeroBalance({
    required this.totalBalance,
    required this.upcomingCount,
  });

  final double totalBalance;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF203135),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المبالغ المتبقية',
            style: TextStyle(color: Color(0xFFCDE0DD), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 8),
          Text(
            upcomingCount == 0 ? 'لا توجد مواعيد قريبة خلال 7 أيام.' : '$upcomingCount خدمة أو موعد خلال 7 أيام.',
            style: const TextStyle(color: Color(0xFFCDE0DD)),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF647477), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              formatMoney(value),
              style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.onOpen,
    required this.onAdd,
    required this.onCopyMessage,
  });

  final CustomerSummary customer;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onCopyMessage;

  @override
  Widget build(BuildContext context) {
    final color = customer.balance > 0 ? const Color(0xFFB9574F) : const Color(0xFF2F7D68);
    final status = customer.balance > 0 ? 'متبقي' : 'مسدد';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Text(customer.name.characters.first),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF203135)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$status · ${customer.count} خدمة · آخر خدمة ${formatDate(customer.lastDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF647477), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(customer.balance),
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'خدمة',
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 20),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'نسخ متابعة',
                        onPressed: onCopyMessage,
                        icon: const Icon(Icons.copy_rounded, size: 19),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.record,
    required this.onDelete,
    required this.onOpenCustomer,
  });

  final ServiceRecord record;
  final VoidCallback onDelete;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: record.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.handyman_rounded, color: record.status.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onOpenCustomer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF203135)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.customerName} · ${record.status.label} · ${formatDate(record.serviceDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF647477), fontSize: 12),
                    ),
                    if (record.note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        record.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF7A8788), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(record.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  record.balance > 0 ? 'متبقي ${formatMoney(record.balance)}' : 'مدفوع',
                  style: TextStyle(
                    color: record.balance > 0 ? const Color(0xFFB9574F) : const Color(0xFF2F7D68),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'حذف',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBalancePanel extends StatelessWidget {
  const _CustomerBalancePanel({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final settled = customer.balance <= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF203135),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settled ? 'الحساب مسدد' : 'متبقي على العميل',
            style: const TextStyle(color: Color(0xFFCDE0DD), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(customer.balance),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'إجمالي الخدمات ${formatMoney(customer.total)} · المقبوض ${formatMoney(customer.paid)}',
            style: const TextStyle(color: Color(0xFFCDE0DD)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.people_alt_outlined, size: 34, color: Color(0xFF849294)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF647477), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

String followUpMessage(CustomerSummary customer) {
  if (customer.balance <= 0) {
    return 'مرحبًا ${customer.name}، شكرًا لك. حساب الخدمات لدينا مسدد ولا يوجد مبلغ متبقٍ.';
  }
  return 'مرحبًا ${customer.name}، للتذكير يوجد مبلغ متبقٍ ${formatMoney(customer.balance)} مقابل الخدمات. شكرًا لك.';
}

int _dayDifference(DateTime target, DateTime base) {
  final targetDay = DateTime(target.year, target.month, target.day);
  final baseDay = DateTime(base.year, base.month, base.day);
  return targetDay.difference(baseDay).inDays;
}

String formatMoney(double value) {
  final absValue = value.abs();
  final number = absValue == absValue.roundToDouble()
      ? absValue.toStringAsFixed(0)
      : absValue.toStringAsFixed(2);
  return '$number د.أ';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
