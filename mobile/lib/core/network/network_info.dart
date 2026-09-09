import 'dart:io';

/// Answers "is this device online?" before a request is attempted.
///
/// Implemented with a DNS lookup rather than `connectivity_plus`: a connected
/// Wi-Fi network with no route to the internet still reports "connected" to
/// that package, whereas a lookup fails the way a real request would.
abstract interface class NetworkInfo {
  /// Whether the device can currently reach the internet.
  Future<bool> get isConnected;
}

/// Default [NetworkInfo] backed by a DNS lookup.
class NetworkInfoImpl implements NetworkInfo {
  const NetworkInfoImpl({
    this.lookupHost = 'one.one.one.one',
    this.timeout = const Duration(seconds: 5),
  });

  /// Host resolved to prove connectivity. Cloudflare's resolver by default.
  final String lookupHost;

  /// How long to wait before treating the lookup as a failure.
  final Duration timeout;

  @override
  Future<bool> get isConnected async {
    try {
      final addresses = await InternetAddress.lookup(lookupHost).timeout(timeout);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } on Exception {
      return false;
    }
  }
}
