from ytmusicapi import YTMusic
import yt_dlp
import json

class YTClient:
    def __init__(self):
        self.yt = YTMusic()

    def search_tracks(self, query, limit=20, offset=0, genre=None):
        results = self.yt.search(query, filter="songs", limit=limit + offset)
        # Apply offset manually since ytmusicapi doesn't support offset directly
        sliced_results = results[offset:offset+limit]
        return self._format_tracks(sliced_results)

    def get_trending_tracks(self, limit=20, offset=0):
        # We can use charts or a default search for trending
        # Since charts might be complex, let's search for top songs
        results = self.yt.search("Top hits 2026", filter="songs", limit=limit + offset)
        sliced_results = results[offset:offset+limit]
        return self._format_tracks(sliced_results)

    def get_track_detail(self, video_id):
        try:
            # Get track details via song ID
            song = self.yt.get_song(video_id)
            if not song:
                return None
            
            # Use yt-dlp to get the stream URL (highest quality audio)
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
            }
            audio_url = ""
            duration = 0
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
                audio_url = info.get('url', '')
                duration = info.get('duration', 0)
                title = info.get('title', song.get('videoDetails', {}).get('title', 'Unknown'))
                author = info.get('uploader', song.get('videoDetails', {}).get('author', 'Unknown'))
            
            # To get album and exact cover, we parse from get_song
            microformat = song.get('microformat', {}).get('microformatDataRenderer', {})
            cover_url = ''
            if 'thumbnail' in microformat:
                thumbnails = microformat['thumbnail'].get('thumbnails', [])
                if thumbnails:
                    cover_url = thumbnails[-1]['url']
                    
            return {
                'youtube_id': video_id,
                'title': title,
                'artist_name': author,
                'album_name': 'YouTube Music',  # Default if not found easily in get_song
                'cover_url': cover_url,
                'duration_seconds': duration,
                'audio_url': audio_url,
                'genre': 'Pop',
                'license_ccurl': ''
            }
        except Exception as e:
            print("Error in get_track_detail:", e)
            return None

    def get_lyrics(self, video_id):
        try:
            watch = self.yt.get_watch_playlist(videoId=video_id)
            lyrics_id = watch.get("lyrics")
            if lyrics_id:
                lyrics_dict = self.yt.get_lyrics(lyrics_id)
                return lyrics_dict.get('lyrics', None)
        except Exception as e:
            print("Error getting lyrics:", e)
        return None

    def get_genres(self):
        return [
            {'id': 1, 'name': 'Pop'},
            {'id': 2, 'name': 'Rock'},
            {'id': 3, 'name': 'Hip-Hop'},
            {'id': 4, 'name': 'Electro'},
            {'id': 5, 'name': 'Classique'},
        ]

    def _format_tracks(self, results):
        formatted = []
        for item in results:
            try:
                if item.get('resultType') not in ['song', 'video']:
                    continue
                
                video_id = item.get('videoId')
                if not video_id:
                    continue
                    
                title = item.get('title', 'Unknown Title')
                
                artists = item.get('artists', [])
                artist_name = artists[0]['name'] if artists else 'Unknown Artist'
                
                album = item.get('album')
                album_name = album.get('name') if album else 'Single'
                
                thumbnails = item.get('thumbnails', [])
                cover_url = thumbnails[-1]['url'] if thumbnails else ''
                
                # ytmusicapi duration is like "3:45"
                duration_str = item.get('duration', '0:00')
                parts = str(duration_str).split(':')
                duration_sec = 0
                if len(parts) == 2:
                    duration_sec = int(parts[0]) * 60 + int(parts[1])
                elif len(parts) == 3:
                    duration_sec = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
                    
                formatted.append({
                    'youtube_id': video_id,
                    'title': title,
                    'artist_name': artist_name,
                    'album_name': album_name,
                    'cover_url': cover_url,
                    'duration_seconds': duration_sec,
                    'audio_url': '', # Filled only on detail request
                    'genre': 'YouTube',
                    'license_ccurl': ''
                })
            except Exception as e:
                print("Error formatting track:", e)
                continue
                
        return formatted
