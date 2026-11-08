Create a comprehensive, production-ready Flutter screen for 'lib/screens/manage_teaching_locations_screen.dart' in the FYBTT application.

Context & Parameter Consistency:
This screen allows educators to manage all their physical and hybrid teaching centres. It integrates with:
- `../models/teacher_location_model.dart`
- `../services/teacher_location_service.dart`
- `location_picker_screen.dart` (for adding new locations)
- Uses Firebase Auth (`FirebaseAuth.instance.currentUser?.uid`)

Requirements:
1. Class Name: `ManageTeachingLocationsScreen` (StatefulWidget)
   - Accepts parameter: `final String currentTeacherId;`
2. Visual Theme & Styling (Executive Grade):
   - Palette: Deep Navy (`#0F172A`), Brand Blue (`#1E4C7A`), Accent Blue (`#2563EB`), Accent Amber (`#F59E0B`), Clean Slate Background (`#F8FAFC`).
   - Premium AppBar with back button, screen title ("Teaching Locations"), and an action button to open "Recently Deleted / Recovery" modal.
   - TabBar or Filter Toggle at the top: "Active Locations" and "Inactive / Archive".
   - Floating Action Button (FAB): Rounded pill button "Add New Centre" with an icon that navigates to `LocationPickerScreen` or opens the add flow.

3. List & Card Components:
   - Real-time StreamBuilder consuming `TeacherLocationService().getTeacherLocationsStream(widget.currentTeacherId, includeInactive: true)`.
   - Empty State: Clean vector illustration / icon, informative title ("No Teaching Centres Added Yet"), subtitle, and a prominent "Add Your First Location" button.
   - Location Card Elements:
     * Header row: Location Type badge (e.g. Tuition Centre, Institute, Home Tuition), Verification Status chip (Verified, Confirmed, Pending), and a 3-dot PopupMenuButton.
     * Location Name in bold navy typography (`#0F172A`).
     * Full Address with a small red pin icon.
     * Teaching Mode chip (Offline, Hybrid, Online).
     * Subject & Class chips wrap summary.
     * Bottom status toggle: Switch widget or toggle button for Active / Inactive status (`TeacherLocationService().toggleLocationActiveStatus(...)`).
     * Action Buttons row:
       - "Batches & Schedule" (navigates or triggers schedule overview).
       - "Move / Edit Pin" (opens map to adjust coordinates).

4. Three-Dot PopupMenu Actions:
   - Edit Details: Navigates to edit screen.
   - Manage Batches: Quick shortcut to batch list.
   - Manage Schedule: Quick shortcut to weekly timetable.
   - Duplicate Location: Clones the location configuration with a new ID after confirmation.
   - Delete Centre: Shows alert dialog warning about active batches; calls `TeacherLocationService().softDeleteTeachingLocation(...)` with an Undo SnackBar.

5. Recently Deleted (Recovery) Sheet:
   - Modal bottom sheet displaying locations where `isDeleted == true`.
   - Each item shows deleted date, with "Restore" (calls `restoreTeachingLocation`) and "Delete Permanently" (calls `permanentlyDeleteTeachingLocation` with strict warning).

6. Code Structure:
   - Start immediately with `import 'package:flutter/material.dart';` on line 1.
   - Output the ENTIRE file in ONE SINGLE code block starting with ```dart and ending with ```.
   - Do NOT output any conversational, introductory, or concluding text outside the code block.
