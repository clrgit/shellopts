
# TODO: Rename/move file
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

    def consume(kinds, lineno, op = :==, charno, &block)
      kinds = Array(kinds).flatten

      constrain kinds, [Symbol]
      constrain lineno, Integer, nil
      constrain op, :==, :>=
      constrain charno, Integer, nil

      l = lambda { |t|
        kinds.include?(t.kind) && 
        t.lineno == (lineno || t.lineno) && 
        t.charno.send(op, charno || t.charno)
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












