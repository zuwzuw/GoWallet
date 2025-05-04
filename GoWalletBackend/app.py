from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, current_app, send_file, send_from_directory
import os
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from sqlalchemy.exc import IntegrityError
from flask_migrate import Migrate
from functools import wraps
from flask_login import current_user
from flask_login import LoginManager
from flask_login import UserMixin
from flask_jwt_extended import jwt_required, get_jwt_identity
from flask_jwt_extended import JWTManager
import qrcode
from datetime import datetime, timedelta

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "postgresql://postgres:postgres@localhost/gowallet"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = "supersecretkey"
db = SQLAlchemy(app)
migrate = Migrate(app, db)
login_manager = LoginManager()
login_manager.init_app(app)
UPLOAD_FOLDER = 'static/uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

class Admin(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)

class Company(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    comments = db.Column(db.String(200), nullable=True)
    address = db.Column(db.Text, nullable=True)
    account_number = db.Column(db.String(50), nullable=False, unique=True)
    qr_code = db.Column(db.Text, nullable=False)
    logo = db.Column(db.String(255), nullable=True)
    
    # Relationship with transactions (one company has many transactions)
    transactions = db.relationship('Transaction', backref='company', lazy=True)

# Card model (with corrected relationships)
class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    card_number = db.Column(db.String(16), nullable=False)
    masked_number = db.Column(db.String(19))
    expiry_month = db.Column(db.String(2))
    expiry_year = db.Column(db.String(2))
    cardholder_name = db.Column(db.String(100))
    balance = db.Column(db.Float, default=0.0)
    
    # Relationship with transactions (one card has many transactions)
    transactions = db.relationship('Transaction', backref='card', lazy=True)

# New Transaction model for payments
class Transaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    card_id = db.Column(db.Integer, db.ForeignKey('card.id'), nullable=False)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    amount = db.Column(db.Float, nullable=False)  # Payment amount
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)  # Transaction time
    
    def to_dict(self):
        """Convert to dictionary for API"""
        return {
            'id': self.id,
            'card_id': self.card_id,
            'company_id': self.company_id,
            'company_name': self.company.name if self.company else "Unknown company",
            'company_logo': self.company.logo if self.company else None,
            'amount': self.amount,
            'timestamp': self.timestamp.strftime('%Y-%m-%d %H:%M:%S')
        }

class User(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    
    # Keep only one relationship definition between User and Card
    cards = db.relationship('Card', backref='user', lazy=True)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
def token_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = None
        
        # Check if token is in header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
            
        try:
            # Verify and decode the token
            import jwt
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.filter_by(id=data['user_id']).first()
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
                
        except Exception as e:
            return jsonify({'error': f'Invalid token: {str(e)}'}), 401
            
        # Pass the current_user to the route function
        return f(current_user=current_user, *args, **kwargs)
    return decorated_function

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

APP_SCHEME = "gowallet://company/"
QR_FOLDER = "static/qrcodes"
UPLOAD_FOLDER = "static/uploads"
def generate_qr_code(account_number):
    deep_link = f"{APP_SCHEME}{account_number}"  # Generate deep link
    qr = qrcode.make(deep_link)
    
    # Create folder if it doesn't exist
    if not os.path.exists(QR_FOLDER):
        os.makedirs(QR_FOLDER)
    
    qr_path = os.path.join(QR_FOLDER, f"{account_number}.png")
    qr.save(qr_path)
    return qr_path 

@login_manager.user_loader
def load_user(user_id):
    return Admin.query.get(int(user_id))

@app.route("/", methods=["GET", "POST"])
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form.get("username")
        email = request.form.get("email")
        password = request.form.get("password")

        if not username or not email or not password:
            flash("All fields are required!", "error")
            return redirect(url_for("register"))

        # Check if a user with the same email or username already exists
        existing_user = Admin.query.filter((Admin.username == username) | (Admin.email == email)).first()
        if existing_user:
            flash("A user with this username or email already exists!", "error")
            return redirect(url_for("register"))

        hashed_password = generate_password_hash(password)

        new_admin = Admin(username=username, email=email, password=hashed_password)
        db.session.add(new_admin)
        
        try:
            db.session.commit()
            flash("Registration successful!", "success")
            return redirect(url_for("login"))
        except IntegrityError:
            db.session.rollback()
            flash("Error saving data. The email might already be registered.", "error")
            return redirect(url_for("register"))

    return render_template("register.html", current_user=None)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email")
        password = request.form.get("password")

        if not email or not password:
            flash("All fields are required!", "error")
            return redirect(url_for("login"))

        user = Admin.query.filter_by(email=email).first()
        if not user or not check_password_hash(user.password, password):
            flash("Invalid email or password!", "error")
            return redirect(url_for("login"))

        flash("Login successful!", "success")
        return redirect(url_for("home"))

    return render_template("login.html")

@app.route("/home")
def home():
    companies = Company.query.all()
    return render_template("home.html", companies=companies)

@app.route('/add_company', methods=['GET', 'POST'])
def add_company():
    if request.method == 'POST':
        name = request.form['name']
        address = request.form.get('address', '')
        account_number = request.form['account_number'] 
        comments = request.form.get('comments', '')
        qr_code = generate_qr_code(account_number)

        # Check if a company with this account_number already exists
        existing_company = Company.query.filter_by(account_number=account_number).first()
        if existing_company:
            flash("A company with this account number already exists!", "danger")
            return redirect(url_for('add_company'))

        logo_file = request.files.get('logo')
        logo_filename = None

        if logo_file and allowed_file(logo_file.filename):
            if not os.path.exists(UPLOAD_FOLDER):
                os.makedirs(UPLOAD_FOLDER)

            filename = secure_filename(logo_file.filename)
            logo_path = os.path.join(UPLOAD_FOLDER, filename)
            logo_file.save(logo_path)
            logo_filename = f'static/uploads/{filename}'

        new_company = Company(
            name=name,
            address=address,
            account_number=account_number,
            comments=comments, 
            qr_code=qr_code,
            logo=logo_filename
        )

        db.session.add(new_company)
        db.session.commit()
        
        flash("Company successfully added!", "success")
        return redirect(url_for('home'))

    return render_template('add_company.html')



@app.route('/edit_company/<int:company_id>', methods=['GET', 'POST'])
def edit_company(company_id):
    company = Company.query.get(company_id)
    if not company:
        flash('Company not found.', 'error')
        return redirect(url_for('home'))
    
    if request.method == 'POST':
        company.name = request.form['name']
        company.address = request.form['address']
        company.account_number = request.form['account_number']
        company.comments = request.form['comments']
        db.session.commit()
        flash('Company data updated!', 'success')
        return redirect(url_for('home'))
    
    return render_template('edit_company.html', company=company)

@app.route('/delete_company/<int:company_id>', methods=['POST'])
def delete_company(company_id):
    company = Company.query.get(company_id)
    if company:
        db.session.delete(company)
        db.session.commit()
        flash('Company successfully deleted!', 'success')
    else:
        flash('Company not found.', 'error')
    return redirect(url_for('home'))

@app.route('/download_qr/<int:company_id>')
def download_qr(company_id):
    company = Company.query.get_or_404(company_id)
    if company.qr_code:
        return send_file(company.qr_code, as_attachment=True)
    else:
        return "QR code not found", 404

@app.route('/company/<account_number>', methods=['GET'])
def get_company(account_number):
    company = db.session.query(Company).filter_by(account_number=account_number).first()
    
    if not company:
        return jsonify({"error": "Company not found"}), 404
    
    return jsonify({
        "name": company.name,
        "logo": company.logo
    })

@app.route('/company/<int:company_id>/transactions')
def company_transactions(company_id):
    """
    Displays transaction history for a specific company with pagination.
    """
    # Get the company
    company = Company.query.get_or_404(company_id)
    
    # Get pagination parameters
    page = request.args.get('page', 1, type=int)
    per_page = 20  # number of transactions per page
    
    # Get transactions with pagination
    transactions_query = Transaction.query.filter_by(company_id=company_id) \
        .order_by(Transaction.timestamp.desc())
    
    transactions_paginated = transactions_query.paginate(page=page, per_page=per_page, error_out=False)
    transactions = transactions_paginated.items
    
    # Enrich transaction data with user and card information
    enriched_transactions = []
    total_amount = 0
    
    for transaction in transactions:
        # Get card and user
        card = Card.query.get(transaction.card_id)
        user = User.query.get(card.user_id) if card else None
        
        # Format masked card number
        card_number = "•••• " + card.card_number[-4:] if card else "Unknown card"
        
        # Format user name
        user_name = user.name if user else "Unknown user"
        
        # Add to total amount
        total_amount += transaction.amount
        
        # Add enriched data
        enriched_transactions.append({
            'id': transaction.id,
            'timestamp': transaction.timestamp.strftime('%d.%m.%Y %H:%M:%S'),
            'card_number': card_number,
            'user_name': user_name,
            'amount': "{:,.2f}".format(transaction.amount).replace(',', ' ')
        })
    
    # Format total amount
    total_amount_formatted = "{:,.2f}".format(total_amount).replace(',', ' ')
    
    # Calculate total number of pages
    total_pages = transactions_paginated.pages or 1
    
    return render_template(
        'company_transactions.html',
        company=company,
        transactions=enriched_transactions,
        total_amount=total_amount_formatted,
        page=page,
        total_pages=total_pages
    )
@app.route('/static/uploads/<path:filename>')
def serve_uploaded_file(filename):
    return send_from_directory('static/uploads', filename)



@app.route('/register_user', methods=['POST'])
def register_user():
    data = request.json
    name = data.get('name')
    phone = data.get('phone')
    password = data.get('password')

    if not name or not phone or not password:
        return jsonify({'error': 'All fields are required'}), 400

    existing_user = User.query.filter_by(phone=phone).first()
    if existing_user:
        return jsonify({'error': 'Phone number already registered'}), 400

    new_user = User(name=name, phone=phone)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': 'User registered successfully', 'user_id': new_user.id}), 201

@app.route('/login_user', methods=['POST'])
def login_user():
    data = request.get_json()

    if not data or 'phone' not in data or 'password' not in data:
        return jsonify({'error': 'Missing phone or password'}), 400

    phone = data['phone']
    password = data['password']

    user = User.query.filter_by(phone=phone).first()

    if not user:
        return jsonify({'error': 'User not found'}), 404

    if not check_password_hash(user.password_hash, password):
        return jsonify({'error': 'Invalid phone or password'}), 401
    
    # Generate JWT token
    import jwt
    import datetime
    
    token = jwt.encode({
        'user_id': user.id,
        'phone': user.phone,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    }, app.config['SECRET_KEY'], algorithm='HS256')
    
    return jsonify({
        'message': 'Login successful',
        'user_id': user.id,
        'phone': user.phone,
        'token': token
    }), 200

@app.route('/add_card', methods=['POST'])
def add_card():
    import random  # Import random module to generate random balance
    
    print(">>> Request received at /add_card")
    data = request.json
    print(">>> Received data:", data)
    
    required_fields = ['phone', 'card_number', 'expiry_month', 'expiry_year', 'cardholder_name']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    user = User.query.filter_by(phone=data['phone']).first()
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    # Mask card number (keep last 4 digits)
    masked_number = "**** **** **** " + data['card_number'][-4:]
    
    # Generate random balance from 100000 to 5000000 sum
    random_balance = random.uniform(100000, 5000000)
    # Round to whole number or 2 decimal places, depending on requirements
    random_balance = round(random_balance, 2)
    
    # Create new card and link to user
    new_card = Card(
        user_id=user.id,
        card_number=data['card_number'],
        masked_number=masked_number,
        expiry_month=data['expiry_month'],
        expiry_year=data['expiry_year'],
        cardholder_name=data['cardholder_name'],
        balance=random_balance  # Set generated balance
    )
    
    try:
        db.session.add(new_card)
        db.session.commit()
        # Return information about created card, including balance
        return jsonify({
            "success": "Card added successfully",
            "card_info": {
                "masked_number": masked_number,
                "balance": random_balance
            }
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"Failed to add card: {str(e)}"}), 500



@app.route('/user_cards/<phone>', methods=['GET'])
@token_required
def get_user_cards(phone, current_user):
    if current_user.phone != phone:
        return jsonify({'error': 'Unauthorized access'}), 403

    cards = Card.query.filter_by(user_id=current_user.id).all()

    cards_data = [{
        'id': card.id,
        'masked_number': f"**** **** **** {card.card_number[-4:]}",
        'card_number': card.card_number,
        'expiry_month': card.expiry_month,
        'expiry_year': card.expiry_year,
        'cardholder_name': card.cardholder_name
    } for card in cards]

    return jsonify({'cards': cards_data})

@app.route('/get_card/<int:card_id>', methods=['GET'])
def get_card(card_id):
    card = Card.query.filter_by(id=card_id).first()
    
    if card:
        # Get the last 5 transactions for the card
        recent_transactions = Transaction.query.filter_by(card_id=card_id)\
            .order_by(Transaction.timestamp.desc())\
            .limit(5).all()
        
        # Convert transactions to a list of dictionaries
        transactions_data = [transaction.to_dict() for transaction in recent_transactions]
        
        return jsonify({
            'id': card.id,
            'masked_number': card.masked_number if card.masked_number else f'**** **** **** {card.card_number[-4:]}',
            'cardholder_name': card.cardholder_name,
            'expiry_month': card.expiry_month,
            'expiry_year': card.expiry_year,
            'balance': card.balance,
            'recent_transactions': transactions_data  # Add recent transactions
        })
    else:
        return jsonify({'error': 'Card not found'}), 404
    
@app.route('/delete_card/<int:card_id>', methods=['DELETE'])
@token_required
def delete_card(current_user, card_id):
    card = Card.query.filter_by(id=card_id, user_id=current_user.id).first()

    if not card:
        return jsonify({'error': 'Card not found or access denied'}), 404

    try:
        db.session.delete(card)
        db.session.commit()
        return jsonify({'message': 'Card successfully deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Failed to delete card: {str(e)}'}), 500
    
@app.route('/make_payment', methods=['POST'])
def make_payment():
    """
    Route for processing payments from users to companies.
    
    Expects JSON in request body:
    {
        "card_id": 123,         // ID of the card used for payment
        "company_id": 5899438,  // Account number of the company receiving payment
        "amount": 100000.00     // Payment amount
    }
    """
    print("========== PAYMENT PROCESSING START ==========")
    
    # Authorization check
    token = request.headers.get('Authorization')
    if not token or not token.startswith('Bearer '):
        print("Authorization error. Token is missing or has invalid format.")
        return jsonify({"error": "Authorization required"}), 401
    
    # Get data from request body
    try:
        print(f"Payment request received. Request data: {request.data}")
        data = request.json
        print(f"Parsed JSON data: {data}")
        
        # Check if all required fields are present
        required_fields = ['card_id', 'company_id', 'amount']
        for field in required_fields:
            if field not in data:
                print(f"Missing required field: {field}")
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        # Get and verify values
        card_id = data['card_id']
        account_number = str(data['company_id'])  # Company account number, not ID
        amount = float(data['amount'])
        
        print(f"card_id type: {type(card_id)}, value: {card_id}")
        print(f"account_number type: {type(account_number)}, value: {account_number}")
        print(f"amount type: {type(amount)}, value: {amount}")
        
        # Convert string IDs to integers if they came as strings
        if isinstance(card_id, str):
            card_id = int(card_id)
            print(f"card_id converted to int: {card_id}")
        
        if amount <= 0:
            print("Error: payment amount must be positive")
            return jsonify({"error": "Payment amount must be positive"}), 400
        
        # Check if card exists
        card = Card.query.get(card_id)
        print(f"Searching card with ID {card_id}: {'found' if card else 'not found'}")
        
        if not card:
            # Additional diagnostics
            all_cards = Card.query.all()
            print(f"All available cards: {[c.id for c in all_cards]}")
            return jsonify({"error": "Card not found"}), 404
        
        # Check if company exists by account number
        company = Company.query.filter_by(account_number=account_number).first()
        print(f"Searching company by account number {account_number}: {'found' if company else 'not found'}")
            
        if not company:
            # List all companies for diagnostics
            all_companies = Company.query.all()
            print(f"All available companies: {[(c.id, c.name, c.account_number) for c in all_companies]}")
            return jsonify({"error": "Company with the specified account number not found"}), 404
        
        print(f"Company found: ID={company.id}, Name={company.name}, Account={company.account_number}")
        
        # Check if sufficient funds
        if card.balance < amount:
            print(f"Insufficient funds: available {card.balance}, required {amount}")
            return jsonify({
                "error": "Insufficient funds on card", 
                "available_balance": card.balance
            }), 400
        
        # Create transaction and deduct funds
        try:
            transaction = Transaction(
                card_id=card_id,
                company_id=company.id,  # Use company ID from database
                amount=amount,
                timestamp=datetime.utcnow() + timedelta(hours=5)
            )
            
            # Deduct funds
            old_balance = card.balance
            card.balance -= amount
            
            print(f"Creating transaction: card_id={card_id}, company_id={company.id}, amount={amount}")
            print(f"Card balance change: {old_balance} -> {card.balance}")
            
            # Save changes
            db.session.add(transaction)
            db.session.commit()
            
            print(f"Transaction successfully created: ID={transaction.id}")
            
            # Form response
            response = {
                "status": "success",
                "message": "Payment successfully completed",
                "transaction_id": transaction.id,
                "new_balance": card.balance,
                "transaction_details": {
                    "amount": amount,
                    "company": company.name,
                    "timestamp": transaction.timestamp.strftime('%Y-%m-%d %H:%M:%S')
                }
            }
            
            print("Response successfully formed")
            print("========== PAYMENT PROCESSING END ==========")
            return jsonify(response), 200
            
        except Exception as e:
            db.session.rollback()
            print(f"Error creating transaction: {e}")
            print("========== PAYMENT PROCESSING END (WITH ERROR) ==========")
            return jsonify({"error": f"Error creating transaction: {str(e)}"}), 500
        
    except ValueError as e:
        print(f"Error processing value: {e}")
        print("========== PAYMENT PROCESSING END (WITH ERROR) ==========")
        return jsonify({"error": "Invalid amount or ID format"}), 400
    
    except Exception as e:
        print(f"Unhandled error: {e}")
        print("========== PAYMENT PROCESSING END (WITH ERROR) ==========")
        return jsonify({"error": f"Error processing payment: {str(e)}"}), 500

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(debug=True, host="0.0.0.0", port=5000)