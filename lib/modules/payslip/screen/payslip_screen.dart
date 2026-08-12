import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_config.dart';
import '../../../utils/api_client.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  List<Map<String, dynamic>> _payslips = [];
  String? _selectedMonth;
  bool _isLoadingPayslips = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPayslipsFromApi();
    });
  }

  Future<void> _fetchPayslipsFromApi() async {
    setState(() => _isLoadingPayslips = true);
    try {
      final auth = context.read<AuthController>();
      final empId = auth.user?.employeeId ?? '';
      final cleanId = empId.trim().replaceAll(RegExp('^0+'), '');

      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/payslips?employee_id=$cleanId'),
      );

      if (response.statusCode == 200) {
        final List decoded = jsonDecode(response.body);
        if (decoded.isNotEmpty) {
          final List<Map<String, dynamic>> fetchedList = [];
          for (final item in decoded) {
            fetchedList.add({
              'month': item['formattedPeriod'] ?? item['monthName'] ?? 'Payslip',
              'fileName': item['fileName'],
              'downloadUrl': item['downloadUrl'],
            });
          }
          setState(() {
            _payslips = fetchedList;
            _selectedMonth = _payslips.first['month'];
          });
        } else {
          setState(() {
            _payslips = [];
            _selectedMonth = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching payslips list: $e');
    } finally {
      setState(() => _isLoadingPayslips = false);
    }
  }

  /// Fetch PDF bytes — tries the static public URL first (fastest, served by Nginx)
  /// then falls back to the API download route.
  Future<Uint8List> _getPdfBytes(Map<String, dynamic> payslip) async {
    final String? downloadUrl = payslip['downloadUrl'];
    final String? fileName = payslip['fileName'];

    // Attempt 1: static public URL
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse(downloadUrl),
          headers: {'Accept': 'application/pdf, */*'},
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200 && res.bodyBytes.length > 100) {
          final header = String.fromCharCodes(res.bodyBytes.take(4));
          if (header == '%PDF') {
            debugPrint('✅ Loaded PDF from static URL: $downloadUrl (${res.bodyBytes.length} bytes)');
            return res.bodyBytes;
          }
        }
      } catch (e) {
        debugPrint('Static URL fetch error: $e');
      }
    }

    // Attempt 2: Backend API download route
    if (fileName != null && fileName.isNotEmpty) {
      final String apiUrl = '${AppConfig.baseUrl}/api/payslips/download/$fileName';
      try {
        final res = await http.get(
          Uri.parse(apiUrl),
          headers: {'Accept': 'application/pdf, */*'},
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200 && res.bodyBytes.length > 100) {
          final header = String.fromCharCodes(res.bodyBytes.take(4));
          if (header == '%PDF') {
            debugPrint('✅ Loaded PDF from API route: $apiUrl (${res.bodyBytes.length} bytes)');
            return res.bodyBytes;
          }
        }
      } catch (e) {
        debugPrint('API route fetch error: $e');
      }
    }

    throw Exception('Unable to load payslip PDF. Please check server availability.');
  }

  Future<void> _downloadPayslip(Map<String, dynamic> payslip) async {
    try {
      final pdfBytes = await _getPdfBytes(payslip);
      final String filename = payslip['fileName'] ?? '${payslip['month'].toString().replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPayslip = _payslips.isNotEmpty
        ? _payslips.firstWhere(
            (p) => p['month'] == _selectedMonth,
            orElse: () => _payslips.first,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Payslip',
        showBack: Navigator.of(context).canPop(),
        actions: currentPayslip != null
            ? [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                  onPressed: () => _downloadPayslip(currentPayslip),
                  tooltip: 'Download PDF',
                ),
              ]
            : null,
      ),
      body: _isLoadingPayslips
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchPayslipsFromApi,
              child: _payslips.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No payslips available on server for this employee.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: _fetchPayslipsFromApi,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Check Server Again', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Month Selector Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: AppColors.cardBg,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Select Month:',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Refresh payslip list',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: _fetchPayslipsFromApi,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedMonth,
                                    dropdownColor: AppColors.cardBg,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: _payslips.map((p) {
                                      return DropdownMenuItem<String>(
                                        value: p['month'],
                                        child: Text(p['month']),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedMonth = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.cardBorder),

                        // Payslip count info bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          color: AppColors.primary.withOpacity(0.06),
                          child: Text(
                            '${_payslips.length} payslip${_payslips.length > 1 ? 's' : ''} available on server  •  Pull down to refresh',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // PDF Viewer Area
                        Expanded(
                          child: FutureBuilder<Uint8List>(
                            future: currentPayslip != null ? _getPdfBytes(currentPayslip) : null,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: AppColors.primary),
                                      SizedBox(height: 12),
                                      Text('Loading payslip PDF...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                );
                              }

                              if (snapshot.hasError || !snapshot.hasData) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Failed to load payslip PDF',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${snapshot.error ?? "File unreadable"}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                          onPressed: () => setState(() {}),
                                          icon: const Icon(Icons.refresh, color: Colors.white),
                                          label: const Text('Retry Loading', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return PdfPreview(
                                build: (format) => snapshot.data!,
                                allowPrinting: false,
                                allowSharing: false,
                                canChangePageFormat: false,
                                canChangeOrientation: false,
                                maxPageWidth: 700,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
