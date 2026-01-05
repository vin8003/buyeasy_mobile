import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'retailer_list_screen.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import 'product_page.dart';
import 'order_history_screen.dart';
import 'order_detail_screen.dart';
import 'add_edit_address_screen.dart';
import '../services/api_service.dart';
import '../providers/order_provider.dart';
import 'package:shop_easyy/providers/navigation_provider.dart';
import 'dart:async';
import '../services/notification_service.dart';

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  _HomeContainerState createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  Retailer? _selectedRetailer;

  // Create a navigator key to control the nested navigator
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ApiService _apiService = ApiService();
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _checkAddresses();
    _listenForNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForNotifications() {
    _notificationSubscription = NotificationService().updateStream.listen((
      data,
    ) {
      if (data['event'] == 'order_chat') {
        if (mounted) {
          final orderId = int.tryParse(data['order_id'].toString());
          if (orderId != null) {
            final currentChatId = context
                .read<OrderProvider>()
                .currentChatOrderId;

            // Only show notification and increment count if NOT in that chat
            if (currentChatId != orderId) {
              context.read<OrderProvider>().incrementUnreadCount(orderId);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('New message from Store!'),
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: Colors.tealAccent,
                    onPressed: () {
                      _navigatorKey.currentState?.pushNamed(
                        '/order-detail',
                        arguments: orderId,
                      );
                    },
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _checkAddresses() async {
    try {
      final response = await _apiService.getAddresses();
      if (response.statusCode == 200) {
        final List addresses = response.data;
        if (addresses.isEmpty && mounted) {
          // Force add address
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) =>
                      const AddEditAddressScreen(isCompulsory: true),
                ),
              )
              .then(
                (_) => _checkAddresses(),
              ); // Check again after they come back (though pop is blocked)
        }
      }
    } catch (e) {
      print('Error checking addresses: $e');
    }
  }

  void onTabTapped(int index) {
    final navProvider = context.read<NavigationProvider>();
    if (navProvider.currentIndex == index) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      navProvider.setIndex(index);
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
    });
    context.read<NavigationProvider>().setIndex(0); // Go to Home (Shop)
    // Ensure we are on home route
    _navigatorKey.currentState?.pushReplacementNamed('/');
  }

  void _changeRetailer() {
    setState(() {
      _selectedRetailer = null;
    });
    context.read<NavigationProvider>().setIndex(0);
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
        builder = (BuildContext context) => WishlistScreen();
        break;
      case '/profile':
        builder = (BuildContext context) => ProfileScreen();
        break;
      case '/product':
        // Handle Product Page inside nested navigator
        final product = settings.arguments as Product;
        builder = (BuildContext context) => ProductPage(product: product);
        break;
      case '/orders':
        builder = (BuildContext context) => OrderHistoryScreen();
        break;
      case '/order-detail':
        final orderId = settings.arguments as int?;
        if (orderId != null) {
          builder = (BuildContext context) =>
              OrderDetailScreen(orderId: orderId);
        } else {
          builder = (BuildContext context) =>
              const Scaffold(body: Center(child: Text('Order ID not found.')));
        }
        break;
      default:
        builder = (BuildContext context) =>
            const Center(child: Text('Unknown Route'));
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    return Scaffold(
      body: Navigator(
        key: _navigatorKey,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: navProvider.currentIndex,
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
