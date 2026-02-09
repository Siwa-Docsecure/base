// lib/screens/warehouse/clients/widgets/client_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/models/client_model.dart';

class ClientFormDialog extends StatefulWidget {
  final ClientModel? client; // null for create, populated for edit
  
  const ClientFormDialog({
    Key? key,
    this.client,
  }) : super(key: key);

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ClientManagementController _controller = Get.find<ClientManagementController>();
  
  late TextEditingController _clientNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _clientNameController = TextEditingController(text: widget.client?.clientName ?? '');
    _contactPersonController = TextEditingController(text: widget.client?.contactPerson ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _addressController = TextEditingController(text: widget.client?.address ?? '');
  }
  
  @override
  void dispose() {
    _clientNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  bool get _isEditMode => widget.client != null;
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    final clientData = {
      'clientName': _clientNameController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    };
    
    bool success;
    if (_isEditMode) {
      success = await _controller.updateClient(widget.client!.clientId, clientData);
    } else {
      success = await _controller.createClient(clientData);
    }
    
    setState(() => _isSubmitting = false);
    
    if (success) {
      Get.back();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.medium,
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: AppEdgeInsets.allLarge,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Name (Required)
                      _buildTextField(
                        controller: _clientNameController,
                        label: 'Client Name',
                        hint: 'Enter company name',
                        icon: Icons.business,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Client name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Client name must be at least 2 characters';
                          }
                          if (value.trim().length > 100) {
                            return 'Client name must not exceed 100 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contact Person (Required)
                      _buildTextField(
                        controller: _contactPersonController,
                        label: 'Contact Person',
                        hint: 'Enter contact person name',
                        icon: Icons.person,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Contact person is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Contact person must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Email (Optional but validated)
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter email address',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Phone (Optional but validated)
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone',
                        hint: 'Enter phone number (e.g., +268-7612-3456)',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final phoneRegex = RegExp(r'^\+?[0-9\s\-()]+$');
                            if (!phoneRegex.hasMatch(value.trim())) {
                              return 'Enter a valid phone number';
                            }
                            if (value.trim().length < 8) {
                              return 'Phone number must be at least 8 characters';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Address (Optional)
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        hint: 'Enter physical address',
                        icon: Icons.location_on,
                        maxLines: 3,
                      ),
                      
                      // Info Box
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: AppBorderRadius.small,
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fields marked with * are required. Email and phone are optional but recommended.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer Actions
            _buildFooter(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: AppEdgeInsets.allMedium,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusMedium),
          topRight: Radius.circular(AppSizes.radiusMedium),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditMode ? Icons.edit : Icons.add_business,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Edit Client' : 'Add New Client',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_isEditMode)
                  Text(
                    widget.client!.clientCode,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _isSubmitting ? null : () => Get.back(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.small,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.small,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.small,
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.small,
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.small,
              borderSide: const BorderSide(color: AppColors.danger, width: 2),
            ),
            filled: true,
            fillColor: _isSubmitting 
                ? AppColors.background 
                : Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFooter() {
    return Container(
      padding: AppEdgeInsets.allMedium,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel Button
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => Get.back(),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMedium,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
          
          // Save/Update Button
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _isEditMode ? Icons.save : Icons.add,
                    size: 18,
                  ),
            label: Text(
              _isSubmitting 
                  ? 'Saving...' 
                  : (_isEditMode ? 'Update Client' : 'Create Client'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEditMode ? AppColors.warning : AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.small,
              ),
              elevation: _isSubmitting ? 0 : 2,
            ),
          ),
        ],
      ),
    );
  }
}