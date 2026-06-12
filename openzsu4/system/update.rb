require 'sketchup'

module ZSU
  module Update
    # Đang phát triển tính năng Update
    GITHUB_URL = "https://github.com/chill4share/openzsu4"

    def self.check_version
      msg = "Dự án OpenZSU hiện đã được chuyển đổi sang mã nguồn mở vĩnh viễn!\n\n" \
            "Hệ thống tự động cập nhật trực tuyến qua Server cũ đã được tắt để đảm bảo an toàn dữ liệu.\n" \
            "Bạn có muốn truy cập kho Github của cộng đồng để kiểm tra và đóng góp các bản cập nhật mới không?"
      
      result = UI.messagebox(msg, MB_YESNO)
      if result == IDYES
        UI.openURL(GITHUB_URL)
      end
      true
    end

    def self.fetch_latest_version
      ZSU::VERSION
    end

    def self.update_available?
      false
    end

    def self.download_and_install
      false
    end
  end
end