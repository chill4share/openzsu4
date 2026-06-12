class ZSU::Amduong
  include ZSU::Preset
  settings_section "am_duong"

  def initialize
    ZSU.init_undo
    init_var
    reset_state
  end

  def init_var
    @su_dung_tiet_dien = read("su_dung_tiet_dien", false)
    @instance_tiet_dien = read("instance_tiet_dien", "ABF_AD")
    @layer_tiet_dien = read("layer_tiet_dien", "ABF_AD")
    @chan_dan_canh_khau = read("chan_dan_canh_khau", false)
    @to_mau_canh_bi_chan = read("to_mau_canh_bi_chan", true)
    @mau_sac_chan = ZSU.parse_color(read("mau_sac_chan", "210, 117, 159"))
    @he_so_giao_diem = read("he_so_giao_diem", 1.0, true).to_f
    @khu_dao = read("khu_dao", true)
    @bo_dem_giao = read("bo_dem_giao", 1, true).to_i
    @tiet_dien_vuong = read("tiet_dien_vuong", false)
    @ty_le_giao = read("ty_le_giao", 2.0, true).to_f
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @duong_kinh_dao = read("duong_kinh_dao", 6.0).to_f.mm
    @khau_sau_them = read("khau_sau_them", 0.0).to_f.mm
    @ho_canh_them = read("ho_canh_them", 0.0).to_f.mm
    @mau_sac_1 = ZSU.parse_color(read("mau_sac_1", "60, 175, 214"))
    @mau_sac_2 = ZSU.parse_color(read("mau_sac_2", "210, 117, 159"))
    @mau_select = Sketchup::Color.new(
      (@mau_sac_1.red + @mau_sac_2.red) / 2,
      (@mau_sac_1.green + @mau_sac_2.green) / 2,
      (@mau_sac_1.blue + @mau_sac_2.blue) / 2,
      200
    )
    @co_lap_doi_tuong = read("co_lap_doi_tuong", true)
    @can_bang_giao = read("can_bang_giao", (@he_so_giao_diem - 1.0) * 12, true).to_f.mm
    @sai_so_giao = read("sai_so_giao", @bo_dem_giao - 16, true).to_f.mm
    @an_net = read("an_net", false)
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Phương pháp" => {
        su_dung_tiet_dien: [:switch, "Sử dụng tiết diện"],
      },
      ["Chặn dán cạnh khấu", -> { !@su_dung_tiet_dien }] => {
        chan_dan_canh_khau: [:switch, "Chặn dán cạnh khấu"],
        to_mau_canh_bi_chan: [:switch, "Tô màu cạnh bị chặn", -> { @chan_dan_canh_khau }],
        mau_sac_chan: [:color, "Màu sắc chặn", -> { @chan_dan_canh_khau && @to_mau_canh_bi_chan }],
      },
      "Khử dao" => {
        khu_dao: [:switch, "Khử dao"],
        tiet_dien_vuong: [:switch, "Tiết diện vuông", -> { @khu_dao }],
        duong_kinh_dao: [:mm, "Đường kính dao", -> { @khu_dao }],
      },
      "Thông số" => {
        khau_sau_them: [:mm, "Khấu sâu thêm"],
        ho_canh_them: [:mm, "Hở cạnh thêm"],
      },
      "Tùy chọn" => {
        co_lap_doi_tuong: [:switch, "Cô lập đối tượng"],
        an_net: [:switch, "Ẩn nét khi kích hoạt"],
      },
    )
    update_intersect
  end

  def load_preset(s)
    @su_dung_tiet_dien = s["su_dung_tiet_dien"] || false
    init_preset(:an_net, s)
    init_preset(:duong_kinh_dao, s) { |v| v.to_f.mm }
    @khu_dao = s.fetch("khu_dao", true)
    @tiet_dien_vuong = s["tiet_dien_vuong"] || false
    init_preset(:khau_sau_them, s) { |v| v.to_f.mm }
    init_preset(:ho_canh_them, s) { |v| v.to_f.mm }
    init_preset(:chan_dan_canh_khau, s)
    init_preset(:to_mau_canh_bi_chan, s)
    init_preset(:layer_tiet_dien, s)
    init_preset(:instance_tiet_dien, s)
  end

  def reset_state
    @intersects = []
    @preview_boards = []
    @reverse = false
    @groups = []
    @board_groups = []
    @tasks = []
    @vector_preview = []
    @state = 0
    @selected_boards = []
    @picked = nil
  end

  def activate
    load_active_preset
    @isolated = false
    @prev_edge_display = ZSU::Model.get_edge_display
    @prev_silhouettes = Sketchup.active_model.rendering_options["DrawSilhouettes"]
    update_edge_display
    boards = ZSU::Board.filter_and_fix
    boards.select! { |board| ZSU::Solid.solid?(board) }
    if boards.length >= 2
      @selected_boards = boards
      start_processing
    else
      @selected_boards = boards
      @state = 0
      ZSU.select(nil)
      update_status
    end
  end

  def start_processing
    @state = 1
    if @co_lap_doi_tuong && @selected_boards.length >= 2
      ZSU.select(@selected_boards)
      ZSU::Isolate.start
      @isolated = true
    end
    ZSU.start
    @groups = ZSU::Board.group_by_normal(@selected_boards)
    @board_groups = @groups.map { |grp| [grp, ZSU::Board.calc_normal(grp.first).normalize] }
    ZSU.commit
    ZSU.select(nil)
    update_intersect
    update_status
  end

  def update_intersect
    cleanup_preview
    ZSU.start
    if @intersects
      @intersects.each { |g| g.erase! if g.valid? }
      @intersects = []
    end
    @vector_preview = []
    if @su_dung_tiet_dien
      @tasks = build_intersect_vector
    else
      @tasks = build_intersect
      build_preview if @tasks
    end
    ZSU.commit
  end

  def cleanup_preview
    return unless @preview_boards && @preview_boards.length > 0
    @preview_boards.each { |g| g.erase! if g.valid? }
    @preview_boards.clear
  end

  def init_group_colors
    preset_colors = [
      Sketchup::Color.new(80, 200, 220, 200),
      Sketchup::Color.new(180, 80, 220, 200),
      Sketchup::Color.new(255, 80, 80, 200),
      Sketchup::Color.new(255, 220, 50, 200),
      Sketchup::Color.new(255, 150, 50, 200),
      Sketchup::Color.new(80, 200, 80, 200),
      Sketchup::Color.new(80, 80, 200, 200),
    ]
    @group_colors ||= @board_groups.each_with_index.map do |_, idx|
      if idx == 0
        @mau_sac_1
      elsif idx == 1
        @mau_sac_2
      elsif idx - 2 < preset_colors.length
        preset_colors[idx - 2]
      else
        Sketchup::Color.new(rand(100..255), rand(100..255), rand(100..255), 200)
      end
    end
  end

  def build_preview
    temp_layer = ZSU.ensure_tag("ZSU_TEMP")
    temp_layer.visible = false
    init_group_colors

    board_trims = Hash.new { |h, k| h[k] = [] }
    @tasks.each do |b1, b2, int1, int2|
      board_trims[b1] << int1
      board_trims[b2] << int2
    end

    @preview_data = []
    board_trims.each do |board, trims|
      preview = ZSU::Board.clone_and_clean(board)
      preview.layer = temp_layer

      trims.each do |trim|
        trim_clone = ZSU::Board.clone_and_clean(trim)
        ZSU::Purge.fix_all(trim_clone)
        faces_before = ZSU.grep_ents(preview, :face).to_a
        ZSU::Solid.trim(preview, trim_clone)
        trim_clone.erase! if trim_clone.valid?
        (ZSU.grep_ents(preview, :face).to_a - faces_before).each do |f|
          f.edges.select { |e| e.faces.size == 1 }.each(&:erase!)
        end
      end

      ZSU::Purge.fix_all(preview)
      @preview_boards << preview

      group_idx = @board_groups.index { |(grp, _)| grp.include?(board) }
      color = @group_colors[group_idx] || Sketchup::Color.new(200, 200, 200, 200)

      @preview_data << [preview, color]
    end
  end

  def onKeyDown(key, repeat, flags, view)
    if key == 192
      ZSU::Settings.open_settings("am_duong")
    end
  end

  def onKeyUp(key, repeat, flags, view)
    return if @sb_selected_item
    if key == 9 && @state == 1
      @reverse = !@reverse
      @button_config[:modified] = true if @button_config
      update_intersect
      view.invalidate
      update_status
    end
  end

  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    return unless @state == 0

    ZSU.select(nil)
    ph = view.pick_helper
    ph.do_pick(x, y)
    @picked = ph.best_picked
    if @picked && ZSU::Solid.solid?(@picked) && !@selected_boards.include?(@picked)
      Sketchup.active_model.selection.add(@picked)
    else
      @picked = nil
    end
  end

  def enableVCB?
    true
  end

  def onUserText(text, view)
    num = text.to_f
    @khau_sau_them = num.mm
    write("khau_sau_them", num)

    @button_config[:modified] = true if @button_config
    update_intersect
    view.invalidate
    update_status
  end

  def update_edge_display
    if @an_net
      ZSU::Model.set_edge_display(0)
      Sketchup.active_model.rendering_options["DrawSilhouettes"] = false
    else
      ZSU::Model.set_edge_display(@prev_edge_display)
      Sketchup.active_model.rendering_options["DrawSilhouettes"] = @prev_silhouettes
    end
  end

  def update_status
    if @state == 0
      if @selected_boards.length < 2
        text = "Chọn tối thiểu hai ván để bắt đầu."
      else
        text = "Nhấn Enter để bắt đầu tính toán."
      end
    else
      text = "Nhấn Tab để đảo hướng. Nhấn Enter hoặc nhấn chuột để hoàn thành."
    end
    ZSU.status(text)
    ZSU.vcb("Khấu sâu thêm", Sketchup.format_length(@khau_sau_them))
  end

  def resume(view)
    view.invalidate
    update_status
  end

  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)

    if @state == 0
      @selected_boards.each do |board|
        next unless board.valid?
        ZSU::View.highlight_board(board, color: @mau_select)
      end
      return
    end

    if @su_dung_tiet_dien
      return unless @vector_preview && !@vector_preview.empty?
      @vector_preview.each do |pts, color|
        next unless pts
        ZSU::View.draw2d_polygon(pts, color: color)
      end
    else
      return unless @preview_data && !@preview_data.empty?
      @preview_data.each do |preview, color|
        next unless preview.valid?
        draw_preview_board(view, preview, color)
      end
    end
  end

  def draw_preview_board(view, board, color)
    faces = ZSU.grep_ents(board, :face)
    tr = board.transformation

    view.drawing_color = color
    faces.each do |face|
      mesh = face.mesh
      mesh.count_polygons.times do |i|
        polygon = mesh.polygon_points_at(i + 1)
        pts = polygon.map { |pt| pt.transform(tr) }
        pts.map! { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
        view.draw(GL_TRIANGLES, pts)
      end
    end
  end

  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split("_").last.to_i
        load_preset(@presets[index]["settings"])
        update_edge_display
        update_intersect if @state == 1
      end
      view.invalidate
    elsif @state == 0
      if @picked
        @selected_boards << @picked
        @picked = nil
        view.invalidate
        update_status
      else
        ph = view.pick_helper
        ph.do_pick(x, y)
        hit = ph.best_picked
        if hit && @selected_boards.include?(hit)
          @selected_boards.delete(hit)
          view.invalidate
          update_status
        end
      end
    else
      start_trim
    end
  end

  def onReturn(view)
    if @state == 0
      if @selected_boards.length >= 2
        start_processing
        view.invalidate
      else
        UI.beep
      end
    else
      start_trim
    end
  end

  def build_intersect_vector
    return unless @board_groups && @board_groups.length > 0
    tasks = []
    temp_layer = ZSU.ensure_tag("ZSU_TEMP")
    temp_layer.visible = false

    init_group_colors

    @board_groups.combination(2) do |(grp1, v1), (grp2, v2)|
      grp1.each do |b1|
        grp2.each do |b2|
          dup1 = ZSU::Board.clone_and_clean(b1)
          dup2 = ZSU::Board.clone_and_clean(b2)
          int = ZSU::Solid.intersect(dup1, dup2)
          next unless int && !ZSU.grep_ents(int, :face).empty?
          ZSU::Purge.fix_all(int)
          next unless ZSU::Board.rebuild(int)

          v3 = v1.cross(v2).normalize
          c2 = b2.bounds.center
          v3.reverse! if v3.dot(Geom::Vector3d.new(-c2.x, -c2.y, -c2.z)) < 0

          tr = int.transformation
          v3_local = v3.transform(tr.inverse)

          faces = ZSU.grep_ents(int, :face)
          side_faces = faces.reject { |f| f.normal.parallel?(v3_local) }
          next unless side_faces.length == 4

          pairs = side_faces.combination(2).select { |fa, fb|
            fa.normal.parallel?(fb.normal)
          }.first(2)
          next unless pairs.length == 2

          b1_normal = ZSU::Board.get_cnc_faces(b1).first.normal.transform(b1.transformation)
          b2_normal = ZSU::Board.get_cnc_faces(b2).first.normal.transform(b2.transformation)

          face_b1 = nil
          face_b2 = nil
          side_faces.each do |f|
            fn = f.normal.transform(tr)
            if fn.parallel?(b1_normal) && face_b1.nil?
              face_b1 = f
            elsif fn.parallel?(b2_normal) && face_b2.nil?
              face_b2 = f
            end
          end
          next unless face_b1 && face_b2

          int.layer = temp_layer
          @intersects << int

          direction = @reverse ? v3.reverse : v3
          [[b1, face_b1], [b2, face_b2]].each do |board, face|
            board_dir = (board == b1) ? direction : direction.reverse
            group_idx = @board_groups.index { |(grp, _)| grp.include?(board) }
            color = @group_colors[group_idx]
            face_pts = extract_face_world_pts(face, tr)
            preview_pts = halve_face_pts(face_pts, board_dir, v3)
            preview_pts = adjust_section_pts(preview_pts, board_dir, v3)
            @vector_preview << [preview_pts, color] if preview_pts
          end

          tasks << [b1, b2, int, face_b1, face_b2, v3]
        end
      end
    end
    tasks
  end

  def apply_vector
    @tasks.each do |b1, b2, int, face_b1, face_b2, v3|
      tr = int.transformation
      direction = @reverse ? v3.reverse : v3

      [[b1, face_b1], [b2, face_b2]].each do |board, face|
        board_dir = (board == b1) ? direction : direction.reverse
        group_idx = @board_groups.index { |(grp, _)| grp.include?(board) }
        color = @group_colors[group_idx]
        face_pts = extract_face_world_pts(face, tr)
        add_section_face(board, face_pts, board_dir, v3, color)
      end
    end

    ZSU.select_tool(nil)
  end

  def extract_face_world_pts(face, tr)
    face.vertices.map { |v| v.position.transform(tr) }
  end

  def halve_face_pts(face_pts, direction, v3)
    edges = []
    face_pts.each_with_index do |pt, i|
      edges << [pt, face_pts[(i + 1) % face_pts.length]]
    end

    v3_edges = []
    edges.each do |p1, p2|
      v3_edges << [p1, p2] if p1.vector_to(p2).parallel?(v3)
    end

    return face_pts unless v3_edges.length == 2

    result = face_pts.map do |pt|
      v3_edge = v3_edges.find { |p1, p2| p1 == pt || p2 == pt }
      if v3_edge
        other = (v3_edge[0] == pt) ? v3_edge[1] : v3_edge[0]
        edge_vec = pt.vector_to(other)
        if edge_vec.samedirection?(direction)
          Geom::Point3d.linear_combination(0.5, pt, 0.5, other)
        else
          pt
        end
      else
        pt
      end
    end
    result
  end

  def adjust_section_pts(pts, direction, v3)
    if @khau_sau_them != 0
      pts = pts.map do |pt|
        edges_from_pt = []
        pts.each do |other|
          next if other == pt
          vec = pt.vector_to(other)
          edges_from_pt << [other, vec] if vec.parallel?(v3)
        end
        edge_data = edges_from_pt.find { |_, vec| vec.samedirection?(direction) }
        if edge_data
          pt.offset(direction, -@khau_sau_them / 2.0)
        else
          pt
        end
      end
    end

    if @ho_canh_them != 0
      center = Geom::Point3d.new(
        pts.sum(&:x) / pts.length,
        pts.sum(&:y) / pts.length,
        pts.sum(&:z) / pts.length
      )
      perp_dir = nil
      pts.each_with_index do |pt, i|
        vec = pt.vector_to(pts[(i + 1) % pts.length])
        unless vec.parallel?(v3)
          perp_dir = vec.normalize
          break
        end
      end
      if perp_dir
        pts = pts.map do |pt|
          vec_to_center = pt.vector_to(center)
          dot = vec_to_center % perp_dir
          if dot.abs > 0.001
            offset_dir = dot > 0 ? perp_dir : perp_dir.reverse
            pt.offset(offset_dir, -@ho_canh_them)
          else
            pt
          end
        end
      end
    end

    pts
  end

  def add_section_face(board, face_pts, direction, v3, color = nil)
    pts = halve_face_pts(face_pts, direction, v3)
    pts = adjust_section_pts(pts, direction, v3)

    tr_inv = board.transformation.inverse
    local_pts = pts.map { |pt| pt.transform(tr_inv) }
    local_dir = direction.transform(tr_inv)
    local_v3 = v3.transform(tr_inv)

    inner_edge, local_pts = calc_overcut_edges(local_pts, local_dir, local_v3)

    ZSU.start
    grp = board.entities.add_group
    ents = grp.entities
    edges = []
    4.times do |i|
      edges += ents.add_edges(local_pts[i], local_pts[(i + 1) % 4])
    end
    edges.each { |e| e.find_faces if e.valid? }

    if color
      rgb_str = "#{color.red}, #{color.green}, #{color.blue}"
      material = ZSU.create_color_mat(rgb_str)
      grp.material = material
      ents.grep(Sketchup::Face).each do |face|
        face.material = material
        face.back_material = material
      end
    end

    section_layer = ZSU.ensure_tag(@layer_tiet_dien)
    grp.name = @instance_tiet_dien
    grp.layer = section_layer
    grp.entities.each { |e| e.layer = section_layer }
    ZSU.commit

    add_overcut_shapes(ents, local_pts, inner_edge) if @khu_dao && @duong_kinh_dao > 0 && inner_edge

    ZSU::Group.center_origin(grp)
  end

  def calc_overcut_edges(local_pts, local_dir, local_v3)
    return [nil, local_pts] unless @khu_dao && @duong_kinh_dao > 0

    radius = @duong_kinh_dao / 2.0
    short_edges = (0..3).each_with_object([]) do |i, arr|
      j = (i + 1) % 4
      arr << [i, j] unless local_pts[i].vector_to(local_pts[j]).parallel?(local_v3)
    end

    return [nil, local_pts] unless short_edges.length == 2

    center = Geom::Point3d.new(
      local_pts.sum(&:x) / 4.0, local_pts.sum(&:y) / 4.0, local_pts.sum(&:z) / 4.0
    )
    inner_edge = nil
    outer_edge = nil
    short_edges.each do |edge|
      i, j = edge
      mid = Geom::Point3d.linear_combination(0.5, local_pts[i], 0.5, local_pts[j])
      if center.vector_to(mid).samedirection?(local_dir)
        outer_edge = edge
      else
        inner_edge = edge
      end
    end

    if outer_edge
      oi, oj = outer_edge
      mid = Geom::Point3d.linear_combination(0.5, local_pts[oi], 0.5, local_pts[oj])
      outward = center.vector_to(mid).normalize
      local_pts[oi] = local_pts[oi].offset(outward, radius)
      local_pts[oj] = local_pts[oj].offset(outward, radius)
    end

    [inner_edge, local_pts]
  end

  def add_overcut_shapes(ents, local_pts, inner_edge)
    radius = @duong_kinh_dao / 2.0
    ii, ij = inner_edge
    ia = local_pts[ii]
    ib = local_pts[ij]
    ab_vec = ib - ia
    ab_len = ab_vec.length.to_f
    return unless ab_len > @duong_kinh_dao

    scale = radius / ab_len
    ab_offset = Geom::Vector3d.new(ab_vec.x * scale, ab_vec.y * scale, ab_vec.z * scale)
    ba_offset = Geom::Vector3d.new(-ab_offset.x, -ab_offset.y, -ab_offset.z)
    c1 = ia.offset(ab_offset)
    c2 = ib.offset(ba_offset)
    other_idx = ((ii + 1) % 4 == ij) ? (ii + 3) % 4 : (ii + 1) % 4
    ad_vec = ia.vector_to(local_pts[other_idx])
    normal = ab_vec.cross(ad_vec)

    ZSU.start
    if !@tiet_dien_vuong
      ents.add_circle(c1, normal, radius * @ty_le_giao)
      ents.add_circle(c2, normal, radius * @ty_le_giao)
    else
      ad_len = ad_vec.length.to_f
      ad_scale = radius / ad_len
      ad_off = Geom::Vector3d.new(ad_vec.x * ad_scale, ad_vec.y * ad_scale, ad_vec.z * ad_scale)
      neg_ad_off = Geom::Vector3d.new(-ad_off.x, -ad_off.y, -ad_off.z)
      [c1, c2].each do |ct|
        sq = [
          ct.offset(ab_offset).offset(ad_off),
          ct.offset(ba_offset).offset(ad_off),
          ct.offset(ba_offset).offset(neg_ad_off),
          ct.offset(ab_offset).offset(neg_ad_off),
        ]
        4.times { |k| ents.add_edges(sq[k], sq[(k + 1) % 4]) }
      end
    end
    ZSU.commit

    ZSU.start
    ZSU.intersect_fix(ents)
    ZSU.find_face(ents)
    ZSU::Purge.process_coplanar_edge(ents)
    ZSU.commit
  end

  def build_intersect
    return unless @board_groups && @board_groups.length > 0
    tasks = []
    temp_layer = ZSU.ensure_tag("ZSU_TEMP")
    temp_layer.visible = false
    @board_groups.combination(2) do |(grp1, v1), (grp2, v2)|
      grp1.each do |b1|
        grp2.each do |b2|
          dup1 = ZSU::Board.clone_and_clean(b1)
          dup2 = ZSU::Board.clone_and_clean(b2)
          int1 = ZSU::Solid.intersect(dup1, dup2)
          next unless int1 && !ZSU.grep_ents(int1, :face).empty?
          ZSU::Purge.fix_all(int1)
          next unless ZSU::Board.rebuild(int1)

          int2 = ZSU::Board.clone_and_clean(int1)

          v3 = v1.cross(v2).normalize
          c2 = b2.bounds.center
          v3.reverse! if v3.dot(Geom::Vector3d.new(-c2.x, -c2.y, -c2.z)) < 0

          depth = ZSU::Board.calc_local_size(int1).max
          distance = depth / 2.0
          moving(int1, -distance, v3)
          moving(int2, distance, v3)

          if group_inside?(int1, b1) || group_inside?(int1, b2)
            switch = group_inside?(int1, b1)
          else
            switch = false
          end
          switch = !switch if @reverse

          int1, int2 = int2, int1 if switch
          int1.layer = temp_layer
          int2.layer = temp_layer

          tasks << [b1, b2, int1, int2, v3]
          @intersects << int1
          @intersects << int2
        end
      end
    end
    tasks
  end

  def start_trim
    if @su_dung_tiet_dien
      apply_vector
    else
      all_inside_faces, all_boards = process_all_tasks
      cleanup_inside_faces(all_inside_faces)
      if @chan_dan_canh_khau
        ZSU.start
        material = nil
        if @to_mau_canh_bi_chan
          rgb_str = "#{@mau_sac_chan.red}, #{@mau_sac_chan.green}, #{@mau_sac_chan.blue}"
          material = ZSU.create_color_mat(rgb_str)
        end
        mark_inside_faces(all_inside_faces, material)
        ZSU.commit
      end
      ZSU.start
      ZSU::Purge.fix_all(all_boards.uniq)
      ZSU.commit
    end

    ZSU.start
    cleanup_temp_layer
    ZSU.commit

    ZSU.select_tool(nil)
  end

  def process_all_tasks
    all_inside_faces = []
    all_boards = []

    @tasks.each do |b1, b2, int1, int2, v3|
      ZSU.start
      edges_before_list = []
      trim_and_cleanup(b1, int1, edges_before_list)
      trim_and_cleanup(b2, int2, edges_before_list)
      ZSU.commit

      [b1, b2].each_with_index do |board, i|
        inside_faces = collect_inside_faces(board, edges_before_list[i], v3)
        inside_faces.select!(&:valid?)

        if inside_faces.length == 3
          adjust_inside_faces(board, inside_faces)
        end

        if @khu_dao && @duong_kinh_dao > 0
          inside_faces = collect_inside_faces(board, edges_before_list[i], v3)
          inside_faces.select!(&:valid?)
          apply_overcut(inside_faces) if inside_faces.length == 3
        end

        inside_faces = collect_all_inside_faces(board, edges_before_list[i])
        all_inside_faces.concat(inside_faces)
      end

      all_boards << b1 << b2
    end

    [all_inside_faces, all_boards]
  end

  def collect_all_inside_faces(body, edges_before)
    new_edges = ZSU.grep_ents(body, :edge).to_a - edges_before
    largest_faces = ZSU::Board.get_cnc_faces(body)
    ZSU.grep_ents(body, :face).select { |f|
      (f.edges - new_edges).empty? && !largest_faces.include?(f)
    }
  end

  def mark_inside_faces(faces, material)
    faces.select!(&:valid?)
    faces.each do |f|
      next unless f.valid?
      f.set_attribute("ZSU", "chan_dan_canh", true)
      if material
        f.material = material
        f.back_material = material
      end
    end
  end

  def adjust_inside_faces(board, inside_faces)
    sorted = inside_faces.sort_by(&:area)
    smallest = sorted[0]
    larger_two = sorted[1..2]

    if @ho_canh_them != 0
      ZSU.start
      larger_two.each do |f|
        next unless f.valid?
        f.pushpull(-@ho_canh_them * @ty_le_giao + @sai_so_giao + @can_bang_giao)
      end
      ZSU.commit
    end

    if @khau_sau_them != 0
      ZSU.start
      smallest.pushpull(-@khau_sau_them / 2.0 * @ty_le_giao + @sai_so_giao) if smallest.valid?
      ZSU.commit
    end
  end

  def apply_overcut(task_inside_faces)
    shared_edges = task_inside_faces.flat_map(&:edges).select { |edge|
      (edge.faces & task_inside_faces).size >= 2
    }.uniq
    return unless shared_edges.any?

    overcut = ZSU::Khudao.allocate
    overcut.instance_variable_set(:@khu_sau_them, 0)
    overcut.instance_variable_set(:@ty_le_khu, @ty_le_giao)
    shared_edges.each do |edge|
      next unless edge.valid? && edge.faces.size == 2
      parent = edge.parent.instances.first rescue nil
      next unless parent
      overcut.process_single(edge, parent,
                             diameter: @duong_kinh_dao, position: "nho", shape: @tiet_dien_vuong)
    end
  end

  def cleanup_inside_faces(all_inside_faces)
    ZSU.start
    all_inside_faces.select!(&:valid?)
    all_inside_faces.each do |f|
      next unless f.valid?
      ZSU::ABF.remove_band(f)
    end
    ZSU.commit
  end

  def cleanup_temp_layer
    model = Sketchup.active_model
    temp_layer = model.layers["ZSU_TEMP"]
    return unless temp_layer
    model.entities.grep(Sketchup::Group).each do |g|
      g.erase! if g.valid? && g.layer == temp_layer
    end
    model.entities.grep(Sketchup::ComponentInstance).each do |c|
      c.erase! if c.valid? && c.layer == temp_layer
    end
    model.layers.remove(temp_layer, true)
  end

  def group_inside?(b1, b2)
    t1 = b1.transformation
    t2 = b2.transformation
    ents2 = b2.entities.grep(Sketchup::Face)
    pts = b1.entities.grep(Sketchup::Face).flat_map { |f|
      f.vertices.map { |v| v.position.transform(t1) }
    }
    pts.all? { |pt|
      ents2.none? { |face|
        face.classify_point(pt.transform(t2.inverse)) == Sketchup::Face::PointOutside
      }
    }
  end

  def trim_and_cleanup(body, inter, edges_before_list)
    unless body.valid? && inter.valid?
      edges_before_list << []
      return
    end
    edges_before_list << ZSU.grep_ents(body, :edge).to_a
    faces_before = ZSU.grep_ents(body, :face).to_a
    ZSU::Solid.trim(body, inter)
    (ZSU.grep_ents(body, :face).to_a - faces_before).each do |f|
      f.edges.select { |e| e.faces.size == 1 }.each(&:erase!)
    end
    inter.erase! if inter.valid?
  end

  def collect_inside_faces(body, edges_before, v3)
    tr = body.transformation
    new_edges = ZSU.grep_ents(body, :edge).to_a - edges_before
    new_edge_faces = ZSU.grep_ents(body, :face).select { |f| (f.edges - new_edges).empty? }

    v3_local = v3.transform(tr.inverse)
    bottom_face = new_edge_faces.find { |f| f.normal.parallel?(v3_local) }
    return new_edge_faces unless bottom_face

    largest_faces = ZSU::Board.get_cnc_faces(body)
    neighbor_faces = bottom_face.edges.flat_map(&:faces).uniq - [bottom_face] - largest_faces

    [bottom_face] + neighbor_faces
  end

  def moving(board, distance, vector)
    d = distance.to_f
    v = Geom::Vector3d.new(vector.x * d, vector.y * d, vector.z * d)
    tr = Geom::Transformation.translation(v)
    board.transform!(tr)
  end

  def deactivate(view)
    save_active_preset
    ZSU::Isolate.stop if @isolated
    @isolated = false
    ZSU::Model.set_edge_display(@prev_edge_display)
    ro = Sketchup.active_model.rendering_options
    ro["DrawSilhouettes"] = @prev_silhouettes unless @prev_silhouettes.nil?
    ZSU.start
    @intersects.each { |g| g.erase! if g.valid? }
    @intersects.clear
    cleanup_preview
    ZSU.commit
    view.invalidate
  end
end
