import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../services/api_service.dart';
import '../models/retailer.dart';
import '../models/category.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  final Retailer retailer;
  final VoidCallback onChangeRetailer;

  const HomeScreen({
    super.key,
    required this.retailer,
    required this.onChangeRetailer,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Product> _filteredProducts = [];
  Set<int> _wishlistedProductIds = {};
  int? _selectedCategoryId;
  bool _isLoading = true;
  String _errorMessage = '';
  String _userReferralCode = '';
  bool _isProfileLoading = false;

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
        _apiService.getWishlist(),
      ]);

      final productsResponse = results[0];
      final categoriesResponse = results[1];
      final wishlistResponse = results[2];

      if (productsResponse.statusCode == 200 &&
          categoriesResponse.statusCode == 200 &&
          wishlistResponse.statusCode == 200) {
        final List<dynamic> productJson = productsResponse.data['results'];
        final List<dynamic> categoryJson = categoriesResponse.data;
        final List<dynamic> wishlistJson = wishlistResponse.data is List
            ? wishlistResponse.data
            : wishlistResponse.data['results'] ?? [];

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

        final wishlistedIds = wishlistJson
            .map((json) => json['product'] as int)
            .toSet();

        setState(() {
          _products = products;
          _filteredProducts = products; // Initially show all
          _categories = categories;
          _wishlistedProductIds = wishlistedIds;
          _isLoading = false;
        });

        // Fetch profile for referral code if not already fetched
        if (_userReferralCode.isEmpty) {
          _fetchUserProfile();
        }
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

  Future<void> _fetchUserProfile() async {
    setState(() => _isProfileLoading = true);
    try {
      final response = await _apiService.fetchUserProfile();
      if (response.statusCode == 200) {
        setState(() {
          _userReferralCode = response.data['referral_code'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user profile for referral code: $e');
    } finally {
      setState(() => _isProfileLoading = false);
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

  int _calculateColumns(double width) {
    if (width > 1200) return 6;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  double _calculateAspectRatio(double width) {
    return 0.6;
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

    final width = MediaQuery.of(context).size.width;
    final columns = _calculateColumns(width);
    final aspectRatio = _calculateAspectRatio(width);

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: CustomScrollView(
        slivers: [
          // Referral Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Referral Code for this Shop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this code with friends! You both earn points when they shop here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_isProfileLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (_userReferralCode.isNotEmpty)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Text(
                            _userReferralCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _userReferralCode),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Referral code copied!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // For now just copy as share placeholder
                                Clipboard.setData(
                                  ClipboardData(text: _userReferralCode),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied to share!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Log in to see your referral code.',
                      style: TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
          // Categories Header
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/categories');
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
            ),

          // Categories List
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length + 1,
                  itemBuilder: (context, index) {
                    final bool isSelected =
                        (index == 0 && _selectedCategoryId == null) ||
                        (index > 0 &&
                            _selectedCategoryId == _categories[index - 1].id);

                    final String label = index == 0
                        ? 'All'
                        : _categories[index - 1].name;
                    final int? categoryId = index == 0
                        ? null
                        : _categories[index - 1].id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => _filterProducts(categoryId),
                        selectedColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.white,
                        elevation: isSelected ? 2 : 0,
                        pressElevation: 4,
                        shadowColor: Colors.blueAccent.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.grey[300]!,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Products Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                _selectedCategoryId == null
                    ? 'Featured Products'
                    : 'Products in ${_categories.firstWhere((c) => c.id == _selectedCategoryId).name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Products Grid
          _filteredProducts.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text('No products found.')),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/product',
                            arguments: _filteredProducts[i],
                          );
                        },
                        child: ProductCard(
                          product: _filteredProducts[i],
                          isWishlisted: _wishlistedProductIds.contains(
                            _filteredProducts[i].id,
                          ),
                        ),
                      ),
                      childCount: _filteredProducts.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}
