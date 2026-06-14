
class ZSU::Monggo
  include ZSU::Preset
  settings_section "mong_go"

  def initialize
    ZSU.init_undo
    init_var
  end

  def activate
    load_active_preset
    @prev_transparency = ZSU::Model.get_trans
    ZSU::Model.set_trans(true)

    @license_status = true
    return ZSU.select_tool(nil) unless @license_status

    @selected_entities = ZSU::Board.filter_and_fix
    reset_state
    update_status
    update_target_faces
  end

  def deactivate(view)
    save_active_preset
    ZSU::Model.set_trans(@prev_transparency)
    view.invalidate
  end

  def resume(view)
    view.invalidate
    update_status
  end

  def enableVCB?
    true
  end

  def onUserText(text, view)
    if text.include?(",")
      parts = text.split(",", 2)
      len1_str = parts[0].strip
      len2_str = parts[1].strip
      unless len1_str.empty?
        len1 = len1_str.to_l.to_mm.to_f
        return if len1 < 0
        @chieu_dai_mong = len1.mm
        write("chieu_dai_mong", len1)
      end
      unless len2_str.empty?
        len2 = len2_str.to_l.to_mm.to_f
        return if len2 < 0
        @chieu_sau_mong = len2.mm
        write("chieu_sau_mong", len2)
      end
    elsif text.start_with?("/")
      if @so_luong_co_dinh
        num = text[1..-1].to_i
        return if num < 0
        @so_luong_mong = num
        write("so_luong_mong", num)
      else
        num = text[1..-1].to_l.to_mm.to_f
        return if num < 0
        @khoang_cach_mong = num.mm
        write("khoang_cach_mong", num)
      end
    elsif text.start_with?(":")
      num = text[1..-1].to_l.to_mm.to_f
      return if num < 0
      @khoan_moi_toi_mong = num.mm
      write("khoan_moi_toi_mong", num)
    else
      len = text.to_l.to_mm.to_f
      return if len < 0
      @cach_truoc = len.mm
      @cach_sau = len.mm if @cach_deu_hai_dau
      write("cach_truoc", len)
    end

    @button_config[:modified] = true if @button_config
    view.invalidate if view
    update_status
  end

  def onKeyDown(key, repeat, flags, view)
    if key == ZSU::Settings.key_mo_cai_dat
      ZSU::Settings.open_settings('mong_go')
    elsif key == VK_CONTROL
      @ctrl_mode = true
      update_ctrl_faces
      view.invalidate
    elsif key == ALT_MODIFIER_KEY
      @alt_mode = true
      view.invalidate
      return true
    end
  end

  def onKeyUp(key, repeat, flags, view)
    return if @sb_selected_item
    if key == 9 # Tab
      @shift_auto = !@shift_auto
      write("shift_auto", @shift_auto)
      update_target_faces
      reset_state
    elsif key == VK_CONTROL
      @ctrl_mode = false
      update_ctrl_faces
    elsif key == ALT_MODIFIER_KEY
      @alt_mode = false
      @highlighted_edges = nil
      return true
    end
    view.invalidate
    update_status
  end

  def onReturn(view)
    if @alt_mode
      execute_alt_mode(view)
    else
      execute_normal_mode(view)
    end
  end

  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    @mouse_x = x
    @mouse_y = y

    ph = view.pick_helper
    ph.do_pick(x, y)
    f = ph.picked_face
    parent = ph.best_picked
    unless parent && ZSU.is_container?(parent)
      reset_state
      view.invalidate
      return
    end
    @fixed_parents ||= Set.new
    unless @fixed_parents.include?(parent)
      parent = parent.make_unique
      ZSU::Group.fix_scale(parent)
      @fixed_parents.add(parent)
    end
    tr = parent.transformation
    @hit_point = f ? ZSU::View.calc_hit_point(f, tr, x, y, view) : nil

    if f
      n = f.normal.transform(tr)
      n.normalize!
      @hover_normal = n
    else
      @hover_normal = nil
    end

    if @alt_mode
      return unless f
      hit_point = ZSU::View.calc_hit_point(f, tr, x, y, view)
      find_highlighted_edges(f, parent, tr, hit_point)
      view.invalidate
      return
    end

    if @shift_auto
      if @selected_entities.size > 0
        @target_faces = find_all_faces_with_filter(@selected_entities)
      else
        @target_faces = find_all_faces([parent])
      end
    else
      return unless f
      fb = ZSU::Board.get_cnc_faces(parent)
      return unless fb
      band_faces = ZSU.grep_ents(parent, :face).to_a - fb.to_a
      if @canh_dai_toi_thieu > 0
        band_faces = band_faces.reject { |face| face.edges.map(&:length).max < @canh_dai_toi_thieu }
      end
      eff_chieu_dai = [@chieu_dai_mong, 1.mm].max
      band_faces = band_faces.reject do |face|
        face.edges.map(&:length).max < (eff_chieu_dai + @duong_kinh_dao)
      end
      band_faces = band_faces.select { |face| r = find_mortise_parent(face, parent); r && !r.empty? }
      target = band_faces.min_by do |face|
        plane = [face.bounds.center.transform(tr), face.normal.transform(tr)]
        @hit_point ? @hit_point.distance_to_plane(plane).abs : 0
      end

      if target
        @target_face = target
        @target_parent = parent
        @target_faces = [{ face: @target_face, parent: @target_parent }]
        @target_org = @target_faces.dup
        if @ctrl_mode
          opposite = band_faces.find { |face| face.normal.reverse == target.normal }
          @target_faces << { face: opposite, parent: @target_parent } if opposite
        end
      else
        reset_state
      end
    end
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
      end
      view.invalidate
    elsif handle_mode_click(x, y, view)
      return
    elsif @alt_mode
      execute_alt_mode(view)
    else
      execute_normal_mode(view)
    end
  end

  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)

    if @alt_mode
      if @highlighted_edges && @highlighted_edges[:chains]
        @highlighted_edges[:chains].each do |chain_data|
          pts = chain_data[:pts]
          ZSU::View.draw2d_polygon(pts) if pts && pts.size >= 3
        end
      end
      return
    end

    @datas = compute_joints_geometry
    return unless @datas
    return if @datas.empty?
    @hover_joint = find_hover_joint(@datas)
    @datas.each do |data|
      next unless data
      draw_joint_preview(data)
      draw_joint_texts(data) if @hien_khoang_cach
    end
  end

  def init_var
    # Phân bổ mộng
    @so_luong_co_dinh = read("so_luong_co_dinh", true)
    @so_luong_mong = read("so_luong_mong", 2).to_i
    @khoang_cach_mong = read("khoang_cach_mong", 200.0).to_f.mm
    # Vị trí
    @cach_deu_hai_dau = read("cach_deu_hai_dau", true)
    @cach_truoc = read("cach_truoc", 50.0).to_f.mm
    @cach_sau = read("cach_sau", 50.0).to_f.mm
    # Điều kiện
    @do_day_toi_thieu = read("van_day_toi_thieu", 16.0).to_f.mm
    @canh_dai_toi_thieu = read("canh_dai_toi_thieu", 50.0).to_f.mm
    # Khử dao
    @khu_dao = read("khu_dao", true)
    @tiet_dien_vuong = read("tiet_dien_vuong", false)
    @hinh_khu_dao = @tiet_dien_vuong ? "vuong" : "tron"
    @duong_kinh_dao = read("duong_kinh_dao", 6.0).to_f.mm
    # Mộng dương
    @chieu_dai_mong = read("chieu_dai_mong", 50.0).to_f.mm
    @chieu_sau_mong = read("chieu_sau_mong", 10.0).to_f.mm
    @bo_dau_mong = read("bo_dau_mong", 0.0).to_f.mm
    @bao_nen_mong = read("bao_mong", 0.0).to_f.mm
    @tao_mong_duong = read("tao_mong_duong", true)
    @instance_ha_nen = read("instance_ha_nen", "ABF_BM")
    @layer_ha_nen = read("layer_ha_nen", "ABF_BM")
    # Mộng âm
    @tao_mong_am = read("tao_mong_am", true)
    @chinh_rong_mong_am = read("tang_chieu_rong", 0.1).to_f.mm
    @chinh_cao_mong_am = read("tang_chieu_day", 0.1).to_f.mm
    @layer_mong_am = read("layer_mong_am", "ABF_MA")
    @instance_mong_am = read("instance_mong_am", "ABF_MA")
    @mau_mong_am = read("mau_mong_am", "210,117,159")
    @mau_mong_am = @mau_mong_am.join(',') if @mau_mong_am.is_a?(Array)
    # Lỗ khoan mồi
    @tao_khoan_moi = read("tao_khoan_moi", true)
    @tiet_dien_vuong_km = read("tiet_dien_vuong_km", false)
    @hinh_khoan_moi = @tiet_dien_vuong_km ? "vuong" : "tron"
    @huong_khoan_moi = read("huong_khoan_moi", "ngoai")
    @duong_kinh_khoan_moi = read("duong_kinh_khoan_moi", 4.0).to_f.mm
    @khoan_moi_toi_mong = read("khoan_moi_toi_mong", 10.0).to_f.mm
    @layer_khoan_moi = read("layer_khoan_moi", "ABF_KM")
    @instance_khoan_moi = read("instance_khoan_moi", "ABF_KM")
    @mau_khoan_moi = read("mau_khoan_moi", "210,117,159")
    @mau_khoan_moi = @mau_khoan_moi.join(',') if @mau_khoan_moi.is_a?(Array)
    # Hiển thị
    @hien_chieu_sau_mong = read("hien_thi_chieu_sau_mong", true)
    @hien_khoang_cach = read("hien_thi_khoang_cach", false)
    # UI state
    @shift_auto = read("shift_auto", false)
    @ctrl_mode = false
    @alt_mode = false
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_mode_buttons(
      ["Tự động", "Thủ công"],
      active_proc: -> { @shift_auto ? 0 : 1 },
      on_click: -> (i) {
        @shift_auto = (i == 0)
        write("shift_auto", @shift_auto)
        update_target_faces
        update_status
        Sketchup.active_model.active_view.invalidate
      }
    )
    init_setting_buttons(
      "Số lượng" => {
        so_luong_co_dinh: [:switch, "Số lượng cố định"],
        so_luong_mong: [:raw, "Số lượng mộng", -> { @so_luong_co_dinh }, 1],
        khoang_cach_mong: [:mm, "Khoảng cách", -> { !@so_luong_co_dinh }, 0],
      },
      "Vị trí" => {
        cach_deu_hai_dau: [:switch, "Cách đều hai đầu"],
        cach_truoc: [:mm, -> { @cach_deu_hai_dau ? "Cách hai đầu" : "Cách trước" }],
        cach_sau: [:mm, "Cách sau", -> { !@cach_deu_hai_dau }],
      },
      "Điều kiện" => {
        van_day_toi_thieu: [:mm, "Ván dày tối thiểu", nil, 0],
        canh_dai_toi_thieu: [:mm, "Cạnh dài tối thiểu", nil, 0],
      },
      "Mộng dương" => {
        tao_mong_duong: [:switch, "Tạo mộng dương"],
        chieu_dai_mong: [:mm, "Chiều dài", -> { @tao_mong_duong }],
        chieu_sau_mong: [:mm, "Chiều sâu", -> { @tao_mong_duong }],
        bo_dau_mong: [:mm, "Bo đầu", -> { @tao_mong_duong }],
        bao_mong: [:mm, "Bào mỏng", -> { @tao_mong_duong }, 0],
      },
      "Mộng âm" => {
        tao_mong_am: [:switch, "Tạo mộng âm"],
        tang_chieu_rong: [:mm, "Tăng chiều rộng", -> { @tao_mong_am }],
        tang_chieu_day: [:mm, "Tăng chiều dày", -> { @tao_mong_am }],
      },
      "Lỗ khoan mồi" => {
        tao_khoan_moi: [:switch, "Tạo lỗ khoan mồi"],
        duong_kinh_khoan_moi: [:mm, "Đường kính", -> { @tao_khoan_moi }, 0],
        khoan_moi_toi_mong: [:mm, "Cách mộng", -> { @tao_khoan_moi }, 0],
        huong_khoan_moi: [:select, "Hướng đặt",
                          {"ngoai" => "Ngoài", "trong" => "Trong",
                           "chinh_giua" => "Giữa mộng", "hai_ben" => "Hai bên"},
                          -> { @tao_khoan_moi }],
      },
      "Hiển thị" => {
        hien_thi_chieu_sau_mong: [:switch, "Hiển thị chiều sâu"],
        hien_thi_khoang_cach: [:switch, "Hiển thị khoảng cách"],
      }
    )
  end

  def update_preview
  end

  private

  def load_preset(s)
    init_preset(:so_luong_co_dinh, s)
    init_preset(:so_luong_mong, s) { |v| v.to_i }
    init_preset(:khoang_cach_mong, s) { |v| v.to_f.mm }
    init_preset(:cach_deu_hai_dau, s)
    init_preset(:cach_truoc, s) { |v| v.to_f.mm }
    init_preset(:cach_sau, s) { |v| v.to_f.mm }
    # Điều kiện - đọc từ key HTML
    @do_day_toi_thieu = (s["van_day_toi_thieu"] || 16.0).to_f.mm
    @canh_dai_toi_thieu = (s["canh_dai_toi_thieu"] || 50.0).to_f.mm
    # Khử dao
    @khu_dao = s.key?("khu_dao") ? s["khu_dao"] : true
    @tiet_dien_vuong = s.key?("tiet_dien_vuong") ? s["tiet_dien_vuong"] : false
    @hinh_khu_dao = @tiet_dien_vuong ? "vuong" : "tron"
    @duong_kinh_dao = (s["duong_kinh_dao"] || 6.0).to_f.mm
    # Mộng dương
    init_preset(:tao_mong_duong, s)
    @chieu_dai_mong = (s["chieu_dai_mong"] || 50.0).to_f.mm
    @chieu_sau_mong = (s["chieu_sau_mong"] || 10.0).to_f.mm
    @bo_dau_mong = (s["bo_dau_mong"] || 0.0).to_f.mm
    @bao_nen_mong = (s["bao_mong"] || 0.0).to_f.mm
    @instance_ha_nen = s["instance_ha_nen"] || "ABF_BM"
    @layer_ha_nen = s["layer_ha_nen"] || "ABF_BM"
    # Mộng âm
    @tao_mong_am = s.key?("tao_mong_am") ? s["tao_mong_am"] : true
    @chinh_rong_mong_am = (s["tang_chieu_rong"] || 0.1).to_f.mm
    @chinh_cao_mong_am = (s["tang_chieu_day"] || 0.1).to_f.mm
    @layer_mong_am = s["layer_mong_am"] || "ABF_MA"
    @instance_mong_am = s["instance_mong_am"] || "ABF_MA"
    v = s["mau_mong_am"]
    @mau_mong_am = v.is_a?(Array) ? v.join(',') : (v || "210,117,159")
    # Khoan mồi
    @tao_khoan_moi = s.key?("tao_khoan_moi") ? s["tao_khoan_moi"] : true
    @tiet_dien_vuong_km = s.key?("tiet_dien_vuong_km") ? s["tiet_dien_vuong_km"] : false
    @hinh_khoan_moi = @tiet_dien_vuong_km ? "vuong" : "tron"
    @huong_khoan_moi = s["huong_khoan_moi"] || "ngoai"
    @duong_kinh_khoan_moi = (s["duong_kinh_khoan_moi"] || 4.0).to_f.mm
    @khoan_moi_toi_mong = (s["khoan_moi_toi_mong"] || 10.0).to_f.mm
    @layer_khoan_moi = s["layer_khoan_moi"] || "ABF_KM"
    @instance_khoan_moi = s["instance_khoan_moi"] || "ABF_KM"
    v2 = s["mau_khoan_moi"]
    @mau_khoan_moi = v2.is_a?(Array) ? v2.join(',') : (v2 || "210,117,159")
    # Hiển thị
    @hien_chieu_sau_mong = s.key?("hien_thi_chieu_sau_mong") ? s["hien_thi_chieu_sau_mong"] : true
    @hien_khoang_cach = s.key?("hien_thi_khoang_cach") ? s["hien_thi_khoang_cach"] : false
  end

  def reset_state
    @target_faces = []
    @resolved_targets = []
    @target_face = nil
    @target_parent = nil
    @mortise_parent = nil
    @target_org = []
    @mortise_cache = {}
    @nearby_cache = {}
    @hit_point = nil
    @hover_normal = nil
    @alt_mode = false
    @highlighted_edges = nil
  end

  def update_status
    cach_str = @cach_deu_hai_dau ?
      "Cách hai đầu [x]: #{@cach_truoc.to_mm.round(1)}" :
      "Cách [x]: #{@cach_truoc.to_mm.round(1)},#{@cach_sau.to_mm.round(1)}"
    so_luong_str = @so_luong_co_dinh ?
      "Số mộng [/x]: #{@so_luong_mong}" :
      "Khoảng cách [/x]: #{@khoang_cach_mong.to_mm.round(1)}"
    kich_thuoc_str = "Kích thước [x,y]: #{@chieu_dai_mong.to_mm.round(1)},#{@chieu_sau_mong.to_mm.round(1)}"
    ZSU.vcb("#{so_luong_str} | #{cach_str} | #{kich_thuoc_str}", nil)
    mode_str = @shift_auto ? "thủ công" : "tự động"
    ZSU.status("Nhấn Tab để chuyển sang chế độ #{mode_str}. Giữ Ctrl để đánh mộng đối xứng. Giữ Alt để khử mộng.")
  end

  def update_ctrl_faces
    return if @shift_auto
    if @ctrl_mode
      return unless @target_face && @target_face.valid? &&
                    @target_parent && @target_parent.valid?
      band_faces = ZSU.grep_ents(@target_parent, :face).to_a - ZSU::Board.get_cnc_faces(@target_parent).to_a
      opposite = band_faces.find { |face| face.valid? && face.normal.reverse == @target_face.normal }
      @target_faces << { face: opposite, parent: @target_parent } if opposite
    else
      return unless @target_faces && @target_faces.size > 1
      @target_faces = [@target_faces.first]
      @target_face = @target_faces.first[:face]
    end
  end

  def update_target_faces
    if @shift_auto
      if @selected_entities.size > 0
        @target_faces = find_all_faces_with_filter(@selected_entities)
      elsif @target_parent
        @target_faces = find_all_faces([@target_parent])
      end
    else
      @target_faces = @target_org.dup
    end
  end

  # ─── FIND FACES ────────────────────────────────────────────────────────────

  def find_all_faces(ents)
    eff = [@chieu_dai_mong, 1.mm].max
    ZSU::Board.get_band_faces(ents, eff + 1.mm)
  end

  def find_all_faces_with_filter(ents)
    eff = [@chieu_dai_mong, 1.mm].max
    ZSU::Board.get_band_faces(ents, eff + 1.mm).select do |data|
      mortises = find_mortise_parent(data[:face], data[:parent], pool: ents)
      !mortises.empty? && mortises.any? { |m| ents.include?(m) }
    end
  end

  # ─── GEOMETRY ──────────────────────────────────────────────────────────────

  def calc_so_luong_mong(distance)
    if @so_luong_co_dinh
      @so_luong_mong
    else
      return 1 if @khoang_cach_mong.nil? || @khoang_cach_mong <= 0
      return 1 if distance <= @khoang_cach_mong
      n = (distance / @khoang_cach_mong).round + 1
      [n, 1].max
    end
  end

  def compute_joint_geometry
    return unless @target_face && @target_parent
    tr = @target_parent.transformation
    if @do_day_toi_thieu > 0
      t_thickness = ZSU::Board.calc_thickness(@target_parent)
      return unless t_thickness && ((t_thickness - @do_day_toi_thieu).abs < 0.01.mm || t_thickness >= @do_day_toi_thieu)
    end
    pool = (@shift_auto && @selected_entities.size > 0) ? @selected_entities : nil
    mortise_parents = find_mortise_parent(@target_face, @target_parent, pool: pool)
    return if mortise_parents.empty?
    if @do_day_toi_thieu > 0
      mortise_parents = mortise_parents.select do |mp|
        m_thickness = ZSU::Board.calc_thickness(mp)
        m_thickness && ((m_thickness - @do_day_toi_thieu).abs < 0.01.mm || m_thickness >= @do_day_toi_thieu)
      end
      return if mortise_parents.empty?
    end

    pairs = ZSU::Face.rectangle_edges(@target_face)
    return unless pairs

    # Cặp cạnh ngắn = chiều dày ván (len), cặp cạnh dài = dọc tiếp xúc
    short_pair = pairs.min_by { |pair|
      a1, a2 = pair[0].vertices.map { |v| v.position.transform(tr) }
      a1.distance(a2)
    }
    long_pair = pairs.max_by { |pair|
      a1, a2 = pair[0].vertices.map { |v| v.position.transform(tr) }
      a1.distance(a2)
    }

    e1, e2 = short_pair
    a1, a2 = e1.vertices.map { |v| v.position.transform(tr) }
    b1, b2 = e2.vertices.map { |v| v.position.transform(tr) }
    v1 = a1.vector_to(a2)
    v2 = b1.vector_to(b2)
    return unless v1.parallel?(v2)
    if v1.dot(v2) < 0
      b1, b2 = b2, b1
      v2 = b1.vector_to(b2)
    end
    proj_a1 = a1.project_to_line([b1, v2])
    normal_vector = a1.vector_to(proj_a1)
    unit_normal = normal_vector.normalize
    unit_v1 = v1.normalize
    orig_mid_a = Geom.linear_combination(0.5, a1, 0.5, a2)
    len = a1.distance(a2)   # chiều dày ván (width of tenon)
    transformed_normal = @target_face.normal.transform(tr)
    transformed_normal.normalize!

    # Dùng cặp cạnh DÀI để xác định vùng tiếp xúc
    le1 = long_pair[0].vertices.map { |v| v.position.transform(tr) }
    le2 = long_pair[1].vertices.map { |v| v.position.transform(tr) }

    results = []
    mortise_parents.each do |mp|
      le1_pts = edge_contact_points(le1, mp)
      le2_pts = edge_contact_points(le2, mp)
      next if le1_pts.size < 2 || le2_pts.size < 2
      le1_pts.sort_by! { |pt| (pt - orig_mid_a).dot(unit_normal) }
      le2_pts.sort_by! { |pt| (pt - orig_mid_a).dot(unit_normal) }
      contact_start = Geom.linear_combination(0.5, le1_pts.first, 0.5, le2_pts.first)
      contact_end = Geom.linear_combination(0.5, le1_pts.last, 0.5, le2_pts.last)
      total_dist = contact_start.distance(contact_end)
      mid_a = contact_start

      if @cach_deu_hai_dau
        cach_truoc = @cach_truoc
        cach_sau = @cach_truoc
      else
        near_start = !@hit_point || contact_start.distance(@hit_point) <= contact_end.distance(@hit_point)
        cach_truoc = near_start ? @cach_truoc : @cach_sau
        cach_sau = near_start ? @cach_sau : @cach_truoc
      end

      chieu_dai_mong = @chieu_dai_mong > 0 ? @chieu_dai_mong : 30.mm

      # Tính số lượng và vị trí mộng
      max_joint_number = ((total_dist - cach_truoc - cach_sau) / chieu_dai_mong).floor
      if max_joint_number < 2
        so_luong_mong = 1
        next if total_dist < chieu_dai_mong
        center_offset = total_dist / 2.0
        start_point = mid_a.offset(unit_normal, center_offset)
        end_point = start_point
      else
        offset_start = cach_truoc + chieu_dai_mong / 2.0
        offset_end = total_dist - cach_sau - chieu_dai_mong / 2.0
        next if offset_end <= offset_start
        start_point = mid_a.offset(unit_normal, offset_start)
        end_point = mid_a.offset(unit_normal, offset_end)
        distance = start_point.distance(end_point)
        max_joint_number = (distance / chieu_dai_mong).floor
        target_so_luong = calc_so_luong_mong(distance)
        so_luong_mong = [target_so_luong, max_joint_number].min
        so_luong_mong = [so_luong_mong, 1].max
        next if so_luong_mong > 1 && distance <= chieu_dai_mong * (so_luong_mong - 1)
      end

      divisor = so_luong_mong > 1 ? so_luong_mong - 1 : 1
      results << {
        start_point: start_point,
        end_point: end_point,
        unit_v1: unit_v1,
        unit_normal: unit_normal,
        transformed_normal: transformed_normal,
        len: len,
        divisor: divisor,
        transform: tr,
        so_luong_mong: so_luong_mong,
        mortise_parent: mp,
        chieu_dai_mong: chieu_dai_mong,
        edge_start: mid_a,
        edge_end: mid_a.offset(unit_normal, total_dist)
      }
    end
    results.empty? ? nil : results
  end

  def compute_joints_geometry
    geometries = []
    new_targets = []
    return unless @target_faces && @target_faces.size > 0
    @target_faces.each do |target|
      @target_face = target[:face]
      @target_parent = target[:parent]
      geos = compute_joint_geometry
      if geos
        geos.each do |geo|
          geometries << geo
          new_targets << target
        end
      end
    end
    @resolved_targets = new_targets
    @target_faces = new_targets
    geometries
  end

  # ─── DRAW HELPERS ──────────────────────────────────────────────────────────

  def find_hover_joint(datas)
    return nil unless @mouse_x && @mouse_y
    view = Sketchup.active_model.active_view
    datas.each do |data|
      next unless data && @tao_mong_duong
      n = data[:so_luong_mong]
      v1 = data[:unit_v1]
      normal = data[:transformed_normal]
      unit_perp = v1 * normal
      unit_perp.normalize!
      half_dai = data[:chieu_dai_mong] / 2.0
      half_len = data[:len] / 2.0
      (0...n).each do |i|
        t = n == 1 ? 0.5 : i.to_f / data[:divisor]
        bp = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        corners = [
          bp.offset(unit_perp, -half_dai).offset(v1, -half_len),
          bp.offset(unit_perp, -half_dai).offset(v1, half_len),
          bp.offset(unit_perp, half_dai).offset(v1, half_len),
          bp.offset(unit_perp, half_dai).offset(v1, -half_len)
        ]
        screen_pts = corners.map { |p| view.screen_coords(p) }
        return { data: data, index: i } if ZSU::View.point_in_polygon_2d?(@mouse_x, @mouse_y, screen_pts)
      end
    end
    nil
  end

  def draw_joint_preview(data)
    so_luong_mong = data[:so_luong_mong]
    v1 = data[:unit_v1]
    normal = data[:transformed_normal]
    xaxis = normal
    zaxis = v1
    yaxis = zaxis * xaxis
    unit_perp = v1 * normal
    unit_perp.normalize!
    (0...so_luong_mong).each do |i|
      t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
      base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
      chieu_dai_mong = data[:chieu_dai_mong]
      half_dai = chieu_dai_mong / 2.0
      half_len = data[:len] / 2.0
      sau = @chieu_sau_mong
      tip = base_point.offset(normal, sau)

      hovered = @hover_joint && @hover_joint[:data].equal?(data) && @hover_joint[:index] == i
      if hovered
        old_w = ZSU::View.edge_weight
        ZSU::View.set_edge_weight(old_w + 1)
      end

      if @tao_mong_duong
        a1 = base_point.offset(unit_perp, -half_dai).offset(v1, -half_len)
        d1 = base_point.offset(unit_perp,  half_dai).offset(v1, -half_len)
        a2 = base_point.offset(unit_perp, -half_dai).offset(v1,  half_len)
        d2 = base_point.offset(unit_perp,  half_dai).offset(v1,  half_len)

        if @hien_chieu_sau_mong
          b1 = tip.offset(unit_perp, -half_dai).offset(v1, -half_len)
          c1 = tip.offset(unit_perp,  half_dai).offset(v1, -half_len)
          b2 = tip.offset(unit_perp, -half_dai).offset(v1,  half_len)
          c2 = tip.offset(unit_perp,  half_dai).offset(v1,  half_len)
          ZSU::View.draw2d_polygon([a1, b1, c1, d1])
          ZSU::View.draw2d_polygon([a2, b2, c2, d2])
          ZSU::View.draw2d_polygon([a1, a2, d2, d1])
          ZSU::View.draw2d_polygon([b1, b2, c2, c1])
          ZSU::View.draw2d_polygon([a1, a2, b2, b1])
          ZSU::View.draw2d_polygon([d1, d2, c2, c1])
        else
          ZSU::View.draw2d_polygon([a1, a2, d2, d1])
        end
      end

      ZSU::View.set_edge_weight(old_w) if hovered

      if @tao_khoan_moi
        draw_pilot_preview(data, base_point, i, so_luong_mong, chieu_dai_mong, yaxis, zaxis)
      end
    end
  end

  def draw_joint_texts(data)
    so_luong_mong = data[:so_luong_mong]
    return if so_luong_mong < 1
    chieu_dai_mong = data[:chieu_dai_mong]
    half_dai = chieu_dai_mong / 2.0
    precision = ZSU::Model.get_unit_precision
    edge_start = data[:edge_start]
    edge_end = data[:edge_end]
    dir = edge_start.vector_to(edge_end)
    return unless dir.valid?
    unit_dir = dir.normalize

    centers = (0...so_luong_mong).map do |i|
      t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
      Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
    end

    first_near = centers.first.offset(unit_dir.reverse, half_dai)
    gap_start = edge_start.distance(first_near)
    if gap_start > 0.1.mm
      mid = Geom.linear_combination(0.5, edge_start, 0.5, first_near)
      ZSU::View.draw2d_text(format("%.#{precision}f", gap_start.to_mm), mid)
    end

    (0...so_luong_mong - 1).each do |i|
      far_i = centers[i].offset(unit_dir, half_dai)
      near_next = centers[i + 1].offset(unit_dir.reverse, half_dai)
      gap = far_i.distance(near_next)
      if gap > 0.1.mm
        mid = Geom.linear_combination(0.5, far_i, 0.5, near_next)
        ZSU::View.draw2d_text(format("%.#{precision}f", gap.to_mm), mid)
      end
    end

    last_far = centers.last.offset(unit_dir, half_dai)
    gap_end = last_far.distance(edge_end)
    if gap_end > 0.1.mm
      mid = Geom.linear_combination(0.5, last_far, 0.5, edge_end)
      ZSU::View.draw2d_text(format("%.#{precision}f", gap_end.to_mm), mid)
    end
  end

  def draw_pilot_preview(data, base_point, i, so_luong_mong, chieu_dai_mong, yaxis, zaxis)
    pilot_offset = (chieu_dai_mong / 2.0) + @khoan_moi_toi_mong
    radius = @duong_kinh_khoan_moi / 2.0
    segments = @tiet_dien_vuong_km ? 4 : 12
    base_vec = (data[:start_point] - data[:end_point])
    base_vec_norm = base_vec.length > 0 ? base_vec.normalize : data[:unit_normal]

    case @huong_khoan_moi
    when "hai_ben"
      [-1, 1].each do |side|
        center = base_point.offset(base_vec_norm, side * pilot_offset)
        circle_pts = (0...segments).map do |j|
          angle = 2 * Math::PI * j / segments
          center.offset(yaxis, Math.cos(angle) * radius).offset(zaxis, Math.sin(angle) * radius)
        end
        ZSU::View.draw2d_polygon(circle_pts)
      end
    when "chinh_giua"
      center = base_point
      circle_pts = (0...segments).map do |j|
        angle = 2 * Math::PI * j / segments
        center.offset(yaxis, Math.cos(angle) * radius).offset(zaxis, Math.sin(angle) * radius)
      end
      ZSU::View.draw2d_polygon(circle_pts)
    else
      pilot_vec = base_vec_norm.clone
      pilot_vec = pilot_vec.reverse if @huong_khoan_moi == "trong"
      pilot_vec = pilot_vec.reverse if (i + 1) > (so_luong_mong.to_f / 2)
      pilot_vec.length = pilot_offset
      center = base_point.transform(Geom::Transformation.translation(pilot_vec))
      circle_pts = (0...segments).map do |j|
        angle = 2 * Math::PI * j / segments
        center.offset(yaxis, Math.cos(angle) * radius).offset(zaxis, Math.sin(angle) * radius)
      end
      ZSU::View.draw2d_polygon(circle_pts)
    end
  end

  # ─── ALT MODE: XÓA MỘNG ───────────────────────────────────────────────────

  def distance_point_to_edge(point, edge, tr)
    p1 = edge.start.position.transform(tr)
    p2 = edge.end.position.transform(tr)
    line = [p1, p2 - p1]
    Geom.closest_points(line, [point, point])[0].distance(point)
  end

  def find_highlighted_edges(face, parent, tr, hit_point)
    @highlighted_edges = nil
    return unless face && face.valid?
    face_edges = face.edges
    edges_with_attr = face_edges.select { |e| e.get_attribute("ZSU", "mong_go") == true }
    return if edges_with_attr.empty?
    closest_edge = edges_with_attr.min_by { |e| distance_point_to_edge(hit_point, e, tr) }
    return unless closest_edge
    first_chain = find_connected_edges_on_face(closest_edge, face_edges, edges_with_attr)
    all_chains = find_all_connected_chains(first_chain, face_edges, edges_with_attr)
    chains_data = all_chains.map { |chain| { edges: chain, pts: edges_to_pts(chain, tr) } }
    @highlighted_edges = { chains: chains_data, transformation: tr, parent: parent, picked_face: face }
  end

  def find_all_connected_chains(first_chain, face_edges, edges_with_attr)
    edges_with_attr_set = Set.new(edges_with_attr)
    face_edges_set = Set.new(face_edges)
    all_chains = [first_chain]
    visited_edges = Set.new(first_chain)
    chains_to_process = [first_chain]
    while !chains_to_process.empty?
      current_chain = chains_to_process.shift
      get_chain_endpoints(current_chain).each do |endpoint_vertex|
        endpoint_vertex.edges.each do |bridge_edge|
          next if visited_edges.include?(bridge_edge)
          next unless face_edges_set.include?(bridge_edge)
          next if edges_with_attr_set.include?(bridge_edge)
          other_vertex = (bridge_edge.vertices - [endpoint_vertex]).first
          next unless other_vertex
          other_vertex.edges.each do |potential_start|
            next if visited_edges.include?(potential_start)
            next unless face_edges_set.include?(potential_start)
            next unless edges_with_attr_set.include?(potential_start)
            new_chain = find_connected_edges_on_face(potential_start, face_edges, edges_with_attr)
            new_chain = new_chain.reject { |e| visited_edges.include?(e) }
            if !new_chain.empty?
              all_chains << new_chain
              new_chain.each { |e| visited_edges.add(e) }
              chains_to_process << new_chain
            end
          end
        end
      end
    end
    all_chains
  end

  def get_chain_endpoints(chain)
    return [] if chain.empty?
    return chain.first.vertices if chain.size == 1
    ordered = ZSU::Edge.order_chain(chain)
    first_edge = ordered.first
    last_edge = ordered.last
    return first_edge.vertices if ordered.size == 1
    first_shared = (first_edge.vertices & ordered[1].vertices).first
    first_endpoint = (first_edge.vertices - [first_shared]).first
    last_shared = (ordered[-2].vertices & last_edge.vertices).first
    last_endpoint = (last_edge.vertices - [last_shared]).first
    [first_endpoint, last_endpoint].compact
  end

  def find_connected_edges_on_face(start_edge, face_edges, edges_with_attr)
    face_edges_set = Set.new(face_edges)
    edges_with_attr_set = Set.new(edges_with_attr)
    result = [start_edge]
    visited = Set.new([start_edge])
    queue = [start_edge]
    while !queue.empty?
      current = queue.shift
      current.vertices.each do |v|
        v.edges.each do |e|
          next if visited.include?(e)
          next unless face_edges_set.include?(e)
          next unless edges_with_attr_set.include?(e)
          visited.add(e)
          result << e
          queue << e
        end
      end
    end
    result
  end

  def edges_to_pts(edges, tr)
    return [] if edges.empty?
    ordered = ZSU::Edge.order_chain(edges)
    pts = []
    ordered.each_with_index do |edge, i|
      if i == 0
        if ordered.size == 1
          pts << edge.start.position.transform(tr)
          pts << edge.end.position.transform(tr)
        else
          shared = (edge.vertices & ordered[1].vertices).first
          start_v = (edge.vertices - [shared]).first
          pts << start_v.position.transform(tr)
          pts << shared.position.transform(tr)
        end
      else
        shared = (ordered[i - 1].vertices & edge.vertices).first
        other = (edge.vertices - [shared]).first
        pts << other.position.transform(tr) if other
      end
    end
    pts
  end

  def execute_alt_mode(view)
    return unless @highlighted_edges && @highlighted_edges[:chains]
    chains  = @highlighted_edges[:chains]
    parent  = @highlighted_edges[:parent]
    picked_face = @highlighted_edges[:picked_face]
    tr      = @highlighted_edges[:transformation]
    return unless chains && !chains.empty? && parent && picked_face

    ZSU.start
    thickness = ZSU::Board.calc_thickness(parent)
    return ZSU.abort unless thickness && thickness > 0

    entities = ZSU::Model.active_entities
    picked_normal = picked_face.normal.transform(tr)
    modifiers = []
    chains.each do |chain_data|
      pts = chain_data[:pts]
      next unless pts && pts.size >= 3
      grp = entities.add_group
      new_face = grp.entities.add_face(pts)
      if new_face
        new_normal = new_face.normal
        if picked_normal.samedirection?(new_normal)
          new_face.pushpull(-thickness)
        else
          new_face.pushpull(thickness)
        end
        modifiers << grp
      else
        grp.erase! if grp.valid?
      end
    end

    face_ids_before = Set.new(ZSU.get_ents(parent).grep(Sketchup::Face).map(&:entityID))
    ZSU::Solid.bulk_trim([parent], modifiers) if modifiers.any?
    ZSU::Purge.fix_all([parent])
    modifiers.each { |m| m.erase! if m.valid? }

    largest_faces = ZSU::Board.get_cnc_faces(parent) || []
    largest_faces = [largest_faces].flatten.compact
    largest_ids = Set.new(largest_faces.first(2).map(&:entityID))
    new_faces = ZSU.get_ents(parent).grep(Sketchup::Face).reject { |f|
      face_ids_before.include?(f.entityID) || largest_ids.include?(f.entityID)
    }

    if new_faces.size == 1
      parent_inv = parent.transformation.inverse
      entities.each do |e|
        next unless (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid?
        next if e == parent
        sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        to_erase = []
        sub_ents.each do |se|
          next unless (se.is_a?(Sketchup::Group) || se.is_a?(Sketchup::ComponentInstance)) && se.valid?
          next unless se.get_attribute("ZSU", "mong_go")
          center_world = se.transformation.origin.transform(e.transformation)
          center_local = center_world.transform(parent_inv)
          to_erase << se if point_on_faces?(center_local, new_faces)
        end
        to_erase.each { |se| se.erase! if se.valid? }
      end
    end

    ZSU.commit
    @highlighted_edges = nil
    @mortise_cache = {}
    @nearby_cache = {}
    view.invalidate
  end

  def point_on_faces?(pt, faces)
    faces.any? do |face|
      next false unless face.valid?
      a, b, c, d = face.plane
      dist = a * pt.x + b * pt.y + c * pt.z + d
      next false if dist.abs > 1.mm
      projected = Geom::Point3d.new(pt.x - dist * a, pt.y - dist * b, pt.z - dist * c)
      cp = face.classify_point(projected)
      cp == Sketchup::Face::PointInside || cp == Sketchup::Face::PointOnEdge || cp == Sketchup::Face::PointOnVertex
    end
  end

  # ─── TẠO HÌNH HỌC ──────────────────────────────────────────────────────────

  def draw_rect(ents, pts)
    ents.add_line(pts[0], pts[1])
    ents.add_line(pts[1], pts[2])
    ents.add_line(pts[2], pts[3])
    ents.add_line(pts[3], pts[0])
  end

  # Tạo mộng dương (tenon): hộp chữ nhật có bo đầu và khử dao
  # x = chiều sâu, y = chiều dài mộng, z = chiều dày ván
  def draw_tenon(x, y, z)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    ymin = -y / 2.0
    ymax =  y / 2.0
    zmin = -z / 2.0
    zmax =  z / 2.0
    pts = [
      Geom::Point3d.new(0, ymin, zmin),
      Geom::Point3d.new(x, ymin, zmin),
      Geom::Point3d.new(x, ymax, zmin),
      Geom::Point3d.new(0, ymax, zmin),
    ]
    draw_rect(ents, pts)

    xaxis  = Geom::Vector3d.new(1, 0, 0)
    normal = Geom::Vector3d.new(0, 0, 1)
    eff_duong_kinh = @khu_dao ? @duong_kinh_dao : 0

    # Bo đầu mộng
    if @bo_dau_mong > 0 && @bo_dau_mong < (@chieu_sau_mong - eff_duong_kinh)
      if @hinh_khu_dao == "tron"
        c1 = Geom::Point3d.new(x - @bo_dau_mong, ymin + @bo_dau_mong, zmin)
        c2 = Geom::Point3d.new(x - @bo_dau_mong, ymax - @bo_dau_mong, zmin)
        ents.add_arc(c1, xaxis, normal, @bo_dau_mong, 270.degrees, 360.degrees, 3)
        ents.add_arc(c2, xaxis, normal, @bo_dau_mong,   0.degrees,  90.degrees, 3)
      else
        ents.add_line(Geom::Point3d.new(x - @bo_dau_mong, ymin, zmin), Geom::Point3d.new(x, ymin + @bo_dau_mong, zmin))
        ents.add_line(Geom::Point3d.new(x, ymax - @bo_dau_mong, zmin), Geom::Point3d.new(x - @bo_dau_mong, ymax, zmin))
      end
    end

    # Khử dao (làm tròn / vuông ở gốc mộng)
    if eff_duong_kinh > 0
      radius = eff_duong_kinh / 2.0
      c1 = Geom::Point3d.new(radius, ymin, zmin)
      c2 = Geom::Point3d.new(radius, ymax, zmin)
      if @hinh_khu_dao == "tron"
        ents.add_arc(c1, xaxis, normal, radius,   0.degrees, 180.degrees, 6)
        ents.add_arc(c2, xaxis, normal, radius, 180.degrees, 360.degrees, 6)
      else
        s1 = [
          Geom::Point3d.new(0, ymax, zmin),
          Geom::Point3d.new(eff_duong_kinh, ymax, zmin),
          Geom::Point3d.new(eff_duong_kinh, ymax - radius, zmin),
          Geom::Point3d.new(0, ymax - radius, zmin),
        ]
        s2 = [
          Geom::Point3d.new(0, ymin, zmin),
          Geom::Point3d.new(eff_duong_kinh, ymin, zmin),
          Geom::Point3d.new(eff_duong_kinh, ymin + radius, zmin),
          Geom::Point3d.new(0, ymin + radius, zmin),
        ]
        draw_rect(ents, s1)
        draw_rect(ents, s2)
      end
    end

    # Tìm mặt lớn nhất, xoá các mặt thừa, pushpull
    ZSU.intersect_fix(ents)
    ents.grep(Sketchup::Edge).each { |e| e.find_faces }
    largest_face = ents.grep(Sketchup::Face).max_by(&:area)
    ents.grep(Sketchup::Face).each do |f|
      next if f == largest_face
      edges = f.edges
      f.erase!
      edges.each { |e| e.erase! if e.valid? && ZSU::Edge.stray?(e) }
    end
    if largest_face && largest_face.valid?
      largest_face.pushpull(z)
    end

    if @target_face && @target_face.valid? && @target_face.material
      grp.material = @target_face.material
    elsif @target_parent && @target_parent.material
      grp.material = @target_parent.material
    end
    ZSU.grep_ents(grp, :edge).each { |e| e.set_attribute("ZSU", "mong_go", true) }
    grp
  end

  # Tạo mộng âm (mortise): hộp chữ nhật với bo góc tại 4 góc
  def draw_mortise(x, y, z)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    ymin = -y / 2.0 - @chinh_rong_mong_am
    ymax =  y / 2.0 + @chinh_rong_mong_am
    ha_nen = @bao_nen_mong
    zmin = -z / 2.0 - @chinh_cao_mong_am + ha_nen / 2.0
    zmax =  z / 2.0 + @chinh_cao_mong_am - ha_nen / 2.0
    pts = [
      Geom::Point3d.new(0, ymin, zmin),
      Geom::Point3d.new(0, ymax, zmin),
      Geom::Point3d.new(0, ymax, zmax),
      Geom::Point3d.new(0, ymin, zmax),
    ]
    draw_rect(ents, pts)

    eff_duong_kinh = @khu_dao ? @duong_kinh_dao : 0
    if eff_duong_kinh > 0
      radius = eff_duong_kinh / 2.0
      c1 = Geom::Point3d.new(0, ymin, zmin + radius)
      c2 = Geom::Point3d.new(0, ymax, zmin + radius)
      c3 = Geom::Point3d.new(0, ymax, zmax - radius)
      c4 = Geom::Point3d.new(0, ymin, zmax - radius)
      if @hinh_khu_dao == "tron"
        normal = Geom::Vector3d.new(1, 0, 0)
        [c1, c2, c3, c4].each { |c| ents.add_circle(c, normal, radius, 12) }
      else
        # Vẽ hình vuông nhỏ tại 4 góc để khử dao dạng vuông
        [c1, c2, c3, c4].each do |c|
          s = [
            Geom::Point3d.new(0, c.y - radius, c.z - radius),
            Geom::Point3d.new(0, c.y + radius, c.z - radius),
            Geom::Point3d.new(0, c.y + radius, c.z + radius),
            Geom::Point3d.new(0, c.y - radius, c.z + radius),
          ]
          draw_rect(ents, s)
        end
      end
      ZSU.intersect_fix(ents)
      ents.grep(Sketchup::Edge).each { |e| e.find_faces }
      faces = ents.grep(Sketchup::Face)
      faces = ZSU::Face.merge_coplanar(faces)
      ents.grep(Sketchup::Edge).each { |e| e.erase! if ZSU::Edge.stray?(e) }
    else
      ents.grep(Sketchup::Edge).each { |e| e.find_faces }
    end

    material = ZSU.create_color_mat(@mau_mong_am)
    grp.material = material
    grp.entities.grep(Sketchup::Face).each do |face|
      face.reverse! if face.normal.x > 0
      face.material = material
      face.back_material = material
    end
    grp
  end

  # Tạo lỗ khoan mồi (pilot hole)
  def draw_pilot(d)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    center = Geom::Point3d.new(0, 0, 0)
    normal = Geom::Vector3d.new(1, 0, 0)
    radius = d / 2.0
    segments = @tiet_dien_vuong_km ? 4 : 12
    edges = ents.add_circle(center, normal, radius, segments)
    edges.first.find_faces if edges && edges.first
    material = ZSU.create_color_mat(@mau_khoan_moi)
    grp.material = material
    ents.grep(Sketchup::Face).each do |face|
      face.material = material
      face.back_material = material
    end
    grp
  end

  # Tạo vai bào nền (shoulder/ha_nen)
  def draw_ha_nen(x, z)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    eff_duong_kinh = @khu_dao ? @duong_kinh_dao : 0
    d = [eff_duong_kinh / 2.0, 3.mm].max
    zmin = -z / 2.0 - d
    zmax =  z / 2.0 + d
    pts = [
      Geom::Point3d.new(0, 0, zmin),
      Geom::Point3d.new(x, 0, zmin),
      Geom::Point3d.new(x, 0, zmax),
      Geom::Point3d.new(0, 0, zmax),
    ]
    draw_rect(ents, pts)
    ZSU.find_face(ents)
    ha_nen_layer = ZSU.ensure_tag(@layer_ha_nen)
    grp.name = @instance_ha_nen
    grp.layer = ha_nen_layer
    ents.each { |e| e.layer = ha_nen_layer }
    grp
  end

  # ─── KHOAN MỒI ─────────────────────────────────────────────────────────────

  def create_pilots(tr, data, chieu_dai_mong, i, so_luong_mong, m_ents, pilot_layer, mortise_parent)
    pilot_offset = (chieu_dai_mong / 2.0) + @khoan_moi_toi_mong
    base_vec = (data[:start_point] - data[:end_point]).clone
    base_vec = data[:unit_normal].clone if base_vec.length == 0

    case @huong_khoan_moi
    when "hai_ben"
      pilot_vec_1 = base_vec.clone
      pilot_vec_1.length = pilot_offset
      add_pilot_instance(tr, pilot_vec_1,          m_ents, pilot_layer, mortise_parent)
      add_pilot_instance(tr, pilot_vec_1.reverse,  m_ents, pilot_layer, mortise_parent)
    when "chinh_giua"
      add_pilot_instance(tr, nil, m_ents, pilot_layer, mortise_parent)
    else
      pilot_vec = base_vec.clone
      pilot_vec = pilot_vec.reverse if @huong_khoan_moi == "trong"
      pilot_vec = pilot_vec.reverse if (i + 1) > (so_luong_mong.to_f / 2)
      pilot_vec.length = pilot_offset
      add_pilot_instance(tr, pilot_vec, m_ents, pilot_layer, mortise_parent)
    end
  end

  def add_pilot_instance(tr, pilot_vec, m_ents, pilot_layer, mortise_parent)
    pilot_clone = @base_pilot.copy
    pilot_clone.transform!(tr)
    pilot_clone.transform!(Geom::Transformation.translation(pilot_vec)) if pilot_vec
    p_parent_tr = mortise_parent.transformation.inverse * pilot_clone.transformation
    new_inst = m_ents.add_instance(pilot_clone.definition, p_parent_tr)
    new_inst.layer = pilot_layer
    new_inst.name = @instance_khoan_moi
    new_inst.entities.each { |e| e.layer = pilot_layer }
    new_inst.set_attribute("ZSU", "mong_go", true)
    pilot_clone.erase!
  end

  # ─── EXECUTE ───────────────────────────────────────────────────────────────

  def execute_normal_mode(view)
    return unless @datas && !@datas.empty?

    if @hover_joint
      hover_data = @hover_joint[:data]
      @hover_idx = @hover_joint[:index]
      data_idx = @datas.index { |d| d.equal?(hover_data) }
      if data_idx
        @datas = [hover_data]
        @resolved_targets = [@resolved_targets[data_idx]]
      end
    else
      @hover_idx = nil
    end

    eff_duong_kinh = @khu_dao ? @duong_kinh_dao : 0
    if @chieu_sau_mong <= @bo_dau_mong + eff_duong_kinh
      text  = "Không thể thực hiện lệnh vì chiều sâu mộng (#{@chieu_sau_mong.to_mm.round(1)}mm)"
      text += " hiện đang nhỏ hơn tổng bo đầu mộng (#{@bo_dau_mong.to_mm.round(1)}mm)"
      text += " cộng đường kính dao (#{eff_duong_kinh.to_mm.round(1)}mm)."
      text += " Điều chỉnh lại cài đặt mộng sau đó thử lại."
      UI.messagebox(text)
      return
    end

    ZSU.start(false)
    mortise_layer = @tao_mong_am ? ZSU.ensure_tag(@layer_mong_am) : nil
    pilot_layer   = @tao_khoan_moi ? ZSU.ensure_tag(@layer_khoan_moi) : nil

    # Nhóm tenon theo target_parent để union và đặt đúng ván chủ
    tenons_by_parent = {}

    @resolved_targets.zip(@datas).each do |target, data|
      next unless target && data
      @target_face   = target[:face]
      @target_parent = target[:parent]
      @mortise_parent = data[:mortise_parent]
      chieu_dai_mong = data[:chieu_dai_mong]

      @base_tenon   = @tao_mong_duong ? draw_tenon(@chieu_sau_mong, chieu_dai_mong, data[:len]) : nil
      @base_ha_nen  = (@tao_mong_duong && @bao_nen_mong > 0) ? draw_ha_nen(@chieu_sau_mong, chieu_dai_mong) : nil
      @base_mortise = @tao_mong_am ? draw_mortise(@chieu_sau_mong, chieu_dai_mong, data[:len]) : nil
      @base_pilot   = @tao_khoan_moi ? draw_pilot(@duong_kinh_khoan_moi) : nil

      so_luong_mong = data[:so_luong_mong]
      (0...so_luong_mong).each do |i|
        next if @hover_idx && i != @hover_idx

        t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
        base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        xaxis = data[:transformed_normal]
        zaxis = data[:unit_v1]
        yaxis = zaxis * xaxis
        tr = Geom::Transformation.axes(base_point, xaxis, yaxis, zaxis)
        m_ents = @mortise_parent ? ZSU.get_ents(@mortise_parent) : nil

        # Mộng âm → đặt trong ván nhận
        if @base_mortise && @mortise_parent && m_ents
          mortise_clone = @base_mortise.copy
          mortise_clone.transform!(tr)
          if @bao_nen_mong > 0 && @hover_normal
            offset_dir = @hover_normal.reverse
            offset_dir.length = @bao_nen_mong / 2.0
            mortise_clone.transform!(Geom::Transformation.new(offset_dir))
          end
          m_parent_tr = @mortise_parent.transformation.inverse * mortise_clone.transformation
          new_inst = m_ents.add_instance(mortise_clone.definition, m_parent_tr)
          new_inst.layer = mortise_layer
          new_inst.name = @instance_mong_am
          new_inst.entities.each { |e| e.layer = mortise_layer }
          ZSU::ABF.is_intersect(new_inst, true)
          new_inst.set_attribute("ZSU", "mong_go", true)
          mortise_clone.erase!
        end

        # Lỗ khoan mồi
        if @base_pilot && @mortise_parent && m_ents
          create_pilots(tr, data, chieu_dai_mong, i, so_luong_mong, m_ents, pilot_layer, @mortise_parent)
        end

        # Mộng dương → thu thập theo parent
        if @base_tenon && @target_parent
          tenon_clone = @base_tenon.copy
          tenon_clone.material = @base_tenon.material
          tenon_clone.transform!(tr)
          parent_id = @target_parent.entityID
          tenons_by_parent[parent_id] ||= { parent: @target_parent, tenons: [] }
          tenons_by_parent[parent_id][:tenons] << tenon_clone
        end

        # Vai hạ nền (bào mỏng)
        if @base_ha_nen && @target_parent && @hover_normal
          ha_nen_clone = @base_ha_nen.copy
          ha_nen_xaxis = data[:transformed_normal]
          ha_nen_zaxis = ha_nen_xaxis * @hover_normal
          ha_nen_zaxis.normalize!
          offset_vec = @hover_normal.clone
          offset_vec.length = data[:len] / 2.0
          ha_nen_origin = base_point.offset(offset_vec)
          ha_nen_tr = Geom::Transformation.axes(ha_nen_origin, ha_nen_xaxis, @hover_normal, ha_nen_zaxis)
          ha_nen_clone.transform!(ha_nen_tr)
          t_ents = ZSU.get_ents(@target_parent)
          if t_ents
            rel_tr = ZSU.is_container?(@target_parent) ?
              @target_parent.transformation.inverse * ha_nen_clone.transformation :
              ha_nen_clone.transformation
            new_inst = t_ents.add_instance(ha_nen_clone.definition, rel_tr)
            ha_nen_layer = ZSU.ensure_tag(@layer_ha_nen)
            new_inst.name = @instance_ha_nen
            new_inst.layer = ha_nen_layer
            new_inst.entities.each { |e| e.layer = ha_nen_layer }
            new_inst.set_attribute("ZSU", "mong_go", true)
          end
          ha_nen_clone.erase!
        end
      end

      @base_tenon.erase! if @base_tenon&.valid?
      @base_ha_nen.erase! if @base_ha_nen&.valid?
      @base_mortise.erase! if @base_mortise&.valid?
      @base_pilot.erase! if @base_pilot&.valid?
    end

    # Union và đặt mộng dương đúng vào từng ván chủ tương ứng
    tenons_by_parent.each_value do |group|
      target_parent = group[:parent]
      tenon_list = group[:tenons]
      next if tenon_list.empty?

      base = tenon_list.shift
      tenon_list.each do |tenon|
        result = base.union(tenon)
        if result
          base = result
        else
          tenon.erase! rescue nil
        end
      end

      next unless base&.valid?
      ZSU.grep_ents(base, :edge).each { |e| e.set_attribute("ZSU", "mong_go", true) }
      entities = ZSU.get_ents(target_parent)
      next unless entities
      relative_transform = ZSU.is_container?(target_parent) ?
        target_parent.transformation.inverse * base.transformation :
        base.transformation
      new_inst = entities.add_instance(base.definition, relative_transform)
      new_inst.explode
      base.erase! rescue nil
      ZSU.intersect_fix(entities)
      after_faces = entities.grep(Sketchup::Face)
      after_faces = ZSU::Face.delete_inside(after_faces) if after_faces
      after_faces = ZSU::Face.merge_coplanar(after_faces) if after_faces
    end

    ZSU.commit
    reset_state
    view.invalidate
  end

  # ─── HELPERS: TÌM VÁN NHẬN ────────────────────────────────────────────────

  def edge_contact_points(edge_world, group)
    g_tr_inv = group.transformation.inverse
    p1l = edge_world[0].transform(g_tr_inv)
    p2l = edge_world[1].transform(g_tr_inv)
    cac_diem = []
    loop_limit = 0
    ZSU.get_ents(group).grep(Sketchup::Face).to_a.each do |face|
      loop_limit += 1
      break if loop_limit > 500
      plane = face.plane
      next unless p1l.distance_to_plane(plane).abs < 1.mm && p2l.distance_to_plane(plane).abs < 1.mm
      [p1l, p2l].each do |pt|
        cl = face.classify_point(pt)
        cac_diem << pt if cl == Sketchup::Face::PointInside ||
                          cl == Sketchup::Face::PointOnEdge ||
                          cl == Sketchup::Face::PointOnVertex
      end
      face.edges.to_a.each do |ef|
        giao = giao_2_doan(p1l, p2l, ef.start.position, ef.end.position)
        cac_diem << giao if giao
      end
    end
    cac_diem.uniq! { |pt| [pt.x.round(4), pt.y.round(4), pt.z.round(4)] }
    cac_diem.map { |pt| pt.transform(group.transformation) }
  end

  def giao_2_doan(a1, a2, b1, b2)
    va = a2 - a1
    vb = b2 - b1
    cross = va.cross(vb)
    return nil if cross.length < 0.001
    w = a1 - b1
    cl2 = cross.length ** 2
    t = vb.cross(w).dot(cross) / cl2
    s = va.cross(w).dot(cross) / cl2
    return nil unless (0.0..1.0).cover?(t) && (0.0..1.0).cover?(s)
    pt_on_a = Geom::Point3d.new(a1.x + t * va.x, a1.y + t * va.y, a1.z + t * va.z)
    pt_on_b = Geom::Point3d.new(b1.x + s * vb.x, b1.y + s * vb.y, b1.z + s * vb.z)
    return nil if pt_on_a.distance(pt_on_b) > 0.5.mm
    pt_on_a
  end

  def find_nearby_groups(parent, pool = nil)
    @nearby_cache ||= {}
    cache_key = parent.entityID
    return @nearby_cache[cache_key] if @nearby_cache.key?(cache_key)
    b1 = parent.bounds
    source = pool || ZSU::Model.active_entities
    result = source.select { |g|
      next unless ZSU.is_container?(g)
      next if g.hidden? || !g.layer.visible?
      next if g == parent
      next if g.name == @instance_mong_am
      next if g.name == @instance_khoan_moi
      next if g.name == @instance_ha_nen
      next if g.name == "_ABF_Label"
      next if g.name == "_ABF_Intersect"
      b2 = g.bounds
      # AABB intersection check đúng
      next unless b1.min.x <= b2.max.x && b2.min.x <= b1.max.x &&
                  b1.min.y <= b2.max.y && b2.min.y <= b1.max.y &&
                  b1.min.z <= b2.max.z && b2.min.z <= b1.max.z
      true
    }
    @nearby_cache[cache_key] = result
    result
  end

  def find_mortise_parent(face = @target_face, parent = @target_parent, pool: nil)
    return [] unless face && face.valid? && parent
    @mortise_cache ||= {}
    cache_key = face.entityID
    return @mortise_cache[cache_key] if @mortise_cache.key?(cache_key)

    tr = parent.transformation
    sorted = face.edges.sort_by { |e| -e.length }
    e1 = sorted[0]
    e2 = sorted[1]
    unless e1 && e2
      @mortise_cache[cache_key] = []
      return []
    end
    line1 = e1.vertices.map { |v| v.position.transform(tr) }
    line2 = e2.vertices.map { |v| v.position.transform(tr) }

    nearby = find_nearby_groups(parent, pool)
    loop_limit = 0
    result = nearby.select { |g|
      loop_limit += 1
      break if loop_limit > 500
      g_tr = g.transformation
      largest = ZSU::Board.get_cnc_faces(g)
      next unless largest && largest.size >= 2
      edges = largest.flat_map(&:edges).uniq
      edges.any? { |e|
        ep = e.vertices.map { |v| v.position.transform(g_tr) }
        Geom.intersect_line_line(ep, line1) && Geom.intersect_line_line(ep, line2)
      }
    }
    @mortise_cache[cache_key] = result
    result
  end

end