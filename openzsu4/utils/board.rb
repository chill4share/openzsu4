module ZSU::Board
  def self.calc_thickness(group)
    faces = group.definition.entities.grep(Sketchup::Face)
    largest = faces.max_by(2) { |f| f.area }
    return unless largest && largest.size == 2
    f1, f2 = largest
    return if ZSU::Face.faces_coplanar?(f1, f2)
    return unless (f1.area - f2.area).abs < ZSU::AREA_TOL
    d = ZSU::Face.calc_distance(f1, f2)
    d
  end
  def self.reset_axes(group)
    ZSU.start
    return nil unless group && group.respond_to?(:definition)
    definition = group.definition
    entities = definition.entities
    edges = entities.grep(Sketchup::Edge)
    faces = entities.grep(Sketchup::Face)
    return nil if edges.empty? || faces.empty?
    longest_edge = edges.max_by { |e| e.length }
    edge_vec = longest_edge.start.position.vector_to(longest_edge.end.position)
    largest_face = faces.max_by { |f| f.area }
    zaxis = largest_face.normal
    dot = edge_vec.dot(zaxis)
    xaxis = Geom::Vector3d.new(
      edge_vec.x - dot * zaxis.x,
      edge_vec.y - dot * zaxis.y,
      edge_vec.z - dot * zaxis.z
    )
    xaxis = edge_vec if xaxis.length < 0.001
    xaxis.normalize!
    yaxis = zaxis.cross(xaxis)
    yaxis.normalize!
    p1 = longest_edge.start.position
    p2 = longest_edge.end.position
    origin = [p1, p2].min_by { |p| [p.z, p.y, -p.x] }
    new_axes = Geom::Transformation.axes(origin, xaxis, yaxis, zaxis)
    definition.entities.transform_entities(new_axes.inverse, entities.to_a)
    definition.instances.each { |i| i.transformation *= new_axes }
    ZSU.commit
  end
  def self.add_thickness(group, d)
    faces = group.definition.entities.grep(Sketchup::Face)
    largest = faces.max_by(2) { |f| f.area }
    return unless largest && largest.size == 2
    f1, f2 = largest
    d /= 2
    f1.pushpull(d)
    f2.pushpull(d)
  end
  def self.change_thickness(group, target, bb)
    faces = group.definition.entities.grep(Sketchup::Face)
    largest = faces.max_by(2) { |f| f.area }
    return unless largest && largest.size == 2
    f1, f2 = largest
    d = ZSU::Face.calc_distance(f1, f2)
    return unless d && d > 0
    delta = (target - d)
    if ZSU::Face.on_outer?(f1, bb, group) && !ZSU::Face.on_outer?(f2, bb, group)
      f2.pushpull(delta)
    elsif ZSU::Face.on_outer?(f2, bb, group) && !ZSU::Face.on_outer?(f1, bb, group)
      f1.pushpull(delta)
    else
      delta /= 2
      f1.pushpull(delta)
      f2.pushpull(delta)
    end
  end
  def self.clone_and_clean(b)
    ents = b.parent.entities
    dup = ents.add_instance(b.definition, b.transformation)
    dup = dup.make_unique
    ZSU::ABF.clean_tag(dup)
    faces = ZSU.grep_ents(dup, :face)
    faces.each { |f| ZSU::ABF.remove_band(f) if f.valid? }
    dup
  end
  def self.filter_and_fix
    model = Sketchup.active_model
    selection = model.selection
    boards = selection.to_a.select { |e| ZSU.is_container?(e) && ZSU::Board.calc_thickness(e) }
    ZSU.start
    boards.map! { |board|
      b = ZSU::Group.component_to_group(board)
      board = b if b
      board = board.make_unique
      ZSU::Group.fix_scale(board)
      board
    }
    ZSU.commit
    ZSU.select(boards)
    boards
  end
  def self.calc_local_size(board)
    b = board.definition.bounds
    t = board.transformation
    x = ((b.max.x - b.min.x) * t.xscale)
    y = ((b.max.y - b.min.y) * t.yscale)
    z = ((b.max.z - b.min.z) * t.zscale)
    [x, y, z]
  end
  def self.vparallel?(a, b)
    a = a.clone.normalize; b = b.clone.normalize
    a.valid? && b.valid? && a.dot(b).abs > 1.0 - ZSU::TOL
  end
  def self.is_container?(ent)
    ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
  end
  def self.is_panel?(ent)
    return false unless is_container?(ent)
    ents = ZSU.get_ents(ent)
    return false if ents.any? { |e| is_container?(e) }
    faces = ents.grep(Sketchup::Face)
    edges = ents.grep(Sketchup::Edge)
    return false unless edges.all? { |e| e.faces.length == 2 }
    areas = faces.map { |f| [f, f.area] }.sort_by { |fa| -fa[1] }
    f1, a1 = areas[0]
    f2, a2 = areas[1]
    return false unless (a1 - a2).abs < ZSU::TOL
    return false unless vparallel?(f1.normal, f2.normal)
    big_faces = [f1, f2]
    other_edges = edges.reject { |e| (big_faces & e.faces).any? }
    return false if other_edges.empty?
    e = other_edges.first
    vec = e.line[1].normalize
    return false unless vparallel?(vec, f1.normal) && vparallel?(vec, f2.normal)
    e.length
  end
  def self.make(face, ents, offset, push)
    group = ents.add_group
    hole_faces = []
    inner_loops = ZSU::Face.inner_loops(face)
    inner_loops.each do |loop|
      points = loop.vertices.map { |v| v.position }
      hole_face = group.entities.add_face(points)
      hole_faces << hole_face if hole_face.valid?
    end
    outer_points = face.outer_loop.vertices.map { |v| v.position }
    new_face = group.entities.add_face(outer_points)
    return unless new_face
    hole_faces.each { |hole_face| hole_face.erase! if hole_face.valid? }
    ZSU::Face.orient_normal(new_face, face)
    if offset != 0
      edges = new_face.edges
      ZSU::Offset.moffset_old(new_face, offset, group.entities)
      oface = group.entities.grep(Sketchup::Face).find { |f| f != new_face }
      edges.each { |e| e.erase! }
    else
      oface = new_face
    end
    oface.pushpull(push) if oface
    group
  end
  def self.calc_normal(board)
    entities = board.is_a?(Sketchup::ComponentInstance) ? board.definition.entities : board.entities
    faces = entities.grep(Sketchup::Face)
    largest_face = faces.max_by { |face| face.area }
    normal = largest_face.normal
    transformation = board.transformation
    normal.transform!(transformation)
    normal.normalize!
    normal
  end
  def self.group_by_normal(boards)
    board_normals = boards.map do |board|
      normal = ZSU::Board.calc_normal(board)
      [board, normal]
    end
    groups = []
    board_normals.each do |board, normal|
      added = false
      groups.each do |group|
        group_normal = group.first[1]
        dot_product = normal.dot(group_normal)
        if (dot_product.abs > 0.999)
          group << [board, normal]
          added = true
          break
        end
      end
      groups << [[board, normal]] unless added
    end
    groups.map { |group| group.map { |board, _normal| board } }
  end
  def self.rebuild(board)
    ents = ZSU.get_ents(board)
    local_bb = Geom::BoundingBox.new
    ents.each { |e| local_bb.add(e.bounds) if e.respond_to?(:bounds) }
    return false if local_bb.empty?
    x0, y0, z0 = local_bb.min.x, local_bb.min.y, local_bb.min.z
    x1, y1, z1 = local_bb.max.x, local_bb.max.y, local_bb.max.z
    return false if [x1 - x0, y1 - y0, z1 - z0].any? { |d| d < 1e-6 }
    if board.material.nil? && ents.grep(Sketchup::Face).any?
      materials = ents.grep(Sketchup::Face).map(&:material).compact.uniq
      board.material = materials.first if materials.size == 1
    end
    ents.clear!
    pts = [
      Geom::Point3d.new(x0, y0, z0), Geom::Point3d.new(x1, y0, z0),
      Geom::Point3d.new(x1, y1, z0), Geom::Point3d.new(x0, y1, z0),
      Geom::Point3d.new(x0, y0, z1), Geom::Point3d.new(x1, y0, z1),
      Geom::Point3d.new(x1, y1, z1), Geom::Point3d.new(x0, y1, z1),
    ]
    faces = []
    faces << ents.add_face(pts[0], pts[1], pts[2], pts[3])
    faces << ents.add_face(pts[4], pts[5], pts[6], pts[7])
    faces << ents.add_face(pts[0], pts[1], pts[5], pts[4])
    faces << ents.add_face(pts[1], pts[2], pts[6], pts[5])
    faces << ents.add_face(pts[2], pts[3], pts[7], pts[6])
    faces << ents.add_face(pts[3], pts[0], pts[4], pts[7])
    faces.compact!
    box_center = Geom::Point3d.new((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
    faces.each do |face|
      next unless face && face.valid?
      fc = face.bounds.center
      face.reverse! if face.normal.dot(fc - box_center) < 0
    end
    true
  end
  def self.get_band_faces(ents, min_edge_length = 0)
    target_faces = []
    ents.each do |entity|
      exd = get_cnc_faces(entity)
      ZSU.grep_ents(entity, :face).each do |face|
        next if exd.include?(face)
        next unless ZSU::Face.rectangle_edges(face)
        next unless face.edges.map { |e| e.length }.max > min_edge_length
        target_faces << { face: face, parent: entity }
      end
    end
    target_faces
  end
  def self.tim_van_gan_nhat(refs, d:, hidden: false)
    refs = [refs] unless refs.is_a?(Array)
    min_x = Float::INFINITY;  min_y = Float::INFINITY;  min_z = Float::INFINITY
    max_x = -Float::INFINITY; max_y = -Float::INFINITY; max_z = -Float::INFINITY
    refs.each do |b|
      bb = b.bounds
      x0 = bb.min.x - d; y0 = bb.min.y - d; z0 = bb.min.z - d
      x1 = bb.max.x + d; y1 = bb.max.y + d; z1 = bb.max.z + d
      min_x = x0 if x0 < min_x; min_y = y0 if y0 < min_y; min_z = z0 if z0 < min_z
      max_x = x1 if x1 > max_x; max_y = y1 if y1 > max_y; max_z = z1 if z1 > max_z
    end
    result = []
    ZSU::Model.active_entities.each do |g|
      next unless ZSU.is_container?(g)
      next if refs.include?(g)
      unless hidden
        next if g.hidden?
        next if g.layer && !g.layer.visible?
      end
      next unless calc_thickness(g)
      gb = g.bounds
      next if gb.min.x > max_x || gb.max.x < min_x ||
              gb.min.y > max_y || gb.max.y < min_y ||
              gb.min.z > max_z || gb.max.z < min_z
      result << g
    end
    result
  end
  def self.get_cnc_faces(input)
    scale_factor_in_plane = ->(plane, transformation) {
      normal = plane.size == 2 ? plane[1].normalize : Geom::Vector3d.new(plane[0], plane[1], plane[2]).normalize
      plane_vector0 = (normal.parallel?(Z_AXIS) ? X_AXIS : Z_AXIS)
      plane_vector1 = normal * plane_vector0
      (plane_vector0.transform(transformation) * plane_vector1.transform(transformation)).length.to_f
    }
    faces = input.is_a?(Array) ? input : ZSU.grep_ents(input, :face)
    areas = {}
    faces.each do |face|
      next unless face.is_a?(Sketchup::Face) && face.valid?
      area = face.area * scale_factor_in_plane.call(face.plane, IDENTITY)
      areas[face] = area
    end
    areas.sort_by { |_, area| -area }.first(2).map(&:first)
  end
end