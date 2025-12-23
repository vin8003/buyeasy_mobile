import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'product_page.dart';
import '../services/api_service.dart';
import '../models/retailer.dart';
import '../models/category.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  final Retailer retailer;
  final VoidCallback onChangeRetailer;

  const HomeScreen({
    Key? key,
    required this.retailer,
    required this.onChangeRetailer,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Product> _filteredProducts = [];
  int? _selectedCategoryId;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch products and categories concurrently
      final results = await Future.wait([
        _apiService.getProducts(widget.retailer.id),
        _apiService.getCategories(),
      ]);

      final productsResponse = results[0];
      final categoriesResponse = results[1];

      if (productsResponse.statusCode == 200 &&
          categoriesResponse.statusCode == 200) {
        final List<dynamic> productJson = productsResponse.data['results'];
        final List<dynamic> categoryJson = categoriesResponse.data;

        final products = productJson
            .map((json) {
              try {
                return Product.fromJson(json);
              } catch (e) {
                return null;
              }
            })
            .where((product) => product != null)
            .cast<Product>()
            .toList();

        final categories = categoryJson
            .map((json) => Category.fromJson(json))
            .toList();

        setState(() {
          _products = products;
          _filteredProducts = products; // Initially show all
          _categories = categories;
          _isLoading = false;
        });
      } else {
        throw 'Failed to load data';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'A network error occurred.';
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      if (categoryId == null) {
        _filteredProducts = _products;
      } else {
        final selectedCategory = _categories.firstWhere(
          (c) => c.id == categoryId,
        );
        // Assuming Product has category field or matching by name.
        // Based on previous code, Product didn't have categoryId, so limiting filtering by name for now if applicable,
        // or just filtering by what we have.
        // Checking Product model might be needed, but for now assuming name match as per previous plan.
        _filteredProducts = _products
            .where((p) => p.categoryName == selectedCategory.name)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shop Easy', style: TextStyle(fontSize: 16)),
            Text(
              widget.retailer.shopName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Change Retailer',
            onPressed: widget.onChangeRetailer,
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Wishlist',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WishlistScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: Column(
        children: [
          // Categories List
          if (_categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                itemCount: _categories.length + 1, // +1 for "All"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategoryId == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: isSelected,
                        onSelected: (_) => _filterProducts(null),
                      ),
                    );
                  }
                  final category = _categories[index - 1];
                  final isSelected = _selectedCategoryId == category.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (_) => _filterProducts(category.id),
                    ),
                  );
                },
              ),
            ),

          // Products Grid
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('No products found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: _filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/product',
                          arguments: _filteredProducts[i],
                        );
                      },
                      child: ProductCard(product: _filteredProducts[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
