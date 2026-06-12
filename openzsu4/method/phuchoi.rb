class ZSU::Phuchoi
  include ZSU::Preset
  settings_section "phuc_hoi"
  def initialize
    ZSU.init_undo
    init_var
  end
  def init_var
    @sua_truc_toa_do = read("sua_truc_toa_do", true)
    @phuc_hoi_hoan_toan = read("phuc_hoi_hoan_toan", true)
    @he_so_hoi_phuc = read("he_so_hoi_phuc", ZSU::View.grid_scale, true).to_f
    @bo_dem_hoi = read("bo_dem_hoi", 1, true).to_i
    @xoa_lien_ket_tiet_dien = read("xoa_lien_ket_tiet_dien", false)
    @ty_le_phuc = read("ty_le_phuc", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @xoa_mat_net_thua = read("xoa_mat_net_thua", false)
    @can_chinh_phuc = read("can_chinh_phuc", (@he_so_hoi_phuc - 1.0) * 12, true).to_f.mm
    @sai_so_hoi = read("sai_so_hoi", @bo_dem_hoi - 32, true).to_f.mm
    @do_dai_toi_thieu = read("do_dai_toi_thieu", 0.0).to_f.mm
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    show_tuong_doi = -> { !@phuc_hoi_hoan_toan }
    init_setting_buttons(
      "Trục tọa độ" => {
        sua_truc_toa_do: [:switch, "Sửa trục tọa độ"],
      },
      "Phục hồi" => {
        phuc_hoi_hoan_toan: [:switch, "Phục hồi hoàn toàn"],
        xoa_lien_ket_tiet_dien: [:switch, "Xóa liên kết và tiết diện", show_tuong_doi],
        xoa_mat_net_thua: [:switch, "Xóa mặt và nét thừa", show_tuong_doi],
        do_dai_toi_thieu: [:mm, "Xóa cạnh ngắn hơn", show_tuong_doi, 0, 5000],
      }
    )
    @target_data = []
    @mode = "Thủ công"
  end
  def load_preset(s)
    @sua_truc_toa_do = s["sua_truc_toa_do"]
    @do_dai_toi_thieu = s["do_dai_toi_thieu"].to_f.mm
    init_preset(:phuc_hoi_hoan_toan, s)
    init_preset(:xoa_lien_ket_tiet_dien, s)
    init_preset(:xoa_mat_net_thua, s)
  end
  def activate
    init_var
    load_active_preset
    @prev_transparency = ZSU::Model.get_trans
    ZSU::Model.set_trans(true)
    @target_data = build_target_auto
    @mode = @target_data.any? ? "Tự động" : "Thủ công"
    @original_selection = @target_data.map { |d| d[:board] }
    ZSU.select(nil)
    update_status
  end
  def deactivate(view)
    save_active_preset
    return if @prev_transparency.nil?
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
  def update_status
    if @mode == "Tự động"
      ZSU.status("Nhấn Enter để phục hồi.")
    else
      ZSU.status("Nhấn chuột trái để phục hồi.")
    end
    ZSU.vcb("Xóa cạnh ngắn hơn", Sketchup.format_length(@do_dai_toi_thieu))
  end
  def onKeyDown(key, repeat, flags, view)
    if key == 192
      ZSU::Settings.open_settings('phuc_hoi')
      return true
    end
  end
  def onUserText(text, view)
    len = text.to_l.to_mm.to_f.clamp(0, 5000)
    @do_dai_toi_thieu = len.mm
    write("do_dai_toi_thieu", len)
    @button_config[:modified] = true if @button_config
    rebuild_target_data
    view.invalidate
    update_status
  end
  def rebuild_target_data
    if @mode == "Tự động"
      @target_data = build_target_from(@original_selection)
    elsif @picked && @picked_face
      @target_data = build_target_manual(@picked, @picked_face)
    end
  end
  def build_target_auto
    boards = Sketchup.active_model.selection.select { |e| ZSU.is_container?(e) }
    boards.each { |b| ZSU::Board.reset_axes(b) } if @sua_truc_toa_do
    build_target_from(boards)
  end
  def build_target_from(boards)
    return [] if boards.nil? || boards.empty?
    boards.filter_map do |board|
      next unless board&.valid?
      face = ZSU::Board.get_cnc_faces(board).first
      next unless face
      pd = calc_preview_points(board, face)
      next unless pd && pd[:points]&.length.to_i >= 3
      { board: board, face: face, preview: pd[:points], normal: pd[:normal],
        thickness: pd[:thickness], method: pd[:method] }
    end
  end
  def build_target_manual(board, face)
    return [] unless board && face
    ZSU::Board.reset_axes(board) if @sua_truc_toa_do
    pd = calc_preview_points(board, face)
    return [] unless pd && pd[:points]&.length.to_i >= 3
    [{ board: board, face: face, preview: pd[:points], normal: pd[:normal],
       thickness: pd[:thickness], method: pd[:method] }]
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    return unless @mode == "Thủ công"
    ph = view.pick_helper
    ph.do_pick(x, y)
    picked = ph.best_picked
    face = ph.picked_face
    if picked && ZSU.is_container?(picked) && face && face_aligned_with_delta?(picked, face)
      @picked = picked
      @picked_face = face
      @target_data = build_target_manual(picked, face)
    else
      @picked = nil
      @picked_face = nil
      @target_data = []
    end
    view.invalidate
  end
  def face_aligned_with_delta?(board, face)
    tr = board.transformation
    world_normal = face.normal.transform(tr)
    bb = @sua_truc_toa_do ? board.bounds : calc_local_bb(board)
    dims = { x: bb.width, y: bb.height, z: bb.depth }
    min_axis = dims.min_by { |_, v| v }[0]
    local_axis = { x: X_AXIS, y: Y_AXIS, z: Z_AXIS }[min_axis]
    delta = @sua_truc_toa_do ? local_axis : local_axis.transform(tr)
    world_normal.parallel?(delta)
  end
  def calc_preview_points(board, face)
    return nil unless face && face.valid?
    return calc_normal_preview(board, face) if @phuc_hoi_hoan_toan
    tr = board.transformation
    local_bb = calc_local_bb(board)
    thickness = [local_bb.width, local_bb.height, local_bb.depth].min
    edges = face.outer_loop.edges.to_a
    long_edges = @do_dai_toi_thieu > 0 ? edges.select { |e| e.length >= @do_dai_toi_thieu } : edges.dup
    if long_edges.length >= 2
      vertex_count = Hash.new(0)
      long_edges.each { |e| vertex_count[e.start] += 1; vertex_count[e.end] += 1 }
      isolated = long_edges.select { |e| vertex_count[e.start] == 1 && vertex_count[e.end] == 1 }
      connected = long_edges - isolated
      isolated.each { |iso| long_edges.delete(iso) unless collinear_with_any?(iso, connected) }
    end
    if long_edges.length >= 2
      strings = ZSU::Edge.build_chains(long_edges)
      if strings.any?
        all_endpoints = strings.flat_map { |s| get_string_endpoints(s) }
        new_lines = connect_closest_endpoints(all_endpoints)
        all_edges = long_edges.map { |e| [e.start.position, e.end.position] } + new_lines
        outline = build_outline(all_edges)
        if outline.length >= 3
          return {
            points: outline.map { |p| p.transform(tr) },
            normal: face.normal.transform(tr),
            thickness: thickness,
            method: :smart
          }
        end
      end
    end
    calc_normal_preview(board, face)
  end
  def calc_normal_preview(board, face)
    tr = board.transformation
    fn = face.normal
    bb = calc_local_bb(board)
    mn = bb.min; mx = bb.max
    x0, y0, z0 = mn.x, mn.y, mn.z
    x1, y1, z1 = mx.x, mx.y, mx.z
    thickness = [bb.width, bb.height, bb.depth].min
    min_axis = { x: bb.width, y: bb.height, z: bb.depth }.min_by { |_, v| v }[0]
    pts, normal = case min_axis
                  when :z
                    z = fn.z > 0 ? z1 : z0
                    coords = [[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]]
                    [coords.map { |c| Geom::Point3d.new(*c) }, fn.z > 0 ? Z_AXIS : Z_AXIS.reverse]
                  when :y
                    y = fn.y > 0 ? y1 : y0
                    coords = [[x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1]]
                    [coords.map { |c| Geom::Point3d.new(*c) }, fn.y > 0 ? Y_AXIS : Y_AXIS.reverse]
                  else
                    x = fn.x > 0 ? x1 : x0
                    coords = [[x, y0, z0], [x, y1, z0], [x, y1, z1], [x, y0, z1]]
                    [coords.map { |c| Geom::Point3d.new(*c) }, fn.x > 0 ? X_AXIS : X_AXIS.reverse]
                  end
    {
      points: pts.map { |p| p.transform(tr) },
      normal: normal.transform(tr),
      thickness: thickness,
      method: :normal
    }
  end
  def connect_closest_endpoints(endpoints)
    pts = endpoints.dup
    lines = []
    while pts.length >= 2
      min_dist = Float::INFINITY
      best_pair = nil
      pts.each_with_index do |p1, i|
        pts.each_with_index do |p2, j|
          next if i >= j
          dist = p1.distance(p2)
          if dist < min_dist
            min_dist = dist
            best_pair = [i, j]
          end
        end
      end
      break unless best_pair
      lines << [pts[best_pair[0]], pts[best_pair[1]]]
      pts.delete_at(best_pair[1])
      pts.delete_at(best_pair[0])
    end
    lines
  end
  def build_outline(edges)
    return [] if edges.empty?
    points = [edges.first[0], edges.first[1]]
    used = [0]
    while used.length < edges.length
      last_pt = points.last
      found = false
      edges.each_with_index do |e, i|
        next if used.include?(i)
        if e[0] == last_pt || e[0].distance(last_pt) < 0.01
          points << e[1] unless e[1].distance(points.first) < 0.01
          used << i
          found = true
          break
        elsif e[1] == last_pt || e[1].distance(last_pt) < 0.01
          points << e[0] unless e[0].distance(points.first) < 0.01
          used << i
          found = true
          break
        end
      end
      break unless found
    end
    points
  end
  def get_string_endpoints(edges)
    return [] if edges.empty?
    vertex_count = Hash.new(0)
    edges.each { |e| vertex_count[e.start] += 1; vertex_count[e.end] += 1 }
    vertex_count.select { |_, count| count == 1 }.keys.map(&:position)
  end
  def collinear_with_any?(edge, other_edges)
    p0 = edge.start.position
    v0 = edge.line[1]
    other_edges.any? do |other|
      p1 = other.start.position
      v1 = other.line[1]
      next false unless v0.parallel?(v1)
      to_point = p0 - p1
      to_point.length < 0.001 || to_point.parallel?(v1)
    end
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    return unless @target_data&.any?
    @target_data.each do |data|
      pts, nml, thick = data[:preview], data[:normal], data[:thickness]
      next unless pts && pts.length >= 3 && nml && thick
      draw_box_preview(pts, nml, thick)
    end
  end
  def draw_box_preview(front_pts, normal, thickness)
    front_pts = front_pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
    offset_vector = normal.reverse
    offset_vector.length = thickness
    back_pts = front_pts.map { |p| p.offset(offset_vector) }
    ZSU::View.draw2d_polygon(front_pts)
    ZSU::View.draw2d_polygon(back_pts)
    front_pts.each_with_index do |fp, i|
      next_i = (i + 1) % front_pts.length
      ZSU::View.draw2d_polygon([fp, front_pts[next_i], back_pts[next_i], back_pts[i]])
    end
  end
  def onReturn(view)
    process_all(view)
  end
  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
        rebuild_target_data
        update_status
      end
      view.invalidate
      return
    end
    process_all(view)
  end
  def process_all(view)
    return unless @target_data&.any?
    @target_data.each do |data|
      board = data[:board]
      face = data[:face]
      if @phuc_hoi_hoan_toan
        rebuild_normal(board)
      elsif data[:method] == :smart
        rebuild_normal(board) unless rebuild_smart(board, data)
      elsif @xoa_lien_ket_tiet_dien || @xoa_mat_net_thua
        erase_nested_groups(board)
      else
        next
      end
    end
    if @mode == "Tự động"
      ZSU.select(@original_selection)
      ZSU.select_tool(nil)
    else
      @target_data = []
      @picked = nil
      @picked_face = nil
      view.invalidate
    end
  end
  def rebuild_smart(board, data)
    ZSU::Board.reset_axes(board) if @sua_truc_toa_do
    ZSU.start
    ents = ZSU.get_ents(board)
    tr = board.transformation
    if @xoa_lien_ket_tiet_dien
      ents.erase_entities(ents.to_a)
    else
      ents.erase_entities(ents.grep(Sketchup::Edge) + ents.grep(Sketchup::Face))
    end
    local_points = data[:preview].map { |p| p.transform(tr.inverse) }
    new_face = ents.add_face(local_points)
    unless new_face && new_face.valid?
      Sketchup.active_model.abort_operation
      return false
    end
    local_normal = data[:normal].transform(tr.inverse)
    new_face.reverse! if new_face.normal.dot(local_normal) < 0
    new_face.pushpull(-data[:thickness] * @ty_le_phuc + @sai_so_hoi + @can_chinh_phuc)
    ZSU::Purge.fix_all(board)
    ZSU.commit
    ZSU::Board.reset_axes(board) if @sua_truc_toa_do
    true
  end
  def erase_nested_groups(board)
    return unless board.valid?
    ents = ZSU.get_ents(board)
    groups = ents.select { |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid?
    }
    return if groups.empty? && !@xoa_mat_net_thua
    ZSU.start
    groups.each { |g| g.erase! if g.valid? }
    ZSU::Purge.fix_all(board) if @xoa_mat_net_thua
    ZSU.commit
  end
  def rebuild_normal(board)
    ZSU::Board.reset_axes(board) if @sua_truc_toa_do
    ZSU.start
    board = board.make_unique
    ZSU::Board.rebuild(board)
    ZSU.commit
    ZSU::Board.reset_axes(board) if @sua_truc_toa_do
  end
  def simplify_face(ents, face, min_length)
    outer_edges = face.outer_loop.edges.to_a
    inner_edges = face.loops.reject { |l| l.outer? }.flat_map(&:edges)
    ents.erase_entities(inner_edges) if inner_edges.any?
    edges = outer_edges.select { |e| e.valid? }
    short_edges = edges.select { |e| e.length < min_length }
    return face if short_edges.empty?
    ents.erase_entities(short_edges)
    long_edges = edges.select { |e| e.valid? }
    vertex_count = Hash.new(0)
    long_edges.each { |e| vertex_count[e.start] += 1; vertex_count[e.end] += 1 }
    isolated = long_edges.select { |e| vertex_count[e.start] == 1 && vertex_count[e.end] == 1 }
    connected = long_edges - isolated
    edges_to_delete = isolated.reject { |iso| collinear_with_any?(iso, connected) }
    ents.erase_entities(edges_to_delete) if edges_to_delete.any?
    long_edges = long_edges.select { |e| e.valid? }
    return nil if long_edges.length < 2
    strings = ZSU::Edge.build_chains(long_edges)
    return nil if strings.empty?
    all_endpoints = strings.flat_map { |s| get_string_endpoints(s) }
    return nil if all_endpoints.length < 2
    connect_closest_endpoints(all_endpoints).each do |p1, p2|
      ents.add_line(p1, p2)
    end
    ZSU.find_face(ents)
    ents.grep(Sketchup::Face).first
  end
  def calc_local_bb(board)
    ents = ZSU.get_ents(board)
    local_bb = Geom::BoundingBox.new
    ents.each { |e| local_bb.add(e.bounds) if e.respond_to?(:bounds) }
    local_bb
  end
end
