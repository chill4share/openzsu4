require 'sketchup'

module ZSU
  module Update
    GITHUB_URL = "https://github.com/chill4share/openzsu4/releases"

    def self.check_version
      msg = "Bạn có muốn mở trang tải các phiên bản (Releases) của OpenZSU trên GitHub để kiểm tra và cập nhật không?"
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