import 'package:flutter/material.dart';

/// Reusable widget for displaying graceful error states across screens when
/// internet disconnection, slow network, request timeout, or Firebase failures occur.
class ErrorStateWidget extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String title;
  final String? message;

  const ErrorStateWidget({
    super.key,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.title = 'Unable to Load Data',
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final String errStr = error?.toString() ?? '';
    bool isNetworkErr = errStr.contains('SocketException') ||
        errStr.contains('network-request-failed') ||
        errStr.contains('ClientException') ||
        errStr.contains('Failed host lookup');
    bool isTimeout = errStr.contains('Timeout') || errStr.contains('deadline-exceeded');
    bool isFirebaseErr = errStr.contains('FirebaseError') || errStr.contains('permission-denied');

    String displayTitle = title;
    String displayMsg = message ?? 'An unexpected error occurred while fetching data.';
    IconData icon = Icons.cloud_off_rounded;

    if (isNetworkErr) {
      displayTitle = 'Internet Connection Lost';
      displayMsg = 'Please check your network connection and try again.';
      icon = Icons.wifi_off_rounded;
    } else if (isTimeout) {
      displayTitle = 'Request Timed Out';
      displayMsg = 'The server is taking too long to respond. Please retry.';
      icon = Icons.timer_off_rounded;
    } else if (isFirebaseErr) {
      displayTitle = 'Database Service Unavailable';
      displayMsg = 'Cloud services are temporarily unreachable. Please retry shortly.';
      icon = Icons.storage_rounded;
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(28.0),
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade50.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1193D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
