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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      },
    );
  }
}
