import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/media_asset.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../viewmodels/admin_media_viewmodel.dart';
import 'widgets/admin_scaffold.dart';

/// UC-19 step 4: upload and manage module media (images, audio, video).
class AdminMediaPage extends StatefulWidget {
  const AdminMediaPage({super.key});

  @override
  State<AdminMediaPage> createState() => _AdminMediaPageState();
}

class _AdminMediaPageState extends State<AdminMediaPage> {
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    if (isAdmin && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminMediaViewModel>().load();
        context.read<AdminContentViewModel>().loadContent();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<AdminMediaViewModel>();

    return AdminScaffold(
      title: 'Media Library',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: media.isLoading
              ? null
              : () => context.read<AdminMediaViewModel>().load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: media.isUploading ? null : () => _startUpload(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload media'),
      ),
      child: Stack(
        children: [
          if (media.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (media.errorMessage != null) ...[
                  _Banner(
                    message: media.errorMessage!,
                    isError: true,
                    onDismiss: () =>
                        context.read<AdminMediaViewModel>().clearMessages(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (media.infoMessage != null) ...[
                  _Banner(
                    message: media.infoMessage!,
                    isError: false,
                    onDismiss: () =>
                        context.read<AdminMediaViewModel>().clearMessages(),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Uploaded Media',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Every file is tied to a module. Use the download URL as an '
                  'audio cue key or lesson source.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (media.assets.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No media uploaded yet.'),
                      ),
                    ),
                  )
                else
                  ...media.assets.map(
                    (asset) => _MediaAssetTile(
                      asset: asset,
                      onDelete: () => _confirmDelete(context, asset),
                    ),
                  ),
              ],
            ),
          if (media.isUploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startUpload(BuildContext context) async {
    final contentViewModel = context.read<AdminContentViewModel>();
    final moduleOptions = contentViewModel.modules
        .map((item) => (id: item.module.id, title: item.module.title))
        .toList();

    if (moduleOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a module first — media must belong to one.'),
        ),
      );
      return;
    }

    final selection = await showModalBottomSheet<_UploadSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _UploadSheet(moduleOptions: moduleOptions),
    );
    if (selection == null || !context.mounted) return;

    // withData forces bytes into memory, which is required on web where there
    // is no readable file path.
    final picked = await FilePicker.pickFiles(
      type: _pickerTypeFor(selection.type),
      withData: true,
    );
    final files = picked?.files ?? const <PlatformFile>[];
    if (files.isEmpty || !context.mounted) return;
    final file = files.first;

    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
      return;
    }

    final adminId = context.read<AdminAuthViewModel>().admin?.uid ?? '';
    final success = await context.read<AdminMediaViewModel>().upload(
          adminId: adminId,
          moduleId: selection.moduleId,
          type: selection.type,
          fileName: file.name,
          contentType: _contentTypeFor(selection.type, file.extension),
          bytes: bytes,
        );

    if (!context.mounted || success) return;

    // Alternative flow: upload failed, offer retry.
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.read<AdminMediaViewModel>().errorMessage ?? 'Upload failed.',
        ),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (context.mounted) _startUpload(context);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MediaAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete media?'),
        content: Text(
          '${asset.fileName} will be removed from Firebase immediately and '
          'cleared from devices on their next sync.',
        ),
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
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AdminMediaViewModel>().delete(asset.id);
  }
}

class _UploadSelection {
  const _UploadSelection({required this.moduleId, required this.type});

  final String moduleId;
  final MediaAssetType type;
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({required this.moduleOptions});

  final List<({String id, String title})> moduleOptions;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  late String _moduleId = widget.moduleOptions.first.id;
  MediaAssetType _type = MediaAssetType.audio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload media',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _moduleId,
            decoration: const InputDecoration(labelText: 'Module'),
            items: widget.moduleOptions
                .map(
                  (option) => DropdownMenuItem(
                    value: option.id,
                    child: Text(option.title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _moduleId = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MediaAssetType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Media type'),
            items: const [
              DropdownMenuItem(
                value: MediaAssetType.audio,
                child: Text('Audio'),
              ),
              DropdownMenuItem(
                value: MediaAssetType.image,
                child: Text('Image'),
              ),
              DropdownMenuItem(
                value: MediaAssetType.video,
                child: Text('Video'),
              ),
              DropdownMenuItem(
                value: MediaAssetType.document,
                child: Text('Document'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              _UploadSelection(moduleId: _moduleId, type: _type),
            ),
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose file'),
          ),
        ],
      ),
    );
  }
}

class _MediaAssetTile extends StatelessWidget {
  const _MediaAssetTile({required this.asset, required this.onDelete});

  final MediaAsset asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE6F1FB),
          child: Icon(_iconFor(asset.type), color: AppColors.sky),
        ),
        title: Text(
          asset.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${asset.type.name} · ${_readableSize(asset.sizeBytes)}'
          '${asset.moduleId == null ? '' : ' · ${asset.moduleId}'}',
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: AppColors.coral),
        ),
      ),
    );
  }

  IconData _iconFor(MediaAssetType type) {
    return switch (type) {
      MediaAssetType.audio => Icons.audiotrack_outlined,
      MediaAssetType.image => Icons.image_outlined,
      MediaAssetType.video => Icons.movie_outlined,
      MediaAssetType.document => Icons.description_outlined,
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isError ? const Color(0xFFFFEAE7) : AppColors.mint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.coral : AppColors.leaf,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

FileType _pickerTypeFor(MediaAssetType type) {
  return switch (type) {
    MediaAssetType.audio => FileType.audio,
    MediaAssetType.image => FileType.image,
    MediaAssetType.video => FileType.video,
    MediaAssetType.document => FileType.any,
  };
}

String _contentTypeFor(MediaAssetType type, String? extension) {
  final normalized = extension?.toLowerCase();
  return switch (normalized) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    _ => switch (type) {
        MediaAssetType.audio => 'audio/mpeg',
        MediaAssetType.image => 'image/png',
        MediaAssetType.video => 'video/mp4',
        MediaAssetType.document => 'application/octet-stream',
      },
  };
}

String _readableSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
