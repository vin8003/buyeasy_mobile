import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:shop_easyy/providers/navigation_provider.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  try {
    // Check if we are on Android or iOS (where google-services.json/plist handles it)
    // OR if we are on Linux/Web where we need manual options.
    // Since google-services.json logic often fails on Linux desktop builds even if plugin is there (it's for Android).
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['API_KEY']!,
          appId: dotenv.env['APP_ID']!,
          messagingSenderId: dotenv.env['MESSAGING_SENDER_ID']!,
          projectId: dotenv.env['PROJECT_ID']!,
          storageBucket: dotenv.env['STORAGE_BUCKET']!,
          authDomain: dotenv.env['AUTH_DOMAIN']!,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await Firebase.initializeApp();
    } else {
      // Firebase Core does not support Linux/Windows Desktop natively yet.
      // We skip initialization to allow the app to run for UI testing,
      // but Firebase features will throw errors if accessed.
      debugPrint('------------------------------------------------');
      debugPrint(
        'WARNING: Firebase is NOT supported on Linux/Windows Desktop.',
      );
      debugPrint('Skipping initialization. Auth features will NOT work.');
      debugPrint(
        'Please run on Android, iOS, or Chrome for full functionality.',
      );
      debugPrint('------------------------------------------------');
    }
    await NotificationService().initialize();
    debugPrint('Firebase/Notifications initialized successfully');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('------------------------------------------------');
    debugPrint('FIREBASE ALERT: Initialization failed.');
    debugPrint('Check if google-services.json is in android/app/');
    debugPrint('Error: $e');
    debugPrint('------------------------------------------------');
    // Run a simple error app
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Firebase Initialization Failed:\n$e',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService().navigatorKey,
      title: 'Order Easy',
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
