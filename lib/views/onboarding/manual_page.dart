import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  PageController? _pageController;
  int _pageIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onboarding = context.watch<OnboardingViewModel>();
    _pageController ??= PageController(
      initialPage: onboarding.currentManualPage,
    );
    _pageIndex = onboarding.currentManualPage;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final onboarding = context.watch<OnboardingViewModel>();
    final parent = auth.parent;

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    final pages = onboarding.manualPages;
    final isLastPage = _pageIndex == pages.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Manual')),
      body: SafeArea(
        child: pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _ManualHeader(
                      parentName: _parentLabel(parent.email),
                      currentPage: _pageIndex + 1,
                      totalPages: pages.length,
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {
                        setState(() => _pageIndex = index);
                        onboarding.saveManualPage(parent.id, index);
                      },
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                          child: Center(
                            child: _ManualCard(
                              icon: _iconFor(page.iconName),
                              title: page.title,
                              body: page.body,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final selected = index == _pageIndex;
                            return _ManualProgressDot(selected: selected);
                          }),
                        ),
                        const SizedBox(height: 14),
                        AppPrimaryButton(
                          icon: isLastPage
                              ? Icons.assignment_turned_in
                              : Icons.arrow_forward,
                          label: isLastPage ? 'Start readiness test' : 'Next',
                          onPressed: () async {
                            if (isLastPage) {
                              await onboarding.completeManual(parent.id);
                              if (!context.mounted) return;
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.onboardingTest,
                              );
                              return;
                            }
                            await _pageController?.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _iconFor(String iconName) {
    return switch (iconName) {
      'family' => Icons.family_restroom,
      'timer' => Icons.timer,
      'heart' => Icons.favorite,
      'lock' => Icons.lock,
      _ => Icons.menu_book,
    };
  }
}

class _ManualHeader extends StatelessWidget {
  const _ManualHeader({
    required this.parentName,
    required this.currentPage,
    required this.totalPages,
  });

  final String parentName;
  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.54)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.honey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.menu_book_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $parentName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Guide $currentPage of $totalPages',
                  style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w700,
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

class _ManualCard extends StatelessWidget {
  const _ManualCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.grape, AppColors.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.grape.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: AppColors.honey),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualProgressDot extends StatelessWidget {
  const _ManualProgressDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 28 : 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: selected ? AppColors.coral : AppColors.lilac,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

String _parentLabel(String email) {
  final name = email.split('@').first.trim();
  if (name.isEmpty) return 'Parent';
  return name[0].toUpperCase() + name.substring(1);
}
