def init
  @x = 0
  @y = 1
  @z = 0
#  @x_vel = 0
  @y_vel = 0

  @sprite = 0

  @jumping = false

  @collisions = []

  @viewport_x, @viewport_y = 0, 0
  @debug = false
  @last_change = milliseconds
  @change_interval = 150

  @swapped = false
end

def draw
  translate(@viewport_x, @viewport_y) do
    level(0)
    sprite(@sprite, @x, @y, @z)

    draw_level_boxes(0) if @debug
    draw_sprite_box(@sprite, @x, @y) if @debug

    rect(16 * 4, 16 * 4, 16, 16, white)

    if @debug
      @collisions.each do |sprite|
        edges = colliding_edge(@sprite, @x, @y, sprite.sprite, sprite.x, sprite.y)
        render_bounding_box(
          sprite.sprite, @collision_detection.box(sprite.sprite), sprite.x, sprite.y, edges
        )
        # p edges
      end
    end
  end

  text(fps.to_s)
end

def update
 # @collision_detection.clear

  @x += 1 if button?("right")
  @x -= 1 if button?("left")

  #@y += 1 if button?("down")
  if (button?("x") || button?("up")) && !@jumping
    @y_vel = -2.5
    @jumping = true unless @jumping
  end

  @y+=@y_vel
  #@y_vel += 0.05 unless @y_vel >= 0

  if button?("x") && button?("y")
    @debug = !@debug
  end

  @viewport_x = width/2 - @x

  if @y < height/4
    @viewport_y = height/4 - @y
  elsif @y > height
    @viewport_y = height/4 - @y
  else
    @viewport_y = 0
  end

  if milliseconds > @last_change + @change_interval
    @last_change = milliseconds
    @swapped = !@swapped

    swap(0, 6, 15) unless @swapped
    swap(0, 15, 6) if @swapped
  end

  @collisions = sprite_vs_level(@sprite, @x, @y, 0)
  @collisions.delete_if {|s| s.z != @z}

  if @collisions.size > 0
    my_box = bounding_box(@sprite)
    @collisions.each do |sprite|
      edges = colliding_edge(@sprite, @x, @y, sprite.sprite, sprite.x, sprite.y)
      # puts "#{sprite.object_id} -> #{edges}"
      box = bounding_box(sprite.sprite)

      @y = sprite.y - (my_box.height + 1) if edges[:top]
      @jumping = false if edges[:top]
      @y = sprite.y + box.y + box. height + 1 if edges[:bottom]
      @y_vel = 0 if edges[:bottom]

      @x = (sprite.x + (my_box.x*3) + my_box.width) if edges[:right] && @y + my_box.y + my_box.height > sprite.y + 6
      @x = (sprite.x - ((my_box.x*2) + my_box.width)) if edges[:left] && @y + my_box.y + my_box.height > sprite.y + 6
    end
  else
    @y_vel += 0.10 if @y_vel < 3.1
  end

  if @y > height+16
    @y = 0
    @y_vel = 0
  end
end
