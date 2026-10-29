MediTech Project Architecture
Project Structure
meditech/
│
├── lib/
│   ├── core/
│   │   ├── theme/
│   │   ├── constants/
│   │   ├── errors/
│   │   └── utils/
│   │
│   ├── data/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── services/
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── search/
│   │   ├── map/
│   │   ├── pharmacy_detail/
│   │   ├── reservation/
│   │   ├── ai_scanner/
│   │   ├── pharmacy_portal/
│   │   └── admin/
│   │
│   └── main.dart
│
└── supabase/
├── migrations/
└── functions/
└── ai-parse-medicine/
lib/
main.dart
Application entry point.

Possible file:

main.dart
core/
Shared files used across the application.

core/theme/
Application styling and themes.

Possible files:

app_theme.dart
app_colors.dart
app_text_styles.dart
app_dimensions.dart
core/constants/
Application-wide constants.

Possible files:

api_constants.dart
route_constants.dart
app_strings.dart
supabase_constants.dart
core/errors/
Error handling classes.

Possible files:

exceptions.dart
failures.dart
error_handler.dart
core/utils/
Helper and utility functions.

Possible files:

validators.dart
date_formatter.dart
location_helper.dart
image_helper.dart
permissions_helper.dart
data/
Manages communication with Supabase and application data.

data/models/
Data models.

Possible files:

user_model.dart
pharmacy_model.dart
medicine_model.dart
reservation_model.dart
inventory_model.dart
data/repositories/
Repository layer.

Possible files:

auth_repository.dart
pharmacy_repository.dart
medicine_repository.dart
reservation_repository.dart
inventory_repository.dart
data/services/
External services and API communication.

Possible files:

supabase_service.dart
auth_service.dart
storage_service.dart
location_service.dart
ai_service.dart
features/
Each feature contains its own screens, providers, and widgets.

features/auth/
Authentication module.

auth/
├── screens/
│   ├── login_screen.dart
│   └── register_screen.dart
├── widgets/
│   └── auth_form.dart
├── providers/
│   └── auth_provider.dart
└── services/
└── auth_service.dart
features/search/
Medicine and pharmacy search.

search/
├── screens/
│   └── search_screen.dart
├── widgets/
│   ├── search_bar.dart
│   └── pharmacy_card.dart
└── providers/
└── search_provider.dart
features/map/
Location and navigation.

map/
├── screens/
│   └── map_screen.dart
├── widgets/
│   └── pharmacy_marker.dart
└── providers/
└── map_provider.dart
features/pharmacy_detail/
Displays pharmacy information.

pharmacy_detail/
├── screens/
│   └── pharmacy_detail_screen.dart
├── widgets/
│   ├── pharmacy_info_card.dart
│   └── inventory_list.dart
└── providers/
└── pharmacy_detail_provider.dart
features/reservation/
Medicine reservation functionality.

reservation/
├── screens/
│   └── reservation_screen.dart
├── widgets/
│   └── reservation_form.dart
└── providers/
└── reservation_provider.dart
features/ai_scanner/
Medicine image scanning and AI parsing.

ai_scanner/
├── screens/
│   └── scanner_screen.dart
├── widgets/
│   └── camera_preview.dart
├── providers/
│   └── scanner_provider.dart
└── services/
└── ocr_service.dart
features/pharmacy_portal/
Pharmacy management dashboard.

pharmacy_portal/
├── screens/
│   ├── dashboard_screen.dart
│   ├── inventory_screen.dart
│   └── reservation_requests_screen.dart
├── widgets/
│   └── inventory_table.dart
└── providers/
└── pharmacy_provider.dart
features/admin/
System administration.

admin/
├── screens/
│   ├── admin_dashboard.dart
│   ├── user_management_screen.dart
│   └── pharmacy_approval_screen.dart
├── providers/
│   └── admin_provider.dart
└── services/
└── admin_service.dart
Supabase
Backend resources.

supabase/migrations/
Database SQL files.

Possible files:

001_create_users.sql
002_create_pharmacies.sql
003_create_medicines.sql
004_create_inventory.sql
005_create_reservations.sql
supabase/functions/
Edge Functions.

ai-parse-medicine/
AI-powered medicine parsing.

Possible files:

ai-parse-medicine/
├── index.ts
├── deno.json
├── types.ts
└── README.md
Responsibilities:

Receive medicine image
Extract text using OCR
Send text to AI model
Return medicine information
Store scan history
Recommended Additional Folders
lib/
├── widgets/
│   ├── custom_button.dart
│   ├── custom_textfield.dart
│   └── loading_indicator.dart
│
├── routes/
│   └── app_router.dart
│
└── providers/
└── app_provider.dart
Technology Stack
Frontend:
- Flutter
- Dart

Backend:
- Supabase

Database:
- PostgreSQL

Authentication:
- Supabase Auth

Storage:
- Supabase Storage

Maps:
- Google Maps API

AI:
- OCR + AI Medicine Parser

State Management:
- Provider / Riverpod

Architecture:
- Feature-Based Architecture