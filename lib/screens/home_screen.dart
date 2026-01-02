import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../services/api_service.dart';
import '../models/retailer.dart';
import '../models/category.dart';
import 'wishlist_screen.dart';
import 'category_products_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _featuredProducts = [];
  Set<int> _wishlistedProductIds = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String _userReferralCode = '';
  bool _isProfileLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch retailer-specific categories and featured products concurrently
      final results = await Future.wait([
        _apiService.getRetailerCategories(widget.retailer.id),
        _apiService.getFeaturedProducts(widget.retailer.id),
        _apiService.getWishlist(),
      ]);

      final categoriesResponse = results[0];
      final featuredResponse = results[1];
      final wishlistResponse = results[2];

      if (categoriesResponse.statusCode == 200 &&
          featuredResponse.statusCode == 200 &&
          wishlistResponse.statusCode == 200) {
        final List<dynamic> categoryJson = categoriesResponse.data is List
            ? categoriesResponse.data
            : categoriesResponse.data['results'] ?? [];
        final List<dynamic> featuredJson = featuredResponse.data is List
            ? featuredResponse.data
            : featuredResponse.data['results'] ?? [];
        final List<dynamic> wishlistJson = wishlistResponse.data is List
            ? wishlistResponse.data
            : wishlistResponse.data['results'] ?? [];

        final categories = categoryJson
            .map((json) => Category.fromJson(json))
            .toList();

        final featuredProducts = featuredJson
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
          _categories = categories;
          _featuredProducts = featuredProducts;
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

  void _navigateToCategory(Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsScreen(
          retailerId: widget.retailer.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // _onSearchChanged will handle the filtering
                },
              )
            : Column(
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
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Referral Banner
            _buildReferralBanner(),

            // Categories Section
            if (_categories.isNotEmpty) ...[
              _buildSectionHeader(
                'Shop by Category',
                onSeeAll: () {
                  Navigator.pushNamed(context, '/categories');
                },
              ),
              _buildCategoriesGrid(),
            ],

            // Featured Products Section
            if (_featuredProducts.isNotEmpty) ...[
              _buildSectionHeader('Featured Products'),
              _buildFeaturedProductsList(),
            ],

            // View All Products Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          retailerId: widget.retailer.id,
                          categoryName: null, // null means all products
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.grid_view),
                  label: const Text('View All Products'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _categories.length > 9 ? 9 : _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    // Define category icons mapping
    final Map<String, IconData> categoryIcons = {
      'grocery': Icons.shopping_basket,
      'groceries': Icons.shopping_basket,
      'fruits': Icons.apple,
      'vegetables': Icons.eco,
      'dairy': Icons.egg_alt,
      'beverages': Icons.local_drink,
      'snacks': Icons.cookie,
      'bakery': Icons.bakery_dining,
      'meat': Icons.kebab_dining,
      'seafood': Icons.set_meal,
      'frozen': Icons.ac_unit,
      'household': Icons.home,
      'personal care': Icons.face,
      'baby': Icons.child_care,
      'pet': Icons.pets,
      'electronics': Icons.devices,
      'clothing': Icons.checkroom,
      'default': Icons.category,
    };

    IconData getIconForCategory(String categoryName) {
      final lowerName = categoryName.toLowerCase();
      for (final entry in categoryIcons.entries) {
        if (lowerName.contains(entry.key)) {
          return entry.value;
        }
      }
      return categoryIcons['default']!;
    }

    return GestureDetector(
      onTap: () => _navigateToCategory(category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getIconForCategory(category.name),
                size: 28,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedProductsList() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _featuredProducts.length,
        itemBuilder: (context, index) {
          final product = _featuredProducts[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/product', arguments: product);
              },
              child: ProductCard(
                product: product,
                isWishlisted: _wishlistedProductIds.contains(product.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferralBanner() {
    return Container(
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
            const Center(child: CircularProgressIndicator(color: Colors.white))
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
    );
  }
}
