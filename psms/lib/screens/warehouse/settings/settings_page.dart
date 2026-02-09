import 'package:flutter/material.dart';
import 'package:psms/controllers/auth_Controller.dart';

import 'tabs/storage_management_page.dart';
import 'widgets/audits_settings_widget.dart';
import 'widgets/general_settings_widget.dart';
import 'widgets/reports_settings_widget.dart';
import 'widgets/storage_settings_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.1),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        title: Container(
          width: double.infinity,
          alignment: Alignment.centerLeft,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Configure system preferences',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.logout, color: Colors.white),
          //   onPressed: () => widget.authController.logout(),
          //   tooltip: 'Logout',
          // ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: Icon(Icons.storage, color: Colors.white),
              text: 'Storage',
            ),
            Tab(
              icon: Icon(Icons.history, color: Colors.white),
              text: 'Audits',
            ),
            Tab(
              icon: Icon(Icons.analytics, color: Colors.white),
              text: 'Reports',
            ),
            Tab(
              icon: Icon(Icons.tune, color: Colors.white),
              text: 'General',
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.black.withOpacity(0.1),
        child: TabBarView(
          controller: _tabController,
          children: const [
            StorageManagementPage(),
            AuditsSettingsWidget(),
            ReportsSettingsWidget(),
            GeneralSettingsWidget(),
          ],
        ),
      ),
    );
  }
}