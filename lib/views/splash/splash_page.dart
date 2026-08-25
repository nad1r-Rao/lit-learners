import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/parent_account.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  ParentAccount? _parent;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    final auth = context.read<AuthViewModel>();
    await auth.loadCurrentParent();
    if (!mounted) return;

    setState(() {
      _parent = auth.parent;
      _isCheckingSession = false;
    });
  }

  Future<void> _continue() async {
    final parent = _parent;
    if (parent == null) {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    await AuthFlowRouter.routeAfterAuth(context: context, parent: parent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash/little_learners_splash.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 650;
                final topSpace =
                    constraints.maxHeight * (compact ? 0.27 : 0.29);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(height: topSpace),
                      const _BrandBadge(),
                      SizedBox(height: compact ? 8 : 14),
                      Text(
                        'Play, learn and grow together',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.coral,
                                  fontSize: compact ? 14 : 16,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      _SplashKoala(compact: compact),
                      const Spacer(),
                      FractionallySizedBox(
                        widthFactor: compact ? 0.86 : 0.76,
                        child: SizedBox(
                          height: compact ? 52 : 58,
                          child: FilledButton.icon(
                            key: const ValueKey('splash-continue-button'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.honey,
                              foregroundColor: AppColors.coral,
                              elevation: 5,
                              shadowColor:
                                  AppColors.grape.withValues(alpha: 0.28),
                            ),
                            onPressed: _isCheckingSession ? null : _continue,
                            icon: _isCheckingSession
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppColors.coral,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _parent == null
                                  ? 'Get started'
                                  : 'Continue learning',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: constraints.maxHeight * 0.105),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashKoala extends StatelessWidget {
  const _SplashKoala({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/koala/koala_guide_portrait.png',
      height: compact ? 76 : 104,
      fit: BoxFit.contain,
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Little Learners',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          boxShadow: [
            BoxShadow(
              color: AppColors.grape.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Text(
            'LITTLE\nLEARNERS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 0.98,
                ),
          ),
        ),
      ),
    );
  }
}
