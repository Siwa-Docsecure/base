// box_management_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/models/box_model.dart';
import 'package:psms/models/client_model.dart';
import 'package:psms/models/racking_label_model.dart';

class BoxManagementScreen extends StatefulWidget {
  const BoxManagementScreen({super.key});

  @override
  State<BoxManagementScreen> createState() => _BoxManagementScreenState();
}

class _BoxManagementScreenState extends State<BoxManagementScreen>
    with SingleTickerProviderStateMixin {
  final BoxController boxController = Get.put(BoxController());
  final AuthController authController = Get.find<AuthController>();
  final StorageController storageController = Get.put(StorageController());

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // View mode: 0 = Table, 1 = Grid
  int _viewMode = 0;

  // Filter variables
  String _selectedStatus = 'all';
  int? _selectedClientId;
  bool _showPendingOnly = false;
  bool _showFilters = false;

  // Selection for bulk operations
  final Set<int> _selectedBoxes = <int>{};
  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      boxController.initialize();
      storageController.initialize();
    });

    // Setup scroll listener for infinite scrolling
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (boxController.currentPage.value < boxController.totalPages.value) {
          boxController.loadNextPage();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.2),
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _isSelectMode ? _buildBulkActionBar() : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.95),
      centerTitle: false,
      title: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Box Management',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              Text(
                '${boxController.totalBoxes.value} boxes',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w100,
                  fontSize: 12,
                ),
              ),
            ],
          )),
      actions: _buildAppBarActions(),
      bottom: _buildTabBar(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      // Search
      IconButton(
        icon: Icon(Icons.search, color: Color(0xFF2C3E50)),
        onPressed: () => _showSearchDialog(),
      ),
      // Filter
      IconButton(
        icon: Icon(
          _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _showFilters = !_showFilters;
          });
        },
      ),
      // View mode toggle
      IconButton(
        icon: Icon(
          _viewMode == 0 ? Icons.grid_view : Icons.table_chart,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _viewMode = _viewMode == 0 ? 1 : 0;
          });
        },
      ),
      // Select mode
      IconButton(
        icon: Icon(
          _isSelectMode ? Icons.deselect : Icons.select_all,
          color: Color(0xFF2C3E50),
        ),
        onPressed: () {
          setState(() {
            _isSelectMode = !_isSelectMode;
            if (!_isSelectMode) {
              _selectedBoxes.clear();
            }
          });
        },
      ),
      // Refresh
      IconButton(
        icon: Icon(Icons.refresh, color: Color(0xFF2C3E50)),
        onPressed: () {
          boxController.initialize();
          storageController.initialize();
        },
      ),
      // More options
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Color(0xFF2C3E50)),
        onSelected: (value) => _handleAppBarAction(value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.download, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Export Data'),
            ),
          ),
          PopupMenuItem(
            value: 'print',
            child: ListTile(
              leading: Icon(Icons.print, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Print Report'),
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings, size: 20, color: Color(0xFF2C3E50)),
              title: Text('Settings'),
            ),
          ),
        ],
      ),
    ];
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Color(0xFF2C3E50),
      unselectedLabelColor: Color(0xFF2C3E50).withOpacity(0.6),
      indicatorColor: Color(0xFF3498DB),
      indicatorWeight: 3,
      tabs: [
        Tab(icon: Icon(Icons.all_inbox), text: 'All Boxes'),
        Tab(icon: Icon(Icons.storage), text: 'In Storage'),
        Tab(icon: Icon(Icons.move_to_inbox), text: 'Retrieved'),
        Tab(icon: Icon(Icons.warning), text: 'Pending Destruction'),
      ],
      onTap: (index) {
        // Apply filters based on tab
        switch (index) {
          case 0:
            _applyFilter(status: 'all');
            break;
          case 1:
            _applyFilter(status: 'stored');
            break;
          case 2:
            _applyFilter(status: 'retrieved');
            break;
          case 3:
            _applyFilter(status: 'all', pendingOnly: true);
            break;
        }
      },
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Filter panel
        if (_showFilters) _buildFilterPanel(),

        // Main content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContentView(),
              _buildContentView(),
              _buildContentView(),
              _buildPendingDestructionView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'stored', child: Text('Stored')),
                    DropdownMenuItem(
                        value: 'retrieved', child: Text('Retrieved')),
                    DropdownMenuItem(
                        value: 'destroyed', child: Text('Destroyed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                      _applyFilter();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Client filter
              Expanded(
                child: Obx(() => DropdownButtonFormField<int?>(
                      value: _selectedClientId,
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text('All Clients')),
                        ...boxController.clients.map((client) {
                          return DropdownMenuItem(
                            value: client.clientId,
                            child: Text(
                                '${client.clientCode} - ${client.clientName}'),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClientId = value;
                          _applyFilter();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // Pending destruction filter
              Checkbox(
                value: _showPendingOnly,
                onChanged: (value) {
                  setState(() {
                    _showPendingOnly = value ?? false;
                    _applyFilter();
                  });
                },
              ),
              Text('Show only pending destruction'),

              Spacer(),

              // Clear filters
              OutlinedButton(
                onPressed: () => _clearFilters(),
                child: Text('Clear Filters'),
              ),
              SizedBox(width: 8),

              // Apply filters
              ElevatedButton(
                onPressed: () => _applyFilter(),
                child: Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    return Obx(() {
      if (boxController.isLoading.value && boxController.boxes.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }

      if (boxController.boxes.isEmpty) {
        return _buildEmptyState();
      }

      if (_viewMode == 0) {
        return _buildTableView();
      } else {
        return _buildGridView();
      }
    });
  }

  Widget _buildTableView() {
    return RefreshIndicator(
      onRefresh: () async {
        await boxController.getAllBoxes();
      },
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          children: [
            // Table header
            _buildTableHeader(),

            // Table rows
            ...boxController.boxes.map((box) => _buildTableRow(box)).toList(),

            // Loading more indicator
            if (boxController.isLoading.value && boxController.boxes.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
                  ),
                ),
              ),

            // End of list
            if (boxController.currentPage.value >=
                boxController.totalPages.value)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'End of list',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_isSelectMode)
            Container(
              width: 50,
              child: Checkbox(
                value: _selectedBoxes.length == boxController.boxes.length,
                onChanged: (value) {
                  if (value == true) {
                    _selectedBoxes.addAll(
                      boxController.boxes.map((box) => box.boxId).toSet(),
                    );
                  } else {
                    _selectedBoxes.clear();
                  }
                  setState(() {});
                },
              ),
            ),
          Expanded(
            flex: 1,
            child: Text(
              'Box Number',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Client',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Location',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Color(0xFF3498DB).withOpacity(0.1)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Color(0xFF3498DB) : Colors.grey.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectMode) {
              setState(() {
                if (isSelected) {
                  _selectedBoxes.remove(box.boxId);
                } else {
                  _selectedBoxes.add(box.boxId);
                }
              });
            } else {
              _showBoxDetails(box);
            }
          },
          onLongPress: () {
            setState(() {
              _isSelectMode = true;
              _selectedBoxes.add(box.boxId);
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isSelectMode)
                  Container(
                    width: 50,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Color(0xFF3498DB),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedBoxes.add(box.boxId);
                          } else {
                            _selectedBoxes.remove(box.boxId);
                          }
                        });
                      },
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        box.boxNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF3498DB),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(box.dateReceived),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    box.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        box.client.clientCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        box.client.clientName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(box.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(box.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(box.status),
                          size: 14,
                          color: _getStatusColor(box.status),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            box.statusDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(box.status),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    box.rackingLabel?.location ?? 'Not Assigned',
                    style: TextStyle(
                      fontSize: 13,
                      color: box.rackingLabel != null
                          ? Colors.grey[700]
                          : Colors.grey[500],
                      fontWeight: box.rackingLabel != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildActionButtons(box),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BoxModel box) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.visibility, size: 20),
          color: Color(0xFF3498DB),
          onPressed: () => _showBoxDetails(box),
          tooltip: 'View Details',
        ),
        if (authController.hasPermission('canEditBoxes'))
          IconButton(
            icon: Icon(Icons.edit, size: 20),
            color: Color(0xFF3498DB),
            onPressed: () => _editBox(box),
            tooltip: 'Edit',
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: Color(0xFF2C3E50)),
          itemBuilder: (context) => _buildBoxMenuItems(box),
          onSelected: (value) => _handleBoxAction(value, box),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return RefreshIndicator(
      onRefresh: () async {
        await boxController.getAllBoxes();
      },
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 1200
              ? 4
              : MediaQuery.of(context).size.width > 800
                  ? 3
                  : 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
        ),
        padding: EdgeInsets.all(8),
        itemCount: boxController.boxes.length + 1,
        itemBuilder: (context, index) {
          if (index == boxController.boxes.length) {
            if (boxController.isLoading.value) {
              return Center(child: CircularProgressIndicator());
            }
            if (boxController.currentPage.value >=
                boxController.totalPages.value) {
              return Container();
            }
            return Center(child: CircularProgressIndicator());
          }

          final box = boxController.boxes[index];
          return _buildGridCard(box);
        },
      ),
    );
  }

  Widget _buildGridCard(BoxModel box) {
    final isSelected = _selectedBoxes.contains(box.boxId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedBoxes.remove(box.boxId);
              } else {
                _selectedBoxes.add(box.boxId);
              }
            });
          } else {
            _showBoxDetails(box);
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectMode = true;
            _selectedBoxes.add(box.boxId);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status color
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: _getStatusColor(box.status),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),

            // Card content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Box number and checkbox
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            box.boxNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isSelectMode)
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedBoxes.add(box.boxId);
                                } else {
                                  _selectedBoxes.remove(box.boxId);
                                }
                              });
                            },
                          ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Description
                    Text(
                      box.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),

                    SizedBox(height: 12),

                    // Client info
                    Row(
                      children: [
                        Icon(Icons.business, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            box.client.clientCode,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4),

                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            box.rackingLabel?.location ?? 'No Location',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    Spacer(),

                    // Status and date
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(box.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(_getStatusIcon(box.status),
                                  size: 12, color: _getStatusColor(box.status)),
                              SizedBox(width: 4),
                              Text(
                                box.statusDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(box.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        Text(
                          DateFormat('MM/dd/yyyy').format(box.dateReceived),
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDestructionView() {
    return Obx(() {
      final boxes = boxController.pendingDestructionBoxes;

      if (boxes.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'No boxes pending destruction',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'All boxes are up to date',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: boxes.length,
        itemBuilder: (context, index) {
          final box = boxes[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[50],
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text(
                box.boxNumber,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(box.description),
                  SizedBox(height: 4),
                  Text(
                    'Client: ${box.client.clientName}',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Destruction Year: ${box.destructionYear} (${box.destructionYear} years overdue)',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility),
                    onPressed: () => _showBoxDetails(box),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _markAsDestroyed(box),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'No boxes found',
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            'Try adjusting your filters or create a new box',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 20),
          if (authController.hasPermission('canCreateBoxes'))
            ElevatedButton.icon(
              onPressed: () => _showCreateBoxDialog(),
              icon: Icon(Icons.add),
              label: Text('Create New Box'),
            ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateBoxDialog(),
      backgroundColor: Color(0xFF3498DB),
      elevation: 4,
      icon: Icon(Icons.add, color: Colors.white),
      label: Text(
        'New Box',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            '${_selectedBoxes.length} boxes selected',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('stored'),
            icon: Icon(Icons.storage, size: 18),
            label: Text('Mark as Stored'),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('retrieved'),
            icon: Icon(Icons.move_to_inbox, size: 18),
            label: Text('Mark as Retrieved'),
          ),
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus('destroyed'),
            icon: Icon(Icons.delete_forever, size: 18),
            label: Text('Mark as Destroyed'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSelectMode = false;
                _selectedBoxes.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Colors.green;
      case 'retrieved':
        return Colors.blue;
      case 'destroyed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Icons.storage;
      case 'retrieved':
        return Icons.move_to_inbox;
      case 'destroyed':
        return Icons.delete_forever;
      default:
        return Icons.help_outline;
    }
  }

  List<PopupMenuEntry<String>> _buildBoxMenuItems(BoxModel box) {
    final items = <PopupMenuEntry<String>>[];

    items.add(PopupMenuItem(
      value: 'view',
      child: ListTile(
        leading: Icon(Icons.visibility),
        title: Text('View Details'),
      ),
    ));

    if (authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit Box'),
        ),
      ));
    }

    if (box.canBeRetrieved) {
      items.add(PopupMenuItem(
        value: 'retrieve',
        child: ListTile(
          leading: Icon(Icons.move_to_inbox),
          title: Text('Mark as Retrieved'),
        ),
      ));
    }

    if (box.canBeStored) {
      items.add(PopupMenuItem(
        value: 'store',
        child: ListTile(
          leading: Icon(Icons.storage),
          title: Text('Mark as Stored'),
        ),
      ));
    }

    if (box.canBeDestroyed && authController.hasPermission('canEditBoxes')) {
      items.add(PopupMenuItem(
        value: 'destroy',
        child: ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.red),
          title: Text('Mark as Destroyed', style: TextStyle(color: Colors.red)),
        ),
      ));
    }

    if (authController.hasPermission('canDeleteBoxes') &&
        box.status != 'destroyed') {
      items.add(PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete Box', style: TextStyle(color: Colors.red)),
        ),
      ));
    }

    items.add(PopupMenuItem(
      value: 'audit',
      child: ListTile(
        leading: Icon(Icons.history),
        title: Text('View Audit Log'),
      ),
    ));

    return items;
  }

  // Action handlers
  void _handleAppBarAction(String action) {
    switch (action) {
      case 'export':
        _exportData();
        break;
      case 'print':
        _printReport();
        break;
      case 'settings':
        _showSettings();
        break;
    }
  }

  void _handleBoxAction(String action, BoxModel box) {
    switch (action) {
      case 'view':
        _showBoxDetails(box);
        break;
      case 'edit':
        _editBox(box);
        break;
      case 'retrieve':
        _changeBoxStatus(box, 'retrieved');
        break;
      case 'store':
        _changeBoxStatus(box, 'stored');
        break;
      case 'destroy':
        _changeBoxStatus(box, 'destroyed');
        break;
      case 'delete':
        _deleteBox(box);
        break;
      case 'audit':
        _showAuditLog(box);
        break;
    }
  }

  // Filter methods
  void _applyFilter({String? status, bool? pendingOnly}) {
    setState(() {
      if (status != null) _selectedStatus = status;
      if (pendingOnly != null) _showPendingOnly = pendingOnly;
    });

    boxController.getAllBoxes(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      clientId: _selectedClientId,
      pendingDestruction: _showPendingOnly,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedClientId = null;
      _showPendingOnly = false;
      _showFilters = false;
    });

    boxController.getAllBoxes();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Boxes'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by box number, description, or client...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              boxController.getAllBoxes(search: _searchController.text);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  // CRUD Operations
  void _showCreateBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BoxDialog();
      },
    );
  }

  void _editBox(BoxModel box) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BoxDialog(box: box);
      },
    );
  }

  void _showBoxDetails(BoxModel box) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: BoxDetailsDialog(box: box),
          ),
        ),
      ),
    );
  }

  void _changeBoxStatus(BoxModel box, String status) {
    Get.defaultDialog(
      title: 'Confirm Status Change',
      content: Text(
          'Change status of ${box.boxNumber} to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxController.changeBoxStatus(box.boxId, status);
      },
    );
  }

  void _markAsDestroyed(BoxModel box) {
    _changeBoxStatus(box, 'destroyed');
  }

  void _deleteBox(BoxModel box) {
    Get.defaultDialog(
      title: 'Delete Box',
      content: Text(
          'Are you sure you want to delete box ${box.boxNumber}? This action cannot be undone.'),
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        await boxController.deleteBox(box.boxId);
      },
    );
  }

  void _bulkUpdateStatus(String status) {
    if (_selectedBoxes.isEmpty) return;

    Get.defaultDialog(
      title: 'Bulk Update Status',
      content: Text(
          'Update ${_selectedBoxes.length} boxes to ${status.capitalizeFirst}?'),
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        await boxController.bulkUpdateBoxStatus(
            _selectedBoxes.toList(), status);
        setState(() {
          _selectedBoxes.clear();
          _isSelectMode = false;
        });
      },
    );
  }

  void _exportData() {
    Get.snackbar(
      'Info',
      'Export feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _printReport() {
    Get.snackbar(
      'Info',
      'Print feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showSettings() {
    Get.snackbar(
      'Info',
      'Settings feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showAuditLog(BoxModel box) {
    Get.snackbar(
      'Info',
      'Audit log feature coming soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }
}

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
                                    ? 'BOX-'
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

// Box Details Dialog - Professional redesign
class BoxDetailsDialog extends StatelessWidget {
  final BoxModel box;
  
  BoxDetailsDialog({super.key, required this.box});
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  backgroundColor: Colors.transparent,
  child: Container(
    width: 700,  // Fixed width
    height: MediaQuery.of(context).size.height * 0.9,  // Fixed height at 80% of screen
    constraints: BoxConstraints(
      minHeight: 600,  // Minimum height
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor(box.status),
                    _getStatusColor(box.status).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(box.status),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box.boxNumber,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            box.statusDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description Card
                    _buildInfoCard(
                      icon: Icons.description,
                      title: 'Description',
                      children: [
                        Text(
                          box.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2C3E50),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Client Information Card
                    _buildInfoCard(
                      icon: Icons.business,
                      title: 'Client Information',
                      children: [
                        _buildDetailRow('Client Code', box.client.clientCode),
                        Divider(height: 16),
                        _buildDetailRow('Client Name', box.client.clientName),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Box Details Card
                    _buildInfoCard(
                      icon: Icons.inventory_2,
                      title: 'Box Information',
                      children: [
                        _buildDetailRow(
                          'Date Received',
                          DateFormat('MMMM dd, yyyy').format(box.dateReceived),
                        ),
                        Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                'Year Received',
                                box.yearReceived.toString(),
                              ),
                            ),
                            Expanded(
                              child: _buildDetailRow(
                                'Retention',
                                '${box.retentionYears} years',
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 16),
                        _buildDetailRow(
                          'Destruction Year',
                          box.destructionYear?.toString() ?? 'N/A',
                        ),
                        
                        // Pending destruction warning
                        if (box.isPendingDestruction) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange, size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pending Destruction',
                                        style: TextStyle(
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'This box is scheduled for destruction',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Location Card (if available)
                    if (box.rackingLabel != null)
                      _buildInfoCard(
                        icon: Icons.location_on,
                        title: 'Storage Location',
                        children: [
                          _buildDetailRow('Label Code', box.rackingLabel!.labelCode),
                          Divider(height: 16),
                          _buildDetailRow('Location', box.rackingLabel!.location),
                        ],
                      )
                    else
                      _buildInfoCard(
                        icon: Icons.location_off,
                        title: 'Storage Location',
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'No location assigned',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    
                    SizedBox(height: 16),
                    
                    // System Information Card
                    _buildInfoCard(
                      icon: Icons.info_outline,
                      title: 'System Information',
                      children: [
                        _buildDetailRow(
                          'Created',
                          DateFormat('MMM dd, yyyy - HH:mm').format(box.createdAt),
                        ),
                        Divider(height: 16),
                        _buildDetailRow(
                          'Last Updated',
                          DateFormat('MMM dd, yyyy - HH:mm').format(box.updatedAt),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // QR Code Card
                    _buildInfoCard(
                      icon: Icons.qr_code,
                      title: 'Quick Access',
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_2, size: 60, color: Color(0xFF3498DB)),
                              SizedBox(height: 12),
                              Text(
                                'Scan QR code for quick access',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                box.boxNumber,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer Actions
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Print label functionality
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFF3498DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.print, color: Color(0xFF3498DB)),
                      label: Text(
                        'Print Label',
                        style: TextStyle(color: Color(0xFF3498DB)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to edit
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3498DB),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.edit, color: Colors.white),
                      label: Text(
                        'Edit Box',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF3498DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Color(0xFF3498DB), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Color(0xFF27AE60);
      case 'retrieved':
        return Color(0xFF3498DB);
      case 'destroyed':
        return Color(0xFFE74C3C);
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'stored':
        return Icons.inventory_2;
      case 'retrieved':
        return Icons.assignment_return;
      case 'destroyed':
        return Icons.delete_forever;
      default:
        return Icons.help_outline;
    }
  }
}