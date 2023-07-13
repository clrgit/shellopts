module Tree
  class Filter
    # Create a node filter. The filter is initialized by a select expression
    # that decides if the node should be given to the block (or submitted to
    # the enumerator) and a traverse expression that decides if the children
    # nodes should be traversed recursively
    #
    # The expressions can be a Proc, Symbol, or an array of classes. In
    # addition, the +select+ can also be true, and +traverse+ can be true,
    # false, or nil. True, false, and nil have special meanings:
    #
    #   when +select+ is
    #     true    Select always. This is the default
    #
    #   when +traverse+ is
    #     true    Traverse always. This is the default
    #     false   Traverse only if select didn't match. This effectively means
    #             stop-on-match
    #     nil     Expects +select+ to return a two-tuple of booleans. Can't be
    #             used when +select+ is true
    #
    # The filter method doesn't have to exist on all traversed nodes. The
    # condition is only true if the method is defined and returns true
    #
    # Filters should not have side-effects because they can be used in
    # enumerators that doesn't execute the filter unless the enumerator is
    # evaluated
    #
    def initialize(select_expr = true, traverse_expr = true, &block)
      constrain select_expr, Proc, Symbol, Class, [Class], true
      constrain traverse_expr, Proc, Symbol, Class, [Class], true, false, nil
      select = mk_lambda(select_expr)
      traverse = mk_lambda(traverse_expr)
      @matcher = 
          case select
            when Proc
              case traverse
                when Proc; lambda { |node| [select.call(node), traverse.call(node)] }
                when true; lambda { |node| [select.call(node), true] }
                when false; lambda { |node| r = select.call(node); [r, !r] }
                when nil; lambda { |node| select.call(node) }
              end
            when true
              case traverse
                when Proc; lambda { |node| [true, traverse.call(node)] }
                when true; lambda { |_| [true, true] }
                when false; lambda { |_| [true, false] } # effectively same as #children.each
                when nil; raise ArgumentError
              end
          end
    end

    # Match +node+ against the filter and return a [select, traverse] tuple of booleans
    def match(node) = @matcher.call(node)
    def match?(node) = !@matcher.call(node).nil? # Better

    # Create a proc if arg is a Symbol or an Array of classes. Pass through
    # Proc objects, true, false, and nil
    def mk_lambda(arg) = self.class.mk_lambda(arg)
    def self.mk_lambda(arg)
      case arg
        when Proc, true, false, nil
          arg
        when Symbol
          lambda { |node| node.respond_to?(arg) && node.send(arg) }
        when Class
          lambda { |node| node.is_a? arg }
        when Array
          arg.all? { |a| a.is_a? Class } or raise ArgumentError, "Array elements should be classes"
          lambda { |node| arg.any? { |a| node.is_a? a } }
      else
        raise ArgumentError
      end
    end

    def dump
      puts "Filter"
      indent {
        puts "class: #{@matcher.class}"
        if @matcher.is_a?(Array)
          puts "select: #{@matcher.first.inspect}"
          puts "tarverse: #{@matcher.last.inspect}"
        else
          puts "select: #{@matcher.inspect}"
        end
      }
    end
  end
end
