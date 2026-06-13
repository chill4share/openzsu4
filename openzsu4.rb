require 'sketchup.rb'
require 'extensions.rb'

module OpenZSU
  VERSION = "4.2.8"

  unless file_loaded?(__FILE__)
    loader_path = File.join(File.dirname(__FILE__), "openzsu4", "main.rb")

    extension = SketchupExtension.new("OpenZSU Woodworking", loader_path)
    extension.version     = VERSION
    extension.creator     = "OpenZSU Community"
    extension.copyright   = "2026 OpenZSU"
    extension.description = "Bộ công cụ mã nguồn mở hỗ trợ thiết kế sản xuất nội thất gỗ công nghiệp (Đã đồng bộ cấu trúc 4.2.6)."

    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end