
class ZSU::Monggo
  include ZSU::Preset
  settings_section "mong_go"

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
      unless len1_str.empty?
        len1 = len1_str.to_l.to_mm.to_f
        return if len1 < 0
        @cach_truoc = len1.mm
        write("cach_truoc", len1)
      end
      unless len2_str.empty? || @cach_deu_hai_dau
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
        @so_luong_mong = num
        write("so_luong_mong", num)
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
      ZSU::Settings.open_settings('mong_go')
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
        picked = @shift_auto ? (fb.to_a - [f]).first || f : f
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
        lk_group = find_mong_go_group(edge, parent)
        if lk_group
          lk_id = lk_group.get_attribute("ZSU", "mong_go_id")
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
      if @tao_mong_duong || @tao_lo_mong || @tao_ha_nen || @tao_chot_go
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
        pf = @alt_mode && fb.size >= 2 ? (fb.to_a - [f]).first || f : f
        @target_faces = [{ face: @target_face, parent: @target_parent,
                           picked_face: pf, original_face: f }]
        @target_org = @target_faces.dup
        if @ctrl_mode
          opposite = band_faces.find { |face| face.normal.reverse == target.normal }
          if opposite
            @target_faces << { face: opposite, parent: @target_parent,
                               picked_face: @target_faces.first&.dig(:picked_face),
                               original_face: @target_faces.first&.dig(:original_face),
                               opposite: true }
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
    @thong_ke_mong_go = read("thong_ke_mong_go", true)
    @ten_hien_thi = read("ten_hien_thi", "Mộng gỗ")
    @so_luong_co_dinh = read("so_luong_co_dinh", true)
    @so_luong_mong = read("so_luong_mong", 2).to_i
    @khoang_cach = read("khoang_cach", 200.0).to_f.mm
    @he_so_dinh_vi = read("he_so_dinh_vi", ZSU::View.grid_scale, true).to_f
    @cach_deu_hai_dau = read("cach_deu_hai_dau", true)
    @bo_dem_dinh_vi = read("bo_dem_dinh_vi", ZSU::View.cache_step(16), true).to_i
    @cach_truoc = read("cach_truoc", 32.0).to_f.mm
    @cach_sau = read("cach_sau", 32.0).to_f.mm
    @van_day_toi_thieu = read("van_day_toi_thieu", 15.0).to_f.mm
    @canh_dai_toi_thieu = read("canh_dai_toi_thieu", 50.0).to_f.mm
    @tao_mong_duong = read("tao_mong_duong", true)
    @chieu_sau_mong_duong = read("chieu_sau_mong_duong", 12.0).to_f.mm
    @do_ho_mong_duong = read("do_ho_mong_duong", 0.0).to_f.mm
    @bo_goc_mong_duong = read("bo_goc_mong_duong", true)
    @ban_kinh_bo_mong_duong = read("ban_kinh_bo_mong_duong", 3.0).to_f.mm
    @instance_mong_duong = read("instance_mong_duong", "ABF_MD")
    @layer_mong_duong = read("layer_mong_duong", "ABF_MD")
    @tao_lo_mong = read("tao_lo_mong", true)
    @chieu_sau_lo_mong = read("chieu_sau_lo_mong", 12.5).to_f.mm
    @do_ho_lo_mong = read("do_ho_lo_mong", 0.2).to_f.mm
    @bo_goc_lo_mong = read("bo_goc_lo_mong", true)
    @ban_kinh_bo_lo_mong = read("ban_kinh_bo_lo_mong", 3.0).to_f.mm
    @instance_lo_mong = read("instance_lo_mong", "ABF_LM")
    @layer_lo_mong = read("layer_lo_mong", "ABF_LM")
    @tao_ha_nen = read("tao_ha_nen", false)
    @chieu_sau_ha_nen = read("chieu_sau_ha_nen", 3.0).to_f.mm
    @do_ho_ha_nen = read("do_ho_ha_nen", 0.0).to_f.mm
    @instance_ha_nen = read("instance_ha_nen", "ABF_HN")
    @layer_ha_nen = read("layer_ha_nen", "ABF_HN")
    @tao_chot_go = read("tao_chot_go", false)
    @chot_go_cach_tam = read("chot_go_cach_tam", 32.0).to_f.mm
    @duong_kinh_chot_go = read("duong_kinh_chot_go", 8.0).to_f.mm
    @ty_le_mong = read("ty_le_mong", ZSU::View.dpi_scale, true).to_f
    @view_dpi = read("view_dpi", ZSU::View.dpi_offset, true).to_f.mm
    @chieu_sau_chot_go = read("chieu_sau_chot_go", 30.0).to_f.mm
    @huong_chot_go = read("huong_chot_go", "hai_ben")
    @instance_chot_go = read("instance_chot_go", "ABF_CG")
    @layer_chot_go = read("layer_chot_go", "ABF_CG")
    @bu_sai_vi_tri = read("bu_sai_vi_tri", (@he_so_dinh_vi - 1.0) * 11, true).to_f.mm
    @sai_so_vi_tri = read("sai_so_vi_tri", @bo_dem_dinh_vi - 8, true).to_f.mm
    @hien_thi_khoang_cach = read("hien_thi_khoang_cach", false)
    @shift_auto = false
    @che_do = read("che_do", 0).to_i
    @xoa_parent = nil
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_mode_buttons(
      ["Tạo mộng", "Đảo mặt", "Xóa mộng"],
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
        thong_ke_mong_go: [:switch, "Thống kê mộng"],
      },
      "Số lượng" => {
        so_luong_co_dinh: [:switch, "Số lượng cố định"],
        so_luong_mong: [:raw, "Số lượng mộng", -> { @so_luong_co_dinh }, 1],
        khoang_cach: [:mm, "Khoảng cách", -> { !@so_luong_co_dinh }, 0],
      },
      "Vị trí" => {
        cach_deu_hai_dau: [:switch, "Cách đều hai đầu"],
        cach_truoc: [:mm, -> { @cach_deu_hai_dau ? "Cách hai đầu" : "Cách trước" },
                     -> { !(@so_luong_co_dinh && @so_luong_mong == 1 && @cach_deu_hai_dau) }],
        cach_sau: [:mm, "Cách sau",
                   -> { !@cach_deu_hai_dau && !(@so_luong_co_dinh && @so_luong_mong == 1) }],
      },
      "Điều kiện" => {
        van_day_toi_thieu: [:mm, "Ván dày tối thiểu", nil, 0],
        canh_dai_toi_thieu: [:mm, "Cạnh dài tối thiểu", nil, 0],
      },
      "Mộng dương" => {
        tao_mong_duong: [:switch, "Tạo mộng dương"],
        chieu_sau_mong_duong: [:mm, "Chiều sâu", -> { @tao_mong_duong }, 0],
        do_ho_mong_duong: [:mm, "Độ hở biên", -> { @tao_mong_duong }],
        bo_goc_mong_duong: [:switch, "Bo góc", -> { @tao_mong_duong }],
        ban_kinh_bo_mong_duong: [:mm, "Bán kính bo", -> { @tao_mong_duong && @bo_goc_mong_duong }, 0],
        instance_mong_duong: [:raw, "Instance", -> { @tao_mong_duong }],
        layer_mong_duong: [:raw, "Layer", -> { @tao_mong_duong }],
      },
      "Lỗ mộng âm" => {
        tao_lo_mong: [:switch, "Tạo lỗ mộng âm"],
        chieu_sau_lo_mong: [:mm, "Chiều sâu", -> { @tao_lo_mong }, 0],
        do_ho_lo_mong: [:mm, "Độ hở biên", -> { @tao_lo_mong }],
        bo_goc_lo_mong: [:switch, "Bo góc", -> { @tao_lo_mong }],
        ban_kinh_bo_lo_mong: [:mm, "Bán kính bo", -> { @tao_lo_mong && @bo_goc_lo_mong }, 0],
        instance_lo_mong: [:raw, "Instance", -> { @tao_lo_mong }],
        layer_lo_mong: [:raw, "Layer", -> { @tao_lo_mong }],
      },
      "Hạ nền" => {
        tao_ha_nen: [:switch, "Tạo vai hạ nền"],
        chieu_sau_ha_nen: [:mm, "Chiều sâu", -> { @tao_ha_nen }, 0],
        do_ho_ha_nen: [:mm, "Độ hở biên", -> { @tao_ha_nen }],
        instance_ha_nen: [:raw, "Instance", -> { @tao_ha_nen }],
        layer_ha_nen: [:raw, "Layer", -> { @tao_ha_nen }],
      },
      "Chốt gỗ" => {
        tao_chot_go: [:switch, "Tạo chốt định vị"],
        chot_go_cach_tam: [:mm, "Cách tâm mộng", -> { @tao_chot_go && @huong_chot_go != "chinh_giua" }, 0],
        duong_kinh_chot_go: [:mm, "Đường kính chốt", -> { @tao_chot_go }, 0],
        chieu_sau_chot_go: [:mm, "Chiều sâu khoan", -> { @tao_chot_go }, 0],
        huong_chot_go: [:select, "Hướng đặt chốt",
                        { "ngoai" => "Ngoài", "trong" => "Trong",
                          "chinh_giua" => "Giữa mộng", "hai_ben" => "Hai bên" },
                        -> { @tao_chot_go }],
        instance_chot_go: [:raw, "Instance", -> { @tao_chot_go }],
        layer_chot_go: [:raw, "Layer", -> { @tao_chot_go }],
      },
      "Hiển thị" => {
        hien_thi_khoang_cach: [:switch, "Hiển thị khoảng cách"],
      }
    )
  end

  def update_preview
  end

  private

  def load_preset(s)
    init_preset(:thong_ke_mong_go, s)
    init_preset(:ten_hien_thi, s)
    init_preset(:so_luong_co_dinh, s)
    init_preset(:so_luong_mong, s) { |v| v.to_i }
    init_preset(:khoang_cach, s) { |v| v.to_f.mm }
    init_preset(:cach_deu_hai_dau, s)
    init_preset(:cach_truoc, s) { |v| v.to_f.mm }
    init_preset(:cach_sau, s) { |v| v.to_f.mm }
    init_preset(:van_day_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:canh_dai_toi_thieu, s) { |v| v.to_f.mm }
    init_preset(:tao_mong_duong, s)
    init_preset(:chieu_sau_mong_duong, s) { |v| v.to_f.mm }
    init_preset(:do_ho_mong_duong, s) { |v| v.to_f.mm }
    init_preset(:bo_goc_mong_duong, s)
    init_preset(:ban_kinh_bo_mong_duong, s) { |v| v.to_f.mm }
    init_preset(:instance_mong_duong, s)
    init_preset(:layer_mong_duong, s)
    init_preset(:tao_lo_mong, s)
    init_preset(:chieu_sau_lo_mong, s) { |v| v.to_f.mm }
    init_preset(:do_ho_lo_mong, s) { |v| v.to_f.mm }
    init_preset(:bo_goc_lo_mong, s)
    init_preset(:ban_kinh_bo_lo_mong, s) { |v| v.to_f.mm }
    init_preset(:instance_lo_mong, s)
    init_preset(:layer_lo_mong, s)
    init_preset(:tao_ha_nen, s)
    init_preset(:chieu_sau_ha_nen, s) { |v| v.to_f.mm }
    init_preset(:do_ho_ha_nen, s) { |v| v.to_f.mm }
    init_preset(:instance_ha_nen, s)
    init_preset(:layer_ha_nen, s)
    init_preset(:tao_chot_go, s)
    init_preset(:chot_go_cach_tam, s) { |v| v.to_f.mm }
    init_preset(:duong_kinh_chot_go, s) { |v| v.to_f.mm }
    init_preset(:chieu_sau_chot_go, s) { |v| v.to_f.mm }
    init_preset(:huong_chot_go, s)
    init_preset(:instance_chot_go, s)
    init_preset(:layer_chot_go, s)
    init_preset(:hien_thi_khoang_cach, s)
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
      "Số mộng [/x]: #{@so_luong_mong}" :
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
        "Giữ Shift để xóa toàn bộ mộng trên ván."
      )
    else
      ZSU.status(
        "Nhấn Tab để chuyển chế độ. " \
        "Giữ Ctrl để đánh mộng đối xứng. " \
        "Giữ Shift để đánh mộng ở tất cả các cạnh. " \
        "Giữ Alt để đảo mặt đánh mộng."
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
    if @tao_mong_duong || @tao_lo_mong || @tao_ha_nen || @tao_chot_go
      faces.select! do |data|
        mortises = find_mortise_parent(data[:face], data[:parent])
        !mortises.empty? && mortises.any? { |m| @selected_entities.include?(m) }
      end
    end
    faces
  end

  def calc_so_luong_mong(distance)
    if !@so_luong_co_dinh
      return 1 if @khoang_cach.nil? || @khoang_cach <= 0
      return 1 if distance <= @khoang_cach
      n = (distance / @khoang_cach).round + 1
      [n, 1].max
    else
      @so_luong_mong
    end
  end

  def tinh_hinh_hoc_mot
    return unless @target_face && @target_parent
    tr = @target_parent.transformation
    if @van_day_toi_thieu > 0
      t_thickness = ZSU::Board.calc_thickness(@target_parent)
      return unless (t_thickness - @van_day_toi_thieu).abs < 0.01.mm || t_thickness >= @van_day_toi_thieu
    end
    need_mortise = @tao_mong_duong || @tao_lo_mong || @tao_ha_nen || @tao_chot_go
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
      mot_mong_rieng = @so_luong_co_dinh && @so_luong_mong == 1 && !@cach_deu_hai_dau
      cach_sau = 0 if mot_mong_rieng

      offset_start = cach_truoc
      offset_end = total_dist - cach_sau

      if offset_end > offset_start
        start_point = mid_a.offset(unit_normal, offset_start)
        end_point = mid_a.offset(unit_normal, offset_end)
        distance = start_point.distance(end_point)
        so_luong_mong = calc_so_luong_mong(distance)
        so_luong_mong = [so_luong_mong, 1].max
      else
        so_luong_mong = 1
      end
      if so_luong_mong == 1
        if mot_mong_rieng
          center_offset = near_start ? @cach_truoc : total_dist - @cach_truoc
          start_point = mid_a.offset(unit_normal, center_offset)
          end_point = start_point
        else
          start_point = mid_a
          end_point = mid_a.offset(unit_normal, total_dist)
        end
      end
      divisor = so_luong_mong > 1 ? so_luong_mong - 1 : 1
      results << {
        start_point: start_point,
        end_point: end_point,
        unit_v1: unit_v1,
        transformed_normal: transformed_normal,
        len: len,
        divisor: divisor,
        transform: tr,
        so_luong_mong: so_luong_mong,
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

  def find_hover_component(datas)
    return nil unless @mouse_x && @mouse_y
    datas.each do |data|
      next unless data
      so_luong_mong = data[:so_luong_mong]
      xaxis = data[:transformed_normal]
      zaxis = data[:unit_v1]
      yaxis = zaxis * xaxis
      face_side = data[:face_side] || 1
      half_len = data[:len] / 2.0

      (0...so_luong_mong).each do |i|
        t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
        bp = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
        w = data[:len] - 2 * @do_ho_mong_duong
        w = 10.mm if w < 10.mm
        h = 35.mm
        pts = stadium_points_raw(bp, zaxis, yaxis, face_side, half_len, w, h)
        hit = ZSU::View.point_in_polygon_2d?(@mouse_x, @mouse_y, pts, xaxis)
        return { data: data, index: i } if hit
      end
    end
    nil
  end

  def draw_joint_preview(data)
    so_luong_mong = data[:so_luong_mong]
    xaxis = data[:transformed_normal]
    zaxis = data[:unit_v1]
    yaxis = zaxis * xaxis
    face_side = data[:face_side] || 1
    half_len = data[:len] / 2.0
    (0...so_luong_mong).each do |i|
      t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
      base_point = Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
      hovered = @hover_component && @hover_component[:data].equal?(data) && @hover_component[:index] == i
      if hovered
        old_w = ZSU::View.edge_weight
        ZSU::View.set_edge_weight(old_w + 1)
      end
      if @tao_mong_duong || @tao_lo_mong
        w = data[:len] - 2 * @do_ho_mong_duong
        w = 10.mm if w < 10.mm
        h = @tao_lo_mong ? 35.mm : 30.mm
        pts = stadium_points_raw(base_point, zaxis, yaxis, face_side, half_len, w, h)
        pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
        ZSU::View.draw2d_polygon(pts)
      end
      if @tao_ha_nen
        w = data[:len] - 2 * @do_ho_ha_nen
        w = 10.mm if w < 10.mm
        h = 50.mm
        pts = stadium_points_raw(base_point, zaxis, yaxis, face_side, half_len, w, h)
        pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
        ZSU::View.draw2d_polygon(pts, guide: true)
      end
      if @tao_chot_go
        draw_pilot_preview(data, base_point, i, so_luong_mong, xaxis, yaxis, zaxis)
      end
      ZSU::View.set_edge_weight(old_w) if hovered
    end
  end

  def draw_pilot_preview(data, base_point, i, so_luong_mong, xaxis, yaxis, zaxis)
    pilot_offset = @chot_go_cach_tam
    base_vec = (data[:start_point] - data[:end_point])
    return if base_vec.length == 0
    base_vec_norm = base_vec.normalize
    face_side = data[:face_side] || 1
    half_len = data[:len] / 2.0
    pilot_base = base_point.offset(zaxis, face_side * half_len)

    centers = case @huong_chot_go
              when "hai_ben"
                [-1, 1].map { |side| pilot_base.offset(base_vec_norm, side * pilot_offset) }
              when "chinh_giua"
                [pilot_base]
              else
                pilot_vec = base_vec.normalize
                pilot_vec = pilot_vec.reverse if @huong_chot_go == "trong"
                pilot_vec = pilot_vec.reverse if (i + 1) > (so_luong_mong.to_f / 2)
                pilot_vec.length = pilot_offset
                [pilot_base.transform(Geom::Transformation.translation(pilot_vec))]
              end
    centers.each do |center|
      r = @duong_kinh_chot_go / 2.0
      pts = (0...16).map do |j|
        angle = 2 * Math::PI * j / 16
        center.offset(yaxis, Math.cos(angle) * r).offset(zaxis, Math.sin(angle) * r)
      end
      pts = pts.map { |p| p.offset([0, 0, @view_dpi]) } if @view_dpi != 0
      ZSU::View.draw2d_polygon(pts)
    end
  end

  def draw_joint_texts(data)
    so_luong_mong = data[:so_luong_mong]
    return if so_luong_mong < 1
    precision = ZSU::Model.get_unit_precision
    edge_start = data[:edge_start]
    edge_end = data[:edge_end]
    dir = edge_start.vector_to(edge_end)
    return unless dir.valid?

    centers = (0...so_luong_mong).map do |i|
      t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
      Geom.linear_combination(1 - t, data[:start_point], t, data[:end_point])
    end

    points = [edge_start] + centers + [edge_end]
    loop_limit_text = 0
    (0...points.size - 1).each do |i|
      loop_limit_text += 1
      break if loop_limit_text > 500
      gap = points[i].distance(points[i + 1])
      if gap > 0.1.mm
        mid = Geom::linear_combination(0.5, points[i], 0.5, points[i + 1])
        ZSU::View.draw2d_text(format("%.#{precision}f", gap.to_mm), mid)
      end
    end
  end

  def stadium_points_raw(center, zaxis, yaxis, face_side, half_len, w, h)
    p_center = center.offset(zaxis, face_side * half_len)
    p1 = p_center.offset(zaxis, -face_side * h)
    v_width = zaxis.cross(yaxis).normalize
    pt1 = p1.offset(v_width, w / 2.0)
    pt2 = p1.offset(v_width, -w / 2.0)
    pt3 = p_center.offset(v_width, -w / 2.0)
    pt4 = p_center.offset(v_width, w / 2.0)
    [pt1, pt2, pt3, pt4]
  end

  def create_stadium_group(w, h, depth, radius, bo_goc)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    w_half = w / 2.0
    pts = [
      Geom::Point3d.new(-w_half, 0, 0),
      Geom::Point3d.new(-w_half, -h, 0),
      Geom::Point3d.new(w_half, -h, 0),
      Geom::Point3d.new(w_half, 0, 0)
    ]
    if bo_goc && radius > 0 && radius < w_half && radius < h
      p1 = pts[1].offset(X_AXIS, radius).offset(Y_AXIS, radius)
      p2 = pts[2].offset(X_AXIS, -radius).offset(Y_AXIS, radius)
      arc1_pts = (0..8).map do |i|
        a = Math::PI + i * (Math::PI / 2.0) / 8
        p1.offset(X_AXIS, radius * Math.cos(a)).offset(Y_AXIS, radius * Math.sin(a))
      end
      arc2_pts = (0..8).map do |i|
        a = Math::PI * 1.5 + i * (Math::PI / 2.0) / 8
        p2.offset(X_AXIS, radius * Math.cos(a)).offset(Y_AXIS, radius * Math.sin(a))
      end
      final_pts = [pts[0]] + arc1_pts + arc2_pts + [pts[3]]
    else
      final_pts = pts
    end
    face = grp.entities.add_face(final_pts)
    face.pushpull(-depth * @ty_le_mong + @sai_so_vi_tri + @bu_sai_vi_tri) if face
    center_origin_raw(grp)
    grp
  end

  def create_pilot_group(d, h)
    entities = ZSU::Model.active_entities
    grp = entities.add_group
    grp.entities.add_circle(ORIGIN, Z_AXIS, d / 2 * @ty_le_mong + @sai_so_vi_tri + @bu_sai_vi_tri, 16)
    face = grp.entities.grep(Sketchup::Face).first
    face.pushpull(-h * @ty_le_mong) if face
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

  def apply_instance_attrs(new_inst, layer, instance_name)
    new_inst.layer = layer
    new_inst.name = instance_name
    new_inst.entities.to_a.each { |e| e.layer = layer }
  end

  def place_clone_in_parent(base_grp, tr, parent, layer, instance_name)
    clone = base_grp.copy
    clone.transform!(tr)
    p_ents = ZSU.get_ents(parent)
    parent_tr = parent.transformation.inverse * clone.transformation
    new_inst = p_ents.add_instance(clone.definition, parent_tr)
    apply_instance_attrs(new_inst, layer, instance_name)
    clone.erase!
    new_inst
  end

  def pilot_vectors(data, i, so_luong_mong)
    offset = @chot_go_cach_tam
    base_vec = (data[:start_point] - data[:end_point])
    return [nil] if base_vec.length == 0
    case @huong_chot_go
    when "hai_ben"
      v = base_vec.clone
      v.length = offset
      [v, v.reverse]
    when "chinh_giua"
      [nil]
    else
      v = base_vec.clone
      v = v.reverse if @huong_chot_go == "trong"
      v = v.reverse if (i + 1) > (so_luong_mong.to_f / 2)
      v.length = offset
      [v]
    end
  end

  def create_pilots(tr, data, i, so_luong_mong, m_ents, pilot_layer)
    pilot_vectors(data, i, so_luong_mong).each do |pv|
      pilot_tr = pv ? Geom::Transformation.translation(pv) * tr : tr
      pilot_clone = @base_pilot.copy
      pilot_clone.transform!(pilot_tr)
      p_parent_tr = @mortise_parent.transformation.inverse * pilot_clone.transformation
      new_inst = m_ents.add_instance(pilot_clone.definition, p_parent_tr)
      apply_instance_attrs(new_inst, pilot_layer, @instance_chot_go)
      new_inst.set_attribute("ZSU", "mong_go", true)
      new_inst.set_attribute("ZSU", "mong_go_id", @current_set_id)
      pilot_clone.erase!
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
      next if g.name == @instance_mong_duong
      next if g.name == @instance_lo_mong
      next if g.name == @instance_ha_nen
      next if g.name == @instance_chot_go
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
        next unless e.get_attribute("ZSU", "mong_go")
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
            next unless e.get_attribute("ZSU", "mong_go")
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

  def find_mong_go_group(edge, parent)
    return nil unless edge
    sub_ents = ZSU.get_ents(parent).to_a
    return nil unless sub_ents
    sub_ents.each do |e|
      next unless ZSU.is_container?(e) && e.valid?
      next unless e.get_attribute("ZSU", "mong_go")
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
        next unless e.get_attribute("ZSU", "mong_go_id") == lk_id
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
      next unless grp.get_attribute("ZSU", "mong_go")
      lk_id = grp.get_attribute("ZSU", "mong_go_id")
      moved_ids << lk_id if lk_id
    end
    mirror_mong_go_partners(moved_ids.uniq, groups)
    ZSU.commit
    view.invalidate
  end

  def mirror_mong_go_partners(partner_ids, own_groups)
    cnc_faces = ZSU::Board.get_cnc_faces(@shift_parent)
    return unless cnc_faces && cnc_faces.size == 2
    shift_tr = @shift_parent.transformation
    mid_world = Geom::Point3d.linear_combination(0.5, cnc_faces[0].bounds.center, 0.5, cnc_faces[1].bounds.center).transform(shift_tr)
    normal_world = cnc_faces[0].normal.transform(shift_tr)
    t_world = mirror_through_plane(mid_world, normal_world)

    partner_ids.each do |lk_id|
      find_mong_go_with_parent(lk_id).each do |partner, parent_inst|
        next if own_groups.include?(partner)
        next unless partner.valid? && parent_inst.valid?
        inv = parent_inst.transformation.inverse
        partner.transform!(inv * t_world * parent_inst.transformation)
      end
    end
  end

  def find_mong_go_with_parent(lk_id)
    result = []
    ZSU::Model.active_entities.to_a.each do |container|
      next unless ZSU.is_container?(container) && container.valid?
      c_ents = container.is_a?(Sketchup::Group) ? container.entities.to_a : container.definition.entities.to_a
      c_ents.each do |e|
        next unless ZSU.is_container?(e) && e.valid?
        next unless e.get_attribute("ZSU", "mong_go_id") == lk_id
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

    lk_id = @dao_mat_subgroup.get_attribute("ZSU", "mong_go_id")
    ZSU.start(false)
    @dao_mat_subgroup.transform!(parent_tr.inverse * t_world * parent_tr)
    if lk_id
      find_mong_go_with_parent(lk_id).each do |partner, partner_parent|
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
    mong_duong_layer = @tao_mong_duong ? ZSU.ensure_tag(@layer_mong_duong) : nil
    lo_mong_layer = @tao_lo_mong ? ZSU.ensure_tag(@layer_lo_mong) : nil
    ha_nen_layer = @tao_ha_nen ? ZSU.ensure_tag(@layer_ha_nen) : nil
    pilot_layer = @tao_chot_go ? ZSU.ensure_tag(@layer_chot_go) : nil
    batch_id = (Time.now.to_f * 1000).to_i.to_s(36)
    set_counter = 0
    base_groups = []

    @target_faces.zip(@datas).to_a.each do |target, data|
      next unless target && data
      w_tenon = data[:len] - 2 * @do_ho_mong_duong
      w_tenon = 10.mm if w_tenon < 10.mm
      w_mortise = data[:len] - 2 * @do_ho_lo_mong
      w_mortise = 10.mm if w_mortise < 10.mm
      w_dap = data[:len] - 2 * @do_ho_ha_nen
      w_dap = 10.mm if w_dap < 10.mm

      base_tenon = @tao_mong_duong ? create_stadium_group(w_tenon, 30.mm, @chieu_sau_mong_duong, @ban_kinh_bo_mong_duong, @bo_goc_mong_duong) : nil
      base_mortise = @tao_lo_mong ? create_stadium_group(w_mortise, 35.mm, @chieu_sau_lo_mong, @ban_kinh_bo_lo_mong, @bo_goc_lo_mong) : nil
      base_ha_nen = @tao_ha_nen ? create_stadium_group(w_dap, 50.mm, @chieu_sau_ha_nen, 0, false) : nil
      base_pilot = @tao_chot_go ? create_pilot_group(@duong_kinh_chot_go, @chieu_sau_chot_go) : nil

      base_groups << { tenon: base_tenon, mortise: base_mortise, ha_nen: base_ha_nen, pilot: base_pilot }
    end

    tenons = []
    @target_faces.zip(@datas).to_a.each_with_index do |(target, data), idx|
      next unless target && data
      bases = base_groups[idx]
      next unless bases
      @target_face = target[:face]
      @target_parent = target[:parent]
      @mortise_parent = data[:mortise_parent]
      @base_tenon = bases[:tenon]
      @base_mortise = bases[:mortise]
      @base_ha_nen = bases[:ha_nen]
      @base_pilot = bases[:pilot]
      so_luong_mong = data[:so_luong_mong]
      face_side = data[:face_side] || 1

      (0...so_luong_mong).each do |i|
        next if @hover_idx && i != @hover_idx
        @current_set_id = "#{batch_id}#{set_counter.to_s(36)}"
        set_counter += 1
        t = so_luong_mong == 1 ? 0.5 : i.to_f / data[:divisor]
        base_point = Geom::linear_combination(1 - t, data[:start_point], t, data[:end_point])
        xaxis = data[:transformed_normal]
        zaxis = data[:unit_v1]
        yaxis = zaxis * xaxis
        tr = Geom::Transformation.axes(base_point, xaxis, yaxis, zaxis)
        rot_tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, (face_side * 90).degrees)
        applied_tr = tr * rot_tr
        m_ents = ZSU.get_ents(@mortise_parent)

        if @tao_mong_duong && @base_tenon
          tenon_clone = @base_tenon.copy
          tenon_clone.transform!(applied_tr)
          tenons << tenon_clone
        end

        if @tao_lo_mong && @base_mortise
          inst = place_clone_in_parent(@base_mortise, applied_tr, @mortise_parent, lo_mong_layer, @instance_lo_mong)
          if inst
            inst.set_attribute("ZSU", "mong_go", true)
            inst.set_attribute("ZSU", "mong_go_id", @current_set_id)
            ZSU::ABF.is_intersect(inst, true)
          end
        end

        if @tao_chot_go
          create_pilots(applied_tr, data, i, so_luong_mong, m_ents, pilot_layer)
        end

        if @tao_ha_nen && @base_ha_nen
          inst = place_clone_in_parent(@base_ha_nen, applied_tr, @mortise_parent, ha_nen_layer, @instance_ha_nen)
          if inst
            inst.set_attribute("ZSU", "mong_go", true)
            inst.set_attribute("ZSU", "mong_go_id", @current_set_id)
          end
        end
      end
    end

    base_groups.each do |bases|
      bases[:tenon].erase! if bases[:tenon]&.valid?
      bases[:ha_nen].erase! if bases[:ha_nen]&.valid?
      bases[:mortise].erase! if bases[:mortise]&.valid?
      bases[:pilot].erase! if bases[:pilot]&.valid?
    end

    if tenons.size > 0
      base = tenons.first
      tenons.shift

      loop_limit_union = 0
      tenons.to_a.each do |tenon|
        loop_limit_union += 1
        break if loop_limit_union > 500
        result = base.union(tenon)
        base = result if result
      end
      ZSU.grep_ents(base, :edge).to_a.each do |e|
        e.set_attribute("ZSU", "mong_go", true)
      end
      if @target_parent
        entities = ZSU.get_ents(@target_parent)
        if entities
          relative_transform = ZSU.is_container?(@target_parent) ?
            @target_parent.transformation.inverse * base.transformation : base.transformation
          new_inst = entities.add_instance(base.definition, relative_transform)
          new_inst.explode
          base.erase!
          ZSU.intersect_fix(entities)
          ZSU::Purge.process_coplanar_edge(entities)
        end
      end
    end

    ZSU.commit
    reset_state
    view.invalidate
  end
end