import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/models/user.dart';
import '../../shops/models/shop.dart';
import '../../shops/providers/shop_providers.dart';

class ManagersScreen extends ConsumerStatefulWidget {
  const ManagersScreen({super.key});

  @override
  ConsumerState<ManagersScreen> createState() => _ManagersScreenState();
}

class _ManagersScreenState extends ConsumerState<ManagersScreen> {
  late Future<List<User>> _managersFuture;

  @override
  void initState() {
    super.initState();
    _managersFuture = _fetch();
  }

  Future<List<User>> _fetch() {
    return ref.read(authRepositoryProvider).listManagers();
  }

  void _reload() {
    setState(() => _managersFuture = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopListControllerProvider).data.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Managers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Add Manager',
            onPressed: () => _showForm(context, shops),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _managersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
          }
          final managers = snapshot.data ?? [];
          if (managers.isEmpty) {
            return const EmptyState(
              icon: Icons.manage_accounts_outlined,
              title: 'No managers yet',
              subtitle: 'Create manager accounts to assign to shops.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: managers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ManagerTile(
                user: managers[index],
                onEdit: () => _showForm(context, shops, user: managers[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showForm(BuildContext context, List<Shop> shops, {User? user}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final passwordController = TextEditingController();
    String? shopId = user?.assignedShopId;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user == null ? 'Add Manager' : 'Edit Manager'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (v) => Validators.required(v, 'Name is required'),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (user == null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    validator: Validators.password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: shopId,
                  decoration: const InputDecoration(labelText: 'Assigned Shop'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No shop')),
                    ...shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => shopId = v,
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
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              if (email.isEmpty && phone.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please provide either email or phone number')),
                  );
                }
                return;
              }
              final data = <String, dynamic>{
                'name': nameController.text.trim(),
                'email': email,
                'phone': phone,
                'assignedShop': shopId,
                if (passwordController.text.isNotEmpty) 'password': passwordController.text,
              };
              try {
                if (user == null) {
                  await ref.read(authRepositoryProvider).createManager(data);
                } else {
                  await ref.read(authRepositoryProvider).updateManager(user.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: Text(user == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (save == true) _reload();
  }
}

class _ManagerTile extends StatelessWidget {
  const _ManagerTile({required this.user, required this.onEdit});

  final User user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            user.email,
            user.assignedShopName ?? 'No shop assigned',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
