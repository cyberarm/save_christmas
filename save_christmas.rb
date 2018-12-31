GameObject = Struct.new(:sprite, :x, :y, :z, :x_velocity, :y_velocity, :jumping)

def init
  @player = GameObject.new(20, 0, 1, 0, 0, 0, false)
  @current_level = 0

  @collisions = []

  @viewport_x, @viewport_y = 0, 0
  @debug = false

  @last_change = milliseconds
  @change_interval = 150
  @swapped = false
end

def draw
  translate(@viewport_x, @viewport_y) do
    level(@current_level)
    sprite(@player.sprite, @player.x, @player.y, @player.z)

    debug_draw
  end

  text(fps.to_s)
end

def update
  input_handler

  @player.x+=@player.x_velocity
  @player.y+=@player.y_velocity

  @viewport_x = width/2 - @player.x

  if @player.y < height/4
    @viewport_y = height/4 - @player.y
  elsif @player.y > height
    @viewport_y = height/4 - @player.y
  else
    @viewport_y = 0
  end

  if milliseconds > @last_change + @change_interval
    @last_change = milliseconds
    @swapped = !@swapped

    swap(@current_level, 6, 15) unless @swapped
    swap(@current_level, 15, 6) if @swapped
  end

  collision_handler

  if @player.y > height+16
    @player.y = 0
    @player.y_velocity = 0
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

      @player.x = (sprite.x - ((my_box.x + 1) + my_box.width)) if edges[:left]  && @player.y + my_box.y + my_box.height > sprite.y + 6
      @player.x = (sprite.x + (my_box.x +  1) + my_box.width)  if edges[:right] && @player.y + my_box.y + my_box.height > sprite.y + 6
    end
  else
    @player.y_velocity += 0.10 if @player.y_velocity < 3.1
  end
end
