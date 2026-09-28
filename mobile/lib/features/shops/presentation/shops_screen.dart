import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../shops/models/shop.dart';
import '../../shops/providers/shop_providers.dart';

class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shopListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(shopListControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Add Shop',
            onPressed: () => _showForm(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(shopListControllerProvider.notifier).refresh(),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shops yet',
              subtitle: 'Create shops and assign managers.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(shopListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: shops.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ShopTile(
                shop: shops[index],
                onEdit: () => _showForm(context, ref, shop: shops[index]),
                onDelete: () => _confirmDelete(context, ref, shops[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref, {Shop? shop}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: shop?.name ?? '');
    final addressController = TextEditingController(text: shop?.address ?? '');
    final contactController = TextEditingController(text: shop?.contactNumber ?? '');
    String? managerId = shop?.managerId;

    final managers = await ref.read(authRepositoryProvider).listManagers();

    if (!context.mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shop == null ? 'Add Shop' : 'Edit Shop'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (v) => Validators.required(v, 'Shop name is required'),
                  decoration: const InputDecoration(labelText: 'Shop Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: managerId,
                  decoration: const InputDecoration(labelText: 'Manager'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No manager')),
                    ...managers.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.email})'))),
                  ],
                  onChanged: (v) => managerId = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = <String, dynamic>{
                'name': nameController.text.trim(),
                'address': addressController.text.trim(),
                'contactNumber': contactController.text.trim(),
                'manager': managerId,
              };
              try {
                if (shop == null) {
                  await ref.read(shopRepositoryProvider).create(data);
                } else {
                  await ref.read(shopRepositoryProvider).update(shop.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: Text(shop == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (save == true) ref.read(shopListControllerProvider.notifier).refresh();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Shop shop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shop'),
        content: Text('Delete "${shop.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(shopRepositoryProvider).delete(shop.id);
      ref.read(shopListControllerProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop, required this.onEdit, required this.onDelete});

  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_outlined, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (shop.address.isNotEmpty) shop.address,
                      if (shop.contactNumber.isNotEmpty) shop.contactNumber,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shop.managerName == null ? 'No manager assigned' : 'Manager: ${shop.managerName}',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
