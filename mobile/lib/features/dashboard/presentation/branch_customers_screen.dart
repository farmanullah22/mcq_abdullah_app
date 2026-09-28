import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../customers/models/customer.dart';
import '../../customers/presentation/customer_detail_screen.dart';

/// Admin-only, shop-scoped customer list opened from the branch command center.
class BranchCustomersScreen extends ConsumerStatefulWidget {
  const BranchCustomersScreen({super.key, required this.shopId, required this.title});

  final String shopId;
  final String title;

  @override
  ConsumerState<BranchCustomersScreen> createState() => _BranchCustomersScreenState();
}

class _BranchCustomersScreenState extends ConsumerState<BranchCustomersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Customer> _items = const [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(customerRepositoryProvider).getCustomers(
            search: _searchController.text.trim(),
            page: 1,
            limit: 30,
            shopId: widget.shopId,
          );
      if (!mounted) return;
      setState(() {
        _items = page.customers;
        _page = 1;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(customerRepositoryProvider).getCustomers(
            search: _searchController.text.trim(),
            page: _page + 1,
            limit: 30,
            shopId: widget.shopId,
          );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...next.customers];
        _page += 1;
        _total = next.total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppBarBrand(showText: false),
            const SizedBox(width: 10),
            Expanded(child: Text('Customers · ${widget.title}')),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.people_alt_outlined,
                            title: 'No customers found',
                            subtitle: 'No customers are registered at this branch.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                if (i >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                return _CustomerCard(customer: _items[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (customer.phone.isNotEmpty) customer.phone,
                        '${customer.purchaseCount} purchases',
                        '${Formatters.compact(customer.totalSpent)} spent',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: customer.balance > 0
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  customer.balance > 0 ? 'Due ${Formatters.compact(customer.balance)}' : 'Clear',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: customer.balance > 0 ? AppColors.danger : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}