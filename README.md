# Employee Management System - Flutter

A comprehensive **Employee Management System** mobile application built with **Flutter**, integrated with a **Next.js** backend and **SAP via CSV/FTP**.

## 📱 Screens & Features

| Module | Screens |
|--------|---------|
| 🔐 **Authentication** | Login, Change Password |
| 📊 **Dashboard** | Overview, Quick Stats, Module Grid |
| 📅 **Leave Management** | Leave Status, Leave Balance, Apply Leave, Team Calendar |
| ✈️ **Tour Management** | Tour Status, Apply Tour |
| 💰 **Payslip** | View & Download Monthly Payslips |
| 🎉 **Holiday** | Holiday Calendar with Filters |
| ✅ **Approvals** | Multi-level Leave & Tour Approvals |
| 👤 **Profile** | View & Edit Employee Profile |
| 🔔 **Notifications** | Real-time Push Notifications |

## 🏗️ Architecture

```
lib/
├── main.dart                        # App entry point
├── app.dart                         # App configuration & theming
├── core/
│   ├── constants/
│   │   ├── app_colors.dart          # Color palette
│   │   ├── app_routes.dart          # Named routes
│   │   └── app_strings.dart         # String constants
│   ├── models/
│   │   ├── user_model.dart          # User data model
│   │   ├── leave_model.dart         # Leave models
│   │   └── tour_model.dart          # Tour model
│   ├── providers/
│   │   ├── auth_provider.dart       # Authentication state
│   │   ├── leave_provider.dart      # Leave state
│   │   ├── tour_provider.dart       # Tour state
│   │   ├── employee_provider.dart   # Employee state
│   │   ├── notification_provider.dart
│   │   └── holiday_provider.dart
│   └── widgets/
│       └── app_widgets.dart         # Reusable widgets
└── features/
    ├── auth/screens/login_screen.dart
    ├── dashboard/screens/dashboard_screen.dart
    ├── leave/screens/
    │   ├── leave_screen.dart         # Tab container
    │   ├── leave_status_screen.dart  # SAP Leave Status layout
    │   ├── leave_balance_screen.dart # SAP Leave Balance layout
    │   ├── leave_apply_screen.dart   # SAP Leave Applied form
    │   └── leave_calendar_screen.dart # SAP Team Calendar
    ├── tour/screens/tour_screen.dart
    ├── payslip/screens/payslip_screen.dart
    ├── holiday/screens/holiday_screen.dart
    ├── profile/screens/profile_screen.dart
    ├── notifications/screens/notifications_screen.dart
    └── approval/screens/approval_screen.dart
```

## 🚀 Setup & Run

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio / VS Code

### Steps

```bash
# Navigate to project
cd employee_management

# Install dependencies
flutter pub get

# Create asset directories
mkdir -p assets/images assets/icons assets/animations

# Run the app
flutter run
```

### Connect to Backend

Update the API base URL in your service layer:
```dart
const String baseUrl = 'http://YOUR_NEXTJS_SERVER:3000/api';
```

## 🎨 Design System

| Element | Value |
|---------|-------|
| Primary | `#4F8EF7` (Blue) |
| Accent | `#7C3AED` (Purple) |
| Background | `#0A0E27` (Dark Navy) |
| Success | `#10B981` (Green) |
| Warning | `#F59E0B` (Amber) |
| Error | `#EF4444` (Red) |
| Font | Inter (Google Fonts) |

## 📡 SAP Integration Flow

```
SAP → CSV Files → FTP/SFTP Server
                        ↓
               Next.js Backend (downloads every 4h)
                        ↓
               CSV → JSON → REST APIs
                        ↓
               Flutter App (displays data)
                        ↓
               User Actions (leave/tour apply)
                        ↓
               Backend updates CSV → FTP/SFTP → SAP
```

## 👥 User Roles

- **Super Admin** - Full system access
- **CMD & DO** - Top-level approvals
- **HOD** - Department approvals
- **Reporting Officer** - Team management
- **Employee** - Self-service
