import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/child_avatar.dart';

class ProfileCreateEditPage extends StatefulWidget {
  const ProfileCreateEditPage({
    this.args,
    super.key,
  });

  final ProfileEditArgs? args;

  @override
  State<ProfileCreateEditPage> createState() => _ProfileCreateEditPageState();
}

class _ProfileCreateEditPageState extends State<ProfileCreateEditPage> {
  final _nameController = TextEditingController();
  int _age = 3;
  String _avatarAsset = 'koala-blue';
  bool _leaderboardOptIn = false;
  String _displayPreference = 'alias';
  bool _didSeedFields = false;
  bool _isUploadingAvatar = false;

  static const _avatars = [
    'koala-blue',
    'koala-green',
    'koala-coral',
    'koala-honey',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshAvatarPreview);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshAvatarPreview);
    _nameController.dispose();
    super.dispose();
  }

  void _refreshAvatarPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final profileVm = context.watch<ProfileViewModel>();
    final editingProfile = widget.args?.profileId == null
        ? null
        : profileVm.profileById(widget.args!.profileId!);
    final isEditing = editingProfile != null;

    if (!_didSeedFields && editingProfile != null) {
      _seedFields(editingProfile);
    }

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Create Profile'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete profile',
              onPressed: () => _confirmDelete(context, editingProfile),
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ProfileFormHero(isEditing: isEditing),
            const SizedBox(height: 16),
            _FancyProfileField(
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                cursorColor: AppColors.plum,
                decoration: const InputDecoration(
                  labelText: 'Child name',
                  prefixIcon: Icon(Icons.badge_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _SectionHeading(
              icon: Icons.cake_rounded,
              label: 'Age',
              helper: 'Choose an age from 3 to 8.',
            ),
            const SizedBox(height: 10),
            _AgeSelector(
              age: _age,
              onChanged: (age) => setState(() => _age = age),
            ),
            const SizedBox(height: 16),
            const _SectionHeading(
              icon: Icons.face_rounded,
              label: 'Avatar',
              helper: 'Pick a color avatar or choose a photo.',
            ),
            const SizedBox(height: 8),
            _AvatarPicker(
              name: _nameController.text.trim().isEmpty
                  ? 'Learner'
                  : _nameController.text,
              selectedAvatar: _avatarAsset,
              avatars: _avatars,
              onAvatarSelected: (avatar) {
                setState(() => _avatarAsset = avatar);
              },
              onPickGallery: _pickAvatarFromGallery,
            ),
            const SizedBox(height: 16),
            _FancyProfileField(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opt in to age-group leaderboard'),
                subtitle: const Text('Display is anonymized in parent views.'),
                activeThumbColor: AppColors.honey,
                activeTrackColor: AppColors.violet,
                value: _leaderboardOptIn,
                onChanged: (value) {
                  setState(() => _leaderboardOptIn = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            _FancyProfileField(
              child: DropdownButtonFormField<String>(
                initialValue: _displayPreference,
                decoration: const InputDecoration(
                  labelText: 'Leaderboard display',
                  prefixIcon: Icon(Icons.visibility_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(value: 'alias', child: Text('Alias')),
                  DropdownMenuItem(
                    value: 'firstName',
                    child: Text('First name'),
                  ),
                ],
                onChanged: _leaderboardOptIn
                    ? (value) {
                        if (value == null) return;
                        setState(() => _displayPreference = value);
                      }
                    : null,
              ),
            ),
            if (profileVm.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                profileVm.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              icon: _isUploadingAvatar ? Icons.cloud_upload : Icons.save,
              label: _isUploadingAvatar
                  ? 'Uploading avatar...'
                  : isEditing
                      ? 'Save changes'
                      : 'Create profile',
              onPressed: profileVm.isLoading || _isUploadingAvatar
                  ? null
                  : () => _save(
                        context,
                        parent.id,
                        editingProfile,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _seedFields(ChildProfile profile) {
    _nameController.text = profile.name;
    _age = profile.age;
    _avatarAsset = profile.avatarAsset;
    _leaderboardOptIn = profile.leaderboardOptIn;
    _displayPreference = profile.displayPreference;
    _didSeedFields = true;
  }

  Future<void> _save(
    BuildContext context,
    String parentId,
    ChildProfile? editingProfile,
  ) async {
    final profileVm = context.read<ProfileViewModel>();
    final avatarForSave = await _avatarForSave(parentId, editingProfile);
    if (!context.mounted || avatarForSave == null) return;

    final success = editingProfile == null
        ? await profileVm.createProfile(
            parentId: parentId,
            name: _nameController.text,
            age: _age,
            avatarAsset: avatarForSave,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          )
        : await profileVm.updateProfile(
            profile: editingProfile,
            name: _nameController.text,
            age: _age,
            avatarAsset: avatarForSave,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          );

    if (!context.mounted || !success) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.profiles,
      (route) => false,
    );
  }

  Future<void> _pickAvatarFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 82,
    );
    if (picked == null) return;
    setState(() => _avatarAsset = Uri.file(picked.path).toString());
  }

  Future<String?> _avatarForSave(
    String parentId,
    ChildProfile? editingProfile,
  ) async {
    if (!_avatarAsset.startsWith('file://')) return _avatarAsset;
    if (Firebase.apps.isEmpty) return _avatarAsset;

    setState(() => _isUploadingAvatar = true);
    try {
      final filePath = Uri.parse(_avatarAsset).toFilePath();
      final extension = _extensionFor(filePath);
      final profilePart = editingProfile?.id ?? 'new';
      final objectName =
          '$profilePart-${DateTime.now().microsecondsSinceEpoch}.$extension';
      final ref = FirebaseStorage.instance.ref(
        'profileAvatars/$parentId/$objectName',
      );
      await ref.putFile(
        File(filePath),
        SettableMetadata(contentType: _contentTypeFor(extension)),
      );
      return ref.getDownloadURL();
    } on FirebaseException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Avatar upload failed: ${error.message ?? error.code}',
          ),
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChildProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete profile?'),
          content: Text('This removes ${profile.name} from this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final deleted = await context.read<ProfileViewModel>().deleteProfile(
          parentId: profile.parentId,
          childId: profile.id,
        );
    if (!context.mounted || !deleted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.profiles,
      (route) => false,
    );
  }
}

class _ProfileFormHero extends StatelessWidget {
  const _ProfileFormHero({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.grape, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.honey,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_reaction_rounded,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Make this profile sparkle' : 'Create a learner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FancyProfileField extends StatelessWidget {
  const _FancyProfileField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.label,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.coral, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.58),
                ),
          ),
        ),
      ],
    );
  }
}

class _AgeSelector extends StatelessWidget {
  const _AgeSelector({
    required this.age,
    required this.onChanged,
  });

  final int age;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var option = 3; option <= 8; option++)
          ChoiceChip(
            label: Text('$option'),
            selected: age == option,
            selectedColor: AppColors.honey,
            backgroundColor: AppColors.lavender,
            labelStyle: TextStyle(
              color: age == option ? AppColors.coral : AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.selectedAvatar,
    required this.avatars,
    required this.onAvatarSelected,
    required this.onPickGallery,
  });

  final String name;
  final String selectedAvatar;
  final List<String> avatars;
  final ValueChanged<String> onAvatarSelected;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: name,
                avatarValue: selectedAvatar,
                radius: 32,
                borderColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Choose from gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final avatar in avatars)
                ChoiceChip(
                  avatar: ChildAvatar(
                    name: name,
                    avatarValue: avatar,
                    radius: 12,
                  ),
                  label: Text(avatar.replaceFirst('koala-', '')),
                  selected: selectedAvatar == avatar,
                  selectedColor: AppColors.honey,
                  onSelected: (_) => onAvatarSelected(avatar),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _extensionFor(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();
  return switch (extension) {
    'png' || 'webp' || 'heic' => extension,
    _ => 'jpg',
  };
}

String _contentTypeFor(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
