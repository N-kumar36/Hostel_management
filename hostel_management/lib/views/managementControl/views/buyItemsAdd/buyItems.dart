import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/api_service.dart';

class BuyItemsPage extends StatefulWidget {
  const BuyItemsPage({super.key});

  @override
  State<BuyItemsPage> createState() => _BuyItemsPageState();
}

class _BuyItemsPageState extends State<BuyItemsPage> {
  final api = ApiService();
  final themeColor = const Color.fromARGB(255, 34, 211, 208);
  
  List<dynamic> _todoList = [];
  bool _isLoading = false;

  //  Cycle Management State Trackers
  List<dynamic> _cycles = [];
  dynamic _selectedCycle;

  // Track state-managed real-time metrics parsed directly from backend object payload
  double totalMoney = 0.0;
  double spendMoney = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCyclesAndItems();
  }

  // 🌟 Fetch available meal cycles first, then load items for the selected cycle
  Future<void> _fetchCyclesAndItems() async {
    setState(() => _isLoading = true);
    try {
      final cycleResponse = await api.getMealCycleDateBounds();
      if (mounted && cycleResponse['success'] == true) {
        setState(() {
          _cycles = cycleResponse['cycles'] ?? [];
          if (_cycles.isNotEmpty) {
            // Default to the current active cycle, otherwise fallback to the first one
            _selectedCycle = _cycles.firstWhere(
              (c) => c['isCurrentActive'] == true,
              orElse: () => _cycles.first,
            );
          }
        });
      }
      
      // Load shopping list items for the active cycle
      await _fetchItems();
    } catch (e) {
      _showErrorSnackBar("Failed to load cycles: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 Fetch shopping items filtered by selected cycle dates
  Future<void> _fetchItems() async {
    if (_selectedCycle == null) return;
    
    setState(() => _isLoading = true);
    try {
      final String start = _selectedCycle!['startDateStr'].toString();
      final String end = _selectedCycle!['endDateStr'].toString();

      final response = await api.getShoppingList(startDateStr: start, endDateStr: end);
      if (mounted && response['success'] == true) {
        setState(() {
          _todoList = response['data'] ?? [];

          // Map metrics dynamically out of backend finance object block
          if (response['finances'] != null) {
            totalMoney = (response['finances']['totalMoney'] ?? 0.0).toDouble();
            spendMoney = (response['finances']['spendMoney'] ?? 0.0).toDouble();
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar("Failed to load list: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Add a new item to backend database
  Future<void> _addItem(String name, String description, double price) async {
    String formattedDateTime = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final payload = {
      "name": name,
      "description": description,
      "price": price,
      "isBought": false,
      "dateTime": formattedDateTime,
    };

    try {
      final response = await api.addShoppingListItem(payload);
      if (response['success'] == true) {
        _fetchItems(); // Refresh live view metrics
      }
    } catch (e) {
      _showErrorSnackBar("Failed to add item: $e");
    }
  }

  // Update an existing item's text or toggle status
  Future<void> _updateItem(String itemId, Map<String, dynamic> updates) async {
    try {
      final response = await api.updateShoppingList(itemId, updates);
      if (response['success'] == true) {
        _fetchItems(); // Refresh live view metrics
      }
    } catch (e) {
      _showErrorSnackBar("Failed to update item: $e");
    }
  }

  // Delete item from backend database with validation safety popups
  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirmDelete = await _showDeleteConfirmationDialog(
      context,
      itemName,
    );
    if (!confirmDelete) return;

    try {
      final success = await api.deleteShoppingListItem(itemId);
      if (success) {
        _fetchItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("\"$itemName\" removed successfully"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey.shade900,
            ),
          );
        }
      } else {
        _showErrorSnackBar("Failed to delete item from server.");
      }
    } catch (e) {
      _showErrorSnackBar("Error deleting item: $e");
    }
  }

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    String itemName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogCtx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
                size: 32,
              ),
              title: const Text(
                "Delete Item?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Text(
                "Are you sure you want to permanently remove \"$itemName\" from the mess procurement registry?",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Mess Shopping List",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🌟 Cycle Selector Section
          if (_cycles.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text(
                    "Cycle: ",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<dynamic>(
                        isExpanded: true,
                        value: _selectedCycle,
                        items: _cycles.map<DropdownMenuItem<dynamic>>((cycle) {
                          return DropdownMenuItem<dynamic>(
                            value: cycle,
                            child: Text(
                              cycle['label'] ?? "Cycle",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newCycle) {
                          if (newCycle != null) {
                            setState(() => _selectedCycle = newCycle);
                            _fetchItems();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(color: Colors.grey.shade200, height: 1),

          // 📊 Top Financial Metrics Dashboard Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TOTAL MONEY",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalMoney.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.indigo,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SPENT MONEY",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${spendMoney.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(color: Colors.grey.shade200, height: 1),

          // 📝 Procurement Items List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                : _todoList.isEmpty
                    ? const Center(
                        child: Text(
                          "No items added matching this cycle timeline.",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchItems,
                        child: ListView.builder(
                          itemCount: _todoList.length,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                          itemBuilder: (context, index) {
                            final item = _todoList[index];
                            final String id = item['_id']?.toString() ?? "";
                            final String itemName = item['name'] ?? "No Name";
                            final bool isBought = item['isBought'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                title: Text(
                                  itemName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration: isBought ? TextDecoration.lineThrough : null,
                                    color: isBought ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      item['description'] ?? "",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isBought ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 12,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['dateTime'] ?? 'Unknown time',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 12,
                                              color: Colors.indigo.shade300,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['createdBy'] != null && item['createdBy']['name'] != null
                                                  ? "By: ${item['createdBy']['name']}"
                                                  : "By: Unknown Admin",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isBought ? Colors.grey.shade400 : Colors.indigo.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Price: ₹${item['price']}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isBought ? Colors.grey : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isBought,
                                      activeColor: Colors.indigo,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (bool? newValue) {
                                        _updateItem(id, {
                                          "isBought": newValue ?? false,
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: Colors.blue.shade600,
                                        size: 20,
                                      ),
                                      onPressed: () => _showItemFormSheet(context, index: index),
                                      tooltip: "Edit item details",
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.shade400,
                                        size: 20,
                                      ),
                                      onPressed: () => _deleteItem(id, itemName),
                                      tooltip: "Delete item",
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemFormSheet(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Item",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showItemFormSheet(BuildContext context, {int? index}) {
    final isEditing = index != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: isEditing ? _todoList[index]['name'] : '',
    );
    final descController = TextEditingController(
      text: isEditing ? _todoList[index]['description'] : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? _todoList[index]['price'].toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      elevation: 5,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? "Edit Mess Item" : "Add New Mess Item",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditing
                      ? "Modify existing data parameters logged previously."
                      : "Log items that need to be purchased for the hostel mess.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., Gas Cylinder, Chicken, Rice',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter the item name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: descController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Quantity Details',
                    hintText: 'e.g., 15 Kg for Sunday, 19kg commercial refill',
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Estimated Price',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter a price';
                    if (double.tryParse(value) == null) return 'Please enter a valid numeric number';
                    if (double.parse(value) < 0) return 'Price cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(sheetCtx).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final double enteredPrice = double.parse(priceController.text.trim());

                        if (isEditing) {
                          final String id = _todoList[index]['_id']?.toString() ?? "";
                          _updateItem(id, {
                            "name": nameController.text.trim(),
                            "description": descController.text.trim(),
                            "price": enteredPrice,
                          });
                        } else {
                          _addItem(
                            nameController.text.trim(),
                            descController.text.trim(),
                            enteredPrice,
                          );
                        }
                        Navigator.pop(sheetCtx);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isEditing ? Icons.check_circle_rounded : Icons.save_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? "Update Item" : "Save Item to List",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}