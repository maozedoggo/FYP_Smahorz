import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
    _animationController.repeat();
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Scan QR Code",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0B1220),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // QR View
          QRView(
            key: qrKey,
            onQRViewCreated: (QRViewController c) {
              controller = c;
              c.scannedDataStream.listen((scanData) {
                controller?.pauseCamera();
                Navigator.pop(context, scanData.code);
              });
            },
            overlay: QrScannerOverlayShape(
              borderColor: Colors.transparent,
              borderRadius: 12,
              borderLength: 0,
              borderWidth: 0,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),

          // Custom Overlay
          _buildCustomOverlay(),

          // Scanner Animation
          _buildScannerAnimation(),

          // Instructions
          _buildInstructions(),

          // Flash Button - Centered at bottom
          _buildFlashButton(),
        ],
      ),
    );
  }

  Widget _buildCustomOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: _ScannerOverlayShape(
          cutOutSize: MediaQuery.of(context).size.width * 0.7,
        ),
      ),
    );
  }

  Widget _buildScannerAnimation() {
    return Positioned(
      top: (MediaQuery.of(context).size.height -
              MediaQuery.of(context).size.width * 0.7) /
          2,
      left: MediaQuery.of(context).size.width * 0.15,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.lightBlueAccent,
              Colors.transparent,
            ],
          ),
        ),
        transform: Matrix4.translationValues(
          0,
          _animation.value * MediaQuery.of(context).size.width * 0.55,
          0,
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Text(
          'Position QR code within the frame',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFlashButton() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Align(
        child: GestureDetector(
          onTap: () {
            controller?.toggleFlash();
            setState(() {
              _isFlashOn = !_isFlashOn;
            });
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(
              _isFlashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final double cutOutSize;

  const _ScannerOverlayShape({required this.cutOutSize});

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          const Radius.circular(12),
        ),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Draw outer darkened overlay
    final Paint paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(getOuterPath(rect), paint);

    // Draw scanner border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final borderRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(borderRect, const Radius.circular(12)),
      borderPaint,
    );

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;

    final cornerLength = 20.0;
    final borderRect2 = borderRect.deflate(1);

    // Top left corner
    canvas.drawLine(
      borderRect2.topLeft,
      borderRect2.topLeft + Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      borderRect2.topLeft,
      borderRect2.topLeft + Offset(0, cornerLength),
      cornerPaint,
    );

    // Top right corner
    canvas.drawLine(
      borderRect2.topRight,
      borderRect2.topRight - Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      borderRect2.topRight,
      borderRect2.topRight + Offset(0, cornerLength),
      cornerPaint,
    );

    // Bottom left corner
    canvas.drawLine(
      borderRect2.bottomLeft,
      borderRect2.bottomLeft + Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      borderRect2.bottomLeft,
      borderRect2.bottomLeft - Offset(0, cornerLength),
      cornerPaint,
    );

    // Bottom right corner
    canvas.drawLine(
      borderRect2.bottomRight,
      borderRect2.bottomRight - Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      borderRect2.bottomRight,
      borderRect2.bottomRight - Offset(0, cornerLength),
      cornerPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}