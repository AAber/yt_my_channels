import 'package:flutter/material.dart';
import '../screens/channel_picker_screen.dart';

class EditButton extends StatelessWidget {
  const EditButton({super.key});

  void _goToManageChannels(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => const ChannelPickerScreen(isAddMode: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => _goToManageChannels(context),
    );
  }
}