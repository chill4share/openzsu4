class ZSU::Khudao
  include ZSU::Preset
  settings_section "khu_dao"
  def initialize
    ZSU.init_undo
    init_var
    reset_state
  end
  def init_var
    @su_dung_tiet_dien = read("su_dung_tiet_dien", false)
    @instance_khu = read("instance_khu", "ABF_KD")
    @layer_khu = read("layer_khu", "ABF_KD")
    @ti_so_khu_do = read("ti_so_khu_do", ZSU::View.grid_scale, true).to_f
    @tiet_dien_vuong = read("tiet_dien_vuong", false)
    @ty_le_khu = read("ty_le_khu", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @bo_dem_khu = read("bo_dem_khu", 1, true).to_i
    @duong_kinh_dao = read("duong_kinh_dao", 6.0).to_f.mm
    @khu_dao = read("khu_dao", true)
    @vi_tri_khu = read("vi_tri_khu", "giua")
    @khu_sau_them = read("khu_sau_them", 0.0).to_f.mm
    @canh_dai_toi_thieu = read("canh_dai_toi_thieu", 10.0).to_f.mm
    @co_lap_doi_tuong = read("co_lap_doi_tuong", false)
    @can_chinh_khu = read("can_chinh_khu", (@ti_so_khu_do - 1.0) * 7, true).to_f.mm
    @hieu_chinh_khu = read("hieu_chinh_khu", @bo_dem_khu - 4, true).to_f.mm
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Phương pháp" => {
        su_dung_tiet_dien: [:switch, "Sử dụng tiết diện"],
      },
      "Tiết diện vuông" => {
        tiet_dien_vuong: [:switch, "Tiết diện vuông"],
        duong_kinh_dao: [:mm, "Đường kính dao"],
      },
      "Khử sâu thêm" => {
        khu_sau_them: [:mm, "Khử sâu thêm", nil, 0],
      },
      "Cạnh dài tối thiểu" => {
        canh_dai_toi_thieu: [:mm, "Cạnh dài tối thiểu"],
      },
      "Cô lập đối tượng" => {
        co_lap_doi_tuong: [:switch, "Cô lập đối tượng"],
      }
    )
  end
  def load_preset(preset_settings)
    @duong_kinh_dao = preset_settings["duong_kinh_dao"].to_f.mm
    @khu_dao = preset_settings.fetch("khu_dao", true)
    @tiet_dien_vuong = preset_settings["tiet_dien_vuong"] || false
    @vi_tri_khu = preset_settings["vi_tri_khu"]
    @khu_sau_them = (preset_settings["khu_sau_them"] || 0).to_f.mm
    @canh_dai_toi_thieu = (preset_settings["canh_dai_toi_thieu"] || 6.0).to_f.mm
    @su_dung_tiet_dien = preset_settings["su_dung_tiet_dien"] || false
    @instance_khu = preset_settings["instance_khu"] || "ABF_KD"
    @layer_khu = preset_settings["layer_khu"] || "ABF_KD"
    @cached_parent = nil
  end
  def activate
    load_active_preset
    @isolated = false
    @cached_parent = nil
    @target_data = build_target_auto
    @mode = @target_data.any? ? "Tự động" : "Thủ công"
    if @co_lap_doi_tuong && @target_data.any?
      boards = @target_data.map { |d| d[:board] }
      ZSU.select(boards)
      ZSU::Isolate.start
      @isolated = true
    end
    reset_state
    update_status
  end
  def deactivate(view)
    save_active_preset
    ZSU::Isolate.stop if @isolated
    @isolated = false
    reset_state
    view.invalidate
  end
  def resume(view)
    @cached_parent = nil
    view.invalidate
    update_status
  end
  def update_status
    if @mode == "Tự động"
      ZSU.status("Nhấn Tab để thay đổi vị trí khử dao. Nhấn Enter để bắt đầu khử dao.")
    else
      ZSU.status("Nhấn Tab để thay đổi vị trí khử dao. Giữ Shift để khử dao tất cả các góc.")
    end
    ZSU.vcb("Đường kính dao", Sketchup.format_length(@duong_kinh_dao))
  end
  def refresh_targets
    @cached_parent = nil
    if @mode == "Tự động"
      @target_data = build_target_auto
    elsif @parent
      @target_data = build_target_all_corners(@parent)
    end
  end
  def handle_sb_user_text(text, view)
    result = super
    refresh_targets if result
    result
  end
  def enableVCB?
    true
  end
  def onUserText(text, view)
    num = text.to_f
    return if num < 0
    @duong_kinh_dao = num.mm
    write("duong_kinh_dao", format("%.2f", num))
    @button_config[:modified] = true if @button_config
    refresh_targets
    view.invalidate if view
    update_status
  end
  def process_single(edge, parent, diameter: nil, position: nil, shape: nil)
    ZSU.start
    @khu_dao = true
    @hit_point = nil
    @duong_kinh_dao = diameter if diameter
    @vi_tri_khu = position if position
    @tiet_dien_vuong = shape unless shape.nil?
    return unless edge.valid? && edge.faces.size == 2
    face = case @vi_tri_khu
             when "lon" then edge.faces.max_by(&:area)
             when "nho" then edge.faces.min_by(&:area)
             else edge.faces
           end
    process_overcut(edge, face, parent)
    ZSU.commit
  end
  def build_target_manual
    return unless @hover_edge && @parent
    edge = @hover_edge
    return unless edge.valid?
    return unless edge.faces.size == 2
    face = case @vi_tri_khu
             when "lon" then edge.faces.max_by(&:area)
             when "nho" then edge.faces.min_by(&:area)
             else edge.faces
           end
    [{ edges: [edge], faces: [face], board: @parent, reference_point: nil }]
  end
  def build_target_all_corners(parent)
    return [] unless parent
    target_data = []
    largest_faces = ZSU::Board.get_cnc_faces(parent)
    return [] if largest_faces.empty?
    vertices = largest_faces.flat_map do |face|
      ZSU.find_concave_vertex(face, @canh_dai_toi_thieu, 10)
    end.uniq
    largest_edges = largest_faces.flat_map(&:edges)
    vert_edges = ZSU.grep_ents(parent, :edge) - largest_edges
    edges = []
    faces = []
    vert_edges.each do |e|
      v_near = vertices.any? do |vtx|
        vtx.position.distance(e.start.position) < 0.1.mm ||
          vtx.position.distance(e.end.position) < 0.1.mm
      end
      next unless v_near
      fcs = e.faces.uniq
      next if fcs.length != 2
      face = if @vi_tri_khu == "giua"
               fcs
             else
               @vi_tri_khu == "lon" ? fcs.max_by(&:area) : fcs.min_by(&:area)
             end
      edges << e
      faces << face
    end
    ref = @hit_point
    ref ||= largest_faces.first.bounds.center.transform(parent.transformation)
    target_data << { edges: edges, faces: faces, board: parent, reference_point: ref }
    target_data
  end
  def build_target_auto
    target_data = []
    boards = ZSU::Board.filter_and_fix
    return [] if boards.empty?
    boards.each do |board|
      largest_face = ZSU::Board.get_cnc_faces(board).first
      vertices = ZSU.find_concave_vertex(largest_face, @canh_dai_toi_thieu, 10)
      all_edges = ZSU.grep_ents(board, :edge)
      face_edges = largest_face.edges
      edges = []
      faces = []
      all_edges.each do |e|
        next if face_edges.include?(e)
        v_near = vertices.any? do |vtx|
          vtx.position.distance(e.start.position) < 0.1.mm ||
            vtx.position.distance(e.end.position) < 0.1.mm
        end
        next unless v_near
        fcs = e.faces.uniq
        next if fcs.length != 2
        face = if @vi_tri_khu == "giua"
                 fcs
               else
                 @vi_tri_khu == "lon" ? fcs.max_by(&:area) : fcs.min_by(&:area)
               end
        edges << e
        faces << face
      end
      ref = largest_face.bounds.center.transform(board.transformation)
      if edges.any? && faces.any?
        target_data << { edges: edges, faces: faces, board: board, reference_point: ref }
      end
    end
    target_data
  end
  def onKeyDown(key, repeat, flags, view)
    ZSU::Settings.open_settings('khu_dao') if key == 192
    if key == VK_SHIFT && @parent && Sketchup.active_model.selection.empty?
      @target_data = build_target_all_corners(@parent)
      view.invalidate
    end
  end
  def onKeyUp(key, repeat, flags, view)
    if key == VK_SHIFT && Sketchup.active_model.selection.empty?
      @target_data = @parent && @hover_edge ? build_target_manual : []
      view.invalidate
      update_status
    elsif key == 9
      values = ["lon", "nho", "giua"]
      index = values.index(@vi_tri_khu) || 0
      @vi_tri_khu = values[(index + 1) % values.size]
      write("vi_tri_khu", @vi_tri_khu)
      @button_config[:modified] = true if @button_config
      if @mode == "Tự động"
        @target_data = build_target_auto
      elsif (flags & CONSTRAIN_MODIFIER_MASK) != 0 && @parent
        @target_data = build_target_all_corners(@parent)
      else
        @target_data = build_target_manual
      end
      view.invalidate
      update_status
    end
  end
  def onReturn(view)
    return unless @mode == "Tự động" && @target_data && @target_data.any?
    return if @duong_kinh_dao == 0
    ZSU.start(false)
    @target_data.each do |group|
      board = group[:board]
      edges = group[:edges]
      faces = group[:faces]
      ref = group[:reference_point]
      edges.each_with_index do |edge, i|
        process_overcut(edge, faces[i], board, ref)
      end
    end
    ZSU.commit
    reset_state
    ZSU.select_tool(nil)
  end
  def cache_parent_data(parent, tr)
    return if @cached_parent == parent
    @cached_parent = parent
    ZSU::Group.fix_scale(parent) if parent.respond_to?(:transformation)
    largest_faces = ZSU::Board.get_cnc_faces(parent)
    largest_edges = largest_faces.flat_map(&:edges)
    @cached_vert_edges = ZSU.grep_ents(parent, :edge) - largest_edges
    @cached_concave_vertices = largest_faces.flat_map do |face|
      ZSU.find_concave_vertex(face, @canh_dai_toi_thieu, 10)
    end.uniq
    @cached_vertex_positions = @cached_concave_vertices.map do |v|
      { vertex: v, world_pos: v.position.transform(tr) }
    end
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    return unless @mode == "Thủ công"
    ph = view.pick_helper
    ph.do_pick(x, y)
    parent = ph.best_picked
    face = ph.picked_face
    return unless parent && face && ZSU.is_container?(parent)
    tr = ph.transformation_at(0)
    path = ph.path_at(0)
    cache_parent_data(parent, tr)
    @hit_point = ZSU::View.calc_hit_point(face, tr, x, y, view)
    nearest = @cached_vertex_positions.min_by { |d| d[:world_pos].distance(@hit_point) }
    return unless nearest
    vertex = nearest[:vertex]
    edges_with_vertex = @cached_vert_edges.select { |e| e.vertices.include?(vertex) }
    if edges_with_vertex.size == 1
      e = edges_with_vertex.first
      @hover_edge = e
      @parent = path.find { |el| ZSU.is_container?(el) }
      @parent ||= Sketchup.active_model.active_path&.reverse&.find { |el| ZSU.is_container?(el) }
      if (flags & CONSTRAIN_MODIFIER_MASK) != 0
        @target_data = build_target_all_corners(@parent)
      else
        @target_data = build_target_manual
      end
    else
      @target_data = []
      reset_state
    end
    view.invalidate
  end
  def process_overcut(e, f, p, reference_point = nil)
    return unless @khu_dao
    tr = p.transformation
    radius = @duong_kinh_dao / 2
    ents = ZSU.get_ents(p)
    edge_normal = e.start.position.vector_to(e.end.position).transform(tr).normalize
    transformed_normal = edge_normal.transform(tr.inverse)
    if @su_dung_tiet_dien
      center_data = calc_drill_centers(e, f, tr, reference_point)
      return if center_data.empty?
      center_data.reject! { |c, _| existing_drill_at?(p, c, radius) }
      return if center_data.empty?
      place_drill_groups(center_data, e, f, ents, tr, transformed_normal, radius)
    else
      v_pos, center_point = calc_overcut_center(e, f, tr)
      transformed_center = center_point.transform(tr.inverse)
      cut_overcut_shape(e, f, ents, transformed_center, transformed_normal, radius, tr, v_pos)
    end
  end
  def calc_overcut_center(e, f, tr)
    v = if @hit_point
          e.vertices.min_by { |vtx| vtx.position.transform(tr).distance(@hit_point) }
        else
          e.vertices.first
        end
    v_pos = v.position.transform(tr)
    if @vi_tri_khu == "giua"
      f1, f2 = f
      e1 = f1.edges.find { |ed| ed != e && ed.vertices.include?(v) }
      e2 = f2.edges.find { |ed| ed != e && ed.vertices.include?(v) }
      v1 = (e1.vertices - [v]).first.position.transform(tr)
      v2 = (e2.vertices - [v]).first.position.transform(tr)
      dir = v_pos.vector_to(v1).normalize + v_pos.vector_to(v2).normalize
      offset = @duong_kinh_dao - 0.1.mm
    else
      f = f.is_a?(Array) ? f.max_by(&:area) : f
      se = f.edges.find { |ed| ed != e && ed.vertices.include?(v) }
      v1 = (se.vertices - [v]).first.position.transform(tr)
      dir = v_pos.vector_to(v1)
      offset = @duong_kinh_dao
    end
    vertex_offset = v_pos.offset(dir, offset)
    center_point = Geom.linear_combination(0.5, v_pos, 0.5, vertex_offset)
    [v_pos, center_point]
  end
  def calc_drill_centers(e, f, tr, reference_point)
    center_data = []
    if @vi_tri_khu == "giua"
      return center_data unless f.is_a?(Array)
      f1, f2 = f
      e.vertices.each do |vtx|
        vtx_pos = vtx.position.transform(tr)
        e1 = f1.edges.find { |ed| ed != e && ed.vertices.include?(vtx) }
        e2 = f2.edges.find { |ed| ed != e && ed.vertices.include?(vtx) }
        v1 = (e1.vertices - [vtx]).first.position.transform(tr)
        v2 = (e2.vertices - [vtx]).first.position.transform(tr)
        d = vtx_pos.vector_to(v1).normalize + vtx_pos.vector_to(v2).normalize
        vx = vtx_pos.offset(d, @duong_kinh_dao - 0.1.mm)
        center_data << [Geom.linear_combination(0.5, vtx_pos, 0.5, vx), vtx_pos]
      end
    else
      f = f.is_a?(Array) ? f.max_by(&:area) : f
      shared = f.edges.select { |ed| ed != e && (ed.vertices & e.vertices).size == 1 }
      shared.each do |se|
        common_v = (se.vertices & e.vertices).first
        vc = common_v.position.transform(tr)
        other_v = (se.vertices - [common_v]).first
        d = vc.vector_to(other_v.position.transform(tr))
        vx = vc.offset(d, @duong_kinh_dao)
        center_data << [Geom.linear_combination(0.5, vc, 0.5, vx), vc]
      end
    end
    if center_data.size > 1
      if @hit_point
        center_data = [center_data.min_by { |c, _| c.distance(@hit_point) }]
      elsif reference_point
        center_data = [center_data.min_by { |c, _| c.distance(reference_point) }]
      end
    end
    center_data
  end
  def place_drill_groups(center_data, e, f, ents, tr, normal, radius)
    layer = ZSU.ensure_tag(@layer_khu)
    center_data.each do |cp, vc|
      ZSU.start
      tc = cp.transform(tr.inverse)
      group = ents.add_group
      group.name = @instance_khu
      group.set_attribute("ZSU", "lo_khoan_khu_dao", true)
      gents = group.entities
      if @khu_sau_them > 0 && !@tiet_dien_vuong
        vc_local = vc.transform(tr.inverse)
        if @vi_tri_khu == "giua"
          elong_dir = tc.vector_to(vc_local).normalize
        else
          v = e.vertices.min_by { |vtx| vtx.position.distance(vc_local) }
          other_f = (e.faces - [f].flatten).first
          other_se = other_f.edges.find { |ed| ed != e && ed.vertices.include?(v) }
          other_v = (other_se.vertices - [v]).first.position
          elong_dir = other_v.vector_to(vc_local).normalize
        end
        pts = stadium_pts(tc, normal, elong_dir, radius * @ty_le_khu + @hieu_chinh_khu + @can_chinh_khu, @khu_sau_them)
        if pts
          half = pts.size / 2
          gents.add_curve(pts[0...half])
          gents.add_curve(pts[half..-1])
          gents.add_line(pts[half - 1], pts[half])
          gents.add_line(pts.last, pts.first)
        else
          gents.add_circle(tc, normal, radius * @ty_le_khu + @hieu_chinh_khu, 24)
        end
      else
        gents.add_circle(tc, normal, radius * @ty_le_khu + @hieu_chinh_khu, 24)
      end
      group.layer = layer
      gents.each { |ed| ed.layer = layer }
      ZSU.commit
      ZSU::Group.center_origin(group)
    end
  end
  def stadium_pts(center, normal, elong_dir, radius, elongation, segments = 12)
    perp = normal.cross(elong_dir)
    return nil if perp.length < 0.001
    perp = perp.normalize
    c_far = center
    c_near = center.offset(elong_dir, elongation)
    pts = []
    (0..segments).each do |i|
      a = Math::PI * i.to_f / segments
      pts << c_near.offset(perp, radius * Math.cos(a)).offset(elong_dir, radius * Math.sin(a))
    end
    (0..segments).each do |i|
      a = Math::PI + Math::PI * i.to_f / segments
      pts << c_far.offset(perp, radius * Math.cos(a)).offset(elong_dir, radius * Math.sin(a))
    end
    pts
  end
  def cut_overcut_shape(e, f, ents, center, normal, radius, tr, v_pos)
    initial_edges = ents.grep(Sketchup::Edge)
    unless @tiet_dien_vuong
      group = ents.add_group
      if @khu_sau_them > 0
        v_local = v_pos.transform(tr.inverse)
        if @vi_tri_khu == "giua"
          elong_dir = center.vector_to(v_local).normalize
        else
          v = e.vertices.min_by { |vtx| vtx.position.distance(v_local) }
          other_f = (e.faces - [f]).first
          other_se = other_f.edges.find { |ed| ed != e && ed.vertices.include?(v) }
          other_v = (other_se.vertices - [v]).first.position
          elong_dir = other_v.vector_to(v_local).normalize
        end
        pts = stadium_pts(center, normal, elong_dir, radius, @khu_sau_them)
        if pts
          half = pts.size / 2
          gents = group.entities
          gents.add_curve(pts[0...half])
          gents.add_curve(pts[half..-1])
          gents.add_line(pts[half - 1], pts[half])
          gents.add_line(pts.last, pts.first)
        else
          group.entities.add_circle(center, normal, radius * @ty_le_khu)
        end
      else
        group.entities.add_circle(center, normal, radius * @ty_le_khu)
      end
      group.explode
    else
      x_axis = normal.axes.x
      y_axis = normal.axes.y
      pts = [
        center.offset(x_axis, -radius).offset(y_axis, -radius),
        center.offset(x_axis, radius).offset(y_axis, -radius),
        center.offset(x_axis, radius).offset(y_axis, radius),
        center.offset(x_axis, -radius).offset(y_axis, radius),
      ]
      4.times { |i| ents.add_line(pts[i], pts[(i + 1) % 4]) }
    end
    ZSU.intersect_fix(ents)
    new_edges = ents.grep(Sketchup::Edge) - initial_edges
    new_edges.each { |edge| edge.erase! if edge.valid? && edge.faces.size < 2 }
    faces = ents.grep(Sketchup::Face)
    filtered = faces.select { |fc| fc.vertices.any? { |vt| vt.position.transform(tr) == v_pos } }
    smallest_face = filtered.min_by(&:area)
    return unless smallest_face
    smallest_face.pushpull(-e.length * @ty_le_khu)
    ZSU::Face.merge_coplanar(ents.grep(Sketchup::Face))
    reset_state
  end
  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
        if @mode == "Tự động"
          @target_data = build_target_auto
        elsif (flags & CONSTRAIN_MODIFIER_MASK) != 0 && @parent
          @target_data = build_target_all_corners(@parent)
        elsif @parent && @hover_edge
          @target_data = build_target_manual
        end
      end
      view.invalidate
    else
      if @duong_kinh_dao == 0
        ZSU.select_tool(nil)
      else
        if @mode == "Thủ công"
          @parent = @parent.make_unique
          ZSU::Group.fix_scale(@parent)
        end
        ZSU.start(false)
        @target_data.each do |group|
          board = group[:board]
          edges = group[:edges]
          faces = group[:faces]
          ref = group[:reference_point]
          edges.each_with_index do |edge, i|
            process_overcut(edge, faces[i], board, ref)
          end
        end
        ZSU.commit
        @cached_parent = nil
        reset_state
        ZSU.select_tool(nil) if @mode == "Tự động"
      end
    end
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    return unless @target_data
    @target_data.each do |group|
      board = group[:board]
      edges = group[:edges]
      faces = group[:faces]
      ref = group[:reference_point]
      edges.each_with_index do |edge, i|
        draw_overcut_preview(edge, faces[i], board, view, ref)
      end
    end
  end
  def draw_overcut_preview(edge, face, parent, view, reference_point = nil)
    return unless edge.valid?
    tr = parent.transformation
    v1 = edge.start.position.transform(tr)
    v2 = edge.end.position.transform(tr)
    normal = v1.vector_to(v2)
    x_axis = normal.axes.x
    y_axis = normal.axes.y
    radius = @duong_kinh_dao / 2
    center_data = []
    if @vi_tri_khu == "giua"
      return unless face.is_a?(Array)
      f1, f2 = face
      edge.vertices.each do |v|
        e1 = f1.edges.find { |e| e != edge && e.vertices.include?(v) }
        e2 = f2.edges.find { |e| e != edge && e.vertices.include?(v) }
        v1 = (e1.vertices - [v]).first.position.transform(tr)
        v2 = (e2.vertices - [v]).first.position.transform(tr)
        vc = v.position.transform(tr)
        dir = vc.vector_to(v1).normalize + vc.vector_to(v2).normalize
        vx = vc.offset(dir, @duong_kinh_dao - 0.1.mm)
        center_data << [Geom.linear_combination(0.5, vc, 0.5, vx), vc]
      end
    else
      face = face.is_a?(Array) ? face.max_by(&:area) : face
      shared = face.edges.select { |e| e != edge && (e.vertices & edge.vertices).size == 1 }
      return unless shared.size == 2
      shared.each do |e|
        common_v = (e.vertices & edge.vertices).first
        vc = common_v.position.transform(tr)
        other_v = (e.vertices - [common_v]).first
        dir = vc.vector_to(other_v.position.transform(tr))
        vx = vc.offset(dir, @duong_kinh_dao)
        center_data << [Geom.linear_combination(0.5, vc, 0.5, vx), vc]
      end
    end
    if @su_dung_tiet_dien
      if center_data.any? { |c, _| existing_drill_at?(parent, c, radius) }
        center_data = []
      elsif center_data.size > 1 && @hit_point
        center_data = [center_data.min_by { |c, _| c.distance(@hit_point) }]
      end
    end
    e_start = edge.start.position.transform(tr)
    e_end = edge.end.position.transform(tr)
    center_data.each do |center, vc|
      if @khu_sau_them > 0 && !@tiet_dien_vuong
        if @vi_tri_khu == "giua"
          elong_dir = center.vector_to(vc).normalize
        else
          v = edge.vertices.min_by { |vtx| vtx.position.transform(tr).distance(vc) }
          other_f = (edge.faces - [face]).first
          other_se = other_f.edges.find { |ed| ed != edge && ed.vertices.include?(v) }
          other_v = (other_se.vertices - [v]).first.position.transform(tr)
          elong_dir = other_v.vector_to(vc).normalize
        end
        pts = stadium_pts(center, normal, elong_dir, radius, @khu_sau_them)
        next unless pts
      elsif !@tiet_dien_vuong || @su_dung_tiet_dien
        pts = 24.times.map do |i|
          angle = i * Math::PI * 2 / 24
          center.offset(x_axis, Math.cos(angle) * radius)
                .offset(y_axis, Math.sin(angle) * radius)
        end
      else
        pts = [
          center.offset(x_axis, -radius).offset(y_axis, -radius),
          center.offset(x_axis, radius).offset(y_axis, -radius),
          center.offset(x_axis, radius).offset(y_axis, radius),
          center.offset(x_axis, -radius).offset(y_axis, radius),
        ]
      end
      edge_vec = vc.distance(e_start) < vc.distance(e_end) ?
                 normal : normal.reverse
      pts_other = pts.map { |p| p.offset(edge_vec) }
      pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
      pts_other = pts_other.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
      ZSU::View.draw2d_polygon(pts)
      ZSU::View.draw2d_polygon(pts_other)
      pts.size.times do |i|
        j = (i + 1) % pts.size
        ZSU::View.draw2d_polygon(
          [pts[i], pts[j], pts_other[j], pts_other[i]],
          line: false
        )
      end
    end
  end
  def reset_state
    @hover_edge = nil
    @parent = nil
    @hit_point = nil
  end
  def existing_drill_at?(parent, center, radius)
    tr = parent.transformation
    threshold = radius + @khu_sau_them
    ZSU.grep_ents(parent, :group).any? do |g|
      next unless g.get_attribute("ZSU", "lo_khoan_khu_dao")
      g.bounds.center.transform(tr).distance(center) < threshold
    end
  end
end
