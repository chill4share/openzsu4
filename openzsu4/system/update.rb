# frozen_string_literal: true

require 'sketchup'
require 'json'
require 'fileutils'

module ZSU
  module Update
    REPO_URL = "https://api.github.com/repos/chill4share/openzsu4/releases/latest"
    GITHUB_URL = "https://github.com/chill4share/openzsu4/releases"

    @check_request = nil
    @download_request = nil
    @check_in_progress = false
    @download_in_progress = false

    def self.check_version(manual = true)
      return if @check_in_progress
      @check_in_progress = true

      Sketchup.status_text = "Đang kiểm tra phiên bản mới từ GitHub..."

      @check_request = Sketchup::Http::Request.new(REPO_URL, Sketchup::Http::GET)
      @check_request.headers = { "User-Agent" => "OpenZSU-Updater" }
      @check_request.start do |req, res|
        next unless @check_in_progress
        @check_in_progress = false

        Sketchup.status_text = ""
        begin
          if res.status_code == 200
            data = JSON.parse(res.body)
            latest_version = data["tag_name"] # e.g. "v4.2.7"
            clean_latest = latest_version.gsub(/[^\d.]/, "")
            clean_current = ZSU::VERSION.gsub(/[^\d.]/, "")

            if version_greater?(clean_latest, clean_current)
              UI.start_timer(0, false) do
                prompt_update(latest_version)
              end
            else
              if manual
                UI.start_timer(0, false) do
                  UI.messagebox("Bạn đang sử dụng phiên bản mới nhất v#{ZSU::VERSION}.")
                end
              end
            end
          else
            raise "Mã phản hồi từ GitHub: #{res.status_code}"
          end
        rescue => e
          if manual
            UI.start_timer(0, false) do
              UI.messagebox("Không thể kiểm tra cập nhật:\n#{e.message}")
            end
          end
        ensure
          @check_request = nil
        end
      end
    end

    def self.version_greater?(v1, v2)
      a = v1.split('.').map(&:to_i)
      b = v2.split('.').map(&:to_i)
      [a.size, b.size].max.times do |i|
        ai = a[i] || 0
        bi = b[i] || 0
        return true if ai > bi
        return false if ai < bi
      end
      false
    end

    def self.prompt_update(latest_version)
      msg = "Đã có phiên bản mới #{latest_version} (phiên bản hiện tại v#{ZSU::VERSION}).\n" \
            "Bạn có muốn tải về và cài đặt tự động không?"
      result = UI.messagebox(msg, MB_YESNO)
      if result == IDYES
        start_download_and_install(latest_version)
      end
    end

    def self.start_download_and_install(version)
      return if @download_in_progress
      @download_in_progress = true

      Sketchup.status_text = "Đang tải bản cập nhật #{version}..."
      
      clean_ver = version.gsub(/[^\d.]/, "")
      download_url = "https://github.com/chill4share/openzsu4/releases/download/v#{clean_ver}/OpenZsu_#{clean_ver}.rbz"
      
      @download_request = Sketchup::Http::Request.new(download_url, Sketchup::Http::GET)
      @download_request.headers = { "User-Agent" => "OpenZSU-Updater" }
      @download_request.start do |req, res|
        next unless @download_in_progress
        @download_in_progress = false

        Sketchup.status_text = ""
        begin
          if res.status_code == 200
            temp_dir = File.join(ENV['LOCALAPPDATA'] || ENV['APPDATA'] || '.', "ZSU", "updates")
            FileUtils.mkdir_p(temp_dir)
            temp_file = File.join(temp_dir, "OpenZsu_#{clean_ver}.rbz")
            
            File.open(temp_file, "wb") { |f| f.write(res.body) }
            
            Sketchup.status_text = "Đang cài đặt bản cập nhật..."
            UI.start_timer(0, false) do
              if Sketchup.respond_to?(:install_from_archive)
                success = Sketchup.install_from_archive(temp_file)
                if success
                  UI.messagebox("Cập nhật thành công phiên bản #{version}!\nVui lòng khởi động lại SketchUp để thay đổi có hiệu lực.")
                else
                  UI.messagebox("Cài đặt bản cập nhật thất bại. Vui lòng tự cài đặt thủ công.")
                end
              else
                UI.messagebox("SketchUp của bạn không hỗ trợ cài đặt tự động. File cập nhật đã được tải về tại:\n#{temp_file}\nVui lòng tự cài đặt thủ công.")
              end
            end
          else
            raise "Mã lỗi tải file: #{res.status_code}"
          end
        rescue => e
          UI.start_timer(0, false) do
            UI.messagebox("Lỗi khi tải hoặc cài đặt bản cập nhật:\n#{e.message}")
          end
        ensure
          @download_request = nil
          @download_in_progress = false
          Sketchup.status_text = ""
        end
      end
    end
  end
end