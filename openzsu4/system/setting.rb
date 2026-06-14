require 'json'
require 'fileutils'

module ZSU::Settings

  SETTINGS_DIR = File.join(ENV['LOCALAPPDATA'], "OPENZSU")
  OLD_SETTINGS_DIR = File.join(ENV['LOCALAPPDATA'], "ZSU")
  SETTINGS_FILE = File.join(SETTINGS_DIR, "settings.json")
  SETTINGS_BACKUP = File.join(SETTINGS_DIR, "settings_backup.json")
  STARTUP_FILE = File.join(SETTINGS_DIR, "startup.json")
  BACKUP_DIR = File.join(SETTINGS_DIR, "backup")
  STARTUP_KEYS = %w[tao_van tao_canh duc_khung ban_le doday phuc_hoi bo_goc bao_ranh tao_uon_cong tao_mong_go lien_ket khau_am_duong khu_dao khau_van noi_van cai_dat che_do_nha_phat_trien bieu_tuong_tuy_chinh thu_muc_bieu_tuong].freeze

  @setting_dialog = nil
  SETTINGS_VERSION = 4

  def self.key_mo_cai_dat
    192
  end

  def self.key_chuyen_che_do
    9
  end

  def self.ensure_file
    if !File.directory?(SETTINGS_DIR) && File.directory?(OLD_SETTINGS_DIR)
      begin
        FileUtils.mkdir_p(SETTINGS_DIR)
        Dir.glob(File.join(OLD_SETTINGS_DIR, "*")).each do |file|
          next if File.directory?(file)
          FileUtils.cp(file, File.join(SETTINGS_DIR, File.basename(file)))
        end
        old_backup = File.join(OLD_SETTINGS_DIR, "backup")
        if File.directory?(old_backup)
          FileUtils.cp_r(old_backup, SETTINGS_DIR)
        end
      rescue => e
        # ignore migration errors
      end
    end
    FileUtils.mkdir_p(SETTINGS_DIR)
    if File.exist?(SETTINGS_FILE)
      content = File.read(SETTINGS_FILE) rescue nil
      data = safe_json_parse(content) if content
      if !data.is_a?(Hash) || !data.key?("version")
        File.rename(SETTINGS_FILE, SETTINGS_BACKUP)
        File.write(SETTINGS_FILE, JSON.generate("version" => SETTINGS_VERSION))
      end
    else
      File.write(SETTINGS_FILE, JSON.generate("version" => SETTINGS_VERSION))
    end
  end

  def self.safe_json_parse(content)
    return {} if content.nil? || content.strip.empty?
    JSON.parse(content)
  rescue JSON::ParserError
    nil
  end

  def self.read_all
    ensure_file
    content = File.read(SETTINGS_FILE) rescue nil
    data = safe_json_parse(content) if content
    if data.nil?
      data = {}
      File.write(SETTINGS_FILE, "{}") rescue nil
    end
    data
  end

  def self.export
    path = UI.savepanel("Xuất cài đặt", SETTINGS_DIR, "settings.json")
    return false unless path
    path += ".json" unless path.downcase.end_with?(".json")
    ensure_file
    FileUtils.cp(SETTINGS_FILE, path)
    UI.messagebox("Đã xuất cài đặt thành công!")
    true
  end

  def self.import
    path = UI.openpanel("Nhập cài đặt", "", "JSON Files|*.json||")
    return false unless path
    begin
      data = JSON.parse(File.read(path))
      if data["version"].to_i != SETTINGS_VERSION
        UI.messagebox("File cài đặt không tương thích với phiên bản hiện tại!")
        return false
      end
      result = UI.messagebox("Cài đặt hiện tại sẽ bị xóa. Bạn có chắc muốn phục hồi cài đặt?", MB_YESNO)
      return false unless result == IDYES
      ensure_file
      FileUtils.cp(path, SETTINGS_FILE)
      true
    rescue JSON::ParserError
      UI.messagebox("File không hợp lệ!")
      false
    end
  end

  def self.reset
    result = UI.messagebox("Bạn có chắc muốn đặt tất cả cài đặt về mặc định?", MB_YESNO)
    return false unless result == IDYES
    File.delete(SETTINGS_FILE) if File.exist?(SETTINGS_FILE)
    ensure_file
    true
  end

  def self.export_online
    UI.messagebox("Tính năng đồng bộ máy chủ trực tuyến đã được tắt trên phiên bản mã nguồn mở này.\nVui lòng sử dụng tính năng Xuất cài đặt cục bộ để lưu trữ dữ liệu an toàn!")
    false
  end

  def self.import_online
    UI.messagebox("Tính năng đồng bộ máy chủ trực tuyến đã được tắt trên phiên bản mã nguồn mở này.\nVui lòng sử dụng tính năng Nhập cài đặt cục bộ để khôi phục dữ liệu an toàn!")
    false
  end

  def self.reset_section(section)
    return false unless section && !section.empty?
    data = read_all
    return false unless data.key?(section)
    data.delete(section)
    write_all(data)
    true
  end

  def self.write_all(data)
    ensure_file
    data["version"] = SETTINGS_VERSION
    begin
      json_content = JSON.pretty_generate(data)
    rescue
      return false
    end
    test_parse = safe_json_parse(json_content)
    if test_parse.nil?
      return false
    end
    temp_file = SETTINGS_FILE + ".tmp"
    begin
      File.write(temp_file, json_content)
    rescue
      return false
    end
    begin
      File.rename(temp_file, SETTINGS_FILE)
    rescue
      File.delete(temp_file) rescue nil
      return false
    end
    true
  end

  def self.intercept_trap_keys(key)
    key_str = key.to_s.downcase.strip
    if key_str.start_with?("ty_le_", "ti_so_", "he_so_", "do_chinh_", "ti_le_")
      return 1.0
    end
    if key_str.start_with?("sai_so_", "can_chinh_", "bu_sai_", "bu_tru_",
                           "do_lech_", "can_bang_", "hieu_chinh_")
      return 0.0
    end
    if key_str.start_with?("bo_dem_")
      return 1
    end
    nil
  end

  def self.read_only(key, default = nil, category = nil)
    intercepted = intercept_trap_keys(key)
    return intercepted unless intercepted.nil?

    data = read_all
    if category.nil?
      data.key?(key) ? coerce(data[key], default) : default
    else
      data[category]&.key?(key) ? coerce(data[category][key], default) : default
    end
  end

  def self.read(key, default = nil, category = nil)
    intercepted = intercept_trap_keys(key)
    return intercepted unless intercepted.nil?

    data = read_all
    begin
      if category.nil?
        if data.key?(key)
          coerce(data[key], default)
        else
          data[key] = default
          write_all(data)
          default
        end
      else
        data[category] ||= {}
        if data[category].key?(key)
          coerce(data[category][key], default)
        else
          data[category][key] = default
          write_all(data)
          default
        end
      end
    rescue
      default
    end
  end

  def self.coerce(value, default)
    return value if default.nil?
    begin
      case default
      when String
        value.is_a?(Array) ? value.join(',') : value.to_s
      when Integer
        value.to_i
      when Float
        value.to_f
      else
        value
      end
    rescue
      default
    end
  end

  def self.read_startup
    JSON.parse(File.read(STARTUP_FILE))
  rescue
    {}
  end

  def self.write_startup(key, value)
    data = read_startup
    data[key] = value
    File.write(STARTUP_FILE, JSON.generate(data))
  end

  def self.write(key, value, category = nil)
    data = read_all
    if category.nil?
      data[key] = value
    else
      data[category] ||= {}
      data[category][key] = value
    end
    write_all(data)
  end

  def self.parse_value(value_str)
    return true if value_str == "true"
    return false if value_str == "false"
    return nil if value_str == "null" || value_str.nil?
    if value_str =~ /^\-?\d+\.?\d*$/
      return value_str.include?('.') ? value_str.to_f : value_str.to_i
    end
    begin
      return JSON.parse(value_str)
    rescue JSON::ParserError
      return value_str
    end
  end

  def self.get_presets(tab_id)
    data = read_all
    data[tab_id] ||= {}
    data[tab_id]["presets"] ||= []
    data[tab_id]["presets"]
  end

  def self.save_preset(tab_id, preset_name, settings)
    data = read_all
    data[tab_id] ||= {}
    data[tab_id]["presets"] ||= []
    existing = data[tab_id]["presets"].find { |p| p["name"] == preset_name }
    if existing
      existing["settings"] = settings
    else
      data[tab_id]["presets"] << {
        "name" => preset_name,
        "settings" => settings
      }
    end
    write_all(data)
    true
  end

  def self.delete_preset(tab_id, preset_name)
    data = read_all
    data[tab_id] ||= {}
    data[tab_id]["presets"] ||= []
    data[tab_id]["presets"].reject! { |p| p["name"] == preset_name }
    write_all(data)
    true
  end

  def self.load_preset(tab_id, preset_name)
    data = read_all
    data[tab_id] ||= {}
    presets = data[tab_id]["presets"] || []
    preset = presets.find { |p| p["name"] == preset_name }
    return nil unless preset
    preset["settings"].each do |key, value|
      data[tab_id][key] = value
    end
    write_all(data)
    tool = Sketchup.active_model.tools.active_tool
    if tool.respond_to?(:init_var)
      tool.init_var
      ZSU::View.invalidate
    end
    result = preset["settings"]
    check_file_paths(result)
    result
  end

  def self.check_file_paths(settings)
    checks = {}
    settings.each do |key, value|
      next unless key.start_with?("duong_dan_") && value.is_a?(String) && !value.empty?
      checks[key] = File.exist?(value)
    end
    settings["_file_checks"] = checks unless checks.empty?
  end

  def self.load_all_settings
    data = read_all
    write_all(data)
    data.each_value { |s| check_file_paths(s) if s.is_a?(Hash) }
    data
  end

  def self.create_setting_dialog(tab_id = 'cai_dat', preset_name = nil)
    initial_tab = tab_id.dup
    initial_preset = preset_name ? preset_name.dup : nil
    dialog = UI::HtmlDialog.new(
      {
        dialog_title: "OpenZSU " + ZSU::VERSION + " - SketchUp " + (Sketchup.version.split('.').first.to_i + 2000).to_s,
        preferences_key: "zsu_settings_dialog",
        scrollable: false,
        resizable: true,
        width: 670,
        height: 640,
        min_width: 660,
        min_height: 640
      }
    )

    dialog.set_html(ZSU::Caidat.html)

    dialog.add_action_callback("load_settings") do |_|
      settings = load_all_settings
      settings["cai_dat"] ||= {}
      settings["cai_dat"]["phien_ban"] = ZSU::VERSION
      settings["cai_dat"]["phien_ban_moi_nhat"] ||= ZSU::VERSION
      settings["cai_dat"].merge!(read_startup)
      settings["su_version"] = Sketchup.version.split('.').first.to_i
      json_str = settings.to_json
      UI.start_timer(0.1, false) do
        script = "if (window.loadAllSettings) { window.loadAllSettings(#{json_str}); }"
        dialog.execute_script(script)
        UI.start_timer(0.15, false) do
          dialog.execute_script("switchToTab('#{initial_tab}');")
          if initial_preset
            UI.start_timer(0.3, false) do
              dialog.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{initial_preset}'); }")
            end
          end
        end
      end
    end

    dialog.add_action_callback("save_setting") do |_, params|
      parts = params.split('@')
      tab_id = parts[0]
      key = parts[1]
      value_str = parts[2]
      value = parse_value(value_str)
      if tab_id == "cai_dat" && STARTUP_KEYS.include?(key)
        write_startup(key, value)
      else
        write(key, value, tab_id)
      end
      if tab_id == "cai_dat"
        ZSU::Preset.reload_display_cache
        ZSU::View.invalidate
      else
        tool = Sketchup.active_model.tools.active_tool
        if tool.respond_to?(:init_var)
          tool.init_var
          ZSU::View.invalidate
        end
      end
    end

    dialog.add_action_callback("export_settings") do |_|
      ZSU::Settings.export
    end

    dialog.add_action_callback("import_settings") do |_|
      if ZSU::Settings.import
        dialog.close
        ZSU::View.invalidate
        UI.messagebox("Đã phục hồi cài đặt thành công!")
        open_settings
      end
    end

    dialog.add_action_callback("export_online") do |_|
      ZSU::Settings.export_online
    end

    dialog.add_action_callback("import_online") do |_|
      ZSU::Settings.import_online
    end

    dialog.add_action_callback("reset_settings") do |_|
      if ZSU::Settings.reset
        dialog.close
        ZSU::View.invalidate
        UI.messagebox("Đã đặt lại cài đặt thành công!")
        open_settings
      end
    end

    dialog.add_action_callback("reset_section") do |_, section|
      section_names = {
        "tao_van" => "Tạo ván", "tao_canh" => "Tạo cánh", "ban_le" => "Bản lề",
        "doday" => "Độ dày", "phuc_hoi" => "Phục hồi", "bo_goc" => "Bo góc",
        "bao_ranh" => "Bào rãnh", "uon_cong" => "Uốn cong", "mong_go" => "Mộng gỗ",
        "lien_ket" => "Liên kết", "am_duong" => "Âm dương", "khu_dao" => "Khử dao",
        "khau_van" => "Khấu ván", "noi_van" => "Nối ván"
      }
      name = section_names[section] || section
      result = UI.messagebox("Bạn có chắc muốn đặt cài đặt của #{name} về mặc định?", MB_YESNO)
      if result == IDYES
        ZSU::Settings.reset_section(section)
        dialog.close
        ZSU::View.invalidate
        UI.messagebox("Đã đặt lại cài đặt thành công!")
        open_settings(section)
      end
    end

    dialog.add_action_callback("view_hardware_id") do |_|
      UI.messagebox("Mã phần cứng: OPEN_SOURCE_LOCAL_HOST")
    end

    dialog.add_action_callback("deactivate_license") do |_|
      UI.messagebox("Phiên bản mã nguồn mở này không yêu cầu kích hoạt bản quyền.")
    end

    dialog.add_action_callback("load_presets") do |_, params|
      tab_id = params.to_s
      presets = get_presets(tab_id)
      data = read_all
      collapsed = (data[tab_id] && data[tab_id]["collapsed_groups"]) || {}
      json_str = presets.to_json
      collapsed_str = collapsed.to_json
      script = "if (window.sendPresetsToIframe) { window.sendPresetsToIframe('#{tab_id}', #{json_str}, #{collapsed_str}); }"
      dialog.execute_script(script)
    end

    dialog.add_action_callback("save_preset") do |_, params|
      parts = params.split('@')
      tab_id = parts[0]
      preset_name = parts[1]
      settings_json = parts[2..-1].join('@')
      settings = JSON.parse(settings_json)
      save_preset(tab_id, preset_name, settings)
      data = read_all
      presets = (data[tab_id] && data[tab_id]["presets"]) || []
      collapsed = (data[tab_id] && data[tab_id]["collapsed_groups"]) || {}
      script = "if (window.sendPresetsToIframe) { window.sendPresetsToIframe('#{tab_id}', #{presets.to_json}, #{collapsed.to_json}); }"
      dialog.execute_script(script)
      tool = Sketchup.active_model.tools.active_tool
      if tool.respond_to?(:init_var)
        tool.init_var
        ZSU::View.invalidate
      end
    end

    dialog.add_action_callback("delete_preset") do |_, params|
      parts = params.split('@')
      tab_id = parts[0]
      preset_name = parts[1]
      delete_preset(tab_id, preset_name)
      data = read_all
      presets = (data[tab_id] && data[tab_id]["presets"]) || []
      collapsed = (data[tab_id] && data[tab_id]["collapsed_groups"]) || {}
      script = "if (window.sendPresetsToIframe) { window.sendPresetsToIframe('#{tab_id}', #{presets.to_json}, #{collapsed.to_json}); }"
      dialog.execute_script(script)
      tool = Sketchup.active_model.tools.active_tool
      if tool.respond_to?(:init_var)
        tool.init_var
        ZSU::View.invalidate
      end
    end

    dialog.add_action_callback("load_preset") do |_, params|
      parts = params.split('@')
      tab_id = parts[0]
      preset_name = parts[1]
      settings = load_preset(tab_id, preset_name)
      if settings
        json_str = settings.to_json
        script = "if (window.sendSettingsToIframe) { window.sendSettingsToIframe('#{tab_id}', #{json_str}); }"
        dialog.execute_script(script)
      end
      settings ? settings.to_json : "null"
    end

    dialog.add_action_callback("save_presets_order") do |_, params|
      parts = params.split('@', 2)
      tab_id = parts[0]
      presets_json = parts[1]
      presets = JSON.parse(presets_json)
      data = read_all
      data[tab_id] ||= {}
      data[tab_id]["presets"] = presets
      write_all(data)
      tool = Sketchup.active_model.tools.active_tool
      if tool.respond_to?(:init_var)
        tool.init_var
        ZSU::View.invalidate
      end
    end

    dialog.add_action_callback("save_collapsed_groups") do |_, params|
      parts = params.split('@', 2)
      tab_id = parts[0]
      groups_json = parts[1]
      collapsed = JSON.parse(groups_json)
      data = read_all
      data[tab_id] ||= {}
      data[tab_id]["collapsed_groups"] = collapsed
      write_all(data)
    end

    dialog.add_action_callback("pick_file") do |_, params|
      parts = params.split('@')
      tab_id = parts[0]
      shape_key = parts[1]
      path_key = parts[2]
      path = UI.openpanel("Chọn file", "", "SketchUp Files|*.skp||")
      iframe_id = "iframe_#{tab_id}"
      if path && File.exist?(path)
        escaped = path.gsub("\\", "/")
        write(path_key, escaped, tab_id)
        script = "var iframe = document.getElementById('#{iframe_id}'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'file_picked', shapeKey: '#{shape_key}', pathKey: '#{path_key}', path: '#{escaped}' }, '*'); }"
        dialog.execute_script(script)
      else
        script = "var iframe = document.getElementById('#{iframe_id}'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'file_picked', shapeKey: '#{shape_key}', pathKey: '#{path_key}', path: null }, '*'); }"
        dialog.execute_script(script)
      end
      tool = Sketchup.active_model.tools.active_tool
      if tool.respond_to?(:init_var)
        tool.init_var
        ZSU::View.invalidate
      end
    end

    dialog.add_action_callback("check_update") do |_|
      begin
        ZSU::Update.check_version(true)
      rescue => e
        UI.messagebox("Lỗi cập nhật: #{e.message}")
        puts e.backtrace
      end
    end

    dialog.add_action_callback("uninstall") do |_|
      UI.messagebox("Để gỡ cài đặt, vui lòng xóa thư mục plugin trong mục Plugins của SketchUp.")
    end

    dialog.add_action_callback("select_icon_folder") do |_|
      folder = UI.select_directory(title: "Chọn thư mục biểu tượng")
      if folder
        folder = folder.gsub("\\", "/")
        write_startup("thu_muc_bieu_tuong", folder)
        script = "var iframe = document.getElementById('iframe_cai_dat'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'icon_folder_result', folder: '#{folder.gsub("'", "\\\\'")}' }, '*'); }"
        dialog.execute_script(script)
      else
        script = "var iframe = document.getElementById('iframe_cai_dat'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'icon_folder_result', folder: '' }, '*'); }"
        dialog.execute_script(script)
      end
    end

    dialog.add_action_callback("install_version") do |_, version|
      true
    end

    dialog.add_action_callback("check_update_version") do |_|
      UI.messagebox("Bạn đang sử dụng phiên bản OpenZSU mới nhất.")
    end

    dialog.set_on_closed {
      @setting_dialog = nil
      ZSU::Preset.reload_display_cache
      ZSU::View.invalidate
    }
    @setting_dialog = dialog
    dialog.center
    dialog.show
  end

  def self.dialog_visible?
    @setting_dialog && @setting_dialog.visible?
  end

  def self.notify_dialog(section, key, value)
    return unless dialog_visible?
    json = { key => value }.to_json
    script = "if (window.sendSettingsToIframe) {" \
      " window.sendSettingsToIframe('#{section}', #{json}); }"
    @setting_dialog.execute_script(script)
  end

  def self.open_settings(tab_id = 'cai_dat', preset_name = nil)
    if dialog_visible?
      if preset_name
        @setting_dialog.execute_script("switchToTab('#{tab_id}');")
        UI.start_timer(0.1, false) do
          @setting_dialog.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{preset_name}'); }")
        end
        return
      end
      @setting_dialog.close
      return
    end
    create_setting_dialog(tab_id, preset_name)
  end
end