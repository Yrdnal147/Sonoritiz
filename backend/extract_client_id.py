import urllib.request
import re

req = urllib.request.Request('https://www.jamendo.com', headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    matches = re.findall(r'client_id["\'\:\s\=]+([a-zA-Z0-9]{8})', html)
    print("Found client_ids in HTML:", list(set(matches)))
except Exception as e:
    print("Error:", e)

# Also check their main JS file
try:
    js_urls = re.findall(r'src="([^"]+\.js[^"]*)"', html)
    for url in js_urls:
        if url.startswith('/'):
            url = 'https://www.jamendo.com' + url
        elif not url.startswith('http'):
            continue
        
        try:
            js = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})).read().decode('utf-8')
            matches = re.findall(r'client_id["\'\:\s\=]+([a-zA-Z0-9]{8})', js)
            if matches:
                print(f"Found in {url}:", list(set(matches)))
        except:
            pass
except Exception as e:
    pass
