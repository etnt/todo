import 'package:flutter/material.dart';

/// Clean banner displaying error messages with an optional Retry button and icon customization.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRateLimit = message.toLowerCase().contains('rate limit');

    final containerColor = isRateLimit
        ? Colors.amber.shade100
        : theme.colorScheme.errorContainer;
    final textColor = isRateLimit
        ? Colors.brown.shade900
        : theme.colorScheme.onErrorContainer;
    final iconColor = isRateLimit
        ? Colors.amber.shade900
        : theme.colorScheme.onErrorContainer;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: containerColor,
        child: Row(
          children: [
            Icon(
              isRateLimit ? Icons.timer_outlined : icon,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
