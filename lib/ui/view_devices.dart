import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ViewDevices extends StatelessWidget {
  final String deviceType;
  final String devicePart;
  final String iconPath;
  final bool status;
  final void Function(bool)? onChanged;

  const ViewDevices({
    super.key,
    required this.deviceType,
    required this.devicePart,
    required this.iconPath,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final deviceFontSize = screenWidth * 0.045;
    final partFontSize = screenWidth * 0.035;
    final iconSize = screenWidth * 0.15;

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.03),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.2),
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(255, 255, 255, 0.2),
                  blurRadius: 10,
                  offset: Offset(0, screenHeight * 0.01),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.02,
              horizontal: screenWidth * 0.03,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  deviceType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: deviceFontSize,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        blurRadius: 3,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                Image.asset(iconPath, height: iconSize, color: Colors.white),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        devicePart,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: partFontSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: status,
                      onChanged: onChanged,
                      activeTrackColor: Colors.tealAccent,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
