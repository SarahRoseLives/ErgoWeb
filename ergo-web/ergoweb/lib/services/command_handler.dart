import 'package:ergoweb/commands/join_command.dart';
import 'package:ergoweb/commands/part_command.dart';
import 'package:ergoweb/commands/slash_command.dart';
import 'package:ergoweb/models/irc_role.dart';
import 'package:ergoweb/viewmodels/chat_controller.dart';
import 'package:ergoweb/commands/command_context.dart';

class CommandHandler {
  final Map<String, SlashCommand> _commands = {};

  void registerCommands() {
    final commandList = [
      JoinCommand(),
      PartCommand(),
      // To add a new op-only command, you would just add it here:
      // KickCommand(),
    ];

    for (final command in commandList) {
      _commands[command.name.toLowerCase()] = command;
    }
  }

  /// This will be used for the autocomplete UI.
  List<SlashCommand> getAvailableCommandsForRole(IrcRole userRole) {
    return _commands.values
        .where((cmd) => userRole.index >= cmd.requiredRole.index)
        .toList();
  }

  Future<void> handleCommand(
      String commandText, ChatController controller) async {
    final parts = commandText.substring(1).split(' ');
    final commandName = parts[0].toLowerCase();
    final args = parts.skip(1).join(' ').trim();

    final command = _commands[commandName];
    final chatState = controller.chatState;
    final currentChannel = chatState.selectedConversationTarget;

    if (command == null) {
      chatState.addSystemMessage(
        currentChannel,
        'Unknown command: /$commandName',
      );
      return;
    }

    final userRole = controller.getCurrentUserRoleInChannel(currentChannel);

    // Check if the user's role index is >= the required role's index.
    // This works because the IrcRole enum is ordered from least to most privileged.
    if (userRole.index >= command.requiredRole.index) {
      final context = CommandContext(
        controller: controller,
        args: args,
        userRole: userRole,
      );
      await command.execute(context);
    } else {
      chatState.addSystemMessage(
        currentChannel,
        "You do not have permission to use the '/$commandName' command.",
      );
    }
  }
}