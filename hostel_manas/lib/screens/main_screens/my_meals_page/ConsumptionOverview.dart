import 'package:flutter/material.dart';

class ConsumptionOverviewPage extends StatefulWidget {
  // Use 'final' for variables in a Widget class
  final String title;
  final String Type;

  // Standard Flutter constructor
  const ConsumptionOverviewPage({super.key, required this.title, required this.Type});

  @override
  State<ConsumptionOverviewPage> createState() =>
      _ConsumptionOverviewPageState();
}

class _ConsumptionOverviewPageState extends State<ConsumptionOverviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        // Access variables using 'widget.'
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text("Details for: ${widget.title}"),
      ),
    );
  }
}