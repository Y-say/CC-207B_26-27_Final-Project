import 'package:flutter/material.dart';

import 'screens/shared/design_gallery_screen.dart';
import 'widgets/theme/app_theme.dart';

// Opens the design kit gallery (no Supabase needed)
void main() => runApp(MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const DesignGalleryScreen(),
    ));