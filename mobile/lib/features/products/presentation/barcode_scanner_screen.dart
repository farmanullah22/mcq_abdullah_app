import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _torchOn = false;
  bool _finished = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_finished) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _finished = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(raw.trim());
  }

  Future<void> _pickFromGallery() async {
    if (_finished) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    _finished = true;
    try {
      final result = await _controller.analyzeImage(file.path);
      if (!mounted) return;
      final raw = result?.barcodes.firstOrNull?.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(raw.trim());
      } else {
        setState(() => _finished = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No barcode found in the selected image.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _finished = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read the image: $e')),
      );
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scanWindow = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 - 30),
            width: size.width * 0.72,
            height: size.height * 0.32,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _handleDetection,
                scanWindow: scanWindow,
                errorBuilder: (context, error) => _ErrorMessage(
                  error.errorCode,
                  onRetry: () => _controller.start(),
                ),
                placeholderBuilder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              if (scanWindow != Rect.zero)
                _ScanWindowOverlay(scanWindow: scanWindow),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan Barcode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                        onPressed: _toggleTorch,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Point the camera at the barcode',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Scan from Gallery'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanWindowOverlay extends StatelessWidget {
  const _ScanWindowOverlay({required this.scanWindow});

  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    const length = 26.0;
    const thickness = 4.0;
    final border = BorderSide(color: color, width: thickness);

    Widget corner(double left, double top, Border border) {
      return Positioned.fromRect(
        rect: Rect.fromLTWH(left, top, length, length),
        child: Container(decoration: BoxDecoration(border: border)),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: scanWindow,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 1),
              ),
            ),
          ),
          corner(scanWindow.left, scanWindow.top, Border(top: border, left: border)),
          corner(
            scanWindow.right - length,
            scanWindow.top,
            Border(top: border, right: border),
          ),
          corner(
            scanWindow.left,
            scanWindow.bottom - length,
            Border(left: border, bottom: border),
          ),
          corner(
            scanWindow.right - length,
            scanWindow.bottom - length,
            Border(right: border, bottom: border),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.code, {required this.onRetry});

  final MobileScannerErrorCode code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (code) {
      MobileScannerErrorCode.permissionDenied => (
          Icons.no_photography_outlined,
          'Camera permission is required to scan barcodes.\n'
              'Allow camera access in app settings, then try again.',
        ),
      MobileScannerErrorCode.unsupported => (
          Icons.videocam_off_outlined,
          'Barcode scanning is not supported on this device.',
        ),
      _ => (Icons.error_outline, 'Could not start the camera.'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}