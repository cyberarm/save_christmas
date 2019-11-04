GameObject = Struct.new(:sprite, :x, :y, :z, :x_velocity, :y_velocity, :jumping, :speed)
GRAVITY = 9.8
class ParticleEmitter
  def initialize(context:, sprites:, max_particles: 512, initial_velocity: 3, angle: 90, jitter: 20, per_interval:, interval:, time_to_live:)
    @context = context
    @sprites = sprites
    @max_particles = max_particles
    @initial_velocity = initial_velocity
    @angle = angle
    @jitter = jitter
    @per_interval = per_interval
    @interval = interval
    @time_to_live = time_to_live

    @last_interval = @context.milliseconds

    @particles = []

    @x_positions = []
    @current_x_position = 0
    100.times { @x_positions << rand(0..@context.width+(@context.width/2)) }
  end

  def draw
    @particles.each {|s| @context.sprite(s.sprite, s.x, s.y)}
  end

  def update(dt)
    if @particles.size <= @max_particles && @context.milliseconds > @last_interval + @interval
      @last_interval = @context.milliseconds
      @per_interval.times { spawn_particle }
    end

    @particles.each do |particle|
      next unless particle

      particle.x -= particle.x_velocity * dt
      particle.y -= particle.y_velocity * dt

      @particles.delete(particle) if @context.milliseconds > @time_to_live + particle.jumping
    end
  end

  def spawn_particle
    x_vel = @initial_velocity * Math.cos((90 + rand(@angle - @jitter/2..@angle + @jitter/2)) * Math::PI / 180)
    y_vel = @initial_velocity * Math.sin((90 + rand(@angle - @jitter/2..@angle + @jitter/2)) * Math::PI / 180)

    @particles << GameObject.new(@sprites.sample, pick_position, -32, 0, x_vel, y_vel, @context.milliseconds)
  end

  def pick_position
    @current_x_position += 1
    @current_x_position = 0 unless @current_x_position < @x_positions.size

    @x_positions[@current_x_position]
  end

  def reset
    @particles.clear
    @last_interval = @context.milliseconds
  end
end


def init
  @snow_emitter = ParticleEmitter.new(context: self, max_particles: 12, sprites: [7, 16], angle: 200, initial_velocity: 55.0, per_interval: 1, interval: 750, time_to_live: 3_500)

  @player = GameObject.new(20, 0, 1, 0, 0, 0, false, 8)
  @lives  = 3
  @ready  = false

  @current_level = 0
  @claimed_present = 255

  @fire_sprites    = [6, 15]
  @present_sprites = [19]

  @collisions = []

  @viewport_x, @viewport_y = 0, 0
  @debug = false

  @last_change = milliseconds
  @change_interval = 150
  @swapped = false

  @last_frame_time = milliseconds

  reset
  transition
end

def reset
  @snow_emitter.reset

  @player.jumping = false
  @collisions = []
  @collected_presents = 0

  @player.x = 0
  @player.y = 1
  @player.x_velocity = 0
  @player.y_velocity = 0

  position_viewport
end

def reset_level(level)
  level.each do |sprite|
    if sprite.sprite == @claimed_present
      sprite.sprite = @present_sprites.sample
    end
  end
end

def reset_game
  i = 0
  while(level = levels[i])
    reset_level(level)
    i+=1
  end

  @current_level = 0
  @lives = 3

  @game_complete, @game_over = false, false
  @ready = false

  reset
  transition

  @last_frame_time = milliseconds
end

def draw
  rect(0, 0, width, height, black)

  unless @ready
    rect(0, 0, width, height, light_gray)
    text("Save Christmas", 15, height/2 - 32, 14, 0, black)
    text("Press Y[C] to start", 24, height/2 + 32, 8, 0, black)

    @ready_x ||= 16
    sprite(@player.sprite, @ready_x, height/2 - 8)
    sprite(@present_sprites.first, width/2 - 8, height/2 - 8)

    last = @ready_x
    @ready_x += 0.55
    @ready_x  = last if @ready_x >= width/2 - (18)
    return
  end

  translate(@viewport_x, @viewport_y) do
    level(@current_level)
    sprite(@player.sprite, @player.x, @player.y, @player.z)

    debug_draw
  end

  @snow_emitter.draw

  if @transitioning || @game_complete || @game_over
    rect(0, 0, width, height, black)
    if @transitioning
      text("LEVEL #{@current_level+1}", 10, height/2-8, 16)
      text("Lives #{@lives}", 10, height/2+10, 8)
    end

    if @game_complete
      text("Game Complete!", 10, height/2-8, 14)
      @game_completed_in ||= (milliseconds-@game_start_time)/1000
      text("Took #{@game_completed_in} seconds", 4, height/2+12, 8)
    end

    if @game_over
      text("Game Over!", 10, height/2-8, 14, 0, red)
    end
  end

  text("#{fps} fps - Level #{@current_level+1} of #{levels.size}")
end

def update
  unless @ready
    if button?("y")
      @game_start_time = milliseconds
      @ready = true

      @last_frame_time = milliseconds
    end
    return
  end

  if @transitioning
    @transitioning = false if milliseconds >= @transition_started + @transition_time

    @last_frame_time = milliseconds
    return
  end

  if @game_complete || @game_over
    if button?("x")
      reset_game

      @last_frame_time = milliseconds
    end
    return
  end

  @snow_emitter.update(dt)

  input_handler

  @player.x += @player.x_velocity
  @player.y -= @player.y_velocity
  @player.x_velocity *= 0.9

  @player.y_velocity -= GRAVITY * dt
  @player.y_velocity = GRAVITY if @player.y_velocity > GRAVITY
  @player.y_velocity = -GRAVITY if @player.y_velocity < -GRAVITY

  position_viewport

  if milliseconds > @last_change + @change_interval
    @last_change = milliseconds
    @swapped = !@swapped

    swap(@current_level, 6, 15) unless @swapped
    swap(@current_level, 15, 6) if @swapped
  end

  collision_handler

  # Player has fallen below level
  if @player.y > height+16
    lose_life!
  end

  if collected_all_presents?
    if levels[@current_level+1]
      @current_level+=1
      reset
      transition
    else
      game_complete
    end
  end

  @last_frame_time = milliseconds
end

def transition
  @transitioning = true
  @transition_started = milliseconds
  @transition_time = 1_500
end

def game_complete
  @game_complete = true
end

def position_viewport
  @viewport_x = width/2 - @player.x

  if @player.y < height/4
    @viewport_y = height/4 - @player.y
  elsif @player.y > height
    @viewport_y = height/4 - @player.y
  else
    @viewport_y = 0
  end
end

def debug_draw
  if @debug
    draw_level_boxes(@current_level)
    draw_sprite_box(@player.sprite, @player.x, @player.y)

    @collisions.each do |sprite|
      edges = colliding_edge(@player.sprite, @player.x, @player.y, sprite.sprite, sprite.x, sprite.y)
      render_bounding_box(
        sprite.sprite, @collision_detection.box(sprite.sprite), sprite.x, sprite.y, edges
      )
    end
  end
end

def input_handler
  @player.x_velocity += @player.speed * dt if button?("right")
  @player.x_velocity -= @player.speed * dt if button?("left")

  if (button?("x") || button?("up")) && !@player.jumping
    @player.y_velocity = 3.0
    @player.jumping = true unless @player.jumping
  end

  if button?("x") && button?("y")
    @debug = !@debug
  end
end


def collision_handler
  @collisions = sprite_vs_level(@player.sprite, @player.x, @player.y, @current_level)

  detect_murderous_collisions
  detect_presents

  @collisions = sprite_vs_level(@player.sprite, @player.x, @player.y, @current_level)
  @collisions.delete_if {|s| s.z != @player.z}

  if @collisions.size > 0
    my_box = bounding_box(@player.sprite)
    @collisions.each do |sprite|
      edges = colliding_edge(@player.sprite, @player.x, @player.y, sprite.sprite, sprite.x, sprite.y)
      box = bounding_box(sprite.sprite)

      if edges[:top]
        @player.y = sprite.y - (my_box.height + my_box.y)
        @player.jumping = false
        @player.y_velocity = 0
      end

      if edges[:bottom]
        @player.y = sprite.y + box.y + box.height + 1
        @player.y_velocity = 0
      end

      @player.x = (sprite.x - ((my_box.x) + my_box.width)) if edges[:left]  && @player.y + my_box.y + my_box.height > sprite.y + 6
      @player.x = (sprite.x + (my_box.x)  + my_box.width)  if edges[:right] && @player.y + my_box.y + my_box.height > sprite.y + 6
    end
  end
end

def detect_murderous_collisions
  @collisions.each do |sprite|
    if is_fire?(sprite)
      lose_life!
    end
  end
end

def is_fire?(sprite, harzard_layer = 1)
  @fire_sprites.detect {|i| i == sprite.sprite && sprite.z == harzard_layer}
end

def detect_presents
  @collisions.each do |sprite|
    if is_present?(sprite)
      @collected_presents += 1
      sprite.sprite = @claimed_present
    end
  end
end

def is_present?(sprite)
  @present_sprites.detect {|s| s == sprite.sprite}
end


def collected_all_presents?
  presents_pending = 0
  levels[@current_level].each do |sprite|
    if is_present?(sprite)
      presents_pending+=1
    end
  end

  presents_pending == 0
end

def lose_life!
  @lives-=1

  if @lives <= 0
    die!
  else

    reset_level(levels[@current_level])
    reset
    transition
  end
end

def die!
  @game_over = true
end

def dt
  (milliseconds - @last_frame_time) / 1000.0
end
