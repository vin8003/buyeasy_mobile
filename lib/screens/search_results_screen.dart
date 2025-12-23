import 'package:flutter/material.dart';
import '../models/product.dart'; // Ensure this path is correct
import '../widgets/product_card.dart'; // Ensure this path is correct

class SearchResultsScreen extends StatelessWidget {
  final String query;
  // This list will be populated by an API call in the future
  final List<Product> searchResults;

  const SearchResultsScreen({
    Key? key,
    required this.query,
    required this.searchResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$query"')),
      body: searchResults.isEmpty
          ? const Center(child: Text('No products found.'))
          : GridView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: searchResults.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (ctx, i) => ProductCard(product: searchResults[i]),
            ),
    );
  }
}
