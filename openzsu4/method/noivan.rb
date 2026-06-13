class ZSU::Noivan
  include ZSU::Preset
  settings_section 'noi_van'
  def initialize
    ZSU.init_undo
    init_var
  end
  def init_var
    @so_luong_co_dinh = read('so_luong_co_dinh', false)
    @so_luong = read('so_luong', 2).to_i
    @bo_dem_khop = read("bo_dem_khop", 1, true).to_i
    @khoang_cach = read('khoang_cach', 250.0).to_f.mm
    @ti_so_khop_noi = read("ti_so_khop_noi", ZSU::View.grid_scale, true).to_f
    @cach_deu_hai_dau = read('cach_deu_hai_dau', true)
    @cach_truoc = read('cach_truoc', 50.0).to_f.mm
    @cach_sau = read('cach_sau', 50.0).to_f.mm
    @bao_mong = read('bao_mong', false)
    @duong_kinh_dao = read('duong_kinh_dao', 6.0).to_f.mm
    @instance_bao_mong = read('instance_bao_mong', 'ABF_BM')
    @layer_bao_mong = read('layer_bao_mong', 'ABF_BM')
    @instance_bao_mong_am = read('instance_bao_mong_am', 'ABF_BM')
    @layer_bao_mong_am = read('layer_bao_mong_am', 'ABF_BM')
    @mau_bao_mong = read('mau_bao_mong', '210,117,159')
    @mau_bao_mong = @mau_bao_mong.join(',') if @mau_bao_mong.is_a?(Array)
    @kieu_mong = read('kieu_mong', 'duoi_ca')
    @chieu_dai = read('chieu_dai', 50.0).to_f.mm
    @chieu_sau = read('chieu_sau', 20.0).to_f.mm
    @ty_le_khop = read("ty_le_khop", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @mo_rong = read('mo_rong', 20.0).to_f.mm
    @bu_tru_khop_noi = read("bu_tru_khop_noi", (@ti_so_khop_noi - 1.0) * 16, true).to_f.mm
    @bo_goc = [read('bo_goc_mong', 6.0).to_f.mm, @chieu_sau].min
    @mo_rong_mong_am = read('mo_rong_mong_am', false)
    @mo_rong_deu = read('mo_rong_deu', 0.0).to_f.mm
    @mo_rong_chieu_dai = read('mo_rong_chieu_dai', 0.0).to_f.mm
    @mo_rong_chieu_sau = read('mo_rong_chieu_sau', 0.0).to_f.mm
    @do_lech_khop = read("do_lech_khop", @bo_dem_khop - 64, true).to_f.mm
    @presets = read('presets', nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      'Số lượng cố định' => {
        so_luong_co_dinh: [:switch, 'Số lượng cố định'],
        so_luong: [:raw, 'Số lượng mộng', -> { @so_luong_co_dinh }, 1],
        khoang_cach: [:mm, 'Khoảng cách', -> { !@so_luong_co_dinh }, 0],
      },
      'Vị trí' => {
        cach_deu_hai_dau: [:switch, 'Cách đều hai đầu'],
        cach_truoc: [:mm, -> { @cach_deu_hai_dau ? 'Cách hai đầu' : 'Cách trước' },
                     -> { !(@so_luong_co_dinh && @so_luong == 1 && @cach_deu_hai_dau) }],
        cach_sau: [:mm, 'Cách sau',
                   -> { !@cach_deu_hai_dau && !(@so_luong_co_dinh && @so_luong == 1) }],
      },
      'Bào mỏng' => {
        bao_mong: [:switch, 'Bào mỏng'],
        instance_bao_mong: [:text, 'Instance dương', -> { @bao_mong }],
        layer_bao_mong: [:text, 'Layer dương', -> { @bao_mong }],
        instance_bao_mong_am: [:text, 'Instance âm', -> { @bao_mong }],
        layer_bao_mong_am: [:text, 'Layer âm', -> { @bao_mong }],
        mau_bao_mong: [:color, 'Màu sắc', -> { @bao_mong }],
      },
      'Kiểu mộng' => {
        kieu_mong: [:select, 'Kiểu mộng', { 'duoi_ca' => 'Đuôi cá', 'chu_t' => 'Chữ T' }],
        chieu_dai: [:mm, 'Chiều dài'],
        chieu_sau: [:mm, 'Chiều sâu'],
        mo_rong: [:mm, 'Mở rộng'],
        bo_goc_mong: [:mm, 'Bo góc', nil, 0],
      },
      'Mở rộng mộng âm' => {
        mo_rong_mong_am: [:switch, 'Mở rộng mộng âm'],
        mo_rong_deu: [:mm, 'Mở rộng đều', -> { @mo_rong_mong_am }],
        mo_rong_chieu_dai: [:mm, 'Mở rộng chiều dài', -> { @mo_rong_mong_am }],
        mo_rong_chieu_sau: [:mm, 'Mở rộng chiều sâu', -> { @mo_rong_mong_am }],
      }
    )
  end
  def load_preset(s)
    init_preset(:so_luong_co_dinh, s)
    init_preset(:so_luong, s)          { |v| v.to_i }
    init_preset(:khoang_cach, s)       { |v| v.to_f.mm }
    init_preset(:chieu_dai, s)         { |v| v.to_f.mm }
    init_preset(:chieu_sau, s)         { |v| v.to_f.mm }
    init_preset(:kieu_mong, s)
    init_preset(:mo_rong, s)       { |v| v.to_f.mm }
    init_preset(:bo_goc_mong, s)     { |v| [v.to_f.mm, @chieu_sau].min }
    init_preset(:cach_deu_hai_dau, s)
    init_preset(:cach_truoc, s)        { |v| v.to_f.mm }
    init_preset(:cach_sau, s)          { |v| v.to_f.mm }
    init_preset(:mo_rong_mong_am, s)
    init_preset(:mo_rong_deu, s)   { |v| v.to_f.mm }
    init_preset(:mo_rong_chieu_dai, s)    { |v| v.to_f.mm }
    init_preset(:mo_rong_chieu_sau, s)    { |v| v.to_f.mm }
    init_preset(:bao_mong, s)
    init_preset(:instance_bao_mong, s)
    init_preset(:layer_bao_mong, s)
    init_preset(:mau_bao_mong, s)
    init_preset(:instance_bao_mong_am, s)
    init_preset(:layer_bao_mong_am, s)
  end
  def activate
    load_active_preset
    @selected_entities = ZSU::Board.filter_and_fix
    reset_state
    update_status
  end
  def deactivate(view)
    save_active_preset
    view.invalidate
  end
  def reset_state
    @target_faces = []
    @target_face = nil
    @target_parent = nil
    @mortise_parent = nil
    @target_org = []
    @transformation = IDENTITY
    @mortise_cache = {}
    @nearby_cache = {}
    @hit_point = nil
    @hover_normal = nil
  end
  def enableVCB?
    true
  end
  def onUserText(text, view)
    if text.include?(',')
      return if @cach_deu_hai_dau
      parts = text.split(',', 2)
      len1_str = parts[0].strip
      len2_str = parts[1].strip
      unless len1_str.empty?
        len1 = len1_str.to_l.to_mm.to_f
        return if len1 < 0
        @cach_truoc = len1.mm
        write('cach_truoc', len1)
      end
      unless len2_str.empty?
        len2 = len2_str.to_l.to_mm.to_f
        return if len2 < 0
        @cach_sau = len2.mm
        write('cach_sau', len2)
      end
    elsif text.start_with?('/')
      unless @so_luong_co_dinh
        num = text[1..-1].to_l.to_mm.to_f
        return if num < 0
        @khoang_cach = num.mm
        write('khoang_cach', num)
      else
        num = text[1..-1].to_i
        return if num < 1
        @so_luong = num
        write('so_luong', num)
      end
    else
      len = text.to_l.to_mm.to_f
      return if len < 0
      @cach_truoc = len.mm
      write('cach_truoc', len)
    end
    @button_config[:modified] = true if @button_config
    view.invalidate if view
    update_status
  end
  def update_status
    secondary = @so_luong_co_dinh ?
      "Số mộng [/x]: #{@so_luong}" :
      "Khoảng cách [/x]: #{Sketchup.format_length(@khoang_cach)}"
    if @cach_deu_hai_dau
      ZSU.vcb("#{secondary} | Cách hai đầu", Sketchup.format_length(@cach_truoc))
    else
      ZSU.vcb(
        "#{secondary} | Cách trước sau",
        "#{Sketchup.format_length(@cach_truoc)}, #{Sketchup.format_length(@cach_sau)}"
      )
    end
    ZSU.status("Nhấn chuột để tạo mộng.")
  end
  def resume(view)
    view.invalidate
    update_status
  end
  def onKeyDown(key, repeat, flags, view)
    ZSU::Settings.open_settings('noi_van') if key == 192
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    f = ph.picked_face
    parent = ph.best_picked
    unless parent
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
    return unless f
    fb = ZSU::Board.get_cnc_faces(parent)
    all_faces = ZSU.grep_ents(parent, :face)
    return unless fb && all_faces
    band_faces = (all_faces - fb).reject { |face| face.edges.map(&:length).max < @chieu_dai }
    band_faces = band_faces.select { |face| r = find_mortise_parent(face, parent); r && !r.empty? }
    @hit_point = ZSU::View.calc_hit_point(f, tr, x, y, view)
    @hover_normal = f.normal.transform(tr).normalize
    target = band_faces.min_by do |face|
      plane = [face.bounds.center.transform(tr), face.normal.transform(tr)]
      @hit_point.distance_to_plane(plane).abs
    end
    if target
      @target_face = target
      @target_parent = parent
      @transformation = tr
      @target_faces = [{
        face: @target_face, parent: @target_parent, transformation: @transformation
      }]
    else
      reset_state
    end
    view.invalidate
  end
  def find_nearby_groups(parent)
    @nearby_cache ||= {}
    return @nearby_cache[parent.entityID] if @nearby_cache.key?(parent.entityID)
    b1 = parent.bounds
    result = ZSU::Model.active_entities.select { |g|
      next unless ZSU.is_container?(g)
      next if g.hidden? || !g.layer.visible? || g == parent
      next if g.name == '_ABF_Label' || g.name == '_ABF_Intersect'
      b2 = g.bounds
      bb = Geom::BoundingBox.new
      bb.add(b1.min, b1.max, b2.min, b2.max)
      next unless bb.width <= b1.width + b2.width &&
                  bb.height <= b1.height + b2.height &&
                  bb.depth <= b1.depth + b2.depth
      true
    }
    @nearby_cache[parent.entityID] = result
    result
  end
  def find_mortise_parent(face = @target_face, parent = @target_parent)
    return unless face && face.valid? && parent
    @mortise_cache ||= {}
    return @mortise_cache[face.entityID] if @mortise_cache.key?(face.entityID)
    tr = parent.transformation
    sorted = face.edges.sort_by { |e| -e.length }
    e1, e2 = sorted[0], sorted[1]
    unless e1 && e2
      @mortise_cache[face.entityID] = []
      return []
    end
    line1 = e1.vertices.map { |v| v.position.transform(tr) }
    line2 = e2.vertices.map { |v| v.position.transform(tr) }
    target_normal = face.normal.transform(tr).normalize
    target_plane = [face.bounds.center.transform(tr), target_normal]
    result = find_nearby_groups(parent).select { |g|
      g_tr = g.transformation
      largest = ZSU::Board.get_cnc_faces(g)
      next unless largest && largest.size >= 2
      all_edges = ZSU.grep_ents(g, :edge)
      next unless all_edges
      edges = all_edges - largest.flat_map(&:edges).uniq
      edges.any? { |e|
        ep = e.vertices.map { |v| v.position.transform(g_tr) }
        next unless Geom.intersect_line_line(ep, line1) && Geom.intersect_line_line(ep, line2)
        e.faces.any? { |ef|
          ef.normal.transform(g_tr).normalize.reverse.samedirection?(target_normal) &&
            ef.bounds.center.transform(g_tr).distance_to_plane(target_plane).abs < ZSU::TOL
        }
      }
    }
    @mortise_cache[face.entityID] = result
    result
  end
  def edge_contact_points(edge_world, group)
    g_tr_inv = group.transformation.inverse
    p1l = edge_world[0].transform(g_tr_inv)
    p2l = edge_world[1].transform(g_tr_inv)
    pts = []
    ZSU.grep_ents(group, :face).each do |face|
      plane = face.plane
      next unless p1l.distance_to_plane(plane).abs < 1.mm &&
                  p2l.distance_to_plane(plane).abs < 1.mm
      [p1l, p2l].each do |pt|
        cl = face.classify_point(pt)
        pts << pt if cl == Sketchup::Face::PointInside ||
                     cl == Sketchup::Face::PointOnEdge ||
                     cl == Sketchup::Face::PointOnVertex
      end
      face.edges.each do |ef|
        giao = giao_2_doan(p1l, p2l, ef.start.position, ef.end.position)
        pts << giao if giao
      end
    end
    pts.uniq! { |pt| [pt.x.round(4), pt.y.round(4), pt.z.round(4)] }
    pts.map { |pt| pt.transform(group.transformation) }
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
    Geom::Point3d.new(a1.x + t * va.x, a1.y + t * va.y, a1.z + t * va.z)
  end
  def calc_so_luong_mong(distance)
    return @so_luong if @so_luong_co_dinh
    return 1 if @khoang_cach.nil? || @khoang_cach <= 0 || distance <= @khoang_cach
    [((distance / @khoang_cach).round + 1), 1].max
  end
  def compute_joint_geometry
    return unless @target_face && @target_parent && @transformation
    mortise_parents = find_mortise_parent
    return if mortise_parents.nil? || mortise_parents.empty?
    pairs = ZSU::Face.rectangle_edges(@target_face)
    return unless pairs
    e1, e2 = pairs.min_by { |pair|
      a1, a2 = pair[0].vertices.map { |v| v.position.transform(@transformation) }
      a1.distance(a2)
    }
    a1, a2 = e1.vertices.map { |v| v.position.transform(@transformation) }
    b1, b2 = e2.vertices.map { |v| v.position.transform(@transformation) }
    v1 = a1.vector_to(a2)
    v2 = b1.vector_to(b2)
    return unless v1.parallel?(v2)
    if v1.dot(v2) < 0
      b1, b2 = b2, b1
      v2 = b1.vector_to(b2)
    end
    unit_normal = a1.vector_to(a1.project_to_line([b1, v2])).normalize
    unit_v1 = v1.normalize
    orig_mid_a = Geom.linear_combination(0.5, a1, 0.5, a2)
    len = a1.distance(a2)
    transformed_normal = @target_face.normal.transform(@transformation).normalize
    sorted_edges = @target_face.edges.sort_by { |e| -e.length }
    le1 = sorted_edges[0].vertices.map { |v| v.position.transform(@transformation) }
    le2 = sorted_edges[1].vertices.map { |v| v.position.transform(@transformation) }
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

      local_normal = transformed_normal.clone
      test_pt = mid_a.offset(local_normal, 1.mm)
      if !ZSU::Solid.within?(test_pt, mp, false, false)
        local_normal = local_normal.reverse
      end

      if @cach_deu_hai_dau
        cach_truoc = @cach_truoc
        cach_sau = @cach_truoc
      else
        near_start = !@hit_point ||
                     contact_start.distance(@hit_point) <= contact_end.distance(@hit_point)
        cach_truoc = near_start ? @cach_truoc : @cach_sau
        cach_sau = near_start ? @cach_sau : @cach_truoc
      end
      mot_mong_rieng = @so_luong_co_dinh && @so_luong == 1 && !@cach_deu_hai_dau
      cach_sau = 0 if mot_mong_rieng
      if ((total_dist - cach_truoc - cach_sau) / @chieu_dai).floor < 2
        so_luong_mong = 1
      else
        offset_start = cach_truoc + @chieu_dai / 2.0
        offset_end = total_dist - cach_sau - @chieu_dai / 2.0
        next if offset_end <= offset_start
        start_point = mid_a.offset(unit_normal, offset_start)
        end_point = mid_a.offset(unit_normal, offset_end)
        distance = start_point.distance(end_point)
        max_n = (distance / @chieu_dai).floor
        target_n = calc_so_luong_mong(distance)
        so_luong_mong = [max_n > target_n ? target_n : max_n, 1].max
      end
      if so_luong_mong > 1
        next if distance <= @chieu_dai * (so_luong_mong - 1)
      else
        if mot_mong_rieng
          center_offset = near_start ?
            @cach_truoc + @chieu_dai / 2.0 :
            total_dist - @cach_truoc - @chieu_dai / 2.0
          start_point = mid_a.offset(unit_normal, center_offset)
          end_point = start_point
        else
          offset_start = @chieu_dai / 2.0
          offset_end = total_dist - offset_start
          next if offset_end <= offset_start
          start_point = mid_a.offset(unit_normal, offset_start)
          end_point = mid_a.offset(unit_normal, offset_end)
        end
      end
      results << {
        start_point: start_point,
        end_point: end_point,
        unit_v1: unit_v1,
        transformed_normal: local_normal,
        len: len,
        divisor: so_luong_mong > 1 ? so_luong_mong - 1 : 1,
        transform: @transformation,
        so_luong_mong: so_luong_mong,
        chieu_dai: @chieu_dai,
        mortise_parent: mp
      }
    end
    results.empty? ? nil : results
  end
  def compute_joints_geometry
    return unless @target_faces && !@target_faces.empty?
    geometries = []
    new_targets = []
    @target_faces.each do |target|
      @target_face = target[:face]
      @target_parent = target[:parent]
      @transformation = target[:transformation]
      geos = compute_joint_geometry
      next unless geos
      geos.each do |geo|
        geometries << geo
        new_targets << target
      end
    end
    @target_faces = new_targets
    geometries
  end
  def preview_arc_points(f, plane_normal)
    xaxis = f[:center].vector_to(f[:v1])
    return [f[:v1], f[:v2]] if xaxis.length < 0.001
    xaxis.normalize!
    yaxis = plane_normal * xaxis
    cv2 = f[:center].vector_to(f[:v2])
    sweep = Math.atan2(cv2 % yaxis, cv2 % xaxis)
    segments = calculate_segments(f[:radius], sweep.abs)
    (0..segments).map do |j|
      angle = sweep * j.to_f / segments
      f[:center].offset(xaxis, Math.cos(angle) * f[:radius])
                .offset(yaxis, Math.sin(angle) * f[:radius])
    end
  end
  def compute_preview_profile(base_point, tip, unit_perp, v1, half_dai, loe)
    a = base_point.offset(unit_perp, -half_dai)
    b = tip.offset(unit_perp, -(half_dai + loe))
    c = tip.offset(unit_perp, (half_dai + loe))
    d = base_point.offset(unit_perp, half_dai)
    return [a, b, c, d], nil unless @bo_goc > 0
    a_far = a.offset((a - d).normalize, 100.mm)
    d_far = d.offset((d - a).normalize, 100.mm)
    fa = compute_fillet(a, a_far, b, @bo_goc)
    fb = compute_fillet(b, a, c, @bo_goc)
    fc = compute_fillet(c, b, d, @bo_goc)
    fd = compute_fillet(d, d_far, c, @bo_goc)
    return [a, b, c, d], nil unless fa && fb && fc && fd
    fa_pts = preview_arc_points(fa, v1)
    fb_pts = preview_arc_points(fb, v1)
    fc_pts = preview_arc_points(fc, v1)
    fd_pts = preview_arc_points(fd, v1).reverse
    profile = fa_pts + fb_pts + fc_pts + fd_pts
    n_a, n_b, n_c = fa_pts.size, fb_pts.size, fc_pts.size
    line_segs = Set.new([n_a - 1, n_a + n_b - 1, n_a + n_b + n_c - 1, profile.size - 1])
    return profile, line_segs
  end
  def compute_preview_profile_t(base_point, tip, unit_perp, v1, half_dai)
    mrd = @mo_rong
    step = Geom.linear_combination(0.5, base_point, 0.5, tip)
    a = base_point.offset(unit_perp, -half_dai)
    b = step.offset(unit_perp, -half_dai)
    c = step.offset(unit_perp, -(half_dai + mrd))
    d = tip.offset(unit_perp, -(half_dai + mrd))
    e = tip.offset(unit_perp, (half_dai + mrd))
    f = step.offset(unit_perp, (half_dai + mrd))
    g = step.offset(unit_perp, half_dai)
    h = base_point.offset(unit_perp, half_dai)
    pts = [a, b, c, d, e, f, g, h]
    return pts, nil unless @bo_goc > 0
    r = @bo_goc
    a_far = a.offset(unit_perp, -100.mm)
    h_far = h.offset(unit_perp, 100.mm)
    fa = compute_fillet(a, a_far, b, r)
    fb = compute_fillet(b, a, c, r)
    fc = compute_fillet(c, b, d, r)
    fd = compute_fillet(d, c, e, r)
    fe = compute_fillet(e, d, f, r)
    ff = compute_fillet(f, e, g, r)
    fg = compute_fillet(g, f, h, r)
    fh = compute_fillet(h, h_far, g, r)
    return pts, nil unless fa && fb && fc && fd && fe && ff && fg && fh
    fa_pts = preview_arc_points(fa, v1)
    fb_pts = preview_arc_points(fb, v1)
    fc_pts = preview_arc_points(fc, v1)
    fd_pts = preview_arc_points(fd, v1)
    fe_pts = preview_arc_points(fe, v1)
    ff_pts = preview_arc_points(ff, v1)
    fg_pts = preview_arc_points(fg, v1)
    fh_pts = preview_arc_points(fh, v1).reverse
    profile = fa_pts + fb_pts + fc_pts + fd_pts + fe_pts + ff_pts + fg_pts + fh_pts
    n_a = fa_pts.size; n_b = fb_pts.size; n_c = fc_pts.size; n_d = fd_pts.size
    n_e = fe_pts.size; n_f = ff_pts.size; n_g = fg_pts.size
    line_segs = Set.new([
      n_a - 1, n_a + n_b - 1, n_a + n_b + n_c - 1,
      n_a + n_b + n_c + n_d - 1, n_a + n_b + n_c + n_d + n_e - 1,
      n_a + n_b + n_c + n_d + n_e + n_f - 1,
      n_a + n_b + n_c + n_d + n_e + n_f + n_g - 1,
      profile.size - 1
    ])
    return profile, line_segs
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    @datas = compute_joints_geometry
    return unless @datas && !@datas.empty?
    @datas.each do |data|
      next unless data
      so_luong = data[:so_luong_mong]
      unit_perp = (data[:unit_v1] * data[:transformed_normal]).normalize
      normal = data[:transformed_normal]
      v1 = data[:unit_v1]
      (0...so_luong).each do |i|
        t = so_luong == 1 ? 0.5 : i.to_f / data[:divisor]
        base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        half_dai = data[:chieu_dai] / 2.0
        half_len = data[:len] / 2.0
        tip = base_point.offset(normal, @chieu_sau)
        if @kieu_mong == 'chu_t'
          profile, line_segs = compute_preview_profile_t(base_point, tip, unit_perp, v1, half_dai)
        else
          profile, line_segs = compute_preview_profile(
            base_point, tip, unit_perp, v1, half_dai, @mo_rong
          )
        end
        profile = profile.map { |pt| pt.offset([0, 0, @view_dpi]) } if @view_dpi != 0
        front = profile.map { |pt| pt.offset(v1, -half_len) }
        back = profile.map { |pt| pt.offset(v1, half_len) }
        ZSU::View.draw2d_polygon(front)
        ZSU::View.draw2d_polygon(back)
        n = profile.size
        n.times do |j|
          j2 = (j + 1) % n
          has_line = line_segs.nil? || line_segs.include?(j)
          ZSU::View.draw2d_polygon([front[j], back[j], back[j2], front[j2]], line: has_line)
        end
      end
    end
  end
  def draw_rect(ents, pts)
    ents.add_line(pts[0], pts[1])
    ents.add_line(pts[1], pts[2])
    ents.add_line(pts[2], pts[3])
    ents.add_line(pts[3], pts[0])
  end
  def draw_ha_nen(x, z)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    d = @duong_kinh_dao / 2.0
    zmin, zmax = -z / 2.0 - d - 5.mm, z / 2.0 + d + 5.mm
    draw_rect(ents, [
      Geom::Point3d.new(0, 0, zmin),
      Geom::Point3d.new(x, 0, zmin),
      Geom::Point3d.new(x, 0, zmax),
      Geom::Point3d.new(0, 0, zmax),
    ])
    ZSU.find_face(ents)
    layer = ZSU.ensure_tag(@layer_bao_mong)
    grp.name = @instance_bao_mong
    grp.layer = layer
    ents.each { |e| e.layer = layer }
    mat = ZSU.create_color_mat(@mau_bao_mong)
    grp.material = mat
    ents.grep(Sketchup::Face).each { |f| f.material = mat; f.back_material = mat }
    grp
  end
  def compute_fillet(corner, prev_pt, next_pt, d)
    d1 = corner.vector_to(prev_pt).normalize
    d2 = corner.vector_to(next_pt).normalize
    dot = [[(d1 % d2), -1.0].max, 1.0].min
    theta = Math.acos(dot)
    return nil if theta < 0.01
    half_theta = theta / 2.0
    radius = d / 2.0
    tangent_len = radius / Math.tan(half_theta)
    center_dist = radius / Math.sin(half_theta)
    bisector = Geom::Vector3d.linear_combination(0.5, d1, 0.5, d2).normalize
    center = corner.offset(bisector, center_dist)
    {
      center: center, radius: radius,
      v1: corner.offset(d1, tangent_len), v2: corner.offset(d2, tangent_len)
    }
  end
  def calculate_segments(radius, angle)
    [[(angle * radius / 2.5.mm).ceil, 6].max, 240].min
  end
  def draw_fillet_arc(ents, f)
    normal = Geom::Vector3d.new(0, 0, 1)
    xaxis = f[:center].vector_to(f[:v1]).normalize
    yaxis = normal * xaxis
    cv2 = f[:center].vector_to(f[:v2])
    sweep = Math.atan2(cv2 % yaxis, cv2 % xaxis)
    ents.add_arc(
      f[:center], xaxis, normal, f[:radius] * @ty_le_khop, 0, sweep,
      calculate_segments(f[:radius], sweep.abs)
    )
  end
  def draw_tenon(x, y, z, mo_rong = 0, flat: false)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    ents = grp.entities
    ymin, ymax = -y / 2.0, y / 2.0
    zmin = flat ? 0 : -z / 2.0
    if @kieu_mong == 'chu_t'
      mrd = @mo_rong
      step_x = x / 2.0
      pts = [
        Geom::Point3d.new(0, ymin, zmin),
        Geom::Point3d.new(step_x, ymin, zmin),
        Geom::Point3d.new(step_x, ymin - mrd, zmin),
        Geom::Point3d.new(x, ymin - mrd, zmin),
        Geom::Point3d.new(x, ymax + mrd, zmin),
        Geom::Point3d.new(step_x, ymax + mrd, zmin),
        Geom::Point3d.new(step_x, ymax, zmin),
        Geom::Point3d.new(0, ymax, zmin),
      ]
      if @bo_goc > 0
        a_far = pts[0].offset((pts[0] - pts[7]).normalize, 100.mm)
        h_far = pts[7].offset((pts[7] - pts[0]).normalize, 100.mm)
        fa = compute_fillet(pts[0], a_far, pts[1], @bo_goc)
        fb = compute_fillet(pts[1], pts[0], pts[2], @bo_goc)
        fc = compute_fillet(pts[2], pts[1], pts[3], @bo_goc)
        fd = compute_fillet(pts[3], pts[2], pts[4], @bo_goc)
        fe = compute_fillet(pts[4], pts[3], pts[5], @bo_goc)
        ff = compute_fillet(pts[5], pts[4], pts[6], @bo_goc)
        fg = compute_fillet(pts[6], pts[5], pts[7], @bo_goc)
        fh = compute_fillet(pts[7], h_far, pts[6], @bo_goc)
        if fa && fb && fc && fd && fe && ff && fg && fh
          ents.add_line(fh[:v1], fa[:v1])
          ents.add_line(fa[:v2], fb[:v1])
          ents.add_line(fb[:v2], fc[:v1])
          ents.add_line(fc[:v2], fd[:v1])
          ents.add_line(fd[:v2], fe[:v1])
          ents.add_line(fe[:v2], ff[:v1])
          ents.add_line(ff[:v2], fg[:v1])
          ents.add_line(fg[:v2], fh[:v2])
          draw_fillet_arc(ents, fa)
          draw_fillet_arc(ents, fb)
          draw_fillet_arc(ents, fc)
          draw_fillet_arc(ents, fd)
          draw_fillet_arc(ents, fe)
          draw_fillet_arc(ents, ff)
          draw_fillet_arc(ents, fg)
          draw_fillet_arc(ents, fh)
        else
          (0...8).each { |i| ents.add_line(pts[i], pts[(i + 1) % 8]) }
        end
      else
        (0...8).each { |i| ents.add_line(pts[i], pts[(i + 1) % 8]) }
      end
    else
      pts = [
        Geom::Point3d.new(0, ymin, zmin),
        Geom::Point3d.new(x, ymin - @mo_rong, zmin),
        Geom::Point3d.new(x, ymax + @mo_rong, zmin),
        Geom::Point3d.new(0, ymax, zmin),
      ]
      if @bo_goc > 0
        a_far = pts[0].offset((pts[0] - pts[3]).normalize, 100.mm)
        d_far = pts[3].offset((pts[3] - pts[0]).normalize, 100.mm)
        fa = compute_fillet(pts[0], a_far, pts[1], @bo_goc)
        fb = compute_fillet(pts[1], pts[0], pts[2], @bo_goc)
        fc = compute_fillet(pts[2], pts[1], pts[3], @bo_goc)
        fd = compute_fillet(pts[3], d_far, pts[2], @bo_goc)
        if fa && fb && fc && fd
          ents.add_line(fa[:v1], fd[:v1])
          ents.add_line(fa[:v2], fb[:v1])
          ents.add_line(fb[:v2], fc[:v1])
          ents.add_line(fc[:v2], fd[:v2])
          draw_fillet_arc(ents, fa)
          draw_fillet_arc(ents, fb)
          draw_fillet_arc(ents, fc)
          draw_fillet_arc(ents, fd)
        else
          draw_rect(ents, pts)
        end
      else
        draw_rect(ents, pts)
      end
    end
    ZSU.find_face(ents)
    largest_face = ents.grep(Sketchup::Face).max_by(&:area)
    ents.grep(Sketchup::Face).each do |f|
      next if f == largest_face
      edges = f.edges
      f.erase!
      edges.each { |e|
        e.erase! if e.valid? && e.is_a?(Sketchup::Edge) && ZSU::Edge.stray?(e)
      }
    end
    largest_face.reverse! if largest_face.normal.z < 0
    if mo_rong != 0
      old_edges = largest_face.edges.to_a
      if ZSU::Offset.moffset(largest_face, mo_rong, ents)
        old_edges.each { |e| e.erase! if e.valid? }
        largest_face = ents.grep(Sketchup::Face).max_by(&:area)
        largest_face.reverse! if largest_face.normal.z < 0
      end
    end
    if flat
      ext = 6.mm
      ext_y = 6.mm
      base_edge = largest_face.edges.min_by { |e| e.vertices.map { |v| v.position.x }.max }
      d_pt, c_pt = base_edge.vertices.map(&:position).sort_by { |p| p.y }
      d_wide = Geom::Point3d.new(d_pt.x, d_pt.y - ext_y, d_pt.z)
      c_wide = Geom::Point3d.new(c_pt.x, c_pt.y + ext_y, c_pt.z)
      f_pt = Geom::Point3d.new(d_pt.x - ext, d_pt.y - ext_y, d_pt.z)
      e_pt = Geom::Point3d.new(c_pt.x - ext, c_pt.y + ext_y, c_pt.z)
      ents.add_face(d_wide, f_pt, e_pt, c_wide)
      ZSU.intersect_fix(ents)
      ents.grep(Sketchup::Edge).each { |e| e.erase! if e.valid? && e.faces.length >= 2 }
    end
    unless flat
      base_area = largest_face.area
      largest_face.pushpull(z * @ty_le_khop + @do_lech_khop + @bu_tru_khop_noi)
      cap_faces = ents.grep(Sketchup::Face).select { |f| (f.area - base_area).abs < 0.01 }
      longest2 = ents.grep(Sketchup::Edge).sort_by(&:length).last(2)
      back_face = ents.grep(Sketchup::Face).find { |f| (f.edges & longest2).length == 2 }
      exclude_faces = cap_faces + [back_face].compact
      exclude_edges = exclude_faces.flat_map(&:edges).uniq
      (ents.grep(Sketchup::Edge) - exclude_edges).each do |e|
        next unless e.faces.length == 2
        e.soft = e.smooth = true
      end
    end
    if @target_face && @target_face.valid? && @target_face.material
      grp.material = @target_face.material
    elsif @target_parent && @target_parent.material
      grp.material = @target_parent.material
    end
    grp
  end
  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        load_preset(@presets[id.to_s.split('_').last.to_i]['settings'])
      end
      view.invalidate
    else
      return unless @datas && !@datas.empty?
      ZSU.start
      @target_faces.zip(@datas).each do |target, data|
        next unless target && data
        @target_face = target[:face]
        @target_parent = target[:parent]
        @transformation = target[:transformation]
        chieu_dai = data[:chieu_dai]
        @base_tenon = draw_tenon(@chieu_sau, chieu_dai, data[:len])
        @base_ha_nen = @bao_mong ? draw_ha_nen(@chieu_sau, @base_tenon.bounds.height) : nil
        tenons = []
        so_luong = data[:so_luong_mong]
        (0...so_luong).each do |i|
          t = so_luong == 1 ? 0.5 : i.to_f / data[:divisor]
          base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
          xaxis = data[:transformed_normal]
          zaxis = data[:unit_v1]
          yaxis = zaxis * xaxis
          tr = Geom::Transformation.axes(base_point, xaxis, yaxis, zaxis)
          tenon_clone = @base_tenon.copy
          tenon_clone.material = @base_tenon.material
          tenon_clone.transform!(tr)
          tenons << tenon_clone
          if @base_ha_nen && @target_parent && @hover_normal
            ha_nen_clone = @base_ha_nen.copy
            ha_nen_xaxis = data[:transformed_normal]
            ha_nen_yaxis = @hover_normal.reverse
            ha_nen_zaxis = (ha_nen_xaxis * ha_nen_yaxis).normalize
            offset_vec = ha_nen_yaxis.clone
            offset_vec.length = data[:len] / 2.0
            ha_nen_tr = Geom::Transformation.axes(
              base_point.offset(offset_vec), ha_nen_xaxis, ha_nen_yaxis, ha_nen_zaxis
            )
            ha_nen_clone.transform!(ha_nen_tr)
            t_ents = ZSU.get_ents(@target_parent)
            if t_ents
              rel_tr = ZSU.is_container?(@target_parent) ?
                @target_parent.transformation.inverse * ha_nen_clone.transformation :
                ha_nen_clone.transformation
              new_inst = t_ents.add_instance(ha_nen_clone.definition, rel_tr)
              layer = ZSU.ensure_tag(@layer_bao_mong)
              new_inst.name = @instance_bao_mong
              new_inst.layer = layer
              new_inst.entities.each { |e| e.layer = layer }
              new_inst.material = ZSU.create_color_mat(@mau_bao_mong)
              new_inst.set_attribute('ZSU', 'noi_van', true)
              ZSU::ABF.is_intersect(new_inst, true)
            end
            ha_nen_clone.erase!
          end
        end
        @base_tenon.erase! if @base_tenon
        @base_ha_nen.erase! if @base_ha_nen
        @mortise_parent = data[:mortise_parent]
        unless tenons.empty?
          base = tenons.first
          tenons[1..-1].each do |tenon|
            result = base.union(tenon)
            base = result if result
          end
          if @mortise_parent
            if @bao_mong && @hover_normal
              mr_sau = @mo_rong_mong_am ? @mo_rong_chieu_sau : 0
              mr_dai = @mo_rong_mong_am ? @mo_rong_chieu_dai : 0
              mr_deu = @mo_rong_mong_am ? @mo_rong_deu : 0
              mortise_flat = draw_tenon(
                @chieu_sau + mr_sau, chieu_dai + mr_dai,
                0, mr_deu, flat: true
              )
              flat_mat = ZSU.create_color_mat(@mau_bao_mong)
              mortise_flat.material = flat_mat
              mortise_flat.entities.grep(Sketchup::Face).each do |f|
                f.material = flat_mat
                f.back_material = flat_mat
              end
              (0...so_luong).each do |i|
                t = so_luong == 1 ? 0.5 : i.to_f / data[:divisor]
                bp = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
                flat_clone = mortise_flat.copy
                xaxis = data[:transformed_normal]
                zaxis = data[:unit_v1]
                yaxis = zaxis * xaxis
                offset_vec = @hover_normal.clone
                offset_vec.length = data[:len] / 2.0
                flat_tr = Geom::Transformation.axes(bp.offset(offset_vec), xaxis, yaxis, zaxis)
                flat_clone.transform!(flat_tr)
                m_ents = ZSU.get_ents(@mortise_parent)
                if m_ents
                  rel_tr = ZSU.is_container?(@mortise_parent) ?
                    @mortise_parent.transformation.inverse * flat_clone.transformation :
                    flat_clone.transformation
                  new_inst = m_ents.add_instance(flat_clone.definition, rel_tr)
                  flat_layer = ZSU.ensure_tag(@layer_bao_mong_am)
                  new_inst.name = @instance_bao_mong_am
                  new_inst.layer = flat_layer
                  new_inst.entities.each { |e| e.layer = flat_layer }
                  new_inst.material = ZSU.create_color_mat(@mau_bao_mong)
                  new_inst.set_attribute('ZSU', 'noi_van', true)
                  ZSU::ABF.is_intersect(new_inst, true)
                end
                flat_clone.erase!
              end
              mortise_flat.erase!
            elsif @mo_rong_mong_am && (@mo_rong_deu != 0 || @mo_rong_chieu_dai != 0 || @mo_rong_chieu_sau != 0)
              mortise_base = draw_tenon(
                @chieu_sau + @mo_rong_chieu_sau, chieu_dai + @mo_rong_chieu_dai,
                data[:len], @mo_rong_deu
              )
              mortise_tenons = []
              (0...so_luong).each do |i|
                t = so_luong == 1 ? 0.5 : i.to_f / data[:divisor]
                bp = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
                xaxis = data[:transformed_normal]
                zaxis = data[:unit_v1]
                yaxis = zaxis * xaxis
                mc = mortise_base.copy
                mc.material = mortise_base.material
                mc.transform!(Geom::Transformation.axes(bp, xaxis, yaxis, zaxis))
                mortise_tenons << mc
              end
              mortise_base.erase!
              mortise_combined = mortise_tenons.first
              mortise_tenons[1..-1].each do |mt|
                result = mortise_combined.union(mt)
                mortise_combined = result if result
              end
              ZSU::Solid.bulk_trim([@mortise_parent], [mortise_combined])
              ZSU::Purge.fix_all([@mortise_parent])
              mortise_combined.erase! if mortise_combined && mortise_combined.valid?
            else
              ZSU::Solid.bulk_trim([@mortise_parent], [base])
              ZSU::Purge.fix_all([@mortise_parent])
            end
            ZSU::Purge.fix_all([@mortise_parent]) if @mortise_parent&.valid?
          end
          if @target_parent
            entities = ZSU.get_ents(@target_parent)
            next unless entities
            rel_tr = ZSU.is_container?(@target_parent) ?
              @target_parent.transformation.inverse * base.transformation :
              base.transformation
            new_inst = entities.add_instance(base.definition, rel_tr)
            new_inst.explode
            base.erase!
            ZSU.intersect_fix(entities)
            after_faces = entities.grep(Sketchup::Face)
            after_faces = ZSU::Face.delete_inside(after_faces)
            ZSU::Face.merge_coplanar(after_faces)
          end
        end
      end
      ZSU.commit
      reset_state
      view.invalidate
    end
  end
end
