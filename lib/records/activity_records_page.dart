import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum _RecordFilter { all, customerOnly, employeeAdminOnly }

enum _SortMetric { purchase, points }

enum _SortOrder { descending, ascending }

class ActivityRecordsPage extends StatefulWidget {
  const ActivityRecordsPage({super.key});

  @override
  State<ActivityRecordsPage> createState() => _ActivityRecordsPageState();
}

class _ActivityRecordsPageState extends State<ActivityRecordsPage> {
  final TextEditingController _searchController = TextEditingController();

  _RecordFilter _filter = _RecordFilter.all;
  _SortMetric _sortMetric = _SortMetric.purchase;
  _SortOrder _sortOrder = _SortOrder.descending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCustomerRecord(String type) {
    return type == 'customer_created' ||
        type == 'points_added' ||
        type == 'points_used';
  }

  bool _isEmployeeAdminRecord(String type) {
    return type == 'employee_created' || type == 'admin_created';
  }

  bool _recordPassesTypeFilter(String type) {
    switch (_filter) {
      case _RecordFilter.all:
        return true;
      case _RecordFilter.customerOnly:
        return _isCustomerRecord(type);
      case _RecordFilter.employeeAdminOnly:
        return _isEmployeeAdminRecord(type);
    }
  }

  bool _recordPassesSearch(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;

    final actor = data['actor'] as Map<String, dynamic>?;
    final actorName = (actor?['name'] as String?)?.toLowerCase() ?? '';
    final customerName = (data['customerName'] as String?)?.toLowerCase() ?? '';
    final targetName = (data['targetName'] as String?)?.toLowerCase() ?? '';
    final title = (data['title'] as String?)?.toLowerCase() ?? '';

    return actorName.contains(query) ||
        customerName.contains(query) ||
        targetName.contains(query) ||
        title.contains(query);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  int _sortRecords(Map<String, dynamic> a, Map<String, dynamic> b) {
    int compare;
    switch (_sortMetric) {
      case _SortMetric.purchase:
        compare = _asDouble(
          a['purchasePrice'],
        ).compareTo(_asDouble(b['purchasePrice']));
        break;
      case _SortMetric.points:
        compare = _asInt(a['pointsAdded']).compareTo(_asInt(b['pointsAdded']));
        break;
    }

    if (_sortOrder == _SortOrder.descending) {
      compare = -compare;
    }

    if (compare != 0) return compare;

    final aCreatedAt =
        (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final bCreatedAt =
        (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    return bCreatedAt.compareTo(aCreatedAt);
  }

  String _formatCreatedAt(dynamic value) {
    if (value is! Timestamp) return 'pending timestamp';
    final dt = value.toDate().toLocal();
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search by employee or customer name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == _RecordFilter.all,
                        onSelected: (_) =>
                            setState(() => _filter = _RecordFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Customer only'),
                        selected: _filter == _RecordFilter.customerOnly,
                        onSelected: (_) => setState(
                          () => _filter = _RecordFilter.customerOnly,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Employee/Admin only'),
                        selected: _filter == _RecordFilter.employeeAdminOnly,
                        onSelected: (_) => setState(
                          () => _filter = _RecordFilter.employeeAdminOnly,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_SortMetric>(
                    initialValue: _sortMetric,
                    decoration: const InputDecoration(
                      labelText: 'Sort metric',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _SortMetric.purchase,
                        child: Text('Purchase'),
                      ),
                      DropdownMenuItem(
                        value: _SortMetric.points,
                        child: Text('Points added'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortMetric = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_SortOrder>(
                    initialValue: _sortOrder,
                    decoration: const InputDecoration(
                      labelText: 'Order',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _SortOrder.descending,
                        child: Text('Descending'),
                      ),
                      DropdownMenuItem(
                        value: _SortOrder.ascending,
                        child: Text('Ascending'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortOrder = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load records: ${snapshot.error}'),
                    ),
                  );
                }

                final query = _searchController.text.trim().toLowerCase();
                final records =
                    snapshot.data?.docs.map((doc) => doc.data()).where((data) {
                      final type = (data['type'] as String?) ?? '';
                      if (!_recordPassesTypeFilter(type)) return false;
                      return _recordPassesSearch(data, query);
                    }).toList() ??
                    <Map<String, dynamic>>[];

                records.sort(_sortRecords);

                if (records.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No records found for current search/filter.',
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = records[index];
                    final actor = data['actor'] as Map<String, dynamic>?;
                    final actorName = (actor?['name'] as String?) ?? 'Unknown';
                    final customerName = (data['customerName'] as String?)
                        ?.trim();
                    final targetName = (data['targetName'] as String?)?.trim();
                    final pointsAdded = _asInt(data['pointsAdded']);
                    final purchasePrice = _asDouble(data['purchasePrice']);
                    final title = (data['title'] as String?) ?? 'Record';

                    final subtitleParts = <String>['By: $actorName'];

                    if (customerName != null && customerName.isNotEmpty) {
                      subtitleParts.add('Customer: $customerName');
                    }
                    if (targetName != null && targetName.isNotEmpty) {
                      subtitleParts.add('Name: $targetName');
                    }
                    if (purchasePrice > 0) {
                      subtitleParts.add(
                        'Purchase: ${purchasePrice.toStringAsFixed(2)}',
                      );
                    }
                    if (pointsAdded > 0) {
                      subtitleParts.add('Points: $pointsAdded');
                    }

                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(
                          '${subtitleParts.join(' • ')}\n${_formatCreatedAt(data['createdAt'])}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
