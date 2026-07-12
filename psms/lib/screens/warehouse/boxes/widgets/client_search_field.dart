// client_search_field.dart
//
// A reusable, searchable, scrollable client selector.
// Tapping the field opens a dialog with a search box and a scrollable
// list of ALL clients passed in — filtering by client name or code.

import 'package:flutter/material.dart';
import 'package:psms/models/client_model.dart';

class ClientSearchField extends StatelessWidget {
  final List<ClientModel> clients;
  final int? selectedClientId;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final String label;
  // Shows this text instead of looking selectedClientId up in `clients`.
  // Useful in edit mode, where the box's client might be inactive/filtered
  // out of the list this picker was given, but we still know its name.
  final String? displayOverride;
  final bool isLoading;
  // If set, a pinned option (e.g. "All Clients") appears at the top of the
  // picker, always visible regardless of search text. Selecting it calls
  // onChanged(null). Pass null (default) to omit it — every client is
  // then required to have a real selection.
  final String? allOptionLabel;

  const ClientSearchField({
    Key? key,
    required this.clients,
    required this.selectedClientId,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Select Client *',
    this.displayOverride,
    this.isLoading = false,
    this.allOptionLabel,
  }) : super(key: key);

  ClientModel? get _selectedClient {
    for (final c in clients) {
      if (c.clientId == selectedClientId) return c;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<_ClientPickerResult>(
      context: context,
      builder: (_) => _ClientPickerDialog(
        clients: clients,
        allOptionLabel: allOptionLabel,
      ),
    );
    if (result != null) {
      onChanged(result.client?.clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedClient = _selectedClient;
    final canTap = enabled && !isLoading;
    final showingAllOption =
        allOptionLabel != null && selectedClientId == null && !isLoading;

    String displayText;
    if (displayOverride != null && displayOverride!.trim().isNotEmpty) {
      displayText = displayOverride!;
    } else if (selectedClient != null) {
      displayText = '${selectedClient.clientCode} - ${selectedClient.clientName}';
    } else if (showingAllOption) {
      displayText = allOptionLabel!;
    } else if (isLoading) {
      displayText = 'Loading clients...';
    } else if (clients.isEmpty) {
      displayText = 'No clients loaded';
    } else {
      displayText = 'Tap to select client';
    }

    return InkWell(
      onTap: canTap ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(Icons.business,
                  color: enabled ? Colors.blue.shade700 : Colors.grey),
          suffixIcon: canTap ? Icon(Icons.arrow_drop_down) : null,
          filled: !enabled,
          fillColor: Colors.grey.shade100,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: (selectedClient != null ||
                    displayOverride != null ||
                    showingAllOption)
                ? Colors.black87
                : Colors.grey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// Distinguishes "user picked All Clients" (client == null) from
// "user dismissed the dialog without choosing" (result == null overall).
class _ClientPickerResult {
  final ClientModel? client;
  const _ClientPickerResult(this.client);
}

class _ClientPickerDialog extends StatefulWidget {
  final List<ClientModel> clients;
  final String? allOptionLabel;

  const _ClientPickerDialog({
    Key? key,
    required this.clients,
    this.allOptionLabel,
  }) : super(key: key);

  @override
  State<_ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends State<_ClientPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ClientModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.clients;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.clients
          : widget.clients.where((c) {
              final name = (c.clientName).toLowerCase();
              final code = (c.clientCode).toLowerCase();
              return name.contains(q) || code.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
            SizedBox(height: 8),
            if (widget.allOptionLabel != null)
              Container(
                margin: EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.groups, color: Colors.blue.shade700),
                  title: Text(
                    widget.allOptionLabel!,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () =>
                      Navigator.pop(context, const _ClientPickerResult(null)),
                ),
              ),
            Text(
              '${_filtered.length} of ${widget.clients.length} clients',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 4),
            Flexible(
              child: widget.clients.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No clients available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No clients match your search',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1),
                            itemBuilder: (context, index) {
                              final client = _filtered[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                    '${client.clientCode} - ${client.clientName}'),
                                onTap: () => Navigator.pop(
                                    context, _ClientPickerResult(client)),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Multi-select variant — used where several clients can be picked
// at once (e.g. bulk report generation). Same searchable/scrollable
// dialog pattern as ClientSearchField, with checkboxes instead of
// single-tap selection, plus Select All / Clear All shortcuts.
// ============================================================

class ClientMultiSelectField extends StatelessWidget {
  final List<ClientModel> clients;
  final List<int> selectedClientIds;
  final ValueChanged<List<int>> onChanged;
  final bool enabled;
  final String label;
  final bool isLoading;
  // Shown in the closed field when nothing is selected, e.g.
  // "All Clients (optional)".
  final String emptyLabel;

  const ClientMultiSelectField({
    Key? key,
    required this.clients,
    required this.selectedClientIds,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Select Clients',
    this.isLoading = false,
    this.emptyLabel = 'All Clients (optional)',
  }) : super(key: key);

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ClientMultiSelectDialog(
        clients: clients,
        initialSelectedIds: selectedClientIds,
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;
    final count = selectedClientIds.length;

    String displayText;
    if (isLoading) {
      displayText = 'Loading clients...';
    } else if (clients.isEmpty) {
      displayText = 'No clients loaded';
    } else if (count == 0) {
      displayText = emptyLabel;
    } else if (count == 1) {
      final client = clients.firstWhere(
        (c) => c.clientId == selectedClientIds.first,
        orElse: () => ClientModel(
          clientId: selectedClientIds.first,
          clientName: 'Unknown',
          clientCode: 'N/A',
          contactPerson: '',
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      displayText = '${client.clientCode} - ${client.clientName}';
    } else {
      displayText = '$count clients selected';
    }

    return InkWell(
      onTap: canTap ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(Icons.business,
                  color: enabled ? Colors.blue.shade700 : Colors.grey),
          suffixIcon: canTap ? Icon(Icons.arrow_drop_down) : null,
          filled: !enabled,
          fillColor: Colors.grey.shade100,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: count > 0 ? Colors.black87 : Colors.grey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ClientMultiSelectDialog extends StatefulWidget {
  final List<ClientModel> clients;
  final List<int> initialSelectedIds;

  const _ClientMultiSelectDialog({
    Key? key,
    required this.clients,
    required this.initialSelectedIds,
  }) : super(key: key);

  @override
  State<_ClientMultiSelectDialog> createState() =>
      _ClientMultiSelectDialogState();
}

class _ClientMultiSelectDialogState extends State<_ClientMultiSelectDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ClientModel> _filtered;
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _filtered = widget.clients;
    _selected = widget.initialSelectedIds.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.clients
          : widget.clients.where((c) {
              final name = (c.clientName).toLowerCase();
              final code = (c.clientCode).toLowerCase();
              return name.contains(q) || code.contains(q);
            }).toList();
    });
  }

  void _toggle(int clientId, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(clientId);
      } else {
        _selected.remove(clientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Clients',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selected.length} of ${widget.clients.length} selected',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _filtered.isEmpty
                          ? null
                          : () => setState(() {
                                _selected.addAll(
                                    _filtered.map((c) => c.clientId));
                              }),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8)),
                      child: Text('Select All', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(() => _selected.clear()),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8)),
                      child: Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            Flexible(
              child: widget.clients.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No clients available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No clients match your search',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1),
                            itemBuilder: (context, index) {
                              final client = _filtered[index];
                              return CheckboxListTile(
                                dense: true,
                                value: _selected.contains(client.clientId),
                                onChanged: (checked) =>
                                    _toggle(client.clientId, checked ?? false),
                                title: Text(
                                    '${client.clientCode} - ${client.clientName}'),
                              );
                            },
                          ),
                        ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _selected.toList()),
                    child: Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}