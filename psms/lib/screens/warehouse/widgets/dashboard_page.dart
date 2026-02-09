import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/utils/responsive_helper.dart';

class DashboardPage extends StatelessWidget {
  final AuthController authController;

  const DashboardPage({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        context.responsiveValue(
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(context),
          SizedBox(height: context.responsiveValue(mobile: 16.0, desktop: 24.0)),
          _buildStorageOverview(context),
          SizedBox(height: context.responsiveValue(mobile: 16.0, desktop: 24.0)),
          _buildQuickStats(context),
          SizedBox(height: context.responsiveValue(mobile: 16.0, desktop: 24.0)),
          _buildRecentActivity(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Obx(() {
      final user = authController.currentUser.value;
      final hour = DateTime.now().hour;
      String greeting = 'Good Morning';
      if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
      if (hour >= 17) greeting = 'Good Evening';

      return Container(
        padding: EdgeInsets.all(
          context.responsiveValue(mobile: 16.0, tablet: 20.0, desktop: 24.0),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.dashboard, size: 32, color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '$greeting, ${user?.username ?? 'User'}!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Welcome back to your warehouse dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, ${user?.username ?? 'User'}!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Welcome back to your warehouse dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.dashboard, size: 40, color: Colors.white),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildStorageOverview(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.responsiveValue(mobile: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Overview',
                style: TextStyle(
                  fontSize: context.responsiveValue(mobile: 16.0, desktop: 18.0),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Refresh'),
              ),
            ],
          ),
          SizedBox(height: context.responsiveValue(mobile: 16.0, desktop: 24.0)),
          context.isMobile
              ? Column(
                  children: [
                    _buildCircularProgress(),
                    SizedBox(height: 24),
                    _buildStorageItems(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 2, child: _buildCircularProgress()),
                    SizedBox(width: 32),
                    Expanded(flex: 3, child: _buildStorageItems()),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress() {
    return Center(
      child: SizedBox(
        height: 160,
        width: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 160,
              width: 160,
              child: CircularProgressIndicator(
                value: 0.70,
                strokeWidth: 12,
                backgroundColor: Color(0xFFF5F6FA).withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '70%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  'Used',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF95A5A6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStorageItem('Stored Boxes', '105 boxes', Color(0xFF3498DB), 0.70),
        SizedBox(height: 16),
        _buildStorageItem('Retrieved', '23 boxes', Color(0xFF27AE60), 0.15),
        SizedBox(height: 16),
        _buildStorageItem('Pending Destruction', '8 boxes', Color(0xFFE74C3C), 0.05),
        SizedBox(height: 16),
        _buildStorageItem('Available Space', '45 slots', Color(0xFF95A5A6), 0.30),
      ],
    );
  }

  Widget _buildStorageItem(String label, String value, Color color, double percentage) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(percentage * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF95A5A6),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final crossAxisCount = context.responsiveValue(
      mobile: 1,
      tablet: 2,
      desktop: 4,
    );

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: context.responsiveValue(mobile: 12.0, desktop: 16.0),
      mainAxisSpacing: context.responsiveValue(mobile: 12.0, desktop: 16.0),
      childAspectRatio: context.responsiveValue(mobile: 1.8, tablet: 1.5, desktop: 1.5),
      children: [
        _buildStatCard('Total Boxes', '136', Icons.inventory_2, Color(0xFF3498DB), '+12%'),
        _buildStatCard('Active Clients', '24', Icons.business, Color(0xFF27AE60), '+5%'),
        _buildStatCard('This Month', '18', Icons.calendar_today, Color(0xFFF39C12), '+8%'),
        _buildStatCard('Pending Requests', '7', Icons.pending_actions, Color(0xFFE74C3C), '2 urgent'),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 2),
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
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Color(0xFF95A5A6)),
              ),
              SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.responsiveValue(mobile: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: context.responsiveValue(mobile: 16.0, desktop: 18.0),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildActivityItem('BOX-2024-156', 'Box stored in RACK-A-12', '2 hours ago', Icons.add_box, Color(0xFF3498DB)),
          _buildActivityItem('BOX-2024-143', 'Retrieved by Acme Corp', '5 hours ago', Icons.output, Color(0xFF27AE60)),
          _buildActivityItem('New Collection', '8 boxes from Global Inc.', 'Yesterday', Icons.collections, Color(0xFFF39C12)),
          _buildActivityItem('BOX-2019-089', 'Marked for destruction', '2 days ago', Icons.delete_outline, Color(0xFFE74C3C)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Color(0xFF95A5A6)),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: Color(0xFF95A5A6)),
          ),
        ],
      ),
    );
  }
}