// box_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/racking_label_model.dart';

// Unified Box Dialog for both Create and Edit
class BoxDialog extends StatefulWidget {
  final BoxModel? box; // null for create, not null for edit

  BoxDialog({this.box});

  @override
  _BoxDialogState createState() => _BoxDialogState();
}

class _BoxDialogState extends State<BoxDialog> {
  final BoxController boxController = Get.find<BoxController>();
  final StorageController storageController = Get.find<StorageController>();
  final _formKey = GlobalKey<FormState>();

  int? _selectedClientId;
  String? _clientCode;
  int? _selectedRackingLabelId;
  final TextEditingController _boxIndexController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _retentionController =
      TextEditingController(text: '7');

  String _boxNumberPreview = '';
  bool _isEditMode = false;
  bool _loadingLocations = false;
  String _locationError = '';

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.box != null;

    if (_isEditMode) {
      // Edit mode: populate fields with existing box data
      final box = widget.box!;
      _selectedClientId = box.client.clientId;
      _clientCode = box.client.clientCode;
      _selectedRackingLabelId = box.rackingLabel?.labelId;
      _boxIndexController.text = _extractBoxIndex(box.boxNumber);
      _descriptionController.text = box.description;
      _dateController.text = DateFormat('yyyy-MM-dd').format(box.dateReceived);
      _retentionController.text = box.retentionYears.toString();
      _boxNumberPreview = box.boxNumber;
    } else {
      // Create mode: set defaults
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // Listen to box index changes to update preview
    _boxIndexController.addListener(_updateBoxNumberPreview);

    // Load available storage locations when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableLocations();
    });
  }

  @override
  void dispose() {
    _boxIndexController.removeListener(_updateBoxNumberPreview);
    super.dispose();
  }

  String _extractBoxIndex(String fullBoxNumber) {
    // Extract box index from full box number (e.g., "CLIENT-CODE-BOX-001" -> "001")
    final parts = fullBoxNumber.split('-');
    if (parts.length >= 2) {
      return parts.last;
    }
    return fullBoxNumber;
  }

  void _updateBoxNumberPreview() {
    if (_selectedClientId != null && _boxIndexController.text.isNotEmpty) {
      final clientCode = boxController.getClientCode(_selectedClientId!);
      if (clientCode != null) {
        setState(() {
          _boxNumberPreview = BoxNumberHelper.formatBoxNumber(
              clientCode, _boxIndexController.text);
        });
      }
    } else {
      setState(() {
        _boxNumberPreview = '';
      });
    }
  }

  Future<void> _loadAvailableLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationError = '';
    });

    try {
      // First try to load all locations
      if (storageController.storageLocations.isEmpty) {
        await storageController.getAllLocations();
      }

      // Then get available locations
      if (storageController.availableLocations.isEmpty) {
        await storageController.getAvailableLocations();
      }

      // If still empty, try BoxController as fallback
      if (storageController.availableLocations.isEmpty &&
          boxController.availableRackingLabels.isEmpty) {
        await boxController.getAvailableRackingLabels();
      }
    } catch (e) {
      _locationError = 'Failed to load storage locations: $e';
    } finally {
      setState(() {
        _loadingLocations = false;
      });
    }
  }

  List<RackingLabelModel> get _availableLocations {
    // Try StorageController first
    if (storageController.availableLocations.isNotEmpty) {
      return storageController.availableLocations;
    }

    // Fall back to BoxController
    if (boxController.availableRackingLabels.isNotEmpty) {
      return boxController.availableRackingLabels;
    }

    // If no available locations, show all locations (for edit mode)
    if (_isEditMode && storageController.storageLocations.isNotEmpty) {
      return storageController.storageLocations;
    }

    return [];
  }

  void _onClientChanged(int? clientId) {
    if (_isEditMode) {
      // In edit mode, don't allow changing client
      Get.snackbar(
        'Info',
        'Cannot change client for existing box',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _selectedClientId = clientId;
      if (clientId != null) {
        _clientCode = boxController.getClientCode(clientId);
      } else {
        _clientCode = null;
      }
      _updateBoxNumberPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 650, // Add this line
          maxHeight: MediaQuery.of(context).size.height *
              0.8, // Change from 0.9 to 0.8
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color:
                    _isEditMode ? Colors.orange.shade700 : Colors.blue.shade700,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? 'Edit Box' : 'Create New Box',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Box Number Preview/Display
                        if (_boxNumberPreview.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _isEditMode
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _isEditMode
                                      ? Colors.orange.shade200
                                      : Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: _isEditMode
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                    size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Box Number: $_boxNumberPreview',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: _isEditMode
                                          ? Colors.orange.shade800
                                          : Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Client selection (disabled in edit mode)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.business,
                                color: _isEditMode
                                    ? Colors.orange
                                    : Colors.blue.shade700),
                            title: Obx(() {
                              if (_isEditMode) {
                                // Show client as read-only in edit mode
                                final client = boxController.clients.firstWhere(
                                  (c) => c.clientId == _selectedClientId,
                                  orElse: () => ClientModel(
                                    clientId: 0,
                                    clientName: 'Unknown',
                                    clientCode: 'N/A',
                                    contactPerson: '',
                                    isActive: false,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  ),
                                );
                                return Text(
                                    '${client.clientCode} - ${client.clientName}');
                              } else {
                                return DropdownButton<int?>(
                                  value: _selectedClientId,
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'Select Client *',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ...boxController.clients.map((client) {
                                      return DropdownMenuItem(
                                        value: client.clientId,
                                        child: Text(
                                            '${client.clientCode} - ${client.clientName}'),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: _onClientChanged,
                                );
                              }
                            }),
                          ),
                        ),
                        if (!_isEditMode && _selectedClientId == null)
                          Padding(
                            padding: EdgeInsets.only(left: 16, top: 4),
                            child: Text(
                              'Client selection is required',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        SizedBox(height: 20),

                        // Box Index (disabled in edit mode)
                        TextFormField(
                          controller: _boxIndexController,
                          decoration: InputDecoration(
                            labelText: 'Box Index *',
                            hintText: 'e.g., 001, 001-A, 2024-001',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                            suffixIcon: _clientCode != null && !_isEditMode
                                ? Container(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _clientCode!,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                            prefixText:
                                _selectedClientId != null && !_isEditMode
                                    ? ''
                                    : '',
                          ),
                          readOnly: _isEditMode,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter box index';
                            }
                            if (!RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(value)) {
                              return 'Only letters, numbers, hyphens, and underscores allowed';
                            }
                            return null;
                          },
                          onChanged: _isEditMode
                              ? null
                              : (value) => _updateBoxNumberPreview(),
                        ),
                        SizedBox(height: 20),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Box Description *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        Row(
                          children: [
                            // Date received (disabled in edit mode)
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                decoration: InputDecoration(
                                  labelText: 'Date Received *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                readOnly: true,
                                onTap: _isEditMode
                                    ? null
                                    : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            _dateController.text =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(date);
                                          });
                                        }
                                      },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a date';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16),

                            // Retention years
                            Expanded(
                              child: TextFormField(
                                controller: _retentionController,
                                decoration: InputDecoration(
                                  labelText: 'Retention Years',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.schedule),
                                  suffixText: 'years',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter retention years';
                                  }
                                  final years = int.tryParse(value);
                                  if (years == null || years <= 0) {
                                    return 'Enter valid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Standard retention: 7 years (financial), 10 years (legal), 3 years (marketing)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),

                        SizedBox(height: 20),

                        // Storage Location Selection
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Storage Location (Optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (_loadingLocations)
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                        'Loading available storage locations...'),
                                  ],
                                ),
                              )
                            else if (_locationError.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                'Error loading locations')),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _locationError,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.red),
                                    ),
                                  ],
                                ),
                              )
                            else if (_availableLocations.isEmpty)
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber,
                                            color: Colors.orange, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                            child:
                                                Text('No Available Locations')),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'All storage locations are currently assigned.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade800),
                                    ),
                                    if (_isEditMode &&
                                        widget.box?.rackingLabel != null)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 8),
                                          Text(
                                            'Current location: ${widget.box!.rackingLabel!.labelCode}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.location_on,
                                          color: Colors.green.shade700),
                                      title: DropdownButton<int?>(
                                        value: _selectedRackingLabelId,
                                        isExpanded: true,
                                        underline: SizedBox(),
                                        hint:
                                            Text('Select location (optional)'),
                                        items: [
                                          DropdownMenuItem(
                                            value: null,
                                            child: Text(
                                                'No location (assign later)'),
                                          ),
                                          ..._availableLocations
                                              .map((location) {
                                            return DropdownMenuItem(
                                              value: location.labelId,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        location.labelCode,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                      ),
                                                      SizedBox(width: 8),
                                                      if (location.isAvailable)
                                                        Chip(
                                                          label: Text(
                                                              'Available',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      10)),
                                                          backgroundColor:
                                                              Colors.green
                                                                  .shade100,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      4),
                                                        )
                                                      else
                                                        Chip(
                                                          label: Text('In Use',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      10)),
                                                          backgroundColor:
                                                              Colors.orange
                                                                  .shade100,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      4),
                                                        ),
                                                    ],
                                                  ),
                                                  Text(
                                                    location
                                                        .locationDescription,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedRackingLabelId = value;
                                          });
                                        },
                                      ),
                                    ),
                                    Divider(height: 1),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      color: Colors.grey.shade50,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_availableLocations.length} locations',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.refresh, size: 18),
                                            onPressed: _loadAvailableLocations,
                                            tooltip: 'Refresh locations',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: 30),

                        // Summary Card
                        if (_boxNumberPreview.isNotEmpty ||
                            _descriptionController.text.isNotEmpty ||
                            _dateController.text.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Summary',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 12),
                                if (_boxNumberPreview.isNotEmpty)
                                  _buildSummaryRow(
                                      'Box Number:', _boxNumberPreview),
                                if (_selectedClientId != null)
                                  _buildSummaryRow(
                                      'Client:',
                                      boxController.clients
                                          .firstWhere(
                                              (c) =>
                                                  c.clientId ==
                                                  _selectedClientId,
                                              orElse: () => ClientModel(
                                                    clientId: 0,
                                                    clientName: 'Unknown',
                                                    clientCode: 'N/A',
                                                    contactPerson: '',
                                                    isActive: false,
                                                    createdAt: DateTime.now(),
                                                    updatedAt: DateTime.now(),
                                                  ))
                                          .clientName),
                                if (_descriptionController.text.isNotEmpty)
                                  _buildSummaryRow('Description:',
                                      _descriptionController.text),
                                if (_dateController.text.isNotEmpty)
                                  _buildSummaryRow(
                                      'Date Received:', _dateController.text),
                                if (_retentionController.text.isNotEmpty)
                                  _buildSummaryRow('Retention Years:',
                                      '${_retentionController.text} years'),
                                if (_selectedRackingLabelId != null)
                                  _buildSummaryRow(
                                      'Location:',
                                      _availableLocations
                                          .firstWhere(
                                              (l) =>
                                                  l.labelId ==
                                                  _selectedRackingLabelId,
                                              orElse: () => RackingLabelModel(
                                                    labelId: 0,
                                                    labelCode: 'N/A',
                                                    locationDescription:
                                                        'Not found',
                                                    isAvailable: false,
                                                    boxesCount: 0,
                                                    createdAt: DateTime.now(),
                                                    updatedAt: DateTime.now(),
                                                  ))
                                          .locationDescription),
                              ],
                            ),
                          ),

                        SizedBox(height: 30),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEditMode
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Obx(() {
                                  if (boxController.isLoading.value) {
                                    return SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    );
                                  }
                                  return Text(_isEditMode
                                      ? 'Update Box'
                                      : 'Create Box');
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (!_isEditMode && _selectedClientId == null) {
        Get.snackbar(
          'Error',
          'Please select a client',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (!_isEditMode && _boxIndexController.text.trim().isEmpty) {
        Get.snackbar(
          'Error',
          'Please enter box index',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (!_isEditMode) {
        // Create mode: Get client code for validation
        final clientCode = boxController.getClientCode(_selectedClientId!);
        if (clientCode == null || clientCode.isEmpty) {
          Get.snackbar(
            'Error',
            'Could not retrieve client code',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        // Create the request
        final request = CreateBoxRequest(
          clientId: _selectedClientId!,
          boxIndex: _boxIndexController.text.trim(),
          rackingLabelId: _selectedRackingLabelId,
          boxDescription: _descriptionController.text,
          dateReceived: _dateController.text,
          retentionYears: int.parse(_retentionController.text),
        );

        final success = await boxController.createBox(request);
        if (success) {
          Navigator.pop(context);
        }
      } else {
        // Edit mode
        final request = UpdateBoxRequest(
          boxDescription: _descriptionController.text,
          rackingLabelId: _selectedRackingLabelId,
          retentionYears: int.parse(_retentionController.text),
        );

        final success =
            await boxController.updateBox(widget.box!.boxId, request);
        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }
}