require 'gosu'
require 'chipmunk'

FOREGROUND = 5

class Engine < Gosu::Window
  attr_reader :space, :screen_width, :screen_height, :static_body, :actors

  def initialize
    @screen_width, @screen_height = 940, 780
    super @screen_width, @screen_height, false

    @space = CP::Space.new 
    @space.damping = 1.00
    @space.gravity = CP::Vec2.new(0, 115)
    @space.iterations = 2
    @space.elastic_iterations = 0

    @static_body = CP::Body.new_static

    @actors = []
  end

  def update
    @space.step 1.0 / 60.0
  end

  def draw
    @actors.each &:draw    
  end

  def button_down(id)
    case id
    when 53
      exit
    else
      puts id
    end
  end

  def create_actor(res, options)
    @actors << Actor.new(self, res, options)
  end

  def resource(type, name)
    path = File.expand_path("../res/#{type}/#{name}", __FILE__)
    Gosu::Image.new(self, path, false)
  end
  alias_method :r, :resource
end

class Actor
  def initialize(window, resource, options = {})
    @window = window
    @resource = resource
    @body = CP::Body.new(0.0001, 0.0001)
    if options[:radius]
      @shape = CP::Shape::Circle.new @body, options[:radius], CP::Vec2.new(0.0, 0.0)
    end
    if @shape
      x = options.fetch(:x, 0.0)
      y = options.fetch(:y, 0.0)
      @shape.e = options.fetch(:elasticity, 0.75)
      @shape.u = options.fetch(:friction, 1)

      vx = options.fetch(:vel_x, 0.0)
      vy = options.fetch(:vel_y, 0.0)

      @shape.body.m = options.fetch(:mass, 10.0)
      @shape.body.p = CP::Vec2.new(x, y) # position
      @shape.body.v = CP::Vec2.new(vx, vy) # velocity
      @shape.body.a = (3*Math::PI/2.0)

      if options[:static]
        window.space.add_static_shape @shape
      else
        window.space.add_body @body
        window.space.add_shape @shape
      end
    end
  end

  def draw
    c = Gosu::Color::WHITE
    @resource.draw(@shape.body.p.x, @shape.body.p.y, FOREGROUND)
    # @resource.draw_row(@shape.body.p.x, @shape.body.p.y, FOREGROUND, @shape.body.a.radians_to_gosu)
  end
end

class StaticActor
  def initialize(window)
    @window = window
    window.space.add_shape @shape if @shape
  end

  def draw
    raise "Not implemeneted"
  end
end

class Peg < StaticActor
  def initialize(window, x, y, radius)
    @x, @y, @r = x, y, radius
    @shape = CP::Shape::Circle.new(window.static_body, radius, CP::Vec2.new(x, y))
    super window
  end

  def draw
    c = Gosu::Color::WHITE
    @window.draw_quad(
      @x - @r, @y - @r, c,
      @x - @r, @y + @r, c,
      @x + @r, @y - @r, c,
      @x + @r, @y + @r, c
    )         
  end
end

class Wall < StaticActor
  def initialize(window, x1, y1, x2, y2, w = 3)
    @x1, @y1, @x2, @y2 = x1, y1, x2, y2
    @w = w
    @window = window
    @shape = CP::Shape::Segment.new(window.static_body, CP::Vec2.new(x1, y1), CP::Vec2.new(x2, y2), w)
    @shape.e = 0.9
    @shape.u = 1    
    super window
  end

  def draw
    c = Gosu::Color::WHITE
    @window.draw_quad(
      @x1 - @w, @y1 - @w, c,
      @x1 + @w, @y1 + @w, c,
      @x2 - @w, @y2 - @w, c,
      @x2 + @w, @y2 + @w, c
    )     
  end
end

class Flipper
  def initialize(window, x, y, direction)
    @window = window
    @x, @y = x, y

    peg = CP::Shape::Circle.new(window.static_body, 10, CP::Vec2.new(x, y))

    @flipper_body = CP::Body.new(0.0001, 0.0001)
    paddle = CP::Shape::Segment.new(@flipper_body, CP::Vec2.new(x, y), CP::Vec2.new(x + 100, y), 10)
    paddle.e = 0.9
    paddle.u = 1

    window.space.add_shape peg
    window.space.add_shape paddle

    CP::Constraint::PinJoint.new(@flipper_body, window.static_body, CP::Vec2.new(0, 0), CP::Vec2.new(0, 0))
  end

  def draw
    c = Gosu::Color::WHITE
    @window.draw_quad(
      @x - 10, @y - 10, c,
      @x + 110, @y - 10, c,
      @x + 110, @y + 10, c,
      @x - 10, @y + 10, c
    )
  end
end

engine = Engine.new
10.times do
  x = engine.screen_width * rand * 0.2
  y = engine.screen_height * rand * 0.2
  vx = 0 # x - (engine.screen_width / 2)
  vy = 0 # y - (engine.screen_height / 2)
  engine.create_actor engine.r(:images, "twitter.png"), radius: 30, x: x, y: y, vel_x: x, vel_y: y
end

statics = [
  Wall.new(engine, 0, 0, engine.screen_width, 0),
  Wall.new(engine, 0, 0, 0, engine.screen_height),
  Wall.new(engine, engine.screen_width, 0, engine.screen_width, engine.screen_height),
  Wall.new(engine, 0, engine.screen_height * 0.8, engine.screen_width, engine.screen_height),

  Peg.new(engine, engine.screen_width / 2, engine.screen_height / 2, 10),
  Peg.new(engine, engine.screen_width / 1.5, engine.screen_height / 2.5, 20),
  Peg.new(engine, engine.screen_width / 2.5, engine.screen_height / 1.5, 30)
]

engine.actors.concat statics

engine.actors << Flipper.new(engine, 300, 300, :left)

engine.show