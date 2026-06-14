class ZSU::Baoranh
  include ZSU::Preset
  settings_section "bao_ranh"
  def initialize
    ZSU.init_undo
    init_var
  end
  def init_var
    @tinh_theo_khong_gian = read("tinh_theo_khong_gian", false)
    @thong_ke_ranh = read("thong_ke_ranh", true)
    @ten_hien_thi = read("ten_hien_thi", "LED")
    @so_luong = [read("so_luong", 1).to_i, 1].max
    @khoang_cach = read("khoang_cach", 50.0).to_f.mm
    @do_dai_co_dinh = read("do_dai_co_dinh", false)
    @chieu_dai_toi_da = read("chieu_dai_toi_da", 100.0).to_f.mm
    @chieu_rong = read("chieu_rong", 12.0).to_f.mm
    @ti_so_do_ranh = read("ti_so_do_ranh", ZSU::View.grid_scale, true).to_f
    @bo_dem_do = read("bo_dem_do", 1, true).to_i
    @cach_deu_hai_dau = read("cach_deu_hai_dau", true)
    @ty_le_ranh = read("ty_le_ranh", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @cach_truoc = read("cach_truoc", 0.0).to_f.mm
    @cach_sau = read("cach_sau", 0.0).to_f.mm
    @cach_mep = read("cach_mep", 50.0).to_f.mm
    @instance_ranh = read("instance_ranh", "ABF_BR")
    @layer_ranh = read("layer_ranh", "ABF_BR")
    @canh_dai_toi_thieu = read("canh_dai_toi_thieu", 200.0).to_f.mm
    @van_day_toi_thieu = read("van_day_toi_thieu", 15.0).to_f.mm
    @can_chinh_ranh = read("can_chinh_ranh", (@ti_so_do_ranh - 1.0) * 8, true).to_f.mm
    @do_lech_do = read("do_lech_do", @bo_dem_do - 4, true).to_f.mm
    @mo_phong_led = read("mo_phong_led", true)
    @mau_sac_led = read("mau_sac_led", "255,168,55")
    @mau_sac_led = @mau_sac_led.join(',') if @mau_sac_led.is_a?(Array)
    @chieu_cao_mo_phong = read("chieu_cao_mo_phong", 200.0).to_f.mm
    @layer_hien_thi = read("layer_hien_thi", "ABF_BR")
    @hien_thi_kich_thuoc = read("hien_thi_kich_thuoc", false)
    @instance_hien_thi = read("instance_hien_thi", "ZSU_BR")
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Không gian" => {
        tinh_theo_khong_gian: [:switch, "Tính theo không gian"],
      },
      "Thống kê" => {
        thong_ke_ranh: [:switch, "Thống kê rãnh"],
        ten_hien_thi: [:raw, "Tên hiển thị", -> { @thong_ke_ranh }],
      },
      "Số lượng" => {
        so_luong: [:raw, "Số lượng", nil, 1],
        khoang_cach: [:mm, "Khoảng cách", -> { @so_luong > 1 }],
      },
      "Kích thước" => {
        do_dai_co_dinh: [:switch, "Độ dài cố định"],
        chieu_dai_toi_da: [:mm, "Chiều dài", -> { @do_dai_co_dinh }, 1],
        chieu_rong: [:mm, "Chiều rộng"],
      },
      "Vị trí" => {
        cach_deu_hai_dau: [:switch, "Cách đều hai đầu"],
        cach_truoc: [:mm, -> { @cach_deu_hai_dau ? "Cách hai đầu" : "Cách trước" }, -> { !@do_dai_co_dinh || !@cach_deu_hai_dau }],
        cach_sau: [:mm, "Cách sau", -> { !@cach_deu_hai_dau && !@do_dai_co_dinh }],
      },
      "Cách mép" => {
        cach_mep: [:mm, "Cách mép"],
      },
      "Instance" => {
        instance_ranh: [:raw, "Instance"],
        layer_ranh: [:raw, "Layer"],
      },
      "Điều kiện" => {
        canh_dai_toi_thieu: [:mm, "Cạnh dài tối thiểu"],
        van_day_toi_thieu: [:mm, "Ván dày tối thiểu"],
      },
      "Mô phỏng" => {
        mo_phong_led: [:switch, "Mô phỏng đèn"],
        mau_sac_led: [:raw, "Màu sắc đèn", -> { @mo_phong_led }],
        chieu_cao_mo_phong: [:mm, "Chiều cao", -> { @mo_phong_led }],
        layer_hien_thi: [:raw, "Layer", -> { @mo_phong_led }],
      },
      "Hiển thị" => {
        hien_thi_kich_thuoc: [:switch, "Hiển thị kích thước"],
      }
    )
  end
  def load_preset(s)
    init_preset(:tinh_theo_khong_gian, s)
    init_preset(:thong_ke_ranh, s)
    init_preset(:ten_hien_thi, s)
    init_preset(:hien_thi_kich_thuoc, s)
    init_preset(:do_dai_co_dinh, s)
    init_preset(:chieu_dai_toi_da, s) { |v| v.to_f.mm }
    init_preset(:cach_deu_hai_dau, s)
    init_preset(:cach_truoc, s) { |v| v.to_f.mm }
    init_preset(:cach_sau, s) { |v| v.to_f.mm }
    init_preset(:cach_mep, s) { |v| v.to_f.mm }
    init_preset(:chieu_rong, s) { |v| v.to_f.mm }
    init_preset(:canh_dai_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:van_day_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:instance_ranh, s)
    init_preset(:layer_ranh, s)
    init_preset(:mo_phong_led, s)
    init_preset(:mau_sac_led, s)
    init_preset(:chieu_cao_mo_phong, s) { |v| v.to_f.mm }
    init_preset(:layer_hien_thi, s)
    init_preset(:instance_hien_thi, s)
    init_preset(:so_luong, s) { |v| [v.to_i, 1].max }
    init_preset(:khoang_cach, s) { |v| v.to_f.mm }
    @cached_parent = nil
  end
  def reset_state
    @all_grooves = []
    @parent = nil
    @face = nil
    @trans = nil
    @rect_limit = nil
    @hit_point = nil
    @chain = nil
    @chain_is_loop = false
    @shift_mode = false
    @mid_lines = nil
    @groove_dirty = true
    @led_strips_cache = nil
  end
  def activate
    load_active_preset
    @cached_parent = nil
    update_status
    reset_state
  end
  def resume(view)
    @cached_parent = nil
    view.invalidate
    update_status
  end
  def update_status
    text = "Giữ Ctrl để bắt cạnh vào chính giữa. " \
           "Giữ Shift để đánh rãnh thẳng."
    ZSU.status(text)
    ZSU.vcb("Số lượng [/x]: #{@so_luong} | Cách trước, sau [x,y] | Cách mép",
            Sketchup.format_length(@cach_mep))
  end
  def deactivate(view)
    save_active_preset
    view.invalidate
  end

  def onKeyDown(key, repeat, flags, view)
    ZSU::Settings.open_settings('bao_ranh') if key == ZSU::Settings.key_mo_cai_dat
    if key == VK_SHIFT && !@shift_mode && @face
      @shift_mode = true
      target = select_nearest_edge(@face)
      @edge = target if target
      view.invalidate
    end
  end

  def onKeyUp(key, repeat, flags, view)
    return if @sb_selected_item
    if key == VK_SHIFT && @shift_mode && @face
      @shift_mode = false
      target = select_nearest_edge(@face)
      @edge = target if target
      view.invalidate
    end
  end
  def enableVCB?
    true
  end
  def onUserText(text, view)
    if text.include?(",")
      parts = text.split(",", 2)
      t1 = parts[0].strip
      t2 = parts[1].strip
      unless t1.empty?
        v = t1.to_f
        @cach_truoc = v.mm
        write("cach_truoc", v)
      end
      unless t2.empty?
        v = t2.to_f
        @cach_sau = v.mm
        write("cach_sau", v)
      end
    elsif text.start_with?('/')
      num = text[1..-1].to_i
      return if num < 1
      @so_luong = num
      write("so_luong", num)
    else
      v = text.strip.to_f
      @cach_mep = v.mm
      write("cach_mep", v)
    end
    @button_config[:modified] = true if @button_config
    view.invalidate if view
    update_status
  end
  def calc_groove_points(face, edge, tr, extra_offset = 0)
    return unless face && edge && tr
    v1_pos, v2_pos = edge
    edge_vec = (v2_pos - v1_pos).normalize
    normal = face.normal.transform(tr)
    inward_vec = (normal * edge_vec).normalize
    mid_point = Geom.linear_combination(0.5, v1_pos, 0.5, v2_pos)
    test_point = mid_point.offset(inward_vec, 1.mm)
    if @rect_limit
      inward_vec = inward_vec.reverse unless point_inside_rect?(test_point, @rect_limit)
    else
      test_point_local = test_point.transform(tr.inverse)
      inward_vec = inward_vec.reverse unless face.classify_point(test_point_local) <= 4
    end
    effective_cach_mep = @cach_mep + extra_offset
    line1_p1 = v1_pos.offset(inward_vec, effective_cach_mep)
    line1_p2 = v2_pos.offset(inward_vec, effective_cach_mep)
    if @rect_limit
      v1x = find_nearest_intersection_rect(line1_p1, line1_p2, @rect_limit, v1_pos)
      v2x = find_nearest_intersection_rect(line1_p1, line1_p2, @rect_limit, v2_pos)
    else
      boundary_edges = face.edges
      v1x = find_nearest_intersection(line1_p1, line1_p2, boundary_edges, tr, v1_pos)
      v2x = find_nearest_intersection(line1_p1, line1_p2, boundary_edges, tr, v2_pos)
    end
    v1x ||= line1_p1
    v2x ||= line1_p2
    near_v1 = !@hit_point || v1_pos.distance(@hit_point) <= v2_pos.distance(@hit_point)
    cach_sau = @cach_deu_hai_dau ? @cach_truoc : @cach_sau
    ct = near_v1 ? @cach_truoc : cach_sau
    cs = near_v1 ? cach_sau : @cach_truoc
    dir_v1 = (v1x - v2x).normalize
    dir_v2 = (v2x - v1x).normalize
    v1x = v1x.offset(dir_v2, ct)
    v2x = v2x.offset(dir_v1, cs)
    return [v1x, v2x] if @chieu_rong == 0
    line2_p1 = v1_pos.offset(inward_vec, effective_cach_mep + @chieu_rong)
    line2_p2 = v2_pos.offset(inward_vec, effective_cach_mep + @chieu_rong)
    if @rect_limit
      v1y = find_nearest_intersection_rect(line2_p1, line2_p2, @rect_limit, v1_pos)
      v2y = find_nearest_intersection_rect(line2_p1, line2_p2, @rect_limit, v2_pos)
    else
      boundary_edges = face.edges
      v1y = find_nearest_intersection(line2_p1, line2_p2, boundary_edges, tr, v1_pos)
      v2y = find_nearest_intersection(line2_p1, line2_p2, boundary_edges, tr, v2_pos)
    end
    v1y ||= line2_p1
    v2y ||= line2_p2
    dir_v1y = (v1y - v2y).normalize
    dir_v2y = (v2y - v1y).normalize
    v1y = v1y.offset(dir_v2y, ct)
    v2y = v2y.offset(dir_v1y, cs)
    ensure_rectangle([v1x, v2x, v2y, v1y])
  end
  def ensure_rectangle(pts)
    return pts unless pts && pts.size == 4
    v1x, v2x, v2y, v1y = pts
    edge_dir = (v2x - v1x).normalize
    width_vec = v1x.vector_to(v1y)
    dot = width_vec % edge_dir
    perp_vec = width_vec - Geom::Vector3d.new(edge_dir.x * dot, edge_dir.y * dot, edge_dir.z * dot)
    projections = [v1x, v2x, v2y, v1y].map { |p| (p - v1x) % edge_dir }
    base1 = v1x.offset(edge_dir, projections.min)
    base2 = v1x.offset(edge_dir, projections.max)
    [base1, base2, base2.offset(perp_vec), base1.offset(perp_vec)]
  end
  def find_nearest_intersection_rect(line_p1, line_p2, rect_pts, ref_point)
    line = [line_p1, line_p2 - line_p1]
    intersections = []
    4.times do |i|
      v1 = rect_pts[i]
      v2 = rect_pts[(i + 1) % 4]
      edge_line = [v1, v2 - v1]
      pt = Geom.intersect_line_line(line, edge_line)
      next unless pt
      next unless point_on_segment?(pt, v1, v2)
      intersections << pt
    end
    return nil if intersections.empty?
    intersections.min_by { |pt| pt.distance(ref_point) }
  end
  def point_on_segment?(pt, v1, v2)
    d1 = pt.distance(v1)
    d2 = pt.distance(v2)
    seg_len = v1.distance(v2)
    (d1 + d2 - seg_len).abs < 0.1.mm
  end
  def point_inside_rect?(pt, rect_pts)
    return false unless rect_pts && rect_pts.length == 4
    v1 = rect_pts[1] - rect_pts[0]
    v2 = rect_pts[3] - rect_pts[0]
    vp = pt - rect_pts[0]
    dot1 = vp.dot(v1)
    dot2 = vp.dot(v2)
    len1_sq = v1.dot(v1)
    len2_sq = v2.dot(v2)
    dot1 >= 0 && dot1 <= len1_sq && dot2 >= 0 && dot2 <= len2_sq
  end
  def limit_groove_length(pts)
    return unless pts && @do_dai_co_dinh && @chieu_dai_toi_da > 0
    if pts.size == 2
      current_length = pts[0].distance(pts[1])
      return if current_length <= @chieu_dai_toi_da
      direction = (pts[1] - pts[0]).normalize
      if @cach_deu_hai_dau
        mid = Geom.linear_combination(0.5, pts[0], 0.5, pts[1])
        half = @chieu_dai_toi_da / 2.0
        pts[0] = mid.offset(direction, -half)
        pts[1] = mid.offset(direction, half)
      else
        near_0 = !@hit_point || pts[0].distance(@hit_point) <= pts[1].distance(@hit_point)
        if near_0
          pts[1] = pts[0].offset(direction, @chieu_dai_toi_da)
        else
          pts[0] = pts[1].offset(direction.reverse, @chieu_dai_toi_da)
        end
      end
    elsif pts.size == 4
      v1x, v2x, v2y, v1y = pts
      current_length = v1x.distance(v2x)
      return if current_length <= @chieu_dai_toi_da
      direction = (v2x - v1x).normalize
      if @cach_deu_hai_dau
        mid1 = Geom.linear_combination(0.5, v1x, 0.5, v2x)
        mid2 = Geom.linear_combination(0.5, v1y, 0.5, v2y)
        half = @chieu_dai_toi_da / 2.0
        pts[0] = mid1.offset(direction, -half)
        pts[1] = mid1.offset(direction, half)
        pts[2] = mid2.offset(direction, half)
        pts[3] = mid2.offset(direction, -half)
      else
        near_0 = !@hit_point || v1x.distance(@hit_point) <= v2x.distance(@hit_point)
        if near_0
          pts[1] = v1x.offset(direction, @chieu_dai_toi_da)
          pts[2] = v1y.offset(direction, @chieu_dai_toi_da)
        else
          pts[0] = v2x.offset(direction.reverse, @chieu_dai_toi_da)
          pts[3] = v2y.offset(direction.reverse, @chieu_dai_toi_da)
        end
      end
    end
  end
  def calc_all_grooves(face, edge, tr)
    return [] unless face && edge && tr
    all = []
    @so_luong.times do |i|
      offset = i * @khoang_cach
      if @chain_is_loop
        pts = calc_loop_groove_points(face, @chain, tr, offset)
      elsif @chain
        pts = calc_chain_groove_points(face, @chain, tr, offset)
      else
        pts = calc_groove_points(face, edge, tr, offset)
      end
      next unless pts
      limit_groove_length(pts) if @do_dai_co_dinh && !@chain
      all << pts
    end
    all
  end
  def find_nearest_rect_edge(rect_pts, hit_point)
    return nil unless rect_pts && rect_pts.length == 4
    edges = 4.times.map { |i| [rect_pts[i], rect_pts[(i + 1) % 4]] }
    edges = edges.select { |e| e[0].distance(e[1]) > @canh_dai_toi_thieu }
    return nil if edges.empty?
    edges.min_by do |e|
      p1, p2 = e
      line = [p1, p2 - p1]
      dist_to_line = hit_point.distance_to_line(line)
      midpoint = Geom::Point3d.linear_combination(0.5, p1, 0.5, p2)
      dist_to_midpoint = hit_point.distance(midpoint)
      dist_to_line + dist_to_midpoint
    end
  end
  def find_nearest_intersection(line_p1, line_p2, edges, tr, ref_point)
    line = [line_p1, line_p2 - line_p1]
    intersections = []
    edges.each do |e|
      v1, v2 = e.vertices.map { |v| v.position.transform(tr) }
      edge_line = [v1, v2 - v1]
      pt = Geom.intersect_line_line(line, edge_line)
      next unless pt
      next unless point_on_segment?(pt, v1, v2)
      intersections << pt
    end
    return nil if intersections.empty?
    intersections.min_by { |pt| pt.distance(ref_point) }
  end
  def find_rect_limit(face, tr, hit_point)
    normal = face.normal.transform(tr)
    normal.normalize!
    axes = [tr.xaxis, tr.yaxis, tr.zaxis]
    perp_axes = axes.reject { |axis| axis.parallel?(normal) }
    return nil unless perp_axes.length == 2
    model = Sketchup.active_model
    hit_points = {}
    directions = [
      [perp_axes[0], :pos1],
      [perp_axes[0].reverse, :neg1],
      [perp_axes[1], :pos2],
      [perp_axes[1].reverse, :neg2]
    ]
    directions.each do |dir, key|
      result = model.raytest([hit_point, dir], true)
      if result
        hit_pt, = result
        hit_points[key] = hit_pt
      end
    end
    return nil unless hit_points.length == 4
    v1_pos = hit_points[:pos1] - hit_point
    v1_neg = hit_points[:neg1] - hit_point
    v2_pos = hit_points[:pos2] - hit_point
    v2_neg = hit_points[:neg2] - hit_point
    [
      hit_point.offset(v1_pos).offset(v2_pos),
      hit_point.offset(v1_neg).offset(v2_pos),
      hit_point.offset(v1_neg).offset(v2_neg),
      hit_point.offset(v1_pos).offset(v2_neg)
    ]
  end
  def cache_parent_data(parent, tr)
    return if @cached_parent == parent
    @cached_parent = parent
    ZSU::Group.fix_scale(parent)
    @cached_largest_faces = ZSU::Board.get_cnc_faces(parent)
    @cached_thickness_valid = (ZSU::Board.calc_thickness(parent) || 0) >= @van_day_toi_thieu
    @cached_edge_data = {}
    @cached_chains = {}
    @cached_largest_faces.each do |face|
      @cached_edge_data[face] = face.edges.map do |e|
        p1 = e.start.position.transform(tr)
        p2 = e.end.position.transform(tr)
        {
          edge: e,
          p_start: p1,
          p_end: p2,
          midpoint: Geom::Point3d.linear_combination(0.5, p1, 0.5, p2),
          line: [p1, p2 - p1],
          length: e.length
        }
      end
      @cached_chains[face] = build_edge_chains(face, tr)
    end
  end
  def build_edge_chains(face, tr)
    edges = face.edges
    vertex_edges = Hash.new { |h, k| h[k] = [] }
    edges.each { |e| e.vertices.each { |v| vertex_edges[v] << e } }
    assigned = {}
    chains = []
    loops = []
    edge_chain = {}
    edges.each do |e|
      next if assigned[e]
      chain_edges, is_loop = collect_chain(e, vertex_edges, assigned)
      chain_edges.each { |ce| assigned[ce] = true }
      next if chain_edges.size < 2
      points = edges_to_polyline(chain_edges, tr)
      points.pop if is_loop && points.size > 1
      idx = chains.size
      chains << points
      loops << is_loop
      chain_edges.each { |ce| edge_chain[ce] = idx }
    end
    { chains: chains, edge_chain: edge_chain, loops: loops }
  end
  def collect_chain(start_edge, vertex_edges, assigned)
    used_fw = { start_edge => true }
    forward = extend_chain(start_edge, start_edge.end, vertex_edges, assigned, used_fw)
    is_loop = false
    if forward.any?
      v = start_edge.end
      forward.each { |e| v = e.other_vertex(v) }
      is_loop = (v == start_edge.start)
    end
    if is_loop
      [[start_edge] + forward, true]
    else
      used_bw = { start_edge => true }
      backward = extend_chain(start_edge, start_edge.start, vertex_edges, assigned, used_bw)
      [backward.reverse + [start_edge] + forward, false]
    end
  end
  def extend_chain(from_edge, vertex, vertex_edges, assigned, used)
    result = []
    current = from_edge
    loop do
      candidates = vertex_edges[vertex].reject { |e| assigned[e] || used[e] }
      break if candidates.empty?
      incoming_dir = vertex.position - current.other_vertex(vertex).position
      best = candidates.min_by { |e|
        incoming_dir.angle_between(e.other_vertex(vertex).position - vertex.position)
      }
      angle = incoming_dir.angle_between(best.other_vertex(vertex).position - vertex.position)
      break if angle > 10.degrees
      used[best] = true
      result << best
      current = best
      vertex = best.other_vertex(vertex)
    end
    result
  end
  def edges_to_polyline(chain_edges, tr)
    return [] if chain_edges.empty?
    return chain_edges[0].vertices.map { |v| v.position.transform(tr) } if chain_edges.size == 1
    shared = (chain_edges[0].vertices & chain_edges[1].vertices).first
    current_vertex = chain_edges[0].other_vertex(shared)
    vertices = [current_vertex]
    chain_edges.each do |e|
      current_vertex = e.other_vertex(current_vertex)
      vertices << current_vertex
    end
    vertices.map { |v| v.position.transform(tr) }
  end
  def offset_polyline(polyline, face, tr, distance)
    return polyline.dup if polyline.size < 2 || distance == 0
    normal = face.normal.transform(tr)
    result = ZSU::Offset.offset_chain_pts(polyline, normal, distance)
    return polyline.dup unless result && result.size >= 2
    mid = Geom.linear_combination(0.5, result[0], 0.5, result[1])
    test_local = mid.transform(tr.inverse)
    unless face.classify_point(test_local) <= 4
      result = ZSU::Offset.offset_chain_pts(polyline, normal, -distance)
      return polyline.dup unless result && result.size >= 2
    end
    result
  end
  def calc_loop_groove_points(face, chain, tr, extra_offset = 0)
    return unless face && chain && chain.size >= 3 && tr
    effective = @cach_mep + extra_offset
    tr_inv = tr.inverse
    local_pts = chain.map { |p| p.transform(tr_inv) }
    outer = ZSU::Offset.offset_pts(local_pts, face.normal, effective)
    return unless outer && outer.size >= 3
    outer_w = outer.map { |p| p.transform(tr) }
    return outer_w if @chieu_rong == 0
    inner = ZSU::Offset.offset_pts(local_pts, face.normal, effective + @chieu_rong)
    return outer_w unless inner && inner.size >= 3
    inner_w = inner.map { |p| p.transform(tr) }
    outer_w + inner_w.reverse
  end
  def calc_chain_groove_points(face, chain, tr, extra_offset = 0)
    return unless face && chain && chain.size >= 2 && tr
    effective_cach_mep = @cach_mep + extra_offset
    line1 = offset_polyline(chain, face, tr, effective_cach_mep)
    return unless line1 && line1.size >= 2
    near_start = !@hit_point || chain.first.distance(@hit_point) <= chain.last.distance(@hit_point)
    cach_sau = @cach_deu_hai_dau ? @cach_truoc : @cach_sau
    ct = near_start ? @cach_truoc : cach_sau
    cs = near_start ? cach_sau : @cach_truoc
    dir_start = (line1[1] - line1[0]).normalize
    line1[0] = line1[0].offset(dir_start, ct)
    dir_end = (line1[-2] - line1[-1]).normalize
    line1[-1] = line1[-1].offset(dir_end, cs)
    return line1 if @chieu_rong == 0
    line2 = offset_polyline(chain, face, tr, effective_cach_mep + @chieu_rong)
    return line1 unless line2 && line2.size >= 2
    dir_start2 = (line2[1] - line2[0]).normalize
    line2[0] = line2[0].offset(dir_start2, ct)
    dir_end2 = (line2[-2] - line2[-1]).normalize
    line2[-1] = line2[-1].offset(dir_end2, cs)
    line1 + line2.reverse
  end
  def polyline_length(pts)
    return 0 unless pts && pts.size >= 2
    (0...pts.size - 1).sum { |i| pts[i].distance(pts[i + 1]) }
  end
  def select_nearest_edge(face)
    edge_data = @cached_edge_data && @cached_edge_data[face]
    return unless edge_data && edge_data.any?
    if @shift_mode
      long_edges = edge_data.select { |d| d[:length] > @canh_dai_toi_thieu }
      return unless long_edges.any?
      nearest = long_edges.min_by { |d|
        @hit_point.distance_to_line(d[:line]) + @hit_point.distance(d[:midpoint])
      }
      @chain = nil
      @chain_is_loop = false
      [nearest[:p_start], nearest[:p_end]]
    else
      nearest = edge_data.min_by { |d|
        @hit_point.distance_to_line(d[:line]) + @hit_point.distance(d[:midpoint])
      }
      chain_data = @cached_chains[face]
      chain_idx = chain_data && chain_data[:edge_chain][nearest[:edge]]
      if chain_idx
        @chain = chain_data[:chains][chain_idx]
        @chain_is_loop = chain_data[:loops][chain_idx]
        [@chain.first, @chain.last]
      elsif nearest[:length] > @canh_dai_toi_thieu
        @chain = nil
        @chain_is_loop = false
        [nearest[:p_start], nearest[:p_end]]
      end
    end
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    ctrl_pressed = (flags & COPY_MODIFIER_MASK) != 0
    if ctrl_pressed
      @cach_mep_backup ||= @cach_mep
      @cach_mep = 0
    elsif @cach_mep_backup
      @cach_mep = @cach_mep_backup
      @cach_mep_backup = nil
    end
    ph = view.pick_helper
    ph.do_pick(x, y)
    f = ph.picked_face
    tr = ph.transformation_at(0)
    parent = ph.best_picked
    unless parent && f && ZSU.is_container?(parent) && parent.transformation.to_a == tr.to_a
      reset_state
      view.invalidate
      return
    end
    cache_parent_data(parent, tr)
    unless @cached_largest_faces.size == 2 &&
           @cached_largest_faces.include?(f) &&
           @cached_thickness_valid
      reset_state
      view.invalidate
      return
    end
    @hit_point = ZSU::View.calc_hit_point(f, tr, x, y, view)
    hit_point = @hit_point
    if @tinh_theo_khong_gian
      @rect_limit = find_rect_limit(f, tr, hit_point)
      @rect_limit ||= ZSU::Face.get_local_bounding(f, tr)
    else
      @rect_limit = nil
    end
    @chain = nil
    if ctrl_pressed
      corners = @rect_limit || ZSU::Face.get_local_bounding(f, tr)
      mid_line1 = [
        Geom::Point3d.linear_combination(0.5, corners[0], 0.5, corners[1]),
        Geom::Point3d.linear_combination(0.5, corners[3], 0.5, corners[2])
      ]
      mid_line2 = [
        Geom::Point3d.linear_combination(0.5, corners[0], 0.5, corners[3]),
        Geom::Point3d.linear_combination(0.5, corners[1], 0.5, corners[2])
      ]
      @mid_lines = [mid_line1, mid_line2]
      dist1 = hit_point.distance_to_line([mid_line1[0], mid_line1[1] - mid_line1[0]])
      dist2 = hit_point.distance_to_line([mid_line2[0], mid_line2[1] - mid_line2[0]])
      base_edge = dist1 < dist2 ? mid_line1 : mid_line2
      edge_vec = (base_edge[1] - base_edge[0]).normalize
      normal = f.normal.transform(tr)
      inward_vec = (normal * edge_vec).normalize
      mid_point = Geom.linear_combination(0.5, base_edge[0], 0.5, base_edge[1])
      test_point = mid_point.offset(inward_vec, 1.mm)
      test_point_local = test_point.transform(tr.inverse)
      inward_vec = inward_vec.reverse unless f.classify_point(test_point_local) <= 4
      half_width = @chieu_rong / 2.0
      target_edge = [
        base_edge[0].offset(inward_vec, -half_width),
        base_edge[1].offset(inward_vec, -half_width)
      ]
    elsif @rect_limit
      @mid_lines = nil
      target_edge = find_nearest_rect_edge(@rect_limit, hit_point)
      unless target_edge
        reset_state
        view.invalidate
        return
      end
    else
      @mid_lines = nil
      @shift_mode = (flags & CONSTRAIN_MODIFIER_MASK) != 0
      target_edge = select_nearest_edge(f)
      unless target_edge
        reset_state
        view.invalidate
        return
      end
    end
    @face = f
    @edge = target_edge
    @parent = parent
    @trans = tr
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
    else
      return unless @parent && @all_grooves && !@all_grooves.empty?
      @all_grooves.each do |pts|
        limit_groove_length(pts) if @do_dai_co_dinh && !@chain
        ZSU.start
        group = ZSU::Model.active_entities.add_group
        if @chain_is_loop && @chieu_rong > 0 && pts.size > 4
          half = pts.size / 2
          outer = pts[0...half]
          inner = pts[half..-1].reverse
          group.entities.add_face(outer)
          inner_face = group.entities.add_face(inner)
          inner_face.erase! if inner_face
        elsif @chain_is_loop
          group.entities.add_face(pts)
        elsif pts.size == 2
          group.entities.add_line(pts[0], pts[1])
        elsif @chain && @chieu_rong == 0
          (0...pts.size - 1).each { |i| group.entities.add_line(pts[i], pts[i + 1]) }
        else
          group.entities.add_face(pts)
        end
        ZSU.commit
        ZSU::Group.center_origin(group)
        ZSU.start
        layer = ZSU.ensure_tag(@layer_ranh)
        m_ents = ZSU.get_ents(@parent)
        m_parent_tr = @parent.transformation.inverse * group.transformation
        new_inst = m_ents.add_instance(group.definition, m_parent_tr)
        new_inst.layer = layer
        new_inst.name = @instance_ranh
        new_inst.entities.each { |e| e.layer = layer }
        ZSU::ABF.is_intersect(new_inst, true)
        if @thong_ke_ranh
          new_inst.set_attribute("ZSU", "bao_ranh", true)
          ZSU::ABF.set_statistical(new_inst, @ten_hien_thi, "length_measuring")
          new_inst.set_attribute("ABF", "is-statistical-object", false)
        end
        if @mo_phong_led
          model = Sketchup.active_model
          material = model.materials[@mau_sac_led]
          unless material
            material = model.materials.add(@mau_sac_led)
            rgb = @mau_sac_led.split(',').map(&:to_i)
            material.color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
          end
          new_inst.material = material
          if @chain
            create_chain_led(model, pts)
          else
            create_straight_led(model, pts, new_inst)
          end
        end
        group.erase!
        ZSU.commit
      end
      reset_state
      view.invalidate
    end
  end
  def create_straight_led(model, pts, new_inst)
    center = new_inst.bounds.center.transform(@parent.transformation)
    v1, v2 = pts[0], pts[1]
    led_length = v1.distance(v2)
    x_axis = (v2 - v1).normalize
    z_axis = @face.normal.transform(@trans).normalize
    half_len = led_length / 2.0
    p1 = center.offset(x_axis, -half_len)
    p2 = center.offset(x_axis, half_len)
    p3 = p2.offset(z_axis, @chieu_cao_mo_phong)
    p4 = p1.offset(z_axis, @chieu_cao_mo_phong)
    led_group = ZSU::Model.active_entities.add_group
    face = led_group.entities.add_face(p1, p2, p3, p4)
    led_group.entities.grep(Sketchup::Edge).each do |e|
      e.soft = true
      e.smooth = true
      e.hidden = true
    end
    mat = ZSU::Material.create_led_material(@mau_sac_led)
    if face
      face.material = mat
      face.back_material = mat
    end
    led_group.material = mat
    ZSU::Material.propagate_uv(
      [face], mat, p4, x_axis, z_axis, @chieu_cao_mo_phong + 20.mm
    )
    ZSU.commit
    ZSU::Group.center_origin(led_group)
    ZSU.start
    led_group.name = @instance_hien_thi
    led_group.layer = ZSU.ensure_tag(@layer_hien_thi)
  end
  def create_chain_led(model, pts)
    if @chain_is_loop
      tr_inv = @trans.inverse
      local_pts = @chain.map { |p| p.transform(tr_inv) }
      c1_local = ZSU::Offset.offset_pts(local_pts, @face.normal, @cach_mep + @chieu_rong / 2.0)
      return unless c1_local && c1_local.size >= 3
      c1 = c1_local.map { |p| p.transform(@trans) }
    else
      c1 = offset_polyline(@chain, @face, @trans, @cach_mep + @chieu_rong / 2.0)
      return unless c1 && c1.size >= 2
    end
    z_axis = @face.normal.transform(@trans).normalize
    c2 = c1.map { |p| p.offset(z_axis, @chieu_cao_mo_phong) }
    led_group = ZSU::Model.active_entities.add_group
    faces = []
    count = @chain_is_loop ? c1.size : c1.size - 1
    count.times do |i|
      j = (i + 1) % c1.size
      f = led_group.entities.add_face(c1[i], c1[j], c2[j], c2[i])
      faces << f if f
    end
    led_group.entities.grep(Sketchup::Edge).each do |e|
      e.soft = true
      e.smooth = true
      e.hidden = true
    end
    mat = ZSU::Material.create_led_material(@mau_sac_led)
    faces.each { |f| f.material = f.back_material = mat }
    led_group.material = mat
    edge_dir = c2[1] - c2[0]
    ZSU::Material.propagate_uv(
      faces, mat, c2[0], edge_dir, z_axis, @chieu_cao_mo_phong + 20.mm
    )
    led_group.name = @instance_hien_thi
    led_group.layer = ZSU.ensure_tag(@layer_hien_thi)
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)
    @all_grooves = calc_all_grooves(@face, @edge, @trans)
    precision = ZSU::Model.get_unit_precision
    if @mo_phong_led
      rgb = @mau_sac_led.split(',').map(&:to_i)
      groove_color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
    end
    @all_grooves.each do |pts|
      pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
      if @chain_is_loop && pts.size > 2
        if @chieu_rong > 0
          half = pts.size / 2
          outer = pts[0...half]
          inner = pts[half..-1].reverse
          half.times do |i|
            j = (i + 1) % half
            ZSU::View.draw_polygon([outer[i], outer[j], inner[j], inner[i]], color: groove_color, line: false)
          end
          ZSU::View.draw_loop(outer)
          ZSU::View.draw_loop(inner)
          led_length = outer.each_with_index.sum { |p, i| p.distance(outer[(i + 1) % half]) }
        else
          ZSU::View.draw_loop(pts)
          led_length = pts.each_with_index.sum { |p, i| p.distance(pts[(i + 1) % pts.size]) }
        end
      elsif @chain && @chieu_rong == 0 && pts.size > 2
        pairs = (0...pts.size - 1).flat_map { |i| [pts[i], pts[i + 1]] }
        ZSU::View.draw_lines(pairs, color: groove_color)
        led_length = polyline_length(pts)
      elsif pts.length > 2
        ZSU::View.draw_polygon(pts, color: groove_color)
        if @chain
          half = pts.size / 2
          led_length = polyline_length(pts[0...half])
        else
          led_length = pts[0].distance(pts[1])
        end
      else
        ZSU::View.draw_lines(pts, color: groove_color)
        led_length = pts[0].distance(pts[1])
      end
      if @hien_thi_kich_thuoc
        mid_idx = pts.size > 4 ? pts.size / 2 - 1 : 1
        mid = Geom.linear_combination(0.5, pts[0], 0.5, pts[mid_idx])
        ZSU::View.draw2d_text(format("%.#{precision}f", led_length.to_mm), mid)
      end
    end
    draw_led_preview if @mo_phong_led
    if @mid_lines
      @mid_lines.each { |line| ZSU::View.draw2d_lines(line, guide: true) }
    end
  end
  LED_STRIPS = 10
  LED_ALPHAS = (0...LED_STRIPS).map { |k|
    (128 * (1.0 - k.to_f / (LED_STRIPS - 1)) + 13 * (k.to_f / (LED_STRIPS - 1))).round
  }
  def draw_led_preview
    return unless @face && @trans && @all_grooves&.any?
    z_axis = @face.normal.transform(@trans).normalize
    rgb = @mau_sac_led.split(',').map(&:to_i)
    step = @chieu_cao_mo_phong / LED_STRIPS.to_f
    @all_grooves.each_with_index do |pts, i|
      if @chain_is_loop
        offset = @cach_mep + @chieu_rong / 2.0 + i * @khoang_cach
        tr_inv = @trans.inverse
        local_pts = @chain.map { |p| p.transform(tr_inv) }
        c1_local = ZSU::Offset.offset_pts(local_pts, @face.normal, offset)
        next unless c1_local && c1_local.size >= 3
        c1 = c1_local.map { |p| p.transform(@trans) }
        LED_STRIPS.times do |k|
          color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2], LED_ALPHAS[k])
          bot = c1.map { |p| p.offset(z_axis, step * k) }
          top = c1.map { |p| p.offset(z_axis, step * (k + 1)) }
          c1.size.times do |j|
            jn = (j + 1) % c1.size
            ZSU::View.draw_polygon(
              [bot[j], bot[jn], top[jn], top[j]],
              color: color, line: false
            )
          end
        end
      elsif @chain
        offset = @cach_mep + @chieu_rong / 2.0 + i * @khoang_cach
        c1 = offset_polyline(@chain, @face, @trans, offset)
        next unless c1 && c1.size >= 2
        LED_STRIPS.times do |k|
          color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2], LED_ALPHAS[k])
          bot = c1.map { |p| p.offset(z_axis, step * k) }
          top = c1.map { |p| p.offset(z_axis, step * (k + 1)) }
          (0...c1.size - 1).each do |j|
            ZSU::View.draw_polygon(
              [bot[j], bot[j + 1], top[j + 1], top[j]],
              color: color, line: false
            )
          end
        end
      else
        next unless pts.size >= 2
        center = if pts.size >= 4
          Geom::Point3d.new(
            pts.sum(&:x) / 4.0,
            pts.sum(&:y) / 4.0,
            pts.sum(&:z) / 4.0
          )
        else
          Geom.linear_combination(0.5, pts[0], 0.5, pts[1])
        end
        x_axis = (pts[1] - pts[0]).normalize
        half = pts[0].distance(pts[1]) / 2.0
        b1 = center.offset(x_axis, -half)
        b2 = center.offset(x_axis, half)
        LED_STRIPS.times do |k|
          color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2], LED_ALPHAS[k])
          p1 = b1.offset(z_axis, step * k)
          p2 = b2.offset(z_axis, step * k)
          p3 = b2.offset(z_axis, step * (k + 1))
          p4 = b1.offset(z_axis, step * (k + 1))
          ZSU::View.draw_polygon(
            [p1, p2, p3, p4], color: color, line: false
          )
        end
      end
    end
  end
end
