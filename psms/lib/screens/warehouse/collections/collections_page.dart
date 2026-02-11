// File: lib/pages/collections/collections_page.dart
// Description: Redesigned collections management page with glassmorphism effects, proper statistics, and signature support

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:psms/constants/api_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/collection_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/collection_model.dart';
import 'package:psms/models/user_model.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final CollectionController _controller = Get.put(CollectionController());
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _boxDescriptionController =
      TextEditingController();

  // Signature controllers
  late SignatureController _dispatcherSignatureController;
  late SignatureController _collectorSignatureController;
  String? _dispatcherSignatureBase64;
  String? _collectorSignatureBase64;

  DateTime? _selectedCollectionDate;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _selectedClientId;
  int? _selectedCollectorUserId;
  bool _showFilters = false;

  // Client users list
  final RxList<UserModel> _clientUsers = <UserModel>[].obs;
  final RxBool _loadingClientUsers = false.obs;

  // Client boxes list (stored boxes only)
  final RxList<BoxModel> _clientStoredBoxes = <BoxModel>[].obs;
  final RxBool _loadingClientBoxes = false.obs;
  final RxList<BoxModel> _selectedBoxes = <BoxModel>[].obs;

  @override
  void initState() {
    super.initState();
    _initializeSignatureControllers();
    _initializePage();
  }

  void _initializeSignatureControllers() {
    _dispatcherSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _collectorSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  Future<void> _initializePage() async {
    await _controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _boxDescriptionController.dispose();
    _dispatcherSignatureController.dispose();
    _collectorSignatureController.dispose();
    super.dispose();
  }

  // ============================================
  // BUILD METHODS
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.2),
      appBar: _buildGlassAppBar(),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.collections.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _controller.getAllCollections();
          },
          color: const Color(0xFF3498DB),
          child: CustomScrollView(
            slivers: [
              // Statistics Cards Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildStatisticsCards(),
                ),
              ),

              // Filters Section
              if (_showFilters)
                SliverToBoxAdapter(child: _buildFiltersSection()),

              // Collections List Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCollectionsList(),
                ),
              ),
            ],
          ),
        );
      }),
      floatingActionButton:
          _controller.canCreateCollections
              ? FloatingActionButton.extended(
                onPressed: () => _showCollectionDialog(),
                backgroundColor: const Color(0xFF3498DB),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'New Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              : null,
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.95),
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collections',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          const Text(
            'Manage warehouse collections efficiently',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w100,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: const Color(0xFF2C3E50),
          ),
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
          tooltip: 'Toggle Filters',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
          onPressed: () async {
            await _controller.getAllCollections();
            _showSuccessSnackbar('Collections refreshed');
          },
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
          onSelected: (value) {
            switch (value) {
              case 'reports':
                _showReportsDialog();
                break;
              case 'export':
                _showExportDialog();
                break;
              case 'statistics':
                _showStatisticsDialog();
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'reports',
                  child: Row(
                    children: [
                      Icon(Icons.summarize, size: 20, color: Color(0xFF2C3E50)),
                      SizedBox(width: 8),
                      Text('View Reports'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'statistics',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, size: 20, color: Color(0xFF2C3E50)),
                      SizedBox(width: 8),
                      Text('Statistics'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20, color: Color(0xFF2C3E50)),
                      SizedBox(width: 8),
                      Text('Export Data'),
                    ],
                  ),
                ),
              ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Obx(() {
      final stats = _controller.collectionStats.value;
      final collections = _controller.collections;

      // Calculate statistics
      final totalCollections = collections.length;
      final totalBoxes = collections.fold<int>(
        0,
        (sum, collection) => sum + collection.totalBoxes,
      );

      // Calculate this month's collections
      final now = DateTime.now();
      final thisMonthCollections =
          collections.where((collection) {
            return collection.collectionDate.year == now.year &&
                collection.collectionDate.month == now.month;
          }).length;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          final isTablet =
              constraints.maxWidth > 600 && constraints.maxWidth <= 900;
          final isMobile = constraints.maxWidth <= 600;

          return Container(
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount:
                  isDesktop
                      ? 4
                      : (isTablet
                          ? 3
                          : 2), // 4 for desktop, 3 for tablet, 2 for mobile
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              padding: const EdgeInsets.all(0),
              childAspectRatio: isDesktop ? 1.2 : (isTablet ? 1.1 : 1.0),
              children: [
                _buildStatCard(
                  title: 'Total Collections',
                  value: totalCollections.toString(),
                  subtitle: 'All time',
                  icon: Icons.inventory_2,
                  color: const Color(0xFF3498DB),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                _buildStatCard(
                  title: 'Total Boxes',
                  value: totalBoxes.toString(),
                  subtitle: 'In collections',
                  icon: Icons.archive,
                  color: const Color(0xFF27AE60),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                _buildStatCard(
                  title: 'This Month',
                  value: thisMonthCollections.toString(),
                  subtitle: 'Collections',
                  icon: Icons.calendar_today,
                  color: const Color(0xFFE67E22),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                _buildStatCard(
                  title: 'Clients',
                  value: _controller.clients.length.toString(),
                  subtitle: 'Active clients',
                  icon: Icons.business,
                  color: const Color(0xFF9B59B6),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDesktop,
    required bool isTablet,
  }) {
    return Container(
      padding:
          isDesktop
              ? const EdgeInsets.all(20)
              : isTablet
              ? const EdgeInsets.all(16)
              : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    isDesktop
                        ? const EdgeInsets.all(12)
                        : isTablet
                        ? const EdgeInsets.all(10)
                        : const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isDesktop ? 24 : (isTablet ? 22 : 20),
                ),
              ),
              if (isDesktop || isTablet) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isDesktop && !isTablet) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3498DB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width:
                    MediaQuery.of(context).size.width > 900
                        ? 300
                        : double.infinity,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Search by client or description',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF3498DB),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3498DB)),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
              SizedBox(
                width:
                    MediaQuery.of(context).size.width > 900
                        ? 250
                        : double.infinity,
                child: Obx(
                  () => DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration: InputDecoration(
                      labelText: 'Client',
                      prefixIcon: const Icon(
                        Icons.business,
                        color: Color(0xFF3498DB),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3498DB)),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('All Clients'),
                      ),
                      ..._controller.clients.map((client) {
                        return DropdownMenuItem<int>(
                          value: client.clientId,
                          child: Text(client.clientName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedClientId = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsList() {
    return Obx(() {
      if (_controller.collections.isEmpty) {
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No collections found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first collection to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Boxes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            // List Items
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _controller.collections.length,
              itemBuilder: (context, index) {
                final collection = _controller.collections[index];
                return _buildCollectionListItem(collection);
              },
            ),
            // Pagination
            if (_controller.totalPages.value > 1)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${_controller.currentPage.value} of ${_controller.totalPages.value}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              _controller.currentPage.value > 1
                                  ? () => _controller.loadPreviousPage()
                                  : null,
                          icon: const Icon(Icons.chevron_left),
                          color: const Color(0xFF3498DB),
                        ),
                        IconButton(
                          onPressed:
                              _controller.currentPage.value <
                                      _controller.totalPages.value
                                  ? () => _controller.loadNextPage()
                                  : null,
                          icon: const Icon(Icons.chevron_right),
                          color: const Color(0xFF3498DB),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildCollectionListItem(CollectionModel collection) {
    final clientName = collection.client.clientName;
    final dateStr = DateFormat(
      'MMM dd, yyyy',
    ).format(collection.collectionDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF3498DB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (collection.boxDescription != null &&
                          collection.boxDescription!.isNotEmpty)
                        Text(
                          collection.boxDescription!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateStr,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${collection.totalBoxes}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF27AE60),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed:
                      () => _showCollectionDialog(collection: collection),
                  icon: const Icon(Icons.visibility, size: 20),
                  color: const Color(0xFF3498DB),
                  tooltip: 'View Collection',
                ),
                if (_controller.canEditCollections)
                  IconButton(
                    onPressed:
                        () => _showCollectionDialog(
                          collection: collection,
                          isEditing: true,
                        ),
                    icon: const Icon(Icons.edit, size: 20),
                    color: const Color(0xFFE67E22),
                    tooltip: 'Edit Collection',
                  ),
                if (_controller.canDeleteCollections)
                  IconButton(
                    onPressed: () => _confirmDeleteCollection(collection),
                    icon: const Icon(Icons.delete, size: 20),
                    color: const Color(0xFFE74C3C),
                    tooltip: 'Delete Collection',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COLLECTION DIALOG (UNIFIED FOR CREATE/VIEW/EDIT)
  // ============================================

  void _showCollectionDialog({
    CollectionModel? collection,
    bool isEditing = false,
  }) {
    // Reset form state
    _selectedClientId = collection?.client.clientId;
    _selectedCollectorUserId = null; // Will be set after loading users
    _selectedCollectionDate = collection?.collectionDate ?? DateTime.now();
    _boxDescriptionController.text = collection?.boxDescription ?? '';
    _dispatcherSignatureBase64 = collection?.dispatcherSignature;
    _collectorSignatureBase64 = collection?.collectorSignature;
    _selectedBoxes.clear();

    // Load client users if client is selected
    if (_selectedClientId != null) {
      _loadClientUsers(_selectedClientId!);
      if (!isEditing && collection == null) {
        _loadClientStoredBoxes(_selectedClientId!);
      }
    }

    final isViewMode = collection != null && !isEditing;
    final isCreateMode = collection == null;
    final isEditMode = collection != null && isEditing;

    showDialog(
      context: context,
      barrierDismissible: !isCreateMode,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            isViewMode
                                ? 'View Collection'
                                : isEditMode
                                ? 'Edit Collection'
                                : 'New Collection',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Client Selection
                          _buildSectionTitle('Client Information'),
                          const SizedBox(height: 12),
                          Obx(
                            () => DropdownButtonFormField<int>(
                              value: _selectedClientId,
                              decoration: _buildInputDecoration(
                                label: 'Client',
                                icon: Icons.business,
                              ),
                              items:
                                  _controller.clients.map((client) {
                                    return DropdownMenuItem<int>(
                                      value: client.clientId,
                                      child: Text(client.clientName),
                                    );
                                  }).toList(),
                              onChanged:
                                  isViewMode
                                      ? null
                                      : (value) {
                                        setState(() {
                                          _selectedClientId = value;
                                          _selectedCollectorUserId = null;
                                          _selectedBoxes.clear();
                                        });
                                        if (value != null) {
                                          _loadClientUsers(value);
                                          _loadClientStoredBoxes(value);
                                        }
                                      },
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Please select a client'
                                          : null,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Collector Selection
                          Obx(() {
                            if (_loadingClientUsers.value) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            // If viewing an existing collection, try to find the collector by name
                            if (collection != null &&
                                _selectedCollectorUserId == null &&
                                _clientUsers.isNotEmpty) {
                              try {
                                final matchingUser = _clientUsers.firstWhere(
                                  (user) =>
                                      user.username == collection.collectorName,
                                  orElse: () => _clientUsers.first,
                                );
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  setState(() {
                                    _selectedCollectorUserId =
                                        matchingUser.userId;
                                  });
                                });
                              } catch (e) {
                                // If no matching user found, just show dropdown
                              }
                            }

                            // In view mode, just show the collector name
                            if (isViewMode && collection != null) {
                              return InputDecorator(
                                decoration: _buildInputDecoration(
                                  label: 'Collector',
                                  icon: Icons.person,
                                ),
                                child: Text(
                                  collection.collectorName,
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              );
                            }

                            return DropdownButtonFormField<int>(
                              value: _selectedCollectorUserId,
                              decoration: _buildInputDecoration(
                                label: 'Collector',
                                icon: Icons.person,
                              ),
                              items:
                                  _clientUsers.map((user) {
                                    return DropdownMenuItem<int>(
                                      value: user.userId,
                                      child: Text(user.username),
                                    );
                                  }).toList(),
                              onChanged:
                                  isViewMode
                                      ? null
                                      : (value) {
                                        setState(() {
                                          _selectedCollectorUserId = value;
                                        });
                                      },
                            );
                          }),

                          const SizedBox(height: 16),

                          // Dispatcher Name (View Mode Only)
                          if (isViewMode && collection != null)
                            Column(
                              children: [
                                InputDecorator(
                                  decoration: _buildInputDecoration(
                                    label: 'Dispatcher',
                                    icon: Icons.local_shipping,
                                  ),
                                  child: Text(
                                    collection.dispatcherName,
                                    style: const TextStyle(
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Collection Date
                          InkWell(
                            onTap:
                                isViewMode
                                    ? null
                                    : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _selectedCollectionDate ??
                                            DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 1),
                                        ),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                    primary: Color(0xFF3498DB),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (date != null && mounted) {
                                        setState(() {
                                          _selectedCollectionDate = date;
                                        });
                                      }
                                    },
                            child: InputDecorator(
                              decoration: _buildInputDecoration(
                                label: 'Collection Date',
                                icon: Icons.calendar_today,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCollectionDate != null
                                        ? DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(_selectedCollectionDate!)
                                        : 'Select date',
                                    style: TextStyle(
                                      color:
                                          _selectedCollectionDate != null
                                              ? const Color(0xFF2C3E50)
                                              : Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (!isViewMode)
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey[400],
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Description
                          TextField(
                            controller: _boxDescriptionController,
                            enabled: !isViewMode,
                            decoration: _buildInputDecoration(
                              label:
                                  isViewMode
                                      ? 'Description'
                                      : 'Additional Notes (Optional)',
                              icon: Icons.notes,
                            ),
                            maxLines: 3,
                          ),

                          const SizedBox(height: 16),

                          // Total Boxes (View Mode Only)
                          if (isViewMode && collection != null)
                            Column(
                              children: [
                                InputDecorator(
                                  decoration: _buildInputDecoration(
                                    label: 'Total Boxes',
                                    icon: Icons.inventory,
                                  ),
                                  child: Text(
                                    '${collection.totalBoxes}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C3E50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Boxes Selection (Only for new collections)
                          if (isCreateMode) ...[
                            const SizedBox(height: 24),
                            _buildSectionTitle('Select Boxes'),
                            const SizedBox(height: 12),
                            Obx(() {
                              if (_loadingClientBoxes.value) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (_clientStoredBoxes.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _selectedClientId == null
                                          ? 'Select a client to view available boxes'
                                          : 'No stored boxes available for this client',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _clientStoredBoxes.length,
                                  itemBuilder: (context, index) {
                                    final box = _clientStoredBoxes[index];
                                    return Obx(
                                      () => CheckboxListTile(
                                        value: _isBoxSelected(box),
                                        onChanged: (value) {
                                          _toggleBoxSelection(box);
                                        },
                                        title: Text(
                                          box.boxNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          box.description ?? 'No description',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        activeColor: const Color(0xFF3498DB),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                          ],

                          // Signatures Section
                          _buildSectionTitle('Signatures'),
                          const SizedBox(height: 12),

                          // Dispatcher Signature (Required for creation)
                          _buildSignatureSection(
                            title:
                                'Dispatcher Signature ${isCreateMode ? '(Required)' : ''}',
                            signatureBase64: _dispatcherSignatureBase64,
                            isViewMode: isViewMode,
                            onCapture: () async {
                              await _captureSignature(
                                context,
                                'Dispatcher Signature',
                                _dispatcherSignatureController,
                                (base64) {
                                  setState(() {
                                    _dispatcherSignatureBase64 = base64;
                                  });
                                },
                              );
                            },
                            onClear: () {
                              setState(() {
                                _dispatcherSignatureBase64 = null;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Collector Signature (Optional)
                          _buildSignatureSection(
                            title: 'Collector Signature (Optional)',
                            signatureBase64: _collectorSignatureBase64,
                            isViewMode: isViewMode,
                            onCapture: () async {
                              await _captureSignature(
                                context,
                                'Collector Signature',
                                _collectorSignatureController,
                                (base64) {
                                  setState(() {
                                    _collectorSignatureBase64 = base64;
                                  });
                                },
                              );
                            },
                            onClear: () {
                              setState(() {
                                _collectorSignatureBase64 = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Actions
                  if (!isViewMode)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF3498DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF3498DB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => _handleSaveCollection(collection),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3498DB),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                isEditMode ? 'Update' : 'Create Collection',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2C3E50),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF3498DB)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3498DB)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSignatureSection({
    required String title,
    required String? signatureBase64,
    required bool isViewMode,
    required VoidCallback onCapture,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: signatureBase64 != null ? Colors.white : Colors.grey[50],
          ),
          child: _buildSignatureImage(signatureBase64),
        ),
        if (!isViewMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.draw, size: 18),
                  label: Text(signatureBase64 != null ? 'Change' : 'Capture'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3498DB),
                    side: const BorderSide(color: Color(0xFF3498DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (signatureBase64 != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE74C3C),
                    side: const BorderSide(color: Color(0xFFE74C3C)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureImage(String? signatureBase64) {
    if (signatureBase64 == null || signatureBase64.isEmpty) {
      return Center(
        child: Text(
          'No signature',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }

    try {
      // Clean the base64 string - remove any data URI prefix
      String cleanBase64 = signatureBase64;

      // If it's a data URI (contains "data:image" and "base64,")
      if (cleanBase64.contains('data:image') &&
          cleanBase64.contains('base64,')) {
        // Extract the base64 part after "base64,"
        cleanBase64 = cleanBase64.split('base64,').last;
      }

      // Remove any whitespace characters
      cleanBase64 = cleanBase64.trim();

      // Decode the base64 string
      final bytes = base64Decode(cleanBase64);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'Invalid signature image',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Format: ${error.toString().split(':').first}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      // Show detailed error for debugging
      debugPrint('Error decoding signature: $e');
      debugPrint(
        'Signature base64 (first 100 chars): ${signatureBase64.substring(0, signatureBase64.length > 100 ? 100 : signatureBase64.length)}...',
      );

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Failed to load signature',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Error: ${e.toString()}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Future<void> _captureSignature(
    BuildContext context,
    String title,
    SignatureController controller,
    Function(String) onSave,
  ) async {
    controller.clear();

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.draw, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Signature Pad
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Signature(
                              controller: controller,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                controller.clear();
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Clear'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (controller.isEmpty) {
                                  _showErrorSnackbar(
                                    'Please provide a signature',
                                  );
                                  return;
                                }
                                final signature = await controller.toPngBytes();
                                if (signature != null) {
                                  final base64 = base64Encode(signature);
                                  Navigator.pop(context, base64);
                                }
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3498DB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    if (result != null) {
      onSave(result);
    }
  }

  Future<void> _handleSaveCollection(
    CollectionModel? existingCollection,
  ) async {
    // Validation
    if (_selectedClientId == null) {
      _showErrorSnackbar('Please select a client');
      return;
    }

    if (_selectedCollectionDate == null) {
      _showErrorSnackbar('Please select a collection date');
      return;
    }

    if (_selectedCollectorUserId == null) {
      _showErrorSnackbar('Please select a collector');
      return;
    }

    if (existingCollection == null && _selectedBoxes.isEmpty) {
      _showErrorSnackbar('Please select at least one box');
      return;
    }

    // Require dispatcher signature for new collections
    if (existingCollection == null && _dispatcherSignatureBase64 == null) {
      _showErrorSnackbar('Dispatcher signature is required');
      return;
    }

    try {
      // Get dispatcher name from current user
      final dispatcherName =
          _authController.currentUser.value?.username ?? 'Unknown';

      // Get collector name from selected user
      final collectorUser = _clientUsers.firstWhere(
        (user) => user.userId == _selectedCollectorUserId,
      );
      final collectorName = collectorUser.username;

      if (existingCollection == null) {
        // Create new collection
        // Create box description from selected boxes
        final boxNumbers = _selectedBoxes.map((box) => box.boxNumber).toList();
        final boxDescription =
            'Boxes: ${boxNumbers.join(', ')}${_boxDescriptionController.text.isNotEmpty ? '\nNotes: ${_boxDescriptionController.text}' : ''}';

        final request = CreateCollectionRequest(
          clientId: _selectedClientId!,
          totalBoxes: _selectedBoxes.length,
          boxDescription: boxDescription,
          dispatcherName: dispatcherName,
          collectorName: collectorName,
          collectionDate: DateFormat(
            'yyyy-MM-dd',
          ).format(_selectedCollectionDate!),
          dispatcherSignature: _dispatcherSignatureBase64,
          collectorSignature: _collectorSignatureBase64,
        );

        final result = await _controller.createCollection(request);

        if (!mounted) return;

        if (result) {
          Navigator.pop(context);
          _showSuccessSnackbar(
            'Collection created successfully with ${_selectedBoxes.length} box(es)',
          );
        }
      } else {
        // Update existing collection
        // Use existing box description if user didn't add notes
        final boxDescription =
            _boxDescriptionController.text.isNotEmpty
                ? _boxDescriptionController.text
                : existingCollection.boxDescription;

        final request = UpdateCollectionRequest(
          totalBoxes: existingCollection.totalBoxes,
          boxDescription: boxDescription,
          dispatcherName: dispatcherName,
          collectorName: collectorName,
          collectionDate: DateFormat(
            'yyyy-MM-dd',
          ).format(_selectedCollectionDate!),
          dispatcherSignature: _dispatcherSignatureBase64,
          collectorSignature: _collectorSignatureBase64,
        );

        final result = await _controller.updateCollection(
          existingCollection.collectionId,
          request,
        );

        if (!mounted) return;

        if (result) {
          Navigator.pop(context);
          _showSuccessSnackbar('Collection updated successfully');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error saving collection: $e');
    }
  }

  // ============================================
  // FILTER METHODS
  // ============================================

  void _applyFilters() async {
    await _controller.getAllCollections(
      search: _searchController.text.trim(),
      clientId: _selectedClientId,
      startDate: _filterStartDate?.toIso8601String(),
      endDate: _filterEndDate?.toIso8601String(),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedClientId = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _controller.clearFilters();
    _applyFilters();
  }

  // ============================================
  // DELETE CONFIRMATION
  // ============================================

  void _confirmDeleteCollection(CollectionModel collection) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Collection'),
            content: const Text(
              'Are you sure you want to delete this collection? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await _controller.deleteCollection(
                    collection.collectionId,
                  );
                  if (success) {
                    _showSuccessSnackbar('Collection deleted successfully');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // ============================================
  // REPORTS & STATISTICS DIALOGS
  // ============================================

  void _showReportsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C3E50),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Collection Reports',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildReportOption(
                          icon: Icons.summarize,
                          color: const Color(0xFF3498DB),
                          title: 'Summary Report',
                          subtitle: 'Overall collection statistics',
                          onTap: () {
                            Navigator.pop(context);
                            _generateSummaryReport();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildReportOption(
                          icon: Icons.business,
                          color: const Color(0xFF2ECC71),
                          title: 'By Client Report',
                          subtitle: 'Collections grouped by client',
                          onTap: () {
                            Navigator.pop(context);
                            _generateClientReport();
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildReportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatisticsDialog() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3498DB),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading statistics...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
    );

    // Load statistics
    await _controller.getCollectionStatistics();

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);

    // Show statistics dialog
    final stats = _controller.collectionStats.value;

    if (stats == null) {
      _showErrorSnackbar('Failed to load statistics');
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3498DB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Collection Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatisticRow(
                            'Total Collections',
                            '${stats.totalCollections}',
                            Icons.inventory_2,
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticRow(
                            'Total Boxes Collected',
                            '${stats.totalBoxesCollected}',
                            Icons.widgets,
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticRow(
                            'Clients with Collections',
                            '${stats.clientsWithCollections}',
                            Icons.business,
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticRow(
                            'Collections Today',
                            '${stats.todayCollections}',
                            Icons.today,
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticRow(
                            'Collections This Week',
                            '${stats.thisWeekCollections}',
                            Icons.date_range,
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticRow(
                            'Collections This Month',
                            '${stats.thisMonthCollections}',
                            Icons.calendar_month,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatisticRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF3498DB)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Export Data'),
            content: Text(
              'Export functionality will allow you to download collection data in various formats (CSV, Excel, PDF).',
              style: TextStyle(color: Colors.grey[600]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessSnackbar('Export feature coming soon');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Export'),
              ),
            ],
          ),
    );
  }

  void _generateSummaryReport() async {
    await _controller.getSummaryReport(
      startDate:
          _filterStartDate != null
              ? DateFormat('yyyy-MM-dd').format(_filterStartDate!)
              : null,
      endDate:
          _filterEndDate != null
              ? DateFormat('yyyy-MM-dd').format(_filterEndDate!)
              : null,
      clientId: _selectedClientId,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C3E50),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Summary Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: GetBuilder<CollectionController>(
                        builder: (controller) {
                          if (controller.summaryReport.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                'No data available for the selected period',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                controller.summaryReport.map((summary) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          summary.date,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildReportStat(
                                              'Collections',
                                              '${summary.collectionCount}',
                                            ),
                                            const SizedBox(width: 16),
                                            _buildReportStat(
                                              'Total Boxes',
                                              '${summary.totalBoxes}',
                                            ),
                                            const SizedBox(width: 16),
                                            _buildReportStat(
                                              'Unique Clients',
                                              '${summary.uniqueClients}',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildReportStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498DB),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _generateClientReport() async {
    await _controller.getByClientReport(
      startDate:
          _filterStartDate != null
              ? DateFormat('yyyy-MM-dd').format(_filterStartDate!)
              : null,
      endDate:
          _filterEndDate != null
              ? DateFormat('yyyy-MM-dd').format(_filterEndDate!)
              : null,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C3E50),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.business, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Client Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: GetBuilder<CollectionController>(
                        builder: (controller) {
                          if (controller.clientReport.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                'No data available for the selected period',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                controller.clientReport.map((report) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.clientName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Client Code: ${report.clientCode}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildReportStat(
                                              'Collections',
                                              '${report.collectionCount}',
                                            ),
                                            const SizedBox(width: 16),
                                            _buildReportStat(
                                              'Total Boxes',
                                              '${report.totalBoxesCollected}',
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Last Collection:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  Text(
                                                    report.lastCollectionDate,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF2C3E50),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ============================================
  // CLIENT USERS MANAGEMENT
  // ============================================

  Future<void> _loadClientUsers(int clientId) async {
    try {
      _loadingClientUsers.value = true;
      _clientUsers.clear();
      _selectedCollectorUserId = null;

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.usersByClient(clientId.toString())}',
        ),
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final data = responseData['data'];
          final List<UserModel> userList =
              (data['users'] as List)
                  .map((userJson) => UserModel.fromJson(userJson))
                  .toList();

          _clientUsers.value = userList;
        } else {
          _showErrorSnackbar(
            responseData['message'] ?? 'Failed to load client users',
          );
        }
      } else {
        _showErrorSnackbar('Failed to load client users');
      }
    } catch (e) {
      _showErrorSnackbar('Error loading client users: $e');
    } finally {
      _loadingClientUsers.value = false;
    }
  }

  // ============================================
  // CLIENT BOXES MANAGEMENT
  // ============================================

  Future<void> _loadClientStoredBoxes(int clientId) async {
    try {
      _loadingClientBoxes.value = true;
      _clientStoredBoxes.clear();
      _selectedBoxes.clear();

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.boxes}',
      ).replace(
        queryParameters: {
          'clientId': clientId.toString(),
          'status': 'stored',
          'limit': '1000',
          'page': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: _authController.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final data = responseData['data'];
          final List<BoxModel> boxList =
              (data['boxes'] as List)
                  .map((boxJson) => BoxModel.fromJson(boxJson))
                  .toList();

          _clientStoredBoxes.value = boxList;
        } else {
          _showErrorSnackbar(responseData['message'] ?? 'Failed to load boxes');
        }
      } else {
        _showErrorSnackbar('Failed to load client boxes');
      }
    } catch (e) {
      _showErrorSnackbar('Error loading client boxes: $e');
    } finally {
      _loadingClientBoxes.value = false;
    }
  }

  void _toggleBoxSelection(BoxModel box) {
    final index = _selectedBoxes.indexWhere((b) => b.boxId == box.boxId);
    if (index >= 0) {
      _selectedBoxes.removeAt(index);
    } else {
      _selectedBoxes.add(box);
    }
  }

  bool _isBoxSelected(BoxModel box) {
    return _selectedBoxes.any((b) => b.boxId == box.boxId);
  }

  // ============================================
  // SNACKBAR HELPERS
  // ============================================

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: const Color(0xFF27AE60),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: const Color(0xFFE74C3C),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }
}
