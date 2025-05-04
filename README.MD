# GoWallet

GoWallet is a comprehensive QR-based payment system consisting of two interconnected components:
1. An admin web application built with Python/Flask/PostgreSQL (GoWalletBackend)
2. A client mobile application developed with Flutter/Dart (GoWalletApp)

The system enables merchants to generate QR codes through the admin web interface, which customers can then scan with the mobile app to make payments using their registered bank cards.

## System Overview

### Admin Web Application (GoWalletBackend)
- Allows administrators to manage merchant accounts
- Generates QR codes for merchants
- Tracks transaction history
- Views payment analytics
- Built with Flask, PostgreSQL, and HTML/CSS/JavaScript

### Mobile Client Application (GoWalletApp)
- User registration and authentication
- Bank card management
- QR code scanning for payments
- Transaction history
- Built with Flutter/Dart for Android devices

## Project Structure

```
GOWALLET/
├── GoWalletApp/                    # Mobile Flutter application
│   ├── .dart_tool/                 # Flutter build tool artifacts
│   ├── .idea/                      # IntelliJ IDEA project settings
│   ├── android/                    # Android platform-specific code
│   │   ├── app/                    # Main Android app code
│   │   ├── gradle/                 # Gradle wrapper files
│   │   └── ...
│   ├── build/                      # Build outputs
│   ├── ios/                        # iOS platform-specific code
│   ├── lib/                        # Dart source code
│   │   ├── main.dart               # Main application entry point
│   │   ├── login_screen.dart       # Login screen UI and logic
│   │   ├── add_card_screen.dart    # Card addition screen
│   │   ├── card_screen.dart        # Card management screen
│   │   ├── company_screen.dart     # Company/merchant view screen
│   │   └── home_screen.dart        # Main home screen
│   ├── test/                       # Unit and widget tests
│   ├── web/                        # Web platform support
│   ├── windows/                    # Windows platform support
│   ├── .flutter-plugins            # Flutter plugin config
│   ├── .flutter-plugins-dependencies # Flutter plugin dependencies
│   ├── .gitignore                  # Git ignore rules
│   ├── .metadata                   # Flutter metadata
│   ├── analysis_options.yaml       # Dart analyzer settings
│   ├── pubspec.lock                # Locked dependencies versions
│   ├── pubspec.yaml                # Flutter package dependencies
│   └── v2.iml                      # IntelliJ module file
│
└── GoWalletBackend/                # Flask web application
    ├── app.py                      # Main Flask application
    ├── requirements.txt            # Python dependencies
    ├── migrations/                 # Database migration files
    ├── templates/                  # HTML templates
    ├── static/                     # Static assets
    │   ├── uploads/                # Uploaded merchant logos
    │   └── qrcodes/                # Generated QR codes
    └── venv/                       # Python virtual environment (not to be committed)
```

## Requirements

### Admin Web Application
- Python 3.8+
- Flask and Flask extensions
- PostgreSQL 12+
- pip (Python package manager)

### Mobile Client Application
- Flutter SDK 2.10+
- Dart SDK 2.16+
- Android SDK 30+
- Android device or emulator for testing

## Installation and Setup

### Admin Web Application (GoWalletBackend)

1. Clone the repository:
```bash
git https://github.com/zuwzuw/GoWallet
cd gowallet/GoWalletBackend
```

2. Create and activate a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows, use: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

If you don't have a requirements.txt file, install the following packages:
```bash
pip install flask flask-sqlalchemy flask-migrate flask-login flask-jwt-extended werkzeug psycopg2-binary qrcode pillow
pip freeze > requirements.txt
```

4. Create PostgreSQL database:
```bash
# Login to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE gowallet;

# Exit PostgreSQL
\q
```

5. Configure the database connection:
Open `app.py` and modify the database URI to match your PostgreSQL configuration:
```python
app.config["SQLALCHEMY_DATABASE_URI"] = "postgresql://postgres:postgres@localhost/gowallet"
```
Replace with your PostgreSQL credentials if different.

6. Create necessary directories for uploads and QR codes:
```bash
mkdir -p static/uploads
mkdir -p static/qrcodes
```

7. Initialize the database:
```bash
flask db init
flask db migrate -m "Initial migration"
flask db upgrade
```

8. Run the development server:
```bash
flask run --host=0.0.0.0 --port=5000
```

The admin web application should now be running at http://localhost:5000

### Mobile Client Application (GoWalletApp)

1. Create a new Flutter project (if starting from scratch):
```bash
# Install Flutter SDK if not already installed
# See https://flutter.dev/docs/get-started/install

# Create a new Flutter project
flutter create gowallet_app

# Rename the directory if needed
mv gowallet_app GoWalletApp
cd GoWalletApp
```

2. Add required Flutter packages in pubspec.yaml:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^0.13.5        # For API requests
  shared_preferences: ^2.0.15  # For local storage
  qr_code_scanner: ^1.0.1  # For scanning QR codes
  flutter_secure_storage: ^6.0.0  # For secure token storage
  provider: ^6.0.3   # For state management
  intl: ^0.17.0      # For date/number formatting
  flutter_svg: ^1.1.4  # For SVG support
  image_picker: ^0.8.5+3  # For image selection
```

3. Install Flutter dependencies:
```bash
flutter pub get
```

3. Configure the server address:
Open all files in the `lib` directory that contain API endpoint references and update them to match your server's IP address:

For example, in `main.dart`:
```dart
// Change this line:
Uri.parse('http://192.168.58.135:5000/register_user'),
// To your server's IP address:
Uri.parse('http://your_server_ip:5000/register_user'),
```

Make sure to update this IP address in all relevant files:
- `main.dart`
- `login_screen.dart`
- `add_card_screen.dart`
- `home_screen.dart`
- `card_screen.dart`
- `company_screen.dart`

4. Configure Android Manifest:
Open `android/app/src/main/AndroidManifest.xml` and ensure the following permissions are added:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet Permission -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Camera Permission for QR scanning -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <application
        android:label="GoWallet"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        <!-- usesCleartextTraffic is needed for HTTP connections -->
        
        <!-- QR code deep link handling -->
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="gowallet" />
        </intent-filter>
        
        <!-- Rest of your application configuration -->
    </application>
</manifest>
```

5. Run the app in debug mode:
```bash
flutter run
```

For building a release version:
```bash
flutter build apk
```

## Usage Guide

### Admin Web Application

1. **Register an Admin Account**:
   - Navigate to `/register`
   - Fill in the username, email, and password
   - Submit to create an admin account

2. **Login**:
   - Navigate to `/login`
   - Enter your email and password

3. **Add a Merchant**:
   - Click on "Add Company" in the navigation
   - Fill in the company details:
     - Name: Company/merchant name
     - Address: Physical location
     - Account Number: 20-digit bank account number
     - Comments: Additional information
     - Logo: Upload a company logo
   - Submit to create the merchant and generate a QR code

4. **Manage Merchants**:
   - View all merchants on the homepage
   - Edit merchant details by clicking "Edit"
   - Delete merchants by clicking "Delete"
   - Download QR codes for merchants by clicking "Download QR"

5. **View Transactions**:
   - Click on "Transactions" for any merchant
   - View transaction history with pagination
   - See details like timestamp, card information, user name, and amount

### Mobile Client Application

1. **Register a User Account**:
   - Open the app and fill in the registration form
   - Provide name, phone number, and password
   - Submit to create a user account

2. **Login**:
   - Enter your phone number and password
   - The app will authenticate and provide a token for transactions

3. **Add a Card**:
   - Navigate to the card management section
   - Enter card details:
     - Card number
     - Expiry month/year
     - Cardholder name
   - Submit to add the card to your account

4. **Make Payments**:
   - Scan a merchant's QR code using the app
   - Select a card to pay with
   - Enter the payment amount
   - Confirm to complete the transaction

5. **View Transaction History**:
   - Navigate to the history section
   - View all your past transactions
   - See details like merchant name, amount, and date

## API Endpoints

### User Authentication
- `POST /register_user` - Register a new mobile app user
- `POST /login_user` - User login, returns JWT token

### Card Management
- `POST /add_card` - Add a new card to user account
- `GET /user_cards/<phone>` - Get all cards for a user
- `GET /get_card/<card_id>` - Get specific card details
- `DELETE /delete_card/<card_id>` - Delete a card

### Payment Processing
- `POST /make_payment` - Process a payment transaction
- `GET /company/<account_number>` - Get company details by account number

### Admin Functionality
- `GET /home` - Admin dashboard with merchant list
- `GET/POST /add_company` - Add a new merchant
- `GET/POST /edit_company/<company_id>` - Edit merchant details
- `POST /delete_company/<company_id>` - Delete a merchant
- `GET /download_qr/<company_id>` - Download merchant QR code
- `GET /company/<company_id>/transactions` - View merchant transactions

## Database Schema

### Admin Tables
- `Admin`: Administrator accounts
- `Company`: Merchant information and QR codes

### User and Transaction Tables
- `User`: Mobile app user accounts
- `Card`: User's bank cards
- `Transaction`: Payment records

## QR Code Format

The QR codes generated by the system use a custom deep link format:
```
gowallet://company/<account_number>
```

This format allows the mobile app to open directly when scanning a QR code and identify the merchant for payment processing.

## Security Considerations

- The current implementation uses a hardcoded secret key. In production, use environment variables for sensitive configuration.
- Consider implementing HTTPS for secure communication.
- Add rate limiting for API endpoints to prevent abuse.
- Implement proper input validation on all user inputs.
- Consider adding two-factor authentication for admin accounts.

## Flutter App Details

### Flutter Packages Used

- **http**: Used for making API requests to the backend server
- **shared_preferences**: For storing user preferences and settings
- **qr_code_scanner**: Provides QR code scanning functionality
- **flutter_secure_storage**: Securely stores authentication tokens
- **provider**: State management solution
- **intl**: Internationalization and formatting for dates/currencies
- **flutter_svg**: Renders SVG images for better quality graphics
- **image_picker**: Enables selecting images from gallery or camera

### Key Flutter Files

- **main.dart**: Application entry point, sets up routes and theme
- **login_screen.dart**: Handles user authentication
- **add_card_screen.dart**: Interface for adding bank cards
- **card_screen.dart**: Shows card details and transaction history
- **company_screen.dart**: Displays merchant information when scanning QR codes
- **home_screen.dart**: Main dashboard after login

## Troubleshooting

### Common Issues

1. **Database Connection Errors**:
   - Verify PostgreSQL is running
   - Check username, password, and database name in connection string
   - Ensure network access to the database server

2. **QR Code Generation Issues**:
   - Check if the `qrcode` Python package is installed
   - Verify write permissions to the QR code directory

3. **Mobile App Connection Issues**:
   - Ensure the server IP address is correctly configured in the app
   - Check that the server is accessible from the mobile device
   - Verify firewall settings allow connections on port 5000

4. **Payment Processing Errors**:
   - Check log output for detailed error messages
   - Verify the card has sufficient balance
   - Ensure the company account number is valid

5. **QR Code Scanning Issues**:
   - Ensure camera permissions are granted to the app
   - Verify that the QR code format is correct
   - Check that the deep link scheme is properly configured in AndroidManifest.xml
   
6. **Flutter Build Issues**:
   - Run `flutter clean` followed by `flutter pub get`
   - Make sure Flutter SDK version is compatible with dependencies
   - Verify Android SDK path in local.properties file

## Production Deployment

### Admin Web Application

For production deployment, consider using:
- Gunicorn or uWSGI as a WSGI server
- Nginx or Apache as a reverse proxy
- Supervisor for process management

Example Nginx configuration:
```
server {
    listen 80;
    server_name your_domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /static {
        alias /path/to/gowallet/GoWalletBackend/static;
    }
}
```

### Mobile Client Application

For production:
- Create a signed APK for Google Play Store distribution
- Configure proper production API endpoints
- Consider implementing app updates mechanism

## Future Enhancements

- Implement push notifications for transaction confirmations
- Add analytics dashboard for merchants
- Implement loyalty program features
- Add support for recurring payments
- Enhance security with biometric authentication
- Add transaction dispute mechanism
- Implement multi-language support

## License

MIT License

Copyright (c) 2025 zuwzuw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Contact & Repository

- **GitHub Repository**: [https://github.com/zuwzuw/GoWallet](https://github.com/zuwzuw/GoWallet)
- **Contact Email**: zuma858@gmail.com

For bug reports, feature requests, or contributions, please use the GitHub issue tracker or contact the developer directly via email.