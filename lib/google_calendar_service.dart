import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class TodoEvent {
  final String title;
  final String eventId;
  final DateTime startTime;
  final DateTime endTime;

  TodoEvent({
    required this.title,
    required this.eventId,
    required this.startTime,
    required this.endTime,
  });

  bool? get completed => null;
}

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
      'email',
      'profile',
    ],
    clientId: kIsWeb
        ? '645023011886-mufnsatm5huj07lnihe47qt5nh178iqv.apps.googleusercontent.com'
        : null,
    hostedDomain: null,
    forceCodeForRefreshToken: true,
  );

  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      debugPrint('Error checking sign in status: $e');
      return false;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('Attempting to sign in...');
      if (kIsWeb) {
        try {
          final account = await _googleSignIn.signIn();
          if (account != null) {
            debugPrint('Sign in successful: ${account.email}');
            debugPrint('Got authentication token');
            return account;
          }
          debugPrint('Sign in failed - account is null');
          return null;
        } catch (e) {
          debugPrint('Web sign in error: $e');
          return null;
        }
      } else {
        return await _googleSignIn.signIn();
      }
    } catch (e) {
      debugPrint('Error during sign in: $e');
      return null;
    }
  }

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    try {
      if (!await isSignedIn()) {
        final account = await signIn();
        if (account == null) return null;
      }

      final currentUser = _googleSignIn.currentUser;
      if (currentUser == null) return null;

      final auth = await currentUser.authentication;
      final headers = {
        'Authorization': 'Bearer ${auth.accessToken}',
        'Accept': 'application/json',
      };

      return calendar.CalendarApi(GoogleAuthClient(headers));
    } catch (e) {
      debugPrint('Error getting Calendar API: $e');
      return null;
    }
  }

  Future<List<TodoEvent>> getEvents() async {
    try {
      final api = await _getCalendarApi();
      if (api == null) return [];

      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final events = await api.events.list(
        'primary',
        timeMin: now.toUtc(),
        timeMax: endOfDay.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items?.map((event) => TodoEvent(
        title: event.summary ?? 'Untitled Event',
        eventId: event.id ?? '',
        startTime: event.start?.dateTime ?? DateTime.now(),
        endTime: event.end?.dateTime ?? DateTime.now().add(const Duration(hours: 1)),
      )).toList() ?? [];
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<TodoEvent?> addEvent(String title, DateTime startTime, DateTime endTime) async {
    if (title.isEmpty) return null;

    try {
      final api = await _getCalendarApi();
      if (api == null) return null;

      final event = calendar.Event()
        ..summary = title
        ..description = 'Task created from Todo App'
        ..start = calendar.EventDateTime(
          dateTime: startTime,
          timeZone: 'Asia/Jakarta',
        )
        ..end = calendar.EventDateTime(
          dateTime: endTime,
          timeZone: 'Asia/Jakarta',
        );

      final result = await api.events.insert(event, 'primary');
      debugPrint('Event created with ID: ${result.id}');
      return TodoEvent(
        title: title,
        eventId: result.id ?? '',
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      debugPrint('Error adding event: $e');
      return null;
    }
  }

  Future<bool> updateEvent(String eventId, String newTitle, DateTime newStartTime, DateTime newEndTime) async {
    try {
      final api = await _getCalendarApi();
      if (api == null) return false;

      final existingEvent = await api.events.get('primary', eventId);
      existingEvent.summary = newTitle;
      existingEvent.start = calendar.EventDateTime(
        dateTime: newStartTime,
        timeZone: 'Asia/Jakarta',
      );
      existingEvent.end = calendar.EventDateTime(
        dateTime: newEndTime,
        timeZone: 'Asia/Jakarta',
      );

      await api.events.update(existingEvent, 'primary', eventId);
      debugPrint('Event updated successfully: $eventId');
      return true;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    if (eventId.isEmpty) {
      debugPrint('Event ID cannot be empty');
      return false;
    }

    try {
      final api = await _getCalendarApi();
      if (api == null) {
        debugPrint('Cannot access Google Calendar API');
        return false;
      }

      try {
        await api.events.get('primary', eventId);
      } catch (e) {
        debugPrint('Event not found: $e');
        return true;
      }

      await api.events.delete('primary', eventId);
      debugPrint('Event successfully deleted: $eventId');
      return true;
    } catch (e) {
      if (e.toString().contains('404')) {
        debugPrint('Event no longer exists: $eventId');
        return true;
      }
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('Signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}
