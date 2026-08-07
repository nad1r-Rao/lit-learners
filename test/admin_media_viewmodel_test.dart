import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/media_asset.dart';
import 'package:little_learners/repositories/media_asset_repository.dart';
import 'package:little_learners/services/storage/media_storage_data_source.dart';
import 'package:little_learners/viewmodels/admin_media_viewmodel.dart';

void main() {
  group('AdminMediaViewModel', () {
    AdminMediaViewModel buildViewModel() {
      return AdminMediaViewModel(
        InMemoryMediaAssetRepository(
          storageDataSource: InMemoryMediaStorageDataSource(),
        ),
      );
    }

    test('uploads media tied to a module', () async {
      final viewModel = buildViewModel();

      final result = await viewModel.upload(
        adminId: 'admin-1',
        moduleId: 'english',
        type: MediaAssetType.audio,
        fileName: 'letter_a.mp3',
        contentType: 'audio/mpeg',
        bytes: const [1, 2, 3],
      );

      expect(result, isTrue);
      expect(viewModel.assets, hasLength(1));
      expect(viewModel.assets.single.moduleId, 'english');
      expect(viewModel.errorMessage, isNull);
    });

    test('refuses upload without a module (UC-19 business rule)', () async {
      final viewModel = buildViewModel();

      final result = await viewModel.upload(
        adminId: 'admin-1',
        moduleId: '   ',
        type: MediaAssetType.audio,
        fileName: 'letter_a.mp3',
        contentType: 'audio/mpeg',
        bytes: const [1, 2, 3],
      );

      expect(result, isFalse);
      expect(viewModel.assets, isEmpty);
      expect(
        viewModel.errorMessage,
        'Choose the module this media file belongs to.',
      );
    });

    test('reports a failure instead of throwing so upload can be retried',
        () async {
      final viewModel = buildViewModel();

      final result = await viewModel.upload(
        adminId: 'admin-1',
        moduleId: 'english',
        type: MediaAssetType.audio,
        fileName: '',
        contentType: 'audio/mpeg',
        bytes: const [1, 2, 3],
      );

      expect(result, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isUploading, isFalse);
    });

    test('deletes an uploaded asset', () async {
      final viewModel = buildViewModel();
      await viewModel.upload(
        adminId: 'admin-1',
        moduleId: 'math',
        type: MediaAssetType.image,
        fileName: 'three_apples.png',
        contentType: 'image/png',
        bytes: const [9, 9],
      );

      final assetId = viewModel.assets.single.id;
      final result = await viewModel.delete(assetId);

      expect(result, isTrue);
      expect(viewModel.assets, isEmpty);
    });
  });
}
