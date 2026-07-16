import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:oksigen24medis_mobile2/features/payment/receipt_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  Future<bool> shareInvoicePdf({
    required String invoiceNo,
    required String customerName,
    required String cashierName,
    required List<ReceiptItem> receiptItems,
    required String paymentMethod,
    required int totalTagihan,
    required int receivedAmount,
    required int change,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('receipt_shop_name') ?? 'OKSIGEN MEDIS 24 JAM';
      final shopAddress = prefs.getString('receipt_shop_address') ?? 'Dusun Sembon, Sembon, Kec. Karangrejo\nKabupaten Tulungagung, Jawa Timur 66253\nTelp: 085866972209 / 085733930575';
      String finalShopAddress = shopAddress;
      if (!shopAddress.contains('085866972209') && !shopAddress.contains('085733930575')) {
        finalShopAddress = '$shopAddress\nTelp: 085866972209 / 085733930575';
      }
      final footer = prefs.getString('receipt_footer') ?? 'Terima Kasih atas Kepercayaan Anda!';
      final showLogo = prefs.getBool('receipt_show_logo') ?? true;

      final pdf = pw.Document();

      // Load logo image
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

      // Formatter helper
      String formatNumber(int val) {
        return val.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (showLogo)
                            pw.Image(logoImage, height: 45)
                          else
                            pw.Text(
                              shopName,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF0055FF),
                              ),
                            ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            finalShopAddress,
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'INVOICE',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0055FF),
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFF1F5F9),
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              invoiceNo,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                  pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFFE2E8F0)),
                  pw.SizedBox(height: 20),

                  // Metadata Info
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Client Details
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 3,
                              height: 38,
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF0055FF),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DIBAYAR KEPADA:',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B)),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  customerName,
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Pelanggan Setia Oksigen Medis 24',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Transaction Details
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  'DETAIL TRANSAKSI:',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B)),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Tanggal: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF334155)),
                                ),
                                pw.Text(
                                  'Metode: $paymentMethod',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF334155)),
                                ),
                                pw.Text(
                                  'Kasir: $cashierName',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF334155)),
                                ),
                              ],
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              width: 3,
                              height: 38,
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF0055FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 24),

                  // Items Table
                  pw.Table(
                    border: const pw.TableBorder(
                      horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                      bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF0055FF), width: 1.5),
                    ),
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0055FF)),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: pw.Text('Deskripsi Item', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: pw.Text('Harga Satuan', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: pw.Text('Qty', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: pw.Text('Total', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      ),
                      // Data Rows
                      ...receiptItems.map((item) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF334155))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: pw.Text('Rp ${formatNumber(item.price)}', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF334155)), textAlign: pw.TextAlign.right),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: pw.Text('${item.quantity}x', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF334155)), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: pw.Text('Rp ${formatNumber(item.price * item.quantity)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)), textAlign: pw.TextAlign.right),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Summary Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 220,
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFF8FAFC),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Total Tagihan:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF334155))),
                                pw.Text('Rp ${formatNumber(totalTagihan)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Diterima:', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.Text('Rp ${formatNumber(receivedAmount)}', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF334155))),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            pw.Divider(color: const PdfColor.fromInt(0xFFE2E8F0), thickness: 0.5),
                            pw.SizedBox(height: 6),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Kembali:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF00A67E))),
                                pw.Text('Rp ${formatNumber(change)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF00A67E))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 48),

                  // Footer Notes
                  pw.Divider(thickness: 0.5, color: const PdfColor.fromInt(0xFFE2E8F0)),
                  pw.SizedBox(height: 16),
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          footer.replaceAll('\n', ' '),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic, color: const PdfColor.fromInt(0xFF0F172A)),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Struk ini merupakan bukti pembayaran resmi yang sah.',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      
      // Open native OS share dialog with generated PDF bytes
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Invoice_${invoiceNo.replaceAll('/', '-')}.pdf',
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
