import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    setWindowMinSize(const Size(200, 150));
    setWindowMaxSize(const Size(400, 300));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iFlow',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme(
          primary: Color(0xFF00A67E), // ChatGPT primary color
          secondary: Color(0xFF36CFC9), // ChatGPT secondary color
          surface: Color(0xFF121212), // Dark surface
          background: Colors.black, // Black background
          error: Color(0xFFCF6679), // Dark theme error color
          onPrimary: Color(0xFFFFFFFF), // White text on primary
          onSecondary: Color(0xFF000000), // Black text on secondary
          onSurface: Color(0xFFFFFFFF), // White text on surface
          onBackground: Color(0xFFFFFFFF), // White text on background
          onError: Color(0xFF000000), // Black text on error
          brightness: Brightness.dark, // Dark theme
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'iFlow'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      final userMessage = _controller.text;
      try {
        setState(() {
          _messages.add({'type': 'user', 'message': userMessage});
        });

        final response = await http.post(
          Uri.parse('http://127.0.0.1:8501/process'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': userMessage}),
        );

        setState(() {
          _messages.add({'type': 'bot', 'message': response.body});
          _controller.clear();
        });
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  void _toggleRecording() async {
    if (!_isRecording) {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/recording_$timestamp.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
        });
      }
    } else {
      final path = await _audioRecorder.stop();
      print('Recording saved to: $path');

      setState(() {
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['type'] == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Text(
                      message['message'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter your message',
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.onSurface,
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  color: Theme.of(context).colorScheme.onSurface,
                  onPressed: _toggleRecording,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
