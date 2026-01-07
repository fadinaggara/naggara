
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../components/custom_calendar_event_data.dart';
import '../event-notif.dart' hide EventNotification;

class AddEventDialog extends StatefulWidget {
  final CustomCalendarEventData? existingEvent;
  
  const AddEventDialog({super.key, this.existingEvent});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _moneyController = TextEditingController();
  final _dieselController = TextEditingController();
  bool _isSaving = false;
  
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Color _selectedColor;
  
  // List for additional items
  final List<AdditionalItem> _additionalItems = [];
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();

  EventNotification _notification = EventNotification(enabled: false, minutesBefore: 60);

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing event data or defaults
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _titleController.text = event.title ?? '';
      _descController.text = event.description ?? '';
      _moneyController.text = event.money?.toString() ?? '';
      _dieselController.text = event.diesel?.toString() ?? '';
      _selectedDate = event.date;
      _startTime = TimeOfDay.fromDateTime(event.startTime ?? event.date);
      _endTime = TimeOfDay.fromDateTime(event.endTime ?? event.date.add(const Duration(hours: 1)));
      _selectedColor = event.color ?? Colors.blue;
      _additionalItems.addAll(event.additionalItems);
      _notification = event.notification;
    } else {
      _selectedDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      _selectedColor = Colors.blue;
      _notification = EventNotification(enabled: false, minutesBefore: 60);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startTime = picked;
          if (_endTime.hour <= _startTime.hour) {
            _endTime =
                TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _pickColor() async {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Event Color"),
        content: Wrap(
          spacing: 8,
          children: colors
              .map((c) => GestureDetector(
                    onTap: () {
                      setState(() => _selectedColor = c);
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(backgroundColor: c, radius: 16),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _addAdditionalItem() {
    final name = _itemNameController.text.trim();
    final price = double.tryParse(_itemPriceController.text);
    
    if (name.isNotEmpty && price != null && price > 0) {
      setState(() {
        _additionalItems.add(AdditionalItem(name: name, price: price));
        _itemNameController.clear();
        _itemPriceController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid item name and price")),
      );
    }
  }
  

  void _removeAdditionalItem(int index) {
    setState(() {
      _additionalItems.removeAt(index);
    });
  }

  void _editAdditionalItem(int index) {
    final item = _additionalItems[index];
    _itemNameController.text = item.name;
    _itemPriceController.text = item.price.toString();
    _removeAdditionalItem(index);
  }

  // Calculate grand total: money - (diesel + items)
  double _calculateGrandTotal() {
    final money = _moneyController.text.isEmpty ? 0.0 : double.tryParse(_moneyController.text) ?? 0.0;
    final diesel = _dieselController.text.isEmpty ? 0.0 : double.tryParse(_dieselController.text) ?? 0.0;
    final additionalItemsTotal = _additionalItems.fold(0.0, (sum, item) => sum + item.price);
    
    return money - (diesel + additionalItemsTotal);
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "🔔 Notification Settings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // Enable/disable notification
        Row(
          children: [
            Checkbox(
              value: _notification.enabled,
              onChanged: (value) {
                setState(() {
                  _notification = _notification.copyWith(enabled: value ?? false);
                });
              },
            ),
            const Text("Enable Notification", style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        
        if (_notification.enabled) ...[
          const SizedBox(height: 16),
          const Text("Notify me:", style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          
          // Predefined time options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimeOption(15, "15 min"),
              _buildTimeOption(30, "30 min"),
              _buildTimeOption(60, "1 hour"),
              _buildTimeOption(120, "2 hours"),
              _buildTimeOption(240, "4 hours"),
              _buildTimeOption(1440, "1 day"),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Custom time input
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Custom minutes',
                    hintText: 'Enter minutes',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final minutes = int.tryParse(value);
                    if (minutes != null && minutes > 0) {
                      setState(() {
                        _notification = _notification.copyWith(minutesBefore: minutes);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _notification.displayText,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Custom message
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Custom message (optional)',
              hintText: 'e.g., Don\'t forget the documents!',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) {
              setState(() {
                _notification = _notification.copyWith(customMessage: value.isEmpty ? null : value);
              });
            },
          ),
          
          const SizedBox(height: 8),
          Text(
            "You'll be notified ${_notification.displayText} the event",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeOption(int minutes, String label) {
    final isSelected = _notification.minutesBefore == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _notification = _notification.copyWith(minutesBefore: minutes);
          });
        }
      },
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startStr = _startTime.format(context);
    final endStr = _endTime.format(context);

    // Calculate totals for display
    final additionalItemsTotal = _additionalItems.fold(0.0, (sum, item) => sum + item.price);
    final dieselCost = _dieselController.text.isEmpty ? 0.0 : double.tryParse(_dieselController.text) ?? 0.0;
    final moneyAmount = _moneyController.text.isEmpty ? 0.0 : double.tryParse(_moneyController.text) ?? 0.0;
    final grandTotal = _calculateGrandTotal();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingEvent != null ? "Edit Event" : "Add New Event",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: "Title"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Please enter a title" : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _moneyController,
                  decoration: const InputDecoration(
                    labelText: "Money (TND)",
                    prefixText: "TND ",
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {}); // Refresh the UI to update totals
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dieselController,
                  decoration: const InputDecoration(
                    labelText: "Diesel Cost (TND)",
                    prefixText: "TND ",
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {}); // Refresh the UI to update totals
                  },
                ),
                
                // Additional Items Section
                const SizedBox(height: 16),
                const Text(
                  "Additional Items (TND)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Add Item Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: "Item Name",
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _itemPriceController,
                        decoration: const InputDecoration(
                          labelText: "Price",
                          prefixText: "TND",
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          setState(() {}); // Refresh the UI to update totals
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: _addAdditionalItem,
                      tooltip: "Add Item",
                    ),
                  ],
                ),
                
                // List of Additional Items
                if (_additionalItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const Text(
                            "Added Items:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ..._additionalItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("TND ${item.price.toStringAsFixed(2)}"),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                    onPressed: () => _editAdditionalItem(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                                    onPressed: () => _removeAdditionalItem(index),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                          // Show the calculation breakdown
                          if (moneyAmount > 0) ...[
                            Text(
                              "Money: TND ${moneyAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                          if (dieselCost > 0) ...[
                            Text(
                              "Diesel Cost: TND ${dieselCost.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                          if (additionalItemsTotal > 0) ...[
                            Text(
                              "Items Cost: TND ${additionalItemsTotal.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                          if (dieselCost > 0 || additionalItemsTotal > 0) ...[
                            Text(
                              "Total Expenses: TND ${(dieselCost + additionalItemsTotal).toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            "Net Profit: TND ${grandTotal.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: grandTotal >= 0 ? Colors.green : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Date: $dateStr"),
                    IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Start: $startStr"),
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickTime(start: true),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("End: $endStr"),
                    IconButton(
                      icon: const Icon(Icons.access_time_filled),
                      onPressed: () => _pickTime(start: false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Color: "),
                    GestureDetector(
                      onTap: _pickColor,
                      child: CircleAvatar(
                          backgroundColor: _selectedColor, radius: 14),
                    ),
                  ],
                ),

                // Notification Section - ADDED HERE
                _buildNotificationSection(),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        
                        final startDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _startTime.hour,
                          _startTime.minute,
                        );
                        final endDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _endTime.hour,
                          _endTime.minute,
                        );

                        // Parse money and diesel values
                        final money = _moneyController.text.isEmpty 
                            ? null 
                            : double.tryParse(_moneyController.text);
                        final diesel = _dieselController.text.isEmpty 
                            ? null 
                            : double.tryParse(_dieselController.text);

                        final event = CustomCalendarEventData(
                          id: widget.existingEvent?.id ?? CustomCalendarEventData.generateId(),
                          date: _selectedDate,
                          title: _titleController.text,
                          description: _descController.text,
                          startTime: startDateTime,
                          endTime: endDateTime,
                          color: _selectedColor,
                          money: money,
                          diesel: diesel,
                          additionalItems: List.from(_additionalItems),
                          notification: _notification, // ADDED NOTIFICATION
                        );
                        Navigator.pop(context, event);
                      },
                      child: Text(widget.existingEvent != null ? "Update Event" : "Add Event"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}