require 'sketchup'

module ZSU
  module Update
    GITHUB_URL = "https://github.com/chill4share/openzsu4/releases"

    def self.check_version(manual = true)
      url = "https://raw.githubusercontent.com/chill4share/openzsu4/refs/heads/main/openzsu4.rb?t=#{Time.now.to_i}"
      
      request = Sketchup::Http::Request.new(url)
      request.headers = { "User-Agent" => "SketchUp-OpenZSU-Updater" }
      
      request.start do |response|
        begin
          # Trạng thái STATUS_SUCCESS trong SketchUp API là 1
          if response.status == 1 
            if response.code == 200
              body = response.body
              if body =~ /VERSION\s*=\s*["']([^"']+)["']/
                latest_ver_str = $1
                
                current_ver = Gem::Version.new(ZSU::VERSION)
                latest_ver = Gem::Version.new(latest_ver_str)

                if latest_ver > current_ver
                  UI.start_timer(0, false) do
                    msg = "Đã có phiên bản mới: v#{latest_ver_str} (Hiện tại: v#{ZSU::VERSION}).\n\nBạn có muốn tải về và cập nhật tự động ngay không?"
                    if UI.messagebox(msg, MB_YESNO) == IDYES
                      download_and_install(latest_ver_str)
                    end
                  end
                elsif manual
                  UI.start_timer(0, false) do
                    UI.messagebox("Bạn đang sử dụng phiên bản mới nhất (v#{ZSU::VERSION}).")
                  end
                end
              else
                raise "Không tìm thấy thông tin định nghĩa VERSION trên GitHub."
              end
            else
              # Chỉ gọi response.code khi status == 1
              raise "Lỗi HTTP từ máy chủ: #{response.code}"
            end
          else
            # Nếu status != 1 (Có thể là 0 hoặc 2), không gọi .code để tránh lỗi hệ thống
            raise "Không thể kết nối tới GitHub (Mã trạng thái Request: #{response.status})"
          end
          
        rescue => e
          if manual
            # Đưa thông báo lỗi về Main Thread an toàn
            UI.start_timer(0, false) do
              UI.messagebox("Lỗi kiểm tra phiên bản: #{e.message}")
            end
          end
        end
      end
      true
    end

    def self.download_and_install(version_str)
      UI.status_text = "Đang tải bản cập nhật OpenZSU v#{version_str}..."
      
      filename = "OpenZsu_#{version_str}.rbz"
      url = "https://github.com/chill4share/openzsu4/releases/download/v#{version_str}/#{filename}"
      
      request = Sketchup::Http::Request.new(url)
      request.headers = { "User-Agent" => "SketchUp-OpenZSU-Updater" }
      
      request.start do |response|
        begin
          if response.status == 1 && response.code == 200
            temp_path = File.join(Sketchup.temp_dir, "openzsu_update_#{Time.now.to_i}.rbz")
            File.open(temp_path, "wb") do |f|
              f.write(response.body)
            end
            
            # Thực hiện cài đặt trực tiếp trong Main Thread để tăng độ ổn định
            UI.start_timer(0, false) do
              begin
                success = Sketchup.install_from_archive(temp_path)
                if success
                  UI.status_text = "Cập nhật OpenZSU hoàn tất!"
                  UI.messagebox("Cập nhật thành công phiên bản OpenZSU v#{version_str}! Plugin đã sẵn sàng sử dụng.")
                else
                  UI.messagebox("Cài đặt bản cập nhật thất bại. Vui lòng thử lại hoặc cài đặt thủ công.")
                end
              ensure
                File.delete(temp_path) if temp_path && File.exist?(temp_path)
              end
            end
          else
            # Tránh gọi response.code bừa bãi khi không thành công kết nối
            err_msg = response.status == 1 ? "HTTP #{response.code}" : "Lỗi kết nối (Status: #{response.status})"
            UI.messagebox("Lỗi tải bản cập nhật: #{err_msg}")
          end
        rescue => e
          UI.messagebox("Lỗi trong quá trình xử lý file cập nhật: #{e.message}")
        ensure
          UI.status_text = ""
        end
      end
    end
  end
end