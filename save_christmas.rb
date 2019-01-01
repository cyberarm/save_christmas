GameObject = Struct.new(:sprite, :x, :y, :z, :x_velocity, :y_velocity, :jumping)

def init
  @player = GameObject.new(20, 0, 1, 0, 0, 0, false)
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

  reset
  transition
end

def reset
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
  while(level = @levels[i])
    reset_level(level)
    i+=1
  end

  @current_level = 0
  @lives = 3

  @game_complete, @game_over = false, false
  @ready = false

  reset
  transition
end

def draw
  rect(0, 0, width, height, black)

  unless @ready
    rect(0, 0, width, height, light_gray)
    text("Save Christmas", 15, height/2 - 32, 14, 0, black)
    text("Press \"Y[C]\" to start", 24, height/2 + 32, 8, 0, black)

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

  if @transitioning || @game_complete || @game_over
    rect(0, 0, width, height, black)
    if @transitioning
      text("LEVEL #{@current_level+1}", 10, height/2-8, 16)
      text("Lives #{@lives}", 10, height/2+10, 8)
    end
    if @game_complete
      text("Game Complete!", 10, height/2-8, 16)
      @game_completed_in ||= (milliseconds-@game_start_time)/1000
      text("Took #{@game_completed_in} seconds", 4, height/2+12, 16)
    end
    if @game_over
      text("Game Over!", 10, height/2-8, 16, 0, red)
    end
  end

  text("#{fps} - Level #{@current_level} of #{LevelEditor.instance.levels.size}")
end

def update
  unless @ready
    if button?("y")
      @game_start_time = milliseconds
      @ready = true
    end
    return
  end

  if @transitioning
    @transitioning = false if milliseconds >= @transition_started + @transition_time

    return
  end

  if @game_complete || @game_over
    if button?("x")
      reset_game
    end
    return
  end

  input_handler

  @player.x+=@player.x_velocity
  @player.y+=@player.y_velocity

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
    if @levels[@current_level+1]
      @current_level+=1
      reset
      transition
    else
      game_complete
    end
  end
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
  @player.x += 1 if button?("right")
  @player.x -= 1 if button?("left")

  if (button?("x") || button?("up")) && !@player.jumping
    @player.y_velocity = -2.5
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
  else
    @player.y_velocity += 0.10 if @player.y_velocity < 3.1
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
  @levels[@current_level].each do |sprite|
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

    reset_level(@levels[@current_level])
    reset
    transition
  end
end

def die!
  @game_over = true
end
