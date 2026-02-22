# reward_token_app

Reward Token is a Flutter + Firebase app for registering customers, issuing QR cards, scanning customers at checkout, and adding loyalty points.

## Current Features

- Employee login with **username or email + 4-digit PIN** (Firebase Auth).
- Role-aware navigation:
	- All users: **Home**, **QR Scan**, **Customer Registration**
	- Admin users: plus **Employee Registration** and **Admin Registration**
- Customer registration with form validation (first name, last name, email, phone).
- UUID-based customer identity and Firestore persistence.
- Real-time customer synchronization from Firestore into in-app state.
- Home screen customer list with current points and empty-state CTA.
- Customer QR card generation (QR payload is customer UUID).
- Customer QR card page actions:
	- **Print** (PDF print flow)
	- **Save as image** (PNG file)
- QR scanner features:
	- Camera scanning with overlay
	- Flash toggle
	- Front/back camera switch
	- Duplicate-scan suppression
- QR import from gallery image.
- Scan result flow:
	- UUID validation
	- Customer lookup
	- Current points display
	- Purchase price input
	- Points conversion and Firestore point increment update
- Employee registration (multi-step):
	- Details + PIN setup
	- Firebase Auth user creation
	- Firestore employee profile creation
	- Role assignment (`employee` / `admin`)
- Admin registration (multi-step), with fixed admin role.
- Custom dark theme and branded company display (`Reward Token`).

## Not Currently Implemented

- Logout action in the UI.
- Customer edit/delete management screens.
- Rewards redemption flow (current flow supports point accumulation only).

## Tech Stack

- Flutter (Material 3)
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- `mobile_scanner`, `image_picker`, `qr_flutter`, `printing`, `pdf`
