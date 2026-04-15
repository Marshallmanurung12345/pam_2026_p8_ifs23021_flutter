// lib/providers/todo_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../data/models/todo_model.dart';
import '../data/services/todo_repository.dart';

enum TodoStatus { initial, loading, success, error }

class TodoProvider extends ChangeNotifier {
  TodoProvider({TodoRepository? repository})
      : _repository = repository ?? TodoRepository();

  final TodoRepository _repository;

  // ── State ────────────────────────────────────
  TodoStatus _status = TodoStatus.initial;
  List<TodoModel> _todos = [];
  TodoModel? _selectedTodo;
  String _errorMessage = '';
  String _searchQuery = '';

  // ── Pagination State ─────────────────────────
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;

  // ── Getters ──────────────────────────────────
  TodoStatus get status => _status;
  TodoModel? get selectedTodo => _selectedTodo;
  String get errorMessage => _errorMessage;
  bool get hasReachedMax => _hasReachedMax;
  bool get isLoadingMore => _isLoadingMore;

  List<TodoModel> get todos {
    if (_searchQuery.isEmpty) return List.unmodifiable(_todos);
    return _todos
        .where((t) =>
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get totalTodos => _todos.length;
  int get doneTodos => _todos.where((t) => t.isDone).length;
  int get pendingTodos => _todos.where((t) => !t.isDone).length;

  // ── Load All Todos (first page) ───────────────
  Future<void> loadTodos({required String authToken}) async {
    _setStatus(TodoStatus.loading);
    _currentPage = 1;
    _hasReachedMax = false;

    final result = await _repository.getTodos(
      authToken: authToken,
      page: _currentPage,
      perPage: _perPage,
    );
    if (result.success && result.data != null) {
      _todos = result.data!;
      if (_todos.length < _perPage) _hasReachedMax = true;
      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

  // ── Load More (pagination) ────────────────────
  Future<void> loadMoreTodos({required String authToken}) async {
    if (_isLoadingMore || _hasReachedMax || _searchQuery.isNotEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentPage++;
    final result = await _repository.getTodos(
      authToken: authToken,
      page: _currentPage,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      final newItems = result.data!;
      if (newItems.isEmpty || newItems.length < _perPage) {
        _hasReachedMax = true;
      }
      // Avoid duplicates
      final existingIds = _todos.map((t) => t.id).toSet();
      final fresh = newItems.where((t) => !existingIds.contains(t.id)).toList();
      _todos = [..._todos, ...fresh];
    } else {
      _currentPage--; // revert on failure
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Load Single Todo ──────────────────────────
  Future<void> loadTodoById({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result =
    await _repository.getTodoById(authToken: authToken, todoId: todoId);
    if (result.success && result.data != null) {
      _selectedTodo = result.data;
      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

  // ── Create Todo ───────────────────────────────
  Future<bool> addTodo({
    required String authToken,
    required String title,
    required String description,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.createTodo(
      authToken: authToken,
      title: title,
      description: description,
    );
    if (result.success) {
      // Reload from page 1
      await loadTodos(authToken: authToken);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Update Todo ───────────────────────────────
  Future<bool> editTodo({
    required String authToken,
    required String todoId,
    required String title,
    required String description,
    required bool isDone,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodo(
      authToken: authToken,
      todoId: todoId,
      title: title,
      description: description,
      isDone: isDone,
    );
    if (result.success) {
      final results = await Future.wait([
        _repository.getTodoById(authToken: authToken, todoId: todoId),
        _repository.getTodos(
            authToken: authToken, page: 1, perPage: _currentPage * _perPage),
      ]);

      final detailResult = results[0];
      final listResult = results[1];

      if (detailResult.success && detailResult.data != null) {
        _selectedTodo = detailResult.data as TodoModel;
      }
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data as List<TodoModel>;
      }

      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Update Cover ──────────────────────────────
  Future<bool> updateCover({
    required String authToken,
    required String todoId,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'cover.jpg',
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodoCover(
      authToken: authToken,
      todoId: todoId,
      imageFile: imageFile,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );
    if (result.success) {
      final results = await Future.wait([
        _repository.getTodoById(authToken: authToken, todoId: todoId),
        _repository.getTodos(
            authToken: authToken, page: 1, perPage: _currentPage * _perPage),
      ]);

      if (results[0].success && results[0].data != null) {
        _selectedTodo = results[0].data as TodoModel;
      }
      if (results[1].success && results[1].data != null) {
        _todos = results[1].data as List<TodoModel>;
      }

      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Delete Todo ───────────────────────────────
  Future<bool> removeTodo({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result =
    await _repository.deleteTodo(authToken: authToken, todoId: todoId);
    if (result.success) {
      _todos.removeWhere((t) => t.id == todoId);
      _selectedTodo = null;
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Search ────────────────────────────────────
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSelectedTodo() {
    _selectedTodo = null;
    notifyListeners();
  }

  void _setStatus(TodoStatus status) {
    _status = status;
    notifyListeners();
  }
}