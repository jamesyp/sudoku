module Sudoku

  class Puzzle
  	# These constants are used for translating between the external
  	# string representation of a puzzle and the internal representation.
  	ASCII = ".123456789"
  	BIN = "\000\001\002\003\004\005\006\007\010\011"

  	def initialize(lines)
  	  if (lines.respond_to? :join)
  	  	s = lines.join
  	  else
  	  	s = lines.dup
  	  end

  	  # Remove whitespace from the data.
  	  s.gsub!(/\s/, "")

  	  # Raise an exception if the input is the wrong size
  	  raise Invalid, "Grid is the wrong size" unless s.size == 81

  	  # Check for invalid characters, and save the location of the first.
  	  # Note that the value is assigned and tested at the same time
  	  if i = s.index(/[^123456789\.]/)
  	  	# Include the invalid character in the message
  	  	raise Invalid, "Illegal character #{s[i, 1]} in puzzle"
  	  end

  	  # The following two lines convert the input string of ASCII
  	  # to an array of integers. 0 represents an unknown value.
  	  s.tr!(ASCII, BIN)  # Translate ASCII to bytes
  	  @grid = s.unpack('c*')	# Now unpack the bytes into an array of integers

  	  # Make sure rows, columns, and boxes have no duplicates
  	  raise Invalid, "Initial puzzle has duplicates" if has_duplicates?
  	end

  	# Return the state of the puzzle as a string of 9 lines
  	# with 9 characters (plus newline) each.
  	def to_s
  	  (0..8).collect{ |r| @grid[r*9, 9].pack('c9') }.join("\n").tr(BIN, ASCII)
  	end

  	def dup
  	  copy = super		# Make a shallow copy by calling Object.dup
  	  @grid = @grid.dup # Make a new copy of the internal data
  	  copy				# Return the copied object
    end

    def [](row, col)
      # Convert 2D (row, col) coordinates into 1D array index
      @grid[row * 9 + col]
    end

    def []=(row, col, newvalue)
      # Raise an exception unless the newvalue is in the range 0 to 9
      unless (0..9).include? newvalue
        raise Invalid, "Illegal cell value"
      end
      # Set the appropriate element of the interal array to newvalue
      @grid[row * 9 + col] = newvalue
    end

    BoxOfIndex = [
      0,0,0,1,1,1,2,2,2,0,0,0,1,1,1,2,2,2,0,0,0,1,1,1,2,2,2,
        3,3,3,4,4,4,5,5,5,3,3,3,4,4,4,5,5,5,3,3,3,4,4,4,5,5,5,
        6,6,6,7,7,7,8,8,8,6,6,6,7,7,7,8,8,8,6,6,6,7,7,7,8,8,8
    ].freeze

    def each_unknown
      0.upto 8 do |row|
        0.upto 8 do |col|
          index = row * 9 + col 	# cell index for (row,col)
          next if @grid[index] != 0 # Move on if we know this cell's value
          box = BoxOfIndex[index]	# Get the box for this cell
          yield row, col, box
        end
      end
    end

    def has_duplicates?
      # uniq! returns nil if all the elements of an array are unique.
      # So if uniq! returns something then the board has duplicates.
      0.upto(8) { |row| return true if rowdigits(row).uniq! }
      0.upto(8) { |col| return true if coldigits(col).uniq! }
      0.upto(8) { |box| return true if boxdigits(box).uniq! }
    
      false		# if all tests pass, then there are no duplicates
    end

    # This array holds a set of all Sudoku digits. It's used below.
    AllDigits = [1,2,3,4,5,6,7,8,9].freeze

    def possible(row, col, box)
      AllDigits - (rowdigits(row) + coldigits(col) + boxdigits(box))
    end

    private

    # Return an array of all known values in the row.
    def rowdigits(row)
      # Extract the subarray that represents the row and remove all zeros.
      # Array subtraction is set difference and removes all occurences.
      @grid[row * 9, 9] - [0]
    end

    # Return an array of all known values in the column.
    def coldigits(col)
      result = []
      col.step(80, 9) do |i|	# Loop from col by nines up to 80
        v = @grid[i]			# get value of cell at that index
        result << v if v != 0 	
      end
      result
    end

    # Map box number to the index of the upper-left cell of that box
    BoxToIndex = [0, 3, 6, 27, 30, 33, 54, 57, 60].freeze

    # Return an array of all known values in the specified box.
    def boxdigits(box)
      # Convert box number to index of upper-left cell of the box
      i = BoxToIndex[box]

      # Return an array of values with zeroes removed
      [
	  	@grid[i],	 @grid[i+1],  @grid[i+2],
	  	@grid[i+9],  @grid[i+10], @grid[i+11],
	  	@grid[i+18], @grid[i+19], @grid[i+20]
      ] - [0]
    end
  end		# end of Puzzle class

  class Invalid < StandardError
  end

  class Impossible < StandardError
  end

  def Sudoku.scan(puzzle)
  	unchanged = false	# This is our loop variable

  	# Loop until we've scanned the whole board without making a change.
  	until unchanged
  	  unchanged = true		# Assume no cells will be changed
  	  rmin,cmin,pmin = nil 	# Track cell with minimum possible set
  	  min = 10				# More than the maximal number of possibilities

  	  # Loop through cells whose value is unknown
  	  puzzle.each_unknown do |row, col, box|
  	  	# Find the set of values that could go in this cell
  	  	p = puzzle.possible(row, col, box)

  	  	# Branch based on the size of the set p
  	  	# We care about 3 cases: p.size == 0, p.size == 1 and p.size > 1.
  	  	case p.size
  	  	when 0 	# No solution exists
  	  	  raise Impossible
  	  	when 1 	# We've found a unique value, so set it in the grid
  	  	  puzzle[row,col] = p[0]
          unchanged = false
  	  	else
  	  	  # Keep track of the smallest set of possibilities
  	  	  # But don't bother if we're going to repeat this loop.
  	  	  if unchanged && p.size < min
  	  	  	min = p.size					# Current smallest size
  	  	  	rmin, cmin, pmin = row, col, p
  	  	  end
  	  	end
  	  end
  	end

  	# Return the cell with the minimal set of possibilities
  	# Note multiple return values
  	return rmin, cmin, pmin
  end

  def Sudoku.solve(puzzle)
  	# Make a private copy of the puzzle that we can modify
  	puzzle = puzzle.dup

  	r,c,p = scan(puzzle)

  	# If we solved it with logic, return the solved puzzle
  	return puzzle if r == nil

    # Otherwise, make guesses and branch
    p.each do |guess|
      puzzle[r,c] = guess

      begin
      	return solve(puzzle)	# If it returns, our puzzle is solved      	
      rescue Impossible
      	next
      end

      # If we get here, none of the guesses worked out
      # so we must have guessed wrong at some earlier point.
      raise Impossible
    end
  end

end
