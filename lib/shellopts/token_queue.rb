
# TODO: Rename/move file
#
# FIXME: Wtf is this?
#
#        Notes
#         o +op+ relates to the line number
#
module ShellOpts
  class TokenQueue
    using Ext::Array::ShiftWhile

    attr_reader :elements

    def initialize(elements)
      @elements = elements.dup
    end

    forward_to :@elements, :empty?, :size, :shift, :unshift, :map, :each, :shift_while

    def head = elements.first
    def rest = elements[1..-1]

    # Yield current token to block as long as it satisfies the conditions given
    # by the arguments
    #
    # +kinds+ limits the kind of tokens. It can be a single kind, an array of
    # kinds, or the empty array (meaning all token kinds).  +lineno+ limits
    # tokens to be on the given line and +op+ and +charno+ limits the indentation
    # of the token: If op is >=, the token has to have same or higher indent,
    # if +op+ is ==, the token should have the given indent +kinds+ can be a
    # kind, an array of kinds, or the empty array
    def consume(kinds, lineno, op = :==, charno, &block)
      kinds = Array(kinds).flatten.compact

      constrain kinds, [Symbol]
      constrain lineno, Integer, nil
      constrain op, :==, :>=
      constrain charno, Integer, nil

      l = lambda { |t|
        (kinds.empty? || kinds.include?(t.kind)) \
        && t.lineno == (lineno || t.lineno) \
        && t.charno.send(op, charno || t.charno)
      }
      r = []
      if block_given?
        while self.head && l.call(self.head)
          r << yield(elements.shift)
        end
      else
        r = elements.shift_while(&l)
      end
      r
    end

    def dump(*methods)
      methods = Array(methods).flatten
      methods = [:kind] if methods.empty?
      puts "[" + map { |t| 
        if methods.size > 1
          "(" + methods.map { |m| t.send(m) }.join(", ") + ")"
        else
          t.send(methods.first)
        end
      }.join(", ") + "]"
    end
  end
end












