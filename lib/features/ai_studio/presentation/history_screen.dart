import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/ai_studio_models.dart';
import '../../../services/api_client.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<Map<String, dynamic>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _refreshJobs();
  }

  void _refreshJobs() {
    setState(() {
      _jobsFuture = ref.read(apiClientProvider).getAiJobs();
    });
  }

  Future<void> _retryFailedItems(String jobId) async {
    try {
      await ref.read(apiClientProvider).retryAiJob(jobId);
      _showSnackbar('Retry started for failed items', isError: false);
      _refreshJobs();
    } catch (e) {
      _showSnackbar('Failed to retry items: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI EDIT HISTORY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshJobs,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final jobs = (snapshot.data?['jobs'] as List? ?? []).map((e) => AiEditJob.fromJson(e)).toList();
          if (jobs.isEmpty) {
            return const Center(child: Text('No AI jobs found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _JobCard(
                job: job, 
                onRetryFailed: () => _retryFailedItems(job.id),
                onTap: () {
                  // context.push('/ai-studio/history/${job.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final AiEditJob job;
  final VoidCallback onRetryFailed;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.onRetryFailed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFailed = job.failedCount > 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      job.type.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(color: AppTheme.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().add_jm().format(job.createdAt),
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.prompt ?? 'No prompt provided',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStat(context, 'Total', job.itemCount.toString(), Colors.blueGrey),
                  const SizedBox(width: 16),
                  _buildStat(context, 'Success', job.successCount.toString(), Colors.green),
                  const SizedBox(width: 16),
                  _buildStat(context, 'Failed', job.failedCount.toString(), Colors.redAccent),
                  const Spacer(),
                  _StatusBadge(status: job.status),
                ],
              ),
              if (hasFailed && job.status != 'running') ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRetryFailed,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('RETRY FAILED ITEMS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textGrey)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed': color = Colors.green; break;
      case 'failed': color = Colors.red; break;
      case 'running': color = Colors.blue; break;
      case 'pending': color = Colors.orange; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

