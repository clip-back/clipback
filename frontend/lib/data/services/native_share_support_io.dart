import 'dart:io';

bool get nativeSharingAvailable => Platform.isIOS || Platform.isAndroid;
