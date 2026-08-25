import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_role.dart';
import 'package:little_learners/models/admin_user.dart';

void main() {
  group('AdminRole', () {
    test('role ids are the stored Firestore values', () {
      // These strings are a data contract with adminUsers/{uid}.role.
      expect(AdminRole.superAdmin.id, 'superAdmin');
      expect(AdminRole.contentAdmin.id, 'contentAdmin');
      expect(AdminRole.analyticsViewer.id, 'analyticsViewer');
    });

    test('parses stored ids, tolerating case and whitespace', () {
      expect(AdminRole.fromId('superAdmin'), AdminRole.superAdmin);
      expect(AdminRole.fromId('  CONTENTADMIN '), AdminRole.contentAdmin);
      expect(AdminRole.fromId('analyticsviewer'), AdminRole.analyticsViewer);
    });

    test('an unknown or missing role resolves to nothing, not a default', () {
      // A typo in the console must deny access rather than grant some.
      expect(AdminRole.fromId('editor'), isNull);
      expect(AdminRole.fromId(''), isNull);
      expect(AdminRole.fromId(null), isNull);
      expect(AdminRole.fromId(7), isNull);
    });

    test('content authoring excludes the analytics viewer', () {
      expect(AdminRole.superAdmin.canManageContent, isTrue);
      expect(AdminRole.contentAdmin.canManageContent, isTrue);
      expect(AdminRole.analyticsViewer.canManageContent, isFalse);
    });

    test('every role may read statistics', () {
      for (final role in AdminRole.values) {
        expect(role.canViewStatistics, isTrue, reason: role.id);
      }
    });

    test('only a super admin sees parent accounts', () {
      expect(AdminRole.superAdmin.canViewParentAccounts, isTrue);
      expect(AdminRole.contentAdmin.canViewParentAccounts, isFalse);
      expect(AdminRole.analyticsViewer.canViewParentAccounts, isFalse);
    });
  });

  group('AdminUser', () {
    AdminUser build({required AdminRole role, bool isActive = true}) {
      return AdminUser(
        uid: 'uid-1',
        email: 'admin@example.com',
        role: role,
        isActive: isActive,
      );
    }

    test('a deactivated account loses every capability', () {
      final suspended = build(role: AdminRole.superAdmin, isActive: false);

      expect(suspended.canSignIn, isFalse);
      expect(suspended.canManageContent, isFalse);
      expect(suspended.canManageMedia, isFalse);
      expect(suspended.canViewStatistics, isFalse);
      expect(suspended.canViewParentAccounts, isFalse);
    });

    test('capabilities follow the role while active', () {
      final content = build(role: AdminRole.contentAdmin);

      expect(content.canManageContent, isTrue);
      expect(content.canViewStatistics, isTrue);
      expect(content.canViewParentAccounts, isFalse);
    });

    test('falls back to the email when no display name is set', () {
      expect(build(role: AdminRole.superAdmin).displayLabel,
          'admin@example.com');
      expect(
        build(role: AdminRole.superAdmin)
            .copyWith(displayName: 'Nadir')
            .displayLabel,
        'Nadir',
      );
    });
  });
}
