# GoTrans - Thông dịch AI Real-time

Dự án này tích hợp core xử lý ngôn ngữ (STT, Dịch, TTS) từ Python Flask Backend vào ứng dụng Flutter.

## Cấu trúc tích hợp

1.  **Backend (Python/Flask)**: Sử dụng Socket.IO để nhận luồng âm thanh, xử lý qua OpenAI/Gemini và trả về văn bản dịch kèm âm thanh TTS.
2.  **Frontend (Flutter)**:
    *   `SocketService`: Quản lý kết nối và giao tiếp thời gian thực.
    *   `OneWayTranslationScreen`: Giao diện người dùng thực hiện ghi âm và hiển thị kết quả.

## Hướng dẫn cài đặt Backend

1.  Lưu đoạn mã Python bạn đã cung cấp vào một thư mục (ví dụ: `backend/main.py`).
2.  Cài đặt các thư viện cần thiết:
    ```bash
    pip install flask flask-socketio imageio-ffmpeg soundfile python-dotenv openai google-generativeai
    ```
3.  Tạo file `.env` và cấu hình `AI_PROVIDER` cùng API Key tương ứng.
4.  Chạy backend:
    ```bash
    python main.py
    ```

## Hướng dẫn cấu hình Flutter

1.  **Kết nối**: Trong `lib/screens/one_way_translation_screen.dart`, hãy cập nhật URL của backend:
    *   Dùng `http://10.0.2.2:5000` nếu chạy trên Android Emulator.
    *   Dùng IP máy tính của bạn (ví dụ `http://192.168.1.x:5000`) nếu chạy trên thiết bị thật.
2.  **Quyền truy cập**: Đã thêm quyền `RECORD_AUDIO` và `INTERNET` trong `AndroidManifest.xml`. Đối với iOS, hãy thêm `NSMicrophoneUsageDescription` vào `Info.plist`.

## Cách sử dụng
- Nhấn **"Bắt đầu nói"** để ghi âm.
- Nhấn **"Dừng nói"** để gửi đoạn âm thanh sang backend.
- Chờ kết quả trả về: văn bản sẽ tự động hiển thị và âm thanh TTS sẽ được phát lại.
