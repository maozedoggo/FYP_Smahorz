import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class SchedulePage extends StatefulWidget {
  final String deviceName;

  const SchedulePage({super.key, required this.deviceName});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.black,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            Align(
              child: Text(
                widget.deviceName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // Calendar
            TableCalendar(
              focusedDay: DateTime.now(),
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2050, 12, 31),
              calendarFormat:
                  CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              daysOfWeekVisible: true,

              headerStyle: const HeaderStyle(
                formatButtonVisible:
                    false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(color: Colors.red),
                defaultTextStyle: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
