import requests
import json

r = requests.get('https://api.jamendo.com/v3.0/tracks/', params={
    'client_id': 'b6747d04',
    'format': 'json',
    'limit': 2,
    'order': 'popularity_week',
})
print(f"HTTP Status: {r.status_code}")
print(json.dumps(r.json(), indent=2))
