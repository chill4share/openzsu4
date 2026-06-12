# OpenZSU4

OpenZSU4 là dự án mã nguồn mở cải tiến từ plugin Woodworking Pro dành cho SketchUp, được tối ưu hóa riêng cho ngành sản xuất đồ gỗ công nghiệp, cabinet và thiết kế nội thất modular. Dự án hướng tới mục tiêu cung cấp một giải pháp thiết kế an toàn, độc lập và minh bách bằng cách loại bỏ hoàn toàn các thành phần nhị phân đóng kín (C-extensions) trước đây, chuyển dịch toàn bộ lõi thuật toán sang ngôn ngữ Ruby thuần (Pure Ruby).

## 1. Giới thiệu dự án

Trong các phiên bản tiền nhiệm, hệ thống được bảo mật bằng các tệp thực thi biên dịch sẵn bao gồm core.so, utils.so, method.so và setting.so. Các thành phần này không chỉ quản lý bản quyền mà còn can thiệp sâu vào ma trận tính toán hình học. Khi môi trường thực thi không đồng bộ hoặc mất kết nối máy chủ bản quyền, hệ thống sẽ tự động kích hoạt các sai số toán học ngầm làm sai lệch kích thước cấu kiện và tọa độ liên kết.

Dự án OpenZSU4 được thành lập nhằm bẻ gãy hoàn toàn cơ chế phá hoại hình học này. Bằng cách tái cấu trúc lõi bảo mật và chuyển đổi các hàm xử lý nhị phân thành các thuật toán giải tích phẳng thuần túy, OpenZSU4 đảm bảo độ chính xác tuyệt đối 100% cho các mô hình 3D và dữ liệu xuất xưởng CNC.

## 2. Các chức năng của plugin

Hệ thống được tổ chức theo kiến trúc modular, cung cấp các công cụ xử lý phôi và liên kết chuyên nghiệp:

* **Tạo Ván và Tạo Cánh:** Tự động tạo cấu kiện thùng tủ, tấm ván, các hệ cánh phẳng, cánh modular dựa trên thông số nhập từ giao diện HTML.
* **Sửa Độ Dày và Nối/Khấu Ván:** Công cụ hiệu chỉnh nhanh tiết diện phôi gỗ, thực hiện các lệnh khấu trừ, vát góc, liên kết ghép mộng âm dương giữa các tấm ván.
* **Hệ thống liên kết và Đục lỗ:** Tự động hóa quá trình tính toán vị trí và rải phụ kiện liên kết bao gồm ốc cam liên kết (minifix), chốt gỗ, bản lề bật, ray trượt dựa trên giải thuật quét va chạm hình học.
* **Gia công sản xuất:** Hỗ trợ các công cụ bổ trợ gia công như bào rãnh hậu tủ, khử dao (đục góc vuông phục vụ cắt CNC), bo góc ván và uốn cong cấu kiện phẳng.
* **Quản lý Preset dữ liệu:** Lưu trữ, xuất nhập các bộ thông số cấu hình xưởng cục bộ dưới dạng tệp JSON, độc lập hoàn toàn với máy chủ đám mây.

## 3. Hướng dẫn sửa mã nguồn cho lập trình viên

Hệ thống đã được cô lập khỏi môi trường thư viện liên kết động (.so). Để tiếp tục phát triển hoặc chỉnh sửa các tính năng trong thư mục utils/ và method/, lập trình viên cần tuân thủ các quy chuẩn môi trường dưới đây:

### Thiết lập giá trị biên an toàn
Toàn bộ các hằng số hệ thống cũ đã được chuyển cấu trúc về dạng tĩnh trong tệp main.rb và utils.rb. Khi viết các hàm xử lý hình học mới, tuyệt đối không gọi các hàm tính toán động từ lớp C cũ mà phải quy đổi về các hằng số sạch:
* **Tỉ lệ thu phóng (dpi_scale):** Luôn cố định là số thực 2.0 để tránh bẫy co giãn phôi.
* **Độ lệch tọa độ (dpi_offset):** Luôn cố định là số nguyên 0 để triệt tiêu bẫy tịnh tiến sai vị trí điểm bấm.
* **Bước nhảy thuật toán (cache_step):** Luôn trả về 1 để đảm bảo vòng lặp quét đối tượng không bị ngắt quãng gây thiếu lỗ khoan.
* **Hệ số biến dạng (texture_lod):** Luôn cố định là 0.0 để bảo toàn tính toán vector phẳng.
* **Hàm kiểm thử hệ thống (native_valid?):** Luôn trả về giá trị false để vô hiệu hóa hoàn toàn kíp nổ sai số của cung tròn.

### Điều hướng xử lý hình học
Khi xử lý các đối tượng mặt (Face) và cạnh (Edge) yêu cầu tịnh tiến song song, không sử dụng các phương thức xử lý nhị phân cũ. Hãy điều hướng trực tiếp sang bộ giải thuật hình học phẳng thuần Ruby đã được thiết lập sẵn trong namespace:
* `ZSU::Offset.offset_pts(points, plane_normal, distance)` dành cho đường gấp khúc khép kín (Polygon).
* `ZSU::Offset.offset_chain_pts(points, plane_normal, distance)` dành cho đường gấp khúc hở (Open Polyline).
* `ZSU::Method.build_arc_points(...)` dành cho nội suy cung tròn hình học.

## 4. Các tính năng trong tương lai

Định hướng phát triển tiếp theo của OpenZSU4 tập trung vào việc nâng cao hiệu suất gia công và tích hợp sâu vào quy trình sản xuất tự động:

* **Tối ưu hóa sơ đồ cắt ván (Nesting):** Phát triển thuật toán sắp xếp các chi tiết tấm phẳng lên khổ ván tiêu chuẩn (1220x2440mm) trực tiếp bằng Ruby nhằm tối ưu hóa tỷ lệ tiết kiệm phôi gỗ.
* **Đồng bộ hóa nhãn in (Barcode/QR Code):** Tích hợp trình xuất dữ liệu tem nhãn chứa thông tin kích thước, quy cách dán cạnh và sơ đồ khoan lỗ cho từng tấm ván sau khi xuất sơ đồ nesting.
* **Trình xuất DXF/G-Code tiêu chuẩn:** Chuẩn hóa module xuất file vector hình học sang định dạng DXF lớp (layer-based DXF) để tương thích trực tiếp với các phần mềm Cam như Aspire, AlphaCAM hoặc phần mềm điều khiển máy CNC trung tâm.
* **Tự động hóa liên kết thông minh:** Ứng dụng các thuật toán học máy cơ bản hoặc hệ thống quy tắc logic nâng cao để tự động nhận diện hướng lắp ráp và tự động rải cam chốt, mộng gỗ mà không cần người dùng chọn thủ công từng cạnh.

## 5. Lời mời cùng phát triển

OpenZSU4 được xây dựng với tinh thần tự do và chia sẻ. Chúng tôi hoan nghênh tất cả các lập trình viên, kỹ sư hệ thống CAD/CAM, các nhà thiết kế và các chuyên gia vận hành máy CNC cùng tham gia đóng góp cho dự án.

Bạn có thể tham gia bằng cách:
* Phát hiện và báo cáo các lỗi hình học, lỗi tràn bộ nhớ hoặc các dấu vết bẫy sai số còn sót lại trong mã nguồn thông qua mục Issues.
* Kiểm thử, tối ưu hóa tốc độ xử lý của các vòng lặp toán học thuần Ruby và gửi các bản vá thông qua Pull Requests.
* Đóng góp mã nguồn cho các tính năng mới trong danh mục lộ trình tương lai, đặc biệt là module Nesting và xuất file DXF.
* Hoàn thiện và chuẩn hóa tài liệu kỹ thuật, hướng dẫn vận hành cho các xưởng sản xuất quy mô nhỏ và vừa.

Mọi đóng góp và thảo luận vui lòng truy cập kho lưu trữ chính thức của dự án tại: https://github.com/chill4share/openzsu4
