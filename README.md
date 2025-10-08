# Drive T - Learn. Drive. Thrive.

A friendly Flutter mobile app connecting driving learners with verified instructors in Ontario.

## 🎯 Features

- **Role Selection**: Choose between Learner or Instructor roles
- **Find Instructors**: Browse and filter nearby driving instructors
- **Book Lessons**: Schedule driving lessons with available instructors
- **Progress Tracking**: Track your driving skills and achievements
- **Lesson Management**: View upcoming and completed lessons
- **Profile Management**: Manage your account and preferences
- **Dark Mode**: Full dark mode support
- **Modern UI**: Material 3 design with warm, friendly aesthetics

## 🎨 Design System

- **Primary Color**: Deep Blue (#1E3A8A)
- **Accent Color**: Bright Yellow (#FACC15)
- **Typography**: Poppins font family
- **Style**: Friendly, minimal, approachable (Duolingo × Uber × Canva)
- **Icons**: Material Design icons
- **Dark Mode**: Fully supported

## 🛠 Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Backend**: Supabase (Auth + Database + Storage)
- **Maps**: Google Maps Flutter plugin
- **UI**: Material 3 with custom theming

## 📱 Screens

1. **Splash Screen**: Animated Drive T logo
2. **Onboarding**: Role selection and verification
3. **Home Dashboard**: Personalized greeting and quick actions
4. **Find Instructor**: Map view with filtering options
5. **Booking**: Date/time selection and lesson details
6. **My Lessons**: Upcoming and completed lessons
7. **Progress Tracker**: Skills checklist and achievements
8. **Profile**: User details and settings

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- iOS Simulator / Android Emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd drive_t_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**
   - Create a new Supabase project
   - Update `lib/main.dart` with your Supabase URL and anon key
   - Set up the database schema (see Database Schema section)

4. **Run the app**
   ```bash
   flutter run
   ```

## 🗄 Database Schema

### Tables

#### profiles
```sql
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE,
  email TEXT,
  phone TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT CHECK (role IN ('learner', 'instructor')),
  profile_image_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (id)
);
```

#### instructors
```sql
CREATE TABLE instructors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  bio TEXT,
  years_of_experience INTEGER,
  hourly_rate DECIMAL(10,2),
  rating DECIMAL(3,2) DEFAULT 0.0,
  total_lessons INTEGER DEFAULT 0,
  car_types TEXT[],
  transmission_types TEXT[],
  license_number TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  address TEXT,
  available_days TEXT[],
  start_time TIME,
  end_time TIME,
  languages TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### lessons
```sql
CREATE TABLE lessons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  learner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  instructor_id UUID REFERENCES instructors(id) ON DELETE CASCADE,
  scheduled_date DATE,
  start_time TIME,
  end_time TIME,
  duration DECIMAL(3,1),
  cost DECIMAL(10,2),
  status TEXT CHECK (status IN ('scheduled', 'completed', 'cancelled', 'in_progress')),
  notes TEXT,
  location TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS)

Enable RLS on all tables and create policies for data access control.

## 🎨 Customization

### Colors
Update `lib/constants/app_colors.dart` to customize the color scheme.

### Fonts
Add custom fonts to `assets/fonts/` and update `pubspec.yaml`.

### Icons
Replace icons in `assets/icons/` and update references in the code.

## 📦 Dependencies

Key dependencies used in this project:

- `flutter_riverpod`: State management
- `go_router`: Navigation
- `supabase_flutter`: Backend services
- `google_maps_flutter`: Maps integration
- `flutter_staggered_animations`: Animations
- `cached_network_image`: Image caching
- `image_picker`: Image selection
- `intl`: Internationalization

## 🚧 Development Status

- ✅ Project structure setup
- ✅ Design system implementation
- ✅ All main screens implemented
- ✅ Navigation and routing
- ✅ Dark mode support
- ✅ Supabase integration stubs
- ⏳ Backend integration (requires Supabase setup)
- ⏳ Maps integration (requires API keys)
- ⏳ Testing implementation

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📞 Support

For support, email support@drivet.app or create an issue in the repository.

---

**Drive T** - Learn. Drive. Thrive. 🚗✨
