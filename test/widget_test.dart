import 'package:flutter_test/flutter_test.dart';
import 'package:app_dich_thuat/main.dart';

void main() {
  testWidgets('Kiểm tra giao diện GoTrans load thành công', (WidgetTester tester) async {
    // Chạy app với Firebase chưa khởi tạo để test giao diện lỗi dự phòng
    await tester.pumpWidget(const MyApp(isFirebaseInitialized: false));

    // Kiểm tra xem dòng thông báo cấu hình có xuất hiện không
    expect(find.textContaining('Firebase chưa được cấu hình đúng'), findsOneWidget);
  });
}
