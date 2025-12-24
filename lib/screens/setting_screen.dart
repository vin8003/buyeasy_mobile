import 'package:flutter/material.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final int _selectedIndex = 4;

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.pushNamed(context, '/category');
        break;
      case 2:
        Navigator.pushNamed(context, '/cart');
        break;
      case 3:
        Navigator.pushNamed(context, '/wishlist');
        break;
      case 4:
        // Already on settings
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
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
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          sectionTitle("Account"),
          settingsTile(
            Icons.person_outline,
            "Profile",
            "Manage your profile",
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          settingsTile(
            Icons.local_shipping_outlined,
            "Orders",
            "Track, return, or cancel orders",
            onTap: () => Navigator.pushNamed(context, '/orders'),
          ),
          settingsTile(
            Icons.percent_outlined,
            "Offers",
            "View and manage offers",
            onTap: () => Navigator.pushNamed(context, '/offers'),
          ),
          const SizedBox(height: 20),
          sectionTitle("App Settings"),
          settingsTile(
            Icons.language,
            "Language",
            "Change app language",
            trailingText: "English",
            onTap: () => Navigator.pushNamed(context, '/language'),
          ),
          const SizedBox(height: 20),
          sectionTitle("Support"),
          settingsTile(
            Icons.help_outline,
            "Help & Support",
            "Get help with your orders",
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget settingsTile(
    IconData icon,
    String title,
    String subtitle, {
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: Colors.black),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailingText != null
          ? Text(trailingText, style: const TextStyle(color: Colors.grey))
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
