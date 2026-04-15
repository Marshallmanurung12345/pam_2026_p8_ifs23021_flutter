// lib/features/profile/profile_screen.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/top_app_bar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Update Profile ──────────────────────────
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _userCtrl;
  bool _profileLoading = false;

  // ── Change Password ─────────────────────────
  final _passFormKey = GlobalKey<FormState>();
  final _currPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _passLoading = false;
  bool _showCurrPass = false;
  bool _showNewPass = false;
  bool _showConfPass = false;

  // ── Photo Preview ────────────────────────────
  Uint8List? _previewImageBytes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _userCtrl = TextEditingController(text: user?.username ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  // ── Pick & Upload Photo ──────────────────────
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: source, imageQuality: 80, maxWidth: 512);
    if (picked == null || !mounted) return;

    // Read bytes for both preview and upload
    final bytes = await picked.readAsBytes();

    // Show preview immediately using Image.memory
    setState(() => _previewImageBytes = bytes);

    // Upload
    final success = await context.read<AuthProvider>().updatePhoto(
      imageBytes: bytes,
      imageFilename: picked.name,
      // On non-web platforms we can also pass the file path, but bytes works everywhere
    );

    if (!mounted) return;

    if (success) {
      // Clear local preview – the provider now has the updated URL
      setState(() => _previewImageBytes = null);
      showAppSnackBar(
        context,
        message: 'Foto profil berhasil diperbarui.',
        type: SnackBarType.success,
      );
    } else {
      // Revert preview on failure
      setState(() => _previewImageBytes = null);
      showAppSnackBar(
        context,
        message: context.read<AuthProvider>().errorMessage,
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) {
      await _pickAndUploadPhoto(ImageSource.gallery);
      return;
    }

    // Mobile: show bottom sheet picker
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Update Profile ──────────────────────────
  Future<void> _submitProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _profileLoading = true);

    final success = await context.read<AuthProvider>().updateProfile(
      name: _nameCtrl.text.trim(),
      username: _userCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _profileLoading = false);

    showAppSnackBar(
      context,
      message: success
          ? 'Profil berhasil diperbarui.'
          : context.read<AuthProvider>().errorMessage,
      type: success ? SnackBarType.success : SnackBarType.error,
    );
  }

  // ── Change Password ─────────────────────────
  Future<void> _submitPassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _passLoading = true);

    final success = await context.read<AuthProvider>().updatePassword(
      currentPassword: _currPassCtrl.text.trim(),
      newPassword: _newPassCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _passLoading = false);

    showAppSnackBar(
      context,
      message: success
          ? 'Kata sandi berhasil diubah.'
          : context.read<AuthProvider>().errorMessage,
      type: success ? SnackBarType.success : SnackBarType.error,
    );

    if (success) {
      _currPassCtrl.clear();
      _newPassCtrl.clear();
      _confPassCtrl.clear();
    }
  }

  // ── Logout ──────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) context.go(RouteConstants.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final user = provider.user;
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.status == AuthStatus.loading && user == null) {
      return const Scaffold(body: LoadingWidget());
    }

    // Build avatar image widget – prefer local preview, then network, then initials
    Widget avatarChild;
    if (_previewImageBytes != null) {
      avatarChild = ClipOval(
        child: Image.memory(
          _previewImageBytes!,
          width: 108,
          height: 108,
          fit: BoxFit.cover,
        ),
      );
    } else if (user?.urlPhoto != null) {
      avatarChild = ClipOval(
        child: Image.network(
          user!.urlPhoto!,
          width: 108,
          height: 108,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(user.name, colorScheme),
        ),
      );
    } else {
      avatarChild = _initialsAvatar(user?.name ?? '?', colorScheme);
    }

    return Scaffold(
      appBar: TopAppBarWidget(
        title: 'Profil Saya',
        showBackButton: false,
        menuItems: [
          TopAppBarMenuItem(
            text: 'Keluar',
            icon: Icons.logout,
            isDestructive: true,
            onTap: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Avatar Section ──────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: avatarChild,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Icon(Icons.camera_alt,
                              size: 14, color: colorScheme.onPrimary),
                        ),
                      ),
                      if (provider.status == AuthStatus.loading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black26),
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${user?.username ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk foto untuk menggantinya',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Edit Profil ─────────────────────
          _SectionCard(
            title: 'Edit Profil',
            icon: Icons.person_outline,
            child: Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama tidak boleh kosong.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Username tidak boleh kosong.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _profileLoading ? null : _submitProfile,
                      icon: _profileLoading
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(
                          _profileLoading ? 'Menyimpan...' : 'Simpan Profil'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Ganti Kata Sandi ────────────────
          _SectionCard(
            title: 'Ganti Kata Sandi',
            icon: Icons.lock_outline,
            child: Form(
              key: _passFormKey,
              child: Column(
                children: [
                  _PasswordField(
                    controller: _currPassCtrl,
                    label: 'Kata Sandi Saat Ini',
                    show: _showCurrPass,
                    onToggle: () =>
                        setState(() => _showCurrPass = !_showCurrPass),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Kata sandi saat ini diperlukan.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _newPassCtrl,
                    label: 'Kata Sandi Baru',
                    show: _showNewPass,
                    onToggle: () =>
                        setState(() => _showNewPass = !_showNewPass),
                    validator: (v) =>
                    (v == null || v.trim().length < 6)
                        ? 'Minimal 6 karakter.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _confPassCtrl,
                    label: 'Konfirmasi Kata Sandi Baru',
                    show: _showConfPass,
                    onToggle: () =>
                        setState(() => _showConfPass = !_showConfPass),
                    validator: (v) =>
                    v != _newPassCtrl.text
                        ? 'Kata sandi tidak cocok.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _passLoading ? null : _submitPassword,
                      icon: _passLoading
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.key),
                      label: Text(
                          _passLoading ? 'Mengubah...' : 'Ganti Kata Sandi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String name, ColorScheme colorScheme) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 40,
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
              show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}