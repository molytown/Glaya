class CountryData {
  final String iso;
  final String name;
  final String code;
  final String flag;
  final Map<String, List<String>> states;

  const CountryData({
    required this.iso,
    required this.name,
    required this.code,
    required this.flag,
    required this.states,
  });
}

const List<CountryData> countries = [
  CountryData(
    iso: 'NG', name: 'Nigeria', code: '+234', flag: '🇳🇬',
    states: {
      'Lagos': ['Ikeja', 'Lekki', 'Victoria Island', 'Surulere', 'Yaba', 'Ajah', 'Ikoyi', 'Oshodi', 'Mushin', 'Agege'],
      'Abuja': ['Garki', 'Wuse', 'Maitama', 'Asokoro', 'Gwarinpa', 'Kubwa', 'Jabi', 'Utako'],
      'Rivers': ['Port Harcourt', 'Obio-Akpor', 'Eleme', 'Bonny'],
      'Oyo': ['Ibadan', 'Ogbomoso', 'Oyo', 'Iseyin'],
      'Kano': ['Kano City', 'Fagge', 'Nassarawa', 'Tarauni'],
      'Enugu': ['Enugu City', 'Nsukka', 'Udi', 'Agbani'],
      'Delta': ['Asaba', 'Warri', 'Sapele', 'Ughelli'],
      'Kaduna': ['Kaduna City', 'Zaria', 'Kafanchan'],
      'Ogun': ['Abeokuta', 'Sagamu', 'Ijebu-Ode', 'Ota'],
      'Anambra': ['Awka', 'Onitsha', 'Nnewi'],
    },
  ),
  CountryData(
    iso: 'GH', name: 'Ghana', code: '+233', flag: '🇬🇭',
    states: {
      'Greater Accra': ['Accra', 'Tema', 'Madina', 'Teshie', 'Nungua'],
      'Ashanti': ['Kumasi', 'Obuasi', 'Ejisu'],
      'Central': ['Cape Coast', 'Winneba', 'Kasoa'],
      'Western': ['Takoradi', 'Sekondi', 'Tarkwa'],
      'Eastern': ['Koforidua', 'Nkawkaw', 'Akim Oda'],
    },
  ),
  CountryData(
    iso: 'KE', name: 'Kenya', code: '+254', flag: '🇰🇪',
    states: {
      'Nairobi': ['Nairobi CBD', 'Westlands', 'Karen', 'Kilimani', 'Langata'],
      'Mombasa': ['Mombasa Island', 'Nyali', 'Bamburi', 'Likoni'],
      'Kisumu': ['Kisumu City', 'Mamboleo'],
      'Nakuru': ['Nakuru Town', 'Naivasha'],
      'Kiambu': ['Thika', 'Ruiru', 'Juja', 'Kikuyu'],
    },
  ),
  CountryData(
    iso: 'ZA', name: 'South Africa', code: '+27', flag: '🇿🇦',
    states: {
      'Gauteng': ['Johannesburg', 'Pretoria', 'Sandton', 'Soweto', 'Midrand'],
      'Western Cape': ['Cape Town', 'Stellenbosch', 'Paarl', 'George'],
      'KwaZulu-Natal': ['Durban', 'Pietermaritzburg', 'Richards Bay'],
      'Eastern Cape': ['Port Elizabeth', 'East London'],
      'Free State': ['Bloemfontein', 'Welkom'],
    },
  ),
  CountryData(
    iso: 'CM', name: 'Cameroon', code: '+237', flag: '🇨🇲',
    states: {
      'Adamaoua': ['Ngaoundéré', 'Meiganga', 'Tibati'],
      'Centre': ['Yaoundé', 'Obala', 'Mbalmayo', 'Bafia'],
      'East': ['Bertoua', 'Batouri', 'Yokadouma'],
      'Far North': ['Maroua', 'Kousséri', 'Mokolo'],
      'Littoral': ['Douala', 'Nkongsamba', 'Edéa', 'Kribi'],
      'North': ['Garoua', 'Guider', 'Pitoa'],
      'Northwest': ['Bamenda', 'Kumbo', 'Wum'],
      'South': ['Ebolowa', 'Kribi', 'Sangmélima'],
      'Southwest': ['Buea', 'Limbe', 'Kumba'],
      'West': ['Bafoussam', 'Dschang', 'Mbouda'],
    },
  ),
  CountryData(
    iso: 'CI', name: 'Ivory Coast', code: '+225', flag: '🇨🇮',
    states: {
      'Abidjan': ['Plateau', 'Cocody', 'Yopougon', 'Marcory', 'Treichville'],
      'Bouaké': ['Bouaké Centre', 'N\'Gattakro', 'Koko'],
      'San-Pédro': ['San-Pédro', 'Grand-Béréby'],
    },
  ),
  CountryData(
    iso: 'SN', name: 'Senegal', code: '+221', flag: '🇸🇳',
    states: {
      'Dakar': ['Dakar Plateau', 'Gorée', 'Médina', 'Fann'],
      'Thiès': ['Thiès', 'Mbour', 'Joal-Fadiouth'],
      'Saint-Louis': ['Saint-Louis', 'Richard Toll'],
    },
  ),
  CountryData(
    iso: 'TZ', name: 'Tanzania', code: '+255', flag: '🇹🇿',
    states: {
      'Dar es Salaam': ['Ilala', 'Kinondoni', 'Temeke', 'Ubungo'],
      'Arusha': ['Arusha City', 'Moshi', 'Karatu'],
      'Mwanza': ['Mwanza City', 'Kahama', 'Shinyanga'],
    },
  ),
  CountryData(
    iso: 'UG', name: 'Uganda', code: '+256', flag: '🇺🇬',
    states: {
      'Kampala': ['Central', 'Kawempe', 'Makindye', 'Nakawa', 'Rubaga'],
      'Wakiso': ['Entebbe', 'Kira', 'Nansana'],
      'Mbale': ['Mbale City', 'Tororo', 'Soroti'],
    },
  ),
  CountryData(
    iso: 'RW', name: 'Rwanda', code: '+250', flag: '🇷🇼',
    states: {
      'Kigali': ['Gasabo', 'Kicukiro', 'Nyarugenge'],
      'Eastern': ['Rwamagana', 'Kayonza', 'Nyagatare'],
      'Western': ['Rubavu', 'Karongi', 'Rusizi'],
    },
  ),
  CountryData(
    iso: 'ET', name: 'Ethiopia', code: '+251', flag: '🇪🇹',
    states: {
      'Addis Ababa': ['Bole', 'Kolfe Keranio', 'Yeka', 'Kirkos'],
      'Oromia': ['Adama', 'Hawassa', 'Jimma'],
      'Amhara': ['Bahir Dar', 'Gondar', 'Dire Dawa'],
    },
  ),
  CountryData(
    iso: 'EG', name: 'Egypt', code: '+20', flag: '🇪🇬',
    states: {
      'Cairo': ['Downtown', 'Giza', 'Maadi', 'Heliopolis'],
      'Alexandria': ['Alexandria Centre', 'Smouha', 'Miami'],
      'Giza': ['Giza City', '6th of October', 'Sheikh Zayed'],
    },
  ),
  CountryData(
    iso: 'MA', name: 'Morocco', code: '+212', flag: '🇲🇦',
    states: {
      'Casablanca': ['Casablanca Centre', 'Maârif', 'Ain Sebaâ'],
      'Rabat': ['Rabat Centre', 'Agdal', 'Hassan'],
      'Marrakech': ['Marrakech Centre', 'Guéliz', 'Menara'],
    },
  ),
  CountryData(
    iso: 'GB', name: 'United Kingdom', code: '+44', flag: '🇬🇧',
    states: {
      'England': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Leeds', 'Bristol'],
      'Scotland': ['Edinburgh', 'Glasgow', 'Aberdeen'],
      'Wales': ['Cardiff', 'Swansea', 'Newport'],
      'Northern Ireland': ['Belfast', 'Derry'],
    },
  ),
  CountryData(
    iso: 'US', name: 'United States', code: '+1', flag: '🇺🇸',
    states: {
      'New York': ['New York City', 'Buffalo', 'Rochester', 'Albany'],
      'California': ['Los Angeles', 'San Francisco', 'San Diego', 'Sacramento'],
      'Texas': ['Houston', 'Dallas', 'Austin', 'San Antonio'],
      'Florida': ['Miami', 'Orlando', 'Tampa', 'Jacksonville'],
      'Illinois': ['Chicago', 'Springfield', 'Naperville'],
      'Georgia': ['Atlanta', 'Savannah', 'Augusta'],
    },
  ),
  CountryData(
    iso: 'CA', name: 'Canada', code: '+1', flag: '🇨🇦',
    states: {
      'Ontario': ['Toronto', 'Ottawa', 'Hamilton', 'Mississauga'],
      'Quebec': ['Montreal', 'Quebec City', 'Laval'],
      'British Columbia': ['Vancouver', 'Victoria', 'Surrey'],
      'Alberta': ['Calgary', 'Edmonton', 'Red Deer'],
    },
  ),
  CountryData(
    iso: 'FR', name: 'France', code: '+33', flag: '🇫🇷',
    states: {
      'Île-de-France': ['Paris', 'Boulogne-Billancourt', 'Saint-Denis'],
      'Provence-Alpes-Côte d\'Azur': ['Marseille', 'Nice', 'Toulon'],
      'Auvergne-Rhône-Alpes': ['Lyon', 'Grenoble', 'Saint-Étienne'],
    },
  ),
  CountryData(
    iso: 'DE', name: 'Germany', code: '+49', flag: '🇩🇪',
    states: {
      'Berlin': ['Berlin Mitte', 'Kreuzberg', 'Prenzlauer Berg'],
      'Bavaria': ['Munich', 'Nuremberg', 'Augsburg'],
      'North Rhine-Westphalia': ['Cologne', 'Düsseldorf', 'Dortmund'],
    },
  ),
  CountryData(
    iso: 'IT', name: 'Italy', code: '+39', flag: '🇮🇹',
    states: {
      'Lazio': ['Rome', 'Fiumicino', 'Ostia'],
      'Lombardy': ['Milan', 'Bergamo', 'Monza'],
      'Campania': ['Naples', 'Salerno', 'Pompeii'],
    },
  ),
  CountryData(
    iso: 'ES', name: 'Spain', code: '+34', flag: '🇪🇸',
    states: {
      'Madrid': ['Madrid Centre', 'Barajas', 'Alcobendas'],
      'Catalonia': ['Barcelona', 'Girona', 'Tarragona'],
      'Andalusia': ['Seville', 'Malaga', 'Granada'],
    },
  ),
  CountryData(
    iso: 'NL', name: 'Netherlands', code: '+31', flag: '🇳🇱',
    states: {
      'North Holland': ['Amsterdam', 'Haarlem', 'Zandvoort'],
      'South Holland': ['Rotterdam', 'The Hague', 'Delft'],
      'North Brabant': ['Eindhoven', 'Breda', 'Tilburg'],
    },
  ),
  CountryData(
    iso: 'BE', name: 'Belgium', code: '+32', flag: '🇧🇪',
    states: {
      'Brussels': ['Brussels City', 'Schaerbeek', 'Anderlecht'],
      'Flanders': ['Antwerp', 'Ghent', 'Bruges'],
      'Wallonia': ['Liège', 'Namur', 'Charleroi'],
    },
  ),
  CountryData(
    iso: 'CH', name: 'Switzerland', code: '+41', flag: '🇨🇭',
    states: {
      'Zurich': ['Zurich City', 'Winterthur', 'Uster'],
      'Geneva': ['Geneva City', 'Carouge', 'Versoix'],
      'Bern': ['Bern City', 'Biel', 'Thun'],
    },
  ),
  CountryData(
    iso: 'AT', name: 'Austria', code: '+43', flag: '🇦🇹',
    states: {
      'Vienna': ['Vienna Centre', 'Döbling', 'Favoriten'],
      'Tyrol': ['Innsbruck', 'Kufstein', 'Reutte'],
      'Salzburg': ['Salzburg City', 'Hallein', 'Saalfelden'],
    },
  ),
  CountryData(
    iso: 'SE', name: 'Sweden', code: '+46', flag: '🇸🇪',
    states: {
      'Stockholm': ['Stockholm Centre', 'Södermalm', 'Östermalm'],
      'Skåne': ['Malmö', 'Lund', 'Helsingborg'],
      'Västra Götaland': ['Gothenburg', 'Borås', 'Trollhättan'],
    },
  ),
  CountryData(
    iso: 'NO', name: 'Norway', code: '+47', flag: '🇳🇴',
    states: {
      'Oslo': ['Oslo Centre', 'Grorud', 'Nordstrand'],
      'Akershus': ['Bærum', 'Asker', 'Lillestrøm'],
      'Hordaland': ['Bergen', 'Askøy', 'Kvam'],
    },
  ),
  CountryData(
    iso: 'DK', name: 'Denmark', code: '+45', flag: '🇩🇰',
    states: {
      'Capital Region': ['Copenhagen', 'Frederiksberg', 'Gentofte'],
      'Central Denmark': ['Aarhus', 'Vejle', 'Randers'],
      'South Denmark': ['Odense', 'Esbjerg', 'Kolding'],
    },
  ),
  CountryData(
    iso: 'FI', name: 'Finland', code: '+358', flag: '🇫🇮',
    states: {
      'Uusimaa': ['Helsinki', 'Espoo', 'Vantaa'],
      'Pirkanmaa': ['Tampere', 'Nokia', 'Ylöjärvi'],
      'Finland Proper': ['Turku', 'Raisio', 'Naantali'],
    },
  ),
  CountryData(
    iso: 'PL', name: 'Poland', code: '+48', flag: '🇵🇱',
    states: {
      'Masovian': ['Warsaw', 'Radom', 'Płock'],
      'Silesian': ['Katowice', 'Gliwice', 'Zabrze'],
      'Lesser Poland': ['Kraków', 'Tarnów', 'Nowy Sącz'],
    },
  ),
  CountryData(
    iso: 'CZ', name: 'Czech Republic', code: '+420', flag: '🇨🇿',
    states: {
      'Prague': ['Prague Centre', 'Prague West', 'Prague East'],
      'Central Bohemian': ['Kladno', 'Mladá Boleslav', 'Čáslav'],
      'Moravian-Silesian': ['Ostrava', 'Karviná', 'Frýdek-Místek'],
    },
  ),
  CountryData(
    iso: 'GR', name: 'Greece', code: '+30', flag: '🇬🇷',
    states: {
      'Attica': ['Athens', 'Piraeus', 'Marousi'],
      'Central Macedonia': ['Thessaloniki', 'Kavala', 'Serres'],
      'Crete': ['Heraklion', 'Chania', 'Rethymno'],
    },
  ),
  CountryData(
    iso: 'PT', name: 'Portugal', code: '+351', flag: '🇵🇹',
    states: {
      'Lisbon': ['Lisbon', 'Amadora', 'Sintra'],
      'Porto': ['Porto', 'Vila Nova de Gaia', 'Matosinhos'],
      'Setúbal': ['Setúbal', 'Almada', 'Barreiro'],
    },
  ),
  CountryData(
    iso: 'IE', name: 'Ireland', code: '+353', flag: '🇮🇪',
    states: {
      'Leinster': ['Dublin', 'Bray', 'Drogheda'],
      'Munster': ['Cork', 'Limerick', 'Galway'],
      'Connacht': ['Galway', 'Sligo', 'Castlebar'],
    },
  ),
  CountryData(
    iso: 'AU', name: 'Australia', code: '+61', flag: '🇦🇺',
    states: {
      'New South Wales': ['Sydney', 'Newcastle', 'Wollongong'],
      'Victoria': ['Melbourne', 'Geelong', 'Ballarat'],
      'Queensland': ['Brisbane', 'Gold Coast', 'Cairns'],
    },
  ),
  CountryData(
    iso: 'NZ', name: 'New Zealand', code: '+64', flag: '🇳🇿',
    states: {
      'Auckland': ['Auckland CBD', 'Manukau', 'North Shore'],
      'Wellington': ['Wellington City', 'Lower Hutt', 'Porirua'],
      'Canterbury': ['Christchurch', 'Timaru', 'Ashburton'],
    },
  ),
  CountryData(
    iso: 'JP', name: 'Japan', code: '+81', flag: '🇯🇵',
    states: {
      'Tokyo': ['Shinjuku', 'Shibuya', 'Minato'],
      'Osaka': ['Osaka City', 'Sakai', 'Suita'],
      'Kanagawa': ['Yokohama', 'Kawasaki', 'Kamakura'],
    },
  ),
  CountryData(
    iso: 'KR', name: 'South Korea', code: '+82', flag: '🇰🇷',
    states: {
      'Seoul': ['Gangnam', 'Jongno', 'Mapo'],
      'Busan': ['Busanjin', 'Haeundae', 'Seo-gu'],
      'Incheon': ['Bupyeong', 'Namdong', 'Yeonsu'],
    },
  ),
  CountryData(
    iso: 'CN', name: 'China', code: '+86', flag: '🇨🇳',
    states: {
      'Beijing': ['Dongcheng', 'Xicheng', 'Chaoyang'],
      'Shanghai': ['Huangpu', 'Xuhui', 'Pudong'],
      'Guangdong': ['Guangzhou', 'Shenzhen', 'Dongguan'],
    },
  ),
  CountryData(
    iso: 'IN', name: 'India', code: '+91', flag: '🇮🇳',
    states: {
      'Maharashtra': ['Mumbai', 'Pune', 'Nagpur'],
      'Delhi': ['New Delhi', 'South Delhi', 'North Delhi'],
      'Karnataka': ['Bangalore', 'Mysore', 'Hubli'],
    },
  ),
  CountryData(
    iso: 'BR', name: 'Brazil', code: '+55', flag: '🇧🇷',
    states: {
      'São Paulo': ['São Paulo', 'Guarulhos', 'Campinas'],
      'Rio de Janeiro': ['Rio de Janeiro', 'Niterói', 'Duque de Caxias'],
      'Minas Gerais': ['Belo Horizonte', 'Uberlândia', 'Contagem'],
    },
  ),
  CountryData(
    iso: 'MX', name: 'Mexico', code: '+52', flag: '🇲🇽',
    states: {
      'Mexico City': ['Coyoacán', 'Benito Juárez', 'Iztapalapa'],
      'Jalisco': ['Guadalajara', 'Zapopan', 'Tlaquepaque'],
      'Nuevo León': ['Monterrey', 'San Pedro Garza García', 'Apodaca'],
    },
  ),
  CountryData(
    iso: 'AR', name: 'Argentina', code: '+54', flag: '🇦🇷',
    states: {
      'Buenos Aires': ['Buenos Aires', 'La Plata', 'Mar del Plata'],
      'Córdoba': ['Córdoba', 'Villa Carlos Paz', 'Río Cuarto'],
      'Santa Fe': ['Rosario', 'Santa Fe', 'San Lorenzo'],
    },
  ),
  CountryData(
    iso: 'CO', name: 'Colombia', code: '+57', flag: '🇨🇴',
    states: {
      'Bogotá': ['Chapinero', 'Suba', 'Kennedy'],
      'Antioquia': ['Medellín', 'Envigado', 'Bello'],
      'Valle del Cauca': ['Cali', 'Palmira', 'Buenaventura'],
    },
  ),
  CountryData(
    iso: 'PE', name: 'Peru', code: '+51', flag: '🇵🇪',
    states: {
      'Lima': ['Lima Centre', 'Miraflores', 'San Borja'],
      'Arequipa': ['Arequipa City', 'Cayma', 'Yanahuara'],
      'Cusco': ['Cusco City', 'Sicuani', 'Urubamba'],
    },
  ),
  CountryData(
    iso: 'CL', name: 'Chile', code: '+56', flag: '🇨🇱',
    states: {
      'Santiago': ['Santiago Centre', 'Providencia', 'Las Condes'],
      'Valparaíso': ['Valparaíso', 'Viña del Mar', 'Concón'],
      'Biobío': ['Concepción', 'Talcahuano', 'Hualpén'],
    },
  ),
  CountryData(
    iso: 'VE', name: 'Venezuela', code: '+58', flag: '🇻🇪',
    states: {
      'Caracas': ['Libertador', 'Sucre', 'Baruta'],
      'Miranda': ['Los Teques', 'Ocumare del Tuy', 'Charallave'],
      'Zulia': ['Maracaibo', 'San Francisco', 'Cabimas'],
    },
  ),
  CountryData(
    iso: 'SA', name: 'Saudi Arabia', code: '+966', flag: '🇸🇦',
    states: {
      'Riyadh': ['Riyadh Centre', 'Olaya', 'Al-Malaz'],
      'Jeddah': ['Jeddah Centre', 'Al-Hamra', 'Al-Rawdah'],
      'Mecca': ['Mecca City', 'Al-Aziziyah', 'Al-Hindawiyyah'],
    },
  ),
  CountryData(
    iso: 'AE', name: 'United Arab Emirates', code: '+971', flag: '🇦🇪',
    states: {
      'Dubai': ['Dubai Marina', 'Downtown Dubai', 'Jumeirah'],
      'Abu Dhabi': ['Abu Dhabi City', 'Al Ain', 'Madinat Zayed'],
      'Sharjah': ['Sharjah City', 'Al Dhaid', 'Kalba'],
    },
  ),
  CountryData(
    iso: 'QA', name: 'Qatar', code: '+974', flag: '🇶🇦',
    states: {
      'Doha': ['Doha Centre', 'West Bay', 'The Pearl'],
      'Al Rayyan': ['Al Rayyan City', 'Al Waab', 'Luqail'],
      'Al Wakrah': ['Al Wakrah City', 'Mesaieed', 'Wukair'],
    },
  ),
  CountryData(
    iso: 'KW', name: 'Kuwait', code: '+965', flag: '🇰🇼',
    states: {
      'Al Asimah': ['Kuwait City', 'Hawalli', 'Salmiya'],
      'Hawalli': ['Hawalli City', 'Jabriya', 'Salmiya'],
      'Farwaniya': ['Farwaniya City', 'Khaitan', 'Rumaitiya'],
    },
  ),
  CountryData(
    iso: 'BH', name: 'Bahrain', code: '+973', flag: '🇧🇭',
    states: {
      'Capital': ['Manama', 'Juffair', 'Adliya'],
      'Muharraq': ['Muharraq City', 'Arad', 'Hidd'],
      'Northern': ['Budaiya', 'Zinj', 'Diyar Al Muharraq'],
    },
  ),
  CountryData(
    iso: 'OM', name: 'Oman', code: '+968', flag: '🇴🇲',
    states: {
      'Muscat': ['Muscat City', 'Seeb', 'Bawshar'],
      'Dhofar': ['Salalah', 'Mirbat', 'Taqa'],
      'North Al Batinah': ['Sohar', 'Suwaiq', 'Khabura'],
    },
  ),
  CountryData(
    iso: 'JO', name: 'Jordan', code: '+962', flag: '🇯🇴',
    states: {
      'Amman': ['Abdoun', 'Sweifieh', 'Zahran'],
      'Irbid': ['Irbid City', 'Al-Hussein', 'Yarmouk'],
      'Aqaba': ['Aqaba City', 'Wadi Rum', 'Ma\'an'],
    },
  ),
  CountryData(
    iso: 'LB', name: 'Lebanon', code: '+961', flag: '🇱🇧',
    states: {
      'Beirut': ['Beirut Centre', 'Achrafieh', 'Hamra'],
      'Mount Lebanon': ['Jounieh', 'Byblos', 'Broummana'],
      'North': ['Tripoli', 'Batroun', 'Zgharta'],
    },
  ),
  CountryData(
    iso: 'TR', name: 'Turkey', code: '+90', flag: '🇹🇷',
    states: {
      'Istanbul': ['Kadıköy', 'Beşiktaş', 'Şişli'],
      'Ankara': ['Çankaya', 'Keçiören', 'Yenimahalle'],
      'Izmir': ['Konak', 'Karşıyaka', 'Bornova'],
    },
  ),
  CountryData(
    iso: 'IL', name: 'Israel', code: '+972', flag: '🇮🇱',
    states: {
      'Tel Aviv': ['Tel Aviv Centre', 'Ramat Gan', 'Herzliya'],
      'Jerusalem': ['Jerusalem Centre', 'West Jerusalem', 'East Jerusalem'],
      'Haifa': ['Haifa City', 'Nesher', 'Kiryat Yam'],
    },
  ),
  CountryData(
    iso: 'PK', name: 'Pakistan', code: '+92', flag: '🇵🇰',
    states: {
      'Karachi': ['Clifton', 'Gulshan', 'DHA'],
      'Lahore': ['Gulberg', 'DHA', 'Johar Town'],
      'Islamabad': ['F-7', 'G-8', 'E-11'],
    },
  ),
  CountryData(
    iso: 'BD', name: 'Bangladesh', code: '+880', flag: '🇧🇩',
    states: {
      'Dhaka': ['Gulshan', 'Banani', 'Dhanmondi'],
      'Chittagong': ['Agrabad', 'GEC Circle', 'Khulshi'],
      'Sylhet': ['Sylhet City', 'Ambarkhana', 'Zindabazar'],
    },
  ),
  CountryData(
    iso: 'LK', name: 'Sri Lanka', code: '+94', flag: '🇱🇰',
    states: {
      'Colombo': ['Colombo 1', 'Colombo 3', 'Colombo 5'],
      'Gampaha': ['Negombo', 'Gampaha City', 'Kadawatha'],
      'Kandy': ['Kandy City', 'Katugastota', 'Peradeniya'],
    },
  ),
  CountryData(
    iso: 'NP', name: 'Nepal', code: '+977', flag: '🇳🇵',
    states: {
      'Bagmati': ['Kathmandu', 'Lalitpur', 'Bhaktapur'],
      'Province 1': ['Biratnagar', 'Dharan', 'Itahari'],
      'Gandaki': ['Pokhara', 'Lamjung', 'Baglung'],
    },
  ),
  CountryData(
    iso: 'TH', name: 'Thailand', code: '+66', flag: '🇹🇭',
    states: {
      'Bangkok': ['Sukhumvit', 'Silom', 'Siam'],
      'Chiang Mai': ['Chiang Mai City', 'San Kamphaeng', 'Hang Dong'],
      'Phuket': ['Phuket City', 'Patong', 'Karon'],
    },
  ),
  CountryData(
    iso: 'VN', name: 'Vietnam', code: '+84', flag: '🇻🇳',
    states: {
      'Ho Chi Minh': ['District 1', 'District 3', 'District 7'],
      'Hanoi': ['Hoan Kiem', 'Ba Dinh', 'Cau Giay'],
      'Da Nang': ['Hai Chau', 'Thanh Khe', 'Son Tra'],
    },
  ),
  CountryData(
    iso: 'MY', name: 'Malaysia', code: '+60', flag: '🇲🇾',
    states: {
      'Kuala Lumpur': ['KLCC', 'Bukit Bintang', 'Cheras'],
      'Selangor': ['Petaling Jaya', 'Shah Alam', 'Subang Jaya'],
      'Penang': ['George Town', 'Bayan Lepas', 'Butterworth'],
    },
  ),
  CountryData(
    iso: 'SG', name: 'Singapore', code: '+65', flag: '🇸🇬',
    states: {
      'Central Region': ['Orchard', 'Marina Bay', 'Newton'],
      'East Region': ['Bedok', 'Tampines', 'Pasir Ris'],
      'West Region': ['Jurong', 'Bukit Batok', 'Clementi'],
    },
  ),
  CountryData(
    iso: 'ID', name: 'Indonesia', code: '+62', flag: '🇮🇩',
    states: {
      'Jakarta': ['Central Jakarta', 'South Jakarta', 'West Jakarta'],
      'West Java': ['Bandung', 'Bogor', 'Bekasi'],
      'East Java': ['Surabaya', 'Malang', 'Batam'],
    },
  ),
  CountryData(
    iso: 'PH', name: 'Philippines', code: '+63', flag: '🇵🇭',
    states: {
      'Metro Manila': ['Makati', 'Quezon City', 'Taguig'],
      'Cebu': ['Cebu City', 'Mandaue', 'Lapu-Lapu'],
      'Davao': ['Davao City', 'Tagum', 'Panabo'],
    },
  ),
  CountryData(
    iso: 'HK', name: 'Hong Kong', code: '+852', flag: '🇭🇰',
    states: {
      'Hong Kong Island': ['Central', 'Causeway Bay', 'Wan Chai'],
      'Kowloon': ['Tsim Sha Tsui', 'Mong Kok', 'Yau Ma Tei'],
      'New Territories': ['Sha Tin', 'Tuen Mun', 'Fanling'],
    },
  ),
  CountryData(
    iso: 'TW', name: 'Taiwan', code: '+886', flag: '🇹🇼',
    states: {
      'Taipei': ['Da\'an', 'Xinyi', 'Zhongshan'],
      'New Taipei': ['Banqiao', 'Xindian', 'Tamsui'],
      'Kaohsiung': ['Zuoying', 'Fengshan', 'Sanmin'],
    },
  ),
];

List<String> getStatesForCountry(String? iso) {
  if (iso == null || iso.isEmpty) return [];
  final country = countries.where((c) => c.iso == iso).firstOrNull;
  return country?.states.keys.toList() ?? [];
}

List<String> getCitiesForState(String? iso, String? state) {
  if (iso == null || iso.isEmpty || state == null || state.isEmpty) return [];
  final country = countries.where((c) => c.iso == iso).firstOrNull;
  return country?.states[state] ?? [];
}

// Neighborhoods for Cameroon cities
const Map<String, List<String>> neighborhoodsByCity = {
  // Cameroon neighborhoods
  'Yaoundé': ['Bastos', 'Messamendongo', 'Ekoumdoum', 'Nkolbisson', 'Omvan', 'Mvan', 'Ngousso', 'Ekoumdoum'],
  'Douala': ['Akwa', 'Bonanjo', 'Bonapriso', 'Deido', 'Kotto', 'Bonaberi', 'New Bell', 'Bessengue'],
  'Bamenda': ['Upstation', 'Downstation', 'Nkwen', 'Mankon', 'Bamenda Station', 'Mulang'],
  'Buea': ['Molyko', 'Buea Town', 'Great Soppo', 'Little Soppo', 'Bokova', 'Bakingili'],
  'Kumba': ['Kumba I', 'Kumba II', 'Kumba III', 'Barombi Kang', 'Mange'],
  'Garoua': ['Pala', 'Dang', 'Kollé', 'Maroua-Sud'],
  'Maroua': ['Doumaire', 'Pont Vert', 'Fouro', 'Kongola'],
  'Ngaoundéré': ['Bamyanga', 'Mbe', 'Voung-Bani', 'Ngaoundéré'],
  'Bafoussam': ['Bamena', 'Nji', 'Bandjoun', 'Foumban'],
  'Limbe': ['Botanical Garden', 'Down Beach', 'Bota', 'Mile 4'],
  'Ebolowa': ['Mvomeka', 'Minkan', 'Ebolowa Centre'],
};

List<String> getNeighborhoodsForCity(String? city) {
  if (city == null || city.isEmpty) return [];
  return neighborhoodsByCity[city] ?? [];
}
