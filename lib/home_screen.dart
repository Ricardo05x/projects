import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:projects/auth_service.dart';
import 'package:projects/google_calendar_service.dart';
import 'package:projects/signin_screen.dart';

class TodoEvent {
  final String title;
  final String eventId;
  final DateTime startTime;
  final DateTime endTime;
  bool completed;
  String description;

  TodoEvent({
    required this.title,
    required this.eventId,
    required this.startTime,
    required this.endTime,
    this.completed = false,
    this.description = '',
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TodoEvent> todoList = [];
  final TextEditingController _controller = TextEditingController();
  int updateIndex = -1;
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGoogleSignIn();
    });
  }

  Future<void> _checkGoogleSignIn() async {
    try {
      if (!await _calendarService.isSignedIn()) {
        if (mounted) {
          _showSignInPrompt();
        }
      }
    } catch (e) {
      debugPrint('Error checking Google Sign In: $e');
    }
  }

  void _showSignInPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in required for Google Calendar sync'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Sign In',
          onPressed: _signInWithGoogle,
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final account = await _calendarService.signIn();
      if (mounted) {
        if (account != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in to Google'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _showSignInPrompt();
        }
      }
    } catch (e) {
      debugPrint('Error during Google Sign In: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign in with Google'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.brown[600]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isStartTime ? _selectedStartDate : _selectedEndDate,
        ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.brown[600]!,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          if (isStartTime) {
            _selectedStartDate = newDateTime;
            if (_selectedEndDate.isBefore(_selectedStartDate)) {
              _selectedEndDate = _selectedStartDate.add(const Duration(hours: 1));
            }
          } else {
            if (newDateTime.isAfter(_selectedStartDate)) {
              _selectedEndDate = newDateTime;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('End time must be after start time'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        });
      }
    }
  }

  void _showDescriptionDialog(TodoEvent todo) {
    final TextEditingController descController = TextEditingController(text: todo.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(todo.title),
        content: TextField(
          controller: descController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add description...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.brown[400])),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                todo.description = descController.text;
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.brown[700]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void addList(String task) async {
    if (task.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task cannot be empty")),
      );
      return;
    }

    try {
      final todoEvent = await _calendarService.addEvent(
        task,
        _selectedStartDate,
        _selectedEndDate,
      );
      if (todoEvent != null) {
        setState(() {
          todoList.add(TodoEvent(
            title: todoEvent.title,
            eventId: todoEvent.eventId,
            startTime: todoEvent.startTime,
            endTime: todoEvent.endTime,
            completed: false,
            description: '',
          ));
          _controller.clear();
          _selectedStartDate = DateTime.now();
          _selectedEndDate = DateTime.now().add(const Duration(hours: 1));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task added to Google Calendar"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding task to calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error connecting to Google Calendar'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void updateListItem(String task, int index) async {
    if (task.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task cannot be empty")),
      );
      return;
    }

    try {
      final success = await _calendarService.updateEvent(
        todoList[index].eventId,
        task,
        _selectedStartDate,
        _selectedEndDate,
      );

      if (success) {
        setState(() {
          todoList[index] = TodoEvent(
            title: task,
            eventId: todoList[index].eventId,
            startTime: _selectedStartDate,
            endTime: _selectedEndDate,
            completed: todoList[index].completed,
            description: todoList[index].description,
          );
          updateIndex = -1;
          _controller.clear();
          _selectedStartDate = DateTime.now();
          _selectedEndDate = DateTime.now().add(const Duration(hours: 1));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task updated in Google Calendar"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating task in calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error connecting to Google Calendar'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void deleteItem(int index) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.brown[400])),
          ),
          TextButton(
            onPressed: () async {
              try {
                final success = await _calendarService.deleteEvent(
                  todoList[index].eventId,
                );

                if (success) {
                  setState(() {
                    todoList.removeAt(index);
                  });
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Task deleted from Google Calendar"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Error deleting task: $e');
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error connecting to Google Calendar'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.brown[700]),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
            child: Column(
              children: [
                Container(
                padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                      color: Colors.brown.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Tasks',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.brown[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.brown[400]),
                      onPressed: () async {
                        await AuthService().signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInScreen()),
                          );
                        }
                      },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: todoList.length,
              itemBuilder: (context, index) {
                final todo = todoList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                            color: Colors.brown.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: todo.completed,
                          onChanged: (bool? value) {
                            setState(() {
                              todo.completed = value ?? false;
                            });
                          },
                          activeColor: Colors.brown[600],
                        ),
                        if (todo.completed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.brown[800],
                        decoration: todo.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('MMM d, h:mm a').format(todo.startTime)} - ${DateFormat('h:mm a').format(todo.endTime)}',
                          style: TextStyle(
                            color: Colors.brown[400],
                            fontSize: 12,
                            decoration: todo.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (todo.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            todo.description,
                            style: TextStyle(
                              color: Colors.brown[600],
                              fontSize: 12,
                              decoration: todo.completed ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.description_outlined, color: Colors.brown[400]),
                          onPressed: () => _showDescriptionDialog(todo),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.brown[400]),
                          onPressed: () {
                            setState(() {
                              _controller.text = todo.title;
                              updateIndex = index;
                              _selectedStartDate = todo.startTime;
                              _selectedEndDate = todo.endTime;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.brown[400]),
                          onPressed: () => deleteItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Add a new task...',
                        hintStyle: TextStyle(color: Colors.brown[300]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.brown[200]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.brown[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.brown[400]!),
                        ),
                        filled: true,
                        fillColor: Colors.brown[50],
                        suffixIcon: IconButton(
                          icon: Icon(
                            updateIndex == -1 ? Icons.add : Icons.edit,
                            color: Colors.brown[700],
                          ),
                          onPressed: () {
                            if (updateIndex == -1) {
                              addList(_controller.text);
                            } else {
                              updateListItem(_controller.text, updateIndex);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDateTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.brown[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.brown[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.brown[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Start: ${DateFormat('MMM d, h:mm a').format(_selectedStartDate)}',
                                      style: TextStyle(color: Colors.brown[800]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDateTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.brown[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.brown[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.brown[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'End: ${DateFormat('MMM d, h:mm a').format(_selectedEndDate)}',
                                      style: TextStyle(color: Colors.brown[800]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}