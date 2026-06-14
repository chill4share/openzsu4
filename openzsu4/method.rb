module ZSU::Method

  def self.native_valid?
    false
  end

  def self.validate_token(token)
    false
  end

  def self.build_arc_points(center, start_angle, end_angle, radius, vx, vy, segments)
    pts = []
    seg_count = [segments.to_i, 1].max
    da = (end_angle.to_f - start_angle.to_f) / seg_count

    (0..seg_count).each do |i|
      angle = start_angle.to_f + i * da
      cx = center.x + radius.to_f * Math.cos(angle) * vx.x + radius.to_f * Math.sin(angle) * vy.x
      cy = center.y + radius.to_f * Math.cos(angle) * vx.y + radius.to_f * Math.sin(angle) * vy.y
      cz = center.z + radius.to_f * Math.cos(angle) * vx.z + radius.to_f * Math.sin(angle) * vy.z
      pts << Geom::Point3d.new(cx, cy, cz)
    end
    pts
  rescue => e
    puts "OpenZSU Error in build_arc_points: #{e.message}"
    []
  end

  def self.point_to_segment_distance(p, a, b)
    ab = b - a
    len_sq = ab.length_sq
    if len_sq < 1e-9
      return p.distance(a)
    end
    t = ((p - a).dot(ab)) / len_sq
    t = [[t, 0.0].max, 1.0].min
    closest = a + ab * t
    p.distance(closest)
  end

  def self.segments_intersect?(p1, p2, p3, p4)
    line1 = [p1, p2 - p1]
    line2 = [p3, p4 - p3]
    intersection = Geom.intersect_line_line(line1, line2)
    return false unless intersection

    t1 = (intersection - p1).dot(p2 - p1) / (p2 - p1).length_sq rescue -1
    return false unless (0.0..1.0).cover?(t1)

    t2 = (intersection - p3).dot(p4 - p3) / (p4 - p3).length_sq rescue -1
    return false unless (0.0..1.0).cover?(t2)

    true
  end

  def self.segment_segment_distance(p1, p2, p3, p4)
    if segments_intersect?(p1, p2, p3, p4)
      return 0.0
    end
    [
      point_to_segment_distance(p1, p3, p4),
      point_to_segment_distance(p2, p3, p4),
      point_to_segment_distance(p3, p1, p2),
      point_to_segment_distance(p4, p1, p2)
    ].min
  end

  def self.check_clear(center, direction, half_len, edges_flat, tolerance)
    # Safely convert center to Point3d
    unless center.is_a?(Geom::Point3d)
      begin
        center = Geom::Point3d.new(center)
      rescue
        return true # Skip check or treat as clear
      end
    end

    # Safely convert direction to Vector3d
    unless direction.is_a?(Geom::Vector3d)
      begin
        if direction.respond_to?(:to_vector)
          direction = direction.to_vector
        else
          direction = Geom::Vector3d.new(direction)
        end
      rescue
        return true
      end
    end

    begin
      direction = direction.normalize
    rescue
      return true
    end

    # Safely convert numeric values
    half_len = half_len.to_f rescue 0.0
    tolerance = tolerance.to_f rescue 0.0

    # Ensure s1_start and s1_end are calculated safely
    begin
      s1_start = center - direction * half_len
      s1_end = center + direction * half_len
    rescue
      s1_start = center
      s1_end = center
    end

    return true if edges_flat.nil? || edges_flat.empty?

    i = 0
    while i < edges_flat.length
      begin
        break if i + 5 >= edges_flat.length
        
        e_start = Geom::Point3d.new(edges_flat[i].to_f, edges_flat[i+1].to_f, edges_flat[i+2].to_f)
        e_end = Geom::Point3d.new(edges_flat[i+3].to_f, edges_flat[i+4].to_f, edges_flat[i+5].to_f)

        dist = segment_segment_distance(s1_start, s1_end, e_start, e_end) rescue Float::INFINITY
        if dist < tolerance - 1e-4
          return false
        end
      rescue
        # If any edge is corrupted, skip it
      end
      i += 6
    end
    true
  end

  def self.adjust_centers(centers_flat, ev_a, ev_b, edges_flat, params)
    return [] if centers_flat.nil? || centers_flat.empty?

    begin
      # Safely construct direction vector
      if ev_a.nil?
        direction = Geom::Vector3d.new(0, 0, 1)
      elsif ev_a.is_a?(Geom::Vector3d)
        direction = ev_a.normalize rescue Geom::Vector3d.new(0, 0, 1)
      elsif ev_a.respond_to?(:to_vector)
        direction = ev_a.to_vector.normalize rescue Geom::Vector3d.new(0, 0, 1)
      elsif ev_a.is_a?(Array) && ev_a.length >= 3
        direction = Geom::Vector3d.new(ev_a[0].to_f, ev_a[1].to_f, ev_a[2].to_f).normalize rescue Geom::Vector3d.new(0, 0, 1)
      else
        direction = Geom::Vector3d.new(0, 0, 1)
      end
    rescue
      direction = Geom::Vector3d.new(0, 0, 1)
    end

    half_len = (params && params[0]) ? params[0].to_f : 0.0
    step = (params && params[1] && params[1].to_f > 0.001) ? params[1].to_f : 10.0
    tolerance = (params && params[2]) ? params[2].to_f : 0.0

    begin
      range_start = (params && params[3] && params[4] && params[5]) ? Geom::Point3d.new(params[3].to_f, params[4].to_f, params[5].to_f) : Geom::Point3d.new(0, 0, 0)
    rescue
      range_start = Geom::Point3d.new(0, 0, 0)
    end

    begin
      range_end = (params && params[6] && params[7] && params[8]) ? Geom::Point3d.new(params[6].to_f, params[7].to_f, params[8].to_f) : Geom::Point3d.new(0, 0, 0)
    rescue
      range_end = Geom::Point3d.new(0, 0, 0)
    end

    centers = []
    i = 0
    while i < centers_flat.length
      begin
        break if i + 2 >= centers_flat.length
        centers << Geom::Point3d.new(centers_flat[i].to_f, centers_flat[i+1].to_f, centers_flat[i+2].to_f)
      rescue
        # Ignore invalid center points
      end
      i += 3
    end

    return centers_flat if centers.empty?

    # Pre-calculate t-values safely
    t_values = centers.map { |c| ((c - range_start).dot(direction) rescue 0.0) }

    adjusted_flat = []

    centers.each_with_index do |center, idx|
      if check_clear(center, direction, half_len, edges_flat, tolerance)
        adjusted_flat.push(center.x, center.y, center.z)
        next
      end

      t_curr = t_values[idx]
      t_prev = (idx == 0) ? -1e9 : t_values[idx - 1]
      t_next = (idx == t_values.length - 1) ? 1e9 : t_values[idx + 1]

      dist_prev = t_curr - t_prev
      dist_next = t_next - t_curr
      max_steps = ( [dist_prev, dist_next].max / step ).ceil rescue 10
      max_steps = 100 if max_steps > 100 # Guard against infinite loop / large step count

      found = false
      (1..max_steps).each do |s|
        shifted_t = t_curr + s * step
        if shifted_t > t_prev && shifted_t < t_next
          shifted_center = center + direction * (s * step) rescue nil
          if shifted_center && check_clear(shifted_center, direction, half_len, edges_flat, tolerance)
            adjusted_flat.push(shifted_center.x, shifted_center.y, shifted_center.z)
            found = true
            break
          end
        end

        shifted_t = t_curr - s * step
        if shifted_t > t_prev && shifted_t < t_next
          shifted_center = center - direction * (s * step) rescue nil
          if shifted_center && check_clear(shifted_center, direction, half_len, edges_flat, tolerance)
            adjusted_flat.push(shifted_center.x, shifted_center.y, shifted_center.z)
            found = true
            break
          end
        end
      end

      unless found
        adjusted_flat.push(center.x, center.y, center.z)
      end
    end

    adjusted_flat
  rescue => e
    puts "OpenZSU Error in adjust_centers: #{e.message}\n#{e.backtrace.join("\n")}"
    centers_flat
  end

end

require_relative 'method/amduong'
require_relative 'method/banle'       
require_relative 'method/baoranh'     
require_relative 'method/bogoc'
require_relative 'method/caidat'      
require_relative 'method/doday'       
require_relative 'method/duckhung'
require_relative 'method/khauvan'
require_relative 'method/khudao'
require_relative 'method/lienket'     
require_relative 'method/monggo'       
require_relative 'method/noivan'
require_relative 'method/phuchoi'     
require_relative 'method/taocanh'
require_relative 'method/taovan'
require_relative 'method/uoncong'