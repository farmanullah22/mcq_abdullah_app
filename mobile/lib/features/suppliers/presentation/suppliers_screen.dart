import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/supplier.dart';
import '../providers/supplier_providers.dart';
import 'supplier_detail_screen.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(supplierListControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF17151C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Suppliers',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.read(supplierListControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: TextField(
                controller: _search,
                onChanged: (v) => ref.read(supplierListControllerProvider.notifier).setSearch(v.trim()),
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or city...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _search.clear();
                            ref.read(supplierListControllerProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.gold.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.35), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.35), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.9), width: 1.4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: state.data.when(
                loading: () => const LoadingView(),
                error: (e, st) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.read(supplierListControllerProvider.notifier).refresh(),
                ),
                data: (page) {
                  final suppliers = page.suppliers;
                  if (suppliers.isEmpty) {
                    return EmptyState(
                      icon: state.search.isEmpty ? Icons.local_shipping_outlined : Icons.search_off,
                      title: state.search.isEmpty ? 'No suppliers yet' : 'No matches found',
                      subtitle: state.search.isEmpty
                          ? 'Tap + to add your first supplier.'
                          : 'No suppliers match your search.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _SupplierTile(
                      supplier: suppliers[i],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplierId: suppliers[i].id)),
                        );
                        if (mounted) ref.read(supplierListControllerProvider.notifier).refresh();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              heroTag: 'addSupplier',
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF17151C),
              icon: const Icon(Icons.add_business_outlined, size: 20),
              label: const Text('Add Supplier'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
                );
                if (mounted) ref.read(supplierListControllerProvider.notifier).refresh();
              },
            ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({required this.supplier, required this.onTap});

  final Supplier supplier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dueColor = supplier.hasDue ? AppColors.danger : AppColors.success;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: supplier.hasDue ? 0.6 : 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                child: Text(
                  (supplier.name.isNotEmpty ? supplier.name[0] : '?').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.goldDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (supplier.phone.isNotEmpty) supplier.phone,
                        if (supplier.city.isNotEmpty) supplier.city,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    supplier.hasDue ? 'Due' : 'Settled',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: dueColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.currency(supplier.balance),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: dueColor,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.goldDark),
            ],
          ),
        ),
      ),
    );
  }
}
