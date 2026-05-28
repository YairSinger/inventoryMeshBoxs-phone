import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../box_session_provider.dart';
import '../../protocol.dart';

class RegistrationOverlay extends StatefulWidget {
  const RegistrationOverlay({super.key});

  @override
  State<RegistrationOverlay> createState() => _RegistrationOverlayState();
}

class _RegistrationOverlayState extends State<RegistrationOverlay> {
  final TextEditingController _nameController = TextEditingController();
  bool _isNaming = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<BoxSessionProvider>(
      builder: (context, provider, child) {
        if (!provider.hasPendingTags || _isNaming) {
          return const SizedBox.shrink();
        }

        // We use a post-frame callback to show the dialog to avoid "build during build" errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isNaming && provider.hasPendingTags) {
            _showNamingDialog(context, provider);
          }
        });

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _showNamingDialog(BuildContext context, BoxSessionProvider provider) async {
    setState(() {
      _isNaming = true;
    });

    final tag = provider.pendingTags.first;
    _nameController.clear();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Tag Detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('UID: ${tag.uid}'),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Flashlight',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Ignore tag for now? Or just close. 
                // Architecture says we must name it to leave registration.
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                final status = await provider.namePendingTag(name);
                
                if (status == imb_ack_status.ack_ok) {
                  if (context.mounted) Navigator.of(context).pop();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to name tag: $status')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      setState(() {
        _isNaming = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
