import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cashier_session_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import 'widgets/home_header.dart';
import 'widgets/katalog_sub_header.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/category_filters.dart';
import 'widgets/product_card.dart';
import 'widgets/product_list_item.dart';

class CashierCatalogView extends StatelessWidget {
  final CashierSessionModel session;
  final TextEditingController searchController;
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final List<ProductModel> filteredProducts;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<ProductModel> onIncrementProduct;
  final ValueChanged<ProductModel> onDecrementProduct;
  final VoidCallback onSyncTap;
  final VoidCallback? onProfileTap;
  final VoidCallback onSearchChanged;
  final bool isSplitPane;
  final bool isGridView;
  final VoidCallback? onToggleViewMode;

  const CashierCatalogView({
    super.key,
    required this.session,
    required this.searchController,
    required this.categories,
    required this.selectedCategoryId,
    required this.filteredProducts,
    required this.onCategorySelected,
    required this.onIncrementProduct,
    required this.onDecrementProduct,
    required this.onSyncTap,
    this.onProfileTap,
    required this.onSearchChanged,
    this.isSplitPane = false,
    this.isGridView = true,
    this.onToggleViewMode,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: HomeHeader(
              session: session,
              onProfileTap: onProfileTap,
              onStatusTap: onSyncTap,
            ),
          ),
        ),

        // Catalog SubHeader with Grid/List Toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: KatalogSubHeader(
              session: session,
              onSyncTap: onSyncTap,
              isGridView: isGridView,
              onToggleViewMode: onToggleViewMode,
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 14),
        ),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SearchBarWidget(
              controller: searchController,
              onChanged: (val) => onSearchChanged(),
              onClear: () => onSearchChanged(),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 14),
        ),

        // Category Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: CategoryFilters(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onCategorySelected: onCategorySelected,
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),

        // Products Display (Grid or List View)
        if (filteredProducts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Produk tidak ditemukan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  return ProductCard(
                    product: product,
                    onIncrement: () => onIncrementProduct(product),
                    onDecrement: () => onDecrementProduct(product),
                    onTap: () => onIncrementProduct(product),
                  );
                },
                childCount: filteredProducts.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProductListItem(
                      product: product,
                      onIncrement: () => onIncrementProduct(product),
                      onDecrement: () => onDecrementProduct(product),
                      onTap: () => onIncrementProduct(product),
                    ),
                  );
                },
                childCount: filteredProducts.length,
              ),
            ),
          ),

        // Bottom padding (less padding when in split pane mode)
        SliverToBoxAdapter(
          child: SizedBox(height: isSplitPane ? 24 : 100),
        ),
      ],
    );
  }
}
