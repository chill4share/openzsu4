class ZSU::Bogoc
  include ZSU::Preset
  settings_section "bo_goc"
  def initialize
    ZSU.init_undo
    init_var
    reset_state
  end
  def activate
    load_active_preset
    @cached_parent = nil
    reset_state
    update_status
  end
  def deactivate(view)
    save_active_preset
    reset_state
    view.invalidate
  end
  def resume(view)
    @cached_parent = nil
    view.invalidate
    update_status
  end
  def enableVCB?
    true
  end
  def onUserText(text, view)
    if text.include?('.s') || text.include?('s')
      so_canh = text.gsub(/[^\d]/, '').to_i
      if so_canh >= 3 && so_canh <= 240
        @so_canh = so_canh
        write("so_canh", @so_canh)
        @button_config[:modified] = true if @button_config
        view.invalidate
        update_status
      end
      return
    end
    num = text.to_f
    return if num < 0
    @ban_kinh = num.mm
    @cached_parent = nil
    write("ban_kinh", format("%.2f", num))
    @button_config[:modified] = true if @button_config
    view.invalidate
    update_status
  end
  def onKeyDown(key, repeat, flags, view)
    if key == 192
      ZSU::Settings.open_settings('bo_goc')
    elsif key == 16 && @parent && @cached_valid_edges && !@cached_valid_edges.empty?
      cache_selection_data
      @shift_all = true
      @hover_edge ||= @cached_valid_edges.first
      view.invalidate
    end
  end
  def onKeyUp(key, repeat, flags, view)
    if key == 16
      @shift_all = false
      view.invalidate
    end
  end
  def cache_parent_data(parent, tr)
    stale = @cached_normal_edges&.any? { |e| !e.valid? }
    return if @cached_parent == parent && !stale
    @cached_parent = parent
    ZSU::Group.fix_scale(parent)
    all_edges = ZSU.grep_ents(parent, :edge)
    largest_faces = ZSU::Board.get_cnc_faces(parent)
    largest_edges = largest_faces.flat_map(&:edges)
    @cached_normal_edges = all_edges - largest_edges
    valid_edges = @cached_normal_edges.select do |e|
      v1, v2 = e.vertices
      next false unless v1.edges.size == 3 && v2.edges.size == 3
      v1_others = v1.edges - [e]
      v2_others = v2.edges - [e]
      v1_others.all? { |edge| edge.length >= @ban_kinh } &&
        v2_others.all? { |edge| edge.length >= @ban_kinh }
    end
    @cached_valid_edges = valid_edges
    @cached_radius_map = calc_radius_map(valid_edges)
    @cached_valid_vertices = valid_edges.flat_map(&:vertices).uniq
    @cached_vertex_positions = @cached_valid_vertices.map do |v|
      { vertex: v, world_pos: v.position.transform(tr) }
    end
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    parent = ph.best_picked
    face = ph.picked_face
    unless face && parent && ZSU.is_container?(parent)
      reset_state
      view.invalidate
      return
    end
    tr = ph.transformation_at(0)
    cache_parent_data(parent, tr)
    if (flags & CONSTRAIN_MODIFIER_MASK) != 0 &&
       @cached_valid_edges && !@cached_valid_edges.empty?
      cache_selection_data
      @shift_all = true
      @parent = parent
      @target_face = face
      @hover_edge = @cached_valid_edges.first
      view.invalidate
      return
    end
    @shift_all = false
    hit_point = ZSU::View.calc_hit_point(face, tr, x, y, view)
    if @bo_goc_tu_do || (flags & ALT_MODIFIER_MASK) != 0
      all_edges = ZSU.grep_ents(parent, :edge)
      target_edges = all_edges - face.edges
      points = target_edges.select do |e|
        v1, v2 = e.vertices
        next false unless v1.edges.size == 3 && v2.edges.size == 3
        v1_others = v1.edges - [e]
        v2_others = v2.edges - [e]
        v1_others.all? { |edge| edge.length >= @ban_kinh } &&
          v2_others.all? { |edge| edge.length >= @ban_kinh }
      end.flat_map(&:vertices).uniq
      vertex = points.min_by { |v| v.position.transform(tr).distance(hit_point) }
      edge = target_edges.select { |e| e.vertices.include?(vertex) }
    else
      nearest = @cached_vertex_positions.min_by { |d| d[:world_pos].distance(hit_point) }
      vertex = nearest[:vertex] if nearest && nearest[:vertex].valid?
      edge = @cached_normal_edges.select { |e| e.valid? && e.vertices.include?(vertex) } if vertex
    end
    if vertex && edge && edge.size == 1
      @hover_edge = edge.first
      @target_face = face
      @parent = parent
    else
      reset_state
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
      return
    end
    return unless @hover_edge && @parent && @target_face
    ZSU.start(false)
    @parent = @parent.make_unique
    if (flags & CONSTRAIN_MODIFIER_MASK) != 0
      hover_parent = @parent
      bo_tat_ca(view)
      @selection_cache&.each_key do |sel_parent|
        next if sel_parent == hover_parent
        next unless sel_parent.valid?
        @parent = sel_parent.make_unique
        bo_tat_ca(view)
      end
    else
      edge = find_edge_by_pos(@hover_edge.start.position, @hover_edge.end.position)
      if edge
        @hover_edge = edge
        bo_mot_edge(edge, @parent.transformation)
      end
    end
    ZSU.commit
    @cached_parent = nil
    reset_state
    view.invalidate
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)
    return unless @hover_edge && @parent && @target_face
    tr = @parent.transformation
    if @shift_all
      saved_radius = @ban_kinh
      if @cached_valid_edges
        @cached_valid_edges.each do |e|
          next unless e.valid?
          @ban_kinh = @cached_radius_map[e] || saved_radius
          draw_edge_preview(e, tr)
        end
      end
      @selection_cache&.each do |sel_parent, data|
        next if sel_parent == @parent
        next unless sel_parent.valid?
        sel_tr = sel_parent.transformation
        data[:edges].each do |e|
          next unless e.valid?
          @ban_kinh = data[:radius_map][e] || saved_radius
          draw_edge_preview(e, sel_tr)
        end
      end
      @ban_kinh = saved_radius
    else
      draw_edge_preview(@hover_edge, tr)
    end
  end
  def init_var
    @bo_goc_tu_do = read("bo_goc_tu_do", false)
    @kieu_bo_goc = read("kieu_bo_goc", "loi")
    @bo_dem_cung = read("bo_dem_cung", 1, true).to_i
    @ban_kinh = read("ban_kinh", 100.0).to_f.mm
    @he_so_bo_tinh = read("he_so_bo_tinh", ZSU::View.grid_scale, true).to_f
    @ty_le_cung = read("ty_le_cung", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @do_min_tu_dong = read("do_min_tu_dong", true)
    @can_chinh_cung = read("can_chinh_cung", (@he_so_bo_tinh - 1.0) * 15, true).to_f.mm
    @cap_do_min = read("cap_do_min", 7).to_i.clamp(1, 10)
    @do_lech_cung = read("do_lech_cung", @bo_dem_cung - 32, true).to_f.mm
    @so_canh = read("so_canh", 24).to_i
    @sai_so_cung = read("sai_so_cung", @bo_dem_cung / 2 - 16, true).to_f.mm
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Bo góc tự do" => {
        bo_goc_tu_do: [:switch, "Bo góc tự do"],
      },
      "Kiểu bo góc" => {
        kieu_bo_goc: [:select, "Kiểu bo góc",
                      {"loi" => "Cung lồi", "lom" => "Cung lõm", "cheo" => "Vát chéo"}],
        ban_kinh: [:mm, -> { @kieu_bo_goc == "cheo" ? "Khoảng cách" : "Bán kính" }],
      },
      ["Độ mịn", -> { @kieu_bo_goc != "cheo" }] => {
        do_min_tu_dong: [:switch, "Độ mịn tự động"],
        cap_do_min: [:raw, "Cấp độ mịn", -> { @do_min_tu_dong }, 1, 10],
        so_canh: [:raw, "Số cạnh", -> { !@do_min_tu_dong }, 3, 240],
      }
    )
  end
  def load_preset(preset_settings)
    @ban_kinh = preset_settings["ban_kinh"].to_f.mm
    @kieu_bo_goc = preset_settings["kieu_bo_goc"]
    @so_canh = preset_settings["so_canh"].to_i
    do_min_tu_dong = preset_settings["do_min_tu_dong"]
    @do_min_tu_dong = do_min_tu_dong unless do_min_tu_dong.nil?
    do_min = preset_settings["cap_do_min"]
    @cap_do_min = do_min.to_i.clamp(1, 10) if do_min
    @cached_parent = nil
  end
  def find_edge_by_pos(start_pos, end_pos)
    ZSU.grep_ents(@parent, :edge).find do |e|
      (e.start.position == start_pos && e.end.position == end_pos) ||
        (e.start.position == end_pos && e.end.position == start_pos)
    end
  end
  def bo_mot_edge(edge, tr)
    @hover_edge = edge
    v1 = edge.start.position.transform(tr)
    v2 = edge.end.position.transform(tr)
    normal = v1.vector_to(v2)
    x_axis, y_axis = normal.axes.x, normal.axes.y
    org_positions = edge.vertices.map(&:position)
    vertex = edge.vertices.first
    vertex_pos = vertex.position
    curve_points = get_curve_points(vertex, tr, normal, x_axis, y_axis)
    return unless curve_points
    local_points = curve_points.map { |pt| pt.transform(tr.inverse) }
    if @kieu_bo_goc == "cheo"
      bo_cheo(local_points, vertex, vertex_pos, org_positions)
    else
      vertex2 = edge.vertices.last
      curve_points2 = get_curve_points(vertex2, tr, normal, x_axis, y_axis)
      bo_cung_doi(curve_points, curve_points2, org_positions, tr) if curve_points2
    end
  end
  def find_valid_edges(parent)
    all_edges = ZSU.grep_ents(parent, :edge)
    largest_faces = ZSU::Board.get_cnc_faces(parent)
    largest_edges = largest_faces.flat_map(&:edges)
    normal_edges = all_edges - largest_edges
    normal_edges.select do |e|
      v1, v2 = e.vertices
      next false unless v1.edges.size == 3 && v2.edges.size == 3
      v1_others = v1.edges - [e]
      v2_others = v2.edges - [e]
      v1_others.all? { |edge| edge.length >= @ban_kinh } &&
        v2_others.all? { |edge| edge.length >= @ban_kinh }
    end
  end
  def bo_tat_ca(view)
    tr = @parent.transformation
    valid = find_valid_edges(@parent)
    radius_map = calc_radius_map(valid)
    data = valid.map do |e|
      [e.start.position, e.end.position, radius_map[e] || @ban_kinh]
    end
    saved_radius = @ban_kinh
    data.each do |start_pos, end_pos, r|
      edge = find_edge_by_pos(start_pos, end_pos)
      next unless edge
      @ban_kinh = r
      bo_mot_edge(edge, tr)
    end
  ensure
    @ban_kinh = saved_radius
  end
  def calc_radius_map(valid_edges)
    radius_map = {}
    valid_edges.each { |e| radius_map[e] = @ban_kinh }
    valid_edges.combination(2).each do |e1, e2|
      e1.vertices.each do |v1|
        e2.vertices.each do |v2|
          conn = (v1.edges & v2.edges).first
          next unless conn
          next unless conn.length < 2 * @ban_kinh
          r = conn.length / 2.0
          radius_map[e1] = [radius_map[e1], r].min
          radius_map[e2] = [radius_map[e2], r].min
        end
      end
    end
    radius_map
  end
  def reset_state
    @hover_edge = nil
    @target_face = nil
    @parent = nil
    @shift_all = false
    @selection_cache = nil
  end
  def get_selected_containers
    Sketchup.active_model.selection.select { |e| e.valid? && ZSU.is_container?(e) }
  end
  def cache_selection_data
    @selection_cache = {}
    get_selected_containers.each do |parent|
      next unless parent.valid?
      ZSU::Group.fix_scale(parent)
      valid_edges = find_valid_edges(parent)
      next if valid_edges.empty?
      @selection_cache[parent] = { edges: valid_edges, radius_map: calc_radius_map(valid_edges) }
    end
  end
  def update_status
    ZSU.status("Giữ Shift để bo tất cả. Giữ Alt để bo tự do.")
    label = @kieu_bo_goc == "cheo" ? "Khoảng cách" : "Bán kính"
    ZSU.vcb(label, Sketchup.format_length(@ban_kinh))
  end
  def bo_cheo(local_points, vertex, vertex_pos, org_positions)
    entities = ZSU.get_ents(@parent)
    created_edges = [entities.add_line(local_points[0], local_points[1])]
    edge_positions = created_edges.map { |e| [e.start.position, e.end.position] }
    ZSU.intersect_fix(entities)
    edges = ZSU.grep_ents(@parent, :edge)
    vertices = ZSU.grep_ents(@parent, :vertex)
    vertex = vertices.find { |v| v.position == vertex_pos }
    created_edges = edges.select do |e|
      edge_positions.any? do |pos|
        pos == [e.start.position, e.end.position] ||
          pos == [e.end.position, e.start.position]
      end
    end
    faces = ZSU.grep_ents(@parent, :face)
    target_face = faces.find do |f|
      created_edges.all? { |e| f.edges.include?(e) } && f.vertices.include?(vertex)
    end
    if target_face
      target_face.pushpull(-@hover_edge.length * @ty_le_cung + @do_lech_cung + @can_chinh_cung)
    else
      edges = ZSU.grep_ents(@parent, :edge)
      target_edges = edges.select do |e|
        e.start.position == vertex_pos || e.end.position == vertex_pos
      end
      target_edges.each(&:find_faces)
      faces = ZSU.grep_ents(@parent, :face)
      target_face = faces.find { |f| (f.edges - (created_edges + target_edges)).empty? }
      return unless target_face
      target_face.pushpull(-@hover_edge.length * @ty_le_cung + @do_lech_cung, true)
      ZSU.grep_ents(@parent, :edge).each do |e|
        if org_positions.include?(e.start.position) ||
           org_positions.include?(e.end.position)
          e.erase!
        end
      end
    end
  end
  def bo_cung_doi(curve_points1, curve_points2, org_positions, tr)
    has_inner_loop = false
    cnc_faces = ZSU::Board.get_cnc_faces(@parent)
    cnc_faces.each do |f|
      next unless f.loops.size > 1
      has_inner_loop = true
      f.loops.each do |loop|
        is_inside = loop != f.outer_loop
        loop.edges.each do |e|
          e.set_attribute("ZSU", "inside_loop_edge", is_inside)
        end
      end
    end
    local_points1 = curve_points1.map { |pt| pt.transform(tr.inverse) }
    local_points2 = curve_points2.map { |pt| pt.transform(tr.inverse) }
    if local_points1[0].distance(local_points2[0]) > local_points1[0].distance(local_points2[-1])
      local_points2.reverse!
    end
    n = [local_points1.length, local_points2.length].min
    parent_ents = ZSU.get_ents(@parent)
    parent_ents.add_line(local_points1[0], local_points2[0])
    parent_ents.add_line(local_points1[n - 1], local_points2[n - 1])
    ZSU.intersect_fix(parent_ents)
    edges_to_erase = @hover_edge.vertices.flat_map(&:edges).uniq
    edges_to_erase.each { |e| e.erase! if e.valid? }
    curve1_edges = parent_ents.add_curve(local_points1)
    curve2_edges = parent_ents.add_curve(local_points2)
    curve1_edges.each { |e| e.set_attribute("ZSU", "temp_curve", true) }
    curve2_edges.each { |e| e.set_attribute("ZSU", "temp_curve", true) }
    connecting = []
    (0...n).each do |i|
      connecting << parent_ents.add_line(local_points1[i], local_points2[i])
    end
    connecting.compact!
    (0...n - 1).each do |i|
      parent_ents.add_face(
        local_points1[i], local_points1[i + 1],
        local_points2[i + 1], local_points2[i]
      ) rescue ArgumentError
    end
    ZSU::Edge.smooth(connecting[1..-2]) if connecting.length > 2
    [connecting[0], connecting[-1]].each do |e|
      next unless e && e.valid?
      e.soft = false
      e.smooth = false
    end
    ZSU::Purge.fix_all_hole([@parent])
    if has_inner_loop
      cnc_normals = ZSU::Board.get_cnc_faces(@parent).map(&:normal)
      ZSU.grep_ents(@parent, :face).each do |f|
        next unless cnc_normals.any? { |n| n.parallel?(f.normal) }
        has_inside = f.edges.any? { |e| e.get_attribute("ZSU", "inside_loop_edge") == true }
        has_outside = f.edges.any? { |e| e.get_attribute("ZSU", "inside_loop_edge") == false }
        f.erase! if has_inside && !has_outside
      end
      cnc = ZSU::Board.get_cnc_faces(@parent)
      if cnc.size == 2
        dir = cnc[0].bounds.center.vector_to(cnc[1].bounds.center)
        cnc[0].reverse! if cnc[0].normal % dir > 0
        cnc[1].reverse! if cnc[1].normal % dir < 0
      end
      ZSU.grep_ents(@parent, :edge).each do |e|
        e.delete_attribute("ZSU", "inside_loop_edge") unless e.get_attribute("ZSU", "inside_loop_edge").nil?
      end
    end
    marked_edges = ZSU.grep_ents(@parent, :edge).select do |e|
      e.get_attribute("ZSU", "temp_curve")
    end
    weld_marked_curves(parent_ents, marked_edges)
    ZSU.grep_ents(@parent, :edge).each do |e|
      e.delete_attribute("ZSU", "temp_curve") if e.get_attribute("ZSU", "temp_curve")
    end
  end
  def weld_marked_curves(ents, edges)
    remaining = edges.dup
    while remaining.any?
      chain = [remaining.shift]
      changed = true
      while changed
        changed = false
        remaining.each do |e|
          if chain.any? { |c| (c.vertices & e.vertices).any? }
            chain << e
            remaining.delete(e)
            changed = true
          end
        end
      end
      next if chain.length < 2
      verts = chain.flat_map(&:vertices)
      vert_count = Hash.new(0)
      verts.each { |v| vert_count[v] += 1 }
      end_verts = vert_count.select { |_, c| c == 1 }.keys
      start_vert = end_verts.any? ? end_verts.first : verts.first
      sorted_verts = [start_vert]
      edges_set = chain.dup
      while sorted_verts.length < verts.uniq.length
        current = sorted_verts.last
        found = false
        edges_set.each do |edge|
          if edge.start == current && !sorted_verts.include?(edge.end)
            sorted_verts << edge.end
            edges_set.delete(edge)
            found = true
            break
          elsif edge.end == current && !sorted_verts.include?(edge.start)
            sorted_verts << edge.start
            edges_set.delete(edge)
            found = true
            break
          end
        end
        break unless found
      end
      points = sorted_verts.map(&:position)
      chain.each { |e| e.explode_curve if e.valid? && e.curve }
      temp_group = ents.add_group
      temp_group.entities.add_curve(points)
      temp_group.explode
    end
  end
  def point_inside_face?(point, face, tr)
    local = point.transform(tr.inverse)
    valid = [Sketchup::Face::PointInside,
             Sketchup::Face::PointOnEdge,
             Sketchup::Face::PointOnVertex]
    valid.include?(face.classify_point(local))
  end
  def get_other_edges(vertex)
    edges = vertex.edges - [@hover_edge]
    edges.size == 2 ? edges : nil
  end
  def self.build_arc_points(center, angle_start, angle_end, radius, x_axis, y_axis, so_canh)
    ZSU::Method.build_arc_points(center, angle_start, angle_end, radius, x_axis, y_axis, so_canh)
  end
  def build_arc_points(center, angle_start, angle_end, radius, x_axis, y_axis, so_canh)
    ZSU::Method.build_arc_points(center, angle_start, angle_end, radius, x_axis, y_axis, so_canh)
  end
  def get_curve_points(vertex, tr, normal, x_axis, y_axis)
    other_edges = get_other_edges(vertex)
    return nil unless other_edges
    reference_face = (other_edges[0].faces & other_edges[1].faces).first
    return nil unless reference_face
    center = vertex.position.transform(tr)
    dirs = other_edges.map do |e|
      center.vector_to(e.other_vertex(vertex).position.transform(tr)).normalize
    end
    angles = dirs.map { |d| Math.atan2(d % y_axis, d % x_axis) }.sort
    case @kieu_bo_goc
      when "lom"
        mid_angle = (angles[0] + angles[1]) / 2
        test_pt = center.offset(x_axis, Math.cos(mid_angle) * @ban_kinh)
                        .offset(y_axis, Math.sin(mid_angle) * @ban_kinh)
        angles.reverse! unless point_inside_face?(test_pt, reference_face, tr)
        angles[1] += 2 * Math::PI if angles[1] < angles[0]
        angle_diff = angles[1] - angles[0]
        so_canh = @do_min_tu_dong ? tinh_so_canh(@ban_kinh, angle_diff) : @so_canh
        build_arc_points(center, angles[0], angles[1], @ban_kinh * @ty_le_cung + @sai_so_cung, x_axis, y_axis, so_canh)
      when "loi"
        e1x, e2x = dirs.map { |d| center.offset(d, @ban_kinh * @ty_le_cung + @sai_so_cung) }
        bisector = Geom::Vector3d.linear_combination(0.5, dirs[0], 0.5, dirs[1]).normalize
        perp1 = normal.cross(dirs[0]).normalize
        perp1 = perp1.reverse if (perp1 % bisector) < 0
        perp2 = normal.cross(dirs[1]).normalize
        perp2 = perp2.reverse if (perp2 % bisector) < 0
        denominator = 1 - (perp1 % perp2)
        return nil if denominator.abs < 0.001
        arc_r = (perp1 % (e2x - e1x)) / denominator
        arc_c = e1x.offset(perp1, arc_r)
        mid_pt = Geom.linear_combination(0.5, e1x, 0.5, e2x)
        test_pt = arc_c.offset(arc_c.vector_to(mid_pt).normalize, arc_r.abs)
        pts_order = point_inside_face?(test_pt, reference_face, tr) ? [e1x, e2x] : [e2x, e1x]
        angles = pts_order.map { |p| Math.atan2((p - arc_c) % y_axis, (p - arc_c) % x_axis) }
        angle_diff = angles[1] - angles[0]
        angle_diff += 2 * Math::PI if angle_diff < 0
        angle_diff = -(2 * Math::PI - angle_diff) if angle_diff > Math::PI
        so_canh = @do_min_tu_dong ? tinh_so_canh(arc_r.abs, angle_diff.abs) : @so_canh
        arc_pts = build_arc_points(arc_c, angles[0], angles[0] + angle_diff,
                                   arc_r.abs, x_axis, y_axis, so_canh)
        [pts_order[0]] + arc_pts + [pts_order[1]]
      when "cheo"
        angles.map do |a|
          center.offset(x_axis, Math.cos(a) * (@ban_kinh * @ty_le_cung + @sai_so_cung))
                .offset(y_axis, Math.sin(a) * (@ban_kinh * @ty_le_cung + @sai_so_cung))
        end
    end
  end
  def draw_edge_preview(edge, tr)
    old_hover = @hover_edge
    @hover_edge = edge
    v1 = edge.start.position.transform(tr)
    v2 = edge.end.position.transform(tr)
    normal = v1.vector_to(v2)
    x_axis = normal.axes.x
    y_axis = normal.axes.y
    edge.vertices.each do |vertex|
      pts = build_vertex_points(vertex, tr, normal, x_axis, y_axis)
      pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if pts && @view_dpi != 0
      ZSU::View.draw_polygon(pts)
    end
    other_edges = get_other_edges(edge.vertices[0])
    if other_edges
      v1_pos, v2_pos = edge.vertices.map { |v| v.position.transform(tr) }
      other_edges.each do |oe|
        corr_edge = edge.vertices[1].edges.find do |e|
          e != edge && (e.faces & oe.faces).any?
        end
        next unless corr_edge
        ov1 = oe.other_vertex(edge.vertices[0]).position.transform(tr)
        ov2 = corr_edge.other_vertex(edge.vertices[1]).position.transform(tr)
        dir1 = v1_pos.vector_to(ov1).normalize
        dir2 = v2_pos.vector_to(ov2).normalize
        pts = [v1_pos, v1_pos.offset(dir1, @ban_kinh),
               v2_pos.offset(dir2, @ban_kinh), v2_pos]
        ZSU::View.draw_polygon(pts)
      end
    end
    @hover_edge = old_hover
  end
  def build_vertex_points(vertex, tr, normal, x_axis, y_axis)
    center = vertex.position.transform(tr)
    curve_points = get_curve_points(vertex, tr, normal, x_axis, y_axis)
    return nil unless curve_points
    @kieu_bo_goc == "loi" ? [center, *curve_points] : [center, *curve_points, center]
  end
  def self.tinh_so_canh(radius, angle, cap_do_min)
    level = cap_do_min.to_i.clamp(1, 10)
    target_chord = (11 - level).mm
    estimated = (angle * radius / target_chord).ceil
    estimated.clamp(3, 240)
  end
  def tinh_so_canh(radius, angle)
    ZSU::Bogoc.tinh_so_canh(radius, angle, @cap_do_min)
  end
end
