import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/category.dart';
import 'category_products_screen.dart';

class CategoryScreen extends StatefulWidget {
  final int? retailerId;
  const CategoryScreen({super.key, this.retailerId});

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Category> _allCategories = [];
  List<Category> _filteredCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCategories = _allCategories
          .where(
            (cat) => cat.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _apiService.getCategories();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _allCategories = data.map((json) => Category.fromJson(json)).toList();
          _filteredCategories = _allCategories;
          _isLoading = false;
        });
      } else {
        throw 'Failed to load categories';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load categories. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchCategories,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120.0,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Explore Categories',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    centerTitle: true,
                    background: Container(color: Colors.white),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_filteredCategories.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No categories found matching your search.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.82,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final category = _filteredCategories[index];
                        return _buildCategoryCard(category);
                      }, childCount: _filteredCategories.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    final Color categoryColor =
        Colors.primaries[category.name.length % Colors.primaries.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(
              categoryName: category.name,
              retailerId: widget.retailerId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: category.image != null && category.image!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: category.image!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _buildFallbackCover(categoryColor, category.name),
                        errorWidget: (context, error, stackTrace) =>
                            _buildFallbackCover(categoryColor, category.name),
                      )
                    : _buildFallbackCover(categoryColor, category.name),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover(Color color, String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
        ),
      ),
      child: Center(
        child: Icon(_getCategoryIcon(name), size: 40, color: Colors.white),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('fruit') || name.contains('vegetable')) return Icons.eco;
    if (name.contains('dairy') ||
        name.contains('milk') ||
        name.contains('egg')) {
      return Icons.egg_outlined;
    }
    if (name.contains('beverage') ||
        name.contains('drink') ||
        name.contains('juice')) {
      return Icons.local_drink_outlined;
    }
    if (name.contains('snack')) return Icons.fastfood_outlined;
    if (name.contains('bakery')) return Icons.bakery_dining_outlined;
    if (name.contains('meat') || name.contains('fish')) {
      return Icons.set_meal_outlined;
    }
    if (name.contains('grocery') || name.contains('staple')) {
      return Icons.shopping_basket_outlined;
    }
    if (name.contains('personal') || name.contains('care')) {
      return Icons.face_retouching_natural;
    }
    if (name.contains('home') || name.contains('household')) {
      return Icons.home_repair_service_outlined;
    }
    return Icons.grid_view_outlined;
  }
}
