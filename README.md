# Moil HR App Backend API

A Node.js & Express.js backend API designed to connect to the Hostinger MySQL database `u156958239_moil_hr_app`.

## Prerequisites

- **Node.js**: Version 14 or higher is recommended.
- **MySQL Remote Access**: Because Hostinger databases block external connections by default, you must configure remote database access to connect to the database from a local machine or external server.

---

## Installation

1. Navigate to the project directory:
   ```bash
   cd "/Users/apple/Flutter WB Project/Moil_backend"
   ```

2. Install all dependencies:
   ```bash
   npm install
   ```

---

## Configuration

### 1. Database Credentials Configuration
Copy the template `.env.example` file to `.env`:
```bash
cp .env.example .env
```

Open the `.env` file and replace the placeholder credentials with your Hostinger database details:
- `DB_HOST`: Hostinger MySQL database host (e.g. `sqlXXX.main-hosting.eu` or your Hostinger server IP address). You can find this under **MySQL Databases** -> **MySQL Server** in Hostinger hPanel.
- `DB_USER`: Your Hostinger MySQL username (e.g. `u156958239_username`).
- `DB_PASSWORD`: The password for your database user.
- `DB_NAME`: `u156958239_moil_hr_app`

### 2. Allow Remote Connections in Hostinger (CRITICAL)
If you are running this backend locally, Hostinger will reject database connections unless your IP is whitelisted.
1. Log in to your **Hostinger hPanel**.
2. Navigate to **Databases** -> **MySQL Databases**.
3. Scroll down to the **Remote MySQL** section.
4. Add your current public IP address in the **IP (IPv4 or IPv6)** input field.
   - *Alternative (For development only)*: Enter `%` in the IP field to allow connections from any IP address.
5. In the **Database** dropdown, select `u156958239_moil_hr_app`.
6. Click **Create** to save.

---

## Running the Application

### Development Mode (with hot reloading)
Runs the server using `nodemon` which will automatically reload files when code changes:
```bash
npm run dev
```

### Production Mode
Starts the server using standard node execution:
```bash
npm run start
```

The server runs on http://localhost:3000 by default (configurable in `.env`).

---

## API Endpoints

### 1. Welcome Endpoint
- **URL**: `GET /`
- **Description**: Verifies that the server is alive.
- **Example Response**:
  ```json
  {
    "message": "Welcome to the Moil HR App Backend API",
    "status": "Running",
    "timestamp": "2026-07-15T12:00:00.000Z"
  }
  ```

### 2. Health Check (including Database connectivity check)
- **URL**: `GET /api/health`
- **Description**: Validates that the Express application is running and performs a verification query to the Hostinger database.
- **Example Response (Success)**:
  ```json
  {
    "status": "UP",
    "uptime": 12.34,
    "database": {
      "status": "CONNECTED",
      "responseTimeMs": 42,
      "check": "OK"
    },
    "timestamp": "2026-07-15T12:00:05.000Z"
  }
  ```

### 3. Inspect Tables (Schema structure lookup)
- **URL**: `GET /api/tables`
- **Description**: Performs a database query using metadata tables to return a list of all tables in the `u156958239_moil_hr_app` database along with their row counts.
- **Example Response**:
  ```json
  {
    "database": "u156958239_moil_hr_app",
    "tableCount": 3,
    "tables": [
      { "name": "employees", "row_count": 25 },
      { "name": "departments", "row_count": 5 },
      { "name": "users", "row_count": 10 }
    ]
  }
  ```

### 4. Fetch Table Data (Limit 100)
- **URL**: `GET /api/data/:table`
- **Description**: Retrieves all columns and up to 100 rows of data from the specified table.
- **Example Response**:
  ```json
  {
    "table": "departments",
    "count": 2,
    "data": [
      { "id": 1, "name": "Human Resources", "code": "HR" },
      { "id": 2, "name": "Finance", "code": "FIN" }
    ]
  }
  ```

### 5. Employee Login (JWT Authentication)
- **URL**: `POST /api/login`
- **Description**: Authenticates an employee using their Employee Number (User ID) and Password. If a custom password has not been set yet, it falls back to validating against their PAN number (default password, case-insensitive). Returns a signed JWT token valid for 24 hours.
- **Request Body (JSON)**:
  ```json
  {
    "employee_number": 141,
    "password": "abjpv5442p"
  }
  ```
- **Example Response (Success)**:
  ```json
  {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "must_change_password": true,
    "employee": {
      "id": 1,
      "employee_number": 141,
      "name": "Rajesh Kumar Verma",
      "status": "Active",
      "group": "Executive",
      "subgroup": "CGM/ED",
      "department": "Project & Diversification",
      "position": "Executive Director (P&D)",
      "gender": "Male",
      "email": "RKV@MOIL.NIC.IN",
      "mobile": "9766697904",
      "pan_number": "ABJPV5442P",
      "has_custom_password": false,
      "must_change_password": true
    }
  }
  ```
- **Example Response (Failure)**:
  ```json
  {
    "error": "Invalid Employee Number or Password"
  }
  ```

### 6. Change Password
- **URL**: `POST /api/change-password`
- **Description**: Changes the password for the currently authenticated employee. Requires a valid JWT bearer token in the `Authorization` header.
- **Headers**:
  - `Authorization: Bearer <your_jwt_token>`
  - `Content-Type: application/json`
- **Request Body (JSON)**:
  ```json
  {
    "old_password": "abjpv5442p",
    "new_password": "mySecurePassword123"
  }
  ```
- **Example Response (Success)**:
  ```json
  {
    "message": "Password changed successfully"
  }
  ```
- **Example Response (Failure - Invalid Current Password)**:
  ```json
  {
    "error": "Invalid current password"
  }
  ```



