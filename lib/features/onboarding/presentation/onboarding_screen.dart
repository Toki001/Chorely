import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/page_frame.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinish, this.onLinkChild, super.key});
  final VoidCallback onFinish;
  final VoidCallback? onLinkChild;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  static const _titles = [
    'One home.\nOne team.',
    'A little clarity.\nA lighter day.',
    'Small moments.\nShared wins.',
  ];
  static const _bodies = [
    'Make room for what matters. Share the everyday chores and take care of home, together.',
    'Give every chore a person and a time. Everyone knows their part, without another reminder.',
    'See what’s done, lend a hand, and enjoy the time you make for each other.',
  ];
  static const _art = ['welcome', 'assign', 'done'];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.roofing_rounded,
                color: ChorelyColors.primary,
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'chorely',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_page > 0)
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: () => setState(() => _page--),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ChorelyColors.lavender.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: Image.asset(
                'app/assets/illustrations/${_art[_page]}.png',
                excludeFromSemantics: true,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.cottage_outlined,
                  size: 100,
                  color: ChorelyColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            label: 'Page ${_page + 1} of 3',
            child: ExcludeSemantics(
              child: Row(
                children: List.generate(
                  3,
                  (i) => Container(
                    width: i == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? ChorelyColors.primary
                          : ChorelyColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _titles[_page],
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            _bodies[_page],
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: ChorelyColors.secondary),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_page < 2) {
                  setState(() => _page++);
                } else {
                  widget.onFinish();
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _page == 2 ? 'Set up your home' : 'Let’s begin',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.onFinish,
              child: const Text('I already have an account'),
            ),
          ),
          if (widget.onLinkChild != null)
            Center(
              child: TextButton(
                onPressed: widget.onLinkChild,
                child: const Text('Link a child device'),
              ),
            ),
        ],
      ),
    ),
  );
}
