import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/parent_account.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/play/play.dart';

/// The first thing a family sees.
///
/// The illustration stays — it is the brand, and it is already artwork for
/// children rather than a stock gradient. Everything sitting on top of it is
/// now built from the play kit, so the very first screen already looks like
/// the app a child ends up in.
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
                    constraints.maxHeight * (compact ? 0.25 : 0.27);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      SizedBox(height: topSpace),
                      PopIn(index: 0, child: _BrandBadge(compact: compact)),
                      SizedBox(height: compact ? 10 : 14),
                      PopIn(index: 1, child: _Tagline(compact: compact)),
                      SizedBox(height: compact ? 12 : 18),
                      PopIn(index: 2, child: _SplashKoala(compact: compact)),
                      const Spacer(),
                      FractionallySizedBox(
                        widthFactor: compact ? 0.9 : 0.8,
                        // No IdleWiggle here, tempting as it is: it repeats
                        // forever, which hangs `pumpAndSettle` in this
                        // screen's widget test and leaves an animation running
                        // on the first screen a budget phone ever draws.
                        child: PlayButton(
                          key: const ValueKey('splash-continue-button'),
                          icon: Icons.arrow_forward_rounded,
                          // The label stays put while the session check runs.
                          // Swapping it for "One moment..." made the first
                          // word a family sees flicker for no reason.
                          label: _parent == null
                              ? 'Get started'
                              : 'Continue learning',
                          color: PlayColors.sunshine,
                          textColor: PlayColors.ink,
                          // Not `big`: the Column has fixed spacing and a
                          // Spacer, so a 96px button overflows it on a short
                          // screen. 72px is still well up from the 58px this
                          // used to be.
                          onPressed: _isCheckingSession ? null : _continue,
                        ),
                      ),
                      SizedBox(
                        height:
                            constraints.maxHeight * (compact ? 0.06 : 0.095),
                      ),
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

/// The koala, in the same white disc it wears on the auth screens.
class _SplashKoala extends StatelessWidget {
  const _SplashKoala({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 86.0 : 112.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/koala/koala_guide_portrait.png',
        height: size * 0.86,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// "Play, learn and grow together", on its own slab so it reads against
/// whatever part of the illustration lands behind it.
class _Tagline extends StatelessWidget {
  const _Tagline({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.16),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        'Play, learn and grow together',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Fredoka',
          color: PlayColors.strawberry,
          fontSize: compact ? 17 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Little Learners',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.symmetric(
          horizontal: 26,
          vertical: compact ? 14 : 18,
        ),
        decoration: BoxDecoration(
          color: PlayColors.lime,
          // 34px, like every other surface in the app. The 8px corners here
          // were the giveaway that this screen predated the play kit.
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: 0.24),
              offset: const Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Text(
            'LITTLE\nLEARNERS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: PlayColors.ink,
              fontSize: compact ? 30 : 36,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
