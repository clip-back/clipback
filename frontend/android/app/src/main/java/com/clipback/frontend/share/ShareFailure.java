package com.clipback.frontend.share;

import java.io.IOException;

/**
 * A share failure and its 공유 저장 시트 alert (#122). The message stays the existing text that the
 * recovery screen keeps showing; only the sheet uses the kind's title and body.
 */
final class ShareFailure extends IOException {
    enum Kind {
        /** 받기 거절: the body is ShareInput's specific reason. */
        REJECTED("공유할 수 없어요", null),
        STORAGE_FULL("보관하지 못했어요", "보관 중인 공유가 가득 찼어요. 허투루 앱에서 저장 대기 공유를 저장하거나 삭제한 뒤 다시 공유해 주세요."),
        STORAGE_FAILED("보관하지 못했어요", "공유 내용을 보관하지 못했어요. 다시 공유해 주세요."),
        LOGIN("로그인이 필요해요", "초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요."),
        UNCONFIRMED("저장하지 못했어요", "저장 결과를 확인하지 못했습니다. 다시 시도해도 중복 저장되지 않습니다."),
        PAUSED("저장하지 못했어요", "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요."),
        CHECK_INPUT("저장하지 못했어요", "지금 링크 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요. 계속 실패하면 Instagram·YouTube 링크나 PNG·JPEG·WebP 이미지인지 확인해 주세요."),
        NOT_SENT("저장하지 못했어요", "지금 저장하지 못했어요. 잠시 후 다시 시도해 주세요."),
        IMAGE_QUOTA("지금은 저장할 수 없어요", "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요."),
        ACCOUNT_CHANGED("저장 환경이 바뀌었어요", "저장 계정이 변경되었습니다. 이 창을 닫고 저장할 계정을 확인해 주세요."),
        OTHER_ENVIRONMENT("저장 환경이 바뀌었어요", "이 초안은 다른 서버 환경에서 전송되었습니다. 같은 서버 환경의 허투루 앱에서 다시 저장해 주세요."),
        SAVED_FOR_PREVIOUS_ACCOUNT("저장 환경이 바뀌었어요", "전송한 계정의 저장 결과는 보관했습니다. 계정이 변경되어 이 창을 닫아 주세요."),
        DELETED("다시 저장할 수 없어요", "이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요."),
        MISMATCH("다시 저장할 수 없어요", "이 초안의 저장 정보가 일치하지 않습니다. 다시 공유해 주세요."),
        TOO_LARGE("다시 저장할 수 없어요", "이미지는 10MiB 이하만 저장할 수 있습니다."),
        MISSING("공유 항목이 없어요", "보관 기간이 지났거나 삭제된 초안입니다.");
        final String title, body;
        Kind(String title, String body) { this.title = title; this.body = body; }
        /** 다시 시도 가능: [다시 시도] sends the same request again. */
        boolean retries() { return this == UNCONFIRMED || this == PAUSED || this == CHECK_INPUT || this == NOT_SENT; }
        /** [허투루 열기] for login required and a full device storage. */
        boolean opensApp() { return this == LOGIN || this == STORAGE_FULL; }
        /** 되돌릴 수 없음: [닫기] drops the share instead of keeping it. */
        boolean discards() { return this == DELETED || this == MISMATCH || this == TOO_LARGE; }
    }
    final Kind kind;
    ShareFailure(Kind kind, String message) { super(message); this.kind = kind; }
    /** The sheet's body; a rejection shows its specific reason. */
    String body() { return kind.body != null ? kind.body : getMessage(); }
}
