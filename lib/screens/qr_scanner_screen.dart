import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';
import 'add_contact_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isScanning = true;

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && (rawValue.startsWith('Twibee://user/') || rawValue.startsWith('Twibee://link'))) {
        setState(() {
          isScanning = false;
        });
        controller.stop();
        
        try {
          if (rawValue.startsWith('Twibee://link')) {
            // Found a Web Linking QR code
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Web Login successful! (Coming Soon)'),
                  backgroundColor: AppColors.orange,
                ),
              );
            }
            return;
          } else if (rawValue.startsWith('Twibee://user/')) {
            final uri = Uri.parse(rawValue);
            final userId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
            final name = uri.queryParameters['name'] ?? 'Unknown User';
            final phone = uri.queryParameters['phone'] ?? '';
            
            if (userId != null && userId.isNotEmpty) {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddContactScreen(
                      initialName: name,
                      initialPhone: phone,
                    ),
                  ),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Error parsing QR Code: $e');
        }
        
        // If parsing fails or not valid
        setState(() {
          isScanning = true;
        });
        controller.start();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TwibeeAppBar(
        title: 'Scan QR Code',
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // Simple scanner overlay
          Container(
            decoration: const ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppColors.orange,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            child: Text(
              'Align QR code within the frame to scan',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          )
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final double _cutOutSize = this.cutOutSize < width ? this.cutOutSize : width - borderOffset;
    final double _borderLength = this.borderLength > _cutOutSize / 2 + borderOffset
        ? _cutOutSize / 2 + borderOffset
        : this.borderLength;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      // Draw top right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - _borderLength,
          cutOutRect.top,
          cutOutRect.right,
          cutOutRect.top + _borderLength,
          topRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw top left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + _borderLength,
          cutOutRect.top + _borderLength,
          topLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - _borderLength,
          cutOutRect.bottom - _borderLength,
          cutOutRect.right,
          cutOutRect.bottom,
          bottomRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.bottom - _borderLength,
          cutOutRect.left + _borderLength,
          cutOutRect.bottom,
          bottomLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}

