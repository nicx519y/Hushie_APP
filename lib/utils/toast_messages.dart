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
    408: 'An error has occurred. Please refresh the page.',
    429: 'An error has occurred. Please refresh the page.',
    500: 'An error has occurred. Please refresh the page.',
    502: 'An error has occurred. Please refresh the page.',
    503: 'An error has occurred. Please refresh the page.',
    504: 'An error has occurred. Please refresh the page.',
  };

  // ========== Network Exception Error Messages ==========
  static const Map<String, String> networkExceptionMessages = {
    'TimeoutException': 'An error has occurred. Please refresh the page.',
    'SocketException': 'An error has occurred. Please refresh the page.',
    'HandshakeException': 'An error has occurred. Please refresh the page.',
    'Connection': 'An error has occurred. Please refresh the page.',
    'FormatException': 'An error has occurred. Please refresh the page.',
    'HttpException': 'An error has occurred. Please refresh the page.',
  };

  // ========== General Network Error Messages ==========
  static const String networkRequestFailed = 'An error has occurred. Please refresh the page.';
  static const String httpRetryExhausted = 'An error has occurred. Please refresh the page.';

  // ========== General App Network & Auth Messages ==========
  static const String networkUnavailable = 'Network unavailable. Please try again later.';
  static const String networkCheckFailed = 'Network check failed. Please try again later.';
  static const String authExpired = 'Authentication expired, please log in again.';

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
  static const String subscriptionSuccess = 'Purchase successful! Subscription activated';
  static const String subscriptionPending = 'Purchase pending, please check subscription status later';
  static const String subscriptionFailed = 'Purchase failed, please try again';
  static const String subscriptionException = 'An exception occurred during purchase, please try again';
  static const String subscribingPleaseDonRepeat = 'Subscribing. Please don\'t repeat.';
  
  // ========== Google Play Billing Error Messages ==========
  static const String billingServiceUnavailable = 'Google Play Billing service unavailable, please check device settings';
  static const String productConfigError = 'Product configuration error, unable to purchase';
  static const String billingUnavailable = 'Google Play Billing service unavailable';
  static const String itemUnavailable = 'Product temporarily unavailable';
  static const String developerError = 'App configuration error, please contact developer';
  static const String userCanceled = 'User canceled the purchase';
  static const String serviceDisconnected = 'Network connection failed, please check network and try again';
  static const String serviceTimeout = 'Request timeout, please try again';

  // ========== App Close Messages ==========
  static const String appWillClose = 'Press back again to quit the app';

  // ========== Logout Related Messages ==========
  static String logoutFailed(String error) => 'Logout failed: $error';
  static const String logoutSuccess = 'You have been logged out.';

  // ========== Get HTTP Status Code Message ==========
  static String getHttpStatusMessage(int statusCode) {
    // return httpStatusMessages[statusCode] ?? 'Network request failed (Status code: $statusCode)';
    return 'An error has occurred. Please refresh the page.';
  }

  // ========== Get Google Play Billing Error Message ==========
  static String getBillingErrorMessage(dynamic exception) {
    final exceptionString = exception.toString();
    
    if (exceptionString.contains('BILLING_UNAVAILABLE')) {
      return billingUnavailable;
    } else if (exceptionString.contains('ITEM_UNAVAILABLE')) {
      return itemUnavailable;
    } else if (exceptionString.contains('DEVELOPER_ERROR')) {
      return developerError;
    } else if (exceptionString.contains('USER_CANCELED')) {
      return userCanceled;
    } else if (exceptionString.contains('SERVICE_DISCONNECTED')) {
      return serviceDisconnected;
    } else if (exceptionString.contains('SERVICE_TIMEOUT')) {
      return serviceTimeout;
    }
    
    // 默认返回开发者错误信息
    return developerError;
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