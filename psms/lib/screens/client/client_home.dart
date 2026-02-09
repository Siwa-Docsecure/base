import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final user = authController.currentUser.value;
          return Text(user?.clientName ?? 'Client Dashboard');
        }),
        backgroundColor: Colors.green[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await authController.getProfile();
              Get.snackbar(
                'Success',
                'Profile refreshed',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Get.defaultDialog(
                title: 'Logout',
                content: const Text('Are you sure you want to logout?'),
                confirm: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    await authController.logout();
                  },
                  child: const Text('Yes'),
                ),
                cancel: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('No'),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Obx(() {
              final user = authController.currentUser.value;
              return UserAccountsDrawerHeader(
                accountName: Text(user?.username ?? 'Client User'),
                accountEmail: Text(user?.email ?? 'client@example.com'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.username?.substring(0, 1).toUpperCase() ?? 'C',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.green[800],
                ),
              );
            }),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Get.back();
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('My Boxes'),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Info',
                  'View your boxes',
                  backgroundColor: Colors.green,
                );
              },
            ),
            if (authController.hasPermission('canViewReports'))
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Reports'),
                onTap: () {
                  Get.back();
                  Get.snackbar(
                    'Info',
                    'View reports',
                    backgroundColor: Colors.green,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Activity History'),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Info',
                  'View activity history',
                  backgroundColor: Colors.green,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('My Account'),
              onTap: () {
                Get.back();
                _showAccountDialog(context, authController);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Info',
                  'Settings feature',
                  backgroundColor: Colors.green,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Info',
                  'Help & Support feature',
                  backgroundColor: Colors.green,
                );
              },
            ),
          ],
        ),
      ),
      body: Obx(() {
        final user = authController.currentUser.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.green[100],
                            child: Icon(
                              Icons.business,
                              size: 30,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.clientName ?? 'Client Company',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Client Code: ${user?.clientCode ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Welcome, ${user?.username ?? 'User'}!',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Quick Stats
              Text(
                'Quick Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard(
                    context,
                    Icons.inventory,
                    'Total Boxes',
                    '42',
                    Colors.blue,
                  ),
                  _buildStatCard(
                    context,
                    Icons.storage,
                    'In Storage',
                    '38',
                    Colors.green,
                  ),
                  _buildStatCard(
                    context,
                    Icons.local_shipping,
                    'In Transit',
                    '4',
                    Colors.orange,
                  ),
                  _buildStatCard(
                    context,
                    Icons.access_time,
                    'Pending Actions',
                    '3',
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildActionChip(
                    context,
                    Icons.search,
                    'Search Box',
                    () => Get.snackbar('Info', 'Search Box feature'),
                  ),
                  _buildActionChip(
                    context,
                    Icons.add,
                    'Request Box',
                    () => Get.snackbar('Info', 'Request Box feature'),
                  ),
                  _buildActionChip(
                    context,
                    Icons.download,
                    'Retrieve Box',
                    () => Get.snackbar('Info', 'Retrieve Box feature'),
                  ),
                  if (authController.hasPermission('canViewReports'))
                    _buildActionChip(
                      context,
                      Icons.analytics,
                      'View Report',
                      () => Get.snackbar('Info', 'View Report feature'),
                    ),
                  _buildActionChip(
                    context,
                    Icons.contact_support,
                    'Contact Support',
                    () => Get.snackbar('Info', 'Contact Support feature'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent Activity
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history),
                          const SizedBox(width: 10),
                          Text(
                            'Recent Activity',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildActivityItem('Box #1234 retrieved', '2 hours ago'),
                      _buildActivityItem('Delivery scheduled', 'Yesterday'),
                      _buildActivityItem('New box stored', '2 days ago'),
                      _buildActivityItem('Monthly report generated', '1 week ago'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.snackbar(
            'Info',
            'Create new request',
            backgroundColor: Colors.green,
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.green[50],
      labelStyle: TextStyle(color: Colors.green[800]),
    );
  }

  Widget _buildActivityItem(String activity, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(activity),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountDialog(BuildContext context, AuthController authController) {
    final user = authController.currentUser.value;
    Get.defaultDialog(
      title: 'Account Details',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountDetail('Username', user?.username),
            _buildAccountDetail('Email', user?.email),
            _buildAccountDetail('Role', user?.role),
            if (user?.clientName != null) _buildAccountDetail('Client', user?.clientName),
            if (user?.clientCode != null) _buildAccountDetail('Client Code', user?.clientCode),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _showChangePasswordDialog();
              },
              icon: const Icon(Icons.lock),
              label: const Text('Change Password'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildAccountDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Get.defaultDialog(
      title: 'Change Password',
      content: Column(
        children: [
          TextField(
            controller: currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () async {
          if (newPasswordController.text != confirmPasswordController.text) {
            Get.snackbar(
              'Error',
              'New passwords do not match',
              backgroundColor: Colors.red,
            );
            return;
          }

          final success = await Get.find<AuthController>().changePassword(
            currentPasswordController.text,
            newPasswordController.text,
          );

          if (success) {
            Get.back();
          }
        },
        child: const Text('Change Password'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}