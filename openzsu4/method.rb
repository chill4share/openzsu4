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
    s1_start = center - direction * half_len
    s1_end = center + direction * half_len
    
    i = 0
    while i < edges_flat.length
      e_start = Geom::Point3d.new(edges_flat[i], edges_flat[i+1], edges_flat[i+2])
      e_end = Geom::Point3d.new(edges_flat[i+3], edges_flat[i+4], edges_flat[i+5])
      
      dist = segment_segment_distance(s1_start, s1_end, e_start, e_end)
      if dist < tolerance - 1e-4
        return false
      end
      i += 6
    end
    true
  end

  def self.adjust_centers(centers_flat, ev_a, ev_b, edges_flat, params)
    return [] if centers_flat.nil? || centers_flat.empty?
    
    direction = Geom::Vector3d.new(ev_a[0], ev_a[1], ev_a[2]).normalize
    half_len = params[0].to_f
    step = params[1].to_f
    tolerance = params[2].to_f
    range_start = Geom::Point3d.new(params[3], params[4], params[5])
    range_end = Geom::Point3d.new(params[6], params[7], params[8])
    
    centers = []
    i = 0
    while i < centers_flat.length
      centers << Geom::Point3d.new(centers_flat[i], centers_flat[i+1], centers_flat[i+2])
      i += 3
    end
    
    t_values = centers.map { |c| (c - range_start).dot(direction) }
    
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
      max_steps = ( [dist_prev, dist_next].max / step ).ceil
      
      found = false
      (1..max_steps).each do |s|
        shifted_t = t_curr + s * step
        if shifted_t > t_prev && shifted_t < t_next
          shifted_center = center + direction * (s * step)
          if check_clear(shifted_center, direction, half_len, edges_flat, tolerance)
            adjusted_flat.push(shifted_center.x, shifted_center.y, shifted_center.z)
            found = true
            break
          end
        end
        
        shifted_t = t_curr - s * step
        if shifted_t > t_prev && shifted_t < t_next
          shifted_center = center - direction * (s * step)
          if check_clear(shifted_center, direction, half_len, edges_flat, tolerance)
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