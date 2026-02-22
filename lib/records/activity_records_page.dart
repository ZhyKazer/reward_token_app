import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum _RecordFilter { all, customerOnly, employeeAdminOnly }

enum _SortMetric {
  allTransactionType,
  pointsAdded,
  pointsUsed,
  employeeCreation,
  adminCreation,
}

enum _SortOrder { descending, ascending }

class ActivityRecordsPage extends StatefulWidget {
  const ActivityRecordsPage({super.key});

  @override
  State<ActivityRecordsPage> createState() => _ActivityRecordsPageState();
}

class _ActivityRecordsPageState extends State<ActivityRecordsPage> {
  final TextEditingController _searchController = TextEditingController();

  _RecordFilter _filter = _RecordFilter.all;
  _SortMetric _sortMetric = _SortMetric.allTransactionType;
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

  bool _isEmployeeAdminRecord(Map<String, dynamic> data) {
    final actor = data['actor'] as Map<String, dynamic>?;
    final actorRole = ((actor?['role'] as String?) ?? '').toLowerCase();
    return actorRole == 'employee' || actorRole == 'admin';
  }

  bool _recordPassesTypeFilter(Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? '';
    switch (_filter) {
      case _RecordFilter.all:
        return true;
      case _RecordFilter.customerOnly:
        return _isCustomerRecord(type);
      case _RecordFilter.employeeAdminOnly:
        return _isEmployeeAdminRecord(data);
    }
  }

  bool _recordPassesTransactionTypeFilter(String type) {
    switch (_sortMetric) {
      case _SortMetric.allTransactionType:
        return true;
      case _SortMetric.pointsAdded:
        return type == 'points_added';
      case _SortMetric.pointsUsed:
        return type == 'points_used';
      case _SortMetric.employeeCreation:
        return type == 'employee_created';
      case _SortMetric.adminCreation:
        return type == 'admin_created';
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
    final aCreatedAt =
        (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final bCreatedAt =
        (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    if (_sortOrder == _SortOrder.descending) {
      return bCreatedAt.compareTo(aCreatedAt);
    }
    return aCreatedAt.compareTo(bCreatedAt);
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

  String _formatTimeOnly(dynamic value) {
    if (value is! Timestamp) return 'pending time';
    final dt = value.toDate().toLocal();
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final isPm = hour24 >= 12;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = isPm ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  Widget? _buildTypeBadge(Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? '';
    final pointsAdded = _asInt(data['pointsAdded']);

    if (type == 'points_added') {
      final label = pointsAdded > 0 ? '+$pointsAdded' : '+Points';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFA31A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (type == 'points_used') {
      final label = pointsAdded > 0 ? '-$pointsAdded' : '-Points';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFCF6679),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return null;
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
                        value: _SortMetric.allTransactionType,
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: _SortMetric.pointsAdded,
                        child: Text('Points Added'),
                      ),
                      DropdownMenuItem(
                        value: _SortMetric.pointsUsed,
                        child: Text('Points Used'),
                      ),
                      DropdownMenuItem(
                        value: _SortMetric.employeeCreation,
                        child: Text('Employee Creation'),
                      ),
                      DropdownMenuItem(
                        value: _SortMetric.adminCreation,
                        child: Text('Admin Creation'),
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
                      if (!_recordPassesTypeFilter(data)) return false;
                      if (!_recordPassesTransactionTypeFilter(type)) {
                        return false;
                      }
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
                    final title = (data['title'] as String?) ?? 'Record';
                    final customerName = (data['customerName'] as String?)
                        ?.trim();
                    final targetName = (data['targetName'] as String?)?.trim();
                    final destinationName =
                        (targetName != null && targetName.isNotEmpty)
                        ? targetName
                        : (customerName != null && customerName.isNotEmpty)
                        ? customerName
                        : 'Unknown';
                    final badge = _buildTypeBadge(data);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 2,
                                height: 8,
                                color: Theme.of(context).dividerColor,
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                width: 2,
                                height: 40, // Fixed height for the line
                                color: Theme.of(context).dividerColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: 8),
                                      badge,
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('$actorName → $destinationName'),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimeOnly(data['createdAt']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
