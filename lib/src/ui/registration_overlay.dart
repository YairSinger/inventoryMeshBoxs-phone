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

  bool _isWriting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<BoxSessionProvider>(
      builder: (context, provider, child) {
        if (!provider.hasPendingTags || (_isNaming && !_isWriting)) {
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
      _isWriting = false;
    });

    final tag = provider.pendingTags.first;
    _nameController.clear();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                    enabled: !_isWriting,
                  ),
                  if (_isWriting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Hold tag against the reader. Waiting for write...', style: TextStyle(color: Colors.teal, fontStyle: FontStyle.italic, fontSize: 12)),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isWriting ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: _isWriting ? null : () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;

                    setStateDialog(() {
                      _isWriting = true;
                    });

                    final status = await provider.namePendingTag(name);
                    
                    if (context.mounted) {
                      if (status == imb_ack_status.ack_ok) {
                        Navigator.of(context).pop();
                      } else if (status == imb_ack_status.ack_ndef_write_failed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to write. Timeout reached.')),
                        );
                        setStateDialog(() {
                          _isWriting = false;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Registration failed: $status')),
                        );
                        Navigator.of(context).pop(); // Dismiss on fatal error so we don't get stuck
                      }
                    }
                  },
                  child: Text(_isWriting ? 'WRITING...' : 'SAVE'),
                ),
              ],
            );
          }
        );
      },
    );

    if (mounted) {
      setState(() {
        _isNaming = false;
        _isWriting = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
