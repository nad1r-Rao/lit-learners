import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

class ReadinessTestPage extends StatefulWidget {
  const ReadinessTestPage({super.key});

  @override
  State<ReadinessTestPage> createState() => _ReadinessTestPageState();
}

class _ReadinessTestPageState extends State<ReadinessTestPage> {
  final Map<String, List<int>> _optionOrderByQuestionId = {};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final onboarding = context.watch<OnboardingViewModel>();
    final parent = auth.parent;

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    _ensureShuffledOptions(onboarding.questions);

    return Scaffold(
      appBar: AppBar(title: const Text('Readiness Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.grape, AppColors.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.honey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Score ${OnboardingViewModel.passingScore}% or more to continue.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < onboarding.questions.length; index++)
              _ReadinessQuestionCard(
                questionNumber: index + 1,
                question: onboarding.questions[index],
                optionOrder:
                    _optionOrderByQuestionId[onboarding.questions[index].id] ??
                        const [],
                selectedAnswer: onboarding
                    .selectedAnswerFor(onboarding.questions[index].id),
                onChanged: (value) {
                  context.read<OnboardingViewModel>().selectAnswer(
                        onboarding.questions[index].id,
                        value,
                      );
                },
              ),
            if (onboarding.latestPassed == false) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lemon.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.honey.withValues(alpha: 0.62),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: ${onboarding.latestScore}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Review these tips, then try again.'),
                    const SizedBox(height: 8),
                    for (final question in onboarding.questions)
                      if (onboarding.selectedAnswerFor(question.id) !=
                          question.correctIndex)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('- ${question.tip}'),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<OnboardingViewModel>().resetReadinessAttempt();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retake test'),
              ),
              const SizedBox(height: 12),
            ],
            AppPrimaryButton(
              icon: Icons.check_circle,
              label: 'Submit test',
              onPressed: onboarding.allQuestionsAnswered
                  ? () => _submit(context, parent.id)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, String parentId) async {
    final passed =
        await context.read<OnboardingViewModel>().submitReadinessTest(parentId);
    if (!context.mounted) return;

    if (passed) {
      Navigator.of(context).pushReplacementNamed(RouteNames.profiles);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Readiness score needs another try.')),
    );
  }

  void _ensureShuffledOptions(List<ReadinessQuestion> questions) {
    for (final question in questions) {
      _optionOrderByQuestionId.putIfAbsent(question.id, () {
        final order = List<int>.generate(question.options.length, (index) {
          return index;
        });
        final seed = question.id.codeUnits.fold<int>(
          question.options.length,
          (value, unit) => value + unit,
        );
        order.shuffle(Random(seed + DateTime.now().microsecond));
        return order;
      });
    }
  }
}

class _ReadinessQuestionCard extends StatelessWidget {
  const _ReadinessQuestionCard({
    required this.questionNumber,
    required this.question,
    required this.optionOrder,
    required this.selectedAnswer,
    required this.onChanged,
  });

  final int questionNumber;
  final ReadinessQuestion question;
  final List<int> optionOrder;
  final int? selectedAnswer;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.52)),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$questionNumber',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RadioGroup<int>(
            groupValue: selectedAnswer,
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
            child: Column(
              children: [
                for (final optionIndex in optionOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReadinessOptionTile(
                      value: optionIndex,
                      label: question.options[optionIndex],
                      selected: selectedAnswer == optionIndex,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessOptionTile extends StatelessWidget {
  const _ReadinessOptionTile({
    required this.value,
    required this.label,
    required this.selected,
  });

  final int value;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? AppColors.lavender : AppColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.plum : AppColors.line,
        ),
      ),
      child: RadioListTile<int>(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        activeColor: AppColors.plum,
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
