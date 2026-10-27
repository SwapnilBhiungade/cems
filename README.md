# Campus Event Management System

A Flask-based web application for managing campus events, student registrations, testimonials, gallery images, and contact messages. The system supports two roles:

- Students: browse events, register, download entry passes, manage their profile, submit testimonials, and view message replies.
- Administrators: create and manage events, moderate testimonials, manage gallery uploads, handle student records, and process contact messages.

## Features

- Public event browsing with search and category filtering
- Student registration and login
- Event registration with capacity checks
- Entry pass PDF generation for registered students
- Student profile page with registrations, testimonials, and message history
- Testimonials submission and admin moderation
- Public event gallery
- Contact form with admin inbox and reply tracking
- Admin dashboard with event, student, registration, and message management
- CSV export for messages, students, and event registrations
- Image uploads for gallery management

## Tech Stack

- Python 3
- Flask
- MySQL
- Flask-WTF / CSRF protection
- bcrypt for password hashing
- ReportLab for PDF entry passes
- Pillow for image handling

## Project Structure

```text
.
|-- app.py
|-- config.py
|-- init_db.py
|-- requirements.txt
|-- static/
|   |-- css/
|   |-- js/
|   `-- images/
|-- templates/
|   |-- admin/
|   |-- user/
|   `-- *.html
`-- uploads/
```

## Main Pages

- `/` - Home page with upcoming events and testimonials
- `/events` - Event listing, search, and filters
- `/gallery` - Public image gallery
- `/about` - System overview and stats
- `/contact` - Contact form
- `/register` - Student registration
- `/login` - User login
- `/profile` - Student profile
- `/my-messages` - Student message history and replies
- `/testimonials` - Approved testimonials
- `/admin/dashboard` - Admin dashboard

## Setup

### 1. Clone and enter the project

```bash
cd CEMS-SHARE
```

### 2. Create a virtual environment

```bash
python -m venv .venv
.venv\Scripts\activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure environment variables

Create a `.env` file in the project root with your database credentials and secret key:

```env
SECRET_KEY=your-secret-key
DB_HOST=gateway01.ap-southeast-1.prod.aws.tidbcloud.com
DB_PORT=4000
DB_USER=your-username.root
DB_PASSWORD=your-password
DB_NAME=sys
DB_CA=./certs/isrgrootx1.pem
CLOUDINARY_URL=cloudinary://your_api_key:your_api_secret@your_cloud_name
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
CLOUDINARY_FOLDER=cems-share/gallery
```

If a variable is missing, the app falls back to the defaults defined in `config.py`.
For gallery uploads in production, configure either `CLOUDINARY_URL` or the separate Cloudinary variables above so uploads, deletes, and previews use cloud storage instead of the local filesystem.

### 5. Initialize the database

Run the database bootstrap script after MySQL is available:

```bash
python init_db.py
```

This creates the tables in the database named by `DB_NAME`, then inserts a default admin account:

- Email: `admin@campus.edu`
- Password: `admin123`

### 6. Start the app

```bash
python app.py
```

The server runs on:

- `http://127.0.0.1:5000`
- `http://0.0.0.0:5000` when accessed from the network

## Production Deployment

For online hosting, run the app through a WSGI server instead of `python app.py`:

```bash
gunicorn wsgi:app
```

For containerized and cloud deployments, refer to the [Implementation Guide](docs/IMPLEMENTATION_GUIDE.md) for Docker, Kubernetes (Amazon EKS), and Jenkins CI/CD instructions.

Recommended production environment variables:

```env
PORT=5000
```

If you are deploying behind HTTPS, keep the TiDB CA certificate available at the path in `DB_CA`.

## Database Tables

- `users` - Authentication and roles
- `students` - Student profile details
- `events` - Event records
- `registrations` - Student event registrations
- `gallery` - Event images
- `testimonials` - Student testimonials and moderation status
- `contacts` - Contact form submissions
- `replies` - Admin replies to contact submissions

## Notes

- File uploads are limited to 16 MB at the Flask level.
- Gallery uploads are validated for type and size in the admin interface.
- PDF entry passes require the `reportlab` package to be installed.
- The app uses session-based authentication and role-based access control.

## Troubleshooting

- If login fails, verify the MySQL credentials in `.env`.
- If table creation fails, make sure the database exists and the configured user has permission to create tables.
- If entry pass generation is unavailable, confirm `reportlab` installed correctly.
- If the database connection fails in production, confirm the TiDB Cloud host, port, username, password, and CA certificate path are all correct.
