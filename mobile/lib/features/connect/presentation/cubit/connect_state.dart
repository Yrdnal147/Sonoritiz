import 'package:equatable/equatable.dart';
import '../../../player/data/models/track_model.dart';

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
  final List<Map<String, dynamic>> suggestionThreads;
  final String sharedPlaylistTitle;
  final List<TrackModel> sharedQueue;
  final int maxParticipants;
  final String connectionStatus;
  final String? actionError;

  const ConnectActive({
    required this.sessionId,
    required this.inviteCode,
    required this.isHost,
    required this.participants,
    this.reactions = const [],
    this.suggestions = const [],
    this.suggestionThreads = const [],
    this.sharedPlaylistTitle = 'File du salon',
    this.sharedQueue = const [],
    this.maxParticipants = 20,
    this.connectionStatus = 'connected',
    this.actionError,
  });

  ConnectActive copyWith({
    List<Map<String, dynamic>>? participants,
    List<Map<String, dynamic>>? reactions,
    List<Map<String, dynamic>>? suggestions,
    List<Map<String, dynamic>>? suggestionThreads,
    String? sharedPlaylistTitle,
    List<TrackModel>? sharedQueue,
    int? maxParticipants,
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
      suggestionThreads: suggestionThreads ?? this.suggestionThreads,
      sharedPlaylistTitle: sharedPlaylistTitle ?? this.sharedPlaylistTitle,
      sharedQueue: sharedQueue ?? this.sharedQueue,
      maxParticipants: maxParticipants ?? this.maxParticipants,
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
        suggestionThreads,
        sharedPlaylistTitle,
        sharedQueue,
        maxParticipants,
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
