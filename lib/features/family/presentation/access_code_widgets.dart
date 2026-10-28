import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../domain/access_code.dart';

class ApprovedCode extends StatefulWidget {
  const ApprovedCode({
    required this.code,
    required this.child,
    required this.expiresAt,
    super.key,
  });
  final String code;
  final bool child;
  final DateTime expiresAt;
  @override
  State<ApprovedCode> createState() => _ApprovedCodeState();
}

class _ApprovedCodeState extends State<ApprovedCode> {
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    final remaining = widget.expiresAt.difference(DateTime.now());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expiresAt.isAfter(DateTime.now())) {
      return const Text(
        'This code expired. Return to the home team to approve a new one.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.child ? 'A little independence.' : 'Room for one more.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          widget.child
              ? 'On the supervised device, choose “Link a child device” and scan or paste this code. It links only the child profile you approved.'
              : 'Give this code privately to the adult you invited. They must sign in with the invited email, then choose “Join a household”.',
        ),
        const SizedBox(height: 12),
        Text(
          'Expires at ${TimeOfDay.fromDateTime(widget.expiresAt.toLocal()).format(context)}. One use. Keep this code private. You can revoke it in access controls.',
        ),
        const SizedBox(height: 20),
        Center(
          child: QrImageView(
            data: widget.code,
            size: 220,
            backgroundColor: Colors.white,
            semanticsLabel: 'One-use household access code. A copy button is available below.',
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(widget.code),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('One-use code copied.')),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy code'),
        ),
      ],
    );
  }
}

class AccessCodeScanner extends StatefulWidget {
  const AccessCodeScanner({required this.onCode, super.key});
  final ValueChanged<String> onCode;
  @override
  State<AccessCodeScanner> createState() => _AccessCodeScannerState();
}

class _AccessCodeScannerState extends State<AccessCodeScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    returnImage: false,
  );
  bool _sent = false;
  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: MobileScanner(
      controller: _controller,
      useAppLifecycleState: true,
      onDetect: (capture) {
        if (_sent) return;
        for (final barcode in capture.barcodes) {
          final code = parseAccessCode(barcode.rawValue ?? '');
          if (code != null) {
            _sent = true;
            widget.onCode(code);
            return;
          }
        }
      },
      errorBuilder: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Camera unavailable or permission denied. You can paste the code instead.',
          ),
        ),
      ),
    ),
  );
}
