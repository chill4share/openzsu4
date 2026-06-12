require 'sketchup'
require 'net/http'
require 'json'
require 'openssl'

module ZSU
  module Update
    GITHUB_URL = "https://github.com/chill4share/openzsu4/releases"

    def self.check_version(manual = true)
      Thread.new do
        begin
          uri = URI("https://api.github.com/repos/chill4share/openzsu4/releases/latest")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "SketchUp-OpenZSU-Updater"
          response = http.request(request)

          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            latest_tag = data["tag_name"]
            latest_ver_str = latest_tag.gsub(/^v/, "")
            
            current_ver = Gem::Version.new(ZSU::VERSION)
            latest_ver = Gem::Version.new(latest_ver_str)

            if latest_ver > current_ver
              UI.start_timer(0, false) do
                msg = "Đã có phiên bản mới: #{latest_tag} (Phiên bản hiện tại: #{ZSU::VERSION}). Bạn có muốn tải về và cập nhật tự động ngay không?"
                if UI.messagebox(msg, MB_YESNO) == IDYES
                  download_and_install(latest_ver_str)
                end
              end
            elsif manual
              UI.start_timer(0, false) do
                UI.messagebox("Bạn đang sử dụng phiên bản mới nhất (#{ZSU::VERSION}).")
              end
            end
          elsif manual
            UI.start_timer(0, false) do
              UI.messagebox("Không thể kiểm tra phiên bản mới. Lỗi HTTP #{response.code}")
            end
          end
        rescue => e
          if manual
            UI.start_timer(0, false) do
              UI.messagebox("Lỗi kiểm tra phiên bản: #{e.message}")
            end
          end
        end
      end
      true
    end

    def self.download_file(url, limit = 10)
      raise "Too many HTTP redirects" if limit == 0

      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "SketchUp-OpenZSU-Updater"
      
      response = http.request(request)
      case response
      when Net::HTTPSuccess
        temp_path = File.join(Sketchup.temp_dir, "openzsu_update_#{Time.now.to_i}.rbz")
        File.open(temp_path, "wb") do |f|
          f.write(response.body)
        end
        temp_path
      when Net::HTTPRedirection
        location = response['location']
        download_file(location, limit - 1)
      else
        raise "Tải file thất bại: HTTP #{response.code}"
      end
    end

    def self.download_and_install(version_str)
      UI.status_text = "Đang tải bản cập nhật OpenZSU v#{version_str}..."
      
      Thread.new do
        begin
          ver_num = version_str.gsub('.', '')
          filename = "OpenZsu_#{ver_num}.rbz"
          url = "https://github.com/chill4share/openzsu4/releases/download/v#{version_str}/#{filename}"
          
          temp_path = download_file(url)
          
          UI.start_timer(0, false) do
            begin
              success = Sketchup.install_from_archive(temp_path)
              if success
                UI.messagebox("Cập nhật thành công phiên bản OpenZSU v#{version_str}! Vui lòng khởi động lại SketchUp để áp dụng các thay đổi.")
              else
                UI.messagebox("Cài đặt bản cập nhật thất bại.")
              end
            rescue => e
              UI.messagebox("Lỗi giải nén cài đặt: #{e.message}")
            ensure
              File.delete(temp_path) rescue nil
            end
          end
        rescue => e
          UI.start_timer(0, false) do
            UI.messagebox("Lỗi tải bản cập nhật: #{e.message}")
          end
        end
      end
    end
  end
end