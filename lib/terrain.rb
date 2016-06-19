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
  ROCK = {
    :desert     => {:below => 0.20, :actual => 0.82 },
    :grassland  => {:below => 0.30, :actual => 0.81 },

    :tundra     => {:above => 0.80, :actual => 0.76 },
    :forest     => {:above => 0.70, :actual => 0.80 },

    :savanna    => {:above => 0.68, :actual => 0.86 },
    :taiga      => {:below => 0.40, :actual => 0.62 },

    :jungle     => {:above => 0.65, :actual => 0.86 },
    :rainforest => {:below => 0.30, :actual => 0.73 },

    :swamp      => {:actual => 2.00 }, # none
  }
  VEG = {
    :desert     => [0.50, 0.53],
    :grassland  => [0.51, 0.81],

    :tundra     => [0.58, 0.70],
    :forest     => [0.505, 0.75],

    :savanna    => [0.52, 0.75],
    :taiga      => [0.50, 0.62],

    :jungle     => [0.50, 0.86],
    :rainforest => [0.50, 0.73],
    :swamp      => [0.50, 1.0],
  }
  COLORS = {
    :dirt  => {
      :desert     => ChunkyPNG::Color.from_hex('#9c7e3d'),
      :forest     => ChunkyPNG::Color.from_hex('#38342e'),
      :grassland  => ChunkyPNG::Color.from_hex('#545145'),
      :jungle     => ChunkyPNG::Color.from_hex('#564629'),
      :rainforest => ChunkyPNG::Color.from_hex('#423934'),
      :savanna    => ChunkyPNG::Color.from_hex('#8d733f'),
      :swamp      => ChunkyPNG::Color.from_hex('#48461e'),
      :taiga      => ChunkyPNG::Color.from_hex('#5c4f40'),
      :tundra     => ChunkyPNG::Color.from_hex('#615d51'),
    },
    :water => {
      :desert     => ChunkyPNG::Color.from_hex('#6d6f52'),
      :forest     => ChunkyPNG::Color.from_hex('#213b45'),
      :grassland  => ChunkyPNG::Color.from_hex('#365d65'),
      :jungle     => ChunkyPNG::Color.from_hex('#404c47'),
      :rainforest => ChunkyPNG::Color.from_hex('#1e3f50'),
      :savanna    => ChunkyPNG::Color.from_hex('#596266'),
      :swamp      => ChunkyPNG::Color.from_hex('#2d4636'),
      :taiga      => ChunkyPNG::Color.from_hex('#3a545f'),
      :tundra     => ChunkyPNG::Color.from_hex('#526b72'),
    },
    :rock => {
      :desert     => ChunkyPNG::Color.from_hex('#8d7135'),
      :forest     => ChunkyPNG::Color.from_hex('#2f2e2d'),
      :grassland  => ChunkyPNG::Color.from_hex('#4b4944'),
      :jungle     => ChunkyPNG::Color.from_hex('#504430'),
      :rainforest => ChunkyPNG::Color.from_hex('#363230'),
      :savanna    => ChunkyPNG::Color.from_hex('#7e6b44'),
      :taiga      => ChunkyPNG::Color.from_hex('#43403d'),
      :tundra     => ChunkyPNG::Color.from_hex('#5c5a57'),
    },
    :veg => {
      :forest     => ChunkyPNG::Color.from_hex('#304b33d0'),
      :desert     => ChunkyPNG::Color.from_hex('#796f3ac5'),
      :grassland  => ChunkyPNG::Color.from_hex('#4f6145d0'),
      :jungle     => ChunkyPNG::Color.from_hex('#3f4424d0'),
      :rainforest => ChunkyPNG::Color.from_hex('#253e25d0'),
      :savanna    => ChunkyPNG::Color.from_hex('#6c6439d0'),
      :swamp      => ChunkyPNG::Color.from_hex('#343b14d0'),
      :taiga      => ChunkyPNG::Color.from_hex('#202e1fc0'),
      :tundra     => ChunkyPNG::Color.from_hex('#525747a0'),
    }
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

    @veg = FractalNoise::PerlinNoise.new(@size, @size, @random)
    @veg.generate(3, 0.6)
    @veg.normalize
    @veg.gamma_filter(1.2)
    @veg.median_filter(2)

    water = WATER[@type]
    rock  = ROCK[@type]
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

        dist(x, y, value, 0.0, rock[:below], 1.0, dp(water[:between].first - rock[:below]))
        dist(x, y, value, rock[:below], water[:between].first, dp(water[:between].first - rock[:below]), 0.5)
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
        dist(x, y, value, water[:between].last, rock[:above], 0.5, dp(rock[:above] - water[:between].last))  
        dist(x, y, value, rock[:above], 1.0, dp(rock[:above] - water[:between].last), 1.0)  

      elsif water[:above]
        dist(x, y, value, 0.0, rock[:below], 1.0, dp(water[:above] - rock[:below]))
        dist(x, y, value, rock[:below], water[:above], dp(water[:above] - rock[:below]), 0.5)
        dist(x, y, value, water[:above], 1.0, 0.5, wp(1.0 - water[:above]))

      elsif water[:below]
        dist(x, y, value, 0.0, water[:below], wp(water[:below]), 0.5)
        dist(x, y, value, water[:below], rock[:above], 0.5, dp(rock[:above] - water[:below]))
        dist(x, y, value, rock[:above], 1.0, dp(rock[:above] - water[:below]), 1.0)

      elsif water[:between]
        mid = water[:between].first + (water[:between].last - water[:between].first)/2.0

        if rock[:below]
          dist(x, y, value, 0.0, rock[:below], 1.0, dp(water[:between].first - rock[:below]))
          dist(x, y, value, rock[:below], water[:between].first, dp(water[:between].first - rock[:below]), 0.5)
        else
          dist(x, y, value, 0.0, water[:between].first, dp(water[:between].first), 0.5)
        end

        dist(x, y, value, water[:between].first, mid, 0.5, wp(water[:between].last - water[:between].first))
        dist(x, y, value, mid, water[:between].last, wp(water[:between].last - water[:between].first), 0.5) 

        if rock[:above]
          dist(x, y, value, water[:between].last, rock[:above], 0.5, dp(rock[:above] - water[:between].last)) 
          dist(x, y, value, rock[:above], 1.0, dp(rock[:above] - water[:between].last), 1.0) 
        else
          dist(x, y, value, water[:between].last, 1.0, 0.5, dp(1.0 - water[:between].last)) 
        end

      end
    end
  end

  def output
    @noise.output_xy("#{@output}/#{@type}-#{@seed}-#{@size}.png") do |x,y|
      value   = @noise.fractal[x][y]
      terrain = value <= 0.5 ? :water : value >= ROCK[@type][:actual] ? :rock : :dirt
      hue,sat,light = ChunkyPNG::Color.to_hsl(COLORS[terrain][@type])
      water   = WATER[@type]
      tsteps  = STEPS[@octave]
      step    = 0

      value = 0.999 if value == 1.0

      if terrain == :dirt || terrain == :rock
        step = ((value - 0.5)/0.5)*tsteps
        light += (@options[:continuous_color] ? step : step.to_i)*0.01
      elsif terrain == :water
        step = ((0.5-value)/0.5)*tsteps
        light -= (@options[:continuous_color] ? step : step.to_i)*0.01
      end

      if value <= VEG[@type].last && value >= VEG[@type].first
        h,s,l,a = ChunkyPNG::Color.to_hsl(COLORS[:veg][@type], true)
          
        fg = ChunkyPNG::Color.from_hsl(h, s, l-@veg.fractal[x][y]/10, (a - (value+0.5)*128).to_i)
        bg = ChunkyPNG::Color.from_hsl(hue, sat, light)

        ChunkyPNG::Color.compose_quick(fg, bg)
      else
        ChunkyPNG::Color.from_hsl(hue, sat, light)
      end
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
