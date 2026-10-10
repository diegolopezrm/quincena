import 'dart:io';

/// Whether a connection to the host that answers the questions opens: the
/// network is back, not only the wifi's icon.
Future<bool> networkReachable() async {
  try {
    final Socket socket = await Socket.connect(
      'firebasevertexai.googleapis.com',
      443,
      timeout: const Duration(seconds: 4),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}
