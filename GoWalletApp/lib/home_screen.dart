import 'package:flutter/material.dart';
import 'add_card_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'card_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'company_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userPhone;
  const HomeScreen({super.key, required this.userPhone});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> cards = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthAndFetchCards();
  }

  Future<void> _checkAuthAndFetchCards() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Debug log to verify token is available
    print('Auth token from SharedPreferences: $token');

    if (token.isEmpty) {
      // No token found, redirect to login
      print('No auth token found, redirecting to login');
      _redirectToLogin();
      return;
    }

    // Token found, fetch cards
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get authorization token from storage
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // Debug log
      print('Using token for API request: $token');

      // Execute API request to get user's card list
      final response = await http.get(
        Uri.parse('http://192.168.58.135:5000/user_cards/${widget.userPhone}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Debug log
      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Add additional debug to check data structure
        print('Decoded data: $data');
        print('Cards data: ${data['cards']}');

        setState(() {
          // Convert received data to list of Maps
          cards = List<Map<String, dynamic>>.from(data['cards'] ?? []);
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Unauthorized - token might be expired or invalid
        print('Authentication error (401): Token might be invalid or expired');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Your session has expired. Please login again.';
        });

        // Wait a moment to show the error then redirect to login
        Future.delayed(const Duration(seconds: 3), () {
          _redirectToLogin();
        });
      } else {
        print('Error fetching cards: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load cards. Please try again later.';
        });
      }
    } catch (e) {
      print('Exception when fetching cards: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  void _addCard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCardScreen(
          userPhone: widget.userPhone,
          onCardAdded: (String maskedNumber) {
            // Temporarily add card with basic information until server update
            setState(() {
              cards.add({
                'masked_number': maskedNumber,
                'card_number': maskedNumber
              });
            });
            // After adding the card, update the list from the server
            _fetchCards();
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // If QR scan button is pressed
    if (index == 1) {
      // Navigate to QR scanner screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerScreen(),
        ),
      );
      // Reset the selected index to home after navigation
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _redirectToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to GOWALLET!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Cards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addCard,
                  child: const Text('Add Card'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _fetchCards,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : cards.isEmpty
                  ? const Center(
                child: Text(
                  'You have no cards added yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        cards[index]['masked_number'] ??
                            _formatCardNumber(cards[index]['card_number'] ?? ''),
                        style: const TextStyle(fontSize: 18),
                      ),
                      subtitle: cards[index]['cardholder_name'] != null
                          ? Text(cards[index]['cardholder_name'])
                          : null,
                      leading: const Icon(Icons.credit_card, color: Colors.blue),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cards[index]['expiry_month'] != null &&
                              cards[index]['expiry_year'] != null)
                            Text(
                              '${cards[index]['expiry_month']}/${cards[index]['expiry_year']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                      onTap: () {
                        // Check for ID before navigation
                        final cardId = cards[index]['id'];
                        if (cardId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CardScreen(
                                cardId: cardId,
                                onCardDeleted: () {
                                  // Update card list after deletion
                                  _fetchCards();
                                },
                              ),
                            ),
                          );
                        } else {
                          // Show error notification
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cannot open card: ID is missing'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          // Update card list to get missing data
                          _fetchCards();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'QR Scan',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }

  // Helper method for masking card number
  String _formatCardNumber(String cardNumber) {
    if (cardNumber.length >= 4) {
      return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
    }
    return cardNumber;
  }
}

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isProcessing = false; // Flag to prevent multiple triggers

  @override
  void initState() {
    super.initState();

    // Line animation (movement from top to bottom)
    _animationController =
    AnimationController(vsync: this, duration: Duration(seconds: 2))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  // QR code processing function
  void _handleQRCode(String rawValue) {
    // If we are already processing a QR code, exit the function
    if (_isProcessing) return;

    // Set processing flag
    _isProcessing = true;

    // Pause scanning
    cameraController.stop();

    if (rawValue.startsWith("gowallet://company/")) {
      String companyId = rawValue.replaceFirst("gowallet://company/", "");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CompanyScreen(companyId: companyId)),
      ).then((_) {
        // Reset processing flag and resume scanning when user returns
        _isProcessing = false;
        cameraController.start();
      });
    } else {
      print('❌ Invalid QR code: $rawValue');

      // Show notification about invalid QR code
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );

      // Reset processing flag and resume scanning after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
        _isProcessing = false;
        cameraController.start();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR Scanner')),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null) {
                  // Use QR code processing function
                  _handleQRCode(rawValue);
                }
              }
            },
          ),

          // Darkening around the frame + frame
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double scanSize = constraints.maxWidth * 0.6; // Square size
                double scanTop = (constraints.maxHeight - scanSize) / 2;
                double scanLeft = (constraints.maxWidth - scanSize) / 2;

                return Stack(
                  children: [
                    // Darkening at the top
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: scanTop,
                      child: Container(color: Colors.black.withOpacity(0.6)),
                    ),
                    // Darkening at the bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: scanTop,
                      child: Container(color: Colors.black.withOpacity(0.6)),
                    ),
                    // Darkening on the left
                    Positioned(
                      top: scanTop,
                      left: 0,
                      width: scanLeft,
                      height: scanSize,
                      child: Container(color: Colors.black.withOpacity(0.6)),
                    ),
                    // Darkening on the right
                    Positioned(
                      top: scanTop,
                      right: 0,
                      width: scanLeft,
                      height: scanSize,
                      child: Container(color: Colors.black.withOpacity(0.6)),
                    ),

                    // Square scanning area
                    Positioned(
                      top: scanTop,
                      left: scanLeft,
                      width: scanSize,
                      height: scanSize,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // White frame
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // Animated red line
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _animation.value * (scanSize - 3),
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 3,
                                    color: Colors.redAccent,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Hint
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Place QR code in the center',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

          // Flashlight button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.flashlight_on, color: Colors.white, size: 40),
                onPressed: () => cameraController.toggleTorch(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}