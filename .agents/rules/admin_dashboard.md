# Admin Dashboard Architectural Guideline

- **Independent Web Platform**: The Admin Dashboard is strictly hosted as a separate web application located in the `admin/` directory (`C:\Users\pikeb\Desktop\abuad\admin`), serving its own website.
- **Never In Mobile App**: Under no circumstances should an Admin Dashboard page, screen, or route be implemented inside the Flutter mobile application (`lib/`). All admin moderation and management tasks are handled exclusively via the standalone web portal and admin backend endpoints.
