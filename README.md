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

## 📝 Recent Updates & Enhancements (Rebranding & Core Modules)

We recently completed a comprehensive set of rebranding and core modules alignment enhancements:

### 🔐 Rebranding & Login Page
- Rebranded app headers to Hindi `मॉयल लिमिटेड` (upper line) and English `MOIL Limited` (lower line).
- Removed legacy subtitles ("Leave Management System" and "Sign in to your LMS account") to simplify the login UI.
- Integrated support contact information inside the login card footer:
  - **Email**: `moilnagpur[at]gmail[dot]com`
  - **Contact no.**: `+91 89567 93981`
- Pre-filled mock login credentials automatically in debug mode (`Employee ID: 16194`, `Password: 1009522`) inside the sign-in fields.

### 📊 Dashboard Enhancements
- Removed the redundant Employee Information details card.
- Replaced "Recent Leaves" with a full list under the heading **"Leaves Till Date"**.
- Cleaned up layout headers (removed the "Quick Access" label).
- **Dynamic Leave Quota Dates**: Configured the dashboard quota cards to automatically extract and display the date of the **last leave taken** for each category:
  - Earned Leave (EL), Casual Leave (CL), Half Pay Leave (HPL), and Optional Leave (OP) cards display their last used dates (e.g., `(12-04-2026)`).

### 💰 Payslip Period Filters & Document Dialogs
- Added a period selection dropdown on the Payslip screen, defaulting to the latest period. Overview metrics dynamically update on selection.
- Integrated a Year selection filter dropdown next to the **"Payslip History"** header.
- Redesigned the in-app "View Payslip" dialog to follow the layout of the printed Gautam Payment Slip (side-by-side earnings/deductions table, bank details grid, Form 16, and leave balance summary).

### 👤 HRIS Profile Sheets & PDF Exports
- Standardized all raw employee date values inside `rawEmployees` database to follow the hyphenated `dd-mm-yyyy` format.
- Modified profile screens to output in a single-column layout on mobile, and standard 850px bordered sheet layout on web.
- Configured "Date of Last Promotion" to read from the raw seniority list date (`dosl` column).
- Integrated PDF export functionality on the profile page, outputting clean A4 sheets matching specifications.

### 📅 Leaves Renaming, Quota Tabs & Status Table
- Renamed "Quarterly Leave Apply" to **"Leave Apply"** globally.
- Registered **"Leave Quota"** as a sub-menu item on web sidebar navigation, and as a tab on mobile screens.
- Added `Applied Time` (appliedOn) and `Approve Time` (approvedOn) columns formatted as `dd-mm-yyyy HH:mm` in the leave status table.

### 🎉 Holiday Calendar
- Programmed the list to grey out passed/expired holidays in lists.
- Populated the 8 public holidays for 2025 and 18 optional/restricted holidays for 2026 exactly matching the provided screenshots.
- Defaulted the selected year filter to `2025` for immediate loading of public holidays.

