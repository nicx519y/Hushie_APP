/// Toast Messages Management Class
/// Centralized management of all Toast message texts in the application
class ToastMessages {
  // Private constructor to prevent instantiation
  ToastMessages._();

  // ========== HTTP Status Code Error Messages ==========
  static const Map<int, String> httpStatusMessages = {
    400: 'Bad request parameters',
    401: 'Authentication failed, please log in again',
    403: 'Access denied, insufficient permissions',
    404: 'Requested resource not found',
    408: 'Request timeout, please try again later',
    429: 'Too many requests, please try again later',
    500: 'Internal server error',
    502: 'Gateway error, service temporarily unavailable',
    503: 'Service temporarily unavailable',
    504: 'Gateway timeout, please try again later',
  };

  // ========== Network Exception Error Messages ==========
  static const Map<String, String> networkExceptionMessages = {
    'TimeoutException': 'Network request timeout, please check your connection',
    'SocketException': 'Network connection failed, please check network settings',
    'HandshakeException': 'SSL connection failed, please check network security settings',
    'Connection': 'Network connection error, please try again later',
    'FormatException': 'Data format error',
    'HttpException': 'HTTP request exception',
  };

  // ========== General Network Error Messages ==========
  static const String networkRequestFailed = 'Network request failed, please try again later';
  static const String httpRetryExhausted = 'HTTP request retry attempts exhausted';

  // ========== Login Related Messages ==========
  static const String loginSuccess = 'Log in successfully!';
  static const String loginFailed = 'Log in failed.';

  // ========== Account Related Messages ==========
  static const String accountDeleteSuccess = 'You have deleted the account.';
  static const String accountDeleteFailed = 'Account delete failed.';

  // ========== Subscription Related Messages ==========
  static const String subscriptionAlreadySubscribed = 'You have subscribed to this plan.';
  static const String subscriptionInitializing = 'Initializing purchase...';
  static const String subscriptionProcessing = 'Processing purchase request...';
  static const String subscriptionCanceled = 'Purchase canceled';

  // ========== Logout Related Messages ==========
  static String logoutFailed(String error) => 'Logout failed: $error';

  // ========== Get HTTP Status Code Message ==========
  static String getHttpStatusMessage(int statusCode) {
    return httpStatusMessages[statusCode] ?? 'Network request failed (Status code: $statusCode)';
  }

  // ========== Get Network Exception Message ==========
  static String getNetworkExceptionMessage(dynamic exception) {
    final exceptionString = exception.toString();
    
    // Check for known exception types
    for (final entry in networkExceptionMessages.entries) {
      if (exceptionString.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default message
    return networkRequestFailed;
  }
}