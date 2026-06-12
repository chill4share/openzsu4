
class ZSU::Lienket
  include ZSU::Preset
  settings_section "lien_ket"

  def initialize
    ZSU.init_undo
    init_var
  end

  def activate
    load_active_preset
    @prev_transparency = ZSU::Model.get_trans
    ZSU::Model.set_trans(true)

    @license_status = true 
    return ZSU.select_tool(nil) unless @license_status

    @selected_entities = ZSU::Board.filter_and_fix
    reset_state
    update_status
  end

  def deactivate(view)
    save_active_preset
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

  def onUserText(text, view)
    if text.include?(",")
      parts = text.split(",", 2)
      len1_str = parts[0].strip
      len2_str = parts[1].strip
      if !len1_str.empty?
        len1 = len1_str.to_l.to_mm.to_f
        return if len1 < 0
        @cach_truoc = len1.mm
        write("cach_truoc", len1)
      end
      if !len2_str.empty? && !@cach_deu_hai_dau
        len2 = len2_str.to_l.to_mm.to_f
        return if len2 < 0
        @cach_sau = len2.mm
        write("cach_sau", len2)
      end
    elsif text.start_with?("/")
      if !@so_luong_co_dinh
        num = text[1..-1].to_l.to_mm.to_f
        return if num < 0
        @khoang_cach = num.mm
        write("khoang_cach", num)
      else
        num = text[1..-1].to_i
        return if num < 0
        @so_luong_lien_ket = num
        write("so_luong_lien_ket", num)
      end
    else
      len = text.to_l.to_mm.to_f
      return if len < 0
      @cach_truoc = len.mm
      write("cach_truoc", len)
    end
    @button_config[:modified] = true if @button_config
    view.invalidate if view
    update_status
  end

  def onKeyDown(key, repeat, flags, view)
    if key == 192
      ZSU::Settings.open_settings('lien_ket')
    elsif key == VK_CONTROL
      @ctrl_mode = true
      update_ctrl_faces
      view.invalidate
    elsif key == VK_SHIFT
      @shift_auto = true
      if @che_do == 1
        update_dao_mat_face
      elsif @che_do == 2
        update_xoa_preview
      else
        update_target_faces
      end
      view.invalidate
    elsif key == ALT_MODIFIER_KEY && @che_do == 0
      unless @alt_mode
        @alt_mode = true
        update_picked_face
        view.invalidate
      end
      return true
    end
  end

  def onKeyUp(key, repeat, flags, view)
    return if @sb_selected_item
    if key == 9
      @che_do = (@che_do + 1) % 3
      write("che_do", @che_do)
      @xoa_parent = nil
      @xoa_current_id = nil
      @xoa_id_groups = nil
      @xoa_faces = nil
      @xoa_edges = nil
      update_status
      view.invalidate
    elsif key == VK_CONTROL
      @ctrl_mode = false
      update_ctrl_faces
      view.invalidate
      update_status
    elsif key == VK_SHIFT
      @shift_auto = false
      if @che_do == 1
        update_dao_mat_face
      elsif @che_do == 2
        @xoa_faces = []
        @xoa_edges = []
        @xoa_current_id = nil
        @xoa_id_groups = nil
      else
        update_target_faces
      end
      view.invalidate
    elsif key == ALT_MODIFIER_KEY && @che_do == 0
      if @alt_mode
        @alt_mode = false
        update_picked_face
        view.invalidate
      end
      return true
    end
  end

  def onReturn(view)
    thuc_hien(view)
  end

  def onMouseMove(flags, x, y, view)
    @shift_auto = (flags & CONSTRAIN_MODIFIER_MASK) != 0
    handle_ui_mouse_move(x, y, view)
    @mouse_x = x
    @mouse_y = y

    ph = view.pick_helper
    ph.do_pick(x, y)
    f = ph.picked_face
    parent = ph.best_picked
    unless parent && ZSU.is_container?(parent)
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

    if @che_do == 1
      fb = ZSU::Board.get_cnc_faces(parent)
      subgroup = nil
      if fb && fb.size >= 2
        loop_limit_pick = 0
        (0...ph.count).each do |i|
          loop_limit_pick += 1
          break if loop_limit_pick > 500
          pp = ph.path_at(i)
          next unless pp && pp.size > 1
          next unless pp[0] == parent
          pp[1..-1].each do |e|
            if ZSU.is_container?(e) && e.valid?
              subgroup = e
              break
            end
          end
          break if subgroup
        end
      end
      if subgroup
        @dao_mat_subgroup = subgroup
        @dao_mat_subgroup_parent = parent
        @dao_mat_subgroup_pts, @dao_mat_subgroup_edges =
          collect_subgroup_highlight(subgroup, tr * subgroup.transformation)
        @shift_face = nil
        @shift_face_pts = nil
        @shift_parent = nil
        @dao_mat_original_face = nil
        @dao_mat_cnc_faces = nil
        @dao_mat_tr = nil
      elsif f && fb && fb.include?(f)
        @dao_mat_subgroup = nil
        @dao_mat_subgroup_parent = nil
        @dao_mat_subgroup_pts = nil
        @dao_mat_subgroup_edges = nil
        @dao_mat_original_face = f
        @dao_mat_cnc_faces = fb
        @dao_mat_tr = tr
        picked = @shift_auto ? (fb - [f]).first || f : f
        @shift_face = picked
        @shift_face_pts = picked.outer_loop.vertices.map { |v| v.position.transform(tr) }
        @shift_parent = parent
      else
        @dao_mat_subgroup = nil
        @dao_mat_subgroup_parent = nil
        @dao_mat_subgroup_pts = nil
        @dao_mat_subgroup_edges = nil
        @shift_face = nil
        @shift_face_pts = nil
        @shift_parent = nil
        @dao_mat_original_face = nil
        @dao_mat_cnc_faces = nil
        @dao_mat_tr = nil
      end
      view.invalidate
      return
    end

    if @che_do == 2
      if @shift_auto
        if @xoa_parent != parent
          @xoa_parent = parent
          @xoa_id_groups = nil
          update_xoa_preview
          view.invalidate
        end
      else
        edge = ph.picked_edge
        lk_group = find_lien_ket_group(edge, parent)
        if lk_group
          lk_id = lk_group.get_attribute("ZSU", "lien_ket_id")
          if lk_id && lk_id != @xoa_current_id
            @xoa_current_id = lk_id
            @xoa_id_groups = find_groups_by_id(lk_id)
            @xoa_parent = parent
            update_xoa_id_preview
            view.invalidate
          end
        elsif @xoa_current_id
          @xoa_current_id = nil
          @xoa_id_groups = nil
          @xoa_faces = []
          @xoa_edges = []
          view.invalidate
        end
      end
      return
    end

    if @shift_auto
      @hit_point = ZSU::View.calc_hit_point(f, tr, x, y, view) if f
      if @selected_entities.size > 0
        @target_faces = find_all_faces_with_filter(@selected_entities)
      else
        @target_faces = find_all_faces([parent])
      end
    else
      return unless f
      fb = ZSU::Board.get_cnc_faces(parent)
      return unless fb
      band_faces = ZSU.grep_ents(parent, :face).to_a - fb.to_a
      if @canh_dai_toi_thieu > 0
        band_faces = band_faces.reject { |face| face.edges.map(&:length).max < @canh_dai_toi_thieu }
      end
      if @tao_chot_chinh || @tao_chot_phu
        band_faces = band_faces.select do |face|
          r = find_mortise_parent(face, parent)
          r && !r.empty?
        end
      end
      @hit_point = ZSU::View.calc_hit_point(f, tr, x, y, view)
      target = band_faces.min_by do |face|
        plane = [face.bounds.center.transform(tr), face.normal.transform(tr)]
        @hit_point.distance_to_plane(plane).abs
      end
      if target
        @target_face = target
        @target_parent = parent
        pf = @alt_mode && fb.size >= 2 ? (fb - [f]).first || f : f
        @target_faces = [{ face: @target_face, parent: @target_parent,
                           picked_face: pf, original_face: f }]
        @target_org = @target_faces.dup
        if @ctrl_mode
          opposite = band_faces.find { |face| face.normal.reverse == target.normal }
          if opposite
            @target_faces << { face: opposite, parent: parent,
                               picked_face: pf, original_face: f, opposite: true }
          end
        end
      else
        reset_state
      end
    end
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    return if handle_setting_click(x, y, view)
    if id = handle_preset_click(x, y)
      unless id == :deselected
        index = id.to_s.split('_').last.to_i
        load_preset(@presets[index]["settings"])
      end
      view.invalidate
    elsif handle_mode_click(x, y, view)
      return
    elsif @che_do == 1
      if @dao_mat_subgroup
        thuc_hien_dao_mat_subgroup(view)
      else
        thuc_hien_chuyen_mat(view)
      end
    elsif @che_do == 2
      thuc_hien_xoa(view)
    else
      thuc_hien(view)
    end
  end

  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    draw_mode_buttons(view)

    if @che_do == 1
      if @dao_mat_subgroup_pts && !@dao_mat_subgroup_pts.empty?
        @dao_mat_subgroup_pts.each do |pts|
          next if pts.size < 3
          dp = @view_dpi != 0 ? pts.map { |p| p.offset([0, 0, @view_dpi]) } : pts
          ZSU::View.draw2d_polygon(dp)
        end
        return
      end
      if @dao_mat_subgroup_edges && !@dao_mat_subgroup_edges.empty?
        ep = @view_dpi != 0 ?
          @dao_mat_subgroup_edges.map { |p| p.offset([0, 0, @view_dpi]) } :
          @dao_mat_subgroup_edges
        old_w = ZSU::View.edge_weight
        ZSU::View.set_edge_weight(old_w + 2)
        ZSU::View.draw2d_lines(ep)
        ZSU::View.set_edge_weight(old_w)
        return
      end
      if @shift_face_pts && @shift_face_pts.size >= 3
        sfp = @view_dpi != 0 ? @shift_face_pts.map { |p| p.offset([0, 0, @view_dpi]) } : @shift_face_pts
        ZSU::View.draw2d_polygon(sfp)
        return
      end
    end

    if @che_do == 2
      if @xoa_faces
        @xoa_faces.each { |pts| ZSU::View.draw2d_polygon(pts, color: ZSU::View.warning_face_color) }
      end
      if @xoa_edges && !@xoa_edges.empty?
        ZSU::View.draw2d_lines(@xoa_edges, color: ZSU::View.warning_color)
      end
      return
    end

    @datas = tinh_hinh_hoc
    return unless @datas
    return if @datas.empty?
    @hover_component = find_hover_component(@datas)
    @datas.each do |data|
      next unless data
      draw_joint_preview(data)
      draw_joint_texts(data) if @hien_thi_khoang_cach
    end
  end

  def init_var
    @thong_ke_lien_ket = read("thong_ke_lien_ket", true)
    @ten_hien_thi = read("ten_hien_thi", "Liên kết")
    @so_luong_co_dinh = read("so_luong_co_dinh", true)
    @so_luong_lien_ket = read("so_luong_lien_ket", 2).to_i
    @khoang_cach = read("khoang_cach", 200.0).to_f.mm
    @he_so_dinh_tam = read("he_so_dinh_tam", ZSU::View.grid_scale, true).to_f
    @cach_deu_hai_dau = read("cach_deu_hai_dau", true)
    @bo_dem_tam = read("bo_dem_tam", ZSU::View.cache_step(16), true).to_i
    @cach_truoc = read("cach_truoc", 50.0).to_f.mm
    @cach_sau = read("cach_sau", 50.0).to_f.mm
    @van_day_toi_thieu = read("van_day_toi_thieu", 15.0).to_f.mm
    @canh_dai_toi_thieu = read("canh_dai_toi_thieu", 50.0).to_f.mm
    @tao_chot_chinh = read("tao_chot_chinh", true)
    @kieu_chot_chinh = read("tiet_dien_tuy_chinh_cc", false) ? "tuy_chinh" : "tron"
    @duong_dan_chot_chinh = read("duong_dan_chot_chinh", "")
    @tam_can_giua_cc = read("tam_can_giua_cc", true)
    @goc_xoay_cc = read("goc_xoay_cc", 0).to_i
    @can_giua_chot_chinh = read("can_giua_chot_chinh", false)
    @chot_chinh_cach_mat = read("chot_chinh_cach_mat", 7.0).to_f.mm
    @duong_kinh_lo_chot = read("duong_kinh_lo_chot", 5.0).to_f.mm
    @instance_chot_chinh = read("instance_chot_chinh", "ABF_CC")
    @layer_chot_chinh = read("layer_chot_chinh", "ABF_CC")
    @mo_phong_khoan_ngang = read("mo_phong_khoan_ngang", false)
    @chieu_sau_mo_phong = read("chieu_sau_mo_phong", 35.0).to_f.mm
    @instance_khoan_ngang = "ZSU_KN"
    @layer_khoan_ngang = read("layer_khoan_ngang", "ABF_KN")
    @tao_chot_phu = read("tao_chot_phu", true)
    @kieu_chot_phu = read("tiet_dien_tuy_chinh_cp", false) ? "tuy_chinh" : "tron"
    @duong_dan_chot_phu = read("duong_dan_chot_phu", "")
    @tam_can_giua_cp = read("tam_can_giua_cp", true)
    @goc_xoay_cp = read("goc_xoay_cp", 0).to_i
    @can_giua_chot_phu = read("can_giua_chot_phu", true)
    @chot_phu_cach_mat = read("chot_phu_cach_mat", 7.0).to_f.mm
    @duong_kinh_chot_phu = read("duong_kinh_chot_phu", 8.0).to_f.mm
    @ty_le_chot = read("ty_le_chot", ZSU::View.dpi_scale, true).to_f
    @view_dpi = read("view_dpi", ZSU::View.dpi_offset, true).to_f.mm
    @chot_phu_cach_chot_chinh = read("chot_phu_cach_chot_chinh", 35.0).to_f.mm
    @huong_chot_phu = read("huong_chot_phu", "trong")
    @instance_chot_phu = read("instance_chot_phu", "ABF_CC")
    @layer_chot_phu = read("layer_chot_phu", "ABF_CC")
    @mo_phong_cp = read("mo_phong_cp", false)
    @chieu_sau_mo_phong_cp = read("chieu_sau_mo_phong_cp", 35.0).to_f.mm
    @instance_mo_phong_cp = "ZSU_KN"
    @layer_mo_phong_cp = read("layer_mo_phong_cp", "ABF_KN")
    @tao_oc_khoa = read("tao_oc_khoa", true)
    @kieu_khoa = read("tiet_dien_tuy_chinh_khoa", false) ? "tuy_chinh" : "tron"
    @duong_dan_khoa = read("duong_dan_khoa", "")
    @tam_can_giua_khoa = read("tam_can_giua_khoa", true)
    @goc_xoay_khoa = read("goc_xoay_khoa", 0).to_i
    @duong_kinh_lo_khoa = read("duong_kinh_lo_khoa", 15.0).to_f.mm
    @cach_mep_oc_khoa = read("cach_mep_oc_khoa", 35.0).to_f.mm
    @instance_oc_khoa = read("instance_oc_khoa", "ABF_OK")
    @layer_oc_khoa = read("layer_oc_khoa", "ABF_OK")
    @hien_thi_khoang_cach = read("hien_thi_khoang_cach", false)
    @bu_sai_tam = read("bu_sai_tam", (@he_so_dinh_tam - 1.0) * 13, true).to_f.mm
    @sai_so_tam = read("sai_so_tam", @bo_dem_tam - 8, true).to_f.mm
    @shift_auto = false
    @che_do = read("che_do", 0).to_i
    @xoa_parent = nil
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_mode_buttons(
      ["Tạo liên kết", "Đảo mặt", "Xóa liên kết"],
      active_proc: -> { @che_do },
      on_click: -> (i) {
        @che_do = i
        write("che_do", @che_do)
        update_status
        Sketchup.active_model.active_view.invalidate
      }
    )
    init_setting_buttons(
      "Thống kê" => {
        thong_ke_lien_ket: [:switch, "Thống kê liên kết"],
      },
      "Số lượng" => {
        so_luong_co_dinh: [:switch, "Số lượng cố định"],
        so_luong_lien_ket: [:raw, "Số lượng liên kết", -> { @so_luong_co_dinh }, 1],
        khoang_cach: [:mm, "Khoảng cách", -> { !@so_luong_co_dinh }, 0],
      },
      "Vị trí" => {
        cach_deu_hai_dau: [:switch, "Cách đều hai đầu"],
        cach_truoc: [:mm, -> { @cach_deu_hai_dau ? "Cách hai đầu" : "Cách trước" },
                     -> { !(@so_luong_co_dinh && @so_luong_lien_ket == 1 && @cach_deu_hai_dau) }],
        cach_sau: [:mm, "Cách sau",
                   -> { !@cach_deu_hai_dau && !(@so_luong_co_dinh && @so_luong_lien_ket == 1) }],
      },
      "Điều kiện" => {
        van_day_toi_thieu: [:mm, "Ván dày tối thiểu", nil, 0],
        canh_dai_toi_thieu: [:mm, "Cạnh dài tối thiểu", nil, 0],
      },
      "Chốt chính" => {
        tao_chot_chinh: [:switch, "Tạo chốt chính"],
        tiet_dien_tuy_chinh_cc: [:switch, "Tiết diện tùy chỉnh", -> { @tao_chot_chinh }],
        tam_can_giua_cc: [:switch, "Tâm căn giữa",
                          -> { @tao_chot_chinh && @kieu_chot_chinh == "tuy_chinh" }],
        goc_xoay_cc: [:select, "Góc xoay",
                      { 0 => "0°", 90 => "90°", 180 => "180°", 270 => "270°" },
                      -> { @tao_chot_chinh && @kieu_chot_chinh == "tuy_chinh" }],
        can_giua_chot_chinh: [:switch, "Căn giữa thân ván", -> { @tao_chot_chinh }],
        chot_chinh_cach_mat: [:mm, "Cách mặt", -> { @tao_chot_chinh && !@can_giua_chot_chinh }],
        duong_kinh_lo_chot: [:mm, "Đường kính lỗ",
                             -> { @tao_chot_chinh && @kieu_chot_chinh != "tuy_chinh" }, 0],
        mo_phong_khoan_ngang: [:switch, "Mô phỏng", -> { @tao_chot_chinh }],
        chieu_sau_mo_phong: [:mm, "Chiều sâu", -> { @tao_chot_chinh && @mo_phong_khoan_ngang }],
      },
      "Chốt phụ" => {
        tao_chot_phu: [:switch, "Tạo chốt phụ"],
        tiet_dien_tuy_chinh_cp: [:switch, "Tiết diện tùy chỉnh", -> { @tao_chot_phu }],
        tam_can_giua_cp: [:switch, "Tâm căn giữa",
                          -> { @tao_chot_phu && @kieu_chot_phu == "tuy_chinh" }],
        goc_xoay_cp: [:select, "Góc xoay",
                      { 0 => "0°", 90 => "90°", 180 => "180°", 270 => "270°" },
                      -> { @tao_chot_phu && @kieu_chot_phu == "tuy_chinh" }],
        can_giua_chot_phu: [:switch, "Căn giữa thân ván", -> { @tao_chot_phu }],
        chot_phu_cach_mat: [:mm, "Cách mặt", -> { @tao_chot_phu && !@can_giua_chot_phu }],
        duong_kinh_chot_phu: [:mm, "Đường kính lỗ",
                              -> { @tao_chot_phu && @kieu_chot_phu != "tuy_chinh" }, 0],
        chot_phu_cach_chot_chinh: [:mm, "Cách chốt chính",
                                   -> { @tao_chot_phu && @huong_chot_phu != "chinh_giua" }, 0],
        huong_chot_phu: [:select, "Hướng chốt",
                         { "ngoai" => "Ngoài", "trong" => "Trong",
                           "chinh_giua" => "Giữa", "hai_ben" => "Hai bên" },
                         -> { @tao_chot_phu }],
        mo_phong_cp: [:switch, "Mô phỏng", -> { @tao_chot_phu }],
        chieu_sau_mo_phong_cp: [:mm, "Chiều sâu", -> { @tao_chot_phu && @mo_phong_cp }],
      },
      "Ốc khóa" => {
        tao_oc_khoa: [:switch, "Tạo ốc khóa"],
        tiet_dien_tuy_chinh_khoa: [:switch, "Tiết diện tùy chỉnh", -> { @tao_oc_khoa }],
        tam_can_giua_khoa: [:switch, "Tâm căn giữa",
                            -> { @tao_oc_khoa && @kieu_khoa == "tuy_chinh" }],
        goc_xoay_khoa: [:select, "Góc xoay",
                        { 0 => "0°", 90 => "90°", 180 => "180°", 270 => "270°" },
                        -> { @tao_oc_khoa && @kieu_khoa == "tuy_chinh" }],
        duong_kinh_lo_khoa: [:mm, "Đường kính lỗ",
                             -> { @tao_oc_khoa && @kieu_khoa != "tuy_chinh" }, 0],
        cach_mep_oc_khoa: [:mm, "Cách mép", -> { @tao_oc_khoa }, 0],
      },
      "Hiển thị" => {
        hien_thi_khoang_cach: [:switch, "Hiển thị khoảng cách"],
      }
    )
    load_custom_definitions
  end

  def update_preview
    load_custom_definitions
  end

  private

  def load_custom_definition(path, center: false, rotation: 0)
    return [nil, nil, nil, nil] unless path.is_a?(String) && !path.empty? && File.exist?(path)
    defn = Sketchup.active_model.definitions.load(path) rescue nil
    return [nil, nil, nil, nil] unless defn
    containers = defn.entities.to_a.select { |e|
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    }
    return [nil, nil, nil, nil] unless containers.size == 1
    src = containers.first
    src_layer = src.layer
    src_name = src.name
    defn = src.definition
    if center
      bb_center = defn.bounds.center
      src_tr = Geom::Transformation.new([-bb_center.x, -bb_center.y, -bb_center.z])
    else
      src_tr = Geom::Transformation.new
    end
    if rotation != 0
      rot_tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, rotation.degrees)
      src_tr = rot_tr * src_tr
    end
    [defn, src_layer, src_name, src_tr]
  end

  def load_custom_definitions
    if @kieu_chot_chinh == "tuy_chinh"
      @defn_chot_chinh, @src_layer_cc, @src_name_cc, @src_tr_cc =
        load_custom_definition(@duong_dan_chot_chinh,
                               center: @tam_can_giua_cc, rotation: @goc_xoay_cc)
    else
      @defn_chot_chinh = @src_layer_cc = @src_name_cc = @src_tr_cc = nil
    end
    if @kieu_chot_phu == "tuy_chinh"
      @defn_chot_phu, @src_layer_cp, @src_name_cp, @src_tr_cp =
        load_custom_definition(@duong_dan_chot_phu,
                               center: @tam_can_giua_cp, rotation: @goc_xoay_cp)
    else
      @defn_chot_phu = @src_layer_cp = @src_name_cp = @src_tr_cp = nil
    end
    if @kieu_khoa == "tuy_chinh"
      @defn_khoa, @src_layer_k, @src_name_k, @src_tr_k =
        load_custom_definition(@duong_dan_khoa,
                               center: @tam_can_giua_khoa, rotation: @goc_xoay_khoa)
    else
      @defn_khoa = @src_layer_k = @src_name_k = @src_tr_k = nil
    end
    @edges_chot_chinh = extract_defn_edges(@defn_chot_chinh, @src_tr_cc)
    @edges_chot_phu = extract_defn_edges(@defn_chot_phu, @src_tr_cp)
    @edges_khoa = extract_defn_edges(@defn_khoa, @src_tr_k)
    rot_180 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees)
    @src_tr_cc_opp = @src_tr_cc ? rot_180 * @src_tr_cc : nil
    @src_tr_cp_opp = @src_tr_cp ? rot_180 * @src_tr_cp : nil
    @src_tr_k_opp = @src_tr_k ? rot_180 * @src_tr_k : nil
  end

  def extract_defn_edges(defn, src_tr = nil)
    return [] unless defn
    edges = []
    base_tr = src_tr || Geom::Transformation.new
    collect_edges(defn.entities, edges, base_tr)
    edges
  end

  def collect_edges(entities, edges, tr)
    entities.each do |e|
      if e.is_a?(Sketchup::Edge)
        edges << [e.start.position.transform(tr), e.end.position.transform(tr)]
      elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        collect_edges(sub_ents, edges, tr * e.transformation)
      end
    end
  end

  def load_preset(s)
    init_preset(:thong_ke_lien_ket, s)
    init_preset(:ten_hien_thi, s)
    init_preset(:so_luong_co_dinh, s)
    init_preset(:so_luong_lien_ket, s) { |v| v.to_i }
    init_preset(:khoang_cach, s) { |v| v.to_f.mm }
    init_preset(:cach_deu_hai_dau, s)
    init_preset(:cach_truoc, s) { |v| v.to_f.mm }
    init_preset(:cach_sau, s) { |v| v.to_f.mm }
    init_preset(:van_day_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:canh_dai_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:tao_chot_chinh, s)
    @kieu_chot_chinh = s["tiet_dien_tuy_chinh_cc"] ? "tuy_chinh" : "tron"
    init_preset(:duong_dan_chot_chinh, s)
    init_preset(:tam_can_giua_cc, s)
    init_preset(:goc_xoay_cc, s) { |v| v.to_i }
    init_preset(:can_giua_chot_chinh, s)
    init_preset(:chot_chinh_cach_mat, s) { |v| v.to_f.mm }
    init_preset(:duong_kinh_lo_chot, s) { |v| v.to_f.mm }
    init_preset(:instance_chot_chinh, s)
    init_preset(:layer_chot_chinh, s)
    init_preset(:mo_phong_khoan_ngang, s)
    init_preset(:chieu_sau_mo_phong, s) { |v| v.to_f.mm }
    init_preset(:layer_khoan_ngang, s)
    init_preset(:tao_chot_phu, s)
    @kieu_chot_phu = s["tiet_dien_tuy_chinh_cp"] ? "tuy_chinh" : "tron"
    init_preset(:duong_dan_chot_phu, s)
    init_preset(:tam_can_giua_cp, s)
    init_preset(:goc_xoay_cp, s) { |v| v.to_i }
    init_preset(:can_giua_chot_phu, s)
    init_preset(:chot_phu_cach_mat, s) { |v| v.to_f.mm }
    init_preset(:duong_kinh_chot_phu, s) { |v| v.to_f.mm }
    init_preset(:chot_phu_cach_chot_chinh, s) { |v| v.to_f.mm }
    init_preset(:huong_chot_phu, s)
    init_preset(:instance_chot_phu, s)
    init_preset(:layer_chot_phu, s)
    init_preset(:mo_phong_cp, s)
    init_preset(:chieu_sau_mo_phong_cp, s) { |v| v.to_f.mm }
    init_preset(:layer_mo_phong_cp, s)
    init_preset(:tao_oc_khoa, s)
    @kieu_khoa = s["tiet_dien_tuy_chinh_khoa"] ? "tuy_chinh" : "tron"
    init_preset(:duong_dan_khoa, s)
    init_preset(:tam_can_giua_khoa, s)
    init_preset(:goc_xoay_khoa, s) { |v| v.to_i }
    init_preset(:duong_kinh_lo_khoa, s) { |v| v.to_f.mm }
    init_preset(:cach_mep_oc_khoa, s) { |v| v.to_f.mm }
    init_preset(:instance_oc_khoa, s)
    init_preset(:layer_oc_khoa, s)
    load_custom_definitions
  end

  def reset_state
    @target_faces = []
    @target_face = nil
    @target_parent = nil
    @mortise_parent = nil
    @target_org = []
    @mortise_cache = {}
    @nearby_cache = {}
    @xoa_parent = nil
    @xoa_faces = nil
    @xoa_edges = nil
    @xoa_current_id = nil
    @xoa_id_groups = nil
    @hit_point = nil
    @shift_face = nil
    @shift_face_pts = nil
    @shift_parent = nil
    @dao_mat_original_face = nil
    @dao_mat_cnc_faces = nil
    @dao_mat_tr = nil
    @dao_mat_subgroup = nil
    @dao_mat_subgroup_parent = nil
    @dao_mat_subgroup_pts = nil
    @dao_mat_subgroup_edges = nil
    @alt_mode = false
  end

  def update_status
    secondary = @so_luong_co_dinh ?
      "Số liên kết [/x]: #{@so_luong_lien_ket}" :
      "Khoảng cách [/x]: #{Sketchup.format_length(@khoang_cach)}"
    if @cach_deu_hai_dau
      ZSU.vcb("#{secondary} | Cách hai đầu", Sketchup.format_length(@cach_truoc))
    else
      ZSU.vcb(
        "#{secondary} | Cách trước sau",
        "#{Sketchup.format_length(@cach_truoc)}, #{Sketchup.format_length(@cach_sau)}"
      )
    end
    case @che_do
    when 1
      ZSU.status(
        "Nhấn Tab để chuyển chế độ. " \
        "Giữ Shift để chọn mặt đối diện."
      )
    when 2
      ZSU.status(
        "Nhấn Tab để chuyển chế độ. " \
        "Giữ Shift để xóa toàn bộ liên kết trên ván."
      )
    else
      ZSU.status(
        "Nhấn Tab để chuyển chế độ. " \
        "Giữ Ctrl để đánh liên kết đối xứng. " \
        "Giữ Shift để đánh liên kết ở tất cả các cạnh. " \
        "Giữ Alt để đảo mặt đánh liên kết."
      )
    end
  end

  def update_dao_mat_face
    return unless @dao_mat_original_face&.valid? && @dao_mat_cnc_faces && @dao_mat_tr
    f = @dao_mat_original_face
    picked = @shift_auto ? (@dao_mat_cnc_faces.to_a - [f]).first || f : f
    @shift_face = picked
    @shift_face_pts = picked.outer_loop.vertices.map { |v| v.position.transform(@dao_mat_tr) }
  end

  def update_picked_face
    return unless @target_faces
    @target_faces.each do |t|
      parent = t[:parent]
      fb = ZSU::Board.get_cnc_faces(parent)
      next unless fb && fb.size >= 2
      f = t[:original_face] || t[:picked_face]
      t[:picked_face] = @alt_mode ? (fb.to_a - [f]).first || f : f
    end
  end

  def update_ctrl_faces
    return if @shift_auto
    if @ctrl_mode
      return unless @target_face && @target_face.valid? &&
                    @target_parent && @target_parent.valid?
      band_faces = ZSU.grep_ents(@target_parent, :face).to_a - ZSU::Board.get_cnc_faces(@target_parent).to_a
      opposite = band_faces.find { |face|
        face.valid? && face.normal.reverse == @target_face.normal
      }
      if opposite
        @target_faces << { face: opposite, parent: @target_parent,
                           picked_face: @target_faces.first&.dig(:picked_face),
                           original_face: @target_faces.first&.dig(:original_face),
                           opposite: true }
      end
    else
      return unless @target_faces && @target_faces.size > 1
      @target_faces = [@target_faces.first]
      @target_face = @target_faces.first[:face]
    end
  end

  def update_target_faces
    if @shift_auto
      if @selected_entities.size > 0
        @target_faces = find_all_faces_with_filter(@selected_entities)
      elsif @target_parent
        @target_faces = find_all_faces([@target_parent])
      end
    else
      @target_faces = @target_org.dup
    end
  end

  def find_all_faces(ents)
    min_len = @cach_deu_hai_dau ? @cach_truoc * 2 : @cach_truoc + @cach_sau
    faces = ZSU::Board.get_band_faces(ents, min_len).to_a
    faces.each do |data|
      exd = ZSU::Board.get_cnc_faces(data[:parent])
      pf = exd&.first
      data[:original_face] = pf
      data[:picked_face] = @alt_mode && exd && exd.size >= 2 ? (exd.to_a - [pf]).first || pf : pf
    end
    faces
  end

  def find_all_faces_with_filter(ents)
    faces = find_all_faces(ents)
    if @tao_chot_chinh || @tao_chot_phu
      faces.select! do |data|
        mortises = find_mortise_parent(data[:face], data[:parent])
        !mortises.empty? && mortises.any? { |m| @selected_entities.include?(m) }
      end
    end
    faces
  end

  def calc_so_luong_lien_ket(distance)
    if !@so_luong_co_dinh
      return 1 if @khoang_cach.nil? || @khoang_cach <= 0
      return 1 if distance <= @khoang_cach
      n = (distance / @khoang_cach).round + 1
      [n, 1].max
    else
      @so_luong_lien_ket
    end
  end

  def tinh_hinh_hoc_mot
    return unless @target_face && @target_parent
    tr = @target_parent.transformation
    if @van_day_toi_thieu > 0
      t_thickness = ZSU::Board.calc_thickness(@target_parent)
      return unless (t_thickness - @van_day_toi_thieu).abs < 0.01.mm || t_thickness >= @van_day_toi_thieu
    end
    need_mortise = @tao_chot_chinh || @tao_chot_phu
    if need_mortise
      mortise_parents = find_mortise_parent(@target_face, @target_parent) || []
      return if mortise_parents.empty?
      if @van_day_toi_thieu > 0
        mortise_parents = mortise_parents.select do |mp|
          m_thickness = ZSU::Board.calc_thickness(mp)
          (m_thickness - @van_day_toi_thieu).abs < 0.01.mm || m_thickness >= @van_day_toi_thieu
        end
        return if mortise_parents.empty?
      end
    else
      mortise_parents = [nil]
    end
    pairs = ZSU::Face.rectangle_edges(@target_face)
    return unless pairs
    e1, e2 = pairs.min_by { |pair|
      e = pair[0]
      a1, a2 = e.vertices.map { |v| v.position.transform(tr) }
      a1.distance(a2)
    }
    a1, a2 = e1.vertices.map { |v| v.position.transform(tr) }
    b1, b2 = e2.vertices.map { |v| v.position.transform(tr) }
    v1 = a1.vector_to(a2)
    v2 = b1.vector_to(b2)
    return unless v1.parallel?(v2)
    if v1.dot(v2) < 0
      b1, b2 = b2, b1
      v2 = b1.vector_to(b2)
    end
    proj_a1 = a1.project_to_line([b1, v2])
    normal_vector = a1.vector_to(proj_a1)
    unit_normal = normal_vector.normalize
    unit_v1 = v1.normalize
    orig_mid_a = Geom::linear_combination(0.5, a1, 0.5, a2)
    len = a1.distance(a2)
    transformed_normal = @target_face.normal.transform(tr)
    transformed_normal.normalize!
    sorted_edges = @target_face.edges.sort_by { |e| -e.length }
    le1 = sorted_edges[0].vertices.map { |v| v.position.transform(tr) }
    le2 = sorted_edges[1].vertices.map { |v| v.position.transform(tr) }
    face_side = 1
    if @picked_face && @picked_face.valid?
      pf_normal_world = @picked_face.normal.transform(tr)
      face_side = pf_normal_world.dot(unit_v1) < 0 ? -1 : 1
    end
    results = []
    mortise_parents.each do |mp|
      if mp
        le1_pts = edge_contact_points(le1, mp)
        le2_pts = edge_contact_points(le2, mp)
        next if le1_pts.size < 2 || le2_pts.size < 2
        le1_pts.sort_by! { |pt| (pt - orig_mid_a).dot(unit_normal) }
        le2_pts.sort_by! { |pt| (pt - orig_mid_a).dot(unit_normal) }
        contact_start = Geom.linear_combination(0.5, le1_pts.first, 0.5, le2_pts.first)
        contact_end = Geom.linear_combination(0.5, le1_pts.last, 0.5, le2_pts.last)
      else
        le1_sorted = le1.sort_by { |pt| (pt - orig_mid_a).dot(unit_normal) }
        le2_sorted = le2.sort_by { |pt| (pt - orig_mid_a).dot(unit_normal) }
        contact_start = Geom.linear_combination(0.5, le1_sorted.first, 0.5, le2_sorted.first)
        contact_end = Geom.linear_combination(0.5, le1_sorted.last, 0.5, le2_sorted.last)
      end
      total_dist = contact_start.distance(contact_end)
      mid_a = contact_start

      if @cach_deu_hai_dau
        cach_truoc = @cach_truoc
        cach_sau = @cach_truoc
      else
        near_start = !@hit_point || contact_start.distance(@hit_point) <= contact_end.distance(@hit_point)
        cach_truoc = near_start ? @cach_truoc : @cach_sau
        cach_sau = near_start ? @cach_sau : @cach_truoc
      end
      mot_mong_rieng = @so_luong_co_dinh && @so_luong_lien_ket == 1 && !@cach_deu_hai_dau
      cach_sau = 0 if mot_mong_rieng

      offset_start = cach_truoc
      offset_end = total_dist - cach_sau

      if offset_end > offset_start
        start_point = mid_a.offset(unit_normal, offset_start)
        end_point = mid_a.offset(unit_normal, offset_end)
        distance = start_point.distance(end_point)
        so_luong_lien_ket = calc_so_luong_lien_ket(distance)
        so_luong_lien_ket = [so_luong_lien_ket, 1].max
      else
        so_luong_lien_ket = 1
      end
      if so_luong_lien_ket == 1
        if mot_mong_rieng
          center_offset = near_start ? @cach_truoc : total_dist - @cach_truoc
          start_point = mid_a.offset(unit_normal, center_offset)
          end_point = start_point
        else
          start_point = mid_a
          end_point = mid_a.offset(unit_normal, total_dist)
        end
      end
      divisor = so_luong_lien_ket > 1 ? so_luong_lien_ket - 1 : 1
      results << {
        start_point: start_point,
        end_point: end_point,
        unit_v1: unit_v1,
        transformed_normal: transformed_normal,
        len: len,
        divisor: divisor,
        transform: tr,
        so_luong_lien_ket: so_luong_lien_ket,
        mortise_parent: mp,
        face_side: face_side,
        edge_start: mid_a,
        edge_end: mid_a.offset(unit_normal, total_dist)
      }
    end
    results.empty? ? nil : results
  end

  def tinh_hinh_hoc
    geometries = []
    new_targets = []
    return unless @target_faces && @target_faces.size > 0
    ref_dir = nil
    @target_faces.each do |target|
      @target_face = target[:face]
      @target_parent = target[:parent]
      @picked_face = target[:picked_face]
      geos = tinh_hinh_hoc_mot
      if geos
        dir = geos[0][:start_point].vector_to(geos[0][:end_point])
        if ref_dir.nil?
          ref_dir = dir if dir.valid?
        elsif dir.valid? && ref_dir.dot(dir) < 0
          geos.each do |geo|
            geo[:start_point], geo[:end_point] = geo[:end_point], geo[:start_point]
            geo[:edge_start], geo[:edge_end] = geo[:edge_end], geo[:edge_start]
          end
        end
        geos.each do |geo|
          geo[:opposite] = target[:opposite]
          geometries << geo
          new_targets << target
        end
      end
    end
    @target_faces = new_targets
    geometries
  end

  CIRCLE_SEGMENTS = 24
  ROT_180 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees)

  def draw_circle_preview(center, radius, segments, ax1, ax2)
    pts = (0...segments).map do |j|
      angle = 2 * Math::PI * j / segments
      center.offset(ax1, Math.cos(angle) * radius).offset(ax2, Math.sin(angle) * radius)
    end
    ZSU::View.draw2d_polygon(pts)
  end

  def draw_defn_preview(edges, center, xaxis, yaxis, zaxis, opposite: false)
    return unless edges && !edges.empty?
    tr = Geom::Transformation.axes(center, xaxis, yaxis, zaxis)
    tr = tr * ROT_180 if opposite
    pts = edges.flat_map { |pair| pair.map { |p| p.transform(tr) } }
    ZSU::View.draw2d_lines(pts)
  end

  def find_hover_component(datas)
    return nil unless @mouse_x && @mouse_y
    datas.each do |data|
      next unless data
      so_luong_lien_ket = data[:so_luong_lien_ket]
      xaxis = data[:transformed_normal]
      zaxis = data[:unit_v1]
      yaxis = zaxis * xaxis
      face_side = data[:face_side] || 1
      half_len = data[:len] / 2.0

      (0...so_luong_lien_ket).each do |i|
        t = so_luong_lien_ket == 1 ? 0.5 : i.to_f / data[:divisor]
        bp = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        if @tao_oc_khoa
          center = bp.offset(xaxis.reverse, @cach_mep_oc_khoa).offset(zaxis, face_side * half_len)
          r = @duong_kinh_lo_khoa / 2.0
          hit = ZSU::View.point_in_circle_2d?(@mouse_x, @mouse_y, center, r, xaxis, yaxis)
          return { data: data, index: i } if hit
        end
        if @tao_chot_chinh
          mortise_center = @can_giua_chot_chinh ? bp : base_point.offset(zaxis, face_side * (half_len - @chot_chinh_cach_mat))
          r = @duong_kinh_lo_chot / 2.0
          hit = ZSU::View.point_in_circle_2d?(@mouse_x, @mouse_y, mortise_center, r, yaxis, zaxis)
          return { data: data, index: i } if hit
        end
        if @tao_chot_phu
          pilot_offset = @chot_phu_cach_chot_chinh
          base_vec = (data[:start_point] - data[:end_point])
          pilot_base = @can_giua_chot_phu ? bp : base_point.offset(zaxis, face_side * (half_len - @chot_phu_cach_mat))
          centers = if base_vec.length == 0
                      [pilot_base]
                    else
                      case @huong_chot_phu
                      when "hai_ben"
                        base_vec_norm = base_vec.normalize
                        [-1, 1].map { |side| pilot_base.offset(base_vec_norm, side * pilot_offset) }
                      when "chinh_giua"
                        [pilot_base]
                      else
                        pilot_vec = base_vec.normalize
                        pilot_vec = pilot_vec.reverse if @huong_chot_phu == "trong"
                        pilot_vec = pilot_vec.reverse if (i + 1) > (so_luong_lien_ket.to_f / 2)
                        pilot_vec.length = pilot_offset
                        [pilot_base.transform(Geom::Transformation.translation(pilot_vec))]
                      end
                    end
          r = @duong_kinh_chot_phu / 2.0
          centers.each do |center|
            hit = ZSU::View.point_in_circle_2d?(@mouse_x, @mouse_y, center, r, yaxis, zaxis)
            return { data: data, index: i } if hit
          end
        end
      end
    end
    nil
  end

  def draw_joint_preview(data)
    so_luong_lien_ket = data[:so_luong_lien_ket]
    xaxis = data[:transformed_normal]
    zaxis = data[:unit_v1]
    yaxis = zaxis * xaxis
    face_side = data[:face_side] || 1
    half_len = data[:len] / 2.0
    (0...so_luong_lien_ket).each do |i|
      t = so_luong_lien_ket == 1 ? 0.5 : i.to_f / data[:divisor]
      base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
      hovered = @hover_component && @hover_component[:data].equal?(data) && @hover_component[:index] == i
      if hovered
        old_w = ZSU::View.edge_weight
        ZSU::View.set_edge_weight(old_w + 1)
      end
      opp = data[:opposite]
      if @tao_chot_chinh
        mortise_center = @can_giua_chot_chinh ? base_point : base_point.offset(zaxis, face_side * (half_len - @chot_chinh_cach_mat))
        if @defn_chot_chinh
          draw_defn_preview(@edges_chot_chinh, mortise_center, zaxis.reverse, yaxis, xaxis, opposite: opp)
        else
          draw_circle_preview(mortise_center, @duong_kinh_lo_chot / 2.0, CIRCLE_SEGMENTS, yaxis, zaxis)
        end
      end
      if @tao_oc_khoa
        center = base_point.offset(xaxis.reverse, @cach_mep_oc_khoa).offset(zaxis, face_side * half_len)
        if @defn_khoa
          draw_defn_preview(@edges_khoa, center, xaxis, yaxis, zaxis, opposite: opp)
        else
          draw_circle_preview(center, @duong_kinh_lo_khoa / 2.0, CIRCLE_SEGMENTS, xaxis, yaxis)
        end
      end
      if @tao_chot_phu
        draw_pilot_preview(data, base_point, i, so_luong_lien_ket, xaxis, yaxis, zaxis)
      end
      ZSU::View.set_edge_weight(old_w) if hovered
    end
  end

  def draw_pilot_preview(data, base_point, i, so_luong_lien_ket, xaxis, yaxis, zaxis)
    pilot_offset = @chot_phu_cach_chot_chinh
    base_vec = (data[:start_point] - data[:end_point])
    return if base_vec.length == 0
    base_vec_norm = base_vec.normalize
    face_side = data[:face_side] || 1
    half_len = data[:len] / 2.0
    pilot_base = @can_giua_chot_phu ? base_point : base_point.offset(zaxis, face_side * (half_len - @chot_phu_cach_mat))

    centers = case @huong_chot_phu
              when "hai_ben"
                [-1, 1].map { |side| pilot_base.offset(base_vec_norm, side * pilot_offset) }
              when "chinh_giua"
                [pilot_base]
              else
                pilot_vec = base_vec.normalize
                pilot_vec = pilot_vec.reverse if @huong_chot_phu == "trong"
                pilot_vec = pilot_vec.reverse if (i + 1) > (so_luong_lien_ket.to_f / 2)
                pilot_vec.length = pilot_offset
                [pilot_base.transform(Geom::Transformation.translation(pilot_vec))]
              end
    opp = data[:opposite]
    centers.each do |center|
      if @defn_chot_phu
        draw_defn_preview(@edges_chot_phu, center, zaxis.reverse, yaxis, xaxis, opposite: opp)
      else
        draw_circle_preview(center, @duong_kinh_chot_phu / 2.0, CIRCLE_SEGMENTS, yaxis, zaxis)
      end
    end
  end

  def draw_joint_texts(data)
    so_luong_lien_ket = data[:so_luong_lien_ket]
    return if so_luong_lien_ket < 1
    precision = ZSU::Model.get_unit_precision
    edge_start = data[:edge_start]
    edge_end = data[:edge_end]
    dir = edge_start.vector_to(edge_end)
    return unless dir.valid?

    centers = (0...so_luong_lien_ket).map do |i|
      t = so_luong_lien_ket == 1 ? 0.5 : i.to_f / data[:divisor]
      Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
    end

    points = [edge_start] + centers + [edge_end]
    loop_limit_text = 0
    (0...points.size - 1).each do |i|
      loop_limit_text += 1
      break if loop_limit_text > 500
      gap = points[i].distance(points[i + 1])
      if gap > 0.1.mm
        mid = Geom.linear_combination(0.5, points[i], 0.5, points[i + 1])
        ZSU::View.draw2d_text(format("%.#{precision}f", gap.to_mm), mid)
      end
    end
  end

  def create_shape_group(center, normal, radius)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    grp.entities.add_circle(center, normal, radius * @ty_le_chot + @sai_so_tam + @bu_sai_tam, CIRCLE_SEGMENTS)
    center_origin_raw(grp)
    grp
  end

  def center_origin_raw(group)
    definition = group.definition
    entities = definition.entities
    new_origin = definition.bounds.center
    new_axes = Geom::Transformation.axes(new_origin, X_AXIS, Y_AXIS, Z_AXIS)
    entities.transform_entities(new_axes.inverse, entities.to_a)
    definition.instances.each { |instance| instance.transformation *= new_axes }
  end

  def draw_tenon(z, face_side = 1)
    return nil if @defn_khoa
    center = Geom::Point3d.new(-@cach_mep_oc_khoa, 0, face_side * z / 2.0)
    create_shape_group(center, Geom::Vector3d.new(0, 0, face_side.to_f), @duong_kinh_lo_khoa / 2.0)
  end

  def draw_mortise(z, face_side = 1)
    return nil if @defn_chot_chinh
    center_z = @can_giua_chot_chinh ? 0 : face_side * (z / 2.0 - @chot_chinh_cach_mat)
    center = Geom::Point3d.new(0, 0, center_z)
    create_shape_group(center, Geom::Vector3d.new(1, 0, 0), @duong_kinh_lo_chot / 2.0)
  end

  def draw_pilot(d, z = 0, face_side = 1)
    return nil if @defn_chot_phu
    center_z = @can_giua_chot_phu ? 0 : face_side * (z / 2.0 - @chot_phu_cach_mat)
    center = Geom::Point3d.new(0, 0, center_z)
    create_shape_group(center, Geom::Vector3d.new(1, 0, 0), d / 2)
  end

  def draw_rect_marker(depth, z, face_side = 1)
    grp = ZSU::Model.active_entities.add_group
    z_pos = face_side * z / 2.0
    pts = [
      Geom::Point3d.new(0, -4.mm, z_pos),
      Geom::Point3d.new(-depth, -4.mm, z_pos),
      Geom::Point3d.new(-depth, 4.mm, z_pos),
      Geom::Point3d.new(0, 4.mm, z_pos)
    ]
    pts.each_with_index { |pt, i| grp.entities.add_line(pt, pts[(i + 1) % pts.size]) }
    center_origin_raw(grp)
    grp
  end

  def draw_circle_marker(center_z)
    center = Geom::Point3d.new(0, 0, center_z)
    create_shape_group(center, Geom::Vector3d.new(1, 0, 0), 4.mm)
  end

  def apply_instance_attrs(new_inst, custom_defn, layer, instance_name, minifix: false)
    if custom_defn
      if @thong_ke_lien_ket
        ZSU::ABF.set_statistical(new_inst, @ten_hien_thi)
      end
    else
      new_inst.layer = layer
      new_inst.name = instance_name
      if minifix && @thong_ke_lien_ket
        ZSU::ABF.set_minifix(new_inst, @ten_hien_thi)
      end
      new_inst.entities.to_a.each { |e| e.layer = layer }
    end
  end

  def place_clone_in_parent(base_grp, tr, parent, layer, instance_name, minifix: false)
    clone = base_grp.copy
    clone.transform!(tr)
    p_ents = ZSU.get_ents(parent)
    parent_tr = parent.transformation.inverse * clone.transformation
    new_inst = p_ents.add_instance(clone.definition, parent_tr)
    apply_instance_attrs(new_inst, nil, layer, instance_name, minifix: minifix)
    clone.erase!
    new_inst
  end

  def place_defn_in_parent(defn, center_tr, world_tr, parent,
                           rot_axes: nil, src_layer: nil, src_name: nil, src_tr: nil)
    local_tr = rot_axes ? Geom::Transformation.axes(ORIGIN, *rot_axes) : Geom::Transformation.new
    src_local = src_tr || Geom::Transformation.new
    full_tr = world_tr * center_tr * local_tr * src_local
    parent_tr = parent.transformation.inverse * full_tr
    p_ents = ZSU.get_ents(parent)
    new_inst = p_ents.add_instance(defn, parent_tr)
    new_inst.layer = src_layer if src_layer
    new_inst.name = src_name if src_name && !src_name.empty?
    apply_instance_attrs(new_inst, defn, nil, nil)
    new_inst
  end

  def pilot_vectors(data, i, so_luong_lien_ket)
    offset = @chot_phu_cach_chot_chinh
    base_vec = (data[:start_point] - data[:end_point])
    return [nil] if base_vec.length == 0
    case @huong_chot_phu
    when "hai_ben"
      v = base_vec.clone
      v.length = offset
      [v, v.reverse]
    when "chinh_giua"
      [nil]
    else
      v = base_vec.clone
      v = v.reverse if @huong_chot_phu == "trong"
      v = v.reverse if (i + 1) > (so_luong_lien_ket.to_f / 2)
      v.length = offset
      [v]
    end
  end

  def create_pilots(tr, data, i, so_luong_lien_ket, m_ents, pilot_layer)
    pilot_vectors(data, i, so_luong_lien_ket).each do |pv|
      add_pilot_instance(tr, pv, m_ents, pilot_layer)
    end
  end

  def add_pilot_instance(tr, pilot_vec, m_ents, pilot_layer)
    pilot_tr = pilot_vec ? Geom::Transformation.translation(pilot_vec) * tr : tr
    if @defn_chot_phu
      center_z = @can_giua_chot_phu ? 0 : (@face_side || 1) * (@cur_len / 2.0 - @chot_phu_cach_mat)
      center_tr = Geom::Transformation.new(Geom::Point3d.new(0, 0, center_z))
      src_tr = @is_opposite ? @src_tr_cp_opp : @src_tr_cp
      inst = place_defn_in_parent(@defn_chot_phu, center_tr, pilot_tr, @mortise_parent,
                                   rot_axes: [Z_AXIS.reverse, Y_AXIS, X_AXIS],
                                   src_layer: @src_layer_cp, src_name: @src_name_cp,
                                   src_tr: src_tr)
      if inst
        inst.set_attribute("ZSU", "lien_ket", true)
        inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
      end
    else
      pilot_clone = @base_pilot.copy
      pilot_clone.transform!(pilot_tr)
      p_parent_tr = @mortise_parent.transformation.inverse * pilot_clone.transformation
      new_inst = m_ents.add_instance(pilot_clone.definition, p_parent_tr)
      apply_instance_attrs(new_inst, nil, pilot_layer, @instance_chot_phu)
      new_inst.set_attribute("ZSU", "lien_ket", true)
      new_inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
      if !@tao_oc_khoa && !@tao_chot_chinh && @thong_ke_lien_ket
        ZSU::ABF.set_statistical(new_inst, @ten_hien_thi)
      end
      pilot_clone.erase!
    end
  end

  def create_mo_phong_cp(tr, data, i, so_luong_lien_ket, mo_phong_cp_layer)
    pilot_vectors(data, i, so_luong_lien_ket).each do |pv|
      place_mo_phong_cp(tr, pv, mo_phong_cp_layer)
    end
  end

  def place_marker_clone(base_grp, applied_tr, parent, layer, instance_name)
    return unless base_grp
    t_ents = ZSU.get_ents(parent)
    return unless t_ents && ZSU.is_container?(parent)
    clone = base_grp.copy
    clone.transform!(applied_tr)
    p_tr = parent.transformation.inverse * clone.transformation
    inst = t_ents.add_instance(clone.definition, p_tr)
    inst.layer = layer
    inst.name = instance_name
    inst.entities.to_a.each { |e| e.layer = layer }
    inst.set_attribute("ZSU", "lien_ket", true)
    clone.erase!
    inst
  end

  def place_marker_group(specs, kind)
    return if specs.empty?
    t_ents = ZSU.get_ents(@target_parent)
    return unless t_ents && ZSU.is_container?(@target_parent)
    grp = t_ents.add_group
    grp.name = "ZSU_KN"
    grp.set_attribute("ZSU", "lien_ket", true)
    grp.set_attribute("ZSU", "lien_ket_id", @current_set_id)
    parent_inv = @target_parent.transformation.inverse
    grp_inv = grp.transformation.inverse
    specs.each do |spec|
      base, applied_tr, inst_layer = spec[0], spec[1], spec[2]
      next unless base
      clone = base.copy
      clone.transform!(applied_tr)
      inner_tr = grp_inv * parent_inv * clone.transformation
      inst = grp.entities.add_instance(clone.definition, inner_tr)
      inst.layer = inst_layer
      inst.entities.to_a.each { |e| e.layer = inst_layer }
      case kind
      when :rect
        ZSU::ABF.set_side_drill_depth(inst)
      when :circle
        ZSU::ABF.set_side_drill(inst, spec[3])
      end
      clone.erase!
    end
    grp
  end

  def place_mo_phong_cp(tr, pilot_vec, mo_phong_cp_layer)
    pilot_tr = pilot_vec ? Geom::Transformation.translation(pilot_vec) * tr : tr
    if @base_mp_cp_rect
      inst = place_marker_clone(@base_mp_cp_rect, pilot_tr, @target_parent, mo_phong_cp_layer, @instance_mo_phong_cp)
      ZSU::ABF.set_side_drill_depth(inst) if inst
    end
    if @base_mp_cp_circle
      inst = place_marker_clone(@base_mp_cp_circle, pilot_tr, @target_parent, mo_phong_cp_layer, @instance_mo_phong_cp)
      ZSU::ABF.set_side_drill(inst, @chieu_sau_mo_phong_cp.to_mm.to_f) if inst
    end
  end

  def edge_contact_points(edge_world, group)
    g_tr_inv = group.transformation.inverse
    p1l = edge_world[0].transform(g_tr_inv)
    p2l = edge_world[1].transform(g_tr_inv)
    cac_diem = []
    loop_limit_contact = 0
    ZSU.get_ents(group).grep(Sketchup::Face).to_a.each do |face|
      loop_limit_contact += 1
      break if loop_limit_contact > 500
      plane = face.plane
      next unless p1l.distance_to_plane(plane).abs < 1.mm && p2l.distance_to_plane(plane).abs < 1.mm
      [p1l, p2l].each do |pt|
        cl = face.classify_point(pt)
        cac_diem << pt if cl == Sketchup::Face::PointInside ||
                          cl == Sketchup::Face::PointOnEdge ||
                          cl == Sketchup::Face::PointOnVertex
      end
      face.edges.to_a.each do |ef|
        giao = giao_2_doan(p1l, p2l, ef.start.position, ef.end.position)
        cac_diem << giao if giao
      end
    end
    cac_diem.uniq! { |pt| [pt.x.round(4), pt.y.round(4), pt.z.round(4)] }
    cac_diem.map { |pt| pt.transform(group.transformation) }
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

  def find_nearby_groups(parent)
    @nearby_cache ||= {}
    cache_key = parent.entityID
    return @nearby_cache[cache_key] if @nearby_cache.key?(cache_key)

    b1 = parent.bounds
    result = ZSU::Model.active_entities.to_a.select { |g|
      next unless ZSU.is_container?(g)
      next if g.hidden? || !g.layer.visible?
      next if g == parent
      next if g.name == @instance_chot_chinh
      next if g.name == @instance_oc_khoa
      next if g.name == @instance_chot_phu
      next if g.name == @instance_khoan_ngang
      next if g.name == "_ABF_Label"
      next if g.name == "_ABF_Intersect"
      b2 = g.bounds
      bb = Geom::BoundingBox.new
      bb.add(b1.min, b1.max, b2.min, b2.max)
      next unless bb.width <= b1.width + b2.width &&
                  bb.height <= b1.height + b2.height &&
                  bb.depth <= b1.depth + b2.depth
      true
    }
    @nearby_cache[cache_key] = result
    result
  end

  def find_mortise_parent(face = @target_face, parent = @target_parent)
    return unless face && face.valid? && parent
    @mortise_cache ||= {}
    cache_key = face.entityID
    return @mortise_cache[cache_key] if @mortise_cache.key?(cache_key)

    tr = parent.transformation
    sorted = face.edges.sort_by { |e| -e.length }
    e1 = sorted[0]
    e2 = sorted[1]
    unless e1 && e2
      @mortise_cache[cache_key] = []
      return []
    end
    line1 = e1.vertices.map { |v| v.position.transform(tr) }
    line2 = e2.vertices.map { |v| v.position.transform(tr) }
    band_normal = face.normal.transform(tr)
    band_mid = Geom.linear_combination(0.5, line1[0], 0.5, line1[1])

    nearby = find_nearby_groups(parent)
    loop_limit_mortise = 0
    result = nearby.select { |g|
      loop_limit_mortise += 1
      break if loop_limit_mortise > 500
      g_tr = g.transformation
      largest = ZSU::Board.get_cnc_faces(g)
      next unless largest && largest.size >= 2
      closest_cf = largest.min_by { |cf|
        plane = [cf.bounds.center.transform(g_tr), cf.normal.transform(g_tr)]
        band_mid.distance_to_plane(plane).abs
      }
      cn = closest_cf.normal.transform(g_tr)
      next unless cn.parallel?(band_normal) && cn.dot(band_normal) < 0
      le1_pts = edge_contact_points(line1, g)
      le2_pts = edge_contact_points(line2, g)
      le1_pts.size >= 2 && le2_pts.size >= 2
    }
    @mortise_cache[cache_key] = result
    result
  end

  def tim_nhom_xoa(parent)
    return [] unless parent.valid?
    groups = []
    sub_ents = ZSU.get_ents(parent).to_a
    parent_tr = parent.transformation
    if sub_ents
      sub_ents.each do |e|
        next unless (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid?
        next unless e.get_attribute("ZSU", "lien_ket")
        groups << { grp: e, parent_tr: parent_tr }
      end
    end
    fb = ZSU::Board.get_cnc_faces(parent)
    if fb
      band_faces = ZSU.grep_ents(parent, :face).to_a - fb.to_a
      if band_faces && !band_faces.empty?
        entities = ZSU::Model.active_entities.to_a
        loop_limit_xoa = 0
        entities.each do |container|
          loop_limit_xoa += 1
          break if loop_limit_xoa > 1000
          next unless (container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)) && container.valid?
          next if container == parent
          c_ents = container.is_a?(Sketchup::Group) ? container.entities.to_a : container.definition.entities.to_a
          c_tr = container.transformation
          c_ents.each do |e|
            next unless (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid?
            next unless e.get_attribute("ZSU", "lien_ket")
            center_world = e.transformation.origin.transform(c_tr)
            center_in_parent = center_world.transform(parent_tr.inverse)
            on_band = band_faces.any? do |face|
              next false unless face.valid?
              cl = face.classify_point(center_in_parent)
              cl == Sketchup::Face::PointInside ||
              cl == Sketchup::Face::PointOnEdge ||
              cl == Sketchup::Face::PointOnVertex
            end
            groups << { grp: e, parent_tr: c_tr } if on_band
          end
        end
      end
    end
    groups
  end

  def update_xoa_preview
    @xoa_faces = []
    @xoa_edges = []
    @xoa_current_id = nil
    @xoa_id_groups = nil
    return unless @xoa_parent&.valid?
    groups = tim_nhom_xoa(@xoa_parent)
    groups.each do |entry|
      grp = entry[:grp]
      next unless grp.valid?
      world_tr = entry[:parent_tr] * grp.transformation
      ents = grp.is_a?(Sketchup::Group) ? grp.entities.to_a : grp.definition.entities.to_a
      collect_xoa_geometry(ents, world_tr)
    end
  end

  def collect_xoa_geometry(entities, tr)
    entities.each do |e|
      if e.is_a?(Sketchup::Face)
        @xoa_faces << e.outer_loop.vertices.map { |v| v.position.transform(tr) }
      elsif e.is_a?(Sketchup::Edge) && e.faces.empty?
        @xoa_edges << e.start.position.transform(tr) << e.end.position.transform(tr)
      elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        sub_ents = e.is_a?(Sketchup::Group) ? e.entities.to_a : e.definition.entities.to_a
        collect_xoa_geometry(sub_ents, tr * e.transformation)
      end
    end
  end

  def find_lien_ket_group(edge, parent)
    return nil unless edge
    sub_ents = ZSU.get_ents(parent).to_a
    return nil unless sub_ents
    sub_ents.each do |e|
      next unless ZSU.is_container?(e) && e.valid?
      next unless e.get_attribute("ZSU", "lien_ket")
      return e if container_has_edge?(e, edge)
    end
    nil
  end

  def container_has_edge?(container, edge)
    ents = container.is_a?(Sketchup::Group) ? container.entities.to_a : container.definition.entities.to_a
    return true if ents.grep(Sketchup::Edge).include?(edge)
    ents.each do |inner|
      next unless ZSU.is_container?(inner) && inner.valid?
      return true if container_has_edge?(inner, edge)
    end
    false
  end

  def find_groups_by_id(lk_id)
    groups = []
    ZSU::Model.active_entities.to_a.each do |container|
      next unless ZSU.is_container?(container) && container.valid?
      c_ents = container.is_a?(Sketchup::Group) ? container.entities.to_a : container.definition.entities.to_a
      c_ents.each do |e|
        next unless ZSU.is_container?(e) && e.valid?
        next unless e.get_attribute("ZSU", "lien_ket_id") == lk_id
        groups << e
      end
    end
    groups
  end

  def update_xoa_id_preview
    @xoa_faces = []
    @xoa_edges = []
    return unless @xoa_id_groups
    @xoa_id_groups.each do |grp|
      next unless grp.valid?
      parent = grp.parent
      parent_tr = if parent.is_a?(Sketchup::ComponentDefinition)
                    inst = parent.instances.first
                    inst ? inst.transformation : Geom::Transformation.new
                  else
                    Geom::Transformation.new
                  end
      world_tr = parent_tr * grp.transformation
      ents = grp.is_a?(Sketchup::Group) ? grp.entities.to_a : grp.definition.entities.to_a
      collect_xoa_geometry(ents, world_tr)
    end
  end

  def thuc_hien_chuyen_mat(view)
    return unless @shift_face && @shift_face.valid? && @shift_parent
    face_normal = @shift_face.normal
    face_plane = [@shift_face.bounds.center, face_normal]
    ents = ZSU.get_ents(@shift_parent).to_a
    groups = ents.select { |e| ZSU.is_container?(e) }
    return if groups.empty?

    ZSU.start(false)
    ents.grep(Sketchup::Face).to_a.each { |face| face.delete_attribute("ABF", "is-labeled-face") }
    @shift_face.set_attribute("ABF", "is-labeled-face", true)
    moved_ids = []
    groups.each do |grp|
      center = grp.bounds.center
      projected = center.project_to_plane(face_plane)
      move_vec = center.vector_to(projected)
      next unless move_vec.valid?
      grp.transform!(Geom::Transformation.translation(move_vec))
      next unless grp.get_attribute("ABF", "is-minifix-part-b")
      lk_id = grp.get_attribute("ZSU", "lien_ket_id")
      moved_ids << lk_id if lk_id
    end
    mirror_lien_ket_partners(moved_ids.uniq, groups)
    ZSU.commit
    view.invalidate
  end

  def mirror_lien_ket_partners(partner_ids, own_groups)
    cnc_faces = ZSU::Board.get_cnc_faces(@shift_parent)
    return unless cnc_faces && cnc_faces.size == 2
    shift_tr = @shift_parent.transformation
    mid_world = Geom::Point3d.linear_combination(0.5, cnc_faces[0].bounds.center, 0.5, cnc_faces[1].bounds.center).transform(shift_tr)
    normal_world = cnc_faces[0].normal.transform(shift_tr)
    t_world = mirror_through_plane(mid_world, normal_world)

    partner_ids.each do |lk_id|
      find_lien_ket_with_parent(lk_id).each do |partner, parent_inst|
        next if own_groups.include?(partner)
        next unless partner.valid? && parent_inst.valid?
        inv = parent_inst.transformation.inverse
        partner.transform!(inv * t_world * parent_inst.transformation)
      end
    end
  end

  def find_lien_ket_with_parent(lk_id)
    result = []
    ZSU::Model.active_entities.to_a.each do |container|
      next unless ZSU.is_container?(container) && container.valid?
      c_ents = container.is_a?(Sketchup::Group) ? container.entities.to_a : container.definition.entities.to_a
      c_ents.each do |e|
        next unless ZSU.is_container?(e) && e.valid?
        next unless e.get_attribute("ZSU", "lien_ket_id") == lk_id
        result << [e, container]
      end
    end
    result
  end

  def thuc_hien_dao_mat_subgroup(view)
    return unless @dao_mat_subgroup&.valid? && @dao_mat_subgroup_parent&.valid?
    cnc_faces = ZSU::Board.get_cnc_faces(@dao_mat_subgroup_parent)
    return unless cnc_faces && cnc_faces.size == 2
    parent_tr = @dao_mat_subgroup_parent.transformation
    mid_world = Geom::Point3d.linear_combination(0.5, cnc_faces[0].bounds.center, 0.5, cnc_faces[1].bounds.center).transform(parent_tr)
    normal_world = cnc_faces[0].normal.transform(parent_tr)
    t_world = mirror_through_plane(mid_world, normal_world)

    lk_id = @dao_mat_subgroup.get_attribute("ZSU", "lien_ket_id")
    is_oc_khoa = @dao_mat_subgroup.get_attribute("ABF", "is-minifix-part-b")
    ZSU.start(false)
    @dao_mat_subgroup.transform!(parent_tr.inverse * t_world * parent_tr)
    if lk_id && is_oc_khoa
      find_lien_ket_with_parent(lk_id).each do |partner, partner_parent|
        next if partner == @dao_mat_subgroup
        next unless partner.valid? && partner_parent.valid?
        pp_tr = partner_parent.transformation
        partner.transform!(pp_tr.inverse * t_world * pp_tr)
      end
    end
    ZSU.commit
    @dao_mat_subgroup = nil
    @dao_mat_subgroup_parent = nil
    @dao_mat_subgroup_pts = nil
    @dao_mat_subgroup_edges = nil
    view.invalidate
  end

  def collect_subgroup_highlight(grp, world_tr)
    faces = []
    edges = []
    ents = grp.is_a?(Sketchup::Group) ? grp.entities.to_a : grp.definition.entities.to_a
    collect_subgroup_highlight_recursive(ents, world_tr, faces, edges)
    [faces, edges]
  end

  def collect_subgroup_highlight_recursive(entities, tr, faces, edges)
    entities.each do |e|
      if e.is_a?(Sketchup::Face)
        faces << e.outer_loop.vertices.map { |v| v.position.transform(tr) }
      elsif e.is_a?(Sketchup::Edge) && e.faces.empty?
        edges << e.start.position.transform(tr) << e.end.position.transform(tr)
      elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        sub_ents = e.is_a?(Sketchup::Group) ? e.entities.to_a : e.definition.entities.to_a
        collect_subgroup_highlight_recursive(sub_ents, tr * e.transformation, faces, edges)
      end
    end
  end

  def mirror_through_plane(point, normal)
    n = normal.clone
    n.normalize!
    axes = n.axes
    t = Geom::Transformation.axes(point, axes[0], axes[1], n)
    t * Geom::Transformation.scaling(1, 1, -1) * t.inverse
  end

  def thuc_hien_xoa(view)
    if @shift_auto
      return unless @xoa_parent && @xoa_parent.valid?
      groups = tim_nhom_xoa(@xoa_parent)
      return if groups.empty?
      ZSU.start(false)
      groups.each { |entry| entry[:grp].erase! if entry[:grp].valid? }
      ZSU.commit
      @xoa_parent = nil
    else
      return unless @xoa_id_groups && !@xoa_id_groups.empty?
      ZSU.start(false)
      @xoa_id_groups.each { |g| g.erase! if g.valid? }
      ZSU.commit
      @xoa_current_id = nil
      @xoa_id_groups = nil
    end
    @xoa_faces = []
    @xoa_edges = []
    view.invalidate
  end

  def thuc_hien(view)
    return unless @datas && !@datas.empty?
    if @hover_component
      hover_data = @hover_component[:data]
      @hover_idx = @hover_component[:index]
      data_idx = @datas.index { |d| d.equal?(hover_data) }
      if data_idx
        @datas = [hover_data]
        @target_faces = [@target_faces[data_idx]]
      end
    else
      @hover_idx = nil
    end

    ZSU.start(false)
    chot_chinh_layer = @tao_chot_chinh && !@defn_chot_chinh ? ZSU.ensure_tag(@layer_chot_chinh) : nil
    oc_khoa_layer = @tao_oc_khoa && !@defn_khoa ? ZSU.ensure_tag(@layer_oc_khoa) : nil
    pilot_layer = @tao_chot_phu && !@defn_chot_phu ? ZSU.ensure_tag(@layer_chot_phu) : nil
    khoan_ngang_layer = @tao_chot_chinh && @mo_phong_khoan_ngang ? ZSU.ensure_tag(@layer_khoan_ngang) : nil
    mo_phong_cp_layer = @tao_chot_phu && @mo_phong_cp ? ZSU.ensure_tag(@layer_mo_phong_cp) : nil
    batch_id = (Time.now.to_f * 1000).to_i.to_s(36)
    set_counter = 0
    base_groups = []
    @target_faces.zip(@datas).each do |target, data|
      next unless target && data
      fs = data[:face_side] || 1
      z  = data[:len]
      base_tenon        = (@tao_oc_khoa == true) ? draw_tenon(z, fs) : nil
      base_mortise      = (@tao_chot_chinh == true) ? draw_mortise(z, fs) : nil
      base_pilot        = (@tao_chot_phu == true) ? draw_pilot(@duong_kinh_chot_phu, z, fs) : nil
      base_khoan_rect   = (@tao_chot_chinh && @mo_phong_khoan_ngang) ? draw_rect_marker(@chieu_sau_mo_phong, z, fs) : nil
      base_khoan_circle = (@tao_chot_chinh && @mo_phong_khoan_ngang) ? draw_circle_marker(!@can_giua_chot_chinh ? fs * (z / 2.0 - @chot_chinh_cach_mat) : 0) : nil
      base_mp_cp_rect   = (@tao_chot_phu && @mo_phong_cp) ? draw_rect_marker(@chieu_sau_mo_phong_cp, z, fs) : nil
      base_mp_cp_circle = (@tao_chot_phu && @mo_phong_cp) ? draw_circle_marker(!@can_giua_chot_phu ? fs * (z / 2.0 - @chot_phu_cach_mat) : 0) : nil
      base_groups << {
        tenon: base_tenon, mortise: base_mortise, pilot: base_pilot,
        khoan_rect: base_khoan_rect, khoan_circle: base_khoan_circle,
        mp_cp_rect: base_mp_cp_rect, mp_cp_circle: base_mp_cp_circle
      }
    end
    @target_faces.zip(@datas).each_with_index do |(target, data), idx|
      next unless target && data
      bases = base_groups[idx]
      next unless bases
      @target_face = target[:face]
      @target_parent = target[:parent]
      @mortise_parent = data[:mortise_parent]
      @base_tenon = bases[:tenon]
      @base_mortise = bases[:mortise]
      @base_pilot = bases[:pilot]
      @base_khoan_rect = bases[:khoan_rect]
      @base_khoan_circle = bases[:khoan_circle]
      @base_mp_cp_rect = bases[:mp_cp_rect]
      @base_mp_cp_circle = bases[:mp_cp_circle]
      so_luong_lien_ket = data[:so_luong_lien_ket]
      face_side = data[:face_side] || 1
      @face_side = face_side
      @cur_len = data[:len]
      @is_opposite = target[:opposite]
      (0...so_luong_lien_ket).each do |i|
        next if @hover_idx && i != @hover_idx
        @current_set_id = "#{batch_id}#{set_counter.to_s(36)}"
        set_counter += 1
        t = so_luong_lien_ket == 1 ? 0.5 : i.to_f / data[:divisor]
        base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        xaxis = data[:transformed_normal]
        zaxis = data[:unit_v1]
        yaxis = zaxis * xaxis
        tr = Geom::Transformation.axes(base_point, xaxis, yaxis, zaxis)
        m_ents = ZSU.get_ents(@mortise_parent)
        if @tao_chot_chinh
          if @defn_chot_chinh
            center_z = @can_giua_chot_chinh ? 0 : face_side * (data[:len] / 2.0 - @chot_chinh_cach_mat)
            center_tr = Geom::Transformation.new(Geom::Point3d.new(0, 0, center_z))
            src_tr = @is_opposite ? @src_tr_cc_opp : @src_tr_cc
            inst = place_defn_in_parent(@defn_chot_chinh, center_tr, tr, @mortise_parent,
                                         rot_axes: [Z_AXIS.reverse, Y_AXIS, X_AXIS],
                                         src_layer: @src_layer_cc, src_name: @src_name_cc,
                                         src_tr: src_tr)
            if inst
              inst.set_attribute("ZSU", "lien_ket", true)
              inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
              if !@tao_oc_khoa && @thong_ke_lien_ket
                ZSU::ABF.set_minifix(inst, @ten_hien_thi, part: "a")
              end
            end
          elsif @base_mortise
            inst = place_clone_in_parent(@base_mortise, tr, @mortise_parent, chot_chinh_layer, @instance_chot_chinh)
            if inst
              inst.set_attribute("ZSU", "lien_ket", true)
              inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
              if !@tao_oc_khoa && @thong_ke_lien_ket
                ZSU::ABF.set_minifix(inst, @ten_hien_thi, part: "a")
              end
            end
          end
        end
        if @tao_chot_phu
          create_pilots(tr, data, i, so_luong_lien_ket, m_ents, pilot_layer)
        end
        if @tao_oc_khoa
          if @defn_khoa
            center = Geom::Point3d.new(-@cach_mep_oc_khoa, 0, face_side * data[:len] / 2.0)
            center_tr = Geom::Transformation.new(center)
            src_tr = @is_opposite ? @src_tr_k_opp : @src_tr_k
            inst = place_defn_in_parent(@defn_khoa, center_tr, tr, @target_parent,
                                         src_layer: @src_layer_k, src_name: @src_name_k,
                                         src_tr: src_tr)
            if inst
              inst.set_attribute("ZSU", "lien_ket", true)
              inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
            end
          elsif @base_tenon
            tenon_clone = @base_tenon.copy
            tenon_clone.transform!(tr)
            t_ents = ZSU.get_ents(@target_parent)
            if t_ents && ZSU.is_container?(@target_parent)
              t_parent_tr = @target_parent.transformation.inverse * tenon_clone.transformation
              new_inst = t_ents.add_instance(tenon_clone.definition, t_parent_tr)
              apply_instance_attrs(new_inst, nil, oc_khoa_layer, @instance_oc_khoa, minifix: true)
              new_inst.set_attribute("ZSU", "lien_ket", true)
              new_inst.set_attribute("ZSU", "lien_ket_id", @current_set_id)
            end
            tenon_clone.erase!
          end
        end
        rect_specs = []
        circle_specs = []
        if @tao_chot_chinh && @mo_phong_khoan_ngang
          ZSU::ABF.ensure_is_board(@target_parent)
          rect_specs << [@base_khoan_rect, tr, khoan_ngang_layer] if @base_khoan_rect
          if @base_khoan_circle
            circle_specs << [@base_khoan_circle, tr, khoan_ngang_layer, @chieu_sau_mo_phong.to_mm.to_f]
          end
        end
        if @tao_chot_phu && @mo_phong_cp
          ZSU::ABF.ensure_is_board(@target_parent)
          pilot_vectors(data, i, so_luong_lien_ket).each do |pv|
            pilot_tr = pv ? Geom::Transformation.translation(pv) * tr : tr
            rect_specs << [@base_mp_cp_rect, pilot_tr, mo_phong_cp_layer] if @base_mp_cp_rect
            if @base_mp_cp_circle
              circle_specs << [@base_mp_cp_circle, pilot_tr, mo_phong_cp_layer, @chieu_sau_mo_phong_cp.to_mm.to_f]
            end
          end
        end
        both_mo_phong = @tao_chot_chinh && @mo_phong_khoan_ngang && @tao_chot_phu && @mo_phong_cp
        if both_mo_phong
          place_marker_group(rect_specs, :rect)
          place_marker_group(circle_specs, :circle)
        else
          rect_specs.each do |base, t, layer|
            inst = place_marker_clone(base, t, @target_parent, layer, @instance_khoan_ngang)
            ZSU::ABF.set_side_drill_depth(inst) if inst
          end
          circle_specs.each do |base, t, layer, depth|
            inst = place_marker_clone(base, t, @target_parent, layer, @instance_khoan_ngang)
            ZSU::ABF.set_side_drill(inst, depth) if inst
          end
        end
      end
    end
    base_groups.each do |bases|
      bases[:tenon].erase! if bases[:tenon]&.valid?
      bases[:mortise].erase! if bases[:mortise]&.valid?
      bases[:pilot].erase! if bases[:pilot]&.valid?
      bases[:khoan_rect].erase! if bases[:khoan_rect]&.valid?
      bases[:khoan_circle].erase! if bases[:khoan_circle]&.valid?
      bases[:mp_cp_rect].erase! if bases[:mp_cp_rect]&.valid?
      bases[:mp_cp_circle].erase! if bases[:mp_cp_circle]&.valid?
    end
    ZSU.commit
    reset_state
    view.invalidate
  end
end