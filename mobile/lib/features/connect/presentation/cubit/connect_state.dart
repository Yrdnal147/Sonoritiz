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
  final String connectionStatus;
  final String? actionError;

  const ConnectActive({
    required this.sessionId,
    required this.inviteCode,
    required this.isHost,
    required this.participants,
    this.connectionStatus = 'connecting',
    this.actionError,
  });

  ConnectActive copyWith({
    List<Map<String, dynamic>>? participants,
    String? connectionStatus,
  }) {
    return ConnectActive(
      sessionId: sessionId,
      inviteCode: inviteCode,
      isHost: isHost,
      participants: participants ?? this.participants,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      actionError: actionError ?? this.actionError,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        inviteCode,
        isHost,
        participants,
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
