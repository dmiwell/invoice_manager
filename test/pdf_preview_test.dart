// Temporary helper test: renders a sample invoice PDF to /tmp for visual
// inspection. Run with: flutter test test/pdf_preview_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_manager/models/models.dart';
import 'package:invoice_manager/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render sample invoice PDF', () async {
    final contractor = Contractor(
      id: 'c1',
      abbr: 'JD',
      fullName: 'John Doe',
      contractorInfo: '782 Riverside Avenue\nOttawa, ON K1G 3W4\nCanada',
      paymentInfo: '**Please pay by bank transfer:**\n'
          'Bank Name: *Royal Bank of Canada (RBC)*\n'
          'Account Holder: *John Doe*\n'
          'Account Number: *123456789*',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    final company = Company(
      id: 'co1',
      name: 'Lorem Ipsum Inc',
      abbr: 'LI',
      companyInfo: '1250 York Tech Park, Suite 400\nToronto, ON M4B 2Y7\nCanada',
      updatedAt: DateTime(2024, 1, 1),
    );
    final contract = Contract(
      id: 'ct1',
      contractor: contractor,
      company: company,
      date: DateTime(2024, 6, 1),
      fixed: false,
      showPeriod: true,
      description: 'Lead Software Development',
    );
    final invoice = Invoice(
      id: 'INV-TEST',
      contract: contract,
      date: DateTime(2024, 9, 5),
      dueDate: DateTime(2024, 9, 19),
      status: InvoiceStatus.sent,
      items: [
        InvoiceItem(
          id: 'i1',
          description: 'Mobile App Development - Q3 Sprint',
          period: 'September 2024',
          quantity: 120.5,
          price: 95.0,
        ),
      ],
    );

    Directory('/tmp/swtest').createSync(recursive: true);
    final bytes = await InvoicePdfService.generatePdfBytes(invoice);
    File('/tmp/swtest/sample_invoice.pdf').writeAsBytesSync(bytes);

    // Variant with an explicit contract ID.
    final invoice2 = Invoice(
      id: 'INV-TEST-2',
      contract: contract.copyWith(contractId: 'CT-2024-042'),
      date: DateTime(2024, 9, 5),
      dueDate: DateTime(2024, 9, 19),
      status: InvoiceStatus.sent,
      items: invoice.items,
    );
    final bytes2 = await InvoicePdfService.generatePdfBytes(invoice2);
    File('/tmp/swtest/sample_invoice_ctid.pdf').writeAsBytesSync(bytes2);

    expect(bytes, isNotEmpty);
  });
}
