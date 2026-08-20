import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PlayerPaywallOverlay extends StatelessWidget {
  final int episodeNumber;
  final int unlockCost;
  final int availableCredits;
  final bool unlocking;
  final bool authenticated;
  final String? message;
  final VoidCallback onUnlock;
  final VoidCallback onLogin;

  const PlayerPaywallOverlay({
    super.key,
    required this.episodeNumber,
    required this.unlockCost,
    required this.availableCredits,
    required this.unlocking,
    required this.authenticated,
    required this.onUnlock,
    required this.onLogin,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.lock_rounded, color: Colors.white, size: 42),
              const SizedBox(height: 16),
              Text(
                'Episódio $episodeNumber',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O próximo toque continua a história.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Desbloqueie agora, no gancho, sem créditos de reação.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: unlocking
                      ? null
                      : authenticated
                          ? onUnlock
                          : onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  child: unlocking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          authenticated
                              ? 'Continuar · $unlockCost ${unlockCost == 1 ? 'moeda' : 'moedas'}'
                              : 'Entre para continuar',
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                authenticated
                    ? 'Você tem $availableCredits ${availableCredits == 1 ? 'moeda' : 'moedas'}'
                    : 'O gancho fica travado até o desbloqueio.',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
