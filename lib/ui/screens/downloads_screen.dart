
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../widgets/downloads/active_downloads_tab.dart';
import '../widgets/downloads/history_downloads_tab.dart';
import '../widgets/animated_button.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {

    
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatusIndicators(context),
          const SizedBox(height: 16),
          // Tab Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabSegmentedControl(),
          ),
          const SizedBox(height: 16),
          
          // Content View
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedIndex == 0 
                  ? const ActiveDownloadsTab() 
                  : const HistoryDownloadsTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Downloads',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.folder_open_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                onPressed: () {
                   // TODO: Open base download folder
                },
                tooltip: 'Open Downloads Folder',
              ),
              PopupMenuButton<String>(
                iconColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                color: Theme.of(context).cardColor,
                onSelected: (value) {
                  if (value == 'clear_finished') {
                    context.read<DownloadProvider>().clearCompleted();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear_finished',
                    child: Text('Clear Finished', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildSegmentTab('Active', 0),
          _buildSegmentTab('History', 1),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: AnimatedButton(
        onPressed: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatusIndicator(
                context, 
                label: 'Active', 
                count: provider.activeRunningCount,
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.downloading_rounded,
              ),
              const SizedBox(width: 12),
              _buildStatusIndicator(
                context, 
                label: 'Pending', 
                count: provider.pendingCount,
                color: Colors.orange,
                icon: Icons.hourglass_empty_rounded,
              ),
              const SizedBox(width: 12),
              _buildStatusIndicator(
                context, 
                label: 'Paused', 
                count: provider.pausedCount,
                color: Colors.grey,
                icon: Icons.pause_circle_outline_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(BuildContext context, {
    required String label, 
    required int count, 
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
