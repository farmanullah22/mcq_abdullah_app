import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/carpet_pattern.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../inventory/models/inventory_log.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../products/models/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/providers/product_providers.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _goldDark = Color(0xFFB8860B);
const _bg = Color(0xFF0B0B0F);

class WarehouseDashboardScreen extends ConsumerStatefulWidget {
  const WarehouseDashboardScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<WarehouseDashboardScreen> createState() => _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends ConsumerState<WarehouseDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(dashboardControllerProvider.notifier).refresh();
    await ref.read(productListControllerProvider.notifier).refresh();
    ref.invalidate(inventoryHistoryControllerProvider);
  }

  Future<void> _pushAndRefresh(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh();
  }

  Future<void> _pushStockIn(String productId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockInScreen(productId: productId)),
    );
    if (mounted) await _refresh();
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(dashboardControllerProvider);
    final productState = ref.watch(productListControllerProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _WarehouseBackdrop(),
          SafeArea(
            child: state.data.when(
              loading: () => _LoadingView(message: 'Loading your warehouse...'),
              error: (e, st) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
              data: (data) => RefreshIndicator(
                color: _gold,
                backgroundColor: const Color(0xFF16141B),
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 150),
                  children: [
                    _LuxHeader(user: user, onOpenDrawer: widget.onOpenDrawer),
                    const SizedBox(height: 24),
                    _WarehouseOverview(cards: data.cards),
                    const SizedBox(height: 22),
                    const _WarehouseActionRow(),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Warehouse Products',
                      subtitle: productState.data.hasValue
                          ? '${productState.data.asData?.value.products.length ?? 0} product${productState.data.asData!.value.products.length == 1 ? '' : 's'} · full stock view'
                          : 'Full stock view',
                    ),
                    const SizedBox(height: 12),
                    _WarehouseCatalog(
                      searchController: _searchController,
                      state: productState,
                      onSearch: (v) => ref.read(productListControllerProvider.notifier).setSearch(v),
                      onRetry: () => ref.read(productListControllerProvider.notifier).refresh(),
                      onOpen: (p) => _push(ProductDetailScreen(product: p)),
                      onStockIn: (p) => _pushStockIn(p.id),
                      onTransfer: (p) => _pushAndRefresh(const StockTransferScreen()),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Low Stock Alerts',
                      subtitle: data.lowStock.isEmpty
                          ? 'All products are well stocked'
                          : '${data.lowStock.length} product${data.lowStock.length == 1 ? '' : 's'} need attention',
                      actionLabel: data.lowStock.isEmpty ? null : 'View All',
                      action: data.lowStock.isEmpty ? null : () => _push(const LowStockScreen()),
                    ),
                    const SizedBox(height: 12),
                    _LowStockCard(items: data.lowStock),
                    const SizedBox(height: 28),
                    const _SectionTitle(
                      title: 'Recent Moves',
                      subtitle: 'Stock in & transfers at the warehouse',
                    ),
                    const SizedBox(height: 12),
                    const _RecentMoves(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- backdrop --

class _WarehouseBackdrop extends StatelessWidget {
  const _WarehouseBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/images/admin_dashboard.jfif',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x38050505),
                Color(0x70050505),
                Color(0x9C050505),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _Glow(size: 280, color: _gold.withValues(alpha: 0.14)),
        ),
        Positioned(
          top: 430,
          left: -120,
          child: _Glow(size: 320, color: _goldDark.withValues(alpha: 0.12)),
        ),
        Positioned(
          bottom: 60,
          right: -120,
          child: _Glow(size: 300, color: const Color(0xFF3A2E10).withValues(alpha: 0.34)),
        ),
        const CarpetPattern(opacity: 0.05),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header --

class _LuxHeader extends StatelessWidget {
  const _LuxHeader({required this.user, this.onOpenDrawer});

  final User? user;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.name ?? '').split(' ').first;
    final warehouseName = user?.assignedShopName ?? 'Warehouse';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'lib/images/hayatlogo.png',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HAYAT FOAM',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: _gold,
                    ),
                  ),
                  Text(
                    'WAREHOUSE CONTROL',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      letterSpacing: 1.6,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            const _LuxBell(),
            const SizedBox(width: 6),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onOpenDrawer,
              child: _Avatar(initial: (user?.name ?? 'M').characters.first),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          _greeting().toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
            color: _goldLight.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        _GoldGradientText(
          child: Text(
            firstName.isEmpty ? 'Welcome' : firstName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              '$warehouseName  ·  Warehouse Manager',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _GoldDivider(),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66D4AF37), blurRadius: 14, spreadRadius: -2),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF17151C),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: _goldLight,
          ),
        ),
      ),
    );
  }
}

class _LuxBell extends ConsumerWidget {
  const _LuxBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: Icon(
            Icons.notifications_none_rounded,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_goldLight, _gold, _goldDark],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17151C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 14),
      painter: _GoldDividerPainter(),
    );
  }
}

class _GoldDividerPainter extends CustomPainter {
  const _GoldDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final line = Paint()
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: [
          _gold.withValues(alpha: 0),
          _gold.withValues(alpha: 0.75),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.42, midY), line);
    canvas.drawLine(
        Offset(size.width * 0.58, midY), Offset(size.width, midY), line);

    final diamond = Paint()..color = _goldLight;
    final center = Offset(size.width / 2, midY);
    final s = 5.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s * 0.7, center.dy)
      ..close();
    canvas.drawPath(path, diamond);
  }

  @override
  bool shouldRepaint(_GoldDividerPainter oldDelegate) => false;
}

// ----------------------------------------------------------------- overview --

class _WarehouseOverview extends StatefulWidget {
  const _WarehouseOverview({required this.cards});

  final DashboardCards cards;

  @override
  State<_WarehouseOverview> createState() => _WarehouseOverviewState();
}

class _WarehouseOverviewState extends State<_WarehouseOverview> {
  final _controller = PageController(viewportFraction: 0.84);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({IconData icon, String label, String subtitle, num value, bool currency, Color color, VoidCallback? onTap})>
      get _cards {
    final c = widget.cards;
    return [
      (
        icon: Icons.inventory_2_outlined,
        label: 'Products',
        subtitle: 'In warehouse stock',
        value: c.totalProducts,
        currency: false,
        color: const Color(0xFF7FB5E8),
        onTap: null,
      ),
      (
        icon: Icons.payments_rounded,
        label: 'Stock Value',
        subtitle: 'Total at cost price',
        value: c.totalStockValue,
        currency: true,
        color: _goldLight,
        onTap: null,
      ),
      (
        icon: Icons.warning_amber_rounded,
        label: 'Stock Alerts',
        subtitle: 'Need restocking',
        value: c.lowStockCount,
        currency: false,
        color: AppColors.premiumRedLight,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LowStockScreen()),
        ),
      ),
      (
        icon: Icons.swap_horiz_rounded,
        label: 'Moved Today',
        subtitle: 'Stock in + out',
        value: c.stockInToday + c.stockOutToday,
        currency: false,
        color: const Color(0xFFC9A9FF),
        onTap: null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _OverviewCard(
                icon: cards[index].icon,
                label: cards[index].label,
                subtitle: cards[index].subtitle,
                value: cards[index].value,
                currency: cards[index].currency,
                color: cards[index].color,
                onTap: cards[index].onTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: i == _current
                    ? const LinearGradient(colors: [_goldLight, _gold, _goldDark])
                    : null,
                color: i == _current ? null : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    this.currency = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final num value;
  final Color color;
  final bool currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = _GlassCard(
      padding: const EdgeInsets.all(18),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF17151C)),
              ),
              const Spacer(),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _GoldGradientText(
            child: _AnimatedNumber(
              value: value,
              currency: currency,
              style: GoogleFonts.playfairDisplay(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: card),
    );
  }
}

// ------------------------------------------------------------------ actions --

class _WarehouseActionRow extends ConsumerWidget {
  const _WarehouseActionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({String label, IconData icon, Color color, Widget screen})>[
      (
        label: 'Stock In',
        icon: Icons.south_west_rounded,
        color: const Color(0xFF6FBE8C),
        screen: const StockInScreen(),
      ),
      (
        label: 'Stock Transfer',
        icon: Icons.swap_horiz_rounded,
        color: _goldLight,
        screen: const StockTransferScreen(),
      ),
      (
        label: 'Add Product',
        icon: Icons.add_box_outlined,
        color: const Color(0xFF7FB5E8),
        screen: const ProductFormScreen(),
      ),
    ];
    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator
                          .push(MaterialPageRoute(builder: (_) => a.screen))
                          .then((_) async {
                        await ref.read(dashboardControllerProvider.notifier).refresh();
                        await ref.read(productListControllerProvider.notifier).refresh();
                        ref.invalidate(inventoryHistoryControllerProvider);
                      });
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _gold.withValues(alpha: 0.4)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: a.color.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: a.color.withValues(alpha: 0.55)),
                                  ),
                                  child: Icon(a.icon, size: 20, color: a.color),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ------------------------------------------------------------- product list --

class _WarehouseCatalog extends StatelessWidget {
  const _WarehouseCatalog({
    required this.searchController,
    required this.state,
    required this.onSearch,
    required this.onRetry,
    required this.onOpen,
    required this.onStockIn,
    required this.onTransfer,
  });

  final TextEditingController searchController;
  final ProductListState state;
  final ValueChanged<String> onSearch;
  final VoidCallback onRetry;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onStockIn;
  final ValueChanged<Product> onTransfer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearch,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          cursorColor: _goldLight,
          decoration: InputDecoration(
            hintText: 'Search warehouse stock by name or SKU...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _gold.withValues(alpha: 0.35)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _gold.withValues(alpha: 0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _gold, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        state.data.when(
          loading: () => const _GlassCard(
            child: _EmptyNote('Loading products...'),
          ),
          error: (e, _) => _ErrorView(message: e.toString(), onRetry: onRetry),
          data: (page) {
            if (page.products.isEmpty) {
              return _GlassCard(
                child: _EmptyNote(
                  state.lowStockOnly
                      ? 'No low stock products right now.'
                      : 'No products found in the warehouse.',
                ),
              );
            }
            return _GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final p in page.products) ...[
                    _WarehouseProductTile(
                      product: p,
                      onTap: () => onOpen(p),
                      onStockIn: () => onStockIn(p),
                      onTransfer: () => onTransfer(p),
                    ),
                    if (p != page.products.last) const Divider(
                      height: 1,
                      color: Colors.white24,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WarehouseProductTile extends StatelessWidget {
  const _WarehouseProductTile({
    required this.product,
    required this.onTap,
    required this.onStockIn,
    required this.onTransfer,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onStockIn;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final colors = product.colorStocks;
    final lowStock = product.isLowStock;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductThumb(image: product.images.isEmpty ? '' : product.images.first),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _goldLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        [
                          if (product.sku.isNotEmpty) product.sku,
                          _typeLabel(product.productType),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                _StockPill(quantity: product.quantity, low: lowStock, unit: _stockUnit(product)),
              ],
            ),
            if (colors.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final c in colors) _TreeColorRow(stock: _dashboardColor(c)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _typeDetail(product),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                _RoundAction(icon: Icons.add_box_rounded, tooltip: 'Stock In', onTap: onStockIn),
                const SizedBox(width: 8),
                _RoundAction(icon: Icons.swap_horiz_rounded, tooltip: 'Transfer', onTap: onTransfer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DashboardColorStock _dashboardColor(ColorStock c) =>
      DashboardColorStock(color: c.color, sets: c.sets, pieces: c.pieces);
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, size: 16, color: _goldLight),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.image});

  final String image;

  static const double _size = 52;

  static final Uint8List _transparentPixel = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.chair_outlined,
            color: _gold.withValues(alpha: 0.7),
            size: _size * 0.46,
          ),
        );

    if (image.isEmpty) return fallback();
    ImageProvider provider;
    if (image.startsWith('data:image')) {
      try {
        provider = MemoryImage(base64Decode(image.split(',').last));
      } catch (_) {
        provider = MemoryImage(_transparentPixel);
      }
    } else {
      provider = NetworkImage(image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: provider,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

// -------------------------------------------------------- low stock section --

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});

  final List<LowStockProduct> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _GlassCard(
        child: _EmptyNote('No low stock items — you are all stocked up!'),
      );
    }
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final item in items.take(6)) _LowStockRow(item: item),
          if (items.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${items.length - 6} more',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final LowStockProduct item;

  @override
  Widget build(BuildContext context) {
    final pct = item.lowStockThreshold > 0
        ? (item.quantity / item.lowStockThreshold).clamp(0.0, 1.0)
        : 1.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.premiumRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.premiumRedLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.premiumRedLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.premiumRedLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.quantity.round()} left',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.premiumRedLight,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- recent moves --

class _RecentMoves extends ConsumerWidget {
  const _RecentMoves();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryHistoryControllerProvider);
    return state.data.when(
      loading: () => const _GlassCard(
        child: _EmptyNote('Loading movements...'),
      ),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
      ),
      data: (result) {
        final logs = result.logs;
        if (logs.isEmpty) {
          return const _GlassCard(
            child: _EmptyNote('No movements yet — stock in and transfers will appear here.'),
          );
        }
        return _GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final log in logs.take(6)) _MovementTile(log: log),
            ],
          ),
        );
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.log});

  final InventoryLog log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.isStockIn;
    final color = isIn ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(
              isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIn ? 'Stock In' : 'Stock Out'} · ${log.movementDetail.isNotEmpty ? log.movementDetail : '${log.quantity} units'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(log.date),
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ common --

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: glow ? 0.24 : 0.12),
            blurRadius: glow ? 34 : 24,
            spreadRadius: glow ? -4 : -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: glow ? 0.18 : 0.14),
                  Colors.white.withValues(alpha: glow ? 0.07 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _gold.withValues(alpha: glow ? 0.6 : 0.42),
                width: glow ? 1.3 : 1,
              ),
            ),
            padding: padding,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, 0.5),
                stops: const [0, 1],
                colors: [
                  Colors.white.withValues(alpha: glow ? 0.14 : 0.10),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && actionLabel != null)
          TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: _goldLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedNumber extends StatelessWidget {
  const _AnimatedNumber({required this.value, required this.style, this.currency = true});

  final num value;
  final TextStyle style;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        currency ? Formatters.currency(v) : Formatters.number(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _GoldGradientText extends StatelessWidget {
  const _GoldGradientText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_goldLight, _gold, _goldDark],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: _gold,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _gold, size: 42),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _goldLight,
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ helpers --

class _TreeColorRow extends StatelessWidget {
  const _TreeColorRow({required this.stock});

  final DashboardColorStock stock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        children: [
          const _TreeJoint(),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _colorFromName(stock.color),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stock.color.isEmpty ? '—' : stock.color.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          _MiniStat(label: 'Sets', value: stock.sets),
          const SizedBox(width: 6),
          _MiniStat(label: 'Pieces', value: stock.pieces),
        ],
      ),
    );
  }
}

class _TreeJoint extends StatelessWidget {
  const _TreeJoint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _gold.withValues(alpha: 0.45), width: 1.2),
          bottom: BorderSide(color: _gold.withValues(alpha: 0.45), width: 1.2),
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$value',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _goldLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.quantity, required this.low, this.unit = ''});

  final int quantity;
  final bool low;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final color = low ? const Color(0xFFFF6B6B) : const Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '$quantity',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit.isEmpty ? 'in stock' : unit,
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorFromName(String name) {
  switch (name.trim().toLowerCase()) {
    case 'red':
      return const Color(0xFFE53935);
    case 'blue':
      return const Color(0xFF1E88E5);
    case 'green':
      return const Color(0xFF43A047);
    case 'yellow':
      return const Color(0xFFFDD835);
    case 'orange':
      return const Color(0xFFFB8C00);
    case 'purple':
      return const Color(0xFF8E24AA);
    case 'pink':
      return const Color(0xFFEC407A);
    case 'brown':
      return const Color(0xFF8D6E63);
    case 'black':
      return const Color(0xFF212121);
    case 'white':
      return const Color(0xFFF5F5F5);
    case 'grey':
    case 'gray':
      return const Color(0xFF9E9E9E);
    case 'beige':
    case 'cream':
      return const Color(0xFFE8DCC0);
    case 'maroon':
      return const Color(0xFF800000);
    case 'navy':
      return const Color(0xFF1A237E);
    case 'gold':
      return _gold;
    default:
      return _gold;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'carpet':
      return 'Carpet';
    case 'meter':
      return 'Meter';
    case 'foam':
      return 'Foam';
    case 'pillow':
      return 'Pillow';
    default:
      return 'Qaleen';
  }
}

String _stockUnit(Product p) {
  switch (p.productType) {
    case 'carpet':
      return 'sqft';
    case 'meter':
      return 'meters';
    case 'qaleen':
    case 'foam':
    case 'pillow':
      return 'pcs';
    default:
      return 'in stock';
  }
}

String _typeDetail(Product p) {
  switch (p.productType) {
    case 'carpet':
      if (p.carpetPiecesData.isNotEmpty) {
        return '${p.carpetPiecesData.length} pieces · ${p.quantity} sqft';
      }
      if (p.carpetWidth > 0 && p.carpetHeight > 0) {
        return '${p.carpetWidth}m x ${p.carpetHeight}m · ${p.quantity} sqft';
      }
      return '${p.quantity} sqft';
    case 'meter':
      return '${p.meterLength}m on roll';
    case 'foam':
      if (p.sizeStocks.isNotEmpty) {
        final total = p.sizeStocks.fold(0, (sum, s) => sum + s.pieces);
        return '${p.sizeStocks.length} size${p.sizeStocks.length == 1 ? '' : 's'} · $total pcs';
      }
      return '${p.quantity} pcs';
    case 'pillow':
      return p.pillowSize.isNotEmpty ? '${p.pillowSize} · ${p.quantity} pcs' : '${p.quantity} pcs';
    case 'qaleen':
      if (p.qaleenSizes.isNotEmpty) {
        final total = p.qaleenSizes.fold(0, (sum, s) => sum + s.pieces);
        return '${p.qaleenSizes.length} size${p.qaleenSizes.length == 1 ? '' : 's'} · $total pieces';
      }
      return '${p.quantity} pieces';
    default:
      return '${p.quantity} in stock';
  }
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).round()}w ago';
  return Formatters.date(dt);
}