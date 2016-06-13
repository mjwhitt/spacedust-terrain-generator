#!/usr/bin/env ruby
$:.push File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'fractal_noise', 'lib'))

require 'chunky_png'
require 'fractal_noise'

class Terrain

  TYPES   = [ :desert, :forest, :grassland, :jungle, :rainforest, :savanna, :swamp, :taiga, :tundra ]
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
  STEPS = { 
     4 =>  5.0,
     5 =>  5.0,
     6 =>  9.0,
     7 =>  9.0,
     8 => 15.0,
     9 => 15.0,
    10 => 15.0,
  }
  WATER = {
    :desert     => {:above => 0.90,                                         },
    :grassland  => {:above => 0.65,                                         },

    :tundra     => {                :below => 0.10,                         },
    :forest     => {                :below => 0.35,                         },

    :savanna    => {                                :between => [0.30, 0.40]},
    :taiga      => {                                :between => [0.60, 0.70]},

    :rainforest => {:above => 0.85,                 :between => [0.45, 0.60]},
    :jungle     => {                :below => 0.15, :between => [0.40, 0.55]},
    :swamp      => {:above => 0.80, :below => 0.20, :between => [0.40, 0.60]},
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
    @octave = @options[:octaves] || OCTAVES[@size].sample(random: @random)
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

    water = WATER[@type]
    @noise.xy do |x,y|
      value = @noise.fractal[x][y]

      if water[:above] && water[:below] && water[:between]
        mid1 = water[:below] + (water[:between].first - water[:below])/2.0
        mid2 = water[:between].first + (water[:between].last - water[:between].first)/2.0
        mid3 = water[:between].last + (water[:above] - water[:between].last)/2.0
        dist(x, y, value, 0.0, water[:below], wp(water[:below]), 0.5)
        dist(x, y, value, water[:below], mid1, 0.5, dp(water[:between].first - water[:below]))
        dist(x, y, value, mid1, water[:between].first, dp(water[:between].first - water[:below]), 0.5)
        dist(x, y, value, water[:between].first, mid2, 0.5, wp(water[:between].last - water[:between].first))
        dist(x, y, value, mid2, water[:between].last, wp(water[:between].last - water[:between].first), 0.5)
        dist(x, y, value, water[:between].last, mid3, 0.5, dp(water[:above] - water[:between].last))
        dist(x, y, value, mid3, water[:above], dp(water[:above] - water[:between].last), 0.5)
        dist(x, y, value, water[:above], 1.0, 0.5, wp(1.0 - water[:above]))
      
      elsif water[:above] && water[:below]
        mid = water[:below] + (water[:above] - water[:below])/2.0

        dist(x, y, value, 0.0, water[:below], wp(water[:below]), 0.5)
        dist(x, y, value, water[:below], mid, 0.5, dp(water[:above] - water[:below]))
        dist(x, y, value, mid, water[:above], dp(water[:above] - water[:below]), 0.5)
        dist(x, y, value, water[:above], 1.0, 0.5, wp(1.0 - water[:above]))

      elsif water[:above] && water[:between]
        mid1 = water[:between].first + (water[:between].last - water[:between].first)/2.0
        mid2 = water[:between].last + (water[:above] - water[:between].last)/2.0

        dist(x, y, value, 0.0, water[:between].first, dp(water[:between].first), 0.5)
        dist(x, y, value, water[:between].first, mid1, 0.5, wp(water[:between].last - water[:between].first))
        dist(x, y, value, mid1, water[:between].last, wp(water[:between].last - water[:between].first), 0.5) 
        dist(x, y, value, water[:between].last, mid2, 0.5, dp(water[:above] - water[:between].last)) 
        dist(x, y, value, mid2, water[:above], dp(water[:above] - water[:between].last), 0.5)
        dist(x, y, value, water[:above], 1.0, 0.5, wp(1.0 - water[:above]))

      elsif water[:below] && water[:between]
        mid1 = water[:below] + (water[:between].first - water[:below])/2.0
        mid2 = water[:between].first + (water[:between].last - water[:between].first)/2.0

        dist(x, y, value, 0.0, water[:below], wp(water[:below]), 0.5)
        dist(x, y, value, water[:below], mid1, 0.5, dp(water[:between].first - water[:below]))
        dist(x, y, value, mid1, water[:between].first, dp(water[:between].first - water[:below]), 0.5)
        dist(x, y, value, water[:between].first, mid2, 0.5, wp(water[:between].last - water[:between].first))
        dist(x, y, value, mid2, water[:between].last, wp(water[:between].last - water[:between].first), 0.5) 
        dist(x, y, value, water[:between].last, 1.0, 0.5, dp(1.0 - water[:between].last))  

      elsif water[:above]
        dist(x, y, value, 0.0, water[:above], dp(water[:above]), 0.5)
        dist(x, y, value, water[:above], 1.0, 0.5, wp(1.0 - water[:above]))

      elsif water[:below]
        dist(x, y, value, 0.0, water[:below], wp(water[:below]), 0.5)
        dist(x, y, value, water[:below], 1.0, 0.5, dp(1.0 - water[:below]))

      elsif water[:between]
        mid = water[:between].first + (water[:between].last - water[:between].first)/2.0

        dist(x, y, value, 0.0, water[:between].first, dp(water[:between].first), 0.5)
        dist(x, y, value, water[:between].first, mid, 0.5, wp(water[:between].last - water[:between].first))
        dist(x, y, value, mid, water[:between].last, wp(water[:between].last - water[:between].first), 0.5) 
        dist(x, y, value, water[:between].last, 1.0, 0.5, dp(1.0 - water[:between].last)) 
      end
    end
  end

  def output
    @noise.output_xy("#{@output}/#{@type}-#{@seed}-#{@size}.png") do |x,y|
      value   = @noise.fractal[x][y]
      terrain = value <= 0.5 ? :water : :dirt
      hue,sat,light = ChunkyPNG::Color.to_hsl(COLORS[terrain][@type])
      water   = WATER[@type]
      tsteps  = STEPS[@octave]
      step    = 0

      if terrain == :dirt
        step = ((value - 0.5)/0.5)*tsteps
        light += (@options[:continuous_color] ? step : step.to_i)*0.01
      elsif terrain == :water
        step = ((0.5-value)/0.5)*tsteps
        light -= (@options[:continuous_color] ? step : step.to_i)*0.01
      end

      ChunkyPNG::Color.from_hsl(hue, sat, light)
    end
  end

  def output_grayscale
    @noise.grayscale("#{@output}/#{@type}-#{@seed}-#{@size}-gray.png")
  end

  private

  def dist(x, y, ovalue, omin, omax, nmin, nmax)
    return unless ovalue >= omin && ovalue <= omax
    @noise.fractal[x][y] = (((ovalue - omin) * (nmax - nmin)) / (omax - omin)) + nmin
  end

  def wp(percent)
    0.5 - percent*0.5
  end

  def dp(percent)
    0.5 + percent*0.5
  end

  def debug(msg)
    $stderr.puts msg if @options[:verbose]
  end

end
