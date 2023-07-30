#!/usr/bin/env ruby

require_relative 'filter.rb'

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
#   o Consider filters a poor-man's project
#   o Make it possible to chain (or nest) filters
#   o A tree-adaptor that take two methods so that 
#       parent = self.send(parent_method)
#       children = self.send(children_method)
#     Eg.
#       tree = Tree::Adaptor(program, :supercommand, :subcommands)
#
  
module Tree
  class Pairs < Enumerator
    def group
      h = {}
      each { |first, last| (h[first] ||= []) << last }
      h.each
    end
  end

  class AbstractTree
    # Parent node
    attr_reader :parent

    # List of child nodes
    def children = abstract_method

    # Create a new node and attach it to the parent
    def initialize(parent, *key)
      (@parent = parent)&.attach(self, *key)
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

    # Like #each but with filters. Same as #preorder except it can take a block argument
    def filter(*filter, this: true, &block) 
      filter = self.class.filter(*filter)
      if block_given?
        do_filter(nil, filter, this, &block)
      else
        Enumerator.new { |enum| do_filter(enum, filter, this) }
      end
    end

    # Like #filter but enumerates [previous-matching-node, matching-node]
    # tuples. This can be used to build projected trees. See also #accumulate
    #
    # #edges returns nil as the previous matching node for top-most matches.
    # This is different from #pairs
    #
    def edges(*filter, this: true, &block)
      filter = self.class.filter(*filter)
      if block_given?
        do_edges(nil, filter, this, &block)
      else
        Pairs.new { |enum| do_edges(enum, filter, this) }
      end
    end

    # Return pairs of nodes where the first node is selected by the filter
    # and the second node is a descendant of the first node that satisfies the
    # condition. The second node doesn't have to be matched by the filter
    #
    # #pairs always return pairs of nodes, nil can't be returned by #pairs
    #
    # TODO: Maybe change semantics so that 'pairs(cond)' selects pairs that
    # match the condition
    def pairs(*filter, cond_expr, this: true, &block)
      filter = self.class.filter(*filter)
      cond = Filter.mk_lambda(cond_expr)
      if block_given?
        do_pairs(nil, filter, this, cond, &block)
      else
        Pairs.new { |enum| do_pairs(enum, filter, this, cond) }
      end
    end

    # Pre-order enumerator of selected nodes
    def preorder(*filter, this: true)
      filter = self.class.filter(*filter)
      Enumerator.new { |enum| do_preorder(enum, filter, this) }
    end

    # Post-order enumerator of selected nodes
    def postorder(*filter, this: true) = raise NotImplementedError

    # List of ancestors of this node bottom-up
    def progenitors(*filter)
      filter = self.class.filter(*filter)
      a = []
      follow(parent, :parent).select { |node| 
        select, traverse = filter.match(node)
        a << node if select
        break if !traverse
      }
      a
    end

    # List ancestors of this node top-down
    def ancestors(*filter) = progenitors(*filter).to_a.reverse

    # Enumerator of descendant nodes matching filter. Same as #preorder with
    # :this set to false
    def descendants(*filter) = preorder(*filter, this: false)

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
    # then used as the accumulator for the child nodes. Returns the original
    # accumulator. See also #inject
    def accumulate(*filter, accumulator, this: true, &block)
      filter = self.class.filter(*filter)
      block_given? or raise ArgumentError, "Block is required"
      acc = do_accumulate(filter, this, accumulator, &block)
      accumulator.nil? ? acc : accumulator
    end

    # Traverse the tree bottom-up while aggregating information
    def aggregate(*filter, this: true, &block)
      filter = self.class.filter(*filter)
      do_aggregate(filter, this, &block)
    end

    # Find first node that matches the filter and that returns truthy from the block
    def find(*filter, &block) = descendants(*filter).first(&block)

    # Create a Tree::Filter object. Can also take an existing filter as
    # argument in which case the given filter will just be passed through
    def self.filter(*args)
      if args.first.is_a?(Filter)
        args.size == 1 or raise ArgumentError
        args.first
      else
        Filter.new(*args) 
      end
    end

  protected
    def attach(child, *key) = abstract_method

    # +enum+ is unused (and unchecked) if a block is given
    def do_edges(enum, filter, this, last_match = nil, &block)
      select, traverse = filter.match(self)
      if this && select
        if block_given?
          yield(last_match, self)
        else
          enum << [last_match, self]
        end
        last_match = self
      end
      children.each { |child| child.do_edges(enum, filter, true, last_match, &block) } if traverse || !this
    end

    def do_pairs(enum, filter, this, cond, last_selected = nil, &block)
      select, traverse = filter.match(self)
      last_selected = self if this && select
      children.each { |child| 
        if last_selected && cond.call(child)
          if block_given?
            yield(last_selected, child)
          else
            enum << [last_selected, child]
          end
        else
          child.do_pairs(enum, filter, true, cond, last_selected, &block) 
        end
      } if traverse || !this
    end

    def do_filter(enum, filter, this, &block)
      select, traverse = filter.match(self)
      if this && select
        if block_given?
          yield self
        else
          enum << self
        end
      end
      children.each { |child| child.do_filter(enum, filter, true, &block) } if traverse || !this
    end

    def do_preorder(enum, filter, this)
      select, traverse = filter.match(self)
      enum << self if this && select
      children.each { |child| child.do_preorder(enum, filter, true) } if traverse || !this
    end

    def do_visit(filter, this, &block)
      select, traverse = filter.match(self)
      yield(self) if this && select
      children.each { |child| child.do_visit(filter, true, &block) } if traverse || !this
    end

    # TODO: Break if acc.nil? Test it. Probably a bad idea because we can easily start with a nil accumulator
    def do_accumulate(filter, this, acc, &block)
#     return nil if acc.nil?
#     puts "#do_accumulate -> #{self.token.value} (#{self.class.name})"
      select, traverse = filter.match(self)
#     puts "  this: #{this}"
#     puts "  select: #{select}"
#     puts "  traverse: #{traverse}"
#     puts "  children.size: #{children.size}"
      acc = yield(acc, self) if this && select
      children.each { |child| child.do_accumulate(filter, true, acc, &block) } if traverse || !this
      acc
    end

    def do_aggregate(filter, this, &block)
      select, traverse = filter.match(self)
      values = traverse ? children.map { |child| child.do_aggregate(filter, true, &block) } : []
      if select
        yield(self, values) #if select
      else
        values
      end
    end
  end

  # A regular tree. Users of this library should derived their base node class
  # from Tree
  #
  class Tree < AbstractTree # Aka. ArrayTree
    attr_reader :children
    def initialize(parent)
      @children = []
      super
    end
  protected
    def attach(child) = @children << child
  end

  # This is an abstract base class for Tree::Map and Tree::Set
  class HashTree < AbstractTree
    attr_reader :nodes
    def children = nodes.values
    def initialize(parent, *key)
      @nodes = {}
      super
    end
    forward_to :nodes, :[], :[]=, :key?, :keys, :values
  protected
    def attach_by_key(child, key)
      !nodes.key?(key) or raise ArgumentError
      nodes[key] = child
      child.instance_variable_set(:@parent, self)
    end
  end

  class Map < HashTree
  protected
    def attach(child, key) = attach_by_key(child, key)
  end

  class Set < HashTree
    # Note that it doesn't make much sense to have a Map#path because a node
    # doesn't know its key, and on the other hand, if a node knows its key,
    # then we could just as well use a Map#Set instead
    def path
      (
        follow(parent, :parent)
            .map { _1.send(:key).to_s }
            .select { !_1.empty? } # Eliminate root object
            .reverse + [key]
      ).join(".")
#     (follow(parent, :parent).map { _1.send(:key) }.reverse + [key]).join(".")
    end

  protected
    def key = abstract_method
    def attach(child) = attach_by_key(child, child.send(:key))
  end



# class TreeAdaptor < AbstractTree
#   attr_reader :obj
#
#   def parent = nil
#   def children
#   end
#
#   def initialize(obj, &block)
#     @block = block
#
# end

# class TreeAdapter < AbstractTree
#   attr_reader :parent_method
#   attr_reader :children_method
#   def parent = self.send(parent_method)
#   def children = self.send(children_method)
#
#   def initialize(root, parent_method, children_method)
#     @parent_method = parent_method
#     @children_method = children_method
#   end
# end
end

