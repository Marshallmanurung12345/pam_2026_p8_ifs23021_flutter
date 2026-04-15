// lib/features/todos/todos_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/error_widget.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/top_app_bar_widget.dart';
import '../../data/models/todo_model.dart';

enum TodoFilter { all, done, pending }

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  TodoFilter _filter = TodoFilter.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        context.read<TodoProvider>().loadMoreTodos(authToken: token);
      }
    }
  }

  void _loadData() {
    final token = context.read<AuthProvider>().authToken;
    if (token != null) {
      context.read<TodoProvider>().loadTodos(authToken: token);
    }
  }

  List<TodoModel> _getFilteredTodos(List<TodoModel> todos) {
    switch (_filter) {
      case TodoFilter.done:
        return todos.where((t) => t.isDone).toList();
      case TodoFilter.pending:
        return todos.where((t) => !t.isDone).toList();
      case TodoFilter.all:
        return todos;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final token = context.read<AuthProvider>().authToken ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final filteredTodos = _getFilteredTodos(provider.todos);

    return Scaffold(
      appBar: TopAppBarWidget(
        title: 'Todo Saya',
        withSearch: true,
        searchHint: 'Cari todo...',
        onSearchChanged: (query) {
          context.read<TodoProvider>().updateSearchQuery(query);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(RouteConstants.todosAdd).then((_) => _loadData()),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          // ── Filter Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented filter
                SegmentedButton<TodoFilter>(
                  segments: const [
                    ButtonSegment(
                      value: TodoFilter.all,
                      label: Text('Semua'),
                      icon: Icon(Icons.list_alt_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: TodoFilter.pending,
                      label: Text('Belum'),
                      icon: Icon(Icons.pending_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: TodoFilter.done,
                      label: Text('Selesai'),
                      icon: Icon(Icons.check_circle_rounded, size: 16),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) =>
                      setState(() => _filter = s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                // Count badge
                Row(
                  children: [
                    _FilterChipBadge(
                      label: 'Total: ${provider.totalTodos}',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _FilterChipBadge(
                      label: 'Selesai: ${provider.doneTodos}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _FilterChipBadge(
                      label: 'Belum: ${provider.pendingTodos}',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ──
          Expanded(
            child: switch (provider.status) {
              TodoStatus.loading when provider.todos.isEmpty =>
              const LoadingWidget(message: 'Memuat todo...'),
              TodoStatus.error when provider.todos.isEmpty =>
                  AppErrorWidget(
                      message: provider.errorMessage, onRetry: _loadData),
              _ => filteredTodos.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter == TodoFilter.all
                          ? 'Belum ada todo.\nKetuk + untuk menambahkan.'
                          : _filter == TodoFilter.done
                          ? 'Belum ada todo yang selesai.'
                          : 'Semua todo sudah selesai! 🎉',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filteredTodos.length +
                      (provider.isLoadingMore ? 1 : 0) +
                      (provider.hasReachedMax && filteredTodos.isNotEmpty
                          ? 1
                          : 0),
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == filteredTodos.length) {
                      if (provider.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      if (provider.hasReachedMax) {
                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'Semua todo sudah dimuat',
                              style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 12),
                            ),
                          ),
                        );
                      }
                    }
                    if (i >= filteredTodos.length) return const SizedBox();
                    final todo = filteredTodos[i];
                    return _TodoCard(
                      todo: todo,
                      onTap: () => context
                          .push(RouteConstants.todosDetail(todo.id))
                          .then((_) => _loadData()),
                      onToggle: () async {
                        final success = await provider.editTodo(
                          authToken: token,
                          todoId: todo.id,
                          title: todo.title,
                          description: todo.description,
                          isDone: !todo.isDone,
                        );
                        if (!success && mounted) {
                          showAppSnackBar(context,
                              message: provider.errorMessage,
                              type: SnackBarType.error);
                        }
                      },
                    );
                  },
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChipBadge extends StatelessWidget {
  const _FilterChipBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style:
        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onTap,
    required this.onToggle,
  });

  final TodoModel todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: todo.isDone ? 0 : 2,
      shadowColor: colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: todo.isDone
            ? BorderSide(color: Colors.green.withOpacity(0.3))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Toggle button
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: todo.isDone
                        ? Colors.green
                        : Colors.transparent,
                    border: Border.all(
                      color: todo.isDone ? Colors.green : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: todo.isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        decoration:
                        todo.isDone ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w600,
                        color: todo.isDone ? colorScheme.outline : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      todo.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (todo.isDone)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.green, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Selesai',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}