# Status Screen & Upload Logic Fixes

## 1. Silent Upload Failure (The "Spinner Disappearing" Bug)
**File:** `lib/screens/media_preview_edit_screen.dart`
* **The Logic Flaw:** The code was uploading images to storage perfectly, but when it tried to insert a new row into the `statuses` table, it passed `type: 'image'`. The `statuses` table has a strict constraint: `CHECK (type IN ('text', 'photo', 'video'))`. Supabase threw a `PostgrestException` because `'image'` is invalid.
* **The Silent Fail:** The `try-catch` block around the upload logic was swallowing this exception. Because the screen had already popped (`mounted == false`), the `ScaffoldMessenger` never showed the error. It simply called `setUploadingStatus(false)`, hiding the spinner without ever creating the status.
* **The Fix:** Changed the logic to pass `'photo'` instead of `'image'`. Added a `showDialog` that forces errors to be visible.

## 2. Text Status Failure
**File:** `lib/screens/text_status_screen.dart`
* **The Logic Flaw:** Similar to the media upload, if `postTextStatus` failed, it failed silently because there was no error handling wrapped around the database call.
* **The Fix:** Wrapped the database insert in a `try-catch` block and added an `AlertDialog` to ensure any backend rejections are immediately visible to the user.

## 3. "My Status" Card UI Redesign
**File:** `lib/screens/status_stories_screen.dart`
* **The Logic Flaw:** In `_buildMyStatusGridCard`, if a user deleted all their statuses (`hasStatus == false`), the UI simply returned a blank `Container(color: AppColors.lightGrey)`. The user had no button to tap to upload a new status. Furthermore, if they *did* have a status, tapping the card only opened the viewer; there was no button to add *another* status.
* **The Fix:** 
  - Restructured the `Stack`. The Avatar profile picture is now **always rendered** in the top left, with a permanent `+` icon badge.
  - Separated the `GestureDetector` zones: The Avatar has its own `onTap` that triggers `_showCreateStatusOptions(context)` (opens gallery). The background thumbnail has its own `onTap` that triggers `OwnStatusViewerScreen` (views statuses).

## 4. "Add Status" Button Inside Edit Screen
**File:** `lib/screens/own_status_viewer_screen.dart`
* **The Logic Flaw:** Inside the `OwnStatusViewerScreen`, the "Add status" `ListTile` at the bottom had its `onTap` hardcoded to `Navigator.pop(context);`.
* **The Fix:** Imported `wechat_assets_picker` and replaced the pop action with a direct call to `_showCreateStatusOptions(context)`, seamlessly opening the gallery.

## 5. UI Not Auto-Refreshing (The Supabase Realtime Issue)
**Action Required:**
* **The Logic Flaw:** `StatusService.getMyStatuses()` uses Supabase's `.stream()` to listen for changes. However, Supabase does not broadcast changes over websockets unless the table is explicitly added to the realtime publication. Thus, the UI only fetched data on app startup, completely ignoring subsequent deletes or inserts until the app was restarted.
* **The Fix:** The developer must execute `alter publication supabase_realtime add table statuses;` in the Supabase SQL editor to enable the websocket broadcasts for this table.
