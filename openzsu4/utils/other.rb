module ZSU
  def self.select_tool(tool_class)
    if tool_class.is_a?(Class)
      tool_instance = tool_class.new
      Sketchup.active_model.select_tool(tool_instance)
    else
      Sketchup.active_model.select_tool(nil)
    end
  end
  def self.init_undo
    start(false)
    Sketchup.active_model.set_attribute("_temp_", "_", nil)
    commit
  end
  def self.start(trans = true)
    Sketchup.active_model.start_operation("ZSU", true, false, trans)
  end
  def self.commit
    Sketchup.active_model.commit_operation
  end
  def self.status(text)
    Sketchup.set_status_text(text)
  end
  def self.vcb(label, value)
    Sketchup.set_status_text(label, SB_VCB_LABEL)
    return unless value
    Sketchup.set_status_text(value, SB_VCB_VALUE)
  end
  def self.parse_color(value)
    if value.is_a?(String)
      rgb = value.split(',').map { |v| v.strip.to_i }
      Sketchup::Color.new(rgb[0], rgb[1], rgb[2], 200)
    elsif value.is_a?(Array)
      Sketchup::Color.new(value[0], value[1], value[2], 200)
    else
      Sketchup::Color.new(128, 128, 128, 200)
    end
  end
  def self.ensure_tag(tag_name)
    tag_name = tag_name.to_s.strip
    return nil if tag_name.empty?
    layers = Sketchup.active_model.layers
    tag = layers[tag_name] || layers.add(tag_name)
    tag.visible = true
    tag
  end
  def self.select(ents)
    selection = Sketchup.active_model.selection
    selection.clear
    ents = Array(ents)
    return unless ents && ents.size > 0
    selection.add(ents)
  end
  def self.get_transform(instance_path)
    transformation = Geom::Transformation.new
    p = instance_path.reject { |e| !e.respond_to?(:transformation) }
    p.each { |inst| transformation *= inst.transformation }
    transformation
  end
  def self.find_concave_vertex(face, limit_length, limit_angle)
    output_vertex = []
    face.loops.each do |loop|
      verts = loop.vertices
      verts.pop if verts.first == verts.last
      verts.each_with_index do |vtx, i|
        prev = verts[i - 1]
        curr = vtx
        nxt = verts[(i + 1) % verts.size]
        vec1 = prev.position.vector_to(curr.position)
        vec2 = nxt.position.vector_to(curr.position)
        next unless vec1.length >= limit_length && vec2.length >= limit_length
        angle = vec1.angle_between(vec2)
        next unless angle.between?(90.degrees - limit_angle.degrees, 90.degrees + limit_angle.degrees)
        v = vec1.normalize + vec2.normalize
        next if v.length == 0
        v.length = 1.mm
        new_pt = curr.position + v
        if face.classify_point(new_pt) == Sketchup::Face::PointInside
          output_vertex << curr
        end
      end
    end
    output_vertex
  end
  def self.is_container?(ent)
    ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
  end
  def self.create_color_mat(rgb, alpha = 1.0)
    ZSU::Material.create_color(rgb, alpha)
  end
  def self.grep_ents(b, mode)
    ents = get_ents(b)
    return unless ents
    case mode
      when :face
        output = ents.grep(Sketchup::Face)
      when :edge
        output = ents.grep(Sketchup::Edge)
      when :vertex
        output = ents.grep(Sketchup::Edge).map(&:vertices).flatten.uniq
      when :group
        output = ents.grep(Sketchup::Group)
    end
    output
  end
  def self.get_ents(parent)
    return parent.entities if parent.is_a?(Sketchup::Group)
    return parent.entities if parent.is_a?(Sketchup::ComponentDefinition)
    return parent.definition.entities if parent.is_a?(Sketchup::ComponentInstance)
    nil
  end
  def self.intersect_fix(ent)
    ent.intersect_with(false, Geom::Transformation.new, ent, Geom::Transformation.new, true, ent.grep(Sketchup::Edge))
  end
  def self.find_face(ents)
    ents.grep(Sketchup::Edge).each { |e| e.find_faces if e.valid? }
  end
end