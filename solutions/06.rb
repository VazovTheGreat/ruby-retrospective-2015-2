module TurtleGraphics
  class Turtle
    DIRECTIONS = {
        'left': [0, -1],
        'right': [0, 1],
        'up': [-1, 0],
        'down': [1, 0]
    }
    DIRECTIONS_SEQUENCE = { 'left': 0, 'up': 1, 'right': 2, 'down': 3 }
    def initialize(rows, cols)
      @rows = rows
      @cols = cols
      @travel_matrix = Array.new(rows) { Array.new(cols) { |_| 0 } }
      @travel_matrix[0][0] = 1
      @location = [0, 0]
      @direction = :right
    end

    def draw(draw_function = nil, &block)
      instance_eval &block if block_given?
      if draw_function.nil?
        @travel_matrix
      else
        draw_function.draw @travel_matrix, max_steps_in_cell
      end
    end

    def max_steps_in_cell
      @travel_matrix.map do |row|
        row.max
      end.max
    end

    def spawn_at(row, col)
      # Should only be called after initialize
      @travel_matrix[@location[0]][@location[1]] = 0
      @location = [row, col]
      @travel_matrix[row][col] = 1
    end

    def move
      direction = DIRECTIONS[@direction]
      row = _translate(@location[0] + direction[0], @rows)
      col = _translate(@location[1] + direction[1], @cols)
      @location[0] = row
      @location[1] = col
      @travel_matrix[row][col] += 1
    end

    def _translate(current, total)
      if current >= total
        current = 0
      elsif current < 0
        current = total - 1
      end
      current
    end

    def look(orientation)
      @direction = orientation
    end

    def turn_left
      _turn(:left)
    end

    def turn_right
      _turn(:right)
    end

    def _turn(direction)
      if direction == :right
        step = 1
      elsif direction == :left
        step = -1
      end
      next_orientation = DIRECTIONS_SEQUENCE[@direction.to_sym] + step
      if next_orientation < 0
        next_orientation = DIRECTIONS_SEQUENCE.length - 1
      elsif next_orientation >= DIRECTIONS_SEQUENCE.length
        next_orientation = 0
      end
      @direction = DIRECTIONS_SEQUENCE.key(next_orientation)
    end
  end

  module Canvas
    class BaseDraw
      def get_intensity_ratio(cell, max_steps)
        cell == 0 ? 0 : cell / max_steps.to_f
      end
    end

    class ASCII < BaseDraw
      def initialize(intensity_array)
        @intensity_array = intensity_array
        intensity_period = 1 / (intensity_array.length.to_f - 1)
        @intensity_periods = [0]
        @intensity_array[1..-1].each_with_index do |_, index|
          @intensity_periods << intensity_period * (index + 1)
        end
      end

      def draw(travel_matrix, max_steps)
        travel_matrix.map do |row|
          row.map do |cell|
            get_cell_char cell, max_steps
          end.join
        end.join("\n")
      end

      def get_cell_char(cell, max_steps)
        intensity_ratio = get_intensity_ratio cell, max_steps
        index = get_intensity_index intensity_ratio
        @intensity_array[index]
      end

      def get_intensity_index(intensity_ratio)
        @intensity_periods.find_index { |period| intensity_ratio <= period }
      end
    end

    class HTML < BaseDraw
      def initialize(size)
        @size = size
        @table = ''
      end

      def html_template
        '<!DOCTYPE html><html><head><title>Turtle graphics</title>' +\
        '<style> table {border-spacing: 0;} tr {padding: 0;} ' +\
        "td {width: #{@size}px; height: #{@size}px; " +\
        'background-color: black; padding: 0; }' +\
        "</style></head><body><table>#{@table}</table></body></html>"
      end

      def draw(travel_matrix, max_steps)
        generate_table travel_matrix, max_steps
        html_template
      end

      def generate_table(travel_matrix, max_steps)
        @table = travel_matrix.map do |row|
          generate_tr row, max_steps
        end.join
      end

      def generate_tr(row, max_steps)
        table_row = row.map do |cell|
          generate_td cell, max_steps
        end.join
        "<tr>#{table_row}</tr>"
      end

      def generate_td(cell, max_steps)
        intensity = get_intensity_ratio cell, max_steps
        "<td style=\"opacity: #{format('%.2f', intensity)}\"></td>"
      end
    end
  end
end