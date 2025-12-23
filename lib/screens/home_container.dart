import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'retailer_list_screen.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import 'product_page.dart';

class HomeContainer extends StatefulWidget {
  const HomeContainer({Key? key}) : super(key: key);

  @override
  _HomeContainerState createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  int _currentIndex = 0;
  Retailer? _selectedRetailer;

  // Create a navigator key to control the nested navigator
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void onTabTapped(int index) {
    if (_currentIndex == index) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _currentIndex = index;
      });
      _navigatorKey.currentState?.pushReplacementNamed(_getRouteName(index));
    }
  }

  String _getRouteName(int index) {
    switch (index) {
      case 0:
        return '/';
      case 1:
        return '/categories';
      case 2:
        return '/cart';
      case 3:
        return '/wishlist';
      case 4:
        return '/profile';
      default:
        return '/';
    }
  }

  void _onRetailerSelected(Retailer retailer) {
    setState(() {
      _selectedRetailer = retailer;
      _currentIndex = 0; // Go to Home (Shop)
    });
    // Ensure we are on home route
    _navigatorKey.currentState?.pushReplacementNamed('/');
  }

  void _changeRetailer() {
    setState(() {
      _selectedRetailer = null;
      _currentIndex = 0;
    });
    _navigatorKey.currentState?.pushReplacementNamed('/');
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    WidgetBuilder builder;
    switch (settings.name) {
      case '/':
        builder = (BuildContext context) {
          if (_selectedRetailer == null) {
            return RetailerListScreen(onRetailerSelected: _onRetailerSelected);
          } else {
            return HomeScreen(
              retailer: _selectedRetailer!,
              onChangeRetailer: _changeRetailer,
            );
          }
        };
        break;
      case '/categories':
        builder = (BuildContext context) =>
            CategoryScreen(retailerId: _selectedRetailer?.id);
        break;
      case '/cart':
        builder = (BuildContext context) =>
            CartScreen(retailerId: _selectedRetailer?.id);
        break;
      case '/wishlist':
        builder = (BuildContext context) => const WishlistScreen();
        break;
      case '/profile':
        builder = (BuildContext context) => const ProfileScreen();
        break;
      case '/product':
        // Handle Product Page inside nested navigator
        final product = settings.arguments as Product;
        builder = (BuildContext context) => ProductPage(product: product);
        break;
      default:
        builder = (BuildContext context) =>
            const Center(child: Text('Unknown Route'));
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        key: _navigatorKey,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
