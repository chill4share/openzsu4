require 'sketchup'

module ZSU

  TOL       = 0.001 unless defined?(ZSU::TOL)
  AREA_TOL  = 0.01 unless defined?(ZSU::AREA_TOL)
  VERSION   = defined?(OpenZSU::VERSION) ? OpenZSU::VERSION : "4.2.7"

  module Core
    def self.dpi_scale; 2.0; end        
    def self.dpi_offset; 20; end       
    def self.cache_step(p); 1; end     
    def self.texture_lod; 1.0; end     
  end

  Math = Core unless defined?(ZSU::Math)
  UtilsRender = Core unless defined?(ZSU::UtilsRender)
  module HtmlConfig
    def self._init_html_config(*args)
      true
    end
  end
end

module OpenZSU
  ::OpenZSU = self unless defined?(::OpenZSU)
end

require_relative 'system/setting'
require_relative 'system/update'
require_relative 'system.rb'

require_relative 'utils/other'

current_dir = File.dirname(__FILE__)
Dir.glob(File.join(current_dir, 'utils', '*.rb')).each do |file|
  require_file = File.basename(file, '.rb')
  next if require_file == 'other' || require_file == 'clibs'
  begin
    require_relative "utils/#{require_file}"
  rescue => e
    puts "OpenZSU Error loading utils/#{require_file}: #{e.message}"
  end
end
require_relative 'utils.rb'

Dir.glob(File.join(current_dir, 'method', '*.rb')).each do |file|
  require_file = File.basename(file, '.rb')
  next if require_file == 'clibs'
  begin
    require_relative "method/#{require_file}"
  rescue SyntaxError => e
    puts "OpenZSU SyntaxError loading method/#{require_file}: #{e.message}"
  rescue => e
    puts "OpenZSU Error loading method/#{require_file}: #{e.message}"
  end
end
require_relative 'method.rb'

module ZSU
  unless file_loaded?(__FILE__)

    tb = UI::Toolbar.new("OpenZSU - Woodworking Pro")
    icon_path = File.join(File.dirname(__FILE__), "icons")

    tools = [
      ["Tạo Ván", "taovan.svg", defined?(ZSU::Taovan) ? ZSU::Taovan : nil],
      ["Tạo Cánh", "taocanh.svg", defined?(ZSU::Taocanh) ? ZSU::Taocanh : nil],
      ["Bản Lề", "banle.svg", defined?(ZSU::Banle) ? ZSU::Banle : nil],
      ["Sửa Độ Dày", "doday.svg", defined?(ZSU::Doday) ? ZSU::Doday : nil],
      ["Nối Ván", "noivan.svg", defined?(ZSU::Noivan) ? ZSU::Noivan : nil],
      ["Khấu Ván", "khauvan.svg", defined?(ZSU::Khauvan) ? ZSU::Khauvan : nil],
      ["Khử Dao", "khudao.svg", defined?(ZSU::Khudao) ? ZSU::Khudao : nil],
      ["Âm Dương", "amduong.svg", defined?(ZSU::Amduong) ? ZSU::Amduong : nil],
      ["Liên Kết", "lienket.svg", defined?(ZSU::Lienket) ? ZSU::Lienket : nil],
      ["Mộng Gỗ", "monggo.svg", defined?(ZSU::Monggo) ? ZSU::Monggo : nil],
      ["Bào Rãnh", "baoranh.svg", defined?(ZSU::Baoranh) ? ZSU::Baoranh : nil],
      ["Bo Góc Ván", "bogoc.svg", defined?(ZSU::Bogoc) ? ZSU::Bogoc : nil],
      ["Đục Khung", "duckhung.svg", defined?(ZSU::Duckhung) ? ZSU::Duckhung : nil],
      ["Uốn Cong", "uoncong.svg", defined?(ZSU::Uoncong) ? ZSU::Uoncong : nil],
      ["Phục Hồi", "phuchoi.svg", defined?(ZSU::Phuchoi) ? ZSU::Phuchoi : nil]
    ]

    tools.each do |title, icon_name, target_module|
      next unless target_module

      cmd = UI::Command.new(title) {
        if Sketchup.active_model
          if target_module.respond_to?(:show_dialog)
            target_module.show_dialog
          else
            Sketchup.active_model.select_tool(target_module.new)
          end
        end
      }

      full_icon = File.join(icon_path, icon_name)
      cmd.small_icon = full_icon
      cmd.large_icon = full_icon
      cmd.tooltip = title
      cmd.status_bar_text = "OpenZSU: #{title}"
      tb.add_item(cmd)
    end

    tb.add_separator

    cmd_setting = UI::Command.new("Cài Đặt Hệ Thống") {
      if defined?(ZSU::Settings) && ZSU::Settings.respond_to?(:open_settings)
        ZSU::Settings.open_settings("cai_dat")
      elsif defined?(ZSU::Caidat) && ZSU::Caidat.respond_to?(:open_settings)
        ZSU::Caidat.open_settings("cai_dat")
      end
    }

    setting_icon = File.join(icon_path, "caidat.svg")
    cmd_setting.small_icon = setting_icon
    cmd_setting.large_icon = setting_icon
    cmd_setting.tooltip = "Cài Đặt Hệ Thống OpenZSU"
    cmd_setting.status_bar_text = "Cấu hình thông số ván, liên kết và tùy chọn mặc định."
    tb.add_item(cmd_setting)

    tb.restore

    menu = UI.menu("Plugins").add_submenu("OpenZSU")
    menu.add_item("Bảng Điều Khiển Cài Đặt") { 
      (defined?(ZSU::Settings) ? ZSU::Settings.open_settings("cai_dat") : ZSU::Caidat.open_settings("cai_dat")) rescue nil 
    }
    menu.add_item("Kiểm Tra Cập Nhật") { ZSU::Update.check_version(true) rescue nil }

    # Silent check for updates at startup (delayed by 3 seconds)
    UI.start_timer(3.0, false) do
      ZSU::Update.check_version(false) rescue nil
    end

    file_loaded(__FILE__)
  end
end