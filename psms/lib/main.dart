import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/controllers/box_controller.dart';
import 'package:psms/controllers/client_management_controller.dart';
import 'package:psms/controllers/collection_controller.dart';
import 'package:psms/controllers/storage_controller.dart';
import 'package:psms/controllers/user_management_controller.dart';
import 'package:psms/screens/warehouse/boxes/box_management_screen.dart';

import 'screens/client/client_home.dart';
import 'screens/login_screen.dart';
import 'screens/warehouse/users/user_management_page.dart';
import 'screens/warehouse/warehouse_home.dart';

void main() async {
  // Initialize GetStorage
  await GetStorage.init();
  
  // Initialize GetX bindings
  Get.put(AuthController());
  Get.put(BoxController());
  Get.put(UserManagementController());
  Get.put(ClientManagementController());
  Get.put(CollectionController());
  Get.put(StorageController());
  
  runApp(const PSMSApp());
}

class PSMSApp extends StatelessWidget {
  const PSMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Physical Storage Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const InitialPage()),
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/warehouse-home', page: () => const WarehouseHomePage()),
        GetPage(name: '/client-home', page: () => const ClientHomePage()),
        GetPage(name: '/user-management', page: () => UserManagementPage()),
      ],
    );
  }
}

class InitialPage extends StatelessWidget {
  const InitialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final authController = Get.find<AuthController>();
      
      if (authController.isAuthenticated.value) {
        // User is logged in, navigate to appropriate home
        Future.delayed(Duration.zero, () {
          authController.navigateToHome();
        });
      } else {
        // User is not logged in, go to login page
        Future.delayed(Duration.zero, () {
          Get.offAllNamed('/login');
        });
      }
      
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    });
  }
}