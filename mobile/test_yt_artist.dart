import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final searchResults = await yt.search.searchContent('Jul officiel', filter: TypeFilters.channel);
    final channels = searchResults.whereType<SearchChannel>();
    if (channels.isNotEmpty) {
      final channel = channels.first;
      print('Found channel: ${channel.name}');
      print('Channel ID: ${channel.id}');
      
      final channelDetails = await yt.channels.get(channel.id);
      print('Logo URL: ${channelDetails.logoUrl}');
    } else {
      print('No channel found.');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
