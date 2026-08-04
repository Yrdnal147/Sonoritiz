class LrcLine {
  final Duration time;
  final String text;

  LrcLine({required this.time, required this.text});
}

class LyricsModel {
  final String? plainLyrics;
  final String? syncedLyrics;
  final List<LrcLine>? parsedSyncedLyrics;

  LyricsModel({
    this.plainLyrics,
    this.syncedLyrics,
  }) : parsedSyncedLyrics = _parseLrc(syncedLyrics);

  bool get hasSynced => parsedSyncedLyrics != null && parsedSyncedLyrics!.isNotEmpty;
  bool get hasPlain => plainLyrics != null && plainLyrics!.isNotEmpty;

  static List<LrcLine>? _parseLrc(String? lrcText) {
    if (lrcText == null || lrcText.trim().isEmpty) return null;
    
    final lines = lrcText.split('\n');
    final List<LrcLine> result = [];
    
    // Extrait [mm:ss.xx]
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        
        final msString = match.group(3)!;
        final ms = msString.length == 2 ? int.parse(msString) * 10 : int.parse(msString);
        
        final text = match.group(4)?.trim() ?? '';
        
        final time = Duration(minutes: min, seconds: sec, milliseconds: ms);
        result.add(LrcLine(time: time, text: text));
      }
    }
    
    return result.isEmpty ? null : result;
  }
}
