class ZSU::Duckhung
  include ZSU::Preset
  settings_section "duc_khung"
  def initialize
    ZSU.init_undo
    init_var
    reset
  end
  def activate
    reset
    @selection = collect_selection
    load_active_preset
    update_status
  end
  def deactivate(view)
    save_active_preset
    reset
    @selection = nil
    view.invalidate
  end
  def collect_selection
    Sketchup.active_model.selection.select { |e| e.valid? && ZSU.is_container?(e) }
  end
  def resume(view)
    @cached_parent = nil
    view.invalidate
    update_status
  end
  def init_var
    @su_dung_tiet_dien = read("su_dung_tiet_dien", false)
    @instance_tiet_dien = read("instance_tiet_dien", "ABF_DK")
    @layer_tiet_dien = read("layer_tiet_dien", "ABF_DK")
    @van_day_toi_thieu = read("van_day_toi_thieu", 15.0).to_f.mm
    @he_so_vien_kinh = read("he_so_vien_kinh", ZSU::View.grid_scale, true).to_f
    @chieu_rong_toi_thieu = read("chieu_rong_toi_thieu", 0).to_f.mm
    @chieu_rong_khung = read("chieu_rong_khung", 80.0).to_f.mm
    @bo_dem_vien = read("bo_dem_vien", 1, true).to_i
    @bo_goc_trong = read("bo_goc_trong", false)
    @bo_goc_kinh = read("bo_goc_kinh", true)
    @kieu_bo_goc = read("kieu_bo_goc", "cung_loi")
    @ban_kinh_bo_goc = read("ban_kinh_bo_goc", 100.0).to_f.mm
    @cap_do_min = read("cap_do_min", 7).to_i.clamp(1, 10)
    @tao_hem_kinh = read("tao_hem_kinh", true)
    @khu_dao_hem = read("khu_dao_hem", false)
    @ty_le_khung = read("ty_le_khung", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @chieu_rong_hem_kinh = read("chieu_rong_hem_kinh", 10.0).to_f.mm
    @instance_hem_kinh = read("instance_hem_kinh", "ABF_HK")
    @layer_hem_kinh = read("layer_hem_kinh", "ABF_HK")
    @mau_sac_hem_kinh = read("mau_sac_hem_kinh", "210,117,159")
    @mau_sac_hem_kinh = @mau_sac_hem_kinh.join(',') if @mau_sac_hem_kinh.is_a?(Array)
    @mo_phong_kinh = read("mo_phong_kinh", true)
    @do_day_kinh = read("do_day_kinh", 3.0).to_f.mm
    @can_bang_vien = read("can_bang_vien", (@he_so_vien_kinh - 1.0) * 9, true).to_f.mm
    @offset_kinh = read("offset_kinh", -3.0).to_f.mm
    @sai_so_vien = read("sai_so_vien", @bo_dem_vien - 8, true).to_f.mm
    @instance_kinh = read("instance_kinh", "ABF_GL")
    @layer_kinh = read("layer_kinh", "ABF_GL")
    @mau_sac_kinh = read("mau_sac_kinh", "60,175,214")
    @mau_sac_kinh = @mau_sac_kinh.join(',') if @mau_sac_kinh.is_a?(Array)
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Tiết diện" => {
        su_dung_tiet_dien: [:switch, "Sử dụng tiết diện"],
      },
      "Điều kiện đục khung" => {
        van_day_toi_thieu: [:mm, "Ván dày tối thiểu", nil, 0],
        chieu_rong_toi_thieu: [:mm, "Chiều rộng tối thiểu", nil, 0],
      },
      "Chiều rộng khung" => {
        chieu_rong_khung: [:mm, "Chiều rộng khung"],
      },
      "Bo góc trong" => {
        bo_goc_trong: [:switch, "Bo góc trong"],
        bo_goc_kinh: [:switch, "Bo góc kính",
          -> { @bo_goc_trong && (@tao_hem_kinh || @mo_phong_kinh) }],
        kieu_bo_goc: [:select, "Kiểu bo góc",
          {"cung_loi" => "Cung lồi", "cung_lom" => "Cung lõm",
           "vat_cheo" => "Vát chéo"}, :bo_goc_trong],
        ban_kinh_bo_goc: [:mm, "Bán kính", :bo_goc_trong],
        cap_do_min: [:raw, "Cấp độ mịn", :bo_goc_trong, 1, 10],
      },
      "Tạo hèm kính" => {
        tao_hem_kinh: [:switch, "Tạo hèm kính"],
        khu_dao_hem: [:switch, "Khử dao hèm", :tao_hem_kinh],
        chieu_rong_hem_kinh: [:mm, "Chiều rộng", :tao_hem_kinh],
      },
      "Mô phỏng kính" => {
        mo_phong_kinh: [:switch, "Mô phỏng kính"],
        do_day_kinh: [:mm, "Độ dày", :mo_phong_kinh, 0],
        offset_kinh: [:mm, "Offset", :mo_phong_kinh],
      }
    )
    @offset_cache = {}
    recalc_inner_pts
  end
  def load_preset(s)
    init_preset(:su_dung_tiet_dien, s)
    init_preset(:instance_tiet_dien, s)
    init_preset(:layer_tiet_dien, s)
    init_preset(:van_day_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:chieu_rong_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:chieu_rong_khung, s) { |v| v.to_f.mm }
    init_preset(:bo_goc_trong, s)
    init_preset(:bo_goc_kinh, s)
    init_preset(:kieu_bo_goc, s)
    init_preset(:ban_kinh_bo_goc, s) { |v| v.to_f.mm }
    init_preset(:cap_do_min, s) { |v| v.to_i.clamp(1, 10) }
    init_preset(:tao_hem_kinh, s)
    init_preset(:khu_dao_hem, s)
    init_preset(:chieu_rong_hem_kinh, s) { |v| v.to_f.mm }
    init_preset(:instance_hem_kinh, s)
    init_preset(:layer_hem_kinh, s)
    init_preset(:mau_sac_hem_kinh, s)
    init_preset(:mo_phong_kinh, s)
    init_preset(:do_day_kinh, s) { |v| v.to_f.mm }
    init_preset(:offset_kinh, s) { |v| v.to_f.mm }
    init_preset(:instance_kinh, s)
    init_preset(:layer_kinh, s)
    init_preset(:mau_sac_kinh, s)
  end
  def reset
    @cached_parent = nil
    @cached_face = nil
    @cached_pts = nil
    @cached_thickness = nil
    @cached_inner_pts = nil
    @cached_inner_pts_world = nil
    @cached_hem_pts_world = nil
    @shift_mode = false
    @original_face = nil
    @offset_cache = {}
    @cached_bo_goc_segments = nil
    @cached_bo_goc_segments_world = nil
    @cached_arc_centers = nil
    @cached_circle_pts_world = nil
    @hovered_arc_idx = nil
    @disabled_arc_indices = Set.new
    @batch_previews = nil
  end
  def update_preview
    recalc_inner_pts
  end
  def update_status
    ZSU.vcb("Chiều rộng khung", Sketchup.format_length(@chieu_rong_khung))
    ZSU.status("Giữ Shift để đảo mặt tạo hèm.")
  end
  def enableVCB?
    true
  end
  def onUserText(text, view)
    val = text.to_l.to_mm.to_f
    return if val <= 0
    @chieu_rong_khung = val.mm
    write("chieu_rong_khung", val)
    recalc_inner_pts
    update_status
    view.invalidate
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    @mouse_x = x
    @mouse_y = y
    @shift_mode = (flags & CONSTRAIN_MODIFIER_MASK) != 0
    ph = view.pick_helper
    ph.do_pick(x, y)
    f = ph.picked_face
    tr = ph.transformation_at(0)
    parent = ph.best_picked
    unless parent && f && ZSU.is_container?(parent) && parent.transformation.to_a == tr.to_a
      clear_highlight
      view.invalidate
      return
    end
    cache_parent(parent)
    unless @cached_largest_faces && @cached_largest_faces.length == 2 &&
           @cached_largest_faces.all?(&:valid?) &&
           @cached_largest_faces.include?(f) && @cached_thickness
      clear_highlight
      view.invalidate
      return
    end
    if @van_day_toi_thieu > 0 && @cached_thickness < @van_day_toi_thieu &&
       (@cached_thickness - @van_day_toi_thieu).abs > 0.01.mm
      clear_highlight
      view.invalidate
      return
    end
    if @chieu_rong_toi_thieu > 0 && @cached_width < @chieu_rong_toi_thieu &&
       (@cached_width - @chieu_rong_toi_thieu).abs > 0.01.mm
      clear_highlight
      view.invalidate
      return
    end
    if @cached_largest_faces.any? { |lf| lf.loops.length >= 2 }
      clear_highlight
      view.invalidate
      return
    end
    @original_face = f
    picked = @shift_mode ? (@cached_largest_faces - [f]).first || f : f
    prev_face = @cached_face
    update_cached_face(picked, tr)
    prev_hover = @hovered_arc_idx
    @hovered_arc_idx = find_hover_arc_center
    view.invalidate if @cached_face != prev_face || @hovered_arc_idx != prev_hover
  end
  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
      end
      view.invalidate
      return
    end
    if @hovered_arc_idx
      if @disabled_arc_indices.include?(@hovered_arc_idx)
        @disabled_arc_indices.delete(@hovered_arc_idx)
      else
        @disabled_arc_indices.add(@hovered_arc_idx)
      end
      @offset_cache = {}
      recalc_inner_pts
      view.invalidate
      return
    end
    return unless @cached_face && @cached_parent && @cached_thickness
    execute
  end

  def onKeyDown(key, repeat, flags, view)
    if key == ZSU::Settings.key_mo_cai_dat
      ZSU::Settings.open_settings('duc_khung')
      init_var
      view.invalidate
    elsif key == VK_SHIFT
      unless @shift_mode
        @shift_mode = true
        update_picked_face
        view.invalidate
      end
    end
  end

  def onKeyUp(key, repeat, flags, view)
    if key == VK_SHIFT
      if @shift_mode
        @shift_mode = false
        update_picked_face
        view.invalidate
      end
    end
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    return unless @cached_pts && @cached_pts.length >= 3 &&
                  @cached_inner_pts_world && @cached_inner_pts_world.length >= 3
    if @view_dpi != 0
      dpi_vec = [0, 0, @view_dpi]
      @cached_pts = @cached_pts.map { |p| p.offset(dpi_vec) }
      @cached_inner_pts_world = @cached_inner_pts_world.map { |p| p.offset(dpi_vec) }
    end
    if @cached_bo_goc_segments_world
      n = @cached_pts.length
      n.times do |i|
        j = (i + 1) % n
        ZSU::View.draw2d_polygon(
          [@cached_pts[i], @cached_pts[j],
           @cached_bo_goc_segments_world[j].first, @cached_bo_goc_segments_world[i].last],
          line: false
        )
      end
      @cached_bo_goc_segments_world.each_with_index do |seg, i|
        next if seg.length <= 1
        (seg.length - 1).times do |k|
          ZSU::View.draw2d_polygon([@cached_pts[i], seg[k], seg[k + 1]], line: false)
        end
      end
    else
      n = @cached_pts.length
      n.times do |i|
        j = (i + 1) % n
        ZSU::View.draw2d_polygon(
          [@cached_pts[i], @cached_pts[j], @cached_inner_pts_world[j], @cached_inner_pts_world[i]],
          line: false
        )
      end
    end
    ZSU::View.draw2d_loop(@cached_pts)
    ZSU::View.draw2d_loop(@cached_inner_pts_world)
    if @cached_circle_pts_world && @cached_normal_world
      @cached_circle_pts_world.each_with_index do |c, i|
        next unless c
        disabled = @disabled_arc_indices.include?(i)
        if i == @hovered_arc_idx
          old_weight = ZSU::View.edge_weight
          ZSU::View.set_edge_weight(old_weight + 1)
        end
        r = @chieu_rong_khung / 6.0
        if disabled && i != @hovered_arc_idx
          ZSU::View.draw2d_circle(c, @cached_normal_world, r, guide: true, fill: false)
        else
          ZSU::View.draw2d_circle(c, @cached_normal_world, r, fill: false)
        end
        ZSU::View.set_edge_weight(old_weight) if i == @hovered_arc_idx
      end
    end
    if @cached_hem_pts_world && @cached_hem_pts_world.length >= 3
      ZSU::View.draw2d_loop(@cached_hem_pts_world, guide: true)
    end
    @batch_previews&.each { |bp| draw_batch_preview(bp) }
  end
  def draw_batch_preview(bp)
    pts = bp[:pts]
    inner = bp[:inner_pts_world]
    hem = bp[:hem_pts_world]
    segments = bp[:bo_goc_segments_world]
    return unless pts && pts.length >= 3 && inner && inner.length >= 3
    if @view_dpi != 0
      dpi_vec = [0, 0, @view_dpi]
      pts = pts.map { |p| p.offset(dpi_vec) }
      inner = inner.map { |p| p.offset(dpi_vec) }
      hem = hem&.map { |p| p.offset(dpi_vec) }
      segments = segments&.map { |seg| seg.map { |p| p.offset(dpi_vec) } }
    end
    if segments
      n = pts.length
      n.times do |i|
        j = (i + 1) % n
        ZSU::View.draw2d_polygon(
          [pts[i], pts[j], segments[j].first, segments[i].last],
          line: false
        )
      end
      segments.each_with_index do |seg, i|
        next if seg.length <= 1
        (seg.length - 1).times do |k|
          ZSU::View.draw2d_polygon([pts[i], seg[k], seg[k + 1]], line: false)
        end
      end
    else
      n = pts.length
      n.times do |i|
        j = (i + 1) % n
        ZSU::View.draw2d_polygon([pts[i], pts[j], inner[j], inner[i]], line: false)
      end
    end
    ZSU::View.draw2d_loop(pts)
    ZSU::View.draw2d_loop(inner)
    ZSU::View.draw2d_loop(hem, guide: true) if hem && hem.length >= 3
  end
  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@cached_pts) if @cached_pts
    bb
  end
  private
  def cache_parent(parent)
    stale = @cached_largest_faces&.any? { |f| !f.valid? }
    return if @cached_parent == parent && !stale
    @cached_parent = parent
    parent = parent.make_unique
    ZSU::Group.fix_scale(parent)
    @cached_largest_faces = ZSU::Board.get_cnc_faces(parent)
    @cached_thickness = ZSU::Board.calc_thickness(parent)
    bb = parent.definition.bounds
    @cached_width = [bb.width, bb.height, bb.depth].sort[1]
    @cached_face = nil
    @cached_pts = nil
    @cached_inner_pts = nil
    @cached_inner_pts_world = nil
    @cached_hem_pts_world = nil
    @offset_cache = {}
  end
  def clear_highlight
    @cached_face = nil
    @cached_pts = nil
    @cached_normal_world = nil
    @cached_inner_pts = nil
    @cached_inner_pts_world = nil
    @cached_hem_pts_world = nil
    @original_face = nil
    @cached_bo_goc_segments = nil
    @cached_bo_goc_segments_world = nil
    @cached_arc_centers = nil
    @cached_circle_pts_world = nil
    @hovered_arc_idx = nil
    @batch_previews = nil
  end
  def recalc_inner_pts
    return unless @cached_face && @cached_parent
    @offset_cache = {}
    old_face = @cached_face
    @cached_face = nil
    update_cached_face(old_face, @cached_parent.transformation)
  end
  def update_picked_face
    return unless @original_face && @cached_parent &&
                  @cached_largest_faces && @cached_largest_faces.length == 2
    f = @original_face
    picked = @shift_mode ? (@cached_largest_faces - [f]).first || f : f
    update_cached_face(picked, @cached_parent.transformation)
  end
  def update_cached_face(f, tr)
    return unless f
    return if @cached_face == f
    @cached_face = f
    @offset_cache ||= {}
    verts = f.outer_loop.vertices.map { |v| v.position }
    @cached_pts = verts.map { |v| v.transform(tr) }
    @cached_normal_world = f.normal.transform(tr).normalize
    cache_key = f.entityID
    cached = @offset_cache[cache_key]
    if cached &&
       cached[:chieu_rong] == @chieu_rong_khung &&
       cached[:hem_rong] == @chieu_rong_hem_kinh &&
       cached[:gia_cong] == @tao_hem_kinh &&
       cached[:bo_goc_trong] == @bo_goc_trong &&
       cached[:kieu_bo_goc] == @kieu_bo_goc &&
       cached[:ban_kinh_bo_goc] == @ban_kinh_bo_goc &&
       cached[:cap_do_min] == @cap_do_min &&
       cached[:bo_goc_kinh] == @bo_goc_kinh
      @cached_inner_pts = cached[:inner]
      @cached_hem_pts_local = cached[:hem]
      @cached_bo_goc_segments = cached[:segments]
      @cached_arc_centers = cached[:arc_centers]
    else
      @cached_inner_pts = ZSU::Offset.offset_pts(verts, f.normal, -@chieu_rong_khung)
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && @cached_inner_pts
        @cached_inner_pts, @cached_bo_goc_segments, @cached_arc_centers =
          apply_bo_goc_to_pts(@cached_inner_pts, f.normal, @disabled_arc_indices)
      else
        @cached_bo_goc_segments = nil
        @cached_arc_centers = nil
      end
      if @tao_hem_kinh && @cached_inner_pts
        if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
          hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
          @cached_hem_pts_local = ZSU::Offset.offset_pts(verts, f.normal, -hem_offset)
        else
          @cached_hem_pts_local = ZSU::Offset.offset_pts(
            @cached_inner_pts, f.normal, @chieu_rong_hem_kinh
          )
        end
      else
        @cached_hem_pts_local = nil
      end
      @offset_cache[cache_key] = {
        chieu_rong: @chieu_rong_khung, hem_rong: @chieu_rong_hem_kinh,
        gia_cong: @tao_hem_kinh,
        bo_goc_trong: @bo_goc_trong, kieu_bo_goc: @kieu_bo_goc,
        ban_kinh_bo_goc: @ban_kinh_bo_goc, cap_do_min: @cap_do_min,
        bo_goc_kinh: @bo_goc_kinh,
        inner: @cached_inner_pts, hem: @cached_hem_pts_local,
        segments: @cached_bo_goc_segments, arc_centers: @cached_arc_centers
      }
    end
    @cached_inner_pts_world = @cached_inner_pts.map { |p| p.transform(tr) } if @cached_inner_pts
    @cached_hem_pts_world = @cached_hem_pts_local&.map { |p| p.transform(tr) }
    @cached_bo_goc_segments_world = @cached_bo_goc_segments&.map { |seg|
      seg.map { |p| p.transform(tr) }
    }
    if @cached_arc_centers && @bo_goc_trong && @ban_kinh_bo_goc > 0
      c2 = ZSU::Offset.offset_pts(verts, f.normal, -@chieu_rong_khung / 2.0)
      @cached_circle_pts_world = c2 ? @cached_arc_centers.each_with_index.map { |ac, i|
        ac ? c2[i].transform(tr) : nil
      } : nil
    else
      @cached_circle_pts_world = nil
    end
    ssm = detect_soft_smooth_vertices(f)
    @cached_soft_vertices = @cached_pts.map.with_index { |_, i| ssm.key?(i) }
    compute_batch_previews
  end
  def batch_active?
    @selection && @cached_parent && @selection.length > 1 &&
      @selection.include?(@cached_parent)
  end
  def matching_disabled_arcs(target_face)
    return nil unless @cached_face && target_face
    ref_n = @cached_face.outer_loop.vertices.length
    tgt_n = target_face.outer_loop.vertices.length
    ref_n == tgt_n ? @disabled_arc_indices : nil
  end
  def compute_batch_previews
    unless batch_active? && @cached_normal_world
      @batch_previews = nil
      return
    end
    @batch_previews = []
    @selection.each do |p|
      next unless p && p.valid? && p != @cached_parent
      preview = compute_preview_for(p, @cached_normal_world)
      @batch_previews << preview if preview
    end
  end
  def compute_preview_for(parent, ref_normal_world)
    faces = ZSU::Board.get_cnc_faces(parent)
    return nil unless faces && faces.length == 2 && faces.all?(&:valid?)
    return nil if faces.any? { |lf| lf.loops.length >= 2 }
    thickness = ZSU::Board.calc_thickness(parent)
    return nil unless thickness
    if @van_day_toi_thieu > 0 && thickness < @van_day_toi_thieu &&
       (thickness - @van_day_toi_thieu).abs > 0.01.mm
      return nil
    end
    bb = parent.definition.bounds
    width = [bb.width, bb.height, bb.depth].sort[1]
    if @chieu_rong_toi_thieu > 0 && width < @chieu_rong_toi_thieu &&
       (width - @chieu_rong_toi_thieu).abs > 0.01.mm
      return nil
    end
    tr = parent.transformation
    target_face = faces.max_by { |f| f.normal.transform(tr).normalize.dot(ref_normal_world) }
    verts = target_face.outer_loop.vertices.map { |v| v.position }
    pts_world = verts.map { |v| v.transform(tr) }
    inner_pts = ZSU::Offset.offset_pts(verts, target_face.normal, -@chieu_rong_khung)
    return nil unless inner_pts && inner_pts.length >= 3
    disabled_arcs = matching_disabled_arcs(target_face)
    bo_goc_segments = nil
    if @bo_goc_trong && @ban_kinh_bo_goc > 0
      inner_pts, bo_goc_segments, _ =
        apply_bo_goc_to_pts(inner_pts, target_face.normal, disabled_arcs)
    end
    hem_pts_local = nil
    if @tao_hem_kinh
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
        hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
        hem_pts_local = ZSU::Offset.offset_pts(verts, target_face.normal, -hem_offset)
      else
        hem_pts_local = ZSU::Offset.offset_pts(
          inner_pts, target_face.normal, @chieu_rong_hem_kinh
        )
      end
    end
    {
      pts: pts_world,
      inner_pts_world: inner_pts.map { |p| p.transform(tr) },
      hem_pts_world: hem_pts_local&.map { |p| p.transform(tr) },
      bo_goc_segments_world: bo_goc_segments&.map { |seg|
        seg.map { |p| p.transform(tr) }
      }
    }
  end
  def execute
    parent = @cached_parent
    face = @cached_face
    thickness = @cached_thickness
    return unless parent && face && thickness
    batch_mode = @selection && @selection.any? { |e| e == parent } && @selection.length > 1
    ref_normal_world = face.normal.transform(parent.transformation).normalize
    targets = []
    if batch_mode
      @selection.each do |p|
        next unless p && p.valid?
        if p == parent
          targets << [parent, face, thickness, @disabled_arc_indices]
        else
          target = p.make_unique
          ZSU::Group.fix_scale(target)
          faces = ZSU::Board.get_cnc_faces(target)
          next unless faces && faces.length == 2 && faces.all?(&:valid?)
          tr = target.transformation
          target_face = faces.max_by { |f| f.normal.transform(tr).normalize.dot(ref_normal_world) }
          target_thickness = ZSU::Board.calc_thickness(target)
          targets << [target, target_face, target_thickness, matching_disabled_arcs(target_face)]
        end
      end
    else
      targets << [parent, face, thickness, @disabled_arc_indices]
    end
    ZSU.start(false)
    begin
      targets.each { |p, f, t, d| execute_one(p, f, t, d) }
      ZSU.commit
    rescue => e
      ZSU.commit
      puts "ZSU::Duckhung error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
    reset
    Sketchup.active_model.active_view.invalidate
  end
  def execute_one(parent, face, thickness, disabled_arcs)
    return unless parent && parent.valid? && face && face.valid? && thickness
    if @van_day_toi_thieu > 0 && thickness < @van_day_toi_thieu &&
       (thickness - @van_day_toi_thieu).abs > 0.01.mm
      return
    end
    bb = parent.definition.bounds
    width = [bb.width, bb.height, bb.depth].sort[1]
    if @chieu_rong_toi_thieu > 0 && width < @chieu_rong_toi_thieu &&
       (width - @chieu_rong_toi_thieu).abs > 0.01.mm
      return
    end
    return if face.loops.length >= 2
    ents = parent.definition.entities
    if @su_dung_tiet_dien
      build_tiet_dien(ents, face, parent, disabled_arcs)
    else
      soft_smooth_map = detect_soft_smooth_vertices(face)
      edges_of_kept = face.edges.to_a
      faces_to_erase = ents.grep(Sketchup::Face) - [face]
      faces_to_erase.each { |f| f.erase! if f.valid? }
      ents.grep(Sketchup::Edge).each do |e|
        next if edges_of_kept.include?(e)
        e.erase! if e.valid? && e.faces.empty?
      end
      remaining_face = ents.grep(Sketchup::Face).first
      build_glass_frame(ents, remaining_face, thickness, soft_smooth_map, parent, disabled_arcs) if remaining_face&.valid?
    end
  end
  def build_tiet_dien(ents, frame_face, parent, disabled_arcs)
    inner_pts = ZSU::Offset.offset_face_pts(frame_face, -@chieu_rong_khung)
    return unless inner_pts && inner_pts.length >= 3
    if @bo_goc_trong && @ban_kinh_bo_goc > 0
      inner_pts, inner_segments =
        apply_bo_goc_to_pts(inner_pts, frame_face.normal, disabled_arcs)
    else
      inner_segments = nil
    end
    layer = ZSU.ensure_tag(@layer_tiet_dien)
    group = ents.add_group
    group.name = @instance_tiet_dien
    group.layer = layer
    group.entities.add_curve(inner_pts + [inner_pts.first])
    group.entities.each { |e| e.layer = layer }
    ZSU.commit
    ZSU::Group.center_origin(group)
    ZSU.start
    if @tao_hem_kinh
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
        hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
        hem_pts = ZSU::Offset.offset_face_pts(frame_face, -hem_offset)
      else
        hem_pts = ZSU::Offset.offset_pts(inner_pts, frame_face.normal, @chieu_rong_hem_kinh)
      end
      hem_segments = (@bo_goc_kinh || !@bo_goc_trong) ? inner_segments : nil
      build_hem(ents, inner_pts, hem_pts, hem_segments) if hem_pts && hem_pts.length >= 3
    end
    if @mo_phong_kinh
      parent_tr = parent.transformation
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
        hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
        glass_pts = ZSU::Offset.offset_face_pts(frame_face, -hem_offset)
      else
        glass_pts = ZSU::Offset.offset_pts(
          inner_pts, frame_face.normal, @chieu_rong_hem_kinh
        )
      end
      glass_pts = inner_pts unless glass_pts && glass_pts.length >= 3
      if @offset_kinh != 0 && glass_pts.length >= 3
        offset_glass = ZSU::Offset.offset_pts(glass_pts, frame_face.normal, -@offset_kinh)
        glass_pts = offset_glass if offset_glass && offset_glass.length >= 3
      end
      world_glass_pts = glass_pts.map { |p| p.transform(parent_tr) }
      glass_layer = ZSU.ensure_tag(@layer_kinh)
      glass_group = ZSU::Model.active_entities.add_group
      glass_group.name = @instance_kinh
      glass_group.layer = glass_layer
      glass_segments = (@bo_goc_kinh || !@bo_goc_trong) ? inner_segments : nil
      draw_loop(glass_group.entities, world_glass_pts, glass_segments)
      glass_face = glass_group.entities.grep(Sketchup::Face).first
      glass_face ||= glass_group.entities.add_face(world_glass_pts)
      if glass_face
        glass_face.pushpull(-@do_day_kinh * @ty_le_khung + @sai_so_vien + @can_bang_vien) if @do_day_kinh > 0
        material = ZSU.create_color_mat(@mau_sac_kinh, 0.25)
        glass_group.material = material
        glass_group.entities.grep(Sketchup::Face).each do |f|
          f.material = nil
          f.back_material = nil
        end
      end
      ZSU.commit
      ZSU::Group.center_origin(glass_group)
      ZSU.start
    end
  end
  def build_glass_frame(ents, frame_face, thickness, soft_smooth_map, parent, disabled_arcs)
    inner_pts = ZSU::Offset.offset_face_pts(frame_face, -@chieu_rong_khung)
    return unless inner_pts && inner_pts.length >= 3
    if @bo_goc_trong && @ban_kinh_bo_goc > 0
      inner_pts, inner_segments =
        apply_bo_goc_to_pts(inner_pts, frame_face.normal, disabled_arcs)
    else
      inner_segments = nil
    end
    largest_verts = frame_face.outer_loop.vertices.map { |v| v.position }
    draw_loop(ents, inner_pts, inner_segments)
    ZSU.intersect_fix(ents)
    inner_face = ents.grep(Sketchup::Face).find do |ff|
      next if ff == frame_face
      verts = ff.vertices.map { |v| v.position }
      verts.all? { |v| inner_pts.any? { |p| v.distance(p) < 0.1.mm } }
    end
    if @mo_phong_kinh && inner_face && inner_face.valid?
      parent_tr = parent.transformation
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
        hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
        glass_pts = ZSU::Offset.offset_face_pts(frame_face, -hem_offset)
      else
        glass_pts = ZSU::Offset.offset_pts(
          inner_pts, frame_face.normal, @chieu_rong_hem_kinh
        )
      end
      glass_pts = inner_pts unless glass_pts && glass_pts.length >= 3
      if @offset_kinh != 0 && glass_pts.length >= 3
        offset_glass = ZSU::Offset.offset_pts(glass_pts, frame_face.normal, -@offset_kinh)
        glass_pts = offset_glass if offset_glass && offset_glass.length >= 3
      end
      world_glass_pts = glass_pts.map { |p| p.transform(parent_tr) }
      glass_layer = ZSU.ensure_tag(@layer_kinh)
      glass_group = ZSU::Model.active_entities.add_group
      glass_group.name = @instance_kinh
      glass_group.layer = glass_layer
      glass_segments = (@bo_goc_kinh || !@bo_goc_trong) ? inner_segments : nil
      draw_loop(glass_group.entities, world_glass_pts, glass_segments)
      glass_face = glass_group.entities.grep(Sketchup::Face).first
      glass_face ||= glass_group.entities.add_face(world_glass_pts)
      if glass_face
        glass_face.pushpull(-@do_day_kinh * @ty_le_khung + @sai_so_vien + @can_bang_vien) if @do_day_kinh > 0
        material = ZSU.create_color_mat(@mau_sac_kinh, 0.25)
        glass_group.material = material
        glass_group.entities.grep(Sketchup::Face).each do |f|
          f.material = nil
          f.back_material = nil
        end
      end
      apply_soft_smooth_at_offsets(
        glass_group.entities, soft_smooth_map, largest_verts, world_glass_pts
      )
      ZSU.commit
      ZSU::Group.center_origin(glass_group)
      ZSU.start
    end
    inner_face.erase! if inner_face && inner_face.valid?
    remaining_face = ents.grep(Sketchup::Face).first
    remaining_face.pushpull(-thickness * @ty_le_khung + @sai_so_vien) if remaining_face && remaining_face.valid?
    apply_soft_smooth_at_offsets(ents, soft_smooth_map, largest_verts, inner_pts)
    apply_soft_smooth_at_offsets(ents, soft_smooth_map, largest_verts, largest_verts)
    if @tao_hem_kinh
      if @bo_goc_trong && @ban_kinh_bo_goc > 0 && !@bo_goc_kinh
        hem_offset = @chieu_rong_khung - @chieu_rong_hem_kinh
        hem_pts = ZSU::Offset.offset_face_pts(frame_face, -hem_offset)
      else
        hem_pts = ZSU::Offset.offset_pts(inner_pts, frame_face.normal, @chieu_rong_hem_kinh)
      end
      hem_segments = (@bo_goc_kinh || !@bo_goc_trong) ? inner_segments : nil
      build_hem(ents, inner_pts, hem_pts, hem_segments) if hem_pts && hem_pts.length >= 3
    end
  end
  def build_hem(frame_ents, inner_pts, hem_pts, segments = nil)
    hem_layer = ZSU.ensure_tag(@layer_hem_kinh)
    hem_group = frame_ents.add_group
    hem_group.name = @instance_hem_kinh
    ents = hem_group.entities
    draw_loop(ents, inner_pts, segments)
    draw_loop(ents, hem_pts, segments)
    longest_idx = (0...inner_pts.length).max_by { |i|
      inner_pts[i].distance(inner_pts[(i + 1) % inner_pts.length])
    }
    v1 = inner_pts[longest_idx]
    v2 = inner_pts[(longest_idx + 1) % inner_pts.length]
    v3 = hem_pts.min_by { |p| p.distance(v1) }
    v4 = hem_pts.min_by { |p| p.distance(v2) }
    e1 = ents.add_line(v1, v3)
    e2 = ents.add_line(v2, v4)
    e1.set_attribute("ZSU", "temp_edge", true) if e1
    e2.set_attribute("ZSU", "temp_edge", true) if e2
    e1.find_faces if e1
    e2.find_faces if e2
    ents.grep(Sketchup::Edge).each do |e|
      e.erase! if e.valid? && e.get_attribute("ZSU", "temp_edge")
    end
    add_khu_dao_circles(hem_group) if @khu_dao_hem
    material = ZSU.create_color_mat(@mau_sac_hem_kinh, 1.0)
    ents.grep(Sketchup::Face).each { |f| f.material = material; f.back_material = material }
    ents.each { |e| e.layer = hem_layer }
    hem_group.layer = hem_layer
    ZSU.commit
    ZSU::Group.center_origin(hem_group)
    ZSU.start
  end
  def add_khu_dao_circles(hem_group)
    ents = hem_group.entities
    hem_face = ents.grep(Sketchup::Face).first
    return unless hem_face && hem_face.valid?
    normal = hem_face.normal
    d_dao = 6.mm
    r_dao = d_dao / 2.0
    outer_verts = hem_face.outer_loop.vertices
    n = outer_verts.size
    centers = []
    outer_verts.each_with_index do |v, i|
      prev_v = outer_verts[(i - 1) % n]
      next_v = outer_verts[(i + 1) % n]
      pos = v.position
      to_prev = pos.vector_to(prev_v.position)
      to_next = pos.vector_to(next_v.position)
      next if to_prev.length < 0.001 || to_next.length < 0.001
      angle = to_prev.angle_between(to_next)
      next unless angle > 0.001 && angle < 140.degrees
      d = to_prev.normalize + to_next.normalize
      next if d.length < 0.001
      d = d.normalize
      test_pt = pos.offset(d, 0.1.mm)
      next unless hem_face.classify_point(test_pt) == Sketchup::Face::PointInside
      vx = pos.offset(d, d_dao - 0.1.mm)
      centers << Geom.linear_combination(0.5, pos, 0.5, vx)
    end
    return if centers.empty?
    centers.each { |c| ents.add_circle(c, normal, r_dao, 24) }
    ZSU.intersect_fix(ents)
    ents.grep(Sketchup::Edge).each do |e|
      next unless e.valid?
      next unless (e.curve.is_a?(Sketchup::ArcCurve) rescue false)
      e.find_faces
    end
    ZSU::Purge.process_coplanar_edge(ents)
  end
  def detect_soft_smooth_vertices(face)
    result = {}
    face_edges = face.edges
    face.outer_loop.vertices.each_with_index do |v, i|
      v.edges.each do |e|
        next if face_edges.include?(e)
        if e.soft? || e.smooth? || e.hidden?
          result[i] = { soft: e.soft?, smooth: e.smooth?, hidden: e.hidden? }
          break
        end
      end
    end
    result
  end
  def apply_soft_smooth_at_offsets(ents, soft_smooth_map, largest_verts, inner_pts)
    return if soft_smooth_map.empty?
    inner_edge_set = Set.new
    inner_pts.each_with_index do |_, i|
      j = (i + 1) % inner_pts.length
      inner_edge_set << [inner_pts[i], inner_pts[j]]
    end
    soft_smooth_map.each do |idx, flags|
      offset_pt = inner_pts[idx]
      next unless offset_pt
      ents.grep(Sketchup::Edge).each do |e|
        verts = e.vertices.map { |v| v.position }
        next unless verts.any? { |v| v.distance(offset_pt) < 0.1.mm }
        on_inner = inner_edge_set.any? do |a, b|
          (verts[0].distance(a) < 0.1.mm && verts[1].distance(b) < 0.1.mm) ||
          (verts[0].distance(b) < 0.1.mm && verts[1].distance(a) < 0.1.mm)
        end
        next if on_inner
        e.soft = flags[:soft] if flags[:soft]
        e.smooth = flags[:smooth] if flags[:smooth]
        e.hidden = flags[:hidden] if flags[:hidden]
      end
    end
  end
  def calc_arc_center(center, dir1, dir2, inward, face_normal, x_axis, y_axis, radius)
    case @kieu_bo_goc
    when "vat_cheo", "cung_lom"
      center
    when "cung_loi"
      e1x = center.offset(dir1, radius)
      e2x = center.offset(dir2, radius)
      bisector = Geom::Vector3d.linear_combination(0.5, dir1, 0.5, dir2).normalize
      perp1 = face_normal.cross(dir1).normalize
      perp1 = perp1.reverse if (perp1 % bisector) < 0
      perp2 = face_normal.cross(dir2).normalize
      perp2 = perp2.reverse if (perp2 % bisector) < 0
      denominator = 1 - (perp1 % perp2)
      return nil if denominator.abs < 0.001
      arc_r = (perp1 % (e2x - e1x)) / denominator
      e1x.offset(perp1, arc_r)
    end
  end
  def find_hover_arc_center
    return nil unless @mouse_x && @mouse_y && @cached_circle_pts_world && @cached_normal_world
    n = @cached_normal_world
    arb = n.parallel?(Z_AXIS) ? X_AXIS : Z_AXIS
    u = n.cross(arb).normalize
    v = n.cross(u).normalize
    @cached_circle_pts_world.each_with_index do |c, i|
      next unless c
      r = @chieu_rong_khung / 6.0
      return i if ZSU::View.point_in_circle_2d?(@mouse_x, @mouse_y, c, r, u, v)
    end
    nil
  end
  def draw_loop(ents, pts, segments = nil, layer = nil)
    if segments
      runs = []
      idx = 0
      segments.each do |seg|
        slice = pts.slice(idx, seg.length)
        if runs.last && runs.last.last.distance(slice.first) < 0.001.mm
          runs.last.concat(slice[1..])
        else
          runs << slice.dup
        end
        idx += seg.length
      end
      if runs.length > 1 && runs.last.last.distance(runs.first.first) < 0.001.mm
        runs[0] = runs.last + runs.first[1..]
        runs.pop
      end
      runs.each_with_index do |run, ri|
        if run.length > 2
          edges = ents.add_curve(run)
          edges.each { |e| e.layer = layer } if layer && edges
        elsif run.length == 2
          e = ents.add_line(run[0], run[1])
          e.layer = layer if layer && e
        end
        next_run = runs[(ri + 1) % runs.length]
        p1 = run.last
        p2 = next_run.first
        next if p1.distance(p2) < 0.001.mm
        e = ents.add_line(p1, p2)
        e.layer = layer if layer && e
      end
    else
      pts.each_with_index do |p, i|
        e = ents.add_line(p, pts[(i + 1) % pts.length])
        e.layer = layer if layer && e
      end
    end
  end
  def apply_bo_goc_to_pts(pts, face_normal, skip_indices = nil)
    n = pts.length
    return [pts, nil] if n < 3
    radius = @ban_kinh_bo_goc
    edge_lens = Array.new(n) { |i| pts[i].distance(pts[(i + 1) % n]) }
    arb = face_normal.parallel?(Z_AXIS) ? X_AXIS : Z_AXIS
    x_axis = face_normal.cross(arb).normalize
    y_axis = face_normal.cross(x_axis).normalize
    per_radius = Array.new(n, radius)
    n.times do |i|
      next if skip_indices&.include?(i)
      prev_i = (i - 1) % n
      next_i = (i + 1) % n
      if skip_indices&.include?(prev_i)
        per_radius[i] = [per_radius[i], edge_lens[prev_i]].min
      else
        per_radius[i] = [per_radius[i], edge_lens[prev_i] / 2.0].min
      end
      if skip_indices&.include?(next_i)
        per_radius[i] = [per_radius[i], edge_lens[i]].min
      else
        per_radius[i] = [per_radius[i], edge_lens[i] / 2.0].min
      end
    end
    segments = []
    arc_centers = []
    n.times do |i|
      prev_i = (i - 1) % n
      next_i = (i + 1) % n
      center = pts[i]
      r = per_radius[i]
      if r < 0.01.mm || edge_lens[prev_i] < 0.01.mm || edge_lens[i] < 0.01.mm
        segments << [pts[i]]
        arc_centers << nil
        next
      end
      dir1 = center.vector_to(pts[prev_i]).normalize
      dir2 = center.vector_to(pts[next_i]).normalize
      outgoing = pts[i].vector_to(pts[next_i])
      inward = face_normal.cross(outgoing).normalize
      if skip_indices && skip_indices.include?(i)
        segments << [pts[i]]
        arc_centers << calc_arc_center(
          center, dir1, dir2, inward, face_normal, x_axis, y_axis, r
        )
        next
      end
      case @kieu_bo_goc
      when "vat_cheo"
        segments << [center.offset(dir1, r), center.offset(dir2, r)]
        arc_centers << center
      when "cung_lom"
        a1 = Math.atan2(dir1 % y_axis, dir1 % x_axis)
        a2 = Math.atan2(dir2 % y_axis, dir2 % x_axis)
        diff = a2 - a1
        diff += 2 * Math::PI while diff < -Math::PI
        diff -= 2 * Math::PI while diff > Math::PI
        so_canh = ZSU::Bogoc.tinh_so_canh(r, diff.abs, @cap_do_min)
        segments << ZSU::Method.build_arc_points(
          center, a1, a1 + diff, r, x_axis, y_axis, so_canh
        )
        arc_centers << center
      when "cung_loi"
        e1x = center.offset(dir1, r)
        e2x = center.offset(dir2, r)
        bisector = Geom::Vector3d.linear_combination(0.5, dir1, 0.5, dir2).normalize
        perp1 = face_normal.cross(dir1).normalize
        perp1 = perp1.reverse if (perp1 % bisector) < 0
        perp2 = face_normal.cross(dir2).normalize
        perp2 = perp2.reverse if (perp2 % bisector) < 0
        denominator = 1 - (perp1 % perp2)
        if denominator.abs < 0.001
          segments << [pts[i]]
          arc_centers << nil
          next
        end
        arc_r = (perp1 % (e2x - e1x)) / denominator
        arc_c = e1x.offset(perp1, arc_r)
        mid_pt = Geom.linear_combination(0.5, e1x, 0.5, e2x)
        test_pt = arc_c.offset(arc_c.vector_to(mid_pt).normalize, arc_r.abs)
        pts_order = (test_pt - center) % inward > 0 ? [e1x, e2x] : [e2x, e1x]
        angles_arc = pts_order.map { |p| Math.atan2((p - arc_c) % y_axis, (p - arc_c) % x_axis) }
        angle_diff = angles_arc[1] - angles_arc[0]
        angle_diff += 2 * Math::PI if angle_diff < 0
        angle_diff = -(2 * Math::PI - angle_diff) if angle_diff > Math::PI
        so_canh = ZSU::Bogoc.tinh_so_canh(arc_r.abs, angle_diff.abs, @cap_do_min)
        segments << ZSU::Method.build_arc_points(arc_c, angles_arc[0], angles_arc[0] + angle_diff,
                                                arc_r.abs, x_axis, y_axis, so_canh)
        arc_centers << arc_c
      end
    end
    [segments.inject([], :+), segments, arc_centers]
  end
end
