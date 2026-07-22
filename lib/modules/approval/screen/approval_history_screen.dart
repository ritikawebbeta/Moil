// lib/modules/approval/screen/approval_history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/app_config.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';

class ApprovalHistoryScreen extends StatefulWidget {
  const ApprovalHistoryScreen({super.key});

  @override
  State<ApprovalHistoryScreen> createState() => _ApprovalHistoryScreenState();
}

class _ApprovalHistoryScreenState extends State<ApprovalHistoryScreen> {
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      if (userJsonStr != null) {
        final userMap = jsonDecode(userJsonStr);
        return userMap['token'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/approvals/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _historyList = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Failed to load approval history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'Approval History',
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_historyList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const EmptyState(
            icon: Icons.history_rounded,
            title: 'No History',
            subtitle: 'You have not processed any approvals yet.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyList.length,
      itemBuilder: (context, index) {
        final item = _historyList[index];
        final isApproved = item['action']?.toString().toLowerCase() == 'approved';
        final isLeave = item['requestType']?.toString().toLowerCase() == 'leave';
        
        DateTime? actionDate;
        if (item['actionDate'] != null) {
          actionDate = DateTime.tryParse(item['actionDate'].toString());
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.cardBorder, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLeave ? AppColors.primary.withOpacity(0.12) : AppColors.officialTour.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLeave ? 'Leave Request' : 'Tour Request',
                        style: TextStyle(
                          color: isLeave ? AppColors.primary : AppColors.officialTour,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? AppColors.success.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['action'] ?? 'Approved',
                        style: TextStyle(
                          color: isApproved ? AppColors.success : AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Applicant', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text(
                      '${item['applicantName']} (${item['applicantId']})',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Request ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Expanded(
                      child: Text(
                        item['requestId'] ?? '-',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Action Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text(
                      actionDate != null ? DateFormat('dd-MM-yyyy HH:mm').format(actionDate.toLocal()) : '-',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                    ),
                  ],
                ),
                if (item['remarks'] != null && item['remarks'].toString().isNotEmpty) ...[
                  const Divider(height: 16, color: AppColors.cardBorder),
                  const Text('Remarks', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  const SizedBox(height: 3),
                  Text(
                    item['remarks'],
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
