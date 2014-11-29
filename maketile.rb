require 'fileutils'
require 'tmpdir'
require 'tempfile'

class MakeTile
  attr_accessor :file, :tile_size, :tile_dir, :base_zoom, :width, :height

  def initialize(file, tile_size, tile_dir)
    self.file = file
    self.tile_size = tile_size
    self.tile_dir = tile_dir
  end

  def make
    zoom_range, base_zoom = zooms
    self.base_zoom = base_zoom
    for z in zoom_range
      make_tile(z)
    end
  end
  
  def zooms
    self.width=`identify -format "%w" #{self.file}`.to_i
    self.height=`identify -format "%h" #{self.file}`.to_i
    base = self.width > self.height ? self.width : self.height
    max_zoom = (Math.log(base) / Math.log(2)).to_i
    min_zoom = (Math.log(self.tile_size) / Math.log(2)).to_i
    return min_zoom..(max_zoom + 1), max_zoom
  end
  
  def make_tile(z)
    scale = (2 ** (z - self.base_zoom)).to_f
    width = (self.width * scale).to_i
    height = (self.height * scale).to_i
    tiles_per_column = (width.to_f / self.tile_size).ceil

    output_dir = File.join(tile_dir, z.to_s)
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)

    Dir.mktmpdir do |working_dir|
      # make resize image
      tmp = Tempfile.new(["tmp", ".png"])
      tmp.close
      `convert -resize #{width}x#{height} #{self.file} #{tmp.path}`
      # crop image
      tilebase = File.join(working_dir, "#{z}_%d.png")
      `convert -crop #{self.tile_size}x#{self.tile_size} +repage #{tmp.path} #{tilebase}`
      tmp.delete

      total_tiles = Dir[File.join(working_dir, "#{z}_*.png")].length
      n = 0
      row = 0
      column = 0

      (n...total_tiles).each do |i|
        filename = File.join(working_dir, "#{z}_#{i}.png")
        target = File.join(tile_dir, z.to_s, "#{column}_#{row}.png")
        `cp -f #{filename} #{target}`
        column = column + 1
        if column >= tiles_per_column
          column = 0
          row = row + 1
        end
      end

    end
  end
end

if __FILE__ == $0
  if ARGV.length < 1
    p "usage: ruby maketile.rb file"
    exit
  end
  file = ARGV[0]
  maketile = MakeTile.new(file, 256, 'tile')
  maketile.make
end
