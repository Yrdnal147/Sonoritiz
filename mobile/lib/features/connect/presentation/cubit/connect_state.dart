import 'package:equatable/equatable.dart';

abstract class ConnectState extends Equatable {
  const ConnectState();

  @override
  List<Object?> get props => [];
}

class ConnectInitial extends ConnectState {}

class ConnectLoading extends ConnectState {}

class ConnectActive extends ConnectState {
  final int sessionId;
  final String inviteCode;
  final bool isHost;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> reactions;
  final List<Map<String, dynamic>> suggestions;
  final String connectionStatus;
  final String? actionError;

  const ConnectActive({
    required this.sessionId,
    required this.inviteCode,
    required this.isHost,
    required this.participants,
    this.reactions = const [],
    this.suggestions = const [],
    this.connectionStatus = 'connected',
    this.actionError,
  });

  ConnectActive copyWith({
    List<Map<String, dynamic>>? participants,
    List<Map<String, dynamic>>? reactions,
    List<Map<String, dynamic>>? suggestions,
    String? connectionStatus,
    String? actionError,
  }) {
    return ConnectActive(
      sessionId: sessionId,
      inviteCode: inviteCode,
      isHost: isHost,
      participants: participants ?? this.participants,
      reactions: reactions ?? this.reactions,
      suggestions: suggestions ?? this.suggestions,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        inviteCode,
        isHost,
        participants,
        reactions,
        suggestions,
        connectionStatus,
        actionError,
      ];
}

class ConnectError extends ConnectState {
  final String message;

  const ConnectError(this.message);

  @override
  List<Object?> get props => [message];
}
