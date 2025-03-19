import 'package:flutter/material.dart';
import 'dart:convert'; // Needed for JSON decoding
import 'package:http/http.dart' as http; // Needed for HTTP requests
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetZone',
      theme: ThemeData(primarySwatch: Colors.red),
      home: SplashScreen(),
    );
  }
}

/// This splash screen animates in four phases:
/// 1. (0–3 sec): Two narrow containers (width=30) show only the first letter "N" and "Z".
/// 2. (3–4 sec): The containers expand from width 30 to 100, revealing the full texts "Net" and "Zone".
/// 3. (4–7 sec): The full "NetZone" is held on screen.
/// 4. (7–9 sec): The full word zooms in and fades out before navigating to the login screen.
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> leftWidth;
  late Animation<double> rightWidth;
  late Animation<double> scaleAnimation;
  late Animation<double> opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Total duration of 9 seconds.
    _controller = AnimationController(
      duration: Duration(seconds: 9),
      vsync: this,
    );

    leftWidth = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(30), weight: 3), // 0–3 sec
      TweenSequenceItem(
          tween: Tween<double>(begin: 30, end: 100)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1), // 3–4 sec
      TweenSequenceItem(tween: ConstantTween(100), weight: 3), // 4–7 sec
      TweenSequenceItem(tween: ConstantTween(100), weight: 2), // 7–9 sec
    ]).animate(_controller);

    rightWidth = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(30), weight: 3),
      TweenSequenceItem(
          tween: Tween<double>(begin: 30, end: 100)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
      TweenSequenceItem(tween: ConstantTween(100), weight: 3),
      TweenSequenceItem(tween: ConstantTween(100), weight: 2),
    ]).animate(_controller);

    // From 7 to 9 seconds, scale up and fade out.
    scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
          parent: _controller,
          curve: Interval(7 / 9, 1.0, curve: Curves.easeOut)),
    );
    opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: Interval(7 / 9, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward().whenComplete(() {
      // Check if a user is already signed in.
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MoviesAndTvPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the animated text.
  Widget buildAnimatedText() {
    // During the first half of the animation, show the animated (clipped) text.
    if (_controller.value < 1.0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left part ("Net"): animate its width
          AnimatedBuilder(
            animation: leftWidth,
            builder: (context, child) {
              return ClipRect(
                child: SizedBox(
                  width: leftWidth.value,
                  child: child,
                ),
              );
            },
            child: Text(
              "Net",
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                color: Colors.red,
                fontSize: 45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Right part ("Zone"): animate its width
          AnimatedBuilder(
            animation: rightWidth,
            builder: (context, child) {
              return ClipRect(
                child: SizedBox(
                  width: rightWidth.value,
                  child: child,
                ),
              );
            },
            child: Text(
              "Zone",
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                color: Colors.blue,
                fontSize: 45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    } else {
      // Once fully expanded, display "NetZone" as one word.
      // Here we use Text.rich with two TextSpans and explicitly set letterSpacing to 0.
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "Net", style: TextStyle(color: Colors.red)),
            TextSpan(text: "Zone", style: TextStyle(color: Colors.blue)),
          ],
        ),
        style: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          letterSpacing: -2.0,
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: opacityAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: buildAnimatedText(),
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .authStateChanges(), // Listens for sign-in/sign-out
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If a user is logged in, show the MoviesAndTvPage.
        if (snapshot.hasData && snapshot.data != null) {
          return MoviesAndTvPage();
        }
        // Otherwise, show the LoginScreen.
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  String? errorMessage;

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      print("Login successful, user: ${userCredential.user}");
      // Explicitly navigate to MoviesAndTvPage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MoviesAndTvPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      print("Login error: ${e.message}");
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      print("Unknown login error: $e");
      setState(() {
        errorMessage = "An unknown error occurred.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white), // White text input
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white), // White label text
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(primary: Colors.blue),
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: const Text(
                "Don't have an account? Sign Up",
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            // Logo area with RichText: "Net" in red and "Zone" in blue.
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: "Net",
                      style: TextStyle(color: Colors.red),
                    ),
                    TextSpan(
                      text: "Zone",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  bool _isLoading = false;
  String? errorMessage;

  Future<void> _signUp() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      //store additional profile info in Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SignUpSuccessScreen()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "An unknown error occurred.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign Up', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            TextField(
              controller: nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(primary: Colors.blue),
                    onPressed: _signUp,
                    child: const Text('Sign Up'),
                  ),
            const SizedBox(height: 40),
            // Logo area: "NetZone" with "Net" in red and "Zone" in blue.
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(text: "Net", style: TextStyle(color: Colors.red)),
                    TextSpan(
                        text: "Zone", style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.email ?? "User"}'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: Center(child: Text('You are now logged in!')),
    );
  }
}

class SignUpSuccessScreen extends StatefulWidget {
  @override
  _SignUpSuccessScreenState createState() => _SignUpSuccessScreenState();
}

class _SignUpSuccessScreenState extends State<SignUpSuccessScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Sign-up successful!",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

Widget buildCommonDrawer(BuildContext context) {
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // The main list of menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Home button
                ListTile(
                  leading: Icon(Icons.home, color: Colors.blue),
                  title: Text('Home', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MoviesAndTvPage()),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.watch_later, color: Colors.blue),
                  title: Text('Watch Later',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WatchLaterPage()),
                    );
                  },
                ),
                // Categories ExpansionTile with nested drop-downs
                ExpansionTile(
                  leading: Icon(Icons.category, color: Colors.blue),
                  title: Text('Categories',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  collapsedIconColor: Colors.white,
                  iconColor: Colors.white,
                  children: [
                    // Action category
                    ExpansionTile(
                      title: Text('Action',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      collapsedIconColor: Colors.blue,
                      iconColor: Colors.blue,
                      children: [
                        ListTile(
                          title: Center(
                            child: Text(
                              'Movies',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ActionMoviesPage()),
                            );
                          },
                        ),
                        ListTile(
                          title: Center(
                            child: Text(
                              'TV Shows',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ActionTvShowsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                    // Comedy category
                    ExpansionTile(
                      title: Text('Comedy',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      collapsedIconColor: Colors.blue, 
                      iconColor: Colors.blue,
                      children: [
                        ListTile(
                          title: Center(
                            child: Text(
                              'Movies',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ComedyMoviesPage()),
                            );
                          },
                        ),
                        ListTile(
                          title: Center(
                            child: Text(
                              'TV Shows',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ComedyTvShowsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                    // Drama category
                    ExpansionTile(
                      title: Text('Drama',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      collapsedIconColor: Colors.blue, 
                      iconColor: Colors.blue,
                      children: [
                        ListTile(
                          title: Center(
                            child: Text(
                              'Movies',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => DramaMoviesPage()),
                            );
                          },
                        ),
                        ListTile(
                          title: Center(
                            child: Text(
                              'TV Shows',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => DramaTvShowsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                    // Horror category
                    ExpansionTile(
                      title: Text('Horror',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      collapsedIconColor: Colors.blue, 
                      iconColor: Colors.blue,
                      children: [
                        ListTile(
                          title: Center(
                            child: Text(
                              'Movies',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HorrorMoviesPage()),
                            );
                          },
                        ),
                        ListTile(
                          title: Center(
                            child: Text(
                              'TV Shows',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HorrorTvShowsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                    // Romance category
                    ExpansionTile(
                      title: Text('Romance',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      collapsedIconColor: Colors.blue,
                      iconColor: Colors.blue,
                      children: [
                        ListTile(
                          title: Center(
                            child: Text(
                              'Movies',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RomanceMoviesPage()),
                            );
                          },
                        ),
                        ListTile(
                          title: Center(
                            child: Text(
                              'TV Shows',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RomanceTvShowsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.white70),
          // Sign Out button at the bottom.
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

/* ================================================================
   API SERVICE & MOVIE MODEL
   ---------------------------------------------------------------
   These classes fetch movie data from a public API (TMDb).
=================================================================== */
class Movie {
  final int id;
  final String title;
  final String posterPath;

  Movie({required this.id, required this.title, required this.posterPath});

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? json['name'] ?? 'No Title',
      posterPath: json['poster_path'] ?? '',
    );
  }
}

class ApiService {
  final String _baseUrl = "https://api.themoviedb.org/3";
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";

  Future<List<Movie>> fetchPopularMovies() async {
    final url = Uri.parse("$_baseUrl/movie/popular?api_key=$_apiKey");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  // Fetch top-rated movies
  Future<List<Movie>> fetchTopRatedMovies() async {
    final url = Uri.parse("$_baseUrl/movie/top_rated?api_key=$_apiKey");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load top-rated movies');
    }
  }

  // Fetch trending movies (using the daily trending endpoint)
  Future<List<Movie>> fetchTrendingMovies() async {
    final url = Uri.parse("$_baseUrl/trending/movie/day?api_key=$_apiKey");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load trending movies');
    }
  }

  // Fetch search results (for both movies and TV shows)
  Future<List<Movie>> fetchSearchResults(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
        "$_baseUrl/search/multi?api_key=$_apiKey&query=$encodedQuery");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      print("Search API response: ${jsonData['results']}");
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load search results');
    }
  }

// Fetch upcoming movies
  Future<List<Movie>> fetchUpcomingMovies() async {
    final url = Uri.parse("$_baseUrl/movie/upcoming?api_key=$_apiKey");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      print("Upcoming API response: ${jsonData['results']}");
      return results.map((movieData) => Movie.fromJson(movieData)).toList();
    } else {
      throw Exception('Failed to load upcoming movies');
    }
  }

  Future<List<Movie>> fetchPopularTvShows() async {
    final url =
        Uri.parse("$_baseUrl/tv/popular?api_key=$_apiKey&language=en-US");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie(
          id: data['id'],
          title: data['name'] ?? 'No Title',
          posterPath: data['poster_path'] ?? '',
        );
      }).toList();
    } else {
      throw Exception("Failed to load popular TV shows");
    }
  }

  Future<List<Movie>> fetchTopRatedTvShows() async {
    final url =
        Uri.parse("$_baseUrl/tv/top_rated?api_key=$_apiKey&language=en-US");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie(
          id: data['id'],
          title: data['name'] ?? 'No Title',
          posterPath: data['poster_path'] ?? '',
        );
      }).toList();
    } else {
      throw Exception("Failed to load top rated TV shows");
    }
  }

  Future<List<Movie>> fetchTrendingTvShows() async {
    final url = Uri.parse("$_baseUrl/trending/tv/day?api_key=$_apiKey");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie(
          id: data['id'],
          title: data['name'] ?? 'No Title',
          posterPath: data['poster_path'] ?? '',
        );
      }).toList();
    } else {
      throw Exception("Failed to load trending TV shows");
    }
  }

  Future<List<Movie>> fetchUpcomingTvShows() async {
    final url =
        Uri.parse("$_baseUrl/tv/airing_today?api_key=$_apiKey&language=en-GB");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie(
          id: data['id'],
          title: data['name'] ?? 'No Title',
          posterPath: data['poster_path'] ?? '',
        );
      }).toList();
    } else {
      throw Exception('Failed to load upcoming TV shows');
    }
  }
}

class SearchSection extends StatefulWidget {
  @override
  _SearchSectionState createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  TextEditingController searchController = TextEditingController();
  List<Movie> searchResults = [];
  bool isLoading = false;
  String? error;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final encodedQuery = Uri.encodeComponent(query);
      print("Searching for: $query (encoded: $encodedQuery)");
      List<Movie> results = await ApiService().fetchSearchResults(query);
      print("Received ${results.length} results.");
      setState(() {
        searchResults = results;
      });
    } catch (e) {
      print("Search error: $e");
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      searchResults = [];
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int resultCount = searchResults.length > 6 ? 6 : searchResults.length;

    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The search field
          TextField(
            controller: searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search movies/tv shows...',
              hintStyle: TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.grey[850],
              prefixIcon: Icon(Icons.search, color: Colors.white),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _performSearch,
            onSubmitted: _performSearch,
          ),
          if (searchResults.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              height: resultCount * 70.0,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                itemCount: resultCount,
                itemBuilder: (context, index) {
                  Movie movie = searchResults[index];
                  final imageUrl =
                      "https://image.tmdb.org/t/p/w500${movie.posterPath}";
                  return ListTile(
                    leading: movie.posterPath.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 50,
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.movie, color: Colors.white),
                    title: Text(movie.title,
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      _clearResults();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailPage(
                              contentId: movie.id, contentType: "movie"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  Widget build(BuildContext context) {
    const double searchAreaHeight = 80.0;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true, // Centers the title horizontally
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 35, // Larger title
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(text: "Net", style: TextStyle(color: Colors.red)),
              TextSpan(text: "Zone", style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
      ),
      drawer: buildCommonDrawer(context),
      // Main content:
      body: Stack(
        children: [
          // Main content: positioned below the search area.
          Positioned.fill(
            top: searchAreaHeight,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Popular Movies Section
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Popular Movies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  PopularMoviesApiSection(),
                  // Top Rated Movies Section
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Top Rated Movies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TopRatedMoviesApiSection(),
                  // Trending Movies Section
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Trending Movies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ExploreTrendingMoviesSection(pageController: _pageController),
                  // Upcoming Movies Section
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Upcoming Movies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  UpcomingMoviesApiSection(),
                ],
              ),
            ),
          ),
          // Search area: fixed at the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 20, // High elevation so it appears on top.
              color: Colors.transparent,
              child: SearchSection(),
            ),
          ),
        ],
      ),
    );
  }

  // Existing helper method to build a movie section (for top rated movies, etc.)
  Widget _buildMovieSection({
    required String title,
    required List<Movie> movies,
    required ScrollController scrollController,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 250,
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailPage(
                              contentId: movie.id, contentType: "movie"),
                        ),
                      );
                    },
                    child: Container(
                      width: 160,
                      margin: EdgeInsets.only(right: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              "https://image.tmdb.org/t/p/w500${movie.posterPath}",
                              height: 200,
                              width: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey,
                                height: 200,
                                width: 160,
                                child: Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            movie.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreTrendingMoviesSection extends StatefulWidget {
  final PageController pageController;

  ExploreTrendingMoviesSection({required this.pageController});

  @override
  _ExploreTrendingMoviesSectionState createState() =>
      _ExploreTrendingMoviesSectionState();
}

class _ExploreTrendingMoviesSectionState
    extends State<ExploreTrendingMoviesSection> {
  List<Movie> trendingMovies = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchTrendingMovies();
  }

  void _fetchTrendingMovies() async {
    try {
      List<Movie> movies = await ApiService().fetchTrendingMovies();
      setState(() {
        trendingMovies = movies;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      return Container(
        height: 400,
        child: Center(
            child:
                Text('Error: $error', style: TextStyle(color: Colors.white))),
      );
    } else if (trendingMovies.isEmpty) {
      return Container(
        height: 400,
        child: Center(
            child: Text('No Trending Movies Found',
                style: TextStyle(color: Colors.white))),
      );
    } else {
      return SizedBox(
        height: 400,
        child: PageView.builder(
          controller: widget.pageController,
          itemCount: trendingMovies.length,
          itemBuilder: (context, index) {
            return _buildScrollableMovieCard(trendingMovies[index]);
          },
        ),
      );
    }
  }

  Widget _buildScrollableMovieCard(Movie movie) {
    final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
    return AnimatedBuilder(
      animation: widget.pageController,
      builder: (context, child) {
        double value = 0.0;
        if (widget.pageController.hasClients &&
            widget.pageController.position.haveDimensions) {
          value = widget.pageController.page! - trendingMovies.indexOf(movie);
        } else {
          value = trendingMovies.indexOf(movie).toDouble();
        }
        double scale = (1 - value.abs() * 0.3).clamp(0.8, 1.0);
        double opacity = (1 - value.abs() * 0.5).clamp(0.5, 1.0);
        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          // Debug print for verifying tap
          print("Tapped on movie with id: ${movie.id}");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MovieDetailPage(contentId: movie.id, contentType: "movie"),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey,
                  child: Icon(Icons.error, color: Colors.red),
                ),
              ),
              Container(
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  movie.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================================================================
   PopularMoviesApiSection
   ---------------------------------------------------------------
   This widget uses FutureBuilder and the ApiService to fetch popular
   movies from TMDb. When a movie is tapped, it navigates to your 
   existing MovieDetailPage.
=================================================================== */
class PopularMoviesApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchPopularMovies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Movies Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final movies = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${movie.posterPath}";
                return GestureDetector(
                  onTap: () {
                    // Navigate to your existing MovieDetailPage.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: movie.id, contentType: "movie"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie poster image from the API.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        // Movie title.
                        Text(
                          movie.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class TopRatedMoviesApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchTopRatedMovies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Movies Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final movies = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${movie.posterPath}";
                return GestureDetector(
                  onTap: () {
                    // Navigate to the detail page when tapped.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: movie.id, contentType: "movie"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display the movie poster.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        // Display the movie title.
                        Text(
                          movie.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class TrendingMoviesApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchTrendingMovies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Trending Movies Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final movies = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${movie.posterPath}";
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: movie.id, contentType: "movie"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie poster image.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        // Movie title.
                        Text(
                          movie.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class UpcomingMoviesApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchUpcomingMovies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Upcoming Movies Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final movies = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${movie.posterPath}";
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: movie.id, contentType: "movie"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie poster image.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        // Movie title.
                        Text(
                          movie.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class ActionMoviesPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchMovies() async {
    final url =
        Uri.parse("$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=28");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception("Failed to load Action movies");
    }
  }

  // Building a grid that shows 3 movies per row.
  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: movie.id, contentType: "movie"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                movie.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Action Movies"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Action movies found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final movies = snapshot.data!;
            return _buildMovieGrid(movies);
          }
        },
      ),
    );
  }
}

// Helper method to build the common Drawer for every page.
Widget _buildCommonDrawer(BuildContext context) {
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text('Home', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          // Other common menu items added here.
          Divider(color: Colors.white70),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class ComedyMoviesPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchMovies() async {
    final url =
        Uri.parse("$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=35");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception("Failed to load Comedy movies");
    }
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: movie.id, contentType: "movie"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                movie.title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Comedy Movies"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Comedy movies found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final movies = snapshot.data!;
            return _buildMovieGrid(movies);
          }
        },
      ),
    );
  }
}

Widget _buildCommonDrawer1(BuildContext context) {
  // Same as defined in ActionMoviesPage
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text('Home', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          Divider(color: Colors.white70),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class DramaMoviesPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchMovies() async {
    final url =
        Uri.parse("$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=18");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception("Failed to load Drama movies");
    }
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: movie.id, contentType: "movie"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                movie.title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Drama Movies"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Drama movies found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final movies = snapshot.data!;
            return _buildMovieGrid(movies);
          }
        },
      ),
    );
  }
}

Widget _buildCommonDrawer2(BuildContext context) {
  // Reuse the common drawer as before.
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text('Home', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          Divider(color: Colors.white70),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class HorrorMoviesPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchMovies() async {
    final url =
        Uri.parse("$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=27");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception("Failed to load Horror movies");
    }
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: movie.id, contentType: "movie"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                movie.title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Horror Movies"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Horror movies found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final movies = snapshot.data!;
            return _buildMovieGrid(movies);
          }
        },
      ),
    );
  }
}

Widget _buildCommonDrawer3(BuildContext context) {
  // Same as before.
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text('Home', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          Divider(color: Colors.white70),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class RomanceMoviesPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchMovies() async {
    final url = Uri.parse(
        "$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=10749");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) => Movie.fromJson(data)).toList();
    } else {
      throw Exception("Failed to load Romance movies");
    }
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${movie.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: movie.id, contentType: "movie"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                movie.title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Romance Movies"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Romance movies found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final movies = snapshot.data!;
            return _buildMovieGrid(movies);
          }
        },
      ),
    );
  }
}

Widget _buildCommonDrawer4(BuildContext context) {
  return Drawer(
    child: Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              'Menu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.blue),
            title: Text('Home', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          Divider(color: Colors.white70),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class PopularTvShowsApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchPopularTvShows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No TV Shows Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final tvShows = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tvShows.length,
              itemBuilder: (context, index) {
                final tvShow = tvShows[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: tvShow.id, contentType: "tv"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tvShow.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class TopRatedTvShowsApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchTopRatedTvShows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Top Rated TV Shows Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final tvShows = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tvShows.length,
              itemBuilder: (context, index) {
                final tvShow = tvShows[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: tvShow.id, contentType: "tv"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tvShow.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class ExploreTrendingTvShowsSection extends StatefulWidget {
  final PageController pageController;

  ExploreTrendingTvShowsSection({required this.pageController});

  @override
  _ExploreTrendingTvShowsSectionState createState() =>
      _ExploreTrendingTvShowsSectionState();
}

class _ExploreTrendingTvShowsSectionState
    extends State<ExploreTrendingTvShowsSection> {
  List<Movie> trendingTvShows = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchTrendingTvShows();
  }

  void _fetchTrendingTvShows() async {
    try {
      List<Movie> shows = await ApiService().fetchTrendingTvShows();
      setState(() {
        trendingTvShows = shows;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      return Container(
        height: 400,
        child: Center(
            child:
                Text('Error: $error', style: TextStyle(color: Colors.white))),
      );
    } else if (trendingTvShows.isEmpty) {
      return Container(
        height: 400,
        child: Center(
            child: Text('No Trending TV Shows Found',
                style: TextStyle(color: Colors.white))),
      );
    } else {
      return SizedBox(
        height: 400,
        child: PageView.builder(
          controller: widget.pageController,
          itemCount: trendingTvShows.length,
          itemBuilder: (context, index) {
            return _buildScrollableTvCard(trendingTvShows[index]);
          },
        ),
      );
    }
  }

  Widget _buildScrollableTvCard(Movie tvShow) {
    final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
    return AnimatedBuilder(
      animation: widget.pageController,
      builder: (context, child) {
        double value = 0.0;
        if (widget.pageController.hasClients &&
            widget.pageController.position.haveDimensions) {
          // Calculate relative position of the card for scaling
          value = widget.pageController.page! - trendingTvShows.indexOf(tvShow);
        } else {
          value = trendingTvShows.indexOf(tvShow).toDouble();
        }
        double scale = (1 - value.abs() * 0.3).clamp(0.8, 1.0);
        double opacity = (1 - value.abs() * 0.5).clamp(0.5, 1.0);
        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          print("Tapped on TV show with id: ${tvShow.id}");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey,
                  child: Icon(Icons.error, color: Colors.red),
                ),
              ),
              Container(
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  tvShow.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpcomingTvShowsApiSection extends StatelessWidget {
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: apiService.fetchUpcomingTvShows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 250,
            child: Center(
              child: Text(
                'No Upcoming TV Shows Found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        } else {
          final tvShows = snapshot.data!;
          return SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tvShows.length,
              itemBuilder: (context, index) {
                final tvShow = tvShows[index];
                final imageUrl =
                    "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailPage(
                            contentId: tvShow.id, contentType: "tv"),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TV Show poster image.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              height: 200,
                              width: 160,
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        // TV Show title.
                        Text(
                          tvShow.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}

class ActionTvShowsPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchTvShows() async {
    final url =
        Uri.parse("$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=10759");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie.fromJson(data);
      }).toList();
    } else {
      throw Exception("Failed to load Action TV shows");
    }
  }

  Widget _buildTvGrid(List<Movie> tvShows) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Three items per row
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        final tvShow = tvShows[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                tvShow.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Action TV Shows"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchTvShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Action TV shows found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final tvShows = snapshot.data!;
            return _buildTvGrid(tvShows);
          }
        },
      ),
    );
  }
}

class ComedyTvShowsPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchTvShows() async {
    final url =
        Uri.parse("$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=35");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie.fromJson(data);
      }).toList();
    } else {
      throw Exception("Failed to load Comedy TV shows");
    }
  }

  Widget _buildTvGrid(List<Movie> tvShows) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        final tvShow = tvShows[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                tvShow.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Comedy TV Shows"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchTvShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Comedy TV shows found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final tvShows = snapshot.data!;
            return _buildTvGrid(tvShows);
          }
        },
      ),
    );
  }
}

class DramaTvShowsPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchTvShows() async {
    final url =
        Uri.parse("$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=18");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie.fromJson(data);
      }).toList();
    } else {
      throw Exception("Failed to load Comedy TV shows");
    }
  }

  Widget _buildTvGrid(List<Movie> tvShows) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        final tvShow = tvShows[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                tvShow.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Drama TV Shows"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchTvShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Comedy TV shows found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final tvShows = snapshot.data!;
            return _buildTvGrid(tvShows);
          }
        },
      ),
    );
  }
}

class HorrorTvShowsPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchTvShows() async {
    final url =
        Uri.parse("$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=9648");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie.fromJson(data);
      }).toList();
    } else {
      throw Exception("Failed to load Comedy TV shows");
    }
  }

  Widget _buildTvGrid(List<Movie> tvShows) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        final tvShow = tvShows[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                tvShow.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Horror TV Shows"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchTvShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Comedy TV shows found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final tvShows = snapshot.data!;
            return _buildTvGrid(tvShows);
          }
        },
      ),
    );
  }
}

class RomanceTvShowsPage extends StatelessWidget {
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<Movie>> fetchTvShows() async {
    final url =
        Uri.parse("$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=10751");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> results = jsonData['results'];
      return results.map((data) {
        return Movie.fromJson(data);
      }).toList();
    } else {
      throw Exception("Failed to load Comedy TV shows");
    }
  }

  Widget _buildTvGrid(List<Movie> tvShows) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        final tvShow = tvShows[index];
        final imageUrl = "https://image.tmdb.org/t/p/w500${tvShow.posterPath}";
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailPage(contentId: tvShow.id, contentType: "tv"),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                tvShow.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Romance TV Shows"),
        backgroundColor: Colors.black,
      ),
      drawer: buildCommonDrawer(context),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Movie>>(
        future: fetchTvShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text("No Comedy TV shows found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final tvShows = snapshot.data!;
            return _buildTvGrid(tvShows);
          }
        },
      ),
    );
  }
}

class MoviesAndTvPage extends StatefulWidget {
  @override
  _MoviesAndTvPageState createState() => _MoviesAndTvPageState();
}

class _MoviesAndTvPageState extends State<MoviesAndTvPage> {
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Movies and TV Shows
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: "Net", style: TextStyle(color: Colors.red)),
                TextSpan(text: "Zone", style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: "Movies"),
              Tab(text: "TV Shows"),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.blue,
          ),
        ),
        drawer: buildCommonDrawer(context),
        body: Column(
          children: [
            SearchSection(),
            Expanded(
              child: TabBarView(
                children: [
                  // Movies tab
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Popular Movies',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        PopularMoviesApiSection(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Top Rated Movies',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        TopRatedMoviesApiSection(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Trending Movies',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        ExploreTrendingMoviesSection(
                            pageController: _pageController),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Upcoming Movies',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        UpcomingMoviesApiSection(),
                      ],
                    ),
                  ),
                  // TV Shows tab
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Popular TV Shows',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        PopularTvShowsApiSection(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Top Rated TV Shows',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        TopRatedTvShowsApiSection(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Trending TV Shows',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        ExploreTrendingTvShowsSection(
                            pageController: _pageController),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Upcoming TV Shows',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        UpcomingTvShowsApiSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MovieDetailPage extends StatefulWidget {
  final int contentId;
  final String contentType;

  MovieDetailPage({required this.contentId, this.contentType = "movie"});

  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  bool isWatchLater = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // API keys and base URL.
  final String _apiKey = "1e36f91aeb2fb4ea55da4775937ecddb";
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<Map<String, dynamic>> fetchDetailsAndCredits() async {
    final detailsUrl = Uri.parse(
        "$_baseUrl/${widget.contentType}/${widget.contentId}?api_key=$_apiKey&language=en-US");
    final creditsUrl = Uri.parse(
        "$_baseUrl/${widget.contentType}/${widget.contentId}/credits?api_key=$_apiKey&language=en-US");

    final detailsResponse = await http.get(detailsUrl);
    final creditsResponse = await http.get(creditsUrl);

    if (detailsResponse.statusCode == 200 &&
        creditsResponse.statusCode == 200) {
      final detailsData = json.decode(detailsResponse.body);
      final creditsData = json.decode(creditsResponse.body);
      return {
        'details': detailsData,
        'credits': creditsData,
      };
    } else {
      throw Exception("Failed to load ${widget.contentType} details");
    }
  }

  // Loads the initial watch later status.
  Future<void> _loadWatchLaterStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection("watchLater").doc(user.uid).get();
      if (doc.exists) {
        List<dynamic> items = doc.get("movies");
        setState(() {
          isWatchLater = items.any((m) => m["id"] == widget.contentId);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWatchLaterStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contentType == "movie"
            ? "Movie Details"
            : "TV Show Details"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchDetailsAndCredits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData) {
            return Center(
                child: Text("No data found",
                    style: TextStyle(color: Colors.white)));
          } else {
            final details = snapshot.data!['details'];
            final credits = snapshot.data!['credits'];

            final overview = details['overview'] ?? "No overview available.";
            final releaseDate = details['release_date'] ?? "N/A";
            final runtime = details['runtime'] != null
                ? "${details['runtime']} min"
                : "N/A";
            final genresList = details['genres'] as List<dynamic>? ?? [];
            final genres = genresList.map((g) => g['name']).join(", ");
            final castList = credits['cast'] as List<dynamic>? ?? [];

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Image
                  Center(
                    child: details['poster_path'] != null &&
                            details['poster_path'] != ""
                        ? Image.network(
                            "https://image.tmdb.org/t/p/w500${details['poster_path']}",
                            height: 300,
                          )
                        : Container(
                            height: 300,
                            color: Colors.grey,
                            child: Icon(Icons.movie,
                                color: Colors.white, size: 100),
                          ),
                  ),
                  SizedBox(height: 16),
                  // Title
                  Text(
                    details['title'] ?? details['name'] ?? "No Title",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  // Release Date, Runtime, Genres
                  Text("Release Date: $releaseDate",
                      style: TextStyle(color: Colors.white)),
                  Text("Runtime: $runtime",
                      style: TextStyle(color: Colors.white)),
                  Text("Genres: $genres",
                      style: TextStyle(color: Colors.white)),
                  SizedBox(height: 16),
                  // Overview
                  Text("Overview:",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(overview,
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 16),
                  // Cast
                  Text("Cast:",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: castList.length,
                      itemBuilder: (context, index) {
                        final castMember = castList[index];
                        final profilePath = castMember['profile_path'];
                        final castImage =
                            (profilePath != null && profilePath != "")
                                ? "https://image.tmdb.org/t/p/w200$profilePath"
                                : null;
                        return Container(
                          width: 100,
                          margin: EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              castImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.network(
                                        castImage,
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      height: 80,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.person,
                                          color: Colors.white),
                                    ),
                              SizedBox(height: 4),
                              Text(
                                castMember['name'] ?? "",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                castMember['character'] ?? "",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final itemMap = {
                        "id": widget.contentId,
                        "title":
                            details['title'] ?? details['name'] ?? "No Title",
                        "posterPath": details['poster_path'] ?? "",
                      };

                      User? user = _auth.currentUser;
                      if (user == null) return;
                      DocumentReference userDoc =
                          _firestore.collection("watchLater").doc(user.uid);

                      if (isWatchLater) {
                        // Remove item from watch later list.
                        await userDoc.update({
                          "movies": FieldValue.arrayRemove([itemMap])
                        });
                      } else {
                        // Add item to watch later list.
                        await userDoc.set({
                          "movies": FieldValue.arrayUnion([itemMap])
                        }, SetOptions(merge: true));
                      }
                      setState(() {
                        isWatchLater = !isWatchLater;
                      });
                    },
                    style: ElevatedButton.styleFrom(primary: Colors.blue),
                    child: Text(
                      isWatchLater
                          ? 'Remove from Watch Later'
                          : 'Add to Watch Later',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Review & Rating Section
                  ReviewSection(movieId: widget.contentId),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class WatchLaterPage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) return Container();

    return Scaffold(
      appBar: AppBar(
        title: Text("Watch Later"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection("watchLater").doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // If document does not exist or movies list is missing, show a message.
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text("No movies in your Watch Later list",
                  style: TextStyle(color: Colors.white)),
            );
          }

          List<dynamic> movies = snapshot.data!.get("movies");
          if (movies.isEmpty) {
            return Center(
              child: Text("No movies in your Watch Later list",
                  style: TextStyle(color: Colors.white)),
            );
          }

          // Display the movies in a grid (3 per row)
          return GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Three items per row
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.6,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movieData = movies[index];
              final String posterPath =
                  (movieData is Map && movieData['posterPath'] != null)
                      ? movieData['posterPath']
                      : "";
              final String title =
                  (movieData is Map && movieData['title'] != null)
                      ? movieData['title']
                      : "No Title";
              final dynamic id = (movieData is Map && movieData['id'] != null)
                  ? movieData['id']
                  : null;
              final String imageUrl = posterPath.isNotEmpty
                  ? "https://image.tmdb.org/t/p/w500$posterPath"
                  : "";

              return Card(
                color: Colors.grey[850],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: posterPath.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.error, color: Colors.red),
                            )
                          : Icon(Icons.movie, color: Colors.white, size: 50),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 2),
                      child: Text(
                        title,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _firestore
                            .collection("watchLater")
                            .doc(user.uid)
                            .update({
                          "movies": FieldValue.arrayRemove([movieData])
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReviewSection extends StatefulWidget {
  final int movieId;
  ReviewSection({required this.movieId});

  @override
  _ReviewSectionState createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    setState(() {
      _isSubmitting = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch username from the "users" collection.
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();
    String username =
        (userDoc.data() as Map<String, dynamic>)['name'] ?? "Anonymous";

    await FirebaseFirestore.instance.collection("reviews").add({
      "movieId": widget.movieId,
      "userId": user.uid,
      "username": username,
      "review": _reviewController.text,
      "rating": _rating,
      "timestamp": FieldValue.serverTimestamp(),
    });
    _reviewController.clear();
    setState(() {
      _rating = 0;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Leave a Review",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        // Row of 5 stars for rating.
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                _rating > index ? Icons.star : Icons.star_border,
                color: Colors.yellow,
              ),
              onPressed: () {
                setState(() {
                  _rating = index + 1.0;
                });
              },
            );
          }),
        ),
        TextField(
          controller: _reviewController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Write your review...",
            hintStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.grey[850],
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(primary: Colors.blue),
          child: _isSubmitting
              ? CircularProgressIndicator()
              : Text("Submit Review", style: TextStyle(color: Colors.white)),
        ),
        SizedBox(height: 16),
        ReviewsList(movieId: widget.movieId),
      ],
    );
  }
}

class ReviewsList extends StatelessWidget {
  final int movieId;
  ReviewsList({required this.movieId});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reviews")
          .where("movieId", isEqualTo: movieId)
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text("No reviews yet", style: TextStyle(color: Colors.white));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final reviewData = docs[index].data() as Map<String, dynamic>;
            final reviewId = docs[index].id;
            final reviewUserId = reviewData["userId"] as String? ?? "";
            return ListTile(
              title: Row(
                children: [
                  Text(
                    reviewData["username"] ?? "Anonymous",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  // Show delete button only if the current user is the owner.
                  if (reviewUserId == currentUserId)
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () async {
                        // Confirm deletion if you want.
                        await FirebaseFirestore.instance
                            .collection("reviews")
                            .doc(reviewId)
                            .delete();
                      },
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < (reviewData["rating"] ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.yellow,
                        size: 16,
                      );
                    }),
                  ),
                  SizedBox(height: 4),
                  Text(
                    reviewData["review"] ?? "",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}