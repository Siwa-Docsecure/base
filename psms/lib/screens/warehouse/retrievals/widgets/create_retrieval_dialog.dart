// lib/screens/widgets/create_retrieval_dialog.dart
//
// Signature flow:
//   1. Staff signs here (required) when creating the retrieval.
//   2. Client signs later via the Signature button on the retrievals list.
//   3. Once both signatures are present the retrieval is complete.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/retrieval_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/screens/warehouse/boxes/widgets/client_search_field.dart';

class CreateRetrievalDialog extends StatefulWidget {
  const CreateRetrievalDialog({Key? key}) : super(key: key);

  @override
  State<CreateRetrievalDialog> createState() => _CreateRetrievalDialogState();
}

class _CreateRetrievalDialogState extends State<CreateRetrievalDialog> {
  final RetrievalController _ctrl = RetrievalController.instance;
  final TextEditingController _reasonController = TextEditingController();

  // Dedicated client source (same one used across the box screens),
  // instead of RetrievalController's own client cache. Lazy getter so it
  // can never throw a LateInitializationError.
  ClientManagementController? _clientCtrl;
  ClientManagementController get clientCtrl {
    if (_clientCtrl == null) {
      _clientCtrl = Get.isRegistered<ClientManagementController>()
          ? Get.find<ClientManagementController>()
          : Get.put(ClientManagementController());
    }
    return _clientCtrl!;
  }

  // Only staff signature is captured at creation time.
  final SignatureController _staffSigCtrl = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  ClientModel? _selectedClient;
  DateTime _retrievalDate = DateTime.now();

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl.clearSelectedBoxes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  Future<void> _loadClients() async {
    // fetchClients() is paginated (20/page by default) — bump the page
    // size so this one call returns every client for the picker.
    clientCtrl.itemsPerPage.value = 1000;
    await clientCtrl.fetchClients(showLoading: true);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _staffSigCtrl.dispose();
    _ctrl.clearSelectedBoxes();
    super.dispose();
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _retrievalDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3498DB)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _retrievalDate = picked);
  }

  Future<void> _submit() async {
    // ── validation ────────────────────────────────────────────────────────
    if (_selectedClient == null) {
      _snack('Please select a client.');
      return;
    }
    if (_ctrl.selectedBoxes.isEmpty) {
      _snack('Please select at least one box.');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _snack('Please enter a reason.');
      return;
    }
    // Staff signature is required before the retrieval can be created.
    if (_staffSigCtrl.isEmpty) {
      _snack('Staff signature is required to create a retrieval.');
      return;
    }

    // Encode staff signature to base64
    final staffBytes = await _staffSigCtrl.toPngBytes();
    final staffSig = staffBytes != null
        ? 'data:image/png;base64,${base64Encode(staffBytes)}'
        : null;

    if (staffSig == null) {
      _snack('Failed to capture signature. Please try again.');
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final retrievedBy =
        Get.find<AuthController>().currentUser.value?.username ?? 'Unknown';

    final successCount = await _ctrl.createRetrievalsForSelectedBoxes(
      clientId: _selectedClient!.clientId,
      retrievalDate: DateFormat('yyyy-MM-dd').format(_retrievalDate),
      retrievedBy: retrievedBy,
      reason: _reasonController.text.trim(),
      staffSignature: staffSig,
      // clientSignature is intentionally null here — client signs separately.
    );

    if (!mounted) return;
    Get.back(); // close loader

    if (successCount > 0) {
      Navigator.of(context).pop();
      Get.snackbar(
        'Success',
        '$successCount retrieval(s) created. Awaiting client signature.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        'Error',
        _ctrl.errorMessage.value.isNotEmpty
            ? _ctrl.errorMessage.value
            : 'Failed to create retrievals.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _snack(String msg) => Get.snackbar(
        'Validation',
        msg,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientSection(),
                    const SizedBox(height: 16),
                    _buildBoxSection(),
                    const SizedBox(height: 16),
                    _buildDateSection(),
                    const SizedBox(height: 16),
                    _buildReasonSection(),
                    const SizedBox(height: 24),
                    // ── Staff signature ──────────────────────────────────
                    _buildDividerLabel('Staff Signature'),
                    const SizedBox(height: 4),
                    // Contextual note about the two-step signature flow
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF3498DB).withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Color(0xFF3498DB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sign below to authorise this retrieval. '
                              'The client will add their signature separately '
                              'to complete the process.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSignaturePad(_staffSigCtrl, required: true),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── sections ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.add, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('New Retrieval',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Select Client'),
        const SizedBox(height: 8),
        Obx(() => ClientSearchField(
              clients: clientCtrl.clients,
              selectedClientId: _selectedClient?.clientId,
              isLoading: clientCtrl.isLoading.value,
              label: 'Choose a client',
              onChanged: (clientId) {
                ClientModel? client;
                if (clientId != null) {
                  for (final c in clientCtrl.clients) {
                    if (c.clientId == clientId) {
                      client = c;
                      break;
                    }
                  }
                }
                setState(() => _selectedClient = client);
                if (client != null) {
                  _ctrl.getClientStoredBoxes(client.clientId);
                }
              },
            )),
        if (_selectedClient != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _infoRow('Name', _selectedClient!.clientName),
                _infoRow('Code', _selectedClient!.clientCode),
                if (_selectedClient!.contactPerson != null)
                  _infoRow('Contact', _selectedClient!.contactPerson!),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBoxSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Select Boxes to Retrieve'),
        const SizedBox(height: 8),

        // _selectedClient is a plain setState variable — checking it inside Obx
        // causes GetX to throw "improper use" because no observable is read on
        // the null branch. Keep the null-guard outside Obx entirely.
        if (_selectedClient == null)
          _hint('Please select a client first.')
        else
          Obx(() {
            // From here every branch reads at least one controller observable.
            if (_ctrl.loadingBoxes.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (_ctrl.clientStoredBoxes.isEmpty) {
              return _hint('No stored boxes available for this client.');
            }
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: Column(
                children: [
                  _SelectAllRow(controller: _ctrl),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _ctrl.clientStoredBoxes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) => _BoxCheckTile(
                        box: _ctrl.clientStoredBoxes[i],
                        controller: _ctrl,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        // Selected-count badge — fine in its own Obx since it always reads
        // selectedBoxes (an observable), regardless of _selectedClient.
        Obx(() {
          final count = _ctrl.selectedBoxes.length;
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$count box${count == 1 ? '' : 'es'} selected',
              style: const TextStyle(
                  color: Color(0xFF3498DB),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Retrieval Date'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('yyyy-MM-dd').format(_retrievalDate),
                    style: const TextStyle(fontSize: 16)),
                const Icon(Icons.calendar_today, color: Color(0xFF3498DB)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Reason / Description'),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter reason or description',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSignaturePad(SignatureController ctrl, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (required)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text('Required',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
                Text('Draw signature below',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            TextButton.icon(
              onPressed: ctrl.clear,
              icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
              label: const Text('Clear', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Signature(
              controller: ctrl,
              backgroundColor: Colors.grey.shade50,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDividerLabel(String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF3498DB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFF3498DB), fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(() {
              final busy = _ctrl.isLoading.value;
              final count = _ctrl.selectedBoxes.length;
              return ElevatedButton(
                onPressed: busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        count > 1
                            ? 'Create $count Retrievals'
                            : 'Create Retrieval',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── micro-widgets ────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50)),
      );

  Widget _hint(String text) =>
      Text(text, style: const TextStyle(color: Colors.grey));

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Text(':  $value', style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({required this.controller});
  final RetrievalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.clientStoredBoxes.length;
      final selected = controller.selectedBoxes.length;
      final allSelected = total > 0 && selected == total;

      return InkWell(
        onTap: () {
          if (allSelected) {
            controller.clearSelectedBoxes();
          } else {
            controller.selectedBoxes.value =
                List.from(controller.clientStoredBoxes);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                allSelected
                    ? Icons.check_box
                    : selected > 0
                        ? Icons.indeterminate_check_box
                        : Icons.check_box_outline_blank,
                color: const Color(0xFF3498DB),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                allSelected ? 'Deselect all' : 'Select all ($total)',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF2C3E50)),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _BoxCheckTile extends StatelessWidget {
  const _BoxCheckTile({required this.box, required this.controller});
  final BoxModel box;
  final RetrievalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.isBoxSelected(box);
      return InkWell(
        onTap: () => controller.toggleBoxSelection(box),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color:
                    isSelected ? const Color(0xFF3498DB) : Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(box.boxNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (box.description != null && box.description!.isNotEmpty)
                      Text(
                        box.description!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}