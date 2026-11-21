# Checklist 3: An ninh mạng & lưu trữ dữ liệu

**Văn bản áp dụng:**
- Luật An ninh mạng 2025: Luật số 116/2025/QH15, thông qua 10/12/2025, hiệu lực 01/07/2026 ([thuvienphapluat](https://thuvienphapluat.vn/van-ban/cong-nghe-thong-tin/Luat-An-ninh-mang-2025-so-116-2025-QH15-666020.aspx)). Luật này kế thừa và hợp nhất Luật An ninh mạng 2018 và Luật An toàn thông tin mạng 2015. Hai luật cũ (Luật An ninh mạng 24/2018/QH14, Luật An toàn thông tin mạng 86/2015/QH13) hết hiệu lực từ 01/07/2026 theo Điều 44 khoản 2 ([trích theo điều](https://hethongphapluat.com/luat-an-ninh-mang-2025/dieu-44), [Apolat](https://apolatlegal.com/vi/laws/luat-an-ninh-mang-2025-so-116-2025-qh15/)).
- **Nghị định 333/2026/NĐ-CP**: hướng dẫn Luật An ninh mạng 2025, ban hành và có hiệu lực 19/08/2026 ([Công báo, DOCX/PDF](https://congbao.chinhphu.vn/van-ban/nghi-dinh-so-333-2026-nd-cp-470335.htm), [PDF](https://congbaocdn.chinhphu.vn/180507251028987904/2026/9/4/470335-1787890927_v1_1788486330_signed.pdf)). Điều 16, 18 đã đối chiếu trước đây; đợt 21/11/2026 đọc trực tiếp Điều 19-22, 30, 31 và sửa các mô tả bên dưới theo đúng điều kiện/chủ thể.
- Nghị định 53/2022/NĐ-CP: Điều 31 NĐ 333 chỉ nói **hồ sơ đề nghị thẩm định an ninh mạng, hồ sơ đề nghị đánh giá điều kiện an ninh mạng đã được tiếp nhận hợp lệ trước 19/08/2026 mà chưa có kết quả** tiếp tục giải quyết theo NĐ 53. Điều 30 chỉ ghi ngày hiệu lực, không chứa câu bãi bỏ NĐ 53. Căn cứ kết luận toàn bộ NĐ 53 hết hiệu lực: **CHƯA XÁC MINH**; cần tra tiếp văn bản/lược đồ hiệu lực, không suy ra từ một bản tin tóm tắt.
- Nghị định 330/2026/NĐ-CP: xử phạt lĩnh vực an ninh mạng và bảo vệ dữ liệu cá nhân (xem checklist 08).

## A. Lưu trữ dữ liệu tại Việt Nam
- [ ] Xác định doanh nghiệp có thuộc diện phải lưu dữ liệu tại Việt Nam và có chi nhánh/văn phòng đại diện không (Điều 25 khoản 3 Luật 116/2025): lưu tại Việt Nam trong thời gian theo quy định của Chính phủ; doanh nghiệp nước ngoài thuộc diện này phải đặt chi nhánh hoặc văn phòng đại diện. Diện này là doanh nghiệp cung cấp dịch vụ trên mạng viễn thông/Internet/dịch vụ gia tăng, có thu thập, khai thác, phân tích, xử lý dữ liệu người dùng tại Việt Nam.
- [ ] Các loại dữ liệu tại khoản 1 Điều 19 NĐ 333/2026 gồm thông tin cá nhân người dùng dịch vụ tại Việt Nam và các dữ liệu được liệt kê do người dùng tạo ra (tài khoản, thời gian sử dụng, thông tin thẻ tín dụng, email, IP đăng nhập/đăng xuất gần nhất, số điện thoại gắn tài khoản/dữ liệu). Khoản 2 quy định doanh nghiệp trong nước lưu dữ liệu thuộc khoản 1 tại Việt Nam. Trường hợp không thu đủ các loại dữ liệu, xem khoản 4, không yêu cầu site tự thu thêm tất cả chỉ để lấp danh sách.
- [ ] **Doanh nghiệp nước ngoài: phải kiểm tra đủ điều kiện và chủ thể**, theo điểm a khoản 3 và khoản 6 Điều 19. Ngoài lĩnh vực dịch vụ được liệt kê, còn có việc dịch vụ bị dùng vi phạm an ninh mạng, yêu cầu phối hợp/ngăn chặn/điều tra/xử lý bằng văn bản sau 3 lần và tối đa 6 tháng nhưng doanh nghiệp không khắc phục, không chấp hành/không đầy đủ hoặc cản trở/vô hiệu hóa biện pháp; quyết định yêu cầu do Bộ trưởng Bộ Công an ban hành. Không rút gọn thành “mọi dịch vụ nước ngoài phải đặt dữ liệu tại VN”. Khoản 6 điểm c cho 12 tháng từ quyết định để hoàn thành; khoản 3 điểm b có xử lý bất khả kháng. Điều 20 khoản 1 tính thời gian lưu từ khi nhận yêu cầu đến khi kết thúc yêu cầu, tối thiểu 24 tháng.

## B. Nhật ký hệ thống (log)
- [ ] Nhật ký hệ thống thuộc điểm b khoản 2 Điều 25 Luật 116/2025 được lưu tối thiểu 12 tháng, theo Điều 20 khoản 3 NĐ 333/2026 (đã đối chiếu). Không biến yêu cầu của nhóm chủ thể/dữ liệu đó thành thời hạn chung cho mọi loại log của mọi website.
- [ ] Nếu là doanh nghiệp viễn thông, Internet cấp địa chỉ IP: Điều 21 khoản 2 và Điều 22 yêu cầu ghi nhận, lưu trữ, quản lý thông tin định danh, nhật ký cấp IP đầy đủ/liên tục tối thiểu 12 tháng; đồng bộ thời gian và có dữ liệu ánh xạ khi dùng NAT (khoản 2, 3 Điều 22, đã đối chiếu). Không áp nghĩa vụ nhà cung cấp Internet này cho một website thông thường chỉ dùng hosting.
- [ ] Cung cấp được log cho cơ quan chuyên trách khi có yêu cầu hợp lệ.

## C. Biện pháp bảo vệ & sự cố
- [ ] Có biện pháp bảo mật tương xứng với dữ liệu đang xử lý: mã hóa dữ liệu nhạy cảm, kiểm soát truy cập, sao lưu, giám sát xâm nhập.
- [ ] Có quy trình ứng phó và báo cáo sự cố an ninh mạng (Điều 40 khoản 1 điểm c và Điều 41 khoản 3 Luật 116/2025).

## D. Nghĩa vụ của doanh nghiệp cung cấp dịch vụ trên không gian mạng (Điều 41, Điều 25 khoản 2 Luật 116/2025)
- [ ] Có quy trình xử lý yêu cầu xác minh, điều tra, phối hợp xử lý vi phạm từ cơ quan chuyên trách.

## E. Nội dung vi phạm trên nền tảng (site có nội dung người dùng đăng: bình luận, bài viết, livestream)
- [ ] Có cơ chế kiểm duyệt nội dung thuộc các hành vi bị cấm (Điều 7 Luật 116/2025).
- [ ] Gỡ nội dung vi phạm trong **24 giờ** kể từ khi lực lượng chuyên trách Bộ Công an yêu cầu, trường hợp khẩn cấp chậm nhất **06 giờ** (Điều 25 khoản 2 điểm b Luật 116/2025). Doanh nghiệp hosting, trung tâm dữ liệu cũng phải gỡ trong 24 giờ (Điều 18 khoản 2 NĐ 333/2026).

> Ngoài phạm vi checklist này: Điều 43 khoản 2 Luật 116/2025 chỉ sửa câu chữ ở Luật Bảo vệ quyền lợi người tiêu dùng ("an toàn, an ninh thông tin" thành "an ninh mạng"), không thêm nghĩa vụ mới ([trích theo điều](https://hethongphapluat.com/luat-an-ninh-mang-2025/dieu-43)).
