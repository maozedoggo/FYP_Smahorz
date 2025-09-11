import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ViewDevices extends StatelessWidget {
  final String deviceType;
  final String devicePart;
  final String iconPath;
  final bool status;
  void Function(bool)? onChanged;

  ViewDevices({
    super.key,
    required this.deviceType,
    required this.devicePart,
    required this.iconPath,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              //Type of Devices
              Text(
                deviceType,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),

              //Icons
              Image.asset(iconPath, height: 65),

              //Part of Devices
              Padding(
                padding: const EdgeInsets.only(left: 15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        devicePart,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    CupertinoSwitch(value: status, onChanged: onChanged),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
