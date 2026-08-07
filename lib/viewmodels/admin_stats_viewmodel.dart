import 'package:flutter/foundation.dart';

import '../models/admin_stats.dart';
import '../repositories/admin_authorization_repository.dart';
import '../repositories/admin_stats_repository.dart';

/// Supplies the dashboard counts, the parent account list, and the progress
/// statistics screen.
class AdminStatsViewModel extends ChangeNotifier {
  AdminStatsViewModel(this._statsRepository);

  final AdminStatsRepository _statsRepository;

  AdminStats _stats = const AdminStats.empty();
  List<AdminParentAccountSummary> _parentAccounts = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  AdminStats get stats => _stats;
  List<AdminParentAccountSummary> get parentAccounts => _parentAccounts;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _statsRepository.loadStats(),
        _statsRepository.loadParentAccounts(),
      ]);
      _stats = results[0] as AdminStats;
      _parentAccounts = results[1] as List<AdminParentAccountSummary>;
      _hasLoaded = true;
    } on AdminPermissionException catch (error) {
      _errorMessage = error.message;
    } on Exception catch (error) {
      _errorMessage = 'Could not load statistics: $error';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clears cached metrics so a signed-out admin's data is not left on screen.
  void reset() {
    _stats = const AdminStats.empty();
    _parentAccounts = const [];
    _hasLoaded = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
