class ZSU::Taocanh
  include ZSU::Preset
  settings_section "tao_canh"
  VK_LEFT = 37
  VK_UP = 38
  VK_RIGHT = 39
  VK_DOWN = 40
  def initialize
    ZSU.init_undo
    @ip = Sketchup::InputPoint.new
    @ip1 = Sketchup::InputPoint.new
    init_var
    reset
  end
  def activate
    reset
    load_active_preset
  end
  def resume(view)
    update_status
    view.invalidate
  end
  def enableVCB?
    true
  end
  def deactivate(view)
    view.lock_inference if view.inference_locked?
    save_active_preset
    view.invalidate
  end
  def init_var
    @phuong_phap_ve = read("phuong_phap_ve", "2_diem")
    @tao_component = read("tao_component", false)
    @do_day = read("do_day", 17.5).to_f.mm
    @bo_dem_canh = read("bo_dem_canh", 1, true).to_i
    @instance = read("instance", "")
    @layer = read("layer", "")
    @ho_deu_bien_ngoai = read("ho_deu_bien_ngoai", true)
    @ho_bien_ngoai = read("ho_bien_ngoai", 2.0).to_f.mm
    @ho_trai = read("ho_trai", 2.0).to_f.mm
    @ho_phai = read("ho_phai", 2.0).to_f.mm
    @ho_tren = read("ho_tren", 2.0).to_f.mm
    @ho_duoi = read("ho_duoi", 2.0).to_f.mm
    @ho_giua_cac_canh = read("ho_giua_cac_canh", 2.0).to_f.mm
    @do_chinh_canh_do = read("do_chinh_canh_do", ZSU::View.grid_scale, true).to_f
    @sai_so_canh = read("sai_so_canh", @bo_dem_canh - 64, true).to_f.mm
    @ty_le_canh = read("ty_le_canh", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @canh_cach_mat_goc = read("canh_cach_mat_goc", 0.0).to_f.mm
    @bu_sai_canh = read("bu_sai_canh", (@do_chinh_canh_do - 1.0) * 11, true).to_f.mm
    @hien_thi_kich_thuoc = read("hien_thi_kich_thuoc", false)
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Phương pháp" => {
        phuong_phap_ve: [:select, "Phương pháp vẽ",
          {"2_diem" => "2 điểm", "3_diem" => "3 điểm",
           "tu_do" => "Tự do"}],
      },
      "Tạo component" => {
        tao_component: [:switch, "Tạo component"],
      },
      "Độ dày" => {
        do_day: [:mm, "Độ dày ván"],
      },
      "Khoảng hở" => {
        ho_deu_bien_ngoai: [:switch, "Hở đều biên ngoài"],
        ho_bien_ngoai: [:mm, "Hở biên ngoài", :ho_deu_bien_ngoai],
        ho_trai: [:mm, "Hở trái", -> { !@ho_deu_bien_ngoai }],
        ho_phai: [:mm, "Hở phải", -> { !@ho_deu_bien_ngoai }],
        ho_tren: [:mm, "Hở trên", -> { !@ho_deu_bien_ngoai }],
        ho_duoi: [:mm, "Hở dưới", -> { !@ho_deu_bien_ngoai }],
        ho_giua_cac_canh: [:mm, "Hở giữa các cánh"],
      },
      "Cách mặt gốc" => {
        canh_cach_mat_goc: [:mm, "Cánh cách mặt gốc"],
      },
      "Kích thước" => {
        hien_thi_kich_thuoc: [:switch, "Hiển thị kích thước"],
      }
    )
    @che_do_tool = read("che_do_tool", "tao_canh")
    update_mode_buttons
  end
  def load_preset(s)
    init_preset(:phuong_phap_ve, s)
    init_preset(:tao_component, s)
    init_preset(:do_day, s) { |v| v.to_f.mm }
    init_preset(:instance, s)
    init_preset(:layer, s)
    init_preset(:ho_deu_bien_ngoai, s)
    init_preset(:ho_bien_ngoai, s) { |v| v.to_f.mm }
    init_preset(:ho_trai, s) { |v| v.to_f.mm }
    init_preset(:ho_phai, s) { |v| v.to_f.mm }
    init_preset(:ho_tren, s) { |v| v.to_f.mm }
    init_preset(:ho_duoi, s) { |v| v.to_f.mm }
    init_preset(:ho_giua_cac_canh, s) { |v| v.to_f.mm }
    init_preset(:canh_cach_mat_goc, s) { |v| v.to_f.mm }
    init_preset(:hien_thi_kich_thuoc, s)
  end
  def reset
    @pts = []
    @state = 0
    @ip1.clear
    @da_ve = false
    @dao_chieu = false
    @diem_chia_tang = []
    @diem_chia_khoang = []
    @tang_ho = []
    @khoang_ho = []
    @che_do_chia = :khoang
    @diem_chia_ht = nil
    @diem_neo = nil
    @ip_valid = false
    @last_ray = nil
    @locked_normal = nil
    @normal_2_diem = nil
    @noi_bo = false
    @ds_o = nil
    @o_hover = nil
    @lich_su_chia = []
    @pts_tu_do = []
    @normal_tu_do = nil
    @pt_tu_do_ht = nil
    @che_do_tool ||= "tao_canh"
    @mat_noi_bat = nil
    @pts_noi_bat = nil
    @chia_pts = nil
    @chia_truc = nil
    @chia_truc_chon = nil
    @chia_do_sau = nil
    @chia_normal = nil
    @chia_parent = nil
    @chia_ds_mat = nil
    @chia_so_luong = nil
    @chia_canh_le ||= :giua
    update_mode_buttons
    update_status
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    if @che_do_tool == "chia_canh" && @state == 0
      unless @chia_ds_mat
        @ip.pick(view, x, y)
        chon_mat_chia(x, y, view)
      end
    else
      set_current_point(x, y, view)
    end
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
      return
    else
      if @che_do_tool == "chia_canh" && @state == 0
        if @chia_ds_mat
          xac_nhan_chia(view)
        elsif @chia_pts
          thuc_hien_chia(view)
        end
        return
      end
      if @state == 0 && @ip.valid? && @phuong_phap_ve == "3_diem"
        return if snap_to_edge(x, y, view)
      end
      picked = set_current_point(x, y, view)
      if @state == 3
        add_division_point(view) if @diem_chia_ht
      elsif picked
        if @phuong_phap_ve == "2_diem" && @state == 1
          @ip1.copy!(@ip)
          @state = 3
          @che_do_chia = :khoang
          @ds_o = compute_global_cells if @noi_bo
          @diem_neo = @pts[1] if @pts[1]
          update_mode_buttons
          update_status
        else
          increment_state
        end
      end
    end
  end
  def onReturn(view)
    if @che_do_tool == "chia_canh" && @state == 0 && @chia_ds_mat
      xac_nhan_chia(view)
      return
    end
    if @state == 4 && @phuong_phap_ve == "tu_do" && @pts_tu_do.length >= 3
      compute_free_bounding_rect
      @state = 3
      @che_do_chia = :khoang
      @ds_o = compute_global_cells if @noi_bo
      update_anchor_for_mode
      update_mode_buttons
      update_status
      view.invalidate
    elsif @state == 3
      create_rectangle
      ZSU.select_tool(nil)
    end
  end
  def onCancel(flag, view)
    if @che_do_tool == "chia_canh" && @state == 0 && @chia_ds_mat
      @chia_ds_mat = nil
      update_status
      view.invalidate
      return
    end
    if @state == 3 && @phuong_phap_ve == "tu_do" && @pts_tu_do && @pts_tu_do.length >= 3
      @state = 4
      @diem_chia_tang.clear
      @diem_chia_khoang.clear
      @tang_ho.clear
      @khoang_ho.clear
      @ds_o = nil
      update_mode_buttons
      update_status
      view.invalidate
      return
    end
    if @state == 4 && @pts_tu_do && @pts_tu_do.length > 2
      @pts_tu_do.pop
      @normal_tu_do = nil if @pts_tu_do.length < 3
      update_status
      view.invalidate
      return
    end
    view.invalidate if @da_ve
    view.lock_inference if view.inference_locked?
    reset
  end
  def onUserText(text, view)
    if text.start_with?('/')
      num = text[1..-1].to_i
      return nil if num < 1
      if @che_do_tool == "chia_canh" && @state == 0
        preview_chia_deu(num, view)
        return
      end
      return nil unless @state == 3
      handle_division_command(num, view)
      return
    end
    if @che_do_tool == "chia_canh" && @state == 0
      begin
        val = text.to_f
        @ho_giua_cac_canh = val.mm
        write("ho_giua_cac_canh", val)
        preview_chia_deu(@chia_so_luong, view) if @chia_so_luong
        update_status
        view.invalidate
      rescue
      end
      return
    end
    handle_dimension_input(text, view)
  end
  def onKeyDown(key, rpt, flags, view)
    if key == 192
      ZSU::Settings.open_settings('tao_canh')
      return true
    end
    if key == ALT_MODIFIER_KEY
      if (@che_do_tool == "chia_canh" && @state == 0) || @state == 3
        chuyen_canh_le_chia(view)
      end
      return true
    end
    if key == 8 && @state == 3 && rpt == 1
      if undo_last_division
        update_status
        view.invalidate
      end
      return true
    end
    if @che_do_tool == "chia_canh" && @state == 0 && rpt == 1
      if key == 17
        doi_truc_chia(view)
        return true
      end
    end
    if @state == 3 && rpt == 1
      if key == 17
        @che_do_chia = (@che_do_chia == :tang) ? :khoang : :tang
        pt_end = @che_do_chia == :khoang ? @pts[1] : @pts[3]
        if @pts[0] && pt_end
          result = project_point_to_axis(@pts[0], pt_end)
          @diem_chia_ht = (result == :no_ray) ? nil : result
        end
        update_anchor_for_mode
        update_mode_buttons
        update_status
        view.invalidate
        return true
      end
    end
    handle_arrow_lock(key, rpt, view) if @state < 3 && @che_do_tool != "chia_canh" && rpt == 1
    handle_inference_lock(key, rpt, view) if key == CONSTRAIN_MODIFIER_KEY && rpt == 1
  end
  def onKeyUp(key, rpt, flags, view)
    return if @sb_selected_item
    return true if key == ALT_MODIFIER_KEY
    if key == CONSTRAIN_MODIFIER_KEY && view.inference_locked?
      view.lock_inference
      return true
    elsif key == CONSTRAIN_MODIFIER_KEY && @state > 2
      @dao_chieu = !@dao_chieu
      update_status
      view.invalidate
      return true
    elsif key == 9
      handle_tab(view)
      return true
    end
  end
  def getExtents
    bb = Geom::BoundingBox.new
    case @state
    when 0
      bb.add(@ip.position) if @ip_valid && @ip.display?
    when 1, 2, 3
      @pts.compact.each { |pt| bb.add(pt) }
    when 4
      @pts_tu_do.each { |pt| bb.add(pt) } if @pts_tu_do
      bb.add(@pt_tu_do_ht) if @pt_tu_do_ht
    end
    bb
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)
    @da_ve = false
    if @che_do_tool == "chia_canh" && @state == 0
      if @ip.valid? && @ip.display? && !@chia_ds_mat
        @ip.draw(view)
        @da_ve = true
      end
      if @chia_ds_mat && @chia_normal && @chia_do_sau
        vec = make_depth_vec(@chia_normal, @chia_do_sau)
        dpi_vec = [0, 0, @view_dpi]
        @chia_ds_mat.each do |cp|
          cp = cp.map { |pt| pt.offset(dpi_vec) } if @view_dpi != 0
          top = cp.map { |pt| pt.offset(vec) }
          ZSU::View.draw_polygon(cp, line: false)
          ZSU::View.draw_polygon(top, line: false)
          cp.length.times do |i|
            j = (i + 1) % cp.length
            ZSU::View.draw_polygon([cp[i], cp[j], top[j], top[i]], line: false)
          end
        end
        @chia_ds_mat.each do |cp|
          top = cp.map { |pt| pt.offset(vec) }
          ZSU::View.draw_loop(cp, guide: true)
          ZSU::View.draw_loop(top, guide: true)
          cp.length.times do |i|
            ZSU::View.draw_lines([cp[i], top[i]], guide: true)
          end
        end
        ve_duong_chia(view) if @chia_ds_mat.length > 1
        ve_kich_thuoc_chia(@chia_ds_mat)
        @da_ve = true
      elsif @pts_noi_bat && @chia_normal && @chia_do_sau && @chia_do_sau.abs > 0.001
        draw_box(@pts_noi_bat, @chia_normal, @chia_do_sau, view, faded: true)
        if @chia_pts
          gap_dir = @chia_truc == :a \
            ? (@pts_noi_bat[1] - @pts_noi_bat[0]) \
            : (@pts_noi_bat[3] - @pts_noi_bat[0])
          ve_khe_chia(@chia_pts, gap_dir, @chia_normal, @chia_do_sau)
          draw_distance_plane(@chia_pts[0], @chia_pts[1], @chia_normal, @chia_do_sau)
          ve_kich_thuoc_chia(tinh_face_chia)
        end
        @da_ve = true
      elsif @pts_noi_bat
        ZSU::View.draw2d_polygon(@pts_noi_bat)
        @da_ve = true
      end
      return
    end
    if @ip_valid && @ip.display?
      @ip.draw(view)
      @da_ve = true
    end
    if @state == 0 && @ip_valid && @ip.edge &&
       @ip.degrees_of_freedom == 1 && @phuong_phap_ve == "3_diem"
      tr = @ip.transformation
      v1 = @ip.edge.start.position.transform(tr)
      v2 = @ip.edge.end.position.transform(tr)
      ZSU::View.draw_lines([v1, v2])
      @da_ve = true
    end
    if @phuong_phap_ve == "tu_do" && @state == 4
      draw_free_polygon(view)
      @da_ve = true
      return
    end
    show_rect = (@phuong_phap_ve == "2_diem" && @state == 1 &&
                 @pts[0] && @pts[1] && @pts[2] && @pts[3])
    if @phuong_phap_ve == "tu_do" && @state == 1 && @pts_tu_do.length == 1 && @pts[1]
      ZSU::View.draw_lines([@pts_tu_do[0], @pts[1]])
      @da_ve = true
    elsif @state == 1 && @pts[0] && @pts[1] && !show_rect
      ZSU::View.draw_lines([@pts[0], @pts[1]])
      @da_ve = true
    elsif show_rect || (@state >= 2 && @pts[0] && @pts[1] && @pts[2] && @pts[3])
      draw_grid_preview(view)
      @da_ve = true
    end
  end
  def update_status
    case @state
    when 0
      if @che_do_tool == "chia_canh"
        ZSU.vcb("Số lượng [/x] | Khoảng hở",
                 Sketchup.format_length(@ho_giua_cac_canh))
        if @chia_ds_mat
          text = "Nhấn Tab để chuyển chế độ. " \
                 "Nhấn Enter để xác nhận. " \
                 "Nhấn Ctrl để đổi chiều chia. " \
                 "Nhấn Alt để chuyển vị trí căn khe hở."
        else
          text = "Nhấn Tab để chuyển chế độ. " \
                 "Nhấn Ctrl để đổi chiều chia. " \
                 "Nhấn Alt để chuyển vị trí căn khe hở."
        end
      else
        ZSU.vcb("Độ dày ván", Sketchup.format_length(@do_day))
        text = "Nhấn Tab để chuyển chế độ. Chọn điểm đầu."
      end
    when 1
      ZSU.vcb("Độ dày ván", Sketchup.format_length(@do_day))
      text = "Nhấn Tab để đảo mặt."
    when 2
      ZSU.vcb("Độ dày ván", Sketchup.format_length(@do_day))
      text = "Nhấn Tab để đảo mặt."
    when 3
      ZSU.vcb("Số lượng [/x] | Khoảng hở",
               Sketchup.format_length(@ho_giua_cac_canh))
      text = "Nhấn Tab để chuyển chế độ. " \
             "Nhấn Ctrl để đổi chiều chia. " \
             "Nhấn Shift để đảo mặt. " \
             "Nhấn Alt để chuyển vị trí căn khe hở. " \
             "Nhấn Backspace để hoàn tác."
    when 4
      ZSU.vcb("Độ dày ván", Sketchup.format_length(@do_day))
      text = "Nhấn Enter để hoàn thành. Nhấn Shift để đảo mặt."
    end
    ZSU.status(text)
  end
  private
  def chon_mat_chia(x, y, view)
    @chia_pts = nil
    ph = view.pick_helper
    ph.do_pick(x, y)
    face = ph.picked_face
    unless face
      @mat_noi_bat = nil
      @pts_noi_bat = nil
      view.invalidate
      return
    end
    path = ph.path_at(0)
    return unless path && !path.empty?
    tr = ph.transformation_at(0)
    parent = path.reverse.find { |e| ZSU.is_container?(e) }
    return unless parent
    faces = parent.definition.entities.grep(Sketchup::Face)
    largest = faces.max_by(2) { |f| f.area }
    return unless largest && largest.size == 2
    local_face = largest.find { |f| f == face }
    unless local_face
      hit_point = ZSU::View.calc_hit_point(face, tr, x, y, view)
      return unless hit_point
      normal = face.normal.transform(tr)
      normal.normalize!
      local_face = largest.find { |f|
        fn = f.normal.transform(tr)
        fn.normalize!
        fn.parallel?(normal)
      }
    end
    if local_face
      @mat_noi_bat = local_face
      @pts_noi_bat = local_face.outer_loop.vertices.map { |v| v.position.transform(tr) }
      if @pts_noi_bat.length == 4
        fn = local_face.normal.transform(tr)
        fn.normalize!
        if @ip.valid?
          v = @ip.position - @pts_noi_bat[0]
          hit = @ip.position.offset(fn, -(v % fn))
        else
          ray = view.pickray(x, y)
          hit = ray_hit_plane(ray, @pts_noi_bat[0], fn)
        end
        if hit
          edge_a = @pts_noi_bat[1] - @pts_noi_bat[0]
          edge_b = @pts_noi_bat[3] - @pts_noi_bat[0]
          axis = @chia_truc_chon || (edge_a.length >= edge_b.length ? :a : :b)
          edge = axis == :a ? edge_a : edge_b
          t = ((hit - @pts_noi_bat[0]) % edge.normalize) / edge.length
          t = [[t, 0.02].max, 0.98].min
          @chia_truc = axis
          if axis == :a
            @chia_pts = [
              Geom.linear_combination(1 - t, @pts_noi_bat[0], t, @pts_noi_bat[1]),
              Geom.linear_combination(1 - t, @pts_noi_bat[3], t, @pts_noi_bat[2])
            ]
          else
            @chia_pts = [
              Geom.linear_combination(1 - t, @pts_noi_bat[0], t, @pts_noi_bat[3]),
              Geom.linear_combination(1 - t, @pts_noi_bat[1], t, @pts_noi_bat[2])
            ]
          end
          other_face = largest.find { |f| f != local_face }
          if other_face
            pt_other = other_face.vertices[0].position.transform(tr)
            @chia_do_sau = (pt_other - @pts_noi_bat[0]) % fn
          end
          @chia_normal = fn
          @chia_parent = parent
        end
      end
    else
      @mat_noi_bat = nil
      @pts_noi_bat = nil
    end
    view.invalidate
  end
  def chuyen_canh_le_chia(key_or_view = nil, view = nil)
    if key_or_view.is_a?(Numeric)
      idx_offset = (key_or_view == VK_RIGHT) ? 1 : -1
    else
      view = key_or_view
      idx_offset = 1
    end
    order = [:dau, :giua, :cuoi]
    idx = order.index(@chia_canh_le) || 1
    @chia_canh_le = order[(idx + idx_offset) % 3]
    preview_chia_deu(@chia_so_luong, view) if @chia_so_luong
    update_status
    view.invalidate
  end
  def ve_khe_chia(split_pts, gap_dir, normal, depth)
    gap = @ho_giua_cac_canh
    return if gap.abs < 0.001
    return unless normal && depth != 0
    axis = gap_dir.length > 0 ? gap_dir.normalize : return
    depth_vec = make_depth_vec(normal, depth)
    p1, p2 = split_pts[0], split_pts[1]
    case @chia_canh_le
    when :dau  then ve_rect_khe(p1, p2, axis,  gap, depth_vec)
    when :cuoi then ve_rect_khe(p1, p2, axis, -gap, depth_vec)
    else
      half = gap / 2.0
      ve_rect_khe(p1, p2, axis,  half, depth_vec)
      ve_rect_khe(p1, p2, axis, -half, depth_vec)
    end
  end
  def ve_rect_khe(p1, p2, axis, dist, depth_vec)
    v = Geom::Vector3d.new(axis.x * dist, axis.y * dist, axis.z * dist)
    g1, g2 = p1.offset(v), p2.offset(v)
    ZSU::View.draw2d_loop([g1, g2, g2.offset(depth_vec), g1.offset(depth_vec)], guide: true)
  end
  def tinh_do_lech(gap)
    case @chia_canh_le
    when :dau  then [0, gap]
    when :cuoi then [gap, 0]
    else [gap / 2.0, gap / 2.0]
    end
  end
  def do_lech_khe
    tinh_do_lech(@ho_giua_cac_canh)
  end
  def doi_truc_chia(view)
    return unless @pts_noi_bat && @pts_noi_bat.length == 4 && @chia_pts
    sp1, sp2 = @chia_pts
    mid = Geom.linear_combination(0.5, sp1, 0.5, sp2)
    if @chia_truc == :a
      edge = @pts_noi_bat[3] - @pts_noi_bat[0]
      t = ((mid - @pts_noi_bat[0]) % edge.normalize) / edge.length
      t = [[t, 0.02].max, 0.98].min
      @chia_pts = [
        Geom.linear_combination(1 - t, @pts_noi_bat[0], t, @pts_noi_bat[3]),
        Geom.linear_combination(1 - t, @pts_noi_bat[1], t, @pts_noi_bat[2])
      ]
      @chia_truc = @chia_truc_chon = :b
    else
      edge = @pts_noi_bat[1] - @pts_noi_bat[0]
      t = ((mid - @pts_noi_bat[0]) % edge.normalize) / edge.length
      t = [[t, 0.02].max, 0.98].min
      @chia_pts = [
        Geom.linear_combination(1 - t, @pts_noi_bat[0], t, @pts_noi_bat[1]),
        Geom.linear_combination(1 - t, @pts_noi_bat[3], t, @pts_noi_bat[2])
      ]
      @chia_truc = @chia_truc_chon = :a
    end
    view.invalidate
  end
  def thuc_hien_chia(view)
    return unless @chia_parent && @chia_pts && @pts_noi_bat
    return unless @pts_noi_bat.length == 4 && @chia_do_sau && @chia_do_sau.abs > 0.001
    parent = @chia_parent
    return unless parent.valid?
    sp1, sp2 = @chia_pts
    off_a, off_b = do_lech_khe
    if @chia_truc == :a
      gap_vec = (@pts_noi_bat[1] - @pts_noi_bat[0]).normalize
      sp1a = sp1.offset(gap_vec, -off_a); sp2a = sp2.offset(gap_vec, -off_a)
      sp1b = sp1.offset(gap_vec,  off_b); sp2b = sp2.offset(gap_vec,  off_b)
      face_pts_list = [
        [@pts_noi_bat[0], sp1a, sp2a, @pts_noi_bat[3]],
        [sp1b, @pts_noi_bat[1], @pts_noi_bat[2], sp2b]
      ]
    else
      gap_vec = (@pts_noi_bat[3] - @pts_noi_bat[0]).normalize
      sp1a = sp1.offset(gap_vec, -off_a); sp2a = sp2.offset(gap_vec, -off_a)
      sp1b = sp1.offset(gap_vec,  off_b); sp2b = sp2.offset(gap_vec,  off_b)
      face_pts_list = [
        [@pts_noi_bat[0], @pts_noi_bat[1], sp2a, sp1a],
        [sp1b, sp2b, @pts_noi_bat[2], @pts_noi_bat[3]]
      ]
    end
    tao_van_chia(face_pts_list, parent, view)
  end
  def ve_duong_chia(view)
    faces = @chia_ds_mat
    axis = @chia_truc || @chia_truc_chon || :a
    (0...faces.length - 1).each do |i|
      if axis == :a
        ea1, ea2 = faces[i][1], faces[i][2]
        sb1, sb2 = faces[i + 1][0], faces[i + 1][3]
      else
        ea1, ea2 = faces[i][3], faces[i][2]
        sb1, sb2 = faces[i + 1][0], faces[i + 1][1]
      end
      case @chia_canh_le
      when :dau
        p1, p2 = ea1, ea2
      when :cuoi
        p1, p2 = sb1, sb2
      else
        p1 = Geom.linear_combination(0.5, ea1, 0.5, sb1)
        p2 = Geom.linear_combination(0.5, ea2, 0.5, sb2)
      end
      draw_distance_plane(p1, p2, @chia_normal, @chia_do_sau)
    end
  end
  def preview_chia_deu(num, view)
    return unless @chia_parent && @pts_noi_bat && @pts_noi_bat.length == 4
    return unless @chia_do_sau && @chia_do_sau.abs > 0.001
    edge_a = @pts_noi_bat[1] - @pts_noi_bat[0]
    edge_b = @pts_noi_bat[3] - @pts_noi_bat[0]
    axis = @chia_truc_chon || (edge_a.length >= edge_b.length ? :a : :b)
    total = axis == :a ? edge_a.length : edge_b.length
    gap = @ho_giua_cac_canh
    available = total - (num - 1) * gap
    return if available <= 0
    sub_size = available / num.to_f
    face_pts_list = []
    num.times do |i|
      t_start = (i * sub_size + i * gap) / total
      t_end = ((i + 1) * sub_size + i * gap) / total
      if axis == :a
        p0 = Geom.linear_combination(1 - t_start, @pts_noi_bat[0], t_start, @pts_noi_bat[1])
        p1 = Geom.linear_combination(1 - t_end, @pts_noi_bat[0], t_end, @pts_noi_bat[1])
        p2 = Geom.linear_combination(1 - t_end, @pts_noi_bat[3], t_end, @pts_noi_bat[2])
        p3 = Geom.linear_combination(1 - t_start, @pts_noi_bat[3], t_start, @pts_noi_bat[2])
      else
        p0 = Geom.linear_combination(1 - t_start, @pts_noi_bat[0], t_start, @pts_noi_bat[3])
        p1 = Geom.linear_combination(1 - t_start, @pts_noi_bat[1], t_start, @pts_noi_bat[2])
        p2 = Geom.linear_combination(1 - t_end, @pts_noi_bat[1], t_end, @pts_noi_bat[2])
        p3 = Geom.linear_combination(1 - t_end, @pts_noi_bat[0], t_end, @pts_noi_bat[3])
      end
      face_pts_list << [p0, p1, p2, p3]
    end
    @chia_ds_mat = face_pts_list
    @chia_so_luong = num
    update_status
    view.invalidate
  end
  def xac_nhan_chia(view)
    return unless @chia_parent && @chia_ds_mat && !@chia_ds_mat.empty?
    return unless @chia_do_sau && @chia_do_sau.abs > 0.001
    parent = @chia_parent
    return unless parent.valid?
    tao_van_chia(@chia_ds_mat, parent, view)
  end
  def tao_van_chia(face_pts_list, parent, view)
    ents = ZSU::Model.active_entities
    orig_name = parent.name
    orig_layer = parent.layer
    orig_material = parent.material
    ZSU.start
    boards = []
    face_pts_list.each do |pts|
      g = ents.add_group
      f = g.entities.add_face(pts)
      next unless f
      board = ZSU::Board.make(f, ents, 0, @chia_do_sau * @ty_le_canh)
      tr = g.transformation
      board.transform!(tr) unless tr.identity?
      boards << board
      f.edges.each { |e| e.erase! if e.valid? }
      g.erase! if g.valid?
    end
    parent.erase! if parent.valid?
    ZSU.commit
    boards.each do |b|
      ZSU.start
      b.name = orig_name
      b.layer = orig_layer
      if orig_material
        b.material = orig_material
        b.entities.grep(Sketchup::Face).each do |f|
          f.material = nil
          f.back_material = nil
        end
      end
      ZSU::Group.reset_axes(b)
      ZSU::Group.center_origin(b)
      ZSU.commit
    end
    ZSU.select(boards)
    reset
    view.invalidate
  end
  def set_current_point(x, y, view)
    @ip.pick(view, x, y, @ip1)
    @ip_valid = @ip.valid?
    @last_ray = view.pickray(x, y)
    update_tooltip(view)
    result = case @state
             when 0 then pick_state0
             when 1 then pick_state1(view)
             when 2 then pick_state2(x, y, view)
             when 3 then pick_state3(x, y, view)
             when 4 then pick_state4
             end
    return result if result == false
    view.invalidate
    true
  end
  def update_tooltip(view)
    if @locked_normal
      axis_name = if @locked_normal.x.abs > 0.9 then "Normal: Red Axis"
                  elsif @locked_normal.y.abs > 0.9 then "Normal: Green Axis"
                  elsif @locked_normal.z.abs > 0.9 then "Normal: Blue Axis"
                  else "Normal: Locked"
                  end
      view.tooltip = axis_name
    elsif @ip.valid?
      view.tooltip = @ip.tooltip
    end
  end
  def pick_state0
    if @ip.valid?
      @pts[0] = @ip.position
    elsif @locked_normal && @last_ray
      pt = ray_hit_plane(@last_ray, ORIGIN, @locked_normal)
      return false unless pt
      @pts[0] = pt
    else
      return false
    end
  end
  def pick_state1(view)
    return false unless @pts[0] && @last_ray
    pt = pick_point_with_lock(@pts[0])
    return false unless pt
    pt = flatten_to_plane(pt, @pts[0]) if @locked_normal
    if @phuong_phap_ve == "2_diem"
      @normal_2_diem = @locked_normal || determine_2point_normal(@pts[0], pt)
      compute_rectangle_from_2points(@pts[0], pt, @normal_2_diem)
    else
      @pts[1] = pt
    end
  end
  def pick_state2(x, y, view)
    return false unless @pts[0] && @pts[1] && @last_ray
    pt1 = pick_point_with_lock(@pts[1])
    return false unless pt1
    if @locked_normal
      edge_vec = @pts[1] - @pts[0]
      if edge_vec.length > 0
        height_dir = @locked_normal.cross(edge_vec)
        if height_dir.length > 0
          height_dir.normalize!
          pt1 = pt1.project_to_line([@pts[1], height_dir])
        end
      end
    end
    compute_state2_rect(pt1, x, y, view)
  end
  def pick_state3(x, y, view)
    pt_end = @che_do_chia == :khoang ? @pts[1] : @pts[3]
    return false unless @pts[0] && pt_end
    if free_mode? && @normal_tu_do
      hit = pick_on_free_plane
      return false unless hit
      @diem_chia_ht = project_to_line_clamped(hit, @pts[0], pt_end)
    else
      result = project_point_to_axis(@pts[0], pt_end)
      return true if result == :no_ray
      @diem_chia_ht = result
    end
    @o_hover = find_hover_cell_idx(x, y, view) if @noi_bo
  end
  def pick_state4
    return false unless @last_ray
    if @normal_tu_do
      pt = pick_on_free_plane
    elsif @ip.valid?
      pt = @ip.position
    else
      camera_pos = view_camera_eye
      distance = camera_pos.distance(@pts_tu_do.last)
      pt = @last_ray[0].offset(@last_ray[1], distance)
    end
    return false unless pt
    @pt_tu_do_ht = pt
  end
  def pick_point_with_lock(ref_pt)
    if @ip.valid? && (!@locked_normal || @ip.face || @ip.edge)
      @ip.position
    elsif @locked_normal
      ray_hit_plane(@last_ray, ref_pt, @locked_normal) || fallback_point(ref_pt)
    else
      fallback_point(ref_pt)
    end
  end
  def fallback_point(ref_pt)
    camera_pos = view_camera_eye
    distance = camera_pos.distance(ref_pt)
    @last_ray[0].offset(@last_ray[1], distance)
  end
  def flatten_to_plane(pt, origin)
    v = pt - origin
    dist = v % @locked_normal
    pt.offset(@locked_normal, -dist)
  end
  def pick_on_free_plane
    if @ip.valid?
      v = @ip.position - @pts_tu_do[0]
      dist = (v % @normal_tu_do).abs
      if dist < 0.1.mm
        return project_to_free_plane(@ip.position)
      end
    end
    ray_hit_plane(@last_ray, @pts_tu_do[0], @normal_tu_do)
  end
  def project_to_line_clamped(hit, pt_start, pt_end)
    vec = pt_end - pt_start
    projected = hit.project_to_line([pt_start, vec])
    if vec.length > 0
      vp = projected - pt_start
      t = (vp % vec) / (vec % vec)
      t = [[t, 0.0].max, 1.0].min
      Geom.linear_combination(1 - t, pt_start, t, pt_end)
    else
      pt_start
    end
  end
  def view_camera_eye
    Sketchup.active_model.active_view.camera.eye
  end
  def increment_state
    if free_mode?
      increment_free_state
      return
    end
    @ip1.copy!(@ip) if @state < 2
    @state += 1
    if @state == 3
      @che_do_chia = :khoang
      @ds_o = compute_global_cells if @noi_bo
      update_anchor_for_mode
    end
    update_mode_buttons
    update_status
  end
  def increment_free_state
    case @state
    when 0
      @pts_tu_do = [@pts[0].clone]
      @state = 1
    when 1
      pt = @ip.valid? ? @ip.position : return
      @pts_tu_do << pt.clone
      @state = 4
    when 4
      return unless @pt_tu_do_ht
      pt = @normal_tu_do ? project_to_free_plane(@pt_tu_do_ht) : @pt_tu_do_ht.clone
      @pts_tu_do << pt
      establish_free_plane if @pts_tu_do.length == 3
    end
    @ip1.copy!(@ip) if @ip.valid?
    update_mode_buttons
    update_status
  end
  def establish_free_plane
    v1 = @pts_tu_do[1] - @pts_tu_do[0]
    v2 = @pts_tu_do[2] - @pts_tu_do[0]
    normal = v1.cross(v2)
    if normal.length > 0.001
      normal.normalize!
      @normal_tu_do = normal
    else
      @pts_tu_do.pop
    end
  end
  def snap_to_edge(x, y, view)
    return false unless @ip.edge && @ip.degrees_of_freedom == 1
    ph = view.pick_helper
    ph.do_pick(x, y)
    tr = ph.transformation_at(0)
    edge = @ip.edge
    v1 = edge.start.position.transform(tr)
    v2 = edge.end.position.transform(tr)
    mouse_pt = @ip.position
    if mouse_pt.distance(v1) < mouse_pt.distance(v2)
      @pts[0] = v1
      @pts[1] = v2
    else
      @pts[0] = v2
      @pts[1] = v1
    end
    @ip1.clear
    @state = 2
    update_mode_buttons
    update_status
    view.invalidate
    true
  end
  def add_division_point(view)
    save_division_state
    if @noi_bo && @o_hover != nil && @ds_o
      vec = @che_do_chia == :khoang ? (@pts[1] - @pts[0]) : (@pts[3] - @pts[0])
      dist = (@diem_chia_ht - @pts[0]) % vec.normalize
      split_cell_at_dist(@o_hover, dist)
    else
      if @che_do_chia == :khoang
        @diem_chia_khoang << @diem_chia_ht
        @khoang_ho << @ho_giua_cac_canh
      else
        @diem_chia_tang << @diem_chia_ht
        @tang_ho << @ho_giua_cac_canh
      end
    end
    @diem_neo = @diem_chia_ht
    @diem_chia_ht = nil
    update_status
    view.invalidate
  end
  def handle_arrow_lock(key, rpt, view)
    new_normal = case key
                 when VK_LEFT  then Geom::Vector3d.new(0, 1, 0)
                 when VK_RIGHT then Geom::Vector3d.new(1, 0, 0)
                 when VK_UP, VK_DOWN then Geom::Vector3d.new(0, 0, 1)
                 end
    return unless new_normal
    same = @locked_normal && (
      (@locked_normal.x.abs == new_normal.x.abs && new_normal.x.abs > 0.9) ||
        (@locked_normal.y.abs == new_normal.y.abs && new_normal.y.abs > 0.9) ||
        (@locked_normal.z.abs == new_normal.z.abs && new_normal.z.abs > 0.9)
    )
    @locked_normal = same ? nil : new_normal
    view.invalidate
  end
  def handle_inference_lock(key, rpt, view)
    if view.inference_locked?
      view.lock_inference
    elsif @state == 0 && @ip.valid?
      view.lock_inference(@ip)
    elsif @state == 1 && @ip.valid?
      view.lock_inference(@ip, @ip1)
    elsif @state == 2 && @ip.valid?
      view.lock_inference(@ip)
    end
  end
  def toggle_noi_bo(view)
    @noi_bo = !@noi_bo
    if @noi_bo
      @ds_o = compute_global_cells
    else
      convert_cells_to_divisions
      @ds_o = nil
    end
    @o_hover = nil
    @lich_su_chia.clear
    update_mode_buttons
    update_status
    view.invalidate
  end
  def convert_cells_to_divisions
    return unless @ds_o && @ds_o.length > 1
    return unless @pts[0] && @pts[1] && @pts[3]
    vec_x = @pts[1] - @pts[0]
    vec_y = @pts[3] - @pts[0]
    return if vec_x.length < 0.001 || vec_y.length < 0.001
    @diem_chia_khoang, @khoang_ho = extract_cell_gaps(0, 1, vec_x.normalize)
    @diem_chia_tang, @tang_ho = extract_cell_gaps(2, 3, vec_y.normalize)
  end
  def extract_cell_gaps(idx_s, idx_e, axis)
    vals = @ds_o.flat_map { |c| [c[idx_s], c[idx_e]] }.uniq.sort
    ends = @ds_o.map { |c| c[idx_e].round(3) }.uniq
    starts = @ds_o.map { |c| c[idx_s].round(3) }.uniq
    points = []
    gaps = []
    (0...vals.length - 1).each do |i|
      gap_size = vals[i + 1] - vals[i]
      next if gap_size < 0.001
      if ends.include?(vals[i].round(3)) && starts.include?(vals[i + 1].round(3))
        off_a, _ = tinh_do_lech(gap_size)
        points << @pts[0].offset(axis, vals[i] + off_a)
        gaps << gap_size
      end
    end
    [points, gaps]
  end
  def handle_tab(view)
    if @state == 0
      @che_do_tool = @che_do_tool == "tao_canh" ? "chia_canh" : "tao_canh"
      write("che_do_tool", @che_do_tool)
      @mat_noi_bat = nil
      @pts_noi_bat = nil
      update_mode_buttons
    elsif @state == 1 || @state == 2
      @dao_chieu = !@dao_chieu
    elsif @state == 3
      toggle_noi_bo(view)
      return
    else
      return
    end
    update_status
    view.invalidate
  end
  def handle_dimension_input(text, view)
    case @state
    when 0
      begin
        @do_day = text.to_l
        write("do_day", @do_day.to_mm)
        @button_config[:modified] = true if @button_config
        update_status
        view.invalidate
      rescue
      end
    when 1
      handle_dim_state1(text, view)
    when 2
      handle_dim_state2(text, view)
    when 3
      begin
        num = text.to_f
        @ho_giua_cac_canh = num.mm
        update_status
        view.invalidate
      rescue
      end
    end
  end
  def handle_dim_state1(text, view)
    if @phuong_phap_ve == "2_diem"
      begin
        normal = @locked_normal || @normal_2_diem || Geom::Vector3d.new(0, 0, 1)
        u_dir = @pts[1] && @pts[0].distance(@pts[1]) > 0.001 \
          ? (@pts[1] - @pts[0]).normalize : compute_plane_directions(normal)[0]
        v_dir = @pts[3] && @pts[0].distance(@pts[3]) > 0.001 \
          ? (@pts[3] - @pts[0]).normalize : compute_plane_directions(normal)[1]
        if text.start_with?(',') || text.start_with?(';')
          @pts[3] = @pts[0].offset(v_dir, text[1..-1].to_l)
        elsif text =~ /[,;x]/
          parts = text.split(/[,;x]/)
          return unless parts.length >= 2
          @pts[1] = @pts[0].offset(u_dir, parts[0].to_l)
          @pts[3] = @pts[0].offset(v_dir, parts[1].to_l)
        else
          @pts[1] = @pts[0].offset(u_dir, text.to_l)
        end
        @pts[2] = @pts[1].offset(v_dir, @pts[0].distance(@pts[3]))
        @ip1.copy!(@ip)
        @state = 3
        @che_do_chia = :khoang
        @diem_neo = @pts[1]
        update_status
        view.invalidate
      rescue
      end
    else
      begin
        vec = @pts[1] - @pts[0]
        if vec.length > 0.0
          vec.length = text.to_l
          @pts[1] = @pts[0].offset(vec)
          view.invalidate
          increment_state
        end
      rescue
      end
    end
  end
  def handle_dim_state2(text, view)
    begin
      parts = text.split(/[,;x]/)
      if parts.length >= 2
        vec_w = @pts[1] - @pts[0]
        vec_w.length = parts[0].to_l if vec_w.length > 0.0
        @pts[1] = @pts[0].offset(vec_w)
        vec_h = @pts[3] - @pts[0]
        if vec_h.length > 0.0
          vec_h.length = parts[1].to_l
          @pts[2] = @pts[1].offset(vec_h)
          @pts[3] = @pts[0].offset(vec_h)
        end
      else
        vec = @pts[3] - @pts[0]
        if vec.length > 0.0
          vec.length = text.to_l
          @pts[2] = @pts[1].offset(vec)
          @pts[3] = @pts[0].offset(vec)
        end
      end
      increment_state
    rescue
    end
  end
  def margin(side)
    @ho_deu_bien_ngoai ? @ho_bien_ngoai : instance_variable_get(:"@ho_#{side}")
  end
  def margin_left;   margin(:trai); end
  def margin_right;  margin(:phai); end
  def margin_top;    margin(:tren); end
  def margin_bottom; margin(:duoi); end
  def compute_cell_bounds(total, division_points, gaps, pt_start, pt_end, margin_start, margin_end)
    vec = pt_end - pt_start
    return [[margin_start, total - margin_end]] if vec.length < 0.001 || division_points.empty?
    axis = vec.normalize
    sorted = division_points.each_with_index.map { |pt, i|
      dist = (pt - pt_start) % axis
      dist = [[dist, 0.0].max, total].min
      { dist: dist, gap: gaps[i] || @ho_giua_cac_canh }
    }.sort_by { |h| h[:dist] }
    boundaries = []
    pos = margin_start
    sorted.each do |h|
      off_a, off_b = tinh_do_lech(h[:gap])
      cell_end = h[:dist] - off_a
      boundaries << [pos, cell_end] if cell_end > pos + 0.001
      pos = h[:dist] + off_b
    end
    cell_end = total - margin_end
    boundaries << [pos, cell_end] if cell_end > pos + 0.001
    boundaries
  end
  def compute_global_cells
    return [] unless @pts.length >= 4 && @pts[0] && @pts[1] && @pts[2] && @pts[3]
    vec_x = @pts[0].vector_to(@pts[1])
    vec_y = @pts[0].vector_to(@pts[3])
    return [] if vec_x.length < 0.001 || vec_y.length < 0.001
    total_x = vec_x.length
    total_y = vec_y.length
    col_bounds = compute_cell_bounds(
      total_x, @diem_chia_khoang, @khoang_ho, @pts[0], @pts[1], margin_left, margin_right
    )
    row_bounds = compute_cell_bounds(
      total_y, @diem_chia_tang, @tang_ho, @pts[0], @pts[3], margin_top, margin_bottom
    )
    cells = []
    col_bounds.each do |gx_s, gx_e|
      next if gx_e <= gx_s
      row_bounds.each do |gy_s, gy_e|
        next if gy_e <= gy_s
        cells << [gx_s, gx_e, gy_s, gy_e]
      end
    end
    cells
  end
  def each_grid_cell
    return unless @pts.length >= 4 && @pts[0] && @pts[1] && @pts[2] && @pts[3]
    return if @pts[0] == @pts[3]
    vec_x = @pts[0].vector_to(@pts[1])
    vec_y = @pts[0].vector_to(@pts[3])
    return if vec_x.length < 0.001 || vec_y.length < 0.001
    cells = @ds_o || compute_global_cells
    cells.each { |cx_s, cx_e, cy_s, cy_e| yield cx_s, cx_e, cy_s, cy_e }
  end
  def bounds_to_rect(ax_start, ax_end, ay_start, ay_end)
    vec_x_n = @pts[0].vector_to(@pts[1]).normalize
    vec_y_n = @pts[0].vector_to(@pts[3]).normalize
    p0 = @pts[0].offset(vec_x_n, ax_start).offset(vec_y_n, ay_start)
    p1 = @pts[0].offset(vec_x_n, ax_end).offset(vec_y_n, ay_start)
    p2 = @pts[0].offset(vec_x_n, ax_end).offset(vec_y_n, ay_end)
    p3 = @pts[0].offset(vec_x_n, ax_start).offset(vec_y_n, ay_end)
    [p0, p1, p2, p3]
  end
  def get_grid_cells
    if free_mode? && @pts_tu_do && @pts_tu_do.length >= 3
      return [@pts_tu_do.dup] unless @state == 3
      return get_free_grid_cells
    end
    cells = []
    each_grid_cell { |*bounds| cells << bounds_to_rect(*bounds) }
    cells
  end
  def get_free_grid_cells
    rect_cells = []
    each_grid_cell do |*bounds|
      rect = bounds_to_rect(*bounds)
      clipped = clip_polygon_to_rect(@pts_tu_do, rect, @normal_tu_do)
      rect_cells << clipped if clipped && clipped.length >= 3
    end
    rect_cells.empty? ? [@pts_tu_do.dup] : rect_cells
  end
  def subdivide_cell_equal(cell_idx, num)
    return unless @ds_o && cell_idx && cell_idx < @ds_o.length
    cell = @ds_o[cell_idx]
    cx_s, cx_e, cy_s, cy_e = cell
    if @che_do_chia == :khoang
      sub_bounds = equal_sub_bounds(num, cx_s, cx_e)
      new_cells = sub_bounds.map { |s, e| [s, e, cy_s, cy_e] }
    else
      sub_bounds = equal_sub_bounds(num, cy_s, cy_e)
      new_cells = sub_bounds.map { |s, e| [cx_s, cx_e, s, e] }
    end
    @ds_o.delete_at(cell_idx)
    @ds_o.insert(cell_idx, *new_cells)
  end
  def equal_sub_bounds(num, range_s, range_e)
    return [[range_s, range_e]] if num < 2
    total = range_e - range_s
    available = total - (num - 1) * @ho_giua_cac_canh
    return [[range_s, range_e]] if available <= 0
    sub_size = available / num.to_f
    bounds = []
    pos = range_s
    num.times do
      bounds << [pos, pos + sub_size]
      pos += sub_size + @ho_giua_cac_canh
    end
    bounds
  end
  def split_cell_at_dist(cell_idx, dist)
    return unless @ds_o && cell_idx && cell_idx < @ds_o.length
    cell = @ds_o[cell_idx]
    cx_s, cx_e, cy_s, cy_e = cell
    off_a, off_b = tinh_do_lech(@ho_giua_cac_canh)
    new_cells = []
    if @che_do_chia == :khoang
      return unless dist > cx_s + 0.001 && dist < cx_e - 0.001
      left_end = dist - off_a
      right_start = dist + off_b
      new_cells << [cx_s, left_end, cy_s, cy_e] if left_end > cx_s + 0.001
      new_cells << [right_start, cx_e, cy_s, cy_e] if cx_e > right_start + 0.001
    else
      return unless dist > cy_s + 0.001 && dist < cy_e - 0.001
      bottom_end = dist - off_a
      top_start = dist + off_b
      new_cells << [cx_s, cx_e, cy_s, bottom_end] if bottom_end > cy_s + 0.001
      new_cells << [cx_s, cx_e, top_start, cy_e] if cy_e > top_start + 0.001
    end
    return if new_cells.empty?
    @ds_o.delete_at(cell_idx)
    @ds_o.insert(cell_idx, *new_cells)
  end
  def update_anchor_for_mode
    @diem_neo = if @che_do_chia == :khoang
                      @diem_chia_khoang.empty? ? @pts[1] : @diem_chia_khoang.last
                    else
                      @diem_chia_tang.empty? ? @pts[3] : @diem_chia_tang.last
                    end
  end
  def save_division_state
    @lich_su_chia << {
      dp: @diem_chia_tang.dup,
      dpk: @diem_chia_khoang.dup,
      th: @tang_ho.dup,
      kh: @khoang_ho.dup,
      cl: @ds_o ? @ds_o.map(&:dup) : nil,
      anchor: @diem_neo
    }
  end
  def undo_last_division
    return false if @lich_su_chia.empty?
    s = @lich_su_chia.pop
    @diem_chia_tang = s[:dp]
    @diem_chia_khoang = s[:dpk]
    @tang_ho = s[:th]
    @khoang_ho = s[:kh]
    @ds_o = s[:cl]
    @diem_neo = s[:anchor]
    true
  end
  def generate_equal_divisions(num, cell_start, cell_end, total, pt_start, pt_end)
    num_divisions = num - 1
    return [] if num_divisions < 1
    available = (cell_end - cell_start) - (num - 1) * @ho_giua_cac_canh
    return [] if available <= 0
    sub_size = available / num.to_f
    he_so = case @chia_canh_le
            when :dau  then -1
            when :cuoi then 0
            else -0.5
            end
    (1..num_divisions).map do |i|
      dist = cell_start + i * sub_size + (i + he_so) * @ho_giua_cac_canh
      t = dist / total
      t = [[t, 0.0].max, 1.0].min
      Geom.linear_combination(1 - t, pt_start, t, pt_end)
    end
  end
  def handle_division_command(num, view)
    save_division_state
    if @noi_bo && @ds_o
      subdivide_cell_equal(@o_hover, num) if @o_hover
    elsif @che_do_chia == :khoang
      @diem_chia_khoang.clear; @khoang_ho.clear
      total = @pts[0].distance(@pts[1])
      pts = generate_equal_divisions(
        num, margin_left, total - margin_right, total, @pts[0], @pts[1]
      )
      pts.each { |pt| @diem_chia_khoang << pt; @khoang_ho << @ho_giua_cac_canh }
      @diem_neo = @diem_chia_khoang.last || @pts[1]
    else
      @diem_chia_tang.clear; @tang_ho.clear
      total = @pts[0].distance(@pts[3])
      pts = generate_equal_divisions(
        num, margin_top, total - margin_bottom, total, @pts[0], @pts[3]
      )
      pts.each { |pt| @diem_chia_tang << pt; @tang_ho << @ho_giua_cac_canh }
      @diem_neo = @diem_chia_tang.last || @pts[3]
    end
    update_status
    view.invalidate
  end
  def create_rectangle
    cells = get_grid_cells
    return reset if cells.empty?
    cells = offset_cells(cells) if @canh_cach_mat_goc != 0
    ents = ZSU::Model.active_entities
    ZSU.start
    new_boards = []
    do_day = (@dao_chieu ? @do_day : -@do_day) * @ty_le_canh + @sai_so_canh + @bu_sai_canh
    cells.each do |cell_pts|
      g = ents.add_group
      f = g.entities.add_face(cell_pts)
      next unless f
      board = ZSU::Board.make(f, ents, 0, do_day)
      tr = g.transformation
      board.transform!(tr) unless tr.identity?
      new_boards << board
      f.edges.each { |e| e.erase! if e.valid? }
      g.erase! if g.valid?
    end
    new_boards = componentize_boards(new_boards) if @tao_component && new_boards.length > 0
    ZSU.commit
    finalize_boards(new_boards)
    ZSU.select(new_boards)
    reset
  end
  def componentize_boards(new_boards)
    num_cols = @diem_chia_khoang.length + 1
    num_rows = @diem_chia_tang.length + 1
    all_components = []
    num_rows.times do |row_idx|
      start_idx = row_idx * num_cols
      row_boards = new_boards[start_idx, num_cols]
      if row_boards && row_boards.length > 0
        row_component = ZSU::Group.group_to_component(row_boards)
        all_components.concat(row_component.is_a?(Array) ? row_component : [row_component])
      end
    end
    all_components
  end
  def finalize_boards(new_boards)
    return unless new_boards.length > 0
    layer = ZSU.ensure_tag(@layer)
    new_boards.each do |b|
      ZSU.start
      b.name = @instance
      b.layer = layer
      ZSU::Group.reset_axes(b)
      ZSU::Group.center_origin(b)
      ZSU.commit
    end
  end
  def draw_grid_preview(view)
    cells = get_grid_cells
    cells = offset_cells(cells) if @canh_cach_mat_goc != 0
    normal = get_normal
    depth = @dao_chieu ? @do_day : -@do_day
    hover_idx = detect_hover_cell(cells, normal) if @noi_bo && @state == 3
    cells.each_with_index do |cell_pts, i|
      faded = @noi_bo && @state == 3 && hover_idx && i != hover_idx
      draw_box(cell_pts, normal, depth, view, faded: faded)
    end
    if @noi_bo && @state == 3 && hover_idx
      vec = make_depth_vec(normal, depth)
      active_pts = cells[hover_idx]
      active_top = active_pts.map { |pt| pt.offset(vec) }
      ZSU::View.draw2d_loop(active_pts, guide: false)
      ZSU::View.draw2d_loop(active_top, guide: false)
      active_pts.length.times do |i|
        j = (i + 1) % active_pts.length
        ZSU::View.draw2d_loop(
          [active_pts[i], active_pts[j], active_top[j], active_top[i]], guide: false
        )
      end
    end
    draw_distances(view)
    draw_division_previews(normal) if @state == 3
  end
  def detect_hover_cell(cells, normal)
    return nil unless @last_ray && normal
    hit = ray_hit_plane(@last_ray, @pts[0], normal)
    return nil unless hit
    cells.each_with_index do |cell_pts, i|
      return i if point_in_cell?(hit, cell_pts, normal)
    end
    nil
  end
  def draw_free_polygon(view)
    return unless @pts_tu_do && @pts_tu_do.length >= 2
    preview_pts = @pts_tu_do.dup
    preview_pts << @pt_tu_do_ht if @pt_tu_do_ht
    if preview_pts.length >= 3
      normal = @normal_tu_do
      unless normal
        v1 = preview_pts[1] - preview_pts[0]
        v2 = preview_pts[2] - preview_pts[0]
        normal = v1.cross(v2)
        normal.normalize! if normal.length > 0
      end
      if normal && normal.length > 0
        depth = @dao_chieu ? @do_day : -@do_day
        draw_box(preview_pts, normal, depth, view)
      else
        preview_pts.each_cons(2) { |a, b| ZSU::View.draw_lines([a, b]) }
      end
    else
      ZSU::View.draw_lines([preview_pts[0], preview_pts[1]])
    end
  end
  def make_depth_vec(normal, depth)
    vec = normal.clone
    vec.length = depth.abs
    vec.reverse! if depth < 0
    vec
  end
  def draw_box(cell_pts, normal, depth, view, faded: false)
    return unless normal && depth != 0
    vec = make_depth_vec(normal, depth)
    top_pts = cell_pts.map { |pt| pt.offset(vec) }
    face_c = faded ? ZSU::View.sub_face_color : nil
    edge_c = faded ? sub_edge_color : nil
    ZSU::View.draw_loop(cell_pts, color: edge_c, guide: true)
    ZSU::View.draw_loop(top_pts, color: edge_c, guide: true)
    cell_pts.length.times do |i|
      ZSU::View.draw_lines([cell_pts[i], top_pts[i]], color: edge_c, guide: true)
    end
    ZSU::View.draw_polygon(cell_pts, color: face_c, line: false)
    ZSU::View.draw_polygon(top_pts, color: face_c, line: false)
    cell_pts.length.times do |i|
      j = (i + 1) % cell_pts.length
      ZSU::View.draw_polygon(
        [cell_pts[i], cell_pts[j], top_pts[j], top_pts[i]], color: face_c, line: false
      )
    end
  end
  def draw_distance_plane(left, right, normal, depth)
    return unless normal && depth != 0
    vec = make_depth_vec(normal, depth)
    ZSU::View.draw2d_polygon([left, right, right.offset(vec), left.offset(vec)])
  end
  def draw_gap_preview(p1, p2, gap_dir, normal, depth)
    gap = @ho_giua_cac_canh
    return if gap.abs < 0.001
    return unless normal && depth != 0
    axis = gap_dir.length > 0 ? gap_dir.normalize : return
    depth_vec = make_depth_vec(normal, depth)
    case @chia_canh_le
    when :dau
      ve_gap_box(p1, p2, axis, gap, depth_vec)
    when :cuoi
      ve_gap_box(p1, p2, axis, -gap, depth_vec)
    else
      half = gap / 2.0
      ve_gap_box(p1, p2, axis, half, depth_vec)
      ve_gap_box(p1, p2, axis, -half, depth_vec)
    end
  end
  def ve_gap_box(p1, p2, axis, dist, depth_vec)
    v = Geom::Vector3d.new(axis.x * dist, axis.y * dist, axis.z * dist)
    front = [p1, p1.offset(v), p2.offset(v), p2]
    back = front.map { |pt| pt.offset(depth_vec) }
    ZSU::View.draw_loop(front, guide: true)
    ZSU::View.draw_loop(back, guide: true)
    front.each_with_index { |fp, i| ZSU::View.draw_lines([fp, back[i]], guide: true) }
  end
  def draw_division_previews(normal)
    return unless @pts[0] && @pts[1] && @pts[3]
    depth = @dao_chieu ? @do_day : -@do_day
    vec_x = @pts[1] - @pts[0]
    vec_y = @pts[3] - @pts[0]
    ov = canh_offset_vec
    unless @ds_o
      @diem_chia_tang.each do |dp|
        dp = dp.offset(ov) if ov
        draw_clipped_division(dp, dp.offset(vec_x), normal, depth)
      end
      @diem_chia_khoang.each do |dp|
        dp = dp.offset(ov) if ov
        draw_clipped_division(dp, dp.offset(vec_y), normal, depth)
      end
    end
    draw_current_division(normal, depth, vec_x, vec_y) if @diem_chia_ht
  end
  def draw_clipped_division(p1, p2, normal, depth)
    p1, p2 = clip_division_line(p1, p2, normal)
    draw_distance_plane(p1, p2, normal, depth) if p1 && p2
  end
  def draw_current_division(normal, depth, vec_x, vec_y)
    khoang = @che_do_chia == :khoang
    p1, p2 = division_line_endpoints(khoang ? :khoang : :tang, vec_x, vec_y)
    gap_dir = khoang ? vec_x : vec_y
    p1, p2 = clip_division_line(p1, p2, normal)
    return unless p1 && p2
    ov = canh_offset_vec
    if ov
      p1 = p1.offset(ov)
      p2 = p2.offset(ov)
    end
    draw_distance_plane(p1, p2, normal, depth)
    draw_gap_preview(p1, p2, gap_dir, normal, depth)
  end
  def division_line_endpoints(mode, vec_x, vec_y)
    khoang = mode == :khoang
    span_vec = khoang ? vec_y : vec_x
    if @noi_bo && @o_hover && @ds_o
      vec_n = span_vec.length > 0 ? span_vec.normalize : nil
      return nil unless vec_n
      cell = @ds_o[@o_hover]
      idx_s, idx_e = khoang ? [2, 3] : [0, 1]
      [@diem_chia_ht.offset(vec_n, cell[idx_s]),
       @diem_chia_ht.offset(vec_n, cell[idx_e])]
    else
      [@diem_chia_ht, @diem_chia_ht.offset(span_vec)]
    end
  end
  def draw_distances(view)
    return unless @hien_thi_kich_thuoc
    cells = get_grid_cells
    return if cells.empty?
    precision = ZSU::Model.get_unit_precision
    cells.each do |cell_pts|
      next if cell_pts.length < 4
      w = cell_pts[0].distance(cell_pts[1]).to_mm
      h = cell_pts[0].distance(cell_pts[3]).to_mm
      text_w = format("%.#{precision}f", w)
      text_h = format("%.#{precision}f", h)
      text = "#{text_w} x #{text_h}"
      n = cell_pts.length.to_f
      center = Geom::Point3d.new(
        cell_pts.sum(&:x) / n,
        cell_pts.sum(&:y) / n,
        cell_pts.sum(&:z) / n
      )
      ZSU::View.draw2d_text(text, center)
    end
  end
  def ve_kich_thuoc_chia(face_pts_list)
    return unless @hien_thi_kich_thuoc && face_pts_list && !face_pts_list.empty?
    precision = ZSU::Model.get_unit_precision
    face_pts_list.each do |cell_pts|
      next if cell_pts.length < 4
      w = cell_pts[0].distance(cell_pts[1]).to_mm
      h = cell_pts[0].distance(cell_pts[3]).to_mm
      text = "#{format("%.#{precision}f", w)} x #{format("%.#{precision}f", h)}"
      n = cell_pts.length.to_f
      center = Geom::Point3d.new(
        cell_pts.sum(&:x) / n,
        cell_pts.sum(&:y) / n,
        cell_pts.sum(&:z) / n
      )
      ZSU::View.draw2d_text(text, center)
    end
  end
  def tinh_face_chia
    return [] unless @chia_pts && @pts_noi_bat && @pts_noi_bat.length == 4
    sp1, sp2 = @chia_pts
    off_a, off_b = do_lech_khe
    if @chia_truc == :a
      gap_vec = (@pts_noi_bat[1] - @pts_noi_bat[0]).normalize
      sp1a = sp1.offset(gap_vec, -off_a); sp2a = sp2.offset(gap_vec, -off_a)
      sp1b = sp1.offset(gap_vec,  off_b); sp2b = sp2.offset(gap_vec,  off_b)
      [
        [@pts_noi_bat[0], sp1a, sp2a, @pts_noi_bat[3]],
        [sp1b, @pts_noi_bat[1], @pts_noi_bat[2], sp2b]
      ]
    else
      gap_vec = (@pts_noi_bat[3] - @pts_noi_bat[0]).normalize
      sp1a = sp1.offset(gap_vec, -off_a); sp2a = sp2.offset(gap_vec, -off_a)
      sp1b = sp1.offset(gap_vec,  off_b); sp2b = sp2.offset(gap_vec,  off_b)
      [
        [@pts_noi_bat[0], @pts_noi_bat[1], sp2a, sp1a],
        [sp1b, sp2b, @pts_noi_bat[2], @pts_noi_bat[3]]
      ]
    end
  end
  def canh_offset_vec
    return nil if @canh_cach_mat_goc == 0
    normal = get_normal
    return nil unless normal && normal.length > 0
    vec = normal.clone
    vec.length = @canh_cach_mat_goc.abs
    vec.reverse! if @canh_cach_mat_goc > 0
    vec.reverse! if @dao_chieu
    vec
  end
  def offset_cells(cells)
    ov = canh_offset_vec
    return cells unless ov
    cells.map { |cell_pts| cell_pts.map { |pt| pt.offset(ov) } }
  end
  def get_normal
    return @normal_tu_do if free_mode? && @normal_tu_do
    return nil if @pts.length < 3 || !@pts[0] || !@pts[1] || !@pts[3]
    vec1 = @pts[1] - @pts[0]
    vec2 = @pts[3] - @pts[0]
    normal = vec1.cross(vec2)
    normal.normalize! if normal.length > 0
    normal
  end
  def ray_hit_plane(ray, plane_pt, plane_normal)
    denom = ray[1] % plane_normal
    return nil if denom.abs < 1e-10
    w = plane_pt - ray[0]
    t = (w % plane_normal) / denom
    return nil if t < 0
    ray[0].offset(ray[1], t)
  end
  def project_to_free_plane(pt)
    return pt unless @normal_tu_do && @pts_tu_do && @pts_tu_do.length >= 3
    v = pt - @pts_tu_do[0]
    dist = v % @normal_tu_do
    pt.offset(@normal_tu_do, -dist)
  end
  def project_point_to_axis(pt_start, pt_end)
    vec = pt_end - pt_start
    line = [pt_start, vec]
    pt = nil
    if @ip_valid
      projected = @ip.position.project_to_line(line)
      if vec.length > 0
        v = projected - pt_start
        t = (v % vec) / (vec % vec)
        pt = @ip.position if t > 0.01 && t < 0.99
      end
    end
    if pt.nil?
      return :no_ray unless @last_ray
      pt = Geom.closest_points(line, @last_ray)[0]
    end
    project_to_line_clamped(pt, pt_start, pt_end)
  end
  def determine_2point_normal(p1, p2)
    tolerance = 0.001.mm
    if (p1.x - p2.x).abs < tolerance
      return Geom::Vector3d.new(1, 0, 0)
    elsif (p1.y - p2.y).abs < tolerance
      return Geom::Vector3d.new(0, 1, 0)
    elsif (p1.z - p2.z).abs < tolerance
      return Geom::Vector3d.new(0, 0, 1)
    end
    v = p2 - p1
    z_axis = Geom::Vector3d.new(0, 0, 1)
    normal = v.cross(z_axis)
    return normal.normalize if normal.length > 0
    Geom::Vector3d.new(0, 0, 1)
  end
  def compute_plane_directions(normal)
    normal = normal.normalize
    z_axis = Geom::Vector3d.new(0, 0, 1)
    x_axis = Geom::Vector3d.new(1, 0, 0)
    y_axis = Geom::Vector3d.new(0, 1, 0)
    if normal.parallel?(z_axis)
      [x_axis, y_axis]
    elsif normal.parallel?(x_axis)
      [y_axis, z_axis]
    elsif normal.parallel?(y_axis)
      [x_axis, z_axis]
    else
      u_dir = normal.cross(z_axis)
      u_dir.normalize!
      v_dir = u_dir.cross(normal)
      v_dir.normalize!
      [u_dir, v_dir]
    end
  end
  def compute_rectangle_from_2points(p1, p2, normal)
    u_dir, v_dir = compute_plane_directions(normal)
    diag = p2 - p1
    du = diag % u_dir
    dv = diag % v_dir
    u_vec = Geom::Vector3d.new(u_dir.x * du, u_dir.y * du, u_dir.z * du)
    v_vec = Geom::Vector3d.new(v_dir.x * dv, v_dir.y * dv, v_dir.z * dv)
    @pts[1] = p1.offset(u_vec)
    @pts[2] = @pts[1].offset(v_vec)
    @pts[3] = p1.offset(v_vec)
  end
  def compute_state2_rect(pt1, x, y, view)
    vec_12 = @pts[1] - @pts[0]
    z_axis = Geom::Vector3d.new(0, 0, 1)
    is_perpendicular_to_z = vec_12.length > 0 && (vec_12.normalize % z_axis).abs < 0.01
    if is_perpendicular_to_z && !@ip.face && @ip.degrees_of_freedom == 3 && !@locked_normal
      pt2 = pt1.project_to_line(@pts)
      z_vec = Geom::Vector3d.new(0, 0, 1)
      distance = (pt1.z - pt2.z).abs
      vec = pt1.z > pt2.z ? z_vec : z_vec.reverse
      vec.length = distance
      height = distance
    else
      pt2 = pt1.project_to_line(@pts)
      vec = pt1 - pt2
      height = vec.length
    end
    if height > 0
      square_point = pt2.offset(vec, @pts[0].distance(@pts[1]))
      if view.pick_helper.test_point(square_point, x, y)
        @pts[2] = @pts[1].offset(vec, @pts[0].distance(@pts[1]))
        @pts[3] = @pts[0].offset(vec, @pts[0].distance(@pts[1]))
        view.tooltip = "Square"
      else
        @pts[2] = @pts[1].offset(vec)
        @pts[3] = @pts[0].offset(vec)
      end
    else
      @pts[2] = @pts[1]
      @pts[3] = @pts[0]
    end
  end
  def compute_free_bounding_rect
    return unless @pts_tu_do && @pts_tu_do.length >= 3 && @normal_tu_do
    normal = @normal_tu_do
    v1 = @pts_tu_do[1] - @pts_tu_do[0]
    v1_proj = v1 - normal.clone.tap { |n| n.length = v1 % normal }
    return if v1_proj.length < 0.001
    x_axis = v1_proj.normalize
    y_axis = normal.cross(x_axis).normalize
    coords = @pts_tu_do.map do |pt|
      v = pt - @pts_tu_do[0]
      [(v % x_axis), (v % y_axis)]
    end
    x_min, x_max = coords.map { |c| c[0] }.minmax
    y_min, y_max = coords.map { |c| c[1] }.minmax
    origin = @pts_tu_do[0].offset(x_axis, x_min).offset(y_axis, y_min)
    @pts[0] = origin
    @pts[1] = origin.offset(x_axis, x_max - x_min)
    @pts[2] = origin.offset(x_axis, x_max - x_min).offset(y_axis, y_max - y_min)
    @pts[3] = origin.offset(y_axis, y_max - y_min)
  end
  def clip_polygon_to_rect(polygon, rect, normal)
    result = polygon.dup
    rect.length.times do |i|
      j = (i + 1) % rect.length
      edge_vec = rect[j] - rect[i]
      inward = normal.cross(edge_vec)
      inward.normalize! if inward.length > 0
      result = clip_polygon_by_plane(result, rect[i], inward)
      return nil if result.nil? || result.length < 3
    end
    result
  end
  def clip_polygon_by_plane(pts, plane_pt, plane_normal)
    return nil if pts.nil? || pts.length < 3
    output = []
    pts.length.times do |i|
      curr = pts[i]
      nxt = pts[(i + 1) % pts.length]
      d_curr = (curr - plane_pt) % plane_normal
      d_nxt = (nxt - plane_pt) % plane_normal
      if d_curr >= -0.001
        output << curr
        if d_nxt < -0.001
          t = d_curr / (d_curr - d_nxt)
          output << Geom.linear_combination(1 - t, curr, t, nxt)
        end
      elsif d_nxt >= -0.001
        t = d_curr / (d_curr - d_nxt)
        output << Geom.linear_combination(1 - t, curr, t, nxt)
      end
    end
    output.length >= 3 ? output : nil
  end
  def clip_division_line(p1, p2, normal)
    return [p1, p2] unless free_mode? && @pts_tu_do && @pts_tu_do.length >= 3
    clipped = clip_segment_to_polygon(p1, p2, @pts_tu_do, normal)
    clipped || [nil, nil]
  end
  def clip_segment_to_polygon(p1, p2, polygon, normal)
    t_enter = 0.0
    t_exit = 1.0
    seg = p2 - p1
    polygon.length.times do |i|
      j = (i + 1) % polygon.length
      edge_vec = polygon[j] - polygon[i]
      inward = normal.cross(edge_vec)
      inward.normalize! if inward.length > 0
      d_start = (p1 - polygon[i]) % inward
      d_seg = seg % inward
      if d_seg.abs < 1e-10
        return nil if d_start < -0.001
      else
        t = -d_start / d_seg
        if d_seg > 0
          t_enter = [t_enter, t].max
        else
          t_exit = [t_exit, t].min
        end
        return nil if t_enter > t_exit + 0.001
      end
    end
    return nil if t_enter > t_exit + 0.001
    [Geom.linear_combination(1 - t_enter, p1, t_enter, p2),
     Geom.linear_combination(1 - t_exit, p1, t_exit, p2)]
  end
  def point_in_cell?(point, cell_pts, normal)
    signs = cell_pts.each_index.map do |i|
      a = cell_pts[i]
      b = cell_pts[(i + 1) % cell_pts.length]
      (b - a).cross(point - a) % normal
    end
    signs.all? { |s| s >= -0.01.mm } || signs.all? { |s| s <= 0.01.mm }
  end
  def free_mode?
    @phuong_phap_ve == "tu_do"
  end
  def sub_edge_color
    ec = ZSU::View.edge_color
    c = Sketchup::Color.new(ec.red, ec.green, ec.blue)
    c.alpha = 0.5
    c
  end
  def find_hover_cell_idx(x, y, view)
    return nil unless @ds_o && @pts[0] && @pts[1] && @pts[3]
    normal = get_normal
    return nil unless normal && normal.length > 0
    ray = view.pickray(x, y)
    hit = ray_hit_plane(ray, @pts[0], normal)
    return nil unless hit
    vec_x = @pts[1] - @pts[0]
    vec_y = @pts[3] - @pts[0]
    return nil if vec_x.length < 0.001 || vec_y.length < 0.001
    v = hit - @pts[0]
    x_dist = v % vec_x.normalize
    y_dist = v % vec_y.normalize
    @ds_o.each_with_index do |cell, i|
      cx_s, cx_e, cy_s, cy_e = cell
      return i if x_dist >= cx_s && x_dist <= cx_e && y_dist >= cy_s && y_dist <= cy_e
    end
    nil
  end
  def update_mode_buttons
    if @state == 0
      init_mode_buttons(
        ["Tạo cánh", "Chia cánh"],
        active_proc: -> { @che_do_tool == "tao_canh" ? 0 : 1 },
        on_click: -> (i) {
          new_mode = i == 0 ? "tao_canh" : "chia_canh"
          return if @che_do_tool == new_mode
          @che_do_tool = new_mode
          write("che_do_tool", @che_do_tool)
          @mat_noi_bat = nil
          @pts_noi_bat = nil
          update_status
          Sketchup.active_model.active_view.invalidate
        }
      )
    elsif @state == 3
      init_mode_buttons(
        ["Tổng thể", "Nội bộ"],
        active_proc: -> { @noi_bo ? 1 : 0 },
        on_click: -> (i) {
          new_noi_bo = (i == 1)
          return if @noi_bo == new_noi_bo
          view = Sketchup.active_model.active_view
          toggle_noi_bo(view)
        }
      )
    elsif @state == 1 || @state == 2
      init_mode_buttons(
        ["Cánh trong", "Cánh ngoài"],
        active_proc: -> { @dao_chieu ? 1 : 0 },
        on_click: -> (i) {
          new_reversed = (i == 1)
          return if @dao_chieu == new_reversed
          view = Sketchup.active_model.active_view
          @dao_chieu = new_reversed
          update_status
          view.invalidate
        }
      )
    else
      @mb_labels = nil
    end
  end
end
