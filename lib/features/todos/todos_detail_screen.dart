// lib/features/todos/todos_detail_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/error_widget.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/top_app_bar_widget.dart';

class TodosDetailScreen extends StatefulWidget {
  const TodosDetailScreen({super.key, required this.todoId});

  final String todoId;

  @override
  State<TodosDetailScreen> createState() => _TodosDetailScreenState();
}

class _TodosDetailScreenState extends State<TodosDetailScreen> {
  Uint8List? _coverPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final token = context.read<AuthProvider>().authToken ?? '';
    context.read<TodoProvider>().loadTodoById(
      authToken: token,
      todoId: widget.todoId,
    );
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    // Show local preview immediately
    setState(() => _coverPreview = bytes);

    final token = context.read<AuthProvider>().authToken ?? '';
    final provider = context.read<TodoProvider>();

    final success = await provider.updateCover(
      authToken: token,
      todoId: widget.todoId,
      imageBytes: bytes,
      imageFilename: picked.name,
    );

    if (!mounted) return;
    if (success) {
      setState(() => _coverPreview = null); // clear preview — network URL loaded
      showAppSnackBar(context,
          message: 'Cover berhasil diperbarui.', type: SnackBarType.success);
    } else {
      setState(() => _coverPreview = null);
      showAppSnackBar(context,
          message: provider.errorMessage, type: SnackBarType.error);
    }
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Hapus Todo'),
        content: const Text('Apakah kamu yakin ingin menghapus todo ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final token = context.read<AuthProvider>().authToken ?? '';
      final success = await context.read<TodoProvider>().removeTodo(
        authToken: token,
        todoId: widget.todoId,
      );
      if (success && mounted) {
        showAppSnackBar(context,
            message: 'Todo berhasil dihapus.', type: SnackBarType.success);
        context.go(RouteConstants.todos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();

    if (provider.status == TodoStatus.loading ||
        provider.status == TodoStatus.initial) {
      return const Scaffold(body: LoadingWidget());
    }

    if (provider.status == TodoStatus.error) {
      return Scaffold(
        body: AppErrorWidget(
            message: provider.errorMessage, onRetry: _loadData),
      );
    }

    final todo = provider.selectedTodo;
    if (todo == null) {
      return const Scaffold(
          body: Center(child: Text('Data tidak ditemukan.')));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: TopAppBarWidget(
        title: todo.title,
        showBackButton: true,
        menuItems: [
          TopAppBarMenuItem(
            text: 'Edit',
            icon: Icons.edit_outlined,
            onTap: () async {
              final edited =
              await context.push<bool>(RouteConstants.todosEdit(todo.id));
              if (edited == true && mounted) _loadData();
            },
          ),
          TopAppBarMenuItem(
            text: 'Hapus',
            icon: Icons.delete_outline,
            isDestructive: true,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cover ──
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Show local preview OR network image
                      if (_coverPreview != null)
                        Image.memory(_coverPreview!, fit: BoxFit.cover)
                      else if (todo.urlCover != null)
                        Image.network(
                          todo.urlCover!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                size: 48, color: colorScheme.outline),
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 52, color: colorScheme.primary),
                              const SizedBox(height: 8),
                              Text(
                                'Ketuk untuk menambah cover',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ),

                      // Edit overlay
                      if (todo.urlCover != null || _coverPreview != null)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Ganti Cover',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),

                      // Loading overlay while uploading
                      if (provider.status == TodoStatus.loading && _coverPreview != null)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Status Chip ──
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: todo.isDone
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: todo.isDone
                          ? Colors.green.withOpacity(0.5)
                          : Colors.orange.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        todo.isDone
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        color: todo.isDone ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        todo.isDone ? 'Selesai' : 'Belum Selesai',
                        style: TextStyle(
                          color: todo.isDone ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Description ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deskripsi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text(todo.description,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Metadata ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informasi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Dibuat',
                        value: _formatDate(todo.createdAt)),
                    const SizedBox(height: 8),
                    _InfoRow(
                        icon: Icons.update_rounded,
                        label: 'Diperbarui',
                        value: _formatDate(todo.updatedAt)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}