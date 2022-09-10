
module Ext
  module Array
    module ShiftWhile
      refine ::Array do
        # The algorithm ensures that the block sees the array as if the current
        # element has already been removed
        def shift_while(&block)
          r = []
          while value = self.shift
            if !block.call(value)
              self.unshift value
              break
            else
              r << value
            end
          end
          r
        end
      end
    end

    module PopWhile
      refine ::Array do
        # The algorithm ensures that the block sees the array as if the current
        # element has already been removed
        def pop_while(&block)
          r = []
          while value = self.pop
            if !block.call(value)
              self.push value
              break
            else
              r << value
            end
          end
          r
        end
      end
    end

    module Wrap
      refine ::Array do
        # Concatenate array of words into lines that are at most +width+
        # characters wide. +curr+ is the initial number of characters already
        # used on the first line
        def wrap(width, curr = 0)
          lines = [[]]
          curr -= 1 # Simplifies conditions below
          each { |word|
            if curr + 1 + word.size <= width
              lines.last << word
              curr += 1 + word.size
            else
              lines << [word]
              curr = word.size
            end
          }
          lines.map! { |words| words.join(" ") }
        end
      end
    end
  end
end
