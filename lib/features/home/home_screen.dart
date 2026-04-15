// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        context.read<TodoProvider>().loadTodos(authToken: token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().user;
    final provider = context.watch<TodoProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    final total = provider.totalTodos;
    final done = provider.doneTodos;
    final pending = provider.pendingTodos;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final token = context.read<AuthProvider>().authToken;
          if (token != null) {
            await context.read<TodoProvider>().loadTodos(authToken: token);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo, ${user?.name.split(' ').first ?? '—'} 👋',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Yuk selesaikan todo-mu hari ini!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color: colorScheme.onPrimary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  isDark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  color: colorScheme.onPrimary,
                                ),
                                onPressed: () => themeProvider.toggleTheme(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Progress bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress Hari Ini',
                                    style: TextStyle(
                                      color:
                                      colorScheme.onPrimary.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                  colorScheme.onPrimary.withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$done dari $total todo selesai',
                                style: TextStyle(
                                  color: colorScheme.onPrimary.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stat Cards ──
                    Row(
                      children: [
                        _StatCard(
                          label: 'Total',
                          value: total,
                          percentage: null,
                          color: colorScheme.primary,
                          icon: Icons.list_alt_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Selesai',
                          value: done,
                          percentage: total == 0
                              ? 0
                              : (done / total * 100).round(),
                          color: Colors.green,
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Belum',
                          value: pending,
                          percentage: total == 0
                              ? 0
                              : (pending / total * 100).round(),
                          color: Colors.orange,
                          icon: Icons.pending_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Progress Detail ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Ringkasan Progress',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ProgressRow(
                              label: 'Selesai',
                              value: done,
                              total: total,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 10),
                            _ProgressRow(
                              label: 'Belum Selesai',
                              value: pending,
                              total: total,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Quick Access ──
                    Text(
                      'Akses Cepat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuickAccessCard(
                      icon: Icons.checklist_rounded,
                      title: 'Daftar Todo',
                      subtitle: 'Lihat dan kelola semua todo-mu',
                      color: colorScheme.primaryContainer,
                      onTap: () => context.go(RouteConstants.todos),
                    ),
                    const SizedBox(height: 12),
                    _QuickAccessCard(
                      icon: Icons.add_task_rounded,
                      title: 'Todo Baru',
                      subtitle: 'Tambahkan todo baru sekarang',
                      color: colorScheme.secondaryContainer,
                      onTap: () => context.push(RouteConstants.todosAdd),
                    ),
                    const SizedBox(height: 12),
                    _QuickAccessCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Profil Saya',
                      subtitle: 'Kelola akun dan preferensi',
                      color: colorScheme.tertiaryContainer,
                      onTap: () => context.go(RouteConstants.profile),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$value (${(pct * 100).toStringAsFixed(0)}%)',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final int? percentage;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
              if (percentage != null)
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, size: 22),
        ),
        title:
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}