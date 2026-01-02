import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../services/api_service.dart';

enum SortOption { priceLowToHigh, priceHighToLow, name }

class CategoryProductsScreen extends StatefulWidget {
  final String? categoryName; // Nullable - when null shows all products
  final int? retailerId;

  const CategoryProductsScreen({super.key, this.categoryName, this.retailerId});

  @override
  _CategoryProductsScreenState createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  Set<int> _wishlistedProductIds = {};
  bool _isLoading = true;
  String _errorMessage = '';
  SortOption _selectedSort = SortOption.name;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (widget.retailerId == null) {
      setState(() {
        _errorMessage = 'Please select a retailer from the Home screen first.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        _apiService.getProducts(widget.retailerId!),
        _apiService.getWishlist(),
      ]);

      final productsResponse = results[0];
      final wishlistResponse = results[1];

      if (productsResponse.statusCode == 200 &&
          wishlistResponse.statusCode == 200) {
        final List<dynamic> productJson = productsResponse.data['results'];
        final List<dynamic> wishlistJson = wishlistResponse.data is List
            ? wishlistResponse.data
            : wishlistResponse.data['results'] ?? [];
        final allProducts = productJson
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

        final wishlistedIds = wishlistJson
            .map((json) => json['product'] as int)
            .toSet();

        setState(() {
          // Filter by category if categoryName is provided, otherwise show all
          if (widget.categoryName != null) {
            _products = allProducts
                .where((p) => p.categoryName == widget.categoryName)
                .toList();
          } else {
            _products = allProducts;
          }
          _wishlistedProductIds = wishlistedIds;
          _sortProducts();
          _isLoading = false;
        });
      } else {
        throw 'Failed to load products';
      }
    } catch (e) {
      print('Error fetching products by category: $e');
      setState(() {
        _errorMessage = 'Failed to load products. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _sortProducts() {
    setState(() {
      switch (_selectedSort) {
        case SortOption.priceLowToHigh:
          _products.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortOption.priceHighToLow:
          _products.sort((a, b) => b.price.compareTo(a.price));
          break;
        case SortOption.name:
          _products.sort((a, b) => a.name.compareTo(b.name));
          break;
      }
    });
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sort By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildSortOption(SortOption.name, 'Name', Icons.sort_by_alpha),
              _buildSortOption(
                SortOption.priceLowToHigh,
                'Price: Low to High',
                Icons.trending_up,
              ),
              _buildSortOption(
                SortOption.priceHighToLow,
                'Price: High to Low',
                Icons.trending_down,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(SortOption option, String title, IconData icon) {
    final isSelected = _selectedSort == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blueAccent)
          : null,
      onTap: () {
        setState(() {
          _selectedSort = option;
          _sortProducts();
        });
        Navigator.pop(context);
      },
    );
  }

  int _calculateColumns(double width) {
    if (width > 1200) return 6;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  double _calculateAspectRatio(double width) {
    return 0.6; // Consistent aspect ratio for better content fitting
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = _calculateColumns(width);
    final aspectRatio = _calculateAspectRatio(width);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.categoryName ?? 'All Products',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          if (!_isLoading && _errorMessage.isEmpty && _products.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                  top: BorderSide(color: Colors.grey[100]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_products.length} Items',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showSortBottomSheet,
                        icon: const Icon(Icons.sort, size: 20),
                        label: const Text('Sort'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const VerticalDivider(
                        width: 1,
                        indent: 10,
                        endIndent: 10,
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () {
                          // Filter action
                        },
                        icon: const Icon(Icons.filter_list, size: 20),
                        label: const Text('Filter'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blueAccent,
                    ),
                  )
                : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _products.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(columns, aspectRatio),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.retailerId != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No products found in this category.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(int columns, double aspectRatio) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: aspectRatio, // Slightly adjusted for better fit
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (ctx, i) {
        return ProductCard(
          product: _products[i],
          isWishlisted: _wishlistedProductIds.contains(_products[i].id),
        );
      },
    );
  }
}
