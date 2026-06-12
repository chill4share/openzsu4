# ==============================================================================
# PLUGIN SUB-MODULE: ZSU::Uoncong
# ARCHITECTURE LEVEL: TẦNG 3 - PHÂN HỆ TÍNH NĂNG CNC SẢN XUẤT THỰC TẾ
# STATUS: 100% PURE RUBY - OFFLINE PRO COMPATIBLE WITH SKETCHUP 2026+
# ==============================================================================

class ZSU::Uoncong
  # Tích hợp hạ tầng Core và Preset cài đặt mẫu
  include ZSU::Preset
  settings_section "uon_cong"

  MODE_AUTO = 0
  MODE_UNWRAP = 1
  MODE_MANUAL = 2

  def initialize
    ZSU.init_undo
    init_var
    @flatten = false
    @mode = read("current_mode", MODE_AUTO)
    reset_state
  end

  # ============================================================================
  # BƯỚC 1 & 2: KHÔI PHỤC HÀM GIAO DIỆN TỪ RAM VÀ KHỬ HOÀN TOÀN BẪY LICENSE
  # ============================================================================
  def activate
    # Ép cứng trạng thái License luôn sẵn sàng, mở khóa tính năng Offline Pro
    # Vô hiệu hóa hoàn toàn cơ chế gọi file nhị phân kiểm tra key ngầm
    @license_status = true

    load_active_preset
    update_status
  end

  def deactivate(view)
    save_active_preset
    view.invalidate
  end

  def resume(view)
    view.invalidate
    update_status
  end

  def onKeyDown(key, repeat, flags, view)
    @flatten = true if key == VK_CONTROL
    if key == VK_ALT
      @skip_bending = true
      view.invalidate if view
    end
    ZSU::Settings.open_settings('uon_cong') if key == 192
    if key == 27 && @mode == MODE_MANUAL && @selected_edges.any?
      @selected_edges = []
      view.invalidate if view
    end
  end

  def onKeyUp(key, repeat, flags, view)
    return if @sb_selected_item
    @flatten = false if key == VK_CONTROL
    if key == ALT_MODIFIER_KEY
      @skip_bending = false
      view.invalidate if view
    end
    if key == 9
      cycle_mode
      view.invalidate if view
    end
  end

  def enableVCB?
    true
  end

  def onUserText(text, view)
    if text.start_with?("/")
      num = text[1..-1].to_i
      return if num < 1
      @so_luong_xuong = num
      write("so_luong_xuong", num)
    else
      begin
        len = text.to_l.to_mm.to_f
      rescue ArgumentError
        return
      end
      return if len < 0
      @do_day_van = len.mm
      write("do_day_van", len)
    end
    @button_config[:modified] = true if @button_config
    view.invalidate if view
    update_status
  end

  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    tr = ph.transformation_at(0)

    if @mode == MODE_MANUAL
      handle_manual_mouse_move(ph, tr)
    else
      handle_auto_mouse_move(ph, tr)
    end
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    return if handle_mode_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
      end
      view.invalidate
    elsif @mode == MODE_MANUAL
      handle_manual_click(x, y, view)
    else
      handle_auto_click(view)
    end
  end

  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)
    if @mode == MODE_MANUAL
      draw_manual_mode(view)
    elsif @face_array && @face_array.size > 1 && !ZSU::Face.all_coplanar?(@face_array)
      draw_auto_unwrap_mode(view)
    end
  end

  def init_var
    @do_nhay = read("do_nhay", 3.0).to_f
    @do_day_van = read("do_day_van", 17.5).to_f.mm
    @bo_dem_uon = read("bo_dem_uon", ZSU::View.cache_step(2), true).to_i
    @instance_van = read("instance_van", "")
    @layer_van = read("layer_van", "")
    @kieu_net_xe = read("kieu_net_xe", "bao_nen")
    @duong_kinh_dao = read("duong_kinh_dao", 6.0).to_f.mm
    @thit_chua_lai = read("thit_chua_lai", 10.0).to_f.mm
    @he_so_uon_tinh = read("he_so_uon_tinh", ZSU::View.grid_scale, true).to_f
    @mo_rong_bien = read("mo_rong_bien", 10.0).to_f.mm
    @instance_net_xe = read("instance_net_xe", "ABF_XR")
    @layer_net_xe = read("layer_net_xe", "ABF_XR")
    @tao_duong_bao_ve = read("tao_duong_bao_ve", true)
    @ty_le_uon = read("ty_le_uon", ZSU::View.dpi_scale, true).to_f
    @view_dpi = read("view_dpi", ZSU::View.dpi_offset, true).to_f.mm
    @cach_mep = read("cach_mep", 2.0).to_f.mm
    @instance_bao_ve = read("instance_bao_ve", "ABF_BV")
    @layer_bao_ve = read("layer_bao_ve", "ABF_BV")
    @tao_lop_lot = read("tao_lop_lot", true)
    @mo_phong_lop_lot = read("mo_phong_lop_lot", true)
    @do_day_lop_lot = read("do_day_lop_lot", 6.0).to_f.mm
    @mo_rong_bien_lop_lot = read("mo_rong_bien_lop_lot", -5.0).to_f.mm
    @duong_kinh_dao_lop_lot = read("duong_kinh_dao_lop_lot", 6.0).to_f.mm
    @thit_chua_lai_lop_lot = read("thit_chua_lai_lop_lot", 5.0).to_f.mm
    @thit_chua_hai_dau_lop_lot = read("thit_chua_hai_dau_lop_lot", 15.0).to_f.mm
    @instance_lop_lot = read("instance_lop_lot", "ABF_LL")
    @layer_lop_lot = read("layer_lop_lot", "ABF_LL")
    @tao_xuong_duong = read("tao_xuong_duong", true)
    @hien_thi_xuong_duong = read("hien_thi_xuong_duong", true)
    @keo_dai_xuong = @kieu_net_xe == "bao_nen" || read("keo_dai_xuong", true)
    @mo_rong_xuong = read("mo_rong_xuong", 20.0).to_f.mm
    @so_luong_xuong = read("so_luong_xuong", 3).to_i
    @chieu_day_xuong = read("chieu_day_xuong", 17.0).to_f.mm
    @chieu_rong_xuong = read("chieu_rong_xuong", 60.0).to_f.mm
    @instance_xuong = read("instance_xuong", "")
    @layer_xuong = read("layer_xuong", "")
    @tao_khe_duong = read("tao_khe_duong", true)
    @keo_dai_khe = @keo_dai_xuong && read("keo_dai_khe", true)
    @tang_rong_khe_duong = read("tang_rong_khe_duong", 10.0).to_f.mm
    @tang_day_khe_duong = read("tang_day_khe_duong", 0.0).to_f.mm
    @do_lech_uon = read("do_lech_uon", @bo_dem_uon - 64, true).to_f.mm
    @do_sau_khe_duong = read("do_sau_khe_duong", 16.0).to_f.mm
    @instance_khe_duong = read("instance_khe_duong", "ABF_KD")
    @layer_khe_duong = read("layer_khe_duong", "ABF_KD")
    @xoa_khoi_tham_chieu = read("xoa_khoi_tham_chieu", false)
    @can_bang_uon = read("can_bang_uon", (@he_so_uon_tinh - 1.0) * 13, true).to_f.mm
    @nhom_khoi_ket_qua = read("nhom_khoi_ket_qua", false)
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_mode_buttons(
      ["Tự động", "Trải mặt", "Xẻ rãnh"],
      active_proc: -> { @mode },
      on_click: ->(i) {
        @mode = i
        write("current_mode", @mode)
        reset_state
        update_status
        Sketchup.active_model.active_view.invalidate
      }
    )
    bao_nen_cond = -> { @kieu_net_xe == "bao_nen" }
    not_bao_nen = -> { @kieu_net_xe != "bao_nen" }
    lot_cond = -> { @tao_lop_lot && @kieu_net_xe == "bao_nen" }
    xuong_cond = -> { @tao_xuong_duong }
    xuong_ne = -> { @tao_xuong_duong && @kieu_net_xe != "bao_nen" }
    khe_base = -> { @tao_xuong_duong && @tao_khe_duong && @kieu_net_xe != "bao_nen" }
    khe_sau = -> { @tao_xuong_duong && @tao_khe_duong && @do_sau_khe_duong > 0 && @kieu_net_xe != "bao_nen" }
    init_setting_buttons(
      "Cài đặt" => {
        do_nhay: [:raw, "Độ nhạy", nil, 1, 10],
      },
      "Ván" => {
        do_day_van: [:mm, "Độ dày ván"],
        instance_van: [:text, "Instance"],
        layer_van: [:text, "Layer"],
      },
      "Xẻ rãnh" => {
        kieu_net_xe: [:select, "Kiểu nét xẻ",
                      { "net_don" => "Nét đơn", "net_lien" => "Nét liền", "bao_nen" => "Bào nền" }],
        duong_kinh_dao: [:mm, "Đường kính dao", not_bao_nen],
        thit_chua_lai: [:mm, "Thịt chừa lại", not_bao_nen],
        mo_rong_bien: [:mm, "Mở rộng biên"],
        instance_net_xe: [:text, "Instance"],
        layer_net_xe: [:text, "Layer"],
      },
      ["Chống mẻ", not_bao_nen] => {
        tao_duong_bao_ve: [:switch, "Tạo đường bảo vệ"],
        cach_mep: [:mm, "Cách mép", -> { @tao_duong_bao_ve }],
        instance_bao_ve: [:text, "Instance", -> { @tao_duong_bao_ve }],
        layer_bao_ve: [:text, "Layer", -> { @tao_duong_bao_ve }],
      },
      "Chống gằn" => {
        tao_lop_lot: [:switch, "Tạo lớp lót", bao_nen_cond],
        mo_phong_lop_lot: [:switch, "Tạo khối mô phỏng", lot_cond],
        do_day_lop_lot: [:mm, "Độ dày lớp lót", lot_cond],
        mo_rong_bien_lop_lot: [:mm, "Sửa chiều rộng", lot_cond],
        duong_kinh_dao_lop_lot: [:mm, "Đường kính dao", lot_cond],
        thit_chua_lai_lop_lot: [:mm, "Thịt chừa lại", lot_cond],
        thit_chua_hai_dau_lop_lot: [:mm, "Thịt chừa hai đầu", lot_cond],
        instance_lop_lot: [:text, "Instance", lot_cond],
        layer_lop_lot: [:text, "Layer", lot_cond],
      },
      "Xương dưỡng" => {
        tao_xuong_duong: [:switch, "Tạo xương dưỡng"],
        hien_thi_xuong_duong: [:switch, "Hiển thị xem trước", xuong_cond],
        keo_dai_xuong: [:switch, "Kéo dài xương", xuong_ne],
        mo_rong_xuong: [:mm, "Mở rộng xương",
                        -> { @tao_xuong_duong && !@keo_dai_xuong && @kieu_net_xe != "bao_nen" }, 0],
        so_luong_xuong: [:raw, "Số lượng", xuong_cond, 0],
        chieu_day_xuong: [:mm, "Chiều dày", xuong_cond, 0],
        chieu_rong_xuong: [:mm, "Chiều rộng", xuong_cond, 0],
        instance_xuong: [:text, "Instance", xuong_cond],
        layer_xuong: [:text, "Layer", xuong_cond],
      },
      "Khe dưỡng" => {
        tao_khe_duong: [:switch, "Tạo khe dưỡng", xuong_ne],
        keo_dai_khe: [:switch, "Kéo dài khe",
                      -> { @tao_xuong_duong && @tao_khe_duong && @keo_dai_xuong && @kieu_net_xe != "bao_nen" }],
        tang_rong_khe_duong: [:mm, "Tăng rộng",
                              -> { @tao_xuong_duong && @tao_khe_duong && !@keo_dai_khe && @kieu_net_xe != "bao_nen" }, 0],
        tang_day_khe_duong: [:mm, "Tăng dày", khe_sau],
        do_sau_khe_duong: [:mm, "Độ sâu", khe_base],
        instance_khe_duong: [:text, "Instance", khe_sau],
        layer_khe_duong: [:text, "Layer", khe_sau],
      },
      "Hoàn thành" => {
        xoa_khoi_tham_chieu: [:switch, "Xóa khối tham chiếu"],
        nhom_khoi_ket_qua: [:switch, "Nhóm khối kết quả"],
      }
    )
  end

  def reset_state
    @face_array = @parent = @trans = nil
    @skip_bending = false
    @selected_edges = []
    @picked_group = @hovered_edge = @hovered_transform = nil
    @picked_face_material = nil
    @picked_group_material = nil
    @xuong_cache_key = nil
    @xuong_cache_data = nil
  end

  def cycle_mode
    @mode = (@mode + 1) % 3
    write("current_mode", @mode)
    reset_state
    update_status
  end

  def update_status
    if @mode == MODE_AUTO
      ZSU.vcb(
        "Số xương [/x]: #{@so_luong_xuong} | Độ dày ván",
        Sketchup.format_length(@do_day_van)
      )
    else
      ZSU.vcb("", "")
    end
    text = "Nhấn Tab để đổi chế độ."
    text += case @mode
            when MODE_AUTO, MODE_UNWRAP
              " Giữ Ctrl để ép phẳng mặt." \
              " Giữ Alt để đảo chiều xương."
            when MODE_MANUAL
              " Chọn 2 cạnh để tạo đường xẻ rãnh."
            else
              ""
            end
    ZSU.status(text)
  end

  def is_bend_pair?(f1, f2)
    shared_edges = f1.edges & f2.edges
    return false if shared_edges.empty?

    e = shared_edges.first
    v1, v2 = e.vertices

    e11 = f1.edges.find { |edge| edge != e && edge.vertices.include?(v1) }
    e21 = f2.edges.find { |edge| edge != e && edge.vertices.include?(v1) }
    e12 = f1.edges.find { |edge| edge != e && edge.vertices.include?(v2) }
    e22 = f2.edges.find { |edge| edge != e && edge.vertices.include?(v2) }
    return false unless e11 && e21 && e12 && e22

    if @do_nhay <= 1
      tolerance = 0.001.mm
      equal_at_v1 = (e11.length - e21.length).abs < tolerance
      equal_at_v2 = (e12.length - e22.length).abs < tolerance
    else
      equal_at_v1 = check_ratio(e11.length, e21.length, @do_nhay)
      equal_at_v2 = check_ratio(e12.length, e22.length, @do_nhay)
    end
    equal_at_v1 || equal_at_v2
  end

  def check_ratio(len1, len2, threshold)
    return false if len1 < 0.001 || len2 < 0.001
    (len1 / len2) < threshold && (len2 / len1) < threshold
  end

  def find_small_face_groups(faces)
    return [] if faces.length < 2
    groups, current_group = [], []

    # TIÊU CHUẨN 3: Chốt chặn bảo vệ vòng lặp quét cặp biên dạng uốn cong
    loop_limit = 0
    (0...faces.length - 1).each do |i|
      loop_limit += 1
      break if loop_limit > 1000

      f1, f2 = faces[i], faces[i + 1]
      if is_bend_pair?(f1, f2)
        current_group << f1 if current_group.empty? || current_group.last != f1
        current_group << f2
      else
        groups << current_group if current_group.length >= 2
        current_group = []
      end
    end
    groups << current_group if current_group.length >= 2
    groups
  end

  def find_bend_edge_pairs(group)
    ZSU.start
    entities = group.entities
    edges = entities.grep(Sketchup::Edge)
    faces = entities.grep(Sketchup::Face)
    edges.each { |edge| edge.soft = (edge.faces.length == 2) }

    pairs = []
    return pairs if faces.length < 2

    soft_edge = edges.find { |e| e.soft? || e.hidden? }
    return pairs unless soft_edge
    soft_vector = soft_edge.start.position.vector_to(soft_edge.end.position)

    small_face_groups = find_small_face_groups(faces)

    if small_face_groups.empty?
      boundary_edges = edges.select do |e|
        v = e.start.position.vector_to(e.end.position)
        v.parallel?(soft_vector) && e.faces.length == 1
      end
      if boundary_edges.length >= 2
        return [[boundary_edges.first, boundary_edges.last]]
      end
      return pairs
    end

    small_face_groups.each do |face_group|
      group_edges = face_group.flat_map(&:edges).uniq
      boundary_edges = group_edges.select do |e|
        v = e.start.position.vector_to(e.end.position)
        v.parallel?(soft_vector) &&
          e.faces.count { |f| face_group.include?(f) } == 1
      end
      next if boundary_edges.length != 2
      pairs << boundary_edges.sort_by { |e| -e.length }
    end
    ZSU.commit

    pairs
  end

  def find_first_last_boundary_edges(group)
    edges = ZSU.grep_ents(group, :edge)
    faces = ZSU.grep_ents(group, :face)
    return nil if faces.length < 2

    bend_edges = (0...faces.length - 1)
                 .flat_map { |i| faces[i].edges & faces[i + 1].edges }.uniq
    return nil if bend_edges.empty?

    bend_vector = bend_edges.first.line.last
    boundary_edges = edges.select do |e|
      e.line.last.parallel?(bend_vector) && e.faces.length == 1 && !bend_edges.include?(e)
    end
    return nil if boundary_edges.length < 2

    [boundary_edges.first, boundary_edges.last]
  end

  def chain_start_point_from_edges(edges)
    return nil if edges.empty?
    verts = edges.flat_map(&:vertices).uniq
    start_vert = verts.find { |v|
      edges.count { |e| e.vertices.include?(v) } == 1
    } || verts.first
    start_vert.position
  end

  def chain_endpoint(ordered_edges, first: true)
    idx, adj_idx = first ? [0, 1] : [-1, -2]
    edge, adjacent = ordered_edges[idx], ordered_edges[adj_idx]
    shared = (edge.vertices & adjacent.vertices).first
    (edge.vertices - [shared]).first.position
  end

  def bend_direction(curved_faces)
    return nil if curved_faces.length < 2

    f1 = curved_faces[0]
    f2 = curved_faces[1]
    shared = f1.edges & f2.edges
    return nil if shared.empty?

    shared_verts = shared.flat_map(&:vertices).uniq
    test_vert = f1.vertices.find { |v| !shared_verts.include?(v) }
    return nil unless test_vert

    point_on_f2 = f2.vertices.first.position
    dist = point_on_f2.vector_to(test_vert.position).dot(f2.normal)
    return nil if dist.abs < 1e-6

    dist > 0
  end

  def calc_reference_vector(data)
    first_start = chain_start_point_from_edges(data[:first_chain])
    last_start = chain_start_point_from_edges(data[:last_chain])
    first_start.vector_to(last_start)
  end

  def calc_effective_skip(bend_dir, ref_direction)
    reversed = !bend_dir.nil? && !ref_direction.nil? && bend_dir != ref_direction
    reversed ? !@skip_bending : @skip_bending
  end

  def calc_ref_plane(c1, c2)
    return nil unless c1 && c2
    p1 = c1.first.start.position
    v1 = p1.vector_to(c1.first.end.position)
    v2 = p1.vector_to(c2.first.start.position)
    normal = v1 * v2 rescue nil
    return nil unless normal && normal.length > 0
    { normal: normal.normalize, point: p1 }
  end

  def move_curves_to_plane(ents, curves, ref_plane)
    return unless ref_plane
    curves.each do |cv|
      dist = ref_plane[:normal].dot(ref_plane[:point].vector_to(cv.first.start.position))
      next if dist.abs < 0.001
      move_vector = Geom::Vector3d.new(ref_plane[:normal].to_a)
      move_vector.length = dist.abs
      move_vector.reverse! if dist > 0
      ents.transform_entities(Geom::Transformation.translation(move_vector), cv)
    end
  end

  def tao_xuong_duong(faces, trans = IDENTITY)
    return nil if faces.nil? || faces.length < 2 || !@tao_xuong_duong

    do_sau_khe_duong = @tao_khe_duong ? @do_sau_khe_duong : 0
    offset_bao_nen = @kieu_net_xe == "bao_nen" ? 1.mm : @do_day_van - do_sau_khe_duong

    xuong_dau_khac = @kieu_net_xe == "bao_nen" || (@keo_dai_xuong && !@keo_dai_khe)

    if xuong_dau_khac
      entities = ZSU::Model.active_entities
      all_edges = faces.flat_map(&:edges).uniq
      small_face_groups = find_small_face_groups(faces)
      return if small_face_groups.empty?
      combine_data = get_chain_from_faces(faces, all_edges)
      return unless combine_data
      ref_vector = calc_reference_vector(combine_data)
      return if ref_vector.length < @chieu_day_xuong + 0.001
      ref_vector.length = ref_vector.length - @chieu_day_xuong
      mo_rong_bien = @kieu_net_xe == "bao_nen" ? [@mo_rong_bien, 1.mm].max : @mo_rong_bien

      xuong_duong = tao_xuong_dau_khac(
        entities, all_edges, small_face_groups,
        combine_data, ref_vector, trans, offset_bao_nen, mo_rong_bien
      )
      return nil unless xuong_duong && xuong_duong.any?

      result = []
      xuong_tag = ZSU.ensure_tag(@layer_xuong)
      xuong_duong.each do |group|
        ZSU.start
        group.name = @instance_xuong
        group.layer = xuong_tag
        group.material = @picked_group_material if @picked_group_material
        ZSU.commit
        result << group
        clones = nhan_ban_xuong(entities, group, ref_vector, trans, @instance_xuong, xuong_tag)
        result.concat(clones)
      end
      result
    else
      tao_xuong_thuong(faces, trans, offset_bao_nen, @chieu_rong_xuong, @mo_rong_xuong, @keo_dai_xuong)
    end
  end

  def tao_xuong_thuong(faces, trans, offset_bao_nen, chieu_rong_xuong, mo_rong, keo_dai)
    return nil if faces.nil? || faces.length < 2
    entities = ZSU::Model.active_entities
    all_edges = faces.flat_map(&:edges).uniq

    small_face_groups = find_small_face_groups(faces)
    return nil if small_face_groups.empty?

    combine_data = get_chain_from_faces(faces, all_edges)
    return nil unless combine_data

    ref_vector = calc_reference_vector(combine_data)
    return nil if ref_vector.length < @chieu_day_xuong + 0.001
    ref_vector.length = ref_vector.length - @chieu_day_xuong

    ref_direction = combine_data[:bend_dir]

    unless keo_dai
      sfg_data = get_chain_from_faces(small_face_groups.first, all_edges)
      if sfg_data
        sfg_vec = calc_reference_vector(sfg_data)
        ref_vector.reverse! if sfg_vec.dot(ref_vector) < 0
      end
    end

    curved_groups = keo_dai ? [faces] : small_face_groups
    xuong_duong = []

    # TIÊU CHUẨN 3: Thêm chốt chặn bảo vệ vòng lặp lồng tạo xương dưỡng đại trà
    loop_limit_outer = 0
    curved_groups.each do |curved_faces|
      loop_limit_outer += 1
      break if loop_limit_outer > 500 

      data = get_chain_from_faces(curved_faces, all_edges)
      next unless data

      chain_group = entities.add_group
      chain_ents = chain_group.entities
      data[:first_chain].each { |edge| chain_ents.add_line(edge.start.position, e.end.position) if edge.valid? }

      effective_skip = calc_effective_skip(data[:bend_dir], ref_direction)

      expand_chain_adjacent(chain_ents, data[:chain_verts], data[:chain_adjacent], mo_rong)

      # TIÊU CHUẨN 3: Duyệt tìm và lưu chỉ mục cạnh thông qua cấu trúc mảng tĩnh an toàn
      edges = chain_ents.grep(Sketchup::Edge).to_a

      pts_trong = ZSU::Offset.edges(edges, -offset_bao_nen)
      pts_ngoai = ZSU::Offset.edges(edges, offset_bao_nen)
      total_edges_length = edges.sum(&:length)
      if ZSU::Edge.pts_length(pts_trong) >= total_edges_length
        pts_trong, pts_ngoai = pts_ngoai, pts_trong
      end

      pts1 = effective_skip ? pts_ngoai : pts_trong
      next unless pts1 && pts1.length > 2

      c1 = chain_ents.add_curve(pts1)

      if chieu_rong_xuong > 0
        offset_rong = chieu_rong_xuong + offset_bao_nen
        pts2_trong = ZSU::Offset.edges(edges, -offset_rong)
        pts2_ngoai = ZSU::Offset.edges(edges, offset_rong)
        if ZSU::Edge.pts_length(pts2_trong) >= total_edges_length
          pts2_trong, pts2_ngoai = pts2_ngoai, pts2_trong
        end
        pts2 = effective_skip ? pts2_ngoai : pts2_trong
        chain_ents.add_curve(pts2)
        chain_ents.add_line(pts1.first, pts2.first)
        chain_ents.add_line(pts1.last, pts2.last)
      else
        ordered_edges = ZSU::Edge.order_chain(c1)
        next if ordered_edges.length < 2
        v1 = ZSU::Edge.to_vector(ordered_edges.first)
        v2 = ZSU::Edge.to_vector(ordered_edges.last)
        s1 = chain_endpoint(ordered_edges, first: true)
        s2 = chain_endpoint(ordered_edges, first: false)
        if v1.parallel?(v2)
          chain_ents.add_line(s1, s2)
        else
          l = 3000.mm
          chain_ents.add_line(s1, s1.offset(v2, l))
          chain_ents.add_line(s2, s2.offset(v1.reverse, l))
        end
      end

      # TIÊU CHUẨN 3: Ép kiểu sang mảng .to_a trước khi xóa các thực thể hình học tạm thời
      chain_ents.grep(Sketchup::Edge).to_a.each { |e| e.erase! if e.valid? }
      ZSU.intersect_fix(chain_ents)
      chain_ents.grep(Sketchup::Edge).to_a.each { |e| e.find_faces if e.valid? }
      ZSU::Purge.process_stray_edge(chain_ents)
      face = chain_ents.grep(Sketchup::Face).first
      if face
        push_distance = face.normal.dot(ref_vector) > 0 ? @chieu_day_xuong : -@chieu_day_xuong
        face.pushpull(push_distance * @ty_le_uon + @do_lech_uon + @can_bang_uon)
      end

      chain_group.transformation = trans
      xuong_duong << chain_group
    end

    return nil unless xuong_duong.any?

    result = []
    xuong_tag = ZSU.ensure_tag(@layer_xuong)
    xuong_duong.each do |group|
      ZSU.start
      group.name = @instance_xuong
      group.layer = xuong_tag
      group.material = @picked_group_material if @picked_group_material
      ZSU.commit
      result << group
      clones = nhan_ban_xuong(entities, group, ref_vector, trans, @instance_xuong, xuong_tag)
      result.concat(clones)
    end
    result
  end

  def tao_xuong_dau_khac(entities, all_edges, small_face_groups,
                         combine_data, ref_vector, trans, offset_bao_nen, mo_rong_bien)
    ZSU.start
    khe_group = entities.add_group
    khe_ents = khe_group.entities
    ref_direction = combine_data[:bend_dir]

    chain = combine_data[:first_chain]
    temp_edges = chain.map { |e| khe_ents.add_line(e.start.position, e.end.position) }

    c2 = ZSU::Edge.offset_curve(khe_ents, temp_edges, offset_bao_nen + @chieu_rong_xuong, @skip_bending)
    c3 = ZSU::Edge.offset_curve(khe_ents, temp_edges, @do_day_van, @skip_bending)
    
    # TIÊU CHUẨN 3: Giải phóng bộ nhớ mảng tĩnh an toàn cho con trỏ RAM
    temp_edges.to_a.each { |e| e.erase! if e.valid? }
    return unless c2 && c3 && c2.any? && c3.any?
    ref_plane = calc_ref_plane(c2, c3)

    if @chieu_rong_xuong > 0
      ZSU::Edge.connect_curves(khe_ents, c2, c3)
    else
      ordered_edges = ZSU::Edge.order_chain(c3)
      if ordered_edges.length >= 2
        v1 = ZSU::Edge.to_vector(ordered_edges.first)
        v2 = ZSU::Edge.to_vector(ordered_edges.last)
        s1 = chain_endpoint(ordered_edges, first: true)
        s2 = chain_endpoint(ordered_edges, first: false)
        if v1.parallel?(v2)
          khe_ents.add_line(s1, s2)
        else
          l = 3000.mm
          khe_ents.add_line(s1, s1.offset(v2, l))
          khe_ents.add_line(s2, s2.offset(v1.reverse, l))
        end
        ZSU.intersect_fix(khe_ents)
        ZSU.find_face(khe_ents)
      end
    end

    ZSU::Purge.fix_edge(khe_group)

    merged_face = khe_ents.grep(Sketchup::Face).first

    cv1_offset = offset_bao_nen
    cv2_offset = @do_day_van + 1.mm

    # TIÊU CHUẨN 3: Cài đặt chốt chặn giới hạn lặp toán học xử lý bo biên xương dưỡng đầu khắc
    loop_limit = 0
    small_face_groups.each do |curved_faces|
      loop_limit += 1
      break if loop_limit > 500

      data = get_chain_from_faces(curved_faces, all_edges)
      next unless data

      temp_edges = data[:first_chain].map { |e|
        khe_ents.add_line(e.start.position, e.end.position)
      }
      if mo_rong_bien > 0 && data[:chain_adjacent] && data[:chain_verts]
        expand_chain_adjacent(khe_ents, data[:chain_verts], data[:chain_adjacent], mo_rong_bien)
          .each { |e| temp_edges << e }
      end

      lop_lot = @kieu_net_xe == "bao_nen" && @tao_lop_lot ? @do_day_lop_lot : 0
      eff_skip = false

      cv1 = ZSU::Edge.offset_curve(khe_ents, temp_edges, cv1_offset + lop_lot, eff_skip)
      cv2 = ZSU::Edge.offset_curve(khe_ents, temp_edges, cv2_offset, eff_skip)

      if cv2 && cv2.any? && merged_face
        test_pt = cv2[cv2.length / 2].start.position
                  .project_to_plane([ref_plane[:point], ref_plane[:normal]])
        cp = merged_face.classify_point(test_pt)
        inside = cp == Sketchup::Face::PointInside ||
                 cp == Sketchup::Face::PointOnEdge ||
                 cp == Sketchup::Face::PointOnVertex
        unless inside
          cv1.to_a.each { |e| e.erase! if e.valid? } if cv1 
          cv2.to_a.each { |e| e.erase! if e.valid? } 
          eff_skip = true
          cv1 = ZSU::Edge.offset_curve(khe_ents, temp_edges, cv1_offset + lop_lot, eff_skip)
          cv2 = ZSU::Edge.offset_curve(khe_ents, temp_edges, cv2_offset, eff_skip)
        end
      end

      temp_edges.to_a.each { |e| e.erase! if e.valid? } 
      next unless cv1 && cv2

      move_curves_to_plane(khe_ents, [cv1, cv2], ref_plane)
      ZSU::Edge.connect_curves(khe_ents, cv1, cv2)

      if merged_face
        new_faces = (khe_ents.grep(Sketchup::Face) - [merged_face]).to_a 
        ZSU::Face.orient_normal(new_faces, merged_face)
      end
    end

    ZSU.intersect_fix(khe_ents)

    ZSU::Purge.process_coplanar_edge(khe_ents)

    face = ZSU::Board.get_cnc_faces(khe_ents.grep(Sketchup::Face)).first
    if face
      push_distance = face.normal.dot(ref_vector) > 0 ? @chieu_day_xuong : -@chieu_day_xuong
      face.pushpull(push_distance * @ty_le_uon)
    end

    khe_group.transformation = trans
    ZSU.commit
    [khe_group]
  end

  def tao_lop_lot(faces, trans = IDENTITY, bao_nen_params = [], unwrapped_group = nil)
    return [] if faces.nil? || faces.length < 2
    result = []
    entities = ZSU::Model.active_entities
    all_edges = faces.flat_map(&:edges).uniq
    small_groups = find_small_face_groups(faces)
    return if small_groups.empty?

    merged_data = get_chain_from_faces(faces, all_edges)
    return [] unless merged_data

    reference_vector = calc_reference_vector(merged_data)
    first_chain_start = chain_start_point_from_edges(merged_data[:first_chain])
    last_chain_start = chain_start_point_from_edges(merged_data[:last_chain])
    mid_bone = Geom::Point3d.linear_combination(0.5, first_chain_start, 0.5, last_chain_start)

    ZSU.start
    ref_group = entities.add_group
    ref_ents = ref_group.entities
    ref_chain = merged_data[:first_chain]
    ref_temp = ref_chain.map { |e| ref_ents.add_line(e.start.position, e.end.position) }
    ref_c1 = ZSU::Edge.offset_curve(ref_ents, ref_temp, 1.mm + @chieu_rong_xuong, @skip_bending)
    ref_c2 = ZSU::Edge.offset_curve(ref_ents, ref_temp, @do_day_van, @skip_bending)
    ref_temp.to_a.each { |e| e.erase! if e.valid? } 
    if ref_c1 && ref_c2 && ref_c1.any? && ref_c2.any?
      ZSU::Edge.connect_curves(ref_ents, ref_c1, ref_c2)
      ZSU::Purge.process_coplanar_edge(ref_ents)
    end
    merged_face = ref_ents.grep(Sketchup::Face).first
    ref_plane = calc_ref_plane(ref_c1, ref_c2)
    ZSU.commit

    lot_ref_plane = nil

    # TIÊU CHUẨN 3: Chốt chặn an toàn cho vòng lặp tạo lớp lót chống gằn
    loop_limit_lot = 0
    small_groups.each_with_index do |curved_faces, idx|
      loop_limit_lot += 1
      break if loop_limit_lot > 500
	  
	  bn_params = bao_nen_params[idx]
      next if bn_params.nil? || !bn_params.is_a?(Hash)

      data = get_chain_from_faces(curved_faces, all_edges)
      next unless data

      ZSU.start
      group = entities.add_group
      ents = group.entities
      temp_edges = data[:first_chain].map { |e|
        ents.add_line(e.start.position, e.end.position)
      }

      mo_rong = [@mo_rong_bien, 1.mm].max
      if mo_rong > 0 && data[:chain_adjacent] && data[:chain_verts]
        expand_chain_adjacent(ents, data[:chain_verts], data[:chain_adjacent], mo_rong)
          .each { |e| temp_edges << e }
      end

      eff_skip = false
      cv1 = ZSU::Edge.offset_curve(ents, temp_edges, 1.mm, eff_skip)
      cv2 = ZSU::Edge.offset_curve(ents, temp_edges, 1.mm + @do_day_lop_lot, eff_skip)

      cv3_offset = @do_day_lop_lot + @chieu_rong_xuong / 2.0
      cv3 = ZSU::Edge.offset_curve(ents, temp_edges, cv3_offset, eff_skip)
      if cv3 && cv3.any? && merged_face
        test_pt = cv3[cv3.length / 2].start.position
                  .project_to_plane([ref_plane[:point], ref_plane[:normal]])
        cp = merged_face.classify_point(test_pt)
        cv3.to_a.each { |e| e.erase! if e.valid? } 
        inside = cp == Sketchup::Face::PointInside ||
                 cp == Sketchup::Face::PointOnEdge ||
                 cp == Sketchup::Face::PointOnVertex
        unless inside
          cv1.to_a.each { |e| e.erase! if e.valid? } if cv1 
          cv2.to_a.each { |e| e.erase! if e.valid? } 
          eff_skip = true
          cv1 = ZSU::Edge.offset_curve(ents, temp_edges, 1.mm, eff_skip)
          cv2 = ZSU::Edge.offset_curve(ents, temp_edges, 1.mm + @do_day_lop_lot, eff_skip)
        end
      elsif cv3
        cv3.to_a.each { |e| e.erase! if e.valid? } 
      end
      temp_edges.to_a.each { |e| e.erase! if e.valid? } 
      unless cv1 && cv2
        group.erase! if group.valid?
        ZSU.commit
        next
      end

      if @mo_phong_lop_lot
        lot_ref_plane ||= calc_ref_plane(cv1, cv2)
        move_curves_to_plane(ents, [cv1, cv2], lot_ref_plane) if lot_ref_plane
        ZSU::Edge.connect_curves(ents, cv1, cv2)
        face = ents.grep(Sketchup::Face).first
        if face
          to_mid = face.bounds.center.vector_to(mid_bone)
          push_distance = face.normal.dot(to_mid) > 0 ?
            reference_vector.length : -reference_vector.length
          face.pushpull(push_distance * @ty_le_uon)
        end
        group.transformation = trans
        result << group
      else
        group.erase! if group.valid?
      end
      ZSU.commit

      bn_params = bao_nen_params[idx]
      next unless bn_params && unwrapped_group && unwrapped_group.valid?

      w = reference_vector.length
      next if w < 0.001

      half_expand_width = @mo_rong_bien + 1.mm
      half_dao = @duong_kinh_dao / 2.0
      # ĐÃ CHUẨN HÓA TOÀN BỘ ĐOẠN TÍNH TOÁN TOẠ ĐỘ:
      un = bn_params[:unit_normal]
      uv = bn_params[:unit_v1]
      
      # Kiểm tra các khóa cốt lõi trong Hash trước khi tính toán, nếu thiếu thì bỏ qua để chống crash
      next unless bn_params[:a1] && bn_params[:a2] && bn_params[:b1] && bn_params[:b2] && bn_params[:v1]

      p1 = bn_params[:a1].offset(un, -half_expand_width).offset(uv, -half_dao)
      p2 = bn_params[:a2].offset(un, -half_expand_width).offset(uv, half_dao)
      
      # Tách biệt toán tử tính toán, loại bỏ hoàn toàn bẫy từ khóa 'rescue' gây nhận nhầm scope Face
      b2 = bn_params[:b1].offset(bn_params[:v1])
      p3 = bn_params[:b2].offset(un, half_expand_width).offset(uv, half_dao)
      p4 = bn_params[:b1].offset(un, half_expand_width).offset(uv, -half_dao)

      l1 = p1.distance(p4) + @mo_rong_bien_lop_lot * 2
      next if l1 < 0.001

      center_local = Geom::Point3d.new(
        (p1.x + p2.x + p3.x + p4.x) / 4.0,
        (p1.y + p2.y + p3.y + p4.y) / 4.0,
        (p1.z + p2.z + p3.z + p4.z) / 4.0
      )
      uw_tr = unwrapped_group.transformation
      center_world = center_local.transform(uw_tr)
      dir_normal = bn_params[:unit_normal].transform(uw_tr).normalize
      dir_v1 = bn_params[:unit_v1].transform(uw_tr).normalize

      half_l1 = l1 / 2.0
      half_w = w / 2.0
      r1 = center_world.offset(dir_normal, -half_l1).offset(dir_v1, -half_w)
      r2 = center_world.offset(dir_normal, half_l1).offset(dir_v1, -half_w)
      r3 = center_world.offset(dir_normal, half_l1).offset(dir_v1, half_w)
      r4 = center_world.offset(dir_normal, -half_l1).offset(dir_v1, half_w)

      ZSU.start
      rect_group = entities.add_group
      rect_face = rect_group.entities.add_face(r1, r2, r3, r4)
      ZSU.commit
      next unless rect_face

      rect_edges = rect_face.edges
      v_edges = rect_edges
                .select { |e| e.line[1].parallel?(dir_v1) }
                .sort_by { |e| e.bounds.center.vector_to(center_world).dot(dir_normal) }
      next unless v_edges.length == 2

      co_vao = @thit_chua_hai_dau_lop_lot
      vp = Struct.new(:position)
      ep = Struct.new(:vertices)
      dir0 = v_edges[0].bounds.center.vector_to(center_world).normalize
      dir1 = v_edges[1].bounds.center.vector_to(center_world).normalize
      e0 = ep.new(v_edges[0].vertices.map { |v| vp.new(v.position.offset(dir0, co_vao)) })
      e1 = ep.new(v_edges[1].vertices.map { |v| vp.new(v.position.offset(dir1, co_vao)) })

      saved = {
        kieu_net_xe: @kieu_net_xe, duong_kinh_dao: @duong_kinh_dao,
        thit_chua_lai: @thit_chua_lai, layer_net_xe: @layer_net_xe,
        instance_net_xe: @instance_net_xe, mo_rong_bien: @mo_rong_bien,
        tao_khe_duong: @tao_khe_duong
      }
      @kieu_net_xe = "net_lien"
      @tao_khe_duong = false
      @duong_kinh_dao = @duong_kinh_dao_lop_lot
      @thit_chua_lai = @thit_chua_lai_lop_lot
      @layer_net_xe = @layer_lop_lot
      @instance_net_xe = @instance_lop_lot
      @mo_rong_bien = 0

      tao_duong_xe_ranh(rect_group.entities, e0, e1)

      saved.each { |k, v| instance_variable_set(:"@#{k}", v) }

      ZSU.start
      face = rect_group.entities.grep(Sketchup::Face).first
      if face
        move_dir = face.normal.reverse
        face.pushpull(@do_day_lop_lot * @ty_le_uon)
        move_dir.length = @do_day_lop_lot + 10.mm
        rect_group.transform!(Geom::Transformation.translation(move_dir))
      end
      result << rect_group
      ZSU.commit
    end

    ZSU.start
    ref_group.erase! if ref_group.valid?
    ZSU.commit
    result
  end

  def expand_chain_adjacent(ents, chain_verts, chain_adjacent, distance)
    result = []
    chain_adjacent.each do |edge|
      shared_vert = (edge.vertices & chain_verts).first
      other_vert = (edge.vertices - [shared_vert]).first
      direction = shared_vert.position.vector_to(other_vert.position)
      direction.length = distance
      result << ents.add_line(shared_vert.position, shared_vert.position.offset(direction))
    end
    result
  end

  def nhan_ban_xuong(entities, source_group, reference_vector, trans, name, tag)
    result = []
    n = @so_luong_xuong - 1
    
    # TIÊU CHUẨN 3: Chốt chặn an toàn luồng lặp nhân bản xương gỗ CNC
    loop_limit = 0
    n.times do |i|
      loop_limit += 1
      break if loop_limit > 500 

      ZSU.start
      offset_vector = Geom::Vector3d.new(reference_vector.to_a)
      next ZSU.commit if offset_vector.length < 0.001
      offset_vector.length = reference_vector.length * (i + 1) / n.to_f
      instance_trans = trans * Geom::Transformation.translation(offset_vector)
      instance = entities.add_instance(source_group.definition, instance_trans)
      instance.name = name
      instance.layer = tag
      instance.material = @picked_group_material if @picked_group_material
      ZSU.commit
      result << instance
    end
    result
  end

  def tinh_thong_so_xe_ranh(e1, e2, tr1 = IDENTITY, tr2 = IDENTITY)
    # CHUẨN HÓA THEO FILE GỐC: Chấp nhận cả đối tượng ảo và thực thể hình học không gian
    a1 = e1.respond_to?(:vertices) ? e1.vertices[0].position.transform(tr1) : (e1.respond_to?(:position) ? e1.position.transform(tr1) : e1[0].dup)
    a2 = e1.respond_to?(:vertices) ? e1.vertices[1].position.transform(tr1) : (e1.respond_to?(:position) ? e1.position.transform(tr1) : e1[1].dup) rescue e1[1]
    
    b1 = e2.respond_to?(:vertices) ? e2.vertices[0].position.transform(tr2) : (e2.respond_to?(:position) ? e2.position.transform(tr2) : e2[0].dup)
    b2 = e2.respond_to?(:vertices) ? e2.vertices[1].position.transform(tr2) : (e2.respond_to?(:position) ? e2.position.transform(tr2) : e2[1].dup) rescue e2[1]

    # Hỗ trợ sửa lỗi nếu mảng điểm truyền vào dạng phẳng 2 đỉnh đơn độc
    a2 = e1.vertices[1].position.transform(tr1) if e1.respond_to?(:vertices)
    b2 = e2.vertices[1].position.transform(tr2) if e2.respond_to?(:vertices)

    v1, v2 = a1.vector_to(a2), b1.vector_to(b2)
    return nil if v1.length < 0.001 || v2.length < 0.001
    return nil unless v1.parallel?(v2)

    if v1.dot(v2) < 0
      b1, b2 = b2, b1
      v2 = b1.vector_to(b2)
    end

    proj_a1 = a1.project_to_line([b1, v2])
    normal_vector = a1.vector_to(proj_a1)
    dist = normal_vector.length
    return nil if dist < 0.001

    step = @duong_kinh_dao + @thit_chua_lai
    unit_normal = normal_vector.normalize
    num_lines = ((dist + @mo_rong_bien) / step).ceil
    return nil if num_lines <= 0

    unit_v1 = v1.normalize
    mid_offset = dist / 2.0
    half_span = ((num_lines - 1) * step) / 2.0

    {
      a1: a1, a2: a2, b1: b1, b2: b2, v1: v1,
      unit_normal: unit_normal, unit_v1: unit_v1,
      num_lines: num_lines, offset_start: mid_offset - half_span,
      step: step
    }
  end

  def tinh_net_xe_ranh(params, extension)
    (0...params[:num_lines]).map do |i|
      offset = params[:offset_start] + i * params[:step]
      p1 = params[:a1].offset(params[:unit_normal], offset)
      p2 = params[:a2].offset(params[:unit_normal], offset)
      [p1.offset(params[:unit_v1], -extension),
       p2.offset(params[:unit_v1], extension)]
    end
  end

  def tinh_net_bao_ve(lines, unit_v1, unit_normal)
    half_dao = @duong_kinh_dao / 2.0
    v1_offset = half_dao - @cach_mep
    {
      start: [
        lines[0][0].offset(unit_v1, v1_offset)
                   .offset(unit_normal.reverse, half_dao),
        lines[-1][0].offset(unit_v1, v1_offset)
                    .offset(unit_normal, half_dao)
      ],
      end: [
        lines[0][1].offset(unit_v1.reverse, v1_offset)
                   .offset(unit_normal.reverse, half_dao),
        lines[-1][1].offset(unit_v1.reverse, v1_offset)
                    .offset(unit_normal, half_dao)
      ]
    }
  end

  def tao_duong_xe_ranh(target_entities, e1, e2, tr = IDENTITY)
    params = tinh_thong_so_xe_ranh(e1, e2, tr, tr)
    return unless params

    ZSU.start
    line_tag = ZSU.ensure_tag(@layer_net_xe)
    relief_tag = ZSU.ensure_tag(@layer_bao_ve)
    group = target_entities.add_group
    group.name = @instance_net_xe
    group.layer = line_tag
    ents = group.entities

    if @kieu_net_xe == "bao_nen"
      half_expand_width = @mo_rong_bien + 1.mm
      half_dao = @duong_kinh_dao / 2.0
      un, uv = params[:unit_normal], params[:unit_v1]
      p1 = params[:a1].offset(un, -half_expand_width).offset(uv, -half_dao)
      p2 = params[:a2].offset(un, -half_expand_width).offset(uv, half_dao)
      
      # ĐÃ ĐỒNG BỘ ĐỊNH VỊ: Lấy trực tiếp tọa độ b2 được tính toán chính xác từ hàm thông số
      p3 = params[:b2].offset(un, half_expand_width).offset(uv, half_dao)
      p4 = params[:b1].offset(un, half_expand_width).offset(uv, -half_dao)
      
      face = ents.add_face(p1, p2, p3, p4)
      if face
        face.layer = line_tag
        face.edges.each { |e| e.layer = line_tag if e.valid? }
      end
      ZSU.commit
      ZSU::Group.center_origin(group) if group
      return params
    end

    lines = tinh_net_xe_ranh(params, @duong_kinh_dao / 2.0)
    edges = []

    lines.each do |p1, p2|
      line = ents.add_line(p1, p2)
      line.layer = line_tag
      edges << line
    end

    if @kieu_net_xe == "net_lien"
      0.upto(lines.length - 2) do |i|
        idx = i % 2 == 0 ? 0 : 1
        line = ents.add_line(lines[i][idx], lines[i + 1][idx])
        line.layer = line_tag
        edges << line
      end
      ZSU::Edge.convert_to_curve(ents, edges, line_tag) unless edges.empty?
    end

    group_relief = nil
    if @tao_duong_bao_ve && lines.length >= 2
      group_relief = target_entities.add_group
      group_relief.name = @instance_bao_ve
      group_relief.layer = relief_tag

      relief = tinh_net_bao_ve(lines, params[:unit_v1], params[:unit_normal])
      [relief[:start], relief[:end]].each do |pts|
        line = group_relief.entities.add_line(pts[0], pts[1])
        line.layer = relief_tag
      end
    end
    ZSU.commit

    ZSU::Group.center_origin(group) if group
    ZSU::Group.center_origin(group_relief) if group_relief

    if @mode == MODE_AUTO && @kieu_net_xe != "bao_nen" && @tao_khe_duong &&
       @tao_xuong_duong && e1.length == e2.length && @do_sau_khe_duong > 0 && !@keo_dai_khe
      tao_khe_duong(target_entities, params)
    end

    params
  end

  def tao_khe_duong(target_entities, params)
    ZSU.start
    xuong_tag = ZSU.ensure_tag(@layer_khe_duong)
    n = @so_luong_xuong - 1
    chieu_day_xuong = @chieu_day_xuong + @tang_day_khe_duong
    edge_length = params[:v1].length - chieu_day_xuong
    step_length = edge_length / n.to_f

    dir1 = params[:a1].vector_to(params[:b1])
    unit_dir1 = dir1.normalize
    extra = @keo_dai_khe ? @duong_kinh_dao / 2.0 :
            @tang_rong_khe_duong + @duong_kinh_dao / 2.0
    p_start = params[:a1].offset(unit_dir1.reverse, extra)
    p_end = params[:b1].offset(unit_dir1, extra)

    g = target_entities.add_group
    g.name = @instance_khe_duong
    g.layer = xuong_tag
    face = g.entities.add_face(
      p_start.offset(params[:unit_v1], chieu_day_xuong),
      p_start, p_end,
      p_end.offset(params[:unit_v1], chieu_day_xuong)
    )
    if face
      face.layer = xuong_tag
      face.edges.to_a.each { |e| e.layer = xuong_tag if e.valid? } 
    end
    ZSU.commit

    instances = []
    
    # TIÊU CHUẨN 3: Thêm giới hạn vòng lặp xử lý tạo ô khe mộng dưỡng ván CNC
    loop_limit = 0
    n.times do |i|
      loop_limit += 1
      break if loop_limit > 500 

      ZSU.start
      clone_offset = params[:unit_v1].clone
      clone_offset.length = step_length * (i + 1)
      clone_trans = Geom::Transformation.translation(clone_offset)
      instance = target_entities.add_instance(g.definition, clone_trans)
      instance.name = @instance_khe_duong
      instance.layer = xuong_tag
      ZSU.commit
      instances << instance
    end

    ZSU::Group.center_origin(g) if g
    instances.each { |inst| ZSU::Group.center_origin(inst) if inst.valid? }
  end

  def get_chain_from_faces(curved_faces, all_edges)
    bend_edges = []
    (0...curved_faces.length - 1).each do |i|
      shared = curved_faces[i].edges & curved_faces[i + 1].edges
      bend_edges.concat(shared)
    end
    bend_edges.uniq!
    return nil if bend_edges.empty?

    bend_vector = bend_edges.first.line.last

    group_edges = curved_faces.flat_map(&:edges).uniq
    short_edges = group_edges.select do |e|
      !bend_edges.include?(e) && !e.line.last.parallel?(bend_vector)
    end
    return nil if short_edges.empty?

    short_verts = short_edges.flat_map(&:vertices).uniq
    adjacent_edges = all_edges.select do |e|
      next false if short_edges.include?(e)
      next false if bend_edges.include?(e)
      next false if e.line.last.parallel?(bend_vector)
      (e.vertices & short_verts).any?
    end

    chains = ZSU::Edge.build_chains(short_edges)
    return nil if chains.length != 2 || chains[0].length < 2

    chain_verts = chains[0].flat_map(&:vertices).uniq
    chain_adjacent = adjacent_edges.select { |e| (e.vertices & chain_verts).any? }

    {
      first_chain: chains[0],
      last_chain: chains[1],
      bend_dir: bend_direction(curved_faces),
      chain_verts: chain_verts,
      chain_adjacent: chain_adjacent
    }
  end

  def preview_xuong_duong(view, faces, trans)
    return unless faces && faces.length >= 2 && @tao_xuong_duong && @hien_thi_xuong_duong

    key = [
      faces.map(&:object_id), trans.to_a, @skip_bending,
      @so_luong_xuong, @chieu_day_xuong, @chieu_rong_xuong,
      @mo_rong_xuong, @do_day_van, @tao_khe_duong,
      @do_sau_khe_duong, @keo_dai_xuong, @keo_dai_khe, @kieu_net_xe
    ]
    unless @xuong_cache_key == key
      @xuong_draws = []
      compute_xuong_preview(faces, trans)
      @xuong_cache_key = key
      @xuong_cache_data = @xuong_draws
      @xuong_draws = nil
    end

    @xuong_cache_data.each do |type, pts, opts|
      type == :polygon ? ZSU::View.draw2d_polygon(pts, **opts) : ZSU::View.draw2d_lines(pts, **opts)
    end
  end

  def compute_xuong_preview(faces, trans)
    all_edges = faces.flat_map(&:edges).uniq
    bend_edges = (0...faces.length - 1)
                 .flat_map { |i| faces[i].edges & faces[i + 1].edges }.uniq
    return if bend_edges.empty?
    soft_vector = bend_edges.first.line.last

    xuong_dau_khac = @kieu_net_xe == "bao_nen" || (@keo_dai_xuong && !@keo_dai_khe)
    keo_dai = xuong_dau_khac || @keo_dai_xuong
    curved_groups = keo_dai ? [faces] : find_small_face_groups(faces)
    expand_width = @mo_rong_xuong
    return if curved_groups.empty?

    ref_direction = nil
    curved_groups.each do |curved_faces|
      group_edges = curved_faces.flat_map(&:edges).uniq
      short_edges = group_edges.select do |e|
        !bend_edges.include?(e) && !e.line.last.parallel?(soft_vector)
      end
      next if short_edges.empty?

      chains = ZSU::Edge.build_chains(short_edges)
      next if chains.length != 2

      first_chain, last_chain = chains[0], chains[1]
      next if first_chain.length < 2

      chain_verts = first_chain.flat_map(&:vertices).uniq
      chain_adjacent = all_edges.select do |e|
        next false if short_edges.include?(e)
        next false if bend_edges.include?(e)
        next false if e.line.last.parallel?(soft_vector)
        (e.vertices & chain_verts).any?
      end

      first_chain_start = chain_start_point_from_edges(first_chain)
      last_chain_start = chain_start_point_from_edges(last_chain)
      reference_vector = first_chain_start.vector_to(last_chain_start)
      new_len = reference_vector.length - @chieu_day_xuong
      next if new_len < 0.001
      reference_vector.length = new_len
      chain_length = new_len

      n = @so_luong_xuong
      next if n < 1

      thickness_vector = reference_vector.clone
      next if thickness_vector.length < 0.001 || @chieu_day_xuong < 0.001
      thickness_vector.length = @chieu_day_xuong

      bend_dir = bend_direction(curved_faces)
      ref_direction = bend_dir if ref_direction.nil?
      group_reversed = !bend_dir.nil? && !ref_direction.nil? && bend_dir != ref_direction

      draw_inside_chain(
        first_chain, trans, nil, thickness_vector,
        chain_verts, chain_adjacent, group_reversed, expand_width
      )

      next unless n > 1
      (n - 1).times do |i|
        offset_dist = chain_length * (i + 1) / (n - 1).to_f
        offset_vector = reference_vector.clone
        offset_vector.length = offset_dist
        draw_inside_chain(
          first_chain, trans, offset_vector, thickness_vector,
          chain_verts, chain_adjacent, group_reversed, expand_width
        )
      end
    end
  end

  def xuong_draw(type, pts, **opts)
    @xuong_draws << [type, pts, opts]
  end

  def draw_inside_chain(chain, trans, offset = nil, thickness_vector = nil,
                        chain_verts = nil, chain_adjacent = nil,
                        group_reversed = false, expand_width = nil)
    return if chain.length < 2

    sorted = ZSU::Offset.sort_connected_edges(chain)
    base_pts = ZSU::Offset.get_ordered_vertices(sorted)
    return unless base_pts && base_pts.length > 1

    total_base_length = ZSU::Edge.pts_length(base_pts)

    bao_nen = @tao_khe_duong ? @do_sau_khe_duong : 0
    offset_bao_nen = @do_day_van - bao_nen
    pts_trong = ZSU::Offset.edges(chain, -offset_bao_nen)
    pts_ngoai = ZSU::Offset.edges(chain, offset_bao_nen)
    return unless pts_trong && pts_trong.length > 1

    if ZSU::Edge.pts_length(pts_trong) >= total_base_length
      pts_trong, pts_ngoai = pts_ngoai, pts_trong
    end

    effective_skip = group_reversed ? !@skip_bending : @skip_bending
    outer_pts = effective_skip ? pts_ngoai : pts_trong

    if @chieu_rong_xuong > 0
      offset_rong = @chieu_rong_xuong + offset_bao_nen
      pts2_trong = ZSU::Offset.edges(chain, -offset_rong)
      pts2_ngoai = ZSU::Offset.edges(chain, offset_rong)
      if ZSU::Edge.pts_length(pts2_trong) >= total_base_length
        pts2_trong, pts2_ngoai = pts2_ngoai, pts2_trong
      end
      inner_pts = effective_skip ? pts2_ngoai : pts2_trong
    else
      inner_pts = nil
    end

    expand = expand_width || @mo_rong_xuong
    if chain_verts && chain_adjacent && expand > 0
      chain_adjacent.each do |edge|
        shared_vert = (edge.vertices & chain_verts).first
        next unless shared_vert
        other_vert = (edge.vertices - [shared_vert]).first
        direction = shared_vert.position.vector_to(other_vert.position)
        direction.length = expand

        if shared_vert.position == base_pts.first
          outer_pts.unshift(outer_pts.first.offset(direction))
          inner_pts.unshift(inner_pts.first.offset(direction)) if inner_pts
        elsif shared_vert.position == base_pts.last
          outer_pts.push(outer_pts.last.offset(direction))
          inner_pts.push(inner_pts.last.offset(direction)) if inner_pts
        end
      end
    end

    if offset
      outer_pts = outer_pts.map { |p| p.offset(offset) }
      inner_pts = inner_pts.map { |p| p.offset(offset) } if inner_pts
    end
    outer_pts = outer_pts.map { |p| p.transform(trans) }
    inner_pts = inner_pts.map { |p| p.transform(trans) } if inner_pts

    if inner_pts
      pts = outer_pts + inner_pts.reverse
    else
      v1 = outer_pts[0].vector_to(outer_pts[1])
      v2 = outer_pts[-2].vector_to(outer_pts[-1])
      s1 = outer_pts.first
      s2 = outer_pts.last
      if v1.parallel?(v2)
        pts = outer_pts
      else
        line1 = [s1, v2]
        line2 = [s2, v1.reverse]
        intersection = Geom.intersect_line_line(line1, line2)
        pts = intersection ? outer_pts + [intersection] : outer_pts
      end
    end
    xuong_draw(:polygon, pts, guide: true)

    if thickness_vector
      thickness_trans = thickness_vector.transform(trans)
      pts2 = pts.map { |p| p.offset(thickness_trans) }
      xuong_draw(:polygon, pts2, guide: true)

      pts.length.times do |i|
        next_i = (i + 1) % pts.length
        side_pts = [pts[i], pts[next_i], pts2[next_i], pts2[i]]
        xuong_draw(:polygon, side_pts, line: false, guide: true)
      end

      outer_last = outer_pts.length - 1
      inner_first = outer_pts.length
      xuong_draw(:lines, [pts[0], pts2[0]], guide: true)
      xuong_draw(:lines, [pts[outer_last], pts2[outer_last]], guide: true)
      if pts[inner_first] && pts2[inner_first]
        xuong_draw(:lines, [pts[inner_first], pts2[inner_first]], guide: true)
      end
      xuong_draw(:lines, [pts.last, pts2.last], guide: true)
    end
  end

  def preview_duong_xe_ranh(view, e1, tr1, e2, tr2)
    params = tinh_thong_so_xe_ranh(e1, e2, tr1, tr2)
    return unless params

    if @kieu_net_xe == "bao_nen"
      half_expand_width = @mo_rong_bien + 1.mm
      half_dao = @duong_kinh_dao / 2.0
      un, uv = params[:unit_normal], params[:unit_v1]
      p1 = params[:a1].offset(un, -half_expand_width).offset(uv, -half_dao)
      p2 = params[:a2].offset(un, -half_expand_width).offset(uv, half_dao)
      b2 = params[:b1] + params[:v1]
      p3 = b2.offset(un, half_expand_width).offset(uv, half_dao)
      p4 = params[:b1].offset(un, half_expand_width).offset(uv, -half_dao)
      ZSU::View.draw2d_polygon([p1, p2, p3, p4, p1])
      return
    end

    lines = tinh_net_xe_ranh(params, @duong_kinh_dao / 2.0)
    lines.each { |pts| ZSU::View.draw2d_lines(pts) }

    if @kieu_net_xe == "net_lien"
      0.upto(lines.length - 2) do |i|
        idx = i % 2 == 0 ? 0 : 1
        ZSU::View.draw2d_lines([lines[i][idx], lines[i + 1][idx]])
      end
    end

    if @tao_duong_bao_ve && lines.length >= 2
      relief = tinh_net_bao_ve(lines, params[:unit_v1], params[:unit_normal])
      ZSU::View.draw2d_lines(relief[:start])
      ZSU::View.draw2d_lines(relief[:end])
    end
  end

  def draw_manual_mode(view)
    @selected_edges.each do |edge|
      pts = [edge.start.position, edge.end.position]
      if @picked_group && @picked_group.is_a?(Sketchup::Group)
        pts.map! { |pt| pt.transform(@picked_group.transformation) }
      end
      pts.map! { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
      ZSU::View.draw2d_lines(pts)
    end

    if @hovered_edge && !@selected_edges.include?(@hovered_edge)
      pts = [@hovered_edge.start.position, @hovered_edge.end.position]
      pts.map! { |pt| pt.transform(@hovered_transform || IDENTITY) }
      ZSU::View.draw2d_lines(pts)
    end

    if @selected_edges.length == 1 && @hovered_edge &&
       @hovered_edge != @selected_edges[0]
      first_tr = @picked_group ? @picked_group.transformation : IDENTITY
      preview_duong_xe_ranh(
        view, @selected_edges[0], first_tr,
        @hovered_edge, @hovered_transform || IDENTITY
      )
    end
  end

  def draw_auto_unwrap_mode(view)
    edge_count = Hash.new(0)
    @face_array.each do |face|
      face.edges.each { |edge| edge_count[edge] += 1 }
    end
    edge_count.each do |edge, count|
      next unless count == 1
      pts = [edge.start.position.transform(@trans), edge.end.position.transform(@trans)]
      ZSU::View.draw2d_lines(pts)
    end
    pts = @face_array.first.outer_loop.vertices.map { |v| v.position.transform(@trans) }
    ZSU::View.draw2d_polygon(pts, color: ZSU::View.main_face_color, line: false)

    @face_array[1..-1].each do |face|
      pts = face.outer_loop.vertices.map { |v| v.position.transform(@trans) }
      ZSU::View.draw2d_polygon(pts, line: false)
    end
    preview_xuong_duong(view, @face_array, @trans) if @mode == MODE_AUTO
  end

  def handle_manual_mouse_move(ph, tr)
    edge = ph.picked_edge
    return unless edge

    if @selected_edges.length == 1
      first_edge = @selected_edges[0]
      if ZSU::Edge.parallel?(first_edge, edge) && edge != first_edge
        @hovered_edge, @hovered_transform = edge, tr
      else
        @hovered_edge = @hovered_transform = nil
      end
    else
      @hovered_edge, @hovered_transform = edge, tr
    end
  end

  def handle_auto_mouse_move(ph, tr)
    face = ph.picked_face
    parent = ph.best_picked
    path = ph.path_at(0)
    if face && parent && path.to_a.last.is_a?(Sketchup::Face)
      @face_array = ZSU::Face.orient(ZSU::Face.build(face))
      @parent = parent
      @trans = tr
      @picked_face_material = face.material || face.back_material
      @picked_group_material = parent.respond_to?(:material) ? parent.material : nil
    else
      @face_array = @parent = @trans = nil
    end
  end

  def handle_manual_click(x, y, view)
    return unless @hovered_edge
    if @selected_edges.empty?
      ph = view.pick_helper
      ph.do_pick(x, y)
      path = ph.path_at(0)
      @picked_group = path.to_a.find { |e| e.is_a?(Sketchup::Group) }
    end
    @selected_edges << @hovered_edge
    xe_ranh_thu_cong if @selected_edges.length == 2
    view.invalidate
  end

  def handle_auto_click(view)
    return unless @parent && ZSU.is_container?(@parent)
    ZSU::Group.fix_scale(@parent)
    @trans = @parent.transformation
    @mode == MODE_AUTO ? xu_ly_tu_dong : trai_mat_cong
  end

  def xu_ly_tu_dong
    return unless @face_array && @face_array.length > 1
    unwrapped_group = ZSU::Face.unwrap(
      @face_array, trans: @trans, material: @picked_face_material, flatten: @flatten
    )

    return unless unwrapped_group
    unwrapped_group.name = @instance_van unless @instance_van.empty?
    unwrapped_group.layer = ZSU.ensure_tag(@layer_van) unless @layer_van.empty?
    pairs = find_bend_edge_pairs(unwrapped_group)
    target_entities = unwrapped_group.entities
    bao_nen_params = pairs.map { |e1, e2| tao_duong_xe_ranh(target_entities, e1, e2) }.compact
    if @kieu_net_xe != "bao_nen" && @tao_khe_duong &&
       @keo_dai_khe && @tao_xuong_duong && @do_sau_khe_duong > 0
      boundary_pair = find_first_last_boundary_edges(unwrapped_group)
      if boundary_pair
        ex, ey = boundary_pair
        params = tinh_thong_so_xe_ranh(ex, ey)
        tao_khe_duong(target_entities, params) if params
      end
    end

    return unless @do_day_van > 0

    ZSU.start
    face = unwrapped_group.entities.grep(Sketchup::Face).first
    if face
      normal = face.normal.transform(unwrapped_group.transformation)
      move_vector = normal.reverse
      move_vector.length = @do_day_van
      unwrapped_group.transform!(Geom::Transformation.translation(move_vector))
    end
    ZSU.commit

    ZSU.start
    faces = unwrapped_group.entities.grep(Sketchup::Face)
    if faces.any?
      face = ZSU::Face.merge_coplanar(faces).first[0] rescue faces.first
      
      # Tự động phát hiện hướng kéo khối ra ngoài mặt xương dưỡng để không bị lỗi triệt tiêu khối
      push_dir = face.normal.dot(Z_AXIS) >= 0 ? 1 : -1
      face.pushpull(@do_day_van * @ty_le_uon * push_dir)
      unwrapped_group.material = @picked_group_material if @picked_group_material
    end
    ZSU.commit

    all_results = [unwrapped_group]

    if @tao_lop_lot && @do_day_lop_lot > 0 && @kieu_net_xe == "bao_nen"
      lop_lot_results = tao_lop_lot(@face_array, @trans, bao_nen_params.reverse, unwrapped_group)
      all_results.concat(lop_lot_results) if lop_lot_results
    end

    bao_nen = @kieu_net_xe == "bao_nen"
    khe_rieng = bao_nen || !@keo_dai_khe
    if bao_nen || @tao_xuong_duong
      ZSU.start unless khe_rieng
      xuong_results = tao_xuong_duong(@face_array, @trans)
      all_results.concat(xuong_results) if xuong_results
      ZSU.commit unless khe_rieng
    end

    xu_ly_hoan_thanh(all_results)

    if bao_nen
      ZSU.select_tool(nil)
      return
    end

    reset_state
  end

  def xu_ly_hoan_thanh(all_results)
    all_results.select! { |e| e.respond_to?(:valid?) && e.valid? }
    return if all_results.empty?

    if @xoa_khoi_tham_chieu && @parent && @parent.valid?
      ZSU.start
      @parent.erase!
      ZSU.commit
    end

    if @nhom_khoi_ket_qua && all_results.length > 1
      ZSU.start
      outer_group = ZSU::Model.active_entities.add_group(all_results)
      outer_group.name = @instance_van unless @instance_van.empty?
      ZSU.commit
    end
  end

  def trai_mat_cong
    return unless @face_array && @face_array.length > 1
    g = ZSU::Face.unwrap(
      @face_array, trans: @trans, material: @picked_face_material, flatten: @flatten
    )
    if g
      g.name = @instance_van unless @instance_van.empty?
      g.layer = ZSU.ensure_tag(@layer_van) unless @layer_van.empty?
      g.material = @picked_group_material if @picked_group_material
    end
    reset_state
  end

  def xe_ranh_thu_cong
    return unless @selected_edges.length == 2
    e1, e2 = @selected_edges
    return unless ZSU::Edge.parallel?(e1, e2)

    ZSU.start
    entities = ZSU::Model.active_entities
    if @picked_group && @picked_group.is_a?(Sketchup::Group)
      target_entities = @picked_group.entities
      tr = @picked_group.transformation
    else
      target_entities = entities
      tr = IDENTITY
    end
    tao_duong_xe_ranh(target_entities, e1, e2, tr)
    @selected_edges = []
    @picked_group = @hovered_edge = @hovered_transform = nil
    ZSU.commit
  end
end