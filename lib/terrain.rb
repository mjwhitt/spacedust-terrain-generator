#!/usr/bin/env ruby
$:.push File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'fractal_noise', 'lib'))

require 'chunky_png'
require 'fractal_noise'

class Terrain

  TYPES   = [ :desert, :forest, :grassland, :jungle, :rainforest, :savanna, :swamp, :taiga, :tundra,]
  SIZES   = [ 48, 64, 96, 128, 160, 192, 256, 320, 384, 512 ]
  OCTAVES = { 
    48  => [4, 5],
    64  => [   5, 6, 7],
    96  => [   5, 6],
    128 => [   5, 6, 7, 8],
    160 => [   5, 6],
    192 => [      6, 7],
    256 => [      6, 7, 8, 9],
    320 => [      6, 7],
    384 => [      6, 7, 8],
    512 => [         7, 8, 9, 10],
  }
  WATER = {
    :desert     => {:above => 0.90,                                         },
    :savanna    => {                                :between => [0.30, 0.40]},
    :jungle     => {                :below => 0.10, :between => [0.45, 0.55]},
    :swamp      => {:above => 0.80, :below => 0.20, :between => [0.40, 0.60]},
    :grassland  => {:above => 0.65,                                         },
    :forest     => {                :below => 0.40,                         },
    :rainforest => {:above => 0.85,                 :between => [0.45, 0.60]},
    :taiga      => {                                :between => [0.55, 0.65]},
    :tundra     => {                :below => 0.10,                         },
  }
  COLORS = {
    :dirt  => {
      :desert     => ChunkyPNG::Color.from_hex('#9c7e3d'),
      :forest     => ChunkyPNG::Color.from_hex('#49443e'),
      :grassland  => ChunkyPNG::Color.from_hex('#5e5a4d'),
      :jungle     => ChunkyPNG::Color.from_hex('#624f2f'),
      :rainforest => ChunkyPNG::Color.from_hex('#463d37'),
      :savanna    => ChunkyPNG::Color.from_hex('#9d8046'),
      :swamp      => ChunkyPNG::Color.from_hex('#555223'),
      :taiga      => ChunkyPNG::Color.from_hex('#5c4f40'),
      :tundra     => ChunkyPNG::Color.from_hex('#6e695c'),
    },
    :water => {
      :desert     => ChunkyPNG::Color.from_hex('#606249'),
      :forest     => ChunkyPNG::Color.from_hex('#284955'),
      :grassland  => ChunkyPNG::Color.from_hex('#365d65'),
      :jungle     => ChunkyPNG::Color.from_hex('#404c47'),
      :rainforest => ChunkyPNG::Color.from_hex('#1e3f50'),
      :savanna    => ChunkyPNG::Color.from_hex('#596266'),
      :swamp      => ChunkyPNG::Color.from_hex('#2d4636'),
      :taiga      => ChunkyPNG::Color.from_hex('#4e7280'),
      :tundra     => ChunkyPNG::Color.from_hex('#526b72'),
    },
  }

  def initialize(options)
    @options = options
    @seed    = options[:seed] || rand(1000000)
    @random  = Random.new(@seed)
    @output  = File.expand_path(File.join(File.dirname(__FILE__), '..', 'output'))
  end

  def generate
    @size   = SIZES[@options[:size] || @random.rand(SIZES.size)]
    @octave = OCTAVES[@size].sample(random: @random)
    @type   = @options[:type] || TYPES.sample(random: @random)

    debug "Generating a #{@size}x#{@size} #{@type} terrain using #{@octave} octaves and #{@seed} seed."

    persistence = FractalNoise::PerlinNoise.new(@size, @size, @random)
    persistence.generate(@octave, 0.6)
    persistence.normalize
    persistence.gamma_filter(1.2)
    persistence.median_filter(2)
    persistence.range(0.3, 0.9)

    @noise = FractalNoise::PerlinNoise.new(@size, @size, @random)
    @noise.generate(@octave, persistence.fractal)
    @noise.normalize
    @noise.gamma_filter(1.2)
    @noise.median_filter(2)
    @noise.normalize

    @terrain = @noise.array { :dirt }

    @noise.xy do |x, y|
      @terrain[x][y] = :water if WATER[@type][:between] && @noise.fractal[x][y] >= WATER[@type][:between].first && @noise.fractal[x][y] <= WATER[@type][:between].last
      @terrain[x][y] = :water if WATER[@type][:above]   && @noise.fractal[x][y] >= WATER[@type][:above]
      @terrain[x][y] = :water if WATER[@type][:below]   && @noise.fractal[x][y] <= WATER[@type][:below]
    end
  end

  def output
    @noise.output_xy("#{@output}/#{@type}-#{@seed}-#{@size}.png") do |x,y|
      hue,sat,light = ChunkyPNG::Color.to_hsl(COLORS[@terrain[x][y]][@type])
      value   = @noise.fractal[x][y]
      terrain = @terrain[x][y]
      water   = WATER[@type]

      # water
      if terrain == :water
        if water[:below] && value <= water[:below]
          light -= (water[:below] - value)/8.0
        elsif water[:above] && value >= water[:above]
          light -= (value - water[:above])/8.0
        else
          mid = water[:between].first + (water[:between].last - water[:between].first)/2.0

          if value < mid
            light -= (value - water[:between].first)/8.0
          else
            light -= (water[:between].last - value)/8.0
          end
        end

      # dirt
      else
        if water[:between]
          
          # lower
          if value < water[:between].first

            # use mid
            if water[:below]
              low  = water[:below]
              high = water[:between].first 
              mid  = low + (high - low)/2.0

              if value < mid
                light += (value - low)/5.0
              else
                light += (high - value)/5.0
              end

            # no mid
            else
              light += (water[:between].first - value)/5.0
            end
          
          # upper
          else
            
            # use mid
            if water[:above]
              low  = water[:between].last
              high = water[:above] || 1.0
              mid  = low + (high - low)/2.0

              if value < mid
                light += (value - low)/5.0
              else
                light += (high - value)/5.0
              end

            # no mid
            else
              light += (value - water[:between].last)/5.0
            end
          end
        else
          
          # use mid point
          if water[:below] && water[:above]
            low  = water[:below] || 0.0
            high = water[:above] || 1.0
            mid  = low + (high - low)/2.0

            if value < mid
              light += (value - low)/5.0
            else
              light += (high - value)/5.0
            end

          # low to high
          elsif water[:below]
            light += (value - water[:below])/5.0

          # high to low
          else
            light += (water[:above] - value)/5.0

          end
        end
      end 

      ChunkyPNG::Color.from_hsl(hue, sat, light)
    end
  end

  private

  def debug(msg)
    $stderr.puts msg if @options[:verbose]
  end

end
