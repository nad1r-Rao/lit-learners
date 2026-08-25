import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/parental_lock_repository.dart';
import 'package:little_learners/viewmodels/parental_lock_viewmodel.dart';

void main() {
  group('ParentalLockViewModel', () {
    test('unlocks when the challenge answer is correct', () async {
      final viewModel = ParentalLockViewModel(InMemoryParentalLockRepository());
      addTearDown(viewModel.dispose);
      await viewModel.loadChallenge();

      final challenge = viewModel.challenge!;
      final passed = await viewModel.verify(challenge.answer.toString());

      expect(passed, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLocked, isFalse);
    });

    test('a fresh challenge is not the same sum every time', () async {
      final repository = InMemoryParentalLockRepository();

      final prompts = <String>{};
      for (var attempt = 0; attempt < 20; attempt++) {
        prompts.add((await repository.createChallenge()).prompt);
      }

      // Two draws can repeat; twenty identical ones would mean the generator
      // is pinned to a fixed seed again.
      expect(prompts.length, greaterThan(1));
    });

    test('the first challenge differs between installs', () async {
      final first = await InMemoryParentalLockRepository(seed: 1)
          .createChallenge();
      final second = await InMemoryParentalLockRepository(seed: 2)
          .createChallenge();

      expect(first.prompt, isNot(second.prompt));
    });

    test('the answer solves the sum it prints', () async {
      final challenge =
          await InMemoryParentalLockRepository(seed: 42).createChallenge();

      final operands = RegExp(r'(\d+) \+ (\d+)').firstMatch(challenge.prompt)!;
      expect(
        int.parse(operands.group(1)!) + int.parse(operands.group(2)!),
        challenge.answer,
      );
    });

    test('locks after three failed attempts', () async {
      final viewModel = ParentalLockViewModel(InMemoryParentalLockRepository());
      addTearDown(viewModel.dispose);
      await viewModel.loadChallenge();

      await viewModel.verify('999');
      await viewModel.verify('999');
      await viewModel.verify('999');

      expect(viewModel.isLocked, isTrue);
      expect(viewModel.errorMessage, contains('Too many tries'));
    });
  });
}
