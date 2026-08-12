import requests
import json
import time

artists = [
    # Français
    "Jul", "Ninho", "Gazo", "SCH", "Tiakola", "PLK", "Orelsan", "Booba", "Aya Nakamura", "Niska",
    "PNL", "Dadju", "Gims", "Tayc", "SDM", "Werenoi", "Soolking", "Soprano", "Nekfeu", "Lomepal",
    "Vald", "Dinos", "Maes", "Zola", "Koba LaD", "Heuss l'Enfoiré", "Naps", "Alonzo", "Kaaris", "Soso Maness",
    "RK", "Timal", "Lacrim", "Rohff", "Bigflo & Oli", "Vianney", "Clara Luciani", "Louane", "Kendji Girac", "Slimane",
    "Claudio Capéo", "Amir", "Julien Doré", "David Guetta", "DJ Snake", "Ofenbach", "Kungs", "Martin Solveig", "Petit Biscuit", "Trinix",
    "Ziak", "Leto", "Favé", "Yamê", "Bekar", "Kerchak", "So La Lune", "Guy2Bezbar", "La Fève", "Zamdane",
    "Benjamin Epps", "Kekra", "Laylow", "Sadek", "Kalash Criminel", "DA Uzi", "Landy", "Bosh", "Kofs", "Gradur",
    "Keblack", "Naza", "Franglish", "Luidji", "Vacra", "Jungeli", "Imen Es", "Lynda", "Nej'", "Eva Queen",
    "Marwa Loud", "Shay", "Meryl", "Santa", "Zaho de Sagazan", "Pomme", "Juliette Armanet", "Hoshi", "Mentissa", "Yseult",
    "Pierre de Maere", "Eddy de Pretto", "Grand Corps Malade", "Calogero", "Florent Pagny", "Francis Cabrel", "Jean-Jacques Goldman", "Indochine", "MC Solaar", "Woodkid",
    
    # Anglais
    "Ed Sheeran", "Dua Lipa", "Harry Styles", "Adele", "Sam Smith", "Coldplay", "Lewis Capaldi", "Central Cee", "Dave", "Stormzy",
    "Skepta", "Jorja Smith", "Rita Ora", "Ellie Goulding", "Raye", "Charli XCX", "Fred again..", "PinkPantheress", "Arctic Monkeys", "Yungblud",
    "James Arthur", "Tom Grennan", "George Ezra", "Calvin Harris", "Jax Jones", "Disclosure", "Clean Bandit", "Anne-Marie", "Little Mix", "Mabel",
    "Headie One", "Russ Millions", "Tion Wayne", "Digga D", "J Hus", "Loyle Carner", "Rag'n'Bone Man", "Sam Fender", "Wet Leg", "Arlo Parks",
    "Glass Animals", "Rex Orange County", "Beabadoobee", "Cat Burns", "Mimi Webb", "Holly Humberstone", "Bakar", "Knucks", "D-Block Europe", "Mahalia",
    
    # Américains
    "Taylor Swift", "Ariana Grande", "Billie Eilish", "Post Malone", "Travis Scott", "Kendrick Lamar", "J. Cole", "Juice WRLD", "XXXTentacion", "Pop Smoke",
    "Lil Baby", "Gunna", "Future", "Young Thug", "Playboi Carti", "Lil Uzi Vert", "Cardi B", "Megan Thee Stallion", "Doja Cat", "SZA",
    "Bruno Mars", "Lady Gaga", "Katy Perry", "Miley Cyrus", "Selena Gomez", "Halsey", "Olivia Rodrigo", "Sabrina Carpenter", "Chappell Roan", "Zach Bryan",
    "Morgan Wallen", "Luke Combs", "Chris Brown", "Usher", "Khalid", "Mac Miller", "Roddy Ricch", "Polo G", "Kodak Black", "Lil Durk",
    "YoungBoy Never Broke Again", "A$AP Rocky", "Tyler, The Creator", "21 Savage", "Don Toliver", "Yeat", "Jack Harlow", "Ice Spice", "Latto", "Coi Leray",
    "Summer Walker", "Brent Faiyaz", "Giveon", "Steve Lacy", "Frank Ocean", "Lana Del Rey", "Eminem", "Kanye West", "Snoop Dogg", "Wiz Khalifa",
    "Machine Gun Kelly", "Kid Cudi", "Anderson .Paak", "Childish Gambino", "H.E.R.", "Kehlani", "Jhené Aiko", "Ella Mai", "Bryson Tiller", "Ty Dolla $ign",
    "YG", "NF", "Logic", "Macklemore", "G-Eazy", "Russ", "Trippie Redd", "Ski Mask The Slump God", "Lil Yachty", "Denzel Curry",
    "JID", "Joey Bada$$", "Cordae", "Vince Staples", "Pusha T", "Big Sean", "French Montana", "A Boogie Wit Da Hoodie", "Lil Tjay", "NLE Choppa",
    "EST Gee", "Moneybagg Yo", "Key Glock", "Pooh Shiesty", "Fivio Foreign", "Tee Grizzley", "Babyface Ray", "Lucki", "Destroy Lonely", "Ken Carson",
    "SoFaygo", "Rich Amiri", "Kankan", "Summrs", "Autumn!", "Babytron", "Flo Milli", "Sukihana", "Lola Brooke", "Doechii",
    "Saweetie", "Muni Long", "Victoria Monét", "Coco Jones", "Lucky Daye", "Fridayy", "Leon Thomas", "SiR", "Madison Beer", "Conan Gray",
    "Lauv", "Jeremy Zucker", "Alec Benjamin", "Stephen Sanchez", "JVKE", "David Kushner", "d4vd", "Tommy Richman", "Shaboozey", "Djo",
    "Laufey", "Lizzy McAlpine", "Phoebe Bridgers", "Clairo", "Boygenius", "Remi Wolf", "Fletcher", "Dove Cameron", "Isabel LaRosa", "Nessa Barrett",
    "Joji", "Aminé", "Rico Nasty", "Tierra Whack", "Rod Wave", "Baby Keem", "Sleepy Hallow", "Nardo Wick", "BigXthaPlug", "Teezo Touchdown",
    
    # Afrique Francophone
    "Fally Ipupa", "Didi B", "Innoss'B", "KS Bloom", "Gaz Mawete", "Koffi Olomidé", "Ferré Gola", "Suspect 95", "Tenor", "Locko",
    "Blanche Bailly", "Stanley Enow", "Sidiki Diabaté", "Iba One", "Dip Doundou Guiss", "Samba Peuzzi", "Jeeba", "Wally Seck", "Magic System", "Alpha Blondy",
    "Tiken Jah Fakoly", "Meiway", "Kerozen", "Josey", "Serge Beynaud", "Ariel Sheney", "Bebi Philip", "Debordo Leekunfa", "Himra", "Fior 2 Bior",
    "Tam Sir", "Team Paiya", "Lil Jay Bingerack", "Ko-c", "Aveiro Djess", "Cysoul", "Santrinos Raphaël", "Vano Baby", "Axel Merryl", "Ghettovi",
    "Memo All Star", "Ngaaka Blindé", "Viviane Chidid", "Huguo Boss", "Kayawoto", "Amzy", "King Mensah", "Toofan", "Charlotte Dipanda", "Rokia Traoré",
    
    # Amérique Latine
    "Bad Bunny", "Shakira", "J Balvin", "Maluma", "Karol G", "Daddy Yankee", "Ozuna", "Anuel AA", "Rauw Alejandro", "Feid",
    "Myke Towers", "Bizarrap", "Peso Pluma", "Natanael Cano", "Fuerza Regida", "Grupo Frontera", "Duki", "Tiago PZK", "Maria Becerra", "Tini",
    "Emilia", "Nicki Nicole", "Anitta", "Sech", "Eladio Carrión", "Mora", "Jhayco", "Lunay", "Justin Quiles", "Tokischa",
    "El Alfa", "Ryan Castro", "Blessd", "Young Miko", "Milo J", "Trueno", "Khea", "Cazzu", "Christian Nodal", "Alejandro Fernández",
    "Luis Fonsi", "Ricky Martin", "Romeo Santos", "Prince Royce", "Natti Natasha", "Becky G", "Camila Cabello", "Manuel Turizo", "Sebastian Yatra", "Camilo",
    
    # K-Pop
    "BTS", "BLACKPINK", "TWICE", "Stray Kids", "Seventeen", "EXO", "NCT 127", "Red Velvet", "ITZY", "(G)I-DLE",
    "NewJeans", "LE SSERAFIM", "aespa", "IVE", "ENHYPEN", "TXT", "ATEEZ", "TREASURE", "NMIXX", "STAYC",
    "IU", "Psy", "Sunmi", "Chungha", "Taeyeon", "Taemin", "Baekhyun", "Kai", "Zico", "Jay Park",
    "Jessi", "Hwasa", "Got7", "Monsta X", "Day6", "The Boyz", "Kep1er", "BABYMONSTER", "ILLIT", "KISS OF LIFE",
    "RIIZE", "ZEROBASEONE", "BOYNEXTDOOR", "TWS", "Jungkook", "Jimin", "V", "Agust D", "Lisa", "Jennie",
    
    # Afrique Anglophone
    "Burna Boy", "Wizkid", "Davido", "Rema", "Asake", "Ayra Starr", "Tems", "Fireboy DML", "CKay", "Omah Lay",
    "Ruger", "Bnxn", "Victony", "Shallipopi", "Seyi Vibez", "Zinoleesky", "Bella Shmurda", "Young Jonn", "Lojay", "Oxlade",
    "Joeboy", "Tiwa Savage", "Yemi Alade", "Patoranking", "Mr Eazi", "Tekno", "Olamide", "Phyno", "Timaya", "Kizz Daniel",
    "Flavour", "Mayorkun", "Peruzzi", "Blaqbonez", "Odumodublvck", "Ladipoe", "Chike", "Johnny Drille", "Fave", "Qing Madi",
    "Mercy Chinwo", "Moses Bliss", "Black Sherif", "Stonebwoy", "Sarkodie", "Shatta Wale", "Gyakie", "Camidoh", "Kuami Eugene", "KiDi",
    "King Promise", "Amaarae", "Tyla", "Master KG", "Uncle Waffles", "Costa Titch", "Focalistic", "Kabza De Small", "DJ Maphorisa", "Young Stunna",
    "Tyler ICU", "Kamo Mphela", "DBN Gogo", "Nasty C", "Cassper Nyovest", "AKA", "Sho Madjozi", "Blxckie", "Elaine", "Ami Faku",
    "Black Coffee", "Diamond Platnumz", "Harmonize", "Rayvanny", "Zuchu", "Mbosso", "Ali Kiba", "Nandy", "Sauti Sol", "Bien",
    "Nyashinski", "Khaligraph Jones", "Otile Brown", "Nadia Mukami", "Azawi", "Vinka", "Joshua Baraka", "Yo Maps", "Chef 187", "Holy Ten",
    "Nutty O", "Jah Prayzah", "Winky D", "King Kaka", "Femi One", "Arrow Bwoy", "Jovial", "P-Square", "D'banj", "2Face Idibia"
]

results = []

for idx, artist in enumerate(artists):
    print(f"Fetching {idx+1}/{len(artists)}: {artist}")
    try:
        url = f"https://itunes.apple.com/search?term={artist}&limit=1&entity=song"
        response = requests.get(url, timeout=5)
        data = response.json()
        image_url = ""
        if data["resultCount"] > 0:
            image_url = data["results"][0].get("artworkUrl100", "")
            # Convert 100x100 to 600x600 for high quality
            image_url = image_url.replace("100x100", "600x600")
        
        results.append({
            "name": artist,
            "imageUrl": image_url
        })
    except Exception as e:
        print(f"Error for {artist}: {e}")
        results.append({
            "name": artist,
            "imageUrl": ""
        })
    time.sleep(0.1) # Be nice to the API

# Generate Dart file
dart_code = "class ArtistsData {\n  static const List<Map<String, String>> globalArtists = [\n"
for item in results:
    safe_name = item['name'].replace("'", "\\'")
    dart_code += f"    {{'name': '{safe_name}', 'imageUrl': '{item['imageUrl']}'}},\n"
dart_code += "  ];\n}\n"

with open("lib/core/constants/artists_data.dart", "w", encoding="utf-8") as f:
    f.write(dart_code)

print("Done! Created lib/core/constants/artists_data.dart")
