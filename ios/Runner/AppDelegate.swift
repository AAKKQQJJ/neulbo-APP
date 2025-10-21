import Flutter
import UIKit
// TODO: Pod 설치 후 주석 해제
// import KakaoSDKCommon
// import KakaoSDKAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // TODO: Pod 설치 후 주석 해제
    // Kakao SDK 초기화
    // let kakaoAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") ?? ""
    // KakaoSDK.initSDK(appKey: kakaoAppKey as! String)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // TODO: Pod 설치 후 주석 해제
    // Kakao 로그인 URL 처리
    // if (AuthApi.isKakaoTalkLoginUrl(url)) {
    //   return AuthController.handleOpenUrl(url: url)
    // }
    
    return super.application(app, open: url, options: options)
  }
}
