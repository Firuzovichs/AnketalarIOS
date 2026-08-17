// MARK: - Kalidlar
enum LKey: String {
    // Onboarding
    case onb1Title, onb1Sub, onb2Title, onb2Sub, onb3Title, onb3Sub
    case next, start

    // Login
    case welcome, loginSub, emailPH, passwordPH
    case forgotPwd, loginBtn, noAccount, signUp

    // Register
    case regTitle, regSub, sendOTP, otpInfo
    case codeTitle, codeSub, noCode, resend, confirm
    case setPwdTitle, setPwdSub, confirmPwdPH
    case agreeTerms, termsLink, regBtn

    // ForgotPassword
    case resetTitle, resetSub, otpTimeLeft, errOtpExpired
    case newPwdTitle, newPwdSub, newPwdPH
    case save, resetDone, resetDoneSub, goLogin

    // Parol kuchi
    case weak, medium, good, strong

    // Tema
    case themePink, themeBlue

    // Kirgan ekran
    case loginOK, soonMsg, logout

    // Profile setup
    case psTitle
    case psStep1, psStep2, psStep3, psStep4, psStep5, psStep6, psStep7
    case psFirstName, psLastName, psPatronymic
    case psBirthDate, psGender, psMale, psFemale
    case psHeight, psWeight, psOptional
    case psSelectInterests, psSelectGoals
    case psAddPhoto, psMinPhoto
    case psContinue, psFinish, psSkip, psLoading, psUploading
    case cancel, done
    case psLocTitle, psLocSub, psDetectLoc, psLocDetected
    case psFaceTitle, psFaceSub, psTakePhoto, psRetake

    // Dashboard
    case dbHello, dbUser, dbMyStory
    case dbForYou, dbNearby, dbNew
    case dbNews, dbStories, dbBanners

    // Story viewer
    case storyViewers, storyNoViewers, storyViewedSuffix
    case storyDelete, storyPremiumViewers
    case storyAgo, storyMinutes, storyHours, storyDays
    case storyReplyPlaceholder, storyReplySent

    // User Profile Page
    case upLike, upLiked, upInterests, upGoals, upOnline, upCm, upKg, upYears
    case upGoToChat

    // VIP Paywall
    case vipReqTitle, vipReqSub, vipReqBtn

    // Map tab
    case mapTitle, mapFilterTitle, mapAge, mapCountry, mapRegion, mapDistrict
    case mapApply, mapClear, mapAny, mapNoUsers, mapLocating, mapLocationDenied
    case mapFrom, mapTo, mapRadiusLabel

    // Like tab (swipe)
    case likeTitle, likeEmptyTitle, likeEmptySub, likeRefresh
    case likeLimitTitle, likeMatchTitle, likeMatchSub, likeContinue
    case likeStampLike, likeStampNope
    // "Habar bilan like" — 3-tugma qatoridagi o'ng tugma bosilganda chiqadigan
    // matn yozish oynasi.
    case likeMsgSheetTitle, likeMsgPlaceholder, likeMsgSend, likeMsgCancel

    // Chat tab
    case chatTitle, chatEmptyTitle, chatEmptySub
    case chatSupportName, chatSupportSub, chatNoMessages
    case chatYouPrefix, chatMsgPhoto, chatMsgVideo, chatMsgVideoNote, chatMsgVoice, chatMsgDeleted, chatMsgLocation
    case chatMsgStoryReply
    case chatToday, chatYesterday, chatExpiresToday, chatExpiresInDays
    case chatLockedRowLabel, chatLockedAlertTitle, chatLockedAlertBody, chatLockedDetail
    case chatTyping, chatReply, chatInputPlaceholder
    case chatAttachPhoto, chatAttachVideo, chatAttachLocation
    case chatVoiceRecording, chatVoiceMicDenied, chatVoiceOpenSettings, chatVoicePremiumRequired
    case chatVideoPremiumRequired, chatLocationDenied
    case chatVideoRecording, chatCameraMicDenied
    case chatLikesReceivedTitle, chatLikesEmpty

    // Chat: bloklash / shikoyat
    case chatMenuBlock, chatBlockConfirmTitle, chatBlockConfirmBody
    case chatBlockReasonTitle, chatBlockReasonSpam, chatBlockReasonHarassment
    case chatBlockReasonFakeProfile, chatBlockReasonInappropriate, chatBlockReasonOther
    case chatBlockDone, chatBlockedTitle, chatBlockedBody, chatBlockedRowLabel
    case chatUnblockButton, chatUnblockConfirmTitle, chatUnblockConfirmBody, chatUnblockDone

    // Chat: bildirishnoma o'chirish/yoqish, qidiruv, "Chatni tozalash"
    case chatMenuMute, chatMenuUnmute
    case chatMenuSearch, chatSearchPlaceholder, chatSearchNoResults
    case chatMenuClearChat, chatClearChatConfirmTitle, chatClearChatConfirmBody, chatClearChatDone

    // Chat: xabarni tahrirlash/nusxalash
    case chatCopy, chatEdit, chatEditingLabel, chatEditedTag

    // Chat: o'chib ketadigan rasm va skrinshot ogohlantirishi
    case chatDisappearingButton, chatDisappearingPickerTitle
    case chatDisappearing3s, chatDisappearing5s, chatDisappearing10s
    case chatMsgDisappearingPhoto, chatDisappearingTapToView, chatDisappearingExpired
    case chatSystemScreenshotSelf, chatSystemScreenshotOther

    // Profile (own profile screen)
    case profTitle, profEdit, profEditTitle, profSaved
    case profPhotos, profPhotosEmpty, profAddPhoto, profPhotoLimitReached
    case profDeletePhotoTitle, profDeletePhotoMsg
    case profStories, profStoriesEmpty
    case profSettings, profLanguage, profTheme
    case profLogoutConfirmTitle, profLogoutConfirmMsg
    case profEmail, profPhone, profMemberSince
    case profBioTitle, profBioEmpty, profBioPlaceholder
    case profInterestsTitle, profGoalsTitle
    case profInterestsEmpty, profGoalsEmpty
    case profGenderUnset, profLocationUnset

    // Profile: yangi dizayn — to'ldirilganlik/tasdiqlanganlik kartalari, asosiy ma'lumotlar
    case profBasicInfoTitle, profGenderLabel, profAddressLabel, profAgeLabel
    case profShowPhoneNumber
    case profCompletionTitle, profCompletionSubtitle
    case profVerifiedTitle, profVerifiedSubtitle
    case profNotVerifiedTitle, profNotVerifiedSubtitle
    case profBioEmptyTitle, profBioEmptySubtitle, profAddBioButton

    // Profile: tahrirlashda Manzil (davlat/viloyat/tuman) tanlash
    case profAddressTitle, profSelectCountry, profSelectRegion, profSelectDistrict

    // Profile: settings — info sahifalari (Biz haqimizda/Shartlar/Maxfiylik) + hisobni o'chirish
    case settingsAbout, settingsTerms, settingsPrivacy
    case settingsDeleteAccount, settingsDeleteAccountPending
    case settingsDeleteAccountConfirmTitle, settingsDeleteAccountConfirmMsg, settingsDeleteAccountConfirmBtn
    case staticPageLoadError

    // Xatolar
    case errIdentifier, errFillAll, errBadResp
    case errParse, errOccurred, errOTP
    case errMinPwd, errPwdMatch, errTerms
    case errFillRequired

    // Xatolar: backend 'code' maydoniga qarab tilga mos chiqariladigan matnlar
    // (LocalizationManager.errorText(code:detail:limit:) orqali ishlatiladi —
    // backend 'detail' matni faqat noma'lum/yangi kod uchun zaxira sifatida qoladi).
    case errAlreadyRegistered, errOtpInvalid, errUserNotFound, errWrongPassword
    case errAccountBlocked, errPhotoNotFound, errNotRegistered
    case errCantBlockSelf, errCantLikeSelf, errDailyLikeLimit, errSuperLikeLimit
    case errAlreadyLiked, errLikeNotFound, errToUserIdRequired, errCantSkipSelf
    case errChatBlocked, errEmptyMessage, errDailyStoryLimit, errStoryNotFound
    case errCantReplyOwnStory, errStoryReplyForbidden, errProfileIncomplete
    case errRadiusPremiumOnly, errLatLngRequired, errLatLngInvalid
    case errNoCandidates, errNotFound
    case errUnknownAppleProduct

    // Subscription (obuna) sahifasi
    case subNavTitle, subHeaderSubtitle, subCurrentPlanLabel
    case subSubscribeButton, subCurrentPlanButton, subRestoreButton
    case subRestoring, subPurchasing, subTermsFooter, subComingSoon
    case subPurchaseFailedTitle, subRestoreNoneTitle
    case subFeatureLikesPerDay, subFeatureSuperLikes, subFeatureWhoLiked, subFeatureRadius
    case subFeatureVoice, subFeatureVideo, subFeatureBoost, subFeatureStoryAnalytics
    case subFeatureStoriesPerDay, subFeatureAdFree, subFeatureChatDuration
    case subPriceMonthlySuffix, subUnlimited
}
