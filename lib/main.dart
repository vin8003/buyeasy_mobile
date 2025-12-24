import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_container.dart';
import 'screens/product_page.dart';
import 'screens/cart_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/order_history_screen.dart';
import 'models/product.dart';
import 'services/api_service.dart';
import 'screens/order_detail_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Note: This will fail if google-services.json is missing
    await Firebase.initializeApp();
    await NotificationService().initialize();
    debugPrint('Firebase/Notifications initialized successfully');
  } catch (e) {
    debugPrint('------------------------------------------------');
    debugPrint('FIREBASE ALERT: Initialization failed.');
    debugPrint('Check if google-services.json is in android/app/');
    debugPrint('Error: $e');
    debugPrint('------------------------------------------------');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService().navigatorKey,
      title: 'Shop Easyy',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeContainer(),
        '/product': (context) {
          final product =
              ModalRoute.of(context)?.settings.arguments as Product?;
          if (product != null) {
            return ProductPage(product: product);
          }
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Product not found.")),
          );
        },
        '/cart': (context) => CartScreen(),
        '/wishlist': (context) => WishlistScreen(),
        '/profile': (context) => ProfileScreen(),
        '/settings': (context) => SettingScreen(),
        '/orders': (context) => OrderHistoryScreen(),
        '/order-detail': (context) {
          final orderId = ModalRoute.of(context)?.settings.arguments as int?;
          if (orderId != null) {
            return OrderDetailScreen(orderId: orderId);
          }
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Order ID not found.")),
          );
        },
      },
    );
  }
}
