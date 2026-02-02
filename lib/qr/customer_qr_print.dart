import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:reward_token_app/app_config.dart';
import 'package:reward_token_app/state/customer_store.dart';

class CustomerQrPrint {
  static Future<void> printCustomerCard(
    Customer customer, {
    String companyName = AppConfig.companyName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: 340,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2, color: PdfColors.grey700),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    companyName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    customer.fullName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
                      data: customer.uuid,
                      width: 220,
                      height: 220,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    customer.uuid,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
    );
  }
}
