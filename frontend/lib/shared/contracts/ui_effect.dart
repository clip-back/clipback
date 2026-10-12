import '../../social_auth.dart';

sealed class UiEffect {
  const UiEffect();
}

class MessageEffect extends UiEffect {
  const MessageEffect(this.message, {this.retryLabel, this.retry});

  final String message;
  final String? retryLabel;
  final void Function()? retry;
}

class CloseTransientRoutesEffect extends UiEffect {
  const CloseTransientRoutesEffect();
}

class ConfirmAccountSwitchEffect extends UiEffect {
  const ConfirmAccountSwitchEffect(this.epoch, this.provider);

  final int epoch;
  final SocialLoginProvider provider;
}

class DetailDeletedEffect extends UiEffect {
  const DetailDeletedEffect();
}

class SavedContentEffect extends UiEffect {
  const SavedContentEffect(this.contentId);

  final int contentId;
}
