module ZSU
  class Khauvan
    include ZSU::Preset
    settings_section "khau_van"
    def initialize
      ZSU.init_undo
      init_var
    end
    def activate
      init_var
      load_active_preset
      sel = ZSU::Board.filter_and_fix
      if sel&.any?
        ZSU.select(nil)
        if @dao_thu_tu
          @bi_khau = sel
          @dao_khau = []
        else
          @dao_khau = sel
          @bi_khau = []
        end
        @state = 1
      else
        @bi_khau = []
        @dao_khau = []
        @state = 0
      end
      update_status
    end
    def onKeyDown(key, repeat, flags, view)
      if key == 192
        ZSU::Settings.open_settings('khau_van')
        return true
      end
    end
    def init_var
      @dao_thu_tu = read("dao_thu_tu", true)
      @do_chinh_khau_do = read("do_chinh_khau_do", ZSU::View.grid_scale, true).to_f
      @kich_hoat_khu_dao = read("kich_hoat_khu_dao", true)
      @bo_dem_khau = read("bo_dem_khau", 1, true).to_i
      @khau_them = read("khau_them", false)
      @ty_le_khau = read("ty_le_khau", 2.0, true).to_f
      @kieu_khau_them = read("kieu_khau_them", "tat_ca")
      @gia_tri_khau_them = read("gia_tri_khau_them", 0.0).to_f.mm
      @tu_dong_tach_khoi = read("tu_dong_tach_khoi", true)
      @bu_tru_van_khau = read("bu_tru_van_khau", (@do_chinh_khau_do - 1.0) * 14, true).to_f.mm
      @hieu_chinh_khau = read("hieu_chinh_khau", @bo_dem_khau - 32, true).to_f.mm
      @view_dpi = read("view_dpi", 0, true).to_f.mm
      @mau_dao_khau = read("mau_dao_khau", "60, 175, 214")
      @mau_bi_khau = read("mau_bi_khau", "210, 117, 159")
      @presets = read("presets", nil)
      init_preset_buttons(@presets)
      init_setting_buttons(
        "Đảo thứ tự chọn" => {
          dao_thu_tu: [:switch, "Đảo thứ tự chọn"],
        },
        "Kích hoạt khử dao" => {
          kich_hoat_khu_dao: [:switch, "Kích hoạt khử dao"],
        },
        "Khấu thêm" => {
          khau_them: [:switch, "Khấu thêm"],
          kieu_khau_them: [:select, "Kiểu khấu thêm", {
            "tat_ca" => "Tất cả", "tiet_dien" => "Tiết diện", "chieu_day" => "Chiều dày"
          }, -> { @khau_them }],
          gia_tri_khau_them: [:mm, "Giá trị khấu thêm", -> { @khau_them }, 0],
        },
        "Tự động tách khối" => {
          tu_dong_tach_khoi: [:switch, "Tự động tách khối"],
        },
        "Màu sắc" => {
          mau_dao_khau: [:color, "Màu dao khấu"],
          mau_bi_khau: [:color, "Màu bị khấu"],
        }
      )
      update_status
    end
    def load_preset(s)
      init_preset(:khau_them, s)
      init_preset(:gia_tri_khau_them, s) { |v| v.to_f.mm }
      init_preset(:kieu_khau_them, s)
      init_preset(:kich_hoat_khu_dao, s)
      init_preset(:dao_thu_tu, s)
      init_preset(:tu_dong_tach_khoi, s)
      init_preset(:mau_dao_khau, s)
      init_preset(:mau_bi_khau, s)
    end
    def draw(view)
      draw_preset_buttons(view)
      draw_setting_buttons(view)
      if @bi_khau&.any?
        c = ZSU.parse_color(@mau_bi_khau)
        @bi_khau.each { |b| ZSU::View.highlight_board(b, color: c) }
      end
      if @dao_khau&.any?
        c = ZSU.parse_color(@mau_dao_khau)
        @dao_khau.each { |b| ZSU::View.highlight_board(b, color: c) }
      end
    end
    def onUserText(text, view)
      len = text.to_l.to_mm.to_f
      return if len < 0
      @gia_tri_khau_them = len.mm
      ZSU::Settings.write("gia_tri_khau_them", len, "khau_van")
      @button_config[:modified] = true if @button_config
      view.invalidate if view
      update_status
    end
    def resume(view)
      view.invalidate
      update_status
    end
    def onMouseMove(flags, x, y, view)
      handle_ui_mouse_move(x, y, view)
      ZSU.select(nil)
      ph = view.pick_helper
      ph.do_pick(x, y)
      @picked = ph.best_picked
      if @picked && ZSU::Solid.solid?(@picked) &&
         !@bi_khau.include?(@picked) && !@dao_khau.include?(@picked)
        Sketchup.active_model.selection.add(@picked)
      else
        @picked = nil
      end
    end
    def onLButtonDown(flags, x, y, view)
      return if handle_setting_click(x, y, view)
      if id = handle_preset_click(x, y)
        unless id == :deselected
          index = id.to_s.split('_').last.to_i
          load_preset(@presets[index]["settings"])
        end
        view.invalidate
      elsif @state == 0
        if @picked
          if @dao_thu_tu
            @bi_khau << @picked unless @bi_khau.include?(@picked)
          else
            @dao_khau << @picked unless @dao_khau.include?(@picked)
          end
          @picked = nil
          view.invalidate
          update_status
        end
      else
        unless @picked
          exit_tool(view)
          return
        end
        if @dao_thu_tu
          xu_ly_nguoc(flags, x, y, view)
        else
          xu_ly_xuoi(flags, x, y, view)
        end
        @picked = nil
        view.invalidate
      end
    end
    def tach_khoi_le(group)
      result = []
      return result unless group&.valid?
      ents = ZSU.get_ents(group)
      loose = ents.grep(Sketchup::Edge) + ents.grep(Sketchup::Face)
      return result if loose.empty?
      clusters = find_clusters(loose)
      return result if clusters.size <= 1
      main = clusters.max_by { |c| c.grep(Sketchup::Face).sum(&:area) }
      parent_ents = group.parent.entities
      copy = parent_ents.add_group
      copy.transformation = group.transformation
      copy.name = group.name
      copy.layer = group.layer
      copy.entities.add_instance(group.definition, Geom::Transformation.new).explode
      (clusters - [main]).flatten.each { |e| e.erase! if e.valid? }
      copy_ents = copy.definition.entities
      copy_ents.grep(Sketchup::Group).each { |g| g.erase! if g.valid? }
      copy_ents.grep(Sketchup::ComponentInstance).each { |c| c.erase! if c.valid? }
      copy_loose = copy_ents.grep(Sketchup::Edge) + copy_ents.grep(Sketchup::Face)
      copy_clusters = find_clusters(copy_loose)
      copy_main = copy_clusters.max_by { |c| c.grep(Sketchup::Face).sum(&:area) }
      copy_main.each { |e| e.erase! if e.valid? }
      result.concat(tach_khoi_le(copy)) if copy_clusters.size > 2
      result << copy
      result
    end
    def expand_all_faces(group, distance, skip_normal: nil)
      return unless group&.valid? && distance != 0
      ZSU.get_ents(group).grep(Sketchup::Face).each do |face|
        next unless face.valid?
        next if skip_normal && face.normal.parallel?(skip_normal)
        face.pushpull(distance * @ty_le_khau + @hieu_chinh_khau + @bu_tru_van_khau)
      end
    end
    def xu_ly_nguoc(flags, x, y, view)
      ZSU.start
      khau_them_vao(@bi_khau, @picked)
      ZSU::Purge.fix_all_hole(@bi_khau)
      @dao_khau << @picked
      ZSU.commit
    end
    def xu_ly_xuoi(flags, x, y, view)
      ZSU.start
      khau_them_vao([@picked], *@dao_khau)
      ZSU::Purge.fix_all_hole([@picked])
      @bi_khau << @picked
      ZSU.commit
    end
    def update_status
      if @state == 0
        text = @dao_thu_tu ?
          "Chọn ván bị khấu. Nhấn Enter để chuyển sang chọn dao khấu." :
          "Chọn dao khấu. Nhấn Enter để chuyển sang chọn ván bị khấu."
      else
        text = @dao_thu_tu ? "Chọn dao khấu." : "Chọn ván bị khấu."
        text += " Nhấn Enter để kết thúc." if @kich_hoat_khu_dao
      end
      ZSU.status(text)
      ZSU.vcb("Khấu thêm", Sketchup.format_length(@gia_tri_khau_them))
    end
    def enableVCB?
      true
    end
    def exit_tool(view)
      tach = []
      if @tu_dong_tach_khoi && @bi_khau&.any?
        ZSU.start(false)
        @bi_khau.each { |bi| tach.concat(tach_khoi_le(bi)) }
        ZSU.commit
      end
      all = (@bi_khau || []) + tach
      if @kich_hoat_khu_dao
        ZSU.select(all)
        ZSU.select_tool(ZSU::Khudao)
      elsif @dao_thu_tu
        ZSU.select(all)
      else
        ZSU.select(@dao_khau)
      end
      view.invalidate
    end
    def onReturn(view)
      if @state == 0
        ready = @dao_thu_tu ? @bi_khau.any? : @dao_khau.any?
        if ready
          @state = 1
          update_status
          view.invalidate
        else
          UI.beep
        end
      else
        exit_tool(view)
      end
    end
    def deactivate(view)
      save_active_preset
      exit_tool(view)
    end
    private
    def find_clusters(loose)
      clusters = []
      remaining = loose.dup
      while remaining.any?
        connected = remaining.first.all_connected & remaining
        clusters << connected
        remaining -= connected
      end
      clusters
    end
    def khau_them_vao(targets, *daos)
      if @khau_them
        if @kieu_khau_them == "chieu_day"
          daos.each do |dao|
            next unless dao.valid?
            dup = ZSU::Board.clone_and_clean(dao)
            ZSU::Board.add_thickness(dup, @gia_tri_khau_them * 2)
            targets.each { |t| ZSU::Solid.trim(t, dup) if t.valid? }
            dup.erase! if dup.valid?
          end
        else
          daos.each do |dao|
            next unless dao.valid?
            skip = @kieu_khau_them == "tiet_dien" ?
              ZSU::Board.get_cnc_faces(dao)&.first&.normal : nil
            targets.each do |t|
              next unless t.valid?
              dup_dao = ZSU::Board.clone_and_clean(dao)
              dup_t = ZSU::Board.clone_and_clean(t)
              int = ZSU::Solid.intersect(dup_dao, dup_t)
              next unless int&.valid?
              expand_all_faces(int, @gia_tri_khau_them, skip_normal: skip)
              ZSU::Solid.trim(t, int)
              int.erase! if int.valid?
            end
          end
        end
      else
        daos.each do |dao|
          next unless dao.valid?
          dup = ZSU::Board.clone_and_clean(dao)
          targets.each { |t| ZSU::Solid.trim(t, dup) if t.valid? }
          dup.erase!
        end
      end
    end
  end
end
