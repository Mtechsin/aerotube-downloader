import 'package:flutter/material.dart';
import '../../models/video_info.dart';

class FormatSelector extends StatelessWidget {
  final List<FormatInfo> formats;
  final FormatInfo selectedFormat;
  final ValueChanged<FormatInfo> onFormatSelected;

  const FormatSelector({
    super.key,
    required this.formats,
    required this.selectedFormat,
    required this.onFormatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Audio Quality'),
          trailing: DropdownButton<FormatInfo>(
            value: selectedFormat,
            items: formats.map((format) {
              return DropdownMenuItem<FormatInfo>(
                value: format,
                child: Text(format.qualityLabel),
              );
            }).toList(),
            onChanged: (format) {
              if (format != null) {
                onFormatSelected(format);
              }
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: formats.length,
            itemBuilder: (context, index) {
              final format = formats[index];
              return ListTile(
                title: Text(format.qualityLabel),
                subtitle: Text('${format.extension} • ${format.formattedFilesize}'),
                trailing: format.audioBitrate != null
                    ? Text('${format.audioBitrate} kbps')
                    : const Icon(Icons.video_file),
                selected: format == selectedFormat,
                onTap: () => onFormatSelected(format),
              );
            },
          ),
        ),
      ],
    );
  }
}