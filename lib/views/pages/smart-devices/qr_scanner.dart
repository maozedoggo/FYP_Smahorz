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
  bool _cameraReady = false;

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
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
      _cameraReady = true;
    });

    controller.scannedDataStream.listen((scanData) {
      controller.pauseCamera();
      if (mounted) {
        Navigator.pop(context, scanData.code);
      }
    });

    // Initialize camera
    controller.resumeCamera();
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
          // QR View - Use ONLY the default overlay with proper styling
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.lightBlueAccent,
              borderRadius: 12,
              borderLength: 30,
              borderWidth: 4,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
              overlayColor: Colors.black.withOpacity(0.4), // Proper overlay color
            ),
          ),

          // REMOVED: _buildCustomOverlay() - This was causing the darkness

          // Scanner Animation
          _buildScannerAnimation(),

          // Instructions
          _buildInstructions(),

          // Flash Button - Centered at bottom
          _buildFlashButton(),

          // Loading indicator if camera is not ready
          if (!_cameraReady)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerAnimation() {
    final cutOutSize = MediaQuery.of(context).size.width * 0.7;
    final topPosition = (MediaQuery.of(context).size.height - cutOutSize) / 2;
    
    return Positioned(
      top: topPosition,
      left: MediaQuery.of(context).size.width * 0.15,
      child: Container(
        width: cutOutSize,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.lightBlueAccent,
              Colors.transparent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.lightBlueAccent.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 2,
            ),
          ],
        ),
        transform: Matrix4.translationValues(
          0,
          _animation.value * cutOutSize,
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
          color: Colors.black.withOpacity(0.3),
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
          onTap: () async {
            try {
              await controller?.toggleFlash();
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            } catch (e) {
              print('Flash error: $e');
            }
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _isFlashOn ? Colors.blueAccent : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFlashOn ? Colors.blueAccent : Colors.white.withOpacity(0.3),
              ),
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