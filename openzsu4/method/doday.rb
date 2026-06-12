class ZSU::Doday
  include ZSU::Preset
  settings_section "doday"
  def initialize
    ZSU.init_undo
    init_var
  end
  def init_var
    @sua_loi_tiep_giap = read("sua_loi_tiep_giap", true)
    @ti_le_nen_do = read("ti_le_nen_do", ZSU::View.grid_scale, true).to_f
    @bo_dem_nen = read("bo_dem_nen", 1, true).to_i
    @do_day = read("do_day", 17.5).to_f.mm
    @ty_le_day = read("ty_le_day", 2.0, true).to_f
    @sai_so_nen = read("sai_so_nen", @bo_dem_nen - 16, true).to_f.mm
    @view_dpi = read("view_dpi", 0, true).to_f.mm
    @bu_sai_nen = read("bu_sai_nen", (@ti_le_nen_do - 1.0) * 11, true).to_f.mm
    @hover_board = nil
  end
  def init_buttons
    @presets = read("presets", nil)
    init_preset_buttons(@presets)
    init_setting_buttons(
      "Sửa tiếp giáp" => {
        sua_loi_tiep_giap: [:switch, "Sửa tiếp giáp"],
      },
      "Độ dày" => {
        do_day: [:mm, "Độ dày"],
      }
    )
  end
  def load_preset(preset_settings)
    @sua_loi_tiep_giap = preset_settings["sua_loi_tiep_giap"]
    @do_day = preset_settings["do_day"].to_f.mm if preset_settings["do_day"]
  end
  def activate
    selection = Sketchup.active_model.selection.to_a.select do |e|
      ZSU.is_container?(e) && ZSU::Board.calc_thickness(e)
    end
    if selection.any?
      values = open_settings
      return ZSU.select_tool(nil) unless values
      process_boards(selection, select_after: true)
      ZSU.select_tool(nil)
      return
    end
    init_buttons
    load_active_preset
    @hover_board = nil
    update_status
  end
  def deactivate(view)
    save_active_preset
    view.invalidate
  end
  def resume(view)
    view.invalidate
    update_status
  end
  def enableVCB?
    true
  end
  def onKeyDown(key, repeat, flags, view)
    ZSU::Settings.open_settings('doday') if key == 192
  end
  def onKeyUp(key, repeat, flags, view)
    find_boards_by_thickness if key == 9
  end
  def onUserText(text, view)
    num = text.to_l.to_mm.to_f
    return if num == 0
    @do_day = num.mm
    write("do_day", num)
    @button_config[:modified] = true if @button_config
    update_status
    view.invalidate
  end
  def onMouseMove(flags, x, y, view)
    handle_ui_mouse_move(x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    picked = ph.best_picked
    old_hover = @hover_board
    if picked && ZSU.is_container?(picked) && ZSU::Board.calc_thickness(picked)
      @hover_board = picked
    else
      @hover_board = nil
    end
    view.invalidate if old_hover != @hover_board
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
    return unless @hover_board
    process_boards([@hover_board])
    @hover_board = nil
    view.invalidate
  end
  def draw(view)
    draw_preset_buttons(view)
    draw_setting_buttons(view)
    return unless @hover_board && @hover_board.valid?
    thickness = ZSU::Board.calc_thickness(@hover_board)
    return unless thickness
    needs_change = (thickness - @do_day).abs > 0.01.mm
    ZSU::View.highlight_board(@hover_board) if needs_change
  end
  def update_status
    ZSU.status("Nhấn chuột vào ván để đổi độ dày. Nhấn Tab để tìm ván theo độ dày.")
    ZSU.vcb("Độ dày", Sketchup.format_length(@do_day))
  end
  private
  def find_boards_by_thickness
    value = format("%.2f", @do_day.to_mm)
    input = UI.inputbox(["Độ dày:"], [value], "Tìm ván theo độ dày")
    return unless input
    target = input[0].to_f.mm
    boards = ZSU::Model.active_entities.select do |e|
      next false unless ZSU.is_container?(e) && !e.hidden?
      t = ZSU::Board.calc_thickness(e)
      t && (t - target).abs < 0.01.mm
    end
    ZSU.select(boards)
  end
  def open_settings
    prompts = ["Sửa tiếp giáp:", "Độ dày mới:"]
    defaults = [@sua_loi_tiep_giap ? "Có" : "Không", format("%.2f", @do_day.to_mm)]
    lists = ["Có|Không", ""]
    values = UI.inputbox(prompts, defaults, lists, "Sửa độ dày")
    return unless values
    @sua_loi_tiep_giap = values[0] == "Có"
    @do_day = values[1].to_f.mm
    write("sua_loi_tiep_giap", @sua_loi_tiep_giap)
    write("do_day", values[1].to_f)
    values
  end
  def process_boards(boards, select_after: false)
    boards = boards.select { |e| e.valid? && ZSU.is_container?(e) && ZSU::Board.calc_thickness(e) }
    return if boards.empty?
    ZSU.init_undo
    boards.map! do |board|
      board = ZSU::Group.component_to_group(board) || board
      board = board.make_unique
      ZSU::Group.fix_scale(board)
      board
    end
    cnc_pairs = apply_thickness(boards, @do_day)
    ZSU.select(boards) if select_after
    ZSU::View.invalidate
    fix_overlapping(boards, cnc_pairs) if @sua_loi_tiep_giap
  end
  def apply_thickness(boards, value)
    faces_cache = {}
    boards.each { |g| faces_cache[g] = ZSU.grep_ents(g, :face) }
    cnc_push = {}
    cnc_pairs = []
    if @sua_loi_tiep_giap
      cnc_info = Hash.new { |h, k| h[k] = [] }
      boards.combination(2).each do |b1, b2|
        result = find_cnc_contact(b1, b2)
        next unless result
        cnc_info[b1] << result[:b1_opposite]
        cnc_info[b2] << result[:b2_opposite]
        cnc_pairs << [b1, b2]
      end
      cnc_info.each do |b, opposites|
        cnc_push[b] = opposites.first if opposites.size == 1
      end
      ZSU.start
      boards.each do |b|
        old_thickness = ZSU::Board.calc_thickness(b)
        next unless old_thickness && value < old_thickness
        delta = value - old_thickness
        others = boards - [b]
        contact_faces = find_contacting_faces(b, others, faces_cache)
        push_faces(contact_faces, delta)
      end
      ZSU.commit
    end
    ZSU.start
    bb = Geom::BoundingBox.new
    boards.each { |b| bb.add(b.bounds) }
    ZSU.commit
    ZSU.start
    boards.each do |b|
      if cnc_push[b]
        old_thickness = ZSU::Board.calc_thickness(b)
        if old_thickness
          delta = value - old_thickness
          cnc_push[b].pushpull(delta * @ty_le_day + @sai_so_nen + @bu_sai_nen) unless delta.abs < 0.001.mm
        end
      else
        ZSU::Board.change_thickness(b, value, bb)
      end
      ZSU::ABF.fix_marking(b)
    end
    ZSU.commit
    cnc_pairs
  end
  def find_contacting_faces(b, others, faces_cache)
    all_faces = faces_cache[b] || ZSU.grep_ents(b, :face)
    largest = ZSU::Board.get_cnc_faces(b)
    return [] unless largest && largest.size == 2
    side_faces = all_faces - largest
    return [] if side_faces.empty?
    tr = b.transformation
    side_faces.select do |face|
      next false unless face.valid?
      face_center = face.bounds.center.transform(tr)
      face_contacting?(face_center, others, faces_cache)
    end
  end
  def find_cnc_contact(b1, b2)
    cnc1 = ZSU::Board.get_cnc_faces(b1)
    cnc2 = ZSU::Board.get_cnc_faces(b2)
    return nil unless cnc1&.size == 2 && cnc2&.size == 2
    tr1 = b1.transformation
    tr2_inv = b2.transformation.inverse
    cnc1.each_with_index do |f1, i|
      center1 = f1.bounds.center.transform(tr1)
      local_p = center1.transform(tr2_inv)
      cnc2.each_with_index do |f2, j|
        return { b1_opposite: cnc1[1 - i], b2_opposite: cnc2[1 - j] } \
          if f2.classify_point(local_p) == Sketchup::Face::PointInside
      end
    end
    nil
  end
  def face_contacting?(point, containers, faces_cache)
    containers.any? do |g|
      local_point = point.transform(g.transformation.inverse)
      faces = faces_cache[g] || ZSU.grep_ents(g, :face)
      faces.any? do |f|
        f.classify_point(local_point) == Sketchup::Face::PointInside
      end
    end
  end
  def push_faces(faces, delta)
    return unless faces&.any?
    faces.each do |face|
      face.pushpull(-delta * @ty_le_day) if face.valid?
    end
  end
  def fix_overlapping(boards, cnc_pairs = [])
    return unless boards && boards.length >= 2
    cnc_set = cnc_pairs.map { |b1, b2| [b1, b2].sort_by(&:object_id) }
    ZSU.start
    boards.combination(2).each do |b1, b2|
      next unless b1.valid? && b2.valid? && b1.bounds.intersect(b2.bounds).valid?
      pair = [b1, b2].sort_by(&:object_id)
      next if cnc_set.any? { |p| p[0] == pair[0] && p[1] == pair[1] }
      try_trim_pair(b1, b2)
    end
    ZSU.commit
    ZSU::View.invalidate
  end
  def try_trim_pair(b1, b2)
    return if try_trim(b1, b2)
    try_trim(b2, b1)
  end
  def try_trim(primary, secondary)
    dup1 = ZSU::Board.clone_and_clean(primary)
    dup2 = ZSU::Board.clone_and_clean(secondary)
    ZSU::Solid.trim(dup1, dup2)
    success = ZSU::Board.is_panel?(dup1) && ZSU::Board.is_panel?(dup2)
    if success
      dup = ZSU::Board.clone_and_clean(secondary)
      ZSU::Solid.trim(primary, dup)
      dup.erase! if dup.valid?
    end
    dup1.erase! if dup1.valid?
    dup2.erase! if dup2.valid?
    success
  end
end
