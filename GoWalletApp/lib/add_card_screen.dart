import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddCardScreen extends StatefulWidget {
  final String userPhone;
  final Function(String) onCardAdded;

  const AddCardScreen({super.key, required this.userPhone, required this.onCardAdded});

  @override
  _AddCardScreenState createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderNameController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderNameController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _saveCard() async {
    if (_formKey.currentState!.validate()) {
      // Format card number for masked display
      String cardNumber = _cardNumberController.text.replaceAll(' ', '');
      String last4Digits = cardNumber.substring(cardNumber.length - 4);
      String maskedNumber = "**** **** **** $last4Digits";

      // Prepare data according to the Card model in the database
      final cardData = {
        "phone": widget.userPhone,
        "card_number": cardNumber,
        "masked_number": maskedNumber,
        "cardholder_name": _cardHolderNameController.text,
        "expiry_month": _expiryMonthController.text,
        "expiry_year": _expiryYearController.text,
        "cvv": _cvvController.text, // Send for verification, but don't store in DB
      };

      try {
        final response = await http.post(
          Uri.parse('http://192.168.58.135:5000/add_card'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(cardData),
        );

        if (response.statusCode == 201) {
          // Return masked number to parent widget
          widget.onCardAdded(maskedNumber);
          Navigator.pop(context);
        } else if (response.statusCode == 409) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already have a card with this number')),
          );
        } else if (response.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error adding card')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Card'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Number Field
                TextFormField(
                  controller: _cardNumberController,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    hintText: 'XXXX XXXX XXXX XXXX',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    // Can add formatter to display spaces between groups of digits
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the card number';
                    }
                    if (value.replaceAll(' ', '').length < 16) {
                      return 'Card number must contain 16 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Card Holder Name
                TextFormField(
                  controller: _cardHolderNameController,
                  decoration: InputDecoration(
                    labelText: 'Cardholder Name',
                    hintText: 'IVAN IVANOV',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the cardholder name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Expiry Date (Month and Year)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryMonthController,
                        decoration: InputDecoration(
                          labelText: 'Month',
                          hintText: 'MM',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter month';
                          }
                          int? month = int.tryParse(value);
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid month';
                          }
                          // Additionally, can check for expired date
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _expiryYearController,
                        decoration: InputDecoration(
                          labelText: 'Year',
                          hintText: 'YY',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter year';
                          }
                          int? year = int.tryParse(value);
                          int currentYear = DateTime.now().year % 100;
                          if (year == null || year < currentYear) {
                            return 'Invalid year';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // CVV Field
                TextFormField(
                  controller: _cvvController,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the CVV code';
                    }
                    if (value.length < 3) {
                      return 'CVV must contain 3 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _saveCard,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Save Card',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}