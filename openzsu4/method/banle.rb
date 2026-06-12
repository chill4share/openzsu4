class ZSU::Banle
  include ZSU::Preset
  settings_section "ban_le"
  CHAR_PATHS = {
    "A" => [
      [[0.3, -0.5], [0.15, 0.0], [-0.14, 0.0], [-0.137, 0.01],
       [0.147, 0.01], [0.0, 0.5], [-0.3, -0.5]],
    ],
    "B" => [
      [[-0.225, -0.5], [-0.225, 0.5], [0.075, 0.5], [0.175, 0.35], [0.175, 0.15],
       [0.082, 0.01], [-0.215, 0.01], [-0.215, 0.0], [0.125, 0.0], [0.225, -0.15],
       [0.225, -0.35], [0.125, -0.5], [-0.215, -0.5]],
    ],
    "C" => [
      [[0.25, 0.4], [0.15, 0.5], [-0.05, 0.5], [-0.2, 0.4], [-0.25, 0.15],
       [-0.25, -0.15], [-0.2, -0.4], [-0.05, -0.5], [0.15, -0.5], [0.25, -0.4]],
    ],
  }
  def initialize
    ZSU.init_undo
    init_var
  end
  def activate
    load_active_preset
    @prev_transparency = ZSU::Model.get_trans
    ZSU::Model.set_trans(true)
    @active_anchor = nil
    @anchor_points = []
    @face = nil
    @tr = nil
    @parent = nil
    @construction_lines = []
    @cached_hoi = nil
    @cached_hoi_band = nil
    update_status
  end
  def resume(view)
    update_status
    view.invalidate
  end
  def enableVCB?
    true
  end
  def deactivate(view)
    restore_hoi
    restore_transparency
    save_active_preset
    view.invalidate
  end
  def init_var
    @thong_ke_ban_le = read("thong_ke_ban_le", true)
    @ten_hien_thi_ban_le = read("ten_hien_thi_ban_le", "")
    @loai_ban_le = read("loai_ban_le", "Tự động")
    @instance_ban_le = read("instance_ban_le", "ABF_BL")
    @layer_ban_le = read("layer_ban_le", "ABF_BL")
    @tu_dong_tranh_dot = read("tu_dong_tranh_dot", true)
    @dot_cach_toi_da = read("dot_cach_toi_da", 50.0).to_f.mm
    @chen_vien_thuoc = read("chen_vien_thuoc", false)
    @do_chinh_xac_lo = read("do_chinh_xac_lo", ZSU::View.grid_scale, true).to_f
    @chieu_cao_chen = read("chieu_cao_chen", 22.5).to_f.mm
    @bo_dem_lo = read("bo_dem_lo", 1, true).to_i
    @duong_kinh_chen = read("duong_kinh_chen", 35.0).to_f.mm
    @ty_le_lo = read("ty_le_lo", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @so_luong_co_dinh = read("so_luong_co_dinh", true)
    @so_luong_ban_le = read("so_luong_ban_le", 2).to_i
    @khoang_cach_ban_le = read("khoang_cach_ban_le", 500.0).to_f.mm
    @cach_hai_dau_ban_le = read("cach_hai_dau_ban_le", 100.0).to_f.mm
    @cach_mep = read("cach_mep", 22.5).to_f.mm
    @danh_dau_lo_khoan = read("danh_dau_lo_khoan", true)
    @lo_khoan_cach_nhau = read("lo_khoan_cach_nhau", 48.0).to_f.mm
    @lo_khoan_cach_tam_chen = read("lo_khoan_cach_tam_chen", 5.5).to_f.mm
    @bu_tru_khoan = read("bu_tru_khoan", (@do_chinh_xac_lo - 1.0) * 10, true).to_f.mm
    @layer_khoan_moi_ban_le = read("layer_khoan_moi_ban_le", "ABF_D3")
    @danh_dau_loai = read("danh_dau_loai", true)
    @kieu_danh_dau = read("kieu_danh_dau", "cham")
    @duong_kinh_cham = read("duong_kinh_cham", 3).to_f.mm
    @chieu_dai_gach = read("chieu_dai_gach", 16).to_f.mm
    @chieu_cao_chu = read("chieu_cao_chu", 20).to_f.mm
    @mau_ban_le_a = read("mau_ban_le_a", "255, 0, 0")
    @mau_ban_le_b = read("mau_ban_le_b", "0, 255, 0")
    @mau_ban_le_c = read("mau_ban_le_c", "0, 0, 255")
    @layer_danh_dau_loai = read("layer_danh_dau_loai", "ABF_KH")
    @khoan_moi_hong = read("khoan_moi_hong", false)
    @lo_cach_nhau_hong = read("lo_cach_nhau_hong", 32).to_f.mm
    @cach_mep_hong = read("cach_mep_hong", 37).to_f.mm
    @instance_khoan_hong = read("instance_khoan_hong", "ABF_KM")
    @layer_khoan_hong = read("layer_khoan_hong", "ABF_D3")
    @danh_dau_huong_mo = read("danh_dau_huong_mo", true)
    @sai_so_lo = read("sai_so_lo", @bo_dem_lo - 8, true).to_f.mm
    @dung_net_dung_danh_dau = read("dung_net_dung_danh_dau", false)
    @net_danh_dau = read("net_danh_dau", "Dash")
    @instance_danh_dau = read("instance_danh_dau", "")
    @layer_danh_dau = read("layer_danh_dau", "ABF_HM")
    @alt_mode = false
    @alt_parent = nil
    @presets = read("presets", nil)
    @cached_perpendicular_boards = nil
    @cached_opposing_faces = nil
    @cached_hinge_data = nil
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Thống kê" => {
        thong_ke_ban_le: [:switch, "Thống kê bản lề"],
        ten_hien_thi_ban_le: [:text, "Tên hiển thị", :thong_ke_ban_le],
      },
      "Bản lề" => {
        loai_ban_le: [:select, "Loại bản lề",
                      { "Bản lề A" => "Loại A", "Bản lề B" => "Loại B",
                        "Bản lề C" => "Loại C", "Tự động" => "Tự động" }],
        instance_ban_le: [:text, "Instance"],
        layer_ban_le: [:text, "Layer"],
      },
      "Tránh đợt" => {
        tu_dong_tranh_dot: [:switch, "Tự động tránh đợt"],
        dot_cach_toi_da: [:mm, "Đợt cách tối đa", :tu_dong_tranh_dot, 0],
      },
      "Chén" => {
        chen_vien_thuoc: [:switch, "Chén viên thuốc"],
        chieu_cao_chen: [:mm, "Chiều cao chén", :chen_vien_thuoc, 0],
        duong_kinh_chen: [:mm, "Đường kính chén"],
      },
      "Số lượng" => {
        so_luong_co_dinh: [:switch, "Số lượng cố định"],
        so_luong_ban_le: [:raw, "Số lượng bản lề", :so_luong_co_dinh, 0],
        khoang_cach_ban_le: [:mm, "Khoảng cách", -> { !@so_luong_co_dinh }],
        cach_hai_dau_ban_le: [:mm, "Cách hai đầu"],
        cach_mep: [:mm, "Cách mép"],
      },
      "Đánh dấu lỗ khoan" => {
        danh_dau_lo_khoan: [:switch, "Đánh dấu lỗ khoan"],
        lo_khoan_cach_nhau: [:mm, "Lỗ cách nhau", :danh_dau_lo_khoan],
        lo_khoan_cach_tam_chen: [:mm, "Cách tâm chén", :danh_dau_lo_khoan],
        layer_khoan_moi_ban_le: [:text, "Layer", :danh_dau_lo_khoan],
      },
      "Đánh dấu loại bản lề" => {
        danh_dau_loai: [:switch, "Đánh dấu loại bản lề"],
        kieu_danh_dau: [:select, "Kiểu đánh dấu",
                        { "cham" => "Chấm", "gach" => "Gạch", "chu" => "Chữ",
                          "mau" => "Màu" }, :danh_dau_loai],
        duong_kinh_cham: [:mm, "Đường kính",
                          -> { @danh_dau_loai && @kieu_danh_dau == "cham" }, 3],
        chieu_dai_gach: [:mm, "Chiều dài",
                         -> { @danh_dau_loai && @kieu_danh_dau == "gach" }, 6],
        chieu_cao_chu: [:mm, "Chiều cao",
                        -> { @danh_dau_loai && @kieu_danh_dau == "chu" }, 3],
        mau_ban_le_a: [:color, "Màu bản lề A",
                       -> { @danh_dau_loai && @kieu_danh_dau == "mau" }],
        mau_ban_le_b: [:color, "Màu bản lề B",
                       -> { @danh_dau_loai && @kieu_danh_dau == "mau" }],
        mau_ban_le_c: [:color, "Màu bản lề C",
                       -> { @danh_dau_loai && @kieu_danh_dau == "mau" }],
        layer_danh_dau_loai: [:text, "Layer",
                              -> { @danh_dau_loai && @kieu_danh_dau != "mau" }],
      },
      "Khoan mồi hông tủ" => {
        khoan_moi_hong: [:switch, "Khoan mồi hông tủ"],
        lo_cach_nhau_hong: [:mm, "Lỗ cách nhau", :khoan_moi_hong],
        cach_mep_hong: [:mm, "Cách mép", :khoan_moi_hong],
        instance_khoan_hong: [:text, "Instance", :khoan_moi_hong],
        layer_khoan_hong: [:text, "Layer", :khoan_moi_hong],
      },
      "Đánh dấu hướng mở" => {
        danh_dau_huong_mo: [:switch, "Đánh dấu hướng mở"],
        dung_net_dung_danh_dau: [:switch, "Dùng nét dựng", :danh_dau_huong_mo],
        net_danh_dau: [:select, "Kiểu nét", {
          "Solid Basic" => "────",
          "Short dash" => "─ ─ ─",
          "Dash" => "── ──",
          "Dot" => "· · · ·",
          "Dash dot" => "── ·",
          "Dash double-dot" => "── ··",
          "Dash triple-dot" => "── ···",
          "Double-dash dot" => "── ── ·",
          "Double-dash double-dot" => "── ── ··",
          "Double-dash triple-dot" => "── ── ···",
          "Long-dash dash" => "─── ──",
          "Long-dash double-dash" => "─── ── ──",
        }, -> { @danh_dau_huong_mo && !@dung_net_dung_danh_dau }],
        layer_danh_dau: [:text, "Layer", :danh_dau_huong_mo],
      },
    )
  end
  def onMouseMove(flags, x, y, view)
    @mouse_x = x
    @mouse_y = y
    handle_ui_mouse_move(x, y, view)
    if @alt_mode
      update_alt_parent(x, y, view)
      return
    end
    ph = view.pick_helper
    ph.do_pick(x, y)
    if ph.best_picked.nil?
      clear_anchors
      view.invalidate
      return
    end
    if update_mark(x, y, view)
      view.invalidate
    end
  end
  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split("_").last.to_i
        load_preset(@presets[index]["settings"])
      end
      view.invalidate
      return
    end
    if @alt_mode
      ph = view.pick_helper
      ph.do_pick(x, y)
      parent = ph.best_picked
      erase_marks(parent) if parent
    else
      create_marks
    end
    view.invalidate
  end
  def onUserText(text, view)
    return unless danh_ban_le?
    if text.start_with?("/")
      if !@so_luong_co_dinh
        num = text[1..-1].to_l.to_mm.to_f
        return if num <= 0
        @khoang_cach_ban_le = num.mm
        write("khoang_cach_ban_le", num)
      else
        num = text[1..-1].to_i
        return if num < 1
        @so_luong_ban_le = num
        write("so_luong_ban_le", num)
      end
    else
      num = text.to_l.to_mm.to_f
      return if num < 0
      @cach_hai_dau_ban_le = num.mm
      write("cach_hai_dau_ban_le", num)
    end
    update_status
    if @active_anchor && @active_anchor[:type] == :edge && danh_ban_le?
      @cached_hinge_data = calc_hinge_data
    end
    view.invalidate if view
  end
  def onKeyDown(key, rpt, flags, view)
    return if @sb_selected_item
    if key == ALT_MODIFIER_KEY
      @alt_mode = true
      update_alt_parent(@mouse_x || 0, @mouse_y || 0, view)
      return true
    elsif key == 192
      ZSU::Settings.open_settings("ban_le")
      return true
    end
  end
  def onKeyUp(key, rpt, flags, view)
    return if @sb_selected_item
    if key == ALT_MODIFIER_KEY
      @alt_mode = false
      @alt_parent = nil
      view.invalidate
      return true
    elsif key == 9 && danh_ban_le?
      cycle_hinge_type(view)
      return true
    end
  end
  def load_preset(s)
    init_preset(:thong_ke_ban_le, s)
    init_preset(:ten_hien_thi_ban_le, s)
    init_preset(:loai_ban_le, s)
    init_preset(:instance_ban_le, s)
    init_preset(:layer_ban_le, s)
    init_preset(:tu_dong_tranh_dot, s)
    init_preset(:dot_cach_toi_da, s) { |v| v.to_f.mm }
    init_preset(:chen_vien_thuoc, s)
    init_preset(:chieu_cao_chen, s) { |v| v.to_f.mm }
    init_preset(:duong_kinh_chen, s) { |v| v.to_f.mm }
    init_preset(:so_luong_co_dinh, s)
    init_preset(:so_luong_ban_le, s) { |v| v.to_i }
    init_preset(:khoang_cach_ban_le, s) { |v| v.to_f.mm }
    init_preset(:cach_hai_dau_ban_le, s) { |v| v.to_f.mm }
    init_preset(:cach_mep, s) { |v| v.to_f.mm }
    init_preset(:danh_dau_lo_khoan, s)
    init_preset(:lo_khoan_cach_nhau, s) { |v| v.to_f.mm }
    init_preset(:lo_khoan_cach_tam_chen, s) { |v| v.to_f.mm }
    init_preset(:layer_khoan_moi_ban_le, s)
    init_preset(:danh_dau_loai, s)
    init_preset(:kieu_danh_dau, s)
    init_preset(:duong_kinh_cham, s) { |v| v.to_f.mm }
    init_preset(:chieu_dai_gach, s) { |v| v.to_f.mm }
    init_preset(:chieu_cao_chu, s) { |v| v.to_f.mm }
    init_preset(:mau_ban_le_a, s)
    init_preset(:mau_ban_le_b, s)
    init_preset(:mau_ban_le_c, s)
    init_preset(:layer_danh_dau_loai, s)
    init_preset(:khoan_moi_hong, s)
    init_preset(:lo_cach_nhau_hong, s) { |v| v.to_f.mm }
    init_preset(:cach_mep_hong, s) { |v| v.to_f.mm }
    init_preset(:instance_khoan_hong, s)
    init_preset(:layer_khoan_hong, s)
    init_preset(:danh_dau_huong_mo, s)
    init_preset(:dung_net_dung_danh_dau, s)
    init_preset(:net_danh_dau, s)
    init_preset(:instance_danh_dau, s)
    init_preset(:layer_danh_dau, s)
  end
  def getExtents
    Geom::BoundingBox.new
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    if @alt_mode
      draw_alt_parent(view)
    else
      draw_mark(view)
    end
  end
  private
  def danh_ban_le?
    !(@so_luong_co_dinh && @so_luong_ban_le == 0)
  end
  def update_status
    ZSU.status("Nhấn Tab để đổi loại bản lề. Giữ Alt để xóa bản lề cũ.")
    if danh_ban_le?
      secondary = !@so_luong_co_dinh ? "Khoảng cách [/x]: #{Sketchup.format_length(@khoang_cach_ban_le)}" : "Số lượng [/x]: #{@so_luong_ban_le}"
      ZSU.vcb("#{secondary} | Cách hai đầu", Sketchup.format_length(@cach_hai_dau_ban_le))
    else
      ZSU.vcb("", nil)
    end
  end
  def restore_transparency
    return unless defined?(@prev_transparency) && !@prev_transparency.nil?
    ZSU::Model.set_trans(@prev_transparency)
    @prev_transparency = nil
  end
  def cycle_hinge_type(view)
    loai_order = ["Bản lề A", "Bản lề B", "Bản lề C", "Tự động"]
    idx = loai_order.index(@loai_ban_le) || 0
    @loai_ban_le = loai_order[(idx + 1) % loai_order.length]
    write("loai_ban_le", @loai_ban_le)
    update_status
    view.invalidate
  end
  def clear_anchors
    @active_anchor = nil
    @anchor_points = []
    @construction_lines = []
    @cached_hinge_data = nil
    @cached_perpendicular_boards = nil
    @cached_opposing_faces = nil
    restore_hoi
  end
  def detect_hoi
    @cached_hoi = nil
    @cached_hoi_band = nil
    @cached_khoan_moi_ref = nil
    return unless @parent && @active_anchor && @active_anchor[:type] == :edge
    edge = @active_anchor[:data]
    cnc_faces = ZSU::Board.get_cnc_faces(@parent)
    all_faces = ZSU.grep_ents(@parent, :face)
    band_face = all_faces.find { |af| !cnc_faces.include?(af) && af.edges.include?(edge) }
    return unless band_face
    parent_normal = ZSU::Board.calc_normal(@parent)
    band_pts = band_face.vertices.map { |v| v.position.transform(@tr) }
    band_bb = Geom::BoundingBox.new
    band_bb.add(band_pts)
    band_center = band_face.bounds.center.transform(@tr)
    candidates = ZSU::Board.tim_van_gan_nhat(@parent, d: 20.mm)
    best_hoi = nil
    best_dist = Float::INFINITY
    edge_vec = (edge.end.position - edge.start.position).transform(@tr).normalize
    candidates.each do |g|
      g_normal = ZSU::Board.calc_normal(g) rescue next
      next unless parent_normal.dot(g_normal).abs < 0.1
      next unless g_normal.dot(edge_vec).abs < 0.1
      dist = bbox_distance(band_bb, g.bounds)
      next if dist > 5.mm
      if dist < best_dist
        best_dist = dist
        best_hoi = g
      end
    end
    return unless best_hoi
    hoi_cnc = ZSU::Board.get_cnc_faces(best_hoi)
    hoi_tr = best_hoi.transformation
    hoi_bands = ZSU.grep_ents(best_hoi, :face).reject { |f| hoi_cnc.include?(f) }
    hoi_bands = hoi_bands.select { |f| f.normal.transform(hoi_tr).normalize.dot(parent_normal).abs > 0.9 }
    @cached_hoi = best_hoi
    @cached_hoi_band = hoi_bands.min_by { |f| f.bounds.center.transform(hoi_tr).distance(band_center) }
    ZSU::Group.fix_scale(@cached_hoi)
    calc_khoan_moi_ref
  end
  def bbox_distance(bb1, bb2)
    dx = [[bb1.min.x, bb2.min.x].max - [bb1.max.x, bb2.max.x].min, 0].max
    dy = [[bb1.min.y, bb2.min.y].max - [bb1.max.y, bb2.max.y].min, 0].max
    dz = [[bb1.min.z, bb2.min.z].max - [bb1.max.z, bb2.max.z].min, 0].max
    Math.sqrt(dx ** 2 + dy ** 2 + dz ** 2)
  end
  def restore_hoi
    @cached_hoi = nil
    @cached_hoi_band = nil
    @cached_khoan_moi_ref = nil
  end
  def calc_khoan_moi_ref
    @cached_khoan_moi_ref = nil
    return unless @cached_hoi && @cached_hoi_band && @cached_hoi_band.valid?
    hoi_tr = @cached_hoi.transformation
    cnc_faces = ZSU::Board.get_cnc_faces(@cached_hoi)
    return if cnc_faces.empty?
    parent_center = @parent.bounds.center
    best_ref = nil
    best_dist = Float::INFINITY
    cnc_faces.each do |cnc_face|
      shared_edges = cnc_face.edges & @cached_hoi_band.edges
      next if shared_edges.empty?
      ref_edge = shared_edges.max_by { |e| e.length }
      next unless ref_edge
      cnc_normal = cnc_face.normal
      edge_dir = (ref_edge.end.position - ref_edge.start.position).normalize
      offset_dir = cnc_normal.cross(edge_dir).normalize
      edge_mid = Geom.linear_combination(0.5, ref_edge.start.position, 0.5, ref_edge.end.position)
      cnc_center = cnc_face.bounds.center
      offset_dir = offset_dir.reverse if (cnc_center - edge_mid).dot(offset_dir) < 0
      ref_point = edge_mid.offset(offset_dir, @cach_mep_hong)
      ref_world = ref_point.transform(hoi_tr)
      dist = parent_center.distance(ref_world)
      if dist < best_dist
        best_dist = dist
        best_ref = ref_world
      end
    end
    @cached_khoan_moi_ref = best_ref
  end
  def update_mark(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    face = ph.picked_face
    return false unless face
    tr = ph.transformation_at(0)
    parent = ph.best_picked
    return false unless parent && ZSU.is_container?(parent) && parent.transformation.to_a == tr.to_a
    ZSU::Group.fix_scale(parent)
    largest_faces = ZSU::Board.get_cnc_faces(parent)
    return false unless largest_faces.include?(face)
    if parent != @parent
      @cached_perpendicular_boards = nil
      @cached_opposing_faces = nil
      @parent = parent
    end
    @face = face
    @tr = tr
    mouse_point = ZSU::View.calc_hit_point(face, tr, x, y, view)
    return false unless mouse_point
    calculate_anchors(face, tr)
    @active_anchor = find_nearest_anchor(mouse_point)
    build_construction_lines(@active_anchor, face, tr) if @active_anchor
    detect_hoi
    @cached_hinge_data = @active_anchor && @active_anchor[:type] == :edge && danh_ban_le? ? calc_hinge_data : nil
    true
  end
  def create_marks
    return unless @construction_lines && @construction_lines.length > 0
    return unless @parent && ZSU.is_container?(@parent)
    ZSU::ABF.ensure_is_board(@parent)
    ZSU.start
    @parent = @parent.make_unique
    ZSU.commit
    parent_entities = ZSU.get_ents(@parent)
    return unless parent_entities
    if @active_anchor[:type] == :center
      create_x_mark(parent_entities)
      return
    end
    ZSU.start
    clear_old_marks(parent_entities)
    create_marking_lines(parent_entities) if @danh_dau_huong_mo
    groups = []
    if danh_ban_le?
      hinge_groups = []
      hinge_data = create_hinges(parent_entities, hinge_groups)
      groups.concat(hinge_groups)
      create_khoan_moi_hong(hinge_data, hinge_groups, groups)
    end
    ZSU.commit
    groups.each { |g| ZSU::Group.center_origin(g) if g.valid? }
  end
  def erase_marks(parent = @parent)
    return unless parent && ZSU.is_container?(parent)
    parent_entities = ZSU.get_ents(parent)
    return unless parent_entities
    ZSU.start
    clear_old_marks(parent_entities)
    ZSU.commit
  end
  def draw_mark(view)
    return unless @active_anchor && @construction_lines.length > 0
    if @active_anchor[:type] == :center
      @construction_lines.each { |line| ZSU::View.draw_lines(line, guide: true) }
      return
    end
    if @danh_dau_huong_mo
      @construction_lines.each { |line| ZSU::View.draw_lines(line, guide: true) }
    end
    draw_hinge_preview if danh_ban_le?
  end
  def calculate_anchors(face, tr)
    @anchor_points = []
    face.edges.each do |edge|
      next if danh_ban_le? && edge.length < @cach_hai_dau_ban_le * 2
      v1 = edge.start.position.transform(tr)
      v2 = edge.end.position.transform(tr)
      mid_point = Geom::Point3d.linear_combination(0.5, v1, 0.5, v2)
      @anchor_points << { point: mid_point, type: :edge, data: edge }
    end
    center = face.bounds.center.transform(tr)
    @anchor_points << { point: center, type: :center, data: face }
  end
  def find_nearest_anchor(mouse_point)
    return nil if @anchor_points.empty? || mouse_point.nil?
    @anchor_points.min_by { |anchor| anchor[:point].distance(mouse_point) }
  end
  def build_construction_lines(anchor, face, tr)
    @construction_lines = []
    if anchor[:type] == :center
      c = bbox_corners(face)
      verts = face.outer_loop.vertices.map { |v| v.position }
      nearest = c.map { |corner| verts.min_by { |v| v.distance(corner) } }
      @construction_lines << [nearest[0].transform(tr), nearest[3].transform(tr)]
      @construction_lines << [nearest[1].transform(tr), nearest[2].transform(tr)]
      return
    end
    return unless anchor[:type] == :edge
    active_anchor = anchor[:point]
    corners = bbox_corners(face)
    sides = [
      [corners[0], corners[1]],
      [corners[2], corners[3]],
      [corners[0], corners[2]],
      [corners[1], corners[3]],
    ]
    nearest = sides.min_by do |a, b|
      a_w = a.transform(tr)
      b_w = b.transform(tr)
      active_anchor.distance_to_line([a_w, b_w - a_w])
    end
    opposite = sides.find { |s| (s & nearest).empty? }
    if opposite
      verts = face.outer_loop.vertices.map { |v| v.position }
      opposite.each do |corner|
        nearest_vert = verts.min_by { |v| v.distance(corner) }
        @construction_lines << [nearest_vert.transform(tr), active_anchor]
      end
    end
  end
  def bbox_corners(face)
    bb = face.bounds
    mn = bb.min
    mx = bb.max
    dx = (mx.x - mn.x).abs
    dy = (mx.y - mn.y).abs
    dz = (mx.z - mn.z).abs
    if dz <= dx && dz <= dy
      [Geom::Point3d.new(mn.x, mn.y, mn.z),
       Geom::Point3d.new(mx.x, mn.y, mn.z),
       Geom::Point3d.new(mn.x, mx.y, mn.z),
       Geom::Point3d.new(mx.x, mx.y, mn.z)]
    elsif dy <= dx
      [Geom::Point3d.new(mn.x, mn.y, mn.z),
       Geom::Point3d.new(mx.x, mn.y, mn.z),
       Geom::Point3d.new(mn.x, mn.y, mx.z),
       Geom::Point3d.new(mx.x, mn.y, mx.z)]
    else
      [Geom::Point3d.new(mn.x, mn.y, mn.z),
       Geom::Point3d.new(mn.x, mx.y, mn.z),
       Geom::Point3d.new(mn.x, mn.y, mx.z),
       Geom::Point3d.new(mn.x, mx.y, mx.z)]
    end
  end
  def oriented_edge(face, edge)
    loop_verts = face.outer_loop.vertices
    idx_s = loop_verts.index(edge.start)
    idx_e = loop_verts.index(edge.end)
    if idx_s && idx_e && (idx_s + 1) % loop_verts.length == idx_e
      [(edge.end.position - edge.start.position).normalize, edge.start.position]
    else
      [(edge.start.position - edge.end.position).normalize, edge.end.position]
    end
  end
  def calc_thickness_vec(face)
    local_normal = face.normal
    face_vert = face.outer_loop.vertices.first
    face_vert.edges.each do |te|
      ov = te.other_vertex(face_vert)
      dir = (ov.position - face_vert.position).normalize
      if dir.dot(local_normal).abs > 0.9
        return ov.position - face_vert.position
      end
    end
    Geom::Vector3d.new(0, 0, 0)
  end
  def resolve_loai_ban_le
    return @loai_ban_le unless @loai_ban_le == "Tự động"
    return "Bản lề A" unless @cached_hoi && @cached_hoi.valid? &&
                             @cached_hoi_band && @cached_hoi_band.valid?
    d_bounds = @parent.definition.bounds
    p_bounds = @cached_hoi.definition.bounds
    t_relative = @tr.inverse * @cached_hoi.transformation
    dims = [d_bounds.width, d_bounds.height, d_bounds.depth]
    t_axis = dims.each_with_index.min_by { |v, _| v }[1]
    edge = @active_anchor[:data]
    edge_dir = (edge.end.position - edge.start.position).normalize
    axes = [Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(0, 0, 1)]
    hinge_axis = axes.each_with_index.max_by { |v, _| edge_dir.dot(v).abs }[1]
    o_axis = [0, 1, 2].find { |i| i != t_axis && i != hinge_axis }
    return "Bản lề A" unless o_axis
    pts_p_in_d = []
    [0, 1].each { |i|
      [0, 1].each { |j|
        [0, 1].each { |k|
          pt = Geom::Point3d.new(
            i == 0 ? p_bounds.min.x : p_bounds.max.x,
            j == 0 ? p_bounds.min.y : p_bounds.max.y,
            k == 0 ? p_bounds.min.z : p_bounds.max.z
          )
          pts_p_in_d << pt.transform(t_relative)
        }
      }
    }
    p_min_o = pts_p_in_d.map { |p| p.to_a[o_axis] }.min
    p_max_o = pts_p_in_d.map { |p| p.to_a[o_axis] }.max
    d_min_o = d_bounds.min.to_a[o_axis]
    d_max_o = d_bounds.max.to_a[o_axis]
    overlap = [0, [p_max_o, d_max_o].min - [p_min_o, d_min_o].max].max
    p_min_t = pts_p_in_d.map { |p| p.to_a[t_axis] }.min
    p_max_t = pts_p_in_d.map { |p| p.to_a[t_axis] }.max
    d_min_t = d_bounds.min.to_a[t_axis]
    d_max_t = d_bounds.max.to_a[t_axis]
    is_inset = p_min_t < d_min_t - 2.mm && p_max_t > d_max_t + 2.mm
    if is_inset || overlap < 2.mm
      "Bản lề C"
    elsif overlap < 12.mm
      "Bản lề B"
    else
      "Bản lề A"
    end
  end
  def point_on_face?(face, point)
    cp = face.classify_point(point)
    cp == Sketchup::Face::PointInside ||
      cp == Sketchup::Face::PointOnEdge ||
      cp == Sketchup::Face::PointOnVertex
  end
  def loai_chu(loai)
    case loai
      when "Bản lề A" then "A"
      when "Bản lề B" then "B"
      when "Bản lề C" then "C"
      else "A"
    end
  end
  def text_local_axes(edge_vec, inward_unit)
    if edge_vec.transform(@tr).z < -0.1
      [inward_unit.reverse, edge_vec.reverse]
    else
      [inward_unit, edge_vec]
    end
  end
  def mau_theo_loai(loai)
    case loai
      when "Bản lề A" then @mau_ban_le_a
      when "Bản lề B" then @mau_ban_le_b
      when "Bản lề C" then @mau_ban_le_c
      else @mau_ban_le_a
    end
  end
  def loai_ban_le_count(loai)
    case loai
      when "Bản lề A" then 1
      when "Bản lề B" then 2
      when "Bản lề C" then 3
      else 1
    end
  end
  def calc_hinge_positions(edge_start, edge_vec, edge_length, cach_hai_dau)
    range_start = edge_start.offset(edge_vec, cach_hai_dau)
    range_end = edge_start.offset(edge_vec, edge_length - cach_hai_dau)
    usable = range_start.distance(range_end)
    so_luong = [@so_luong_ban_le || 1, 1].max
    if !@so_luong_co_dinh
      kc = @khoang_cach_ban_le || 200.mm
      so_luong = usable > 0 ? [(usable / kc).round + 1, 1].max : 1
    end
    so_luong = [[so_luong, (usable / 100.mm).floor + 1].min, 1].max if so_luong > 1
    positions = if so_luong == 1
                  [Geom.linear_combination(0.5, range_start, 0.5, range_end)]
                else
                  (0...so_luong).map do |i|
                    t = i.to_f / (so_luong - 1)
                    Geom.linear_combination(1 - t, range_start, t, range_end)
                  end
                end
    [positions, range_start, range_end]
  end
  def perpendicular_boards
    return @cached_perpendicular_boards if @cached_perpendicular_boards
    parent_normal = ZSU::Board.calc_normal(@parent) rescue nil
    return [] unless parent_normal
    @cached_perpendicular_boards = []
    p_bb = @parent.bounds
    margin = [@dot_cach_toi_da, 50.mm].max
    ZSU::Model.active_entities.each do |g|
      next unless ZSU.is_container?(g)
      next if g == @parent || g.hidden?
      gb = g.bounds
      next if gb.min.x > p_bb.max.x + margin || gb.max.x < p_bb.min.x - margin ||
              gb.min.y > p_bb.max.y + margin || gb.max.y < p_bb.min.y - margin ||
              gb.min.z > p_bb.max.z + margin || gb.max.z < p_bb.min.z - margin
      next unless ZSU::Board.calc_thickness(g)
      g_normal = ZSU::Board.calc_normal(g) rescue next
      next unless parent_normal.dot(g_normal).abs < 0.1
      @cached_perpendicular_boards << g
    end
    @cached_perpendicular_boards
  end
  def opposing_faces
    return @cached_opposing_faces if @cached_opposing_faces
    parent_normal = ZSU::Board.calc_normal(@parent) rescue nil
    return [] unless parent_normal
    thickness = ZSU::Board.calc_thickness(@parent) || 0
    @cached_opposing_faces = []
    perpendicular_boards.each do |g|
      g_tr = g.transformation
      ZSU.grep_ents(g, :face).each do |adj_f|
        adj_normal = adj_f.normal.transform(g_tr).normalize
        next unless adj_normal.dot(parent_normal).abs > 0.9
        @cached_opposing_faces << { face: adj_f, tr: g_tr }
      end
    end
    @cached_opposing_faces
  end
  def check_line_clear(center_world, ev_world, half_len, opposing_faces)
    p1 = center_world.offset(ev_world, half_len)
    p2 = center_world.offset(ev_world, -half_len)
    opposing_faces.each do |fd|
      f = fd[:face]
      g_tr = fd[:tr]
      p1_local = p1.transform(g_tr.inverse).project_to_plane(f.plane)
      p2_local = p2.transform(g_tr.inverse).project_to_plane(f.plane)
      [p1_local, p2_local].each do |pt|
        return false if point_on_face?(f, pt)
      end
      p1_proj = p1_local.transform(g_tr)
      p2_proj = p2_local.transform(g_tr)
      f.edges.each do |e|
        e1 = e.start.position.transform(g_tr)
        e2 = e.end.position.transform(g_tr)
        return false if seg_intersect(p1_proj, p2_proj, e1, e2)
      end
    end
    true
  end
  def adjust_for_intersects(centers, edge_vec, range_start_c, range_end_c)
    return centers unless @tu_dong_tranh_dot
    f_normal_world = @face.normal.transform(@tr).normalize
    opp_normal_world = f_normal_world.reverse
    thickness_vec = calc_thickness_vec(@face)
    tv_world = thickness_vec.transform(@tr)
    opp_plane_pt = @face.outer_loop.vertices.first.position.transform(@tr).offset(tv_world)
    relevant = opposing_faces.select do |fd|
      adj_normal = fd[:face].normal.transform(fd[:tr]).normalize
      next false unless adj_normal.dot(opp_normal_world) < -0.9
      adj_pt = fd[:face].outer_loop.vertices.first.position.transform(fd[:tr])
      (adj_pt - opp_plane_pt).dot(opp_normal_world).abs < @dot_cach_toi_da
    end
    return centers if relevant.empty?
    half_len = 35.mm
    ev_world = edge_vec.transform(@tr).normalize
    step = 10.mm
    proj_plane = [opp_plane_pt, opp_normal_world]
    if ZSU::Method.respond_to?(:adjust_centers)
      edges_flat = []
      relevant.each do |fd|
        fd[:face].edges.each do |e|
          e1 = e.start.position.transform(fd[:tr]).project_to_plane(proj_plane)
          e2 = e.end.position.transform(fd[:tr]).project_to_plane(proj_plane)
          edges_flat.push(e1.x, e1.y, e1.z, e2.x, e2.y, e2.z)
        end
      end
      centers_flat = []
      centers.each do |c|
        w = c.transform(@tr)
        centers_flat.push(w.x, w.y, w.z)
      end
      rs = range_start_c.transform(@tr)
      re = range_end_c.transform(@tr)
      ev_a = [ev_world.x, ev_world.y, ev_world.z]
      params = [half_len, step, 1.mm,
                rs.x, rs.y, rs.z, re.x, re.y, re.z]
      result_flat = ZSU::Method.adjust_centers(
        centers_flat, ev_a, ev_a, edges_flat, params
      )
      inv = @tr.inverse
      result = []
      i = 0
      while i < result_flat.length
        result << Geom::Point3d.new(
          result_flat[i], result_flat[i + 1], result_flat[i + 2]
        ).transform(inv)
        i += 3
      end
      return result
    end
    t_range = (range_end_c - range_start_c).dot(edge_vec)
    center_ts = centers.map { |c| (c - range_start_c).dot(edge_vec) }
    result = []
    centers.each_with_index do |center, idx|
      center_world = center.transform(@tr)
      if check_line_clear(center_world, ev_world, half_len, relevant)
        result << center
        next
      end
      t = center_ts[idx]
      t_lo = idx > 0 ? center_ts[idx - 1] : 0
      t_hi = idx < centers.length - 1 ? center_ts[idx + 1] : t_range
      found = false
      max_steps = [((t - t_lo) / step).floor, ((t_hi - t) / step).floor].max
      (1..max_steps).each do |s|
        [s * step, -s * step].each do |d|
          new_t = t + d
          next if new_t <= t_lo || new_t >= t_hi
          new_center = center.offset(edge_vec, d)
          new_world = new_center.transform(@tr)
          if check_line_clear(new_world, ev_world, half_len, relevant)
            result << new_center
            found = true
            break
          end
        end
        break if found
      end
    end
    result
  end
  def create_x_mark(parent_entities)
    ZSU.start
    clear_old_marks(parent_entities)
    create_marking_lines(parent_entities)
    ZSU.commit
  end
  def clear_old_marks(parent_entities)
    parent_entities.grep(Sketchup::ConstructionLine).each do |cline|
      cline.erase! if cline.get_attribute("ZSU", "danh_dau_huong_mo")
    end
    old_ids = []
    parent_entities.grep(Sketchup::Group).each do |grp|
      next unless grp.get_attribute("ZSU", "danh_dau_huong_mo") ||
                  grp.get_attribute("ZSU", "ban_le")
      bid = grp.get_attribute("ZSU", "ban_le_id")
      old_ids << bid if bid
      grp.erase!
    end
    return if old_ids.empty?
    ZSU::Model.active_entities.each do |container|
      next unless ZSU.is_container?(container) && container.valid?
      c_ents = container.is_a?(Sketchup::Group) ? container.entities : container.definition.entities
      c_ents.grep(Sketchup::Group).each do |grp|
        next unless grp.valid?
        next unless old_ids.include?(grp.get_attribute("ZSU", "ban_le_id"))
        grp.erase!
      end
    end
  end
  def update_alt_parent(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    parent = ph.best_picked
    parent = nil unless parent && ZSU.is_container?(parent)
    return if @alt_parent == parent
    @alt_parent = parent
    view.invalidate
  end
  def draw_alt_parent(view)
    ZSU::View.highlight_board(@alt_parent, color: ZSU::View.warning_face_color) if @alt_parent
  end
  def create_marking_lines(parent_entities)
    layer = ZSU.ensure_tag(@layer_danh_dau)
    if @dung_net_dung_danh_dau
      @construction_lines.each do |line|
        p1, p2 = line
        local_p1 = p1.transform(@tr.inverse)
        local_p2 = p2.transform(@tr.inverse)
        cline = parent_entities.add_cline(local_p1, local_p2)
        if cline
          cline.layer = layer
          cline.set_attribute("ZSU", "danh_dau_huong_mo", true)
        end
      end
    else
      model = Sketchup.active_model
      if model.respond_to?(:line_styles) && model.line_styles
        style_name = @net_danh_dau || "Dash"
        style = model.line_styles[style_name]
        layer.line_style = style if style
      end
      group = parent_entities.add_group
      group.layer = layer
      group.set_attribute("ZSU", "danh_dau_huong_mo", true)
      instance_name = @instance_danh_dau
      group.name = instance_name if instance_name && !instance_name.empty?
      @construction_lines.each do |line|
        p1, p2 = line
        local_p1 = p1.transform(@tr.inverse)
        local_p2 = p2.transform(@tr.inverse)
        edge = group.entities.add_line(local_p1, local_p2)
        edge.layer = layer if edge
      end
    end
  end
  def calc_hinge_data
    local_normal = @face.normal
    cach_mep = @cach_mep || 22.mm
    cach_hai_dau = @cach_hai_dau_ban_le || 100.mm
    edge = @active_anchor[:data]
    edge_vec, edge_start = oriented_edge(@face, edge)
    inward_unit = local_normal.cross(edge_vec).normalize
    thickness_vec = calc_thickness_vec(@face)
    opp_normal = local_normal.reverse
    positions, range_start, range_end = calc_hinge_positions(
      edge_start, edge_vec, edge.length, cach_hai_dau
    )
    centers = positions.map do |pos|
      pos.offset(thickness_vec).offset(inward_unit, cach_mep)
    end
    range_start_c = range_start.offset(thickness_vec).offset(inward_unit, cach_mep)
    range_end_c = range_end.offset(thickness_vec).offset(inward_unit, cach_mep)
    centers = adjust_for_intersects(centers, edge_vec, range_start_c, range_end_c)
    { centers: centers, opp_normal: opp_normal, edge_vec: edge_vec,
      inward_unit: inward_unit, cach_mep: cach_mep }
  end
  def create_hinges(parent_entities, groups)
    data = calc_hinge_data
    banle_layer = ZSU.ensure_tag(@layer_ban_le)
    banle_name = @instance_ban_le
    loai = resolve_loai_ban_le
    batch_id = (Time.now.to_f * 1000).to_i.to_s(36)
    set_counter = 0
    data[:centers].each do |center|
      ban_le_id = "#{batch_id}#{set_counter.to_s(36)}"
      set_counter += 1
      groups << create_single_hinge(
        parent_entities, center, data[:opp_normal], data[:edge_vec],
        data[:inward_unit], banle_name, banle_layer, loai, ban_le_id
      )
    end
    data
  end
  def create_khoan_moi_hong(hinge_data, hinge_groups, groups)
    return unless @khoan_moi_hong && hinge_data
    return unless @cached_hoi && @cached_hoi.valid? && @cached_hoi_band && @cached_hoi_band.valid?
    hoi_ents = ZSU.get_ents(@cached_hoi)
    return unless hoi_ents
    hoi_tr = @cached_hoi.transformation
    hoi_inv = hoi_tr.inverse
    cnc_faces = ZSU::Board.get_cnc_faces(@cached_hoi)
    return if cnc_faces.empty?
    sample_world = hinge_data[:centers].first.transform(@tr)
    sample_hoi = sample_world.transform(hoi_inv)
    cnc_face = cnc_faces.min_by { |f| sample_hoi.distance_to_plane(f.plane).abs }
    cnc_normal = cnc_face.normal
    shared_edges = cnc_face.edges & @cached_hoi_band.edges
    ref_edge = shared_edges.max_by { |e| e.length }
    return unless ref_edge
    edge_dir = (ref_edge.end.position - ref_edge.start.position).normalize
    offset_dir = cnc_normal.cross(edge_dir).normalize
    edge_mid = Geom.linear_combination(0.5, ref_edge.start.position, 0.5, ref_edge.end.position)
    cnc_center = cnc_face.bounds.center
    offset_dir = offset_dir.reverse if (cnc_center - edge_mid).dot(offset_dir) < 0
    layer = ZSU.ensure_tag(@layer_khoan_hong)
    half_spacing = @lo_cach_nhau_hong / 2.0
    hinge_data[:centers].each_with_index do |center_local, i|
      center_world = center_local.transform(@tr)
      center_hoi = center_world.transform(hoi_inv)
      projected = center_hoi.project_to_plane(cnc_face.plane)
      pt_on_edge = projected.project_to_line([ref_edge.start.position, edge_dir])
      base = pt_on_edge.offset(offset_dir, @cach_mep_hong)
      c1 = base.offset(edge_dir, half_spacing)
      c2 = base.offset(edge_dir, -half_spacing)
      ban_le_id = hinge_groups[i]&.get_attribute("ZSU", "ban_le_id")
      group = hoi_ents.add_group
      group.name = @instance_khoan_hong
      group.layer = layer
      group.set_attribute("ZSU", "ban_le", true)
      group.set_attribute("ZSU", "ban_le_id", ban_le_id) if ban_le_id
      group.entities.add_circle(c1, cnc_normal, 1.5.mm)
      group.entities.add_circle(c2, cnc_normal, 1.5.mm)
      group.entities.each { |e| e.layer = layer }
      groups << group
    end
  end
  def draw_chen_stadium(ents, center, normal, edge_vec, radius, chieu_cao)
    half_h = chieu_cao / 2.0
    perp = normal.cross(edge_vec)
    beta = Math.asin([half_h / radius, 1.0].min)
    right_arc = ents.add_arc(center, perp, normal, radius * @ty_le_lo, -beta, beta, 12)
    left_arc = ents.add_arc(center, perp, normal, radius * @ty_le_lo, Math::PI - beta, Math::PI + beta, 12)
    line1 = ents.add_line(right_arc.last.end.position, left_arc.first.start.position)
    line2 = ents.add_line(left_arc.last.end.position, right_arc.first.start.position)
    all_edges = right_arc + [line1] + left_arc + [line2]
    points = [right_arc.first.start.position]
    current = right_arc.first.start
    all_edges.each do |e|
      if e.start == current
        current = e.end
      else
        current = e.start
      end
      points << current.position
    end
    ents.erase_entities(all_edges)
    ents.add_curve(points)
  end
  def draw_chen_stadium_preview(center, normal, edge_vec, radius, chieu_cao, color: nil)
    half_h = chieu_cao / 2.0
    perp = normal.cross(edge_vec)
    beta = Math.asin([half_h / radius, 1.0].min)
    segments = 12
    pts = []
    (0..segments).each do |i|
      angle = -beta + 2 * beta * i / segments
      pt = center.offset(perp, radius * Math.cos(angle)).offset(edge_vec, -radius * Math.sin(angle))
      pts << (@tr ? pt.transform(@tr) : pt)
    end
    (0..segments).each do |i|
      angle = (Math::PI - beta) + 2 * beta * i / segments
      pt = center.offset(perp, radius * Math.cos(angle)).offset(edge_vec, -radius * Math.sin(angle))
      pts << (@tr ? pt.transform(@tr) : pt)
    end
    ZSU::View.draw2d_polygon(pts, color: color)
  end
  def create_single_hinge(
    parent_entities, center, opp_normal, edge_vec, inward_unit, banle_name, banle_layer, loai, ban_le_id
  )
    banle_group = parent_entities.add_group
    banle_group.name = banle_name
    banle_group.layer = banle_layer
    banle_group.set_attribute("ZSU", "ban_le", true)
    banle_group.set_attribute("ZSU", "ban_le_id", ban_le_id)
    chieu_cao = @chieu_cao_chen
    radius = @duong_kinh_chen / 2.0
    if @chen_vien_thuoc && chieu_cao && chieu_cao > 0 && chieu_cao < radius * 2
      draw_chen_stadium(banle_group.entities, center, opp_normal, edge_vec, radius, chieu_cao)
    else
      banle_group.entities.add_circle(center, opp_normal, radius * @ty_le_lo + @sai_so_lo + @bu_tru_khoan)
    end
    banle_group.entities.each { |e| e.layer = banle_layer }
    if @danh_dau_lo_khoan
      khoan_moi_layer = ZSU.ensure_tag(@layer_khoan_moi_ban_le)
      nua_kc = @lo_khoan_cach_nhau / 2.0
      cach_tam = @lo_khoan_cach_tam_chen
      [nua_kc, -nua_kc].each do |x_off|
        small_center = center.offset(edge_vec, x_off).offset(inward_unit, cach_tam)
        edges = banle_group.entities.add_circle(small_center, opp_normal, 1.5.mm * @ty_le_lo, 16)
        edges.each { |e| e.layer = khoan_moi_layer }
      end
    end
    if @danh_dau_loai
      ky_hieu_layer = ZSU.ensure_tag(@layer_danh_dau_loai)
      so_ky_hieu = loai_ban_le_count(loai)
      if @kieu_danh_dau == "cham"
        spacing = 7.mm
        total_width = (so_ky_hieu - 1) * spacing
        start_offset = -total_width / 2.0
        so_ky_hieu.times do |ki|
          kh_center = center.offset(inward_unit, start_offset + ki * spacing)
          edges = banle_group.entities.add_circle(kh_center, opp_normal, @duong_kinh_cham / 2.0 * @ty_le_lo)
          edges.each { |e| e.layer = ky_hieu_layer }
        end
      elsif @kieu_danh_dau == "gach"
        half_len = @chieu_dai_gach / 2.0
        spacing = @chieu_dai_gach / 3.0
        total_width = (so_ky_hieu - 1) * spacing
        start_offset = -total_width / 2.0
        so_ky_hieu.times do |ki|
          kh_center = center.offset(inward_unit, start_offset + ki * spacing)
          p1 = kh_center.offset(edge_vec, half_len)
          p2 = kh_center.offset(edge_vec, -half_len)
          e = banle_group.entities.add_line(p1, p2)
          e.layer = ky_hieu_layer if e
        end
      elsif @kieu_danh_dau == "chu"
        local_x, local_y = text_local_axes(edge_vec, inward_unit)
        draw_char_paths(
          banle_group.entities, center, local_x, local_y, loai_chu(loai), ky_hieu_layer
        )
      elsif @kieu_danh_dau == "mau"
        banle_group.set_attribute("ZSU", "loai_ban_le", loai)
      end
    end
    if @thong_ke_ban_le
      ten = @ten_hien_thi_ban_le
      ten = "Bản lề" if ten.nil? || ten.empty?
      ZSU::ABF.set_hinge(banle_group, "#{ten} - Loại #{loai.to_s.split(" ").last}")
    end
    if @danh_dau_loai && @kieu_danh_dau == "mau" && banle_group.valid?
      edge = banle_group.entities.grep(Sketchup::Edge).first
      edge.find_faces if edge
      mat = ZSU::Material.create_color(mau_theo_loai(loai))
      banle_group.material = mat
    end
    banle_group
  end
  def draw_hinge_preview
    data = @cached_hinge_data
    return unless data
    loai = resolve_loai_ban_le
    so_ky_hieu = loai_ban_le_count(loai)
    chu = loai_chu(loai)
    mau_color = nil
    if @danh_dau_loai && @kieu_danh_dau == "mau"
      mau_color = ZSU.parse_color(mau_theo_loai(loai))
    end
    if @khoan_moi_hong && @cached_hoi && @cached_hoi.valid? && @cached_hoi_band && @cached_hoi_band.valid? && !data[:centers].empty?
      cnc_faces = ZSU::Board.get_cnc_faces(@cached_hoi)
      unless cnc_faces.empty?
        hoi_tr = @cached_hoi.transformation
        hoi_inv = hoi_tr.inverse
        sample_world = data[:centers].first.transform(@tr)
        sample_hoi = sample_world.transform(hoi_inv)
        cnc_face = cnc_faces.min_by { |f| sample_hoi.distance_to_plane(f.plane).abs }
        cnc_normal = cnc_face.normal
        shared_edges = cnc_face.edges & @cached_hoi_band.edges
        ref_edge = shared_edges.max_by { |e| e.length }
        if ref_edge
          edge_dir = (ref_edge.end.position - ref_edge.start.position).normalize
          offset_dir = cnc_normal.cross(edge_dir).normalize
          edge_mid = Geom.linear_combination(0.5, ref_edge.start.position, 0.5, ref_edge.end.position)
          cnc_center = cnc_face.bounds.center
          offset_dir = offset_dir.reverse if (cnc_center - edge_mid).dot(offset_dir) < 0
          half_spacing = @lo_cach_nhau_hong / 2.0
          data[:centers].each do |center|
            center_world = center.transform(@tr)
            center_hoi = center_world.transform(hoi_inv)
            projected = center_hoi.project_to_plane(cnc_face.plane)
            pt_on_edge = projected.project_to_line([ref_edge.start.position, edge_dir])
            base = pt_on_edge.offset(offset_dir, @cach_mep_hong)
            c1 = base.offset(edge_dir, half_spacing)
            c2 = base.offset(edge_dir, -half_spacing)
            ZSU::View.draw2d_circle(c1, cnc_normal, 1.5.mm, segments: 16, tr: hoi_tr)
            ZSU::View.draw2d_circle(c2, cnc_normal, 1.5.mm, segments: 16, tr: hoi_tr)
          end
        end
      end
    end
    data[:centers] = data[:centers].map { |c| c.offset([0, 0, @view_dpi]) } if @view_dpi != 0
    data[:centers].each do |center|
      chieu_cao = @chieu_cao_chen
      radius = @duong_kinh_chen / 2.0
      if @chen_vien_thuoc && chieu_cao && chieu_cao > 0 && chieu_cao < radius * 2
        draw_chen_stadium_preview(
          center, data[:opp_normal], data[:edge_vec],
          radius, chieu_cao, color: mau_color,
        )
      else
        ZSU::View.draw2d_circle(
          center, data[:opp_normal], radius,
          segments: 24, tr: @tr, color: mau_color,
        )
      end
      if @danh_dau_lo_khoan
        nua_kc = @lo_khoan_cach_nhau / 2.0
        cach_tam = @lo_khoan_cach_tam_chen
        [nua_kc, -nua_kc].each do |x_off|
          sc = center.offset(data[:edge_vec], x_off).offset(data[:inward_unit], cach_tam)
          ZSU::View.draw2d_circle(sc, data[:opp_normal], 1.5.mm, segments: 16, tr: @tr)
        end
      end
      if @danh_dau_loai
        if @kieu_danh_dau == "cham"
          spacing = 7.mm
          total_width = (so_ky_hieu - 1) * spacing
          start_offset = -total_width / 2.0
          so_ky_hieu.times do |ki|
            kh_center = center.offset(data[:inward_unit], start_offset + ki * spacing)
            ZSU::View.draw2d_circle(
              kh_center, data[:opp_normal], @duong_kinh_cham / 2.0, segments: 16, tr: @tr,
            )
          end
        elsif @kieu_danh_dau == "gach"
          half_len = @chieu_dai_gach / 2.0
          spacing = @chieu_dai_gach / 3.0
          total_width = (so_ky_hieu - 1) * spacing
          start_offset = -total_width / 2.0
          so_ky_hieu.times do |ki|
            kh_center = center.offset(data[:inward_unit], start_offset + ki * spacing)
            p1 = kh_center.offset(data[:edge_vec], half_len)
            p2 = kh_center.offset(data[:edge_vec], -half_len)
            ZSU::View.draw2d_lines([p1.transform(@tr), p2.transform(@tr)])
          end
        elsif @kieu_danh_dau == "chu"
          local_x, local_y = text_local_axes(data[:edge_vec], data[:inward_unit])
          preview_char_paths(center, local_x, local_y, chu)
        end
      end
    end
  end
  def char_point(center, local_x, local_y, cx, cy)
    center.offset(local_x, cx * @chieu_cao_chu).offset(local_y, cy * @chieu_cao_chu)
  end
  def draw_char_paths(ents, center, local_x, local_y, char, layer)
    CHAR_PATHS[char]&.each do |path|
      pts = path.map { |cx, cy| char_point(center, local_x, local_y, cx, cy) }
      edges = ents.add_curve(pts)
      edges.each { |e| e.layer = layer } if edges
    end
  end
  def preview_char_paths(center, local_x, local_y, char)
    CHAR_PATHS[char]&.each do |path|
      (0...path.length - 1).each do |i|
        p1 = char_point(center, local_x, local_y, path[i][0], path[i][1]).transform(@tr)
        p2 = char_point(center, local_x, local_y, path[i + 1][0], path[i + 1][1]).transform(@tr)
        ZSU::View.draw2d_lines([p1, p2])
      end
    end
  end
  def seg_intersect(a1, a2, b1, b2)
    va = a2 - a1
    vb = b2 - b1
    cross = va.cross(vb)
    return nil if cross.length < 0.001
    w = a1 - b1
    denom = cross.length ** 2
    t_a = vb.cross(w).dot(cross) / denom
    t_b = va.cross(w).dot(cross) / denom
    return nil unless (0.0..1.0).cover?(t_a) && (0.0..1.0).cover?(t_b)
    pt_a = Geom::Point3d.new(a1.x + t_a * va.x, a1.y + t_a * va.y, a1.z + t_a * va.z)
    pt_b = Geom::Point3d.new(b1.x + t_b * vb.x, b1.y + t_b * vb.y, b1.z + t_b * vb.z)
    pt_a.distance(pt_b) < 1.mm ? pt_a : nil
  end
end
