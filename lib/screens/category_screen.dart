import 'package:flutter/material.dart';
import 'category_products_screen.dart'; // add this import

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<CategoryItem> categories = [
      CategoryItem('Women\'s Fashion', Icons.checkroom),
      CategoryItem('Men\'s Fashion', Icons.man),
      CategoryItem('Electronics', Icons.electrical_services),
      CategoryItem('Groceries', Icons.local_grocery_store),
      CategoryItem('Kids', Icons.child_care),
      CategoryItem('Home & Living', Icons.chair),
      CategoryItem('Beauty & Health', Icons.brush),
      CategoryItem('Sports & Fitness', Icons.sports_basketball),
      CategoryItem('Toys & Games', Icons.toys),
      CategoryItem('Books', Icons.book),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search action
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 3 / 2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // ✅ Navigate to category product listing
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProductsScreen(
                    categoryName: categories[index].name,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(categories[index].icon, size: 40, color: Colors.blue),
                  const SizedBox(height: 10),
                  Text(
                    categories[index].name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryItem {
  final String name;
  final IconData icon;

  CategoryItem(this.name, this.icon);
}
