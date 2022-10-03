#!/usr/bin/env ruby

#require 'indented_io'

module Tree
  class Filter
    # Create a node filter. The filter is initialized by a select expression
    # that decides if the node should be given to the block (or submitted to
    # the enumerator) and a traverse expression that decides if the children
    # nodes should be traversed recursively
    #
    # The expressions can be a Proc, Symbol, or a Class. In addition, the
    # +select+ can also be true, and +traverse+ can be true, false, or nil.
    # True, false, and nil have special meanings:
    #
    #   when +select+ is
    #     true    Select always. This is the default
    #
    #   when +traverse+ is
    #     true    Traverse always. This is the default
    #     false   Traverse only if select didn't match
    #     nil     Expects +select+ to return a two-tuple of booleans. Can't be
    #             used when +select+ is true
    #
    def initialize(select_expr = true, traverse_expr = true, &block)
      constrain select_expr, Proc, true
      constrain traverse_expr, Proc, true, false, nil
      @matcher = 
          case select_expr
            when true
              case traverse_expr
                when proc; lambda { |node| [true, traverse_expr.call(node)] }
                when true; lambda { |_| [true, true] }
                when false; lambda { |_| [true, false] } # effectively same as #children.each
                when nil; raise argumenterror
              end
            when Proc
              case traverse_expr
                when proc; lambda { |node| [select_expr.call(node), traverse_expr.call(node)] }
                when true; lambda { |node| [select_expr.call(node), true] }
                when false; lambda { |node| select = select_expr.call(node); [select, !select] }
                when nil; lambda { |node| select_expr.call(node) }
              end
          end
    end

    # Match +node+ against the filter and return a [select, traverse] tuple of bools
    def match(node) = @matcher.call(node)

  protected
    def mk_lambda(arg)
      case arg
        when Proc
          arg
        when Symbol
          lambda { |node| node.send(arg) }
        when Array
          arg.all? { |a| a.is_a? Class } or raise ArgumentError, "Array elements should be classes"
          lambda { |node| arg.any? { |a| node.is_a? a } }
        when true, false
          lambda { |node| arg }
      else
        raise ArgumentError
      end
    end
  end

  class AbstractTree
    # Parent node
    attr_reader :parent

    # List of child nodes
    attr_reader :children

    # An abstract method that gives access to the user-defined node (derived
    # from Tree). It is used to make the algorithms work on both regular trees
    # and projected trees
    def node = abstract_method

    # Create a new node and attach it to the parent
    def initialize(parent)
      @parent = parent
      @children = []
      @parent.children << self if @parent
    end

    # True if the node doesn't contain any children
    def empty?() children.empty? end

    # The number of nodes in the tree. Note that this can be an expensive
    # operation since every node that to be visited
    def size() descendants.to_a.size end

    # Implementation of standard iterator
    def each(&block) = block_given? ? visit(&block) : preorder(this: true)

    # Implementation of standard map method
    def map(&block) = raise NotImplementedError

    # Create a Tree::Filter object. Can also take an existing filter as
    # argument in which case the filter will just be returned. This is for the
    # developers convenience
    def self.filter(*args, &block)
      if args.first.is_a?(Filter)
        args.size == 1 && !block_given? or raise ArgumentError
        args.first
      else
        Filter.new(*args, &block) 
      end
    end

    # Pre-order iteration of nodes. Return an enumerator of selected nodes
    def preorder(*filter, this: true, &block)
      filter = self.class.filter(*filter)
      block_given? ? do_visit(filter, this, &block) : do_preorder(filter, this)
    end

    # Post-order iteration of nodes. Return an enumerator of seleted nodes
    def postorder(*filter, this: true) = raise NotImplementedError

    # Enumerator of descendant nodes matching filter. Same as #preorder with
    # :this set to false
    def descendants(*filter) = preorder(filter, this: false)

    # Execute block on each selected node. The block takes a single node
    # argument if it is unary and a [parent, node] tuple if it is binary
    def visit(*filter, this: true, &block)
      block_given? or raise ArgumentErorr, "Block is required"
      filter = self.class.filter(*filter)
      case block.arity
        when 1; do_visit_unary(filter, this, &block)
        when 2; do_visit_binary(filter, this, &block)
      else
        raise ArgumentError, "Block should take one or two arguments"
      end
    end

    # +block+ takes a [value, child] tuple
    #
    # #transform is matematically a map function but we need to reserve the
    # 'map' name for the #map method, so it is named #transform instead
    def transform(*filter, this: true, initial: nil, &block)
      block_given? or raise ArgumentErorr, "Block is required"
      filter = self.class.filter(*filter)
      do_translate(filter, this, initial, &block)
    end

    # Creates a projection of the tree with only the nodes selected by
    # +select+. The #parent, #children in the projected tree refers to the
    # nodes in the new tree and not the old tree. The ProjectedTree#node method
    # can be used to access the original node
    def project(*filter, this: true) 
      transform(*filter, this: this) { |curr, node| ProjectedTree.new(curr, node) }
    end

    # +block+ takes a tuple of [node, child-values]
    def reduce = NotImplemetedError

    # Find first node that matches the filter and that returns truthy from the block
    def find(*filter, &block) = descendants(*filter).first(&block)

  protected
    def do_preorder(enum, filter, this)
      select, traverse = filter.match(node)
      enum << node if this && select
      children.each { |child| child.do_preorder(enum, filter, true) } if traverse || !this
    end

    def do_egdes(enum, filter, this, prev)
      select, traverse = filter.match(node)
      if this && select
        enum << [prev, node] if this && select
        prev = node
      end
      children.each { |child| child.do_preorder(enum, filter, true, prev) } if traverse || !this
    end

    def do_translate(filter, this, curr, &block)
      select, traverse = filter.match(node)
      curr = yield(curr, node) if this && select
      children.each { |child| child.do_translate(filter, true, curr, &block) } if traverse || !this
      curr
    end
  end

  class ProjectedTree < AbstractTree
    attr_reader :node

    def initialize(parent, node)
      super(parent)
      @node = node
    end

    def method_missing(method, *args, &block) = node.send(method, *args, &block)
  end

  class Tree < AbstractTree
    def node = self
  end
end




