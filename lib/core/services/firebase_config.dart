class FirebaseConfig {
  // ✅ Apni Firebase project details
  static const String apiKey = 'AIzaSyCSJiL23yUzqWL5btwIfxmLFurF8HIklYk';
  static const String projectId = 'real-estate-application-agent';
  
  // Firestore REST API base URL
  static String get firestoreBaseUrl => 
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  
  // Get headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };
}