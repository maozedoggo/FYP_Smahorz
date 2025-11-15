import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code", style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF0B1220),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.arrow_back_ios_new, color: Colors.white,)),
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (QRViewController c) {
          controller = c;

          c.scannedDataStream.listen((scanData) {
            controller?.pauseCamera();
            Navigator.pop(context, scanData.code); // return scanned ID
          });
        },
      ),
    );
  }
}
