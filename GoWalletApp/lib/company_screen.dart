import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyScreen extends StatefulWidget {
  final String companyId;
  final String? userPhone;
  final String? authToken;

  const CompanyScreen({
    super.key,
    required this.companyId,
    this.userPhone,
    this.authToken,
  });

  @override
  _CompanyScreenState createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  Map? companyData;
  List<Map<String, dynamic>> cards = [];
  bool _isLoading = true;
  bool _isLoadingCards = false;
  bool _isProcessingPayment = false;
  String _errorMessage = '';
  String _selectedCardId = '';
  String _selectedCardLast4 = '';
  String? _userPhone;
  String? _authToken;
  TextEditingController _amountController = TextEditingController();

  // Base URL for API requests - this should match your backend
  final String _baseUrl = 'http://192.168.58.135:5000'; // Ensure this matches your actual backend URL

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCompanyDetails();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // If data is already provided through constructor
    if (widget.userPhone != null) {
      setState(() {
        _userPhone = widget.userPhone;
      });
    }

    if (widget.authToken != null) {
      setState(() {
        _authToken = widget.authToken;
      });
    }

    // Load data from SharedPreferences if not provided
    if (_userPhone == null || _authToken == null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userPhone ??= prefs.getString('user_phone');
        _authToken ??= prefs.getString('auth_token');
      });
    }

    print("User Phone: $_userPhone");
    print("Token available: ${_authToken != null ? 'Yes' : 'No'}");
  }

  Future _fetchCompanyDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print("Fetching company details for ID: ${widget.companyId}");
      final response = await http.get(
        Uri.parse('$_baseUrl/company/${widget.companyId}'),
        headers: {'Content-Type': 'application/json'},
      );

      print("Company API response code: ${response.statusCode}");
      print("Company API response body: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          companyData = jsonDecode(response.body);
          _isLoading = false;
        });
        print("Company data loaded: ${companyData!['name']}");
      } else {
        setState(() {
          _errorMessage = 'Error loading company: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Exception during company fetch: $e");
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future _fetchUserCards() async {
    // Check for required data
    if (_userPhone == null) {
      setState(() {
        _errorMessage = 'Could not retrieve user phone number';
      });
      return;
    }

    if (_authToken == null) {
      setState(() {
        _errorMessage = 'Authorization required. Please login again.';
      });
      return;
    }

    setState(() {
      _isLoadingCards = true;
      _errorMessage = '';
    });

    try {
      // Add authorization header with token
      print("Fetching cards for user: $_userPhone");
      final response = await http.get(
        Uri.parse('$_baseUrl/user_cards/$_userPhone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      print("Cards API response code: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("Cards API response body: ${response.body}");
        final data = jsonDecode(response.body);
        setState(() {
          cards = List<Map<String, dynamic>>.from(data['cards']);
          _isLoadingCards = false;
        });
        print("Cards loaded: ${cards.length}");
        _showCardsBottomSheet();
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Authentication error. Please login again.';
          _isLoadingCards = false;
        });
        // You can add redirection to the login screen here
      } else {
        setState(() {
          _errorMessage = 'Error loading cards: ${response.statusCode}';
          _isLoadingCards = false;
        });
      }
    } catch (e) {
      print("Exception during cards fetch: $e");
      setState(() {
        _errorMessage = 'Network error while loading cards: $e';
        _isLoadingCards = false;
      });
    }
  }

  // Get only the last 4 digits of the card
  String _getCardLast4(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    return cardNumber.substring(cardNumber.length - 4);
  }

  void _showCardsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Card',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                child: _isLoadingCards
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
                    // Get the last 4 digits
                    final cardNumber = cards[index]['masked_number'] ??
                        cards[index]['card_number'] ?? '';
                    final last4 = _getCardLast4(cardNumber);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          'Card ⋯⋯ $last4',
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
                          print("Selected card: ID=${cards[index]['id']}, last4=$last4");
                          setState(() {
                            _selectedCardId = cards[index]['id'].toString();
                            _selectedCardLast4 = last4;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Updated method for payment processing with improved error handling and debugging
  Future<void> _processPayment() async {
    // Check for selected card
    if (_selectedCardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a card for payment')),
      );
      return;
    }

    // Check payment amount
    double? amount;
    try {
      // Replace comma with dot for correct parsing
      amount = double.parse(_amountController.text.replaceAll(',', '.'));
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be greater than zero')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    // Set payment processing flag
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = '';
    });

    try {
      print("======== PAYMENT PROCESSING START ========");
      print("Sending payment request to: $_baseUrl/make_payment");
      print("Card ID: $_selectedCardId (type: ${_selectedCardId.runtimeType})");
      print("Company ID: ${widget.companyId} (type: ${widget.companyId.runtimeType})");
      print("Amount: $amount");

      // Convert ID from string to number before sending
      final cardIdInt = int.parse(_selectedCardId);
      final companyIdInt = int.parse(widget.companyId);

      print("Converted card ID: $cardIdInt");
      print("Converted company ID: $companyIdInt");

      final payload = {
        'card_id': cardIdInt,
        'company_id': companyIdInt,
        'amount': amount,
      };

      print("Data being sent: ${jsonEncode(payload)}");

      final response = await http.post(
        Uri.parse('$_baseUrl/make_payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode(payload),
      );

      print("Response code: ${response.statusCode}");
      print("Response body: ${response.body}");
      print("======== PAYMENT PROCESSING END ========");

      // Reset payment processing flag
      setState(() {
        _isProcessingPayment = false;
      });

      if (response.statusCode == 200) {
        // Payment successful
        final responseData = jsonDecode(response.body);
        // Show success dialog
        _showSuccessDialog(responseData);
      } else {
        // Error handling
        Map<String, dynamic> error = {};
        try {
          error = jsonDecode(response.body);
          print("Parsed error: $error");
        } catch (e) {
          print("Could not parse error response: $e");
          error = {'error': 'Unable to read server response'};
        }

        setState(() {
          _errorMessage = error['error'] ?? 'An error occurred while processing the payment (${response.statusCode})';
        });

        // Check for specific insufficient funds error
        if (error['error'] == 'Insufficient funds on card') {
          _showInsufficientFundsDialog(error['available_balance']);
        } else {
          // General error dialog
          _showErrorDialog(_errorMessage);
        }
      }
    } catch (e) {
      print("Exception during payment processing: $e");
      setState(() {
        _isProcessingPayment = false;
        _errorMessage = 'Network error: $e';
      });

      _showErrorDialog('Could not complete the payment. Check your internet connection. Error: $e');
    }
  }

  // Method to display successful payment
  void _showSuccessDialog(Map<String, dynamic> paymentData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Successful Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your payment has been successfully processed.'),
              const SizedBox(height: 16),
              Text('Amount: ${paymentData['transaction_details']['amount']} UZS'),
              Text('New Balance: ${paymentData['new_balance']} UZS'),
              Text('Company: ${paymentData['transaction_details']['company']}'),
              Text('Transaction Time: ${paymentData['transaction_details']['timestamp']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to main screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Method to display insufficient funds error
  void _showInsufficientFundsDialog(double availableBalance) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Insufficient Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your card does not have enough funds to complete this payment.'),
              const SizedBox(height: 8),
              Text('Available balance: $availableBalance UZS'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Method to display general error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && companyData == null
          ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
          : companyData == null
          ? const Center(child: Text('No data'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Company logo with fixed size
                Image.network(
                  "$_baseUrl/${companyData!['logo']}",
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.business, size: 50),
                ),
                const SizedBox(width: 10),
                // Company name
                Expanded(
                  child: Text(
                    companyData!['name'] ?? 'No name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Amount input field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Card selection button right under input
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _userPhone == null || _authToken == null
                  ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Authorization required')),
                );
                // You can add redirection to the login screen here
              }
                  : _fetchUserCards,
              child: const Text('Select Card', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            // Selected card information (simplified)
            if (_selectedCardLast4.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Selected card: $_selectedCardLast4',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            // Authorization error display
            if (_errorMessage.isNotEmpty && companyData != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            // Spacer to push payment button down
            const Spacer(),
            // Payment button at the bottom of the screen
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Block button if payment is being processed
              onPressed: _isProcessingPayment
                  ? null
                  : () {
                if (_amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter payment amount')),
                  );
                  return;
                }

                if (_selectedCardId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a card for payment')),
                  );
                  return;
                }

                // Call payment processing method
                _processPayment();
              },
              child: _isProcessingPayment
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Processing payment...', style: TextStyle(fontSize: 16)),
                ],
              )
                  : const Text('PAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16), // Small bottom padding
          ],
        ),
      ),
    );
  }
}