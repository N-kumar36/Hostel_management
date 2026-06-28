import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as crosspw;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../services/api_service.dart';

class FinanceController {
  final ApiService api = ApiService();

  bool isLoading = false;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();

  int totalMealsServed = 0;
  double totalCollections = 0.0;
  double totalExpenses = 0.0;
  double netBalance = 0.0;
  int currentActiveCycleNumber = 1;

  final DateTime firstAvailableMealDate = DateTime(2026, 1, 1);
  final DateTime lastAvailableMealDate = DateTime.now();

  List<dynamic> studentUsageList = [];
  List<dynamic> expenseItemsList = [];
  List<dynamic> calculatedCyclesList = [];

  Future<void> initialize(VoidCallback updateState) async {
    isLoading = true;
    updateState();
    try {
      final response = await api.getMealCycleDateBounds();
      if (response['success'] == true) {
        calculatedCyclesList = response['cycles'] ?? [];
        if (calculatedCyclesList.isNotEmpty) {
          final liveCycle = calculatedCyclesList.firstWhere(
            (c) => c['isCurrentActive'] == true,
            orElse: () => calculatedCyclesList.first,
          );
          startDate = DateFormat('dd/MM/yyyy').parse(liveCycle['startDateStr']);
          endDate = DateFormat('dd/MM/yyyy').parse(liveCycle['endDateStr']);
          currentActiveCycleNumber = liveCycle['cycleIndex'] ?? 1;
        }
      }
    } catch (e) {
      debugPrint("Error processing cycles list: $e");
    }
    await fetchFinancialData(updateState, (msg) {});
  }

  Future<void> fetchFinancialData(
    VoidCallback updateState,
    Function(String) onError,
  ) async {
    isLoading = true;
    updateState();

    String startFormatted = DateFormat('dd/MM/yyyy').format(startDate);
    String endFormatted = DateFormat('dd/MM/yyyy').format(endDate);

    try {
      final response = await api.getFinanceAuditReport(
        startFormatted,
        endFormatted,
      );
      if (response['success'] == true) {
        final summary = response['summary'] ?? {};
        totalMealsServed = summary['mealsServed'] ?? 0;
        totalCollections = (summary['totalCollections'] ?? 0.0).toDouble();
        totalExpenses = (summary['totalExpenses'] ?? 0.0).toDouble();
        netBalance = (summary['netPoolBalance'] ?? 0.0).toDouble();
        studentUsageList = response['studentUsage'] ?? [];
        expenseItemsList = response['procurementItems'] ?? [];
      } else {
        onError(response['message'] ?? "Failed to retrieve metrics.");
      }
    } catch (e) {
      onError("Error connecting to database audit service: $e");
    } finally {
      isLoading = false;
      updateState();
    }
  }

  void selectCycle(
    dynamic cycle,
    VoidCallback updateState,
    Function(String) onError,
  ) {
    startDate = DateFormat('dd/MM/yyyy').parse(cycle['startDateStr']);
    endDate = DateFormat('dd/MM/yyyy').parse(cycle['endDateStr']);
    currentActiveCycleNumber = cycle['cycleIndex'] ?? 1;
    fetchFinancialData(updateState, onError);
  }

  void selectCustomRange(
    DateTimeRange range,
    VoidCallback updateState,
    Function(String) onError,
  ) {
    startDate = range.start;
    endDate = range.end;
    fetchFinancialData(updateState, onError);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    final String dateStr =
        "${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Title block banner
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Hostel Mess Financial Audit Statement",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Operational Cycle Timeline Block Scope: $dateStr",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
            pw.SizedBox(height: 16),

            // Financial Cards Grid Box Mock
            pw.Text(
              "Summary Metrics Overview",
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 0.28,
              children: [
                _buildPdfMetricTile(
                  "TOTAL INFLOW FUNDS",
                  "Rs. ${totalCollections.toStringAsFixed(2)}",
                  PdfColors.green700,
                ),
                _buildPdfMetricTile(
                  "TOTAL OUTFLOW PROCUREMENT",
                  "Rs. ${totalExpenses.toStringAsFixed(2)}",
                  PdfColors.orange700,
                ),
                _buildPdfMetricTile(
                  "NET POOL BALANCE CASH",
                  "Rs. ${netBalance.toStringAsFixed(2)}",
                  PdfColors.indigo700,
                ),
                _buildPdfMetricTile(
                  "TOTAL SERVICE COUNTS",
                  "$totalMealsServed Plates served",
                  PdfColors.blueGrey700,
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Section 1: Students
            pw.Text(
              "Student Meal Accounts & Verification Ledger",
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Student Name',
                'Billing Item Info',
                'Meals Consumed',
                'Amount',
                'Verification Status',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo900,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              data: studentUsageList
                  .map(
                    (st) => [
                      st['name'],
                      st['title'] ?? 'N/A',
                      "${st['consumed'] ?? 0} Meals",
                      "Rs. ${st['amount']}",
                      st['status'].toString().toUpperCase(),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 28),

            // Section 2: Procurement
            pw.Text(
              "Procurement List & Inventory Deductions Ledger",
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Procured Item Name',
                'Item Description Specifications',
                'Purchase State',
                'Buyer Context',
                'Deduction Cost',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              data: expenseItemsList
                  .map(
                    (item) => [
                      item['name'],
                      item['description'] ?? 'No description supplied',
                      item['isBought'] == true ? "BOUGHT" : "PENDING ITEM",
                      item['createdBy'] ?? 'Manager',
                      "Rs. ${item['price']}",
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildPdfMetricTile(
    String label,
    String value,
    PdfColor textColor,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
