import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../models/category.dart';
import '../providers/category_providers.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add Category',
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.read(categoryListControllerProvider.notifier).refresh()),
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              subtitle: 'Create categories to organize your products.',
              action: () => _showForm(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(categoryListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.category_outlined, color: AppColors.primary),
                    ),
                    title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: category.description.isNotEmpty ? Text(category.description) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showForm(context, ref, category: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () => _confirmDelete(context, ref, category),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref, {Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                validator: (v) => Validators.required(v, 'Category name is required'),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          }, child: const Text('Save')),
        ],
      ),
    );

    if (save != true) return;
    final notifier = ref.read(categoryMutationControllerProvider.notifier);
    final ok = category == null
        ? await notifier.create(nameController.text.trim(), description: descController.text.trim())
        : await notifier.update(category.id, nameController.text.trim(), description: descController.text.trim());
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(categoryMutationControllerProvider).error ?? 'Failed to save category')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
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
    final success = await ref.read(categoryMutationControllerProvider.notifier).delete(category.id);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(categoryMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }
}
