#!/usr/bin/env ruby

#require 'indented_io'

# TODO
#   o map_reduce (currently it is something like #project + #aggregate/#accumulate
#   o next pointers for speed
#   o two-dimensional enumerators for speed
#   o remove filters from methods and use projected or filtered trees
#     instead - filters are for liniear access, projections for structured
#     access
#   o It is a problem that Forrest is not derived from the application
#     deriviation of Tree. This means that custom methods on Tree can't be used on
#     a forrest of those trees. ProjectedTree has a similar problem
#
#     An example of the problem is the #sig method in the rspec tests that has
#     a specialization for nodes in a forrest: There is no place to put this
#     specialization other than monkey-pacthing it into the global Forrest
#     class(!)
#
#     It doesn't seems to be solvable by deriviation or modules
#
#     A solution would be to separate iteration and algoritms (duh). It
#     requires a two-dimensional enumerator:
#
#       def some_algo(enum)
#         v = enum.node.value + enum.children.map(&value).sum
#         v = enum.value + enum.children.map(&value).sum
#       end
#
#     In the above code, 'enum' acts as self. The method could just as well be
#     implemented as a class method
#
#     Another solution would be to just accept the fact, that when using
#     ProjectedTrees we have to use an explicit enum in our algorithms:
#
#       def some_algo(node = self)
#         ...
#       end
#
#   o Application trees should be split into tree-nodes (with tree algoritms)
#     and data-nodes (with the data of the node)
#
  
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
    # Filters should not have side-effects because they can be used in
    # enumerators that doesn't execute the filter unless the enumerator is
    # evaluated
    #
    def initialize(select_expr = true, traverse_expr = true, &block)
      constrain select_expr, Proc, true
      constrain traverse_expr, Proc, true, false, nil
      @matcher = 
          case select_expr
            when true
              case traverse_expr
                when Proc; lambda { |node| [true, traverse_expr.call(node)] }
                when true; lambda { |_| [true, true] }
                when false; lambda { |_| [true, false] } # effectively same as #children.each
                when nil; raise ArgumentError
              end
            when Proc
              case traverse_expr
                when Proc; lambda { |node| [select_expr.call(node), traverse_expr.call(node)] }
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

  class SelectFilter < Filter
    def initialize(select_expr)
      @matcher = mk_lambda(select_expr)
    end

    def match(node) = @matcher.call(node)
  end

  class AbstractTree
    # Parent node
    attr_reader :parent

    # List of child nodes
    attr_reader :children

    # An abstract method that gives access to the user-defined node (derived
    # from Tree). It is used to make the algorithms work on both regular trees
    # and projected trees. It is not defined on forrest objects (but on the
    # contained trees)
    def node = abstract_method

    # Create a new node and attach it to the parent
    def initialize(parent)
      @parent = parent
      @children = []
      @parent.children << self if @parent
    end

    # True if the node doesn't contain any children
    def empty? = children.empty?

    # The number of nodes in the tree. Note that this can be an expensive
    # operation since every node that to be visited
    def size = descendants.to_a.size

    # Implementation of Enumerable#each
    def each(&block) = block_given? ? visit(&block) : preorder(this: true)

    # Implementation of Enumerable#map
    def map(&block) = preorder.map(&block)

    # Implementation of Enumerable#inject method
    def inject(default = nil, &block) = preorder.inject(default, &block)

    # Like #each but with filters
    def filter(*filter, this: true, &block) = raise NotImplementedError

    # Like #filter but block is called with a [previous-matching-node, node]
    # tuple. This can be used to build projected trees
    def pairs(*filter, this: true, &block) = raise NotImplementedError

    # Pre-order enumerator of selected nodes
    def preorder(*filter, this: true)
      filter = self.class.filter(*filter)
      Enumerator.new { |enum| do_preorder(enum, filter, this) }
    end

    # Post-order enumerator of selected nodes
    def postorder(*filter, this: true) = raise NotImplementedError

    # Enumerator of descendant nodes matching filter. Same as #preorder with
    # :this set to false
    def descendants(*filter) = preorder(filter, this: false)

    # Execute block on selected nodes and traverse children if block returns
    # truthy. The block may have side-effects
#   def traverse(select = true, this: true, &block)
#     filter = self.class.select_filter(select)
#     do_traverse(filter, this, &block)
#     preorder(select, block, this: this).each
#   end

    # Execute block on selected nodes. Effectively the same as
    # 'preorder(...).each(&block)' but faster as it doesn't create an
    # Enumerator
    def visit(*filter, this: true, &block)
      filter = self.class.filter(*filter)
      block_given? or raise ArgumentError, "Block is required"
      do_visit(filter, this, &block)
    end

    # Traverse the tree top-down while accumulating information in an accumulator
    # object. The block takes a [accumulator, node] tuple and is responsible
    # for adding itself to the accumulator. The return value from the block is
    # then used as the accumulator for the child nodes
    def accumulate(*filter, accumulator, this: true, &block)
      filter = self.class.filter(*filter)
      block_given? or raise ArgumentError, "Block is required"
      do_accumulate(filter, this, accumulator, &block)
      accumulator
    end

    # tree.filter(Term).map_reduce { |node, values| } # node can be nil
    # tree.filter(Term).map_reduce(scoped: true) { ... }
    #
    # Traverse the tree bottom-up while aggregating information
    def aggregate(*filter, this: true, &block)
      filter = self.class.filter(*filter)
      do_aggregate(filter, this, &block)
    end

    # Creates a projection of the tree with only the nodes selected by the
    # filter
    #
    # If :this is true, it returns a projected tree or nil if self doesn't
    # match. If :this is false, it returns a (possibly empty) forrest object
    #
    # TODO: Maybe the wrong name - compare to 'select/project' in relational
    # databases
    def project(*filter, this: true)
      filter = self.class.filter(*filter)
      select, traverse = filter.match(node)
      return nil if this && !select
      initial = this ? ProjectedTree.new(nil, self) : Forrest.new
      do_accumulate(filter, false, initial) { |parent, node|
        ProjectedTree.new(parent, node)
      }
      initial
    end

    # Find first node that matches the filter and that returns truthy from the block
    def find(*filter, &block) = descendants(*filter).first(&block)

    # Create a Tree::Filter object. Can also take an existing filter as
    # argument in which case the filter will just be returned. This is for the
    # developers convenience
    def self.filter(*args)
      if args.first.is_a?(Filter)
        args.size == 1 or raise ArgumentError
        args.first
      else
        Filter.new(*args) 
      end
    end

    # Create a Tree::SelectFilter. Pass-through filter object if given as argument
    def self.select_filter(select_expr, &block)
      if args.first.is_a?(Filter)
        args.size == 1 or raise ArgumentError
        args.first
      else
        SelectFilter.new(select_expr) 
      end
    end

  protected
    def do_preorder(enum, filter, this)
      if this
        select, traverse = filter.match(node)
        enum << node if select
      end
      children.each { |child| child.do_preorder(enum, filter, true) } if traverse || !this
    end

    def do_visit(filter, this, &block)
      select, traverse = filter.match(node)
      yield(node) if this && select
      children.each { |child| child.do_visit(filter, true, &block) } if traverse || !this
    end

    def do_accumulate(filter, this, acc, &block)
      select, traverse = filter.match(node)
      acc = yield(acc, node) if this && select
      children.each { |child| child.do_accumulate(filter, true, acc, &block) } if traverse || !this
    end

    def do_aggregate(filter, this, &block)
      select, traverse = filter.match(self)
      values = traverse ? children.map { |child| child.do_aggregate(filter, true, &block) } : []
      if select
        yield(node, values) #if select
      else
        values
      end
    end
  end

  # A regular tree. Users of this library should derived their base node class
  # from Tree
  #
  class Tree < AbstractTree
    def node = self
  end

  # The #parent and #children methods in the projected tree refers
  # to the nodes in the new tree and not the old tree. The ProjectedTree#node
  # method can be used to access the original node
  #
  # Projected trees acts like cached selections of nodes and can be used to
  # avoid repeated searches down through the hierarchy of nodes
  #
  class ProjectedTree < AbstractTree
    attr_reader :node

    def initialize(parent, node)
      super(parent)
      @node = node
    end

    def method_missing(method, *args, &block) = node.send(method, *args, &block)
  end

  # A Forrest is a special kind of Tree where the top node can't be accessed,
  # effectively turning it into a container of trees (aka. "forrest"). It is
  # derived from AbstractTree but its methods has no working :this argument -
  # the methods fail if it is not +false+
  #
  # The value of :this is checked dynamically to allow AbstractTree to use
  # derived methods in Forrest (eg. AbstractTree#map calls Forrest#preorder)
  #
  # It is used as root node for projected trees when there is no single parent
  # of the selection
  #
  # TODO Derive from ProjectedTree
  #
  class Forrest < AbstractTree
    def node = raise ArgumentError, "#node is not defined on a Forrest object"

    def filter(*filter, this: false)
      constrain this, false
      super(*filter, this: false)
    end

    def preorder(*filter, this: false)
      constrain this, false
      super(*filter, this: false)
    end

    def postorder(*filter)
      constrain this, false
      super(*filter, this: false)
    end

    def visit(*filter, this: false, &block)
      constrain this, false
      super(*filter, this: false, &block)
    end

    def accumulate(*filter, initial: nil, this: false, &block)
      constrain this, false
      super(*filter, this: false, initial: initial, &block)
    end

    def aggregate(*filter, this: false, &block)
      constrain this, false
      super(*filter, this: false, &block)
    end

    def project(*filter, this: false)
      constrain this, false
      super(*filter, this: false)
    end

    def initialize()
      super(nil)
    end

    # def project(*filter) # TODO Short-cut 
    # def forrest(*filter) # TODO Short-cut
  end
end












