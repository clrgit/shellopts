#!/usr/bin/env ruby

#require 'indented_io'

module Tree
  class Filter
    attr_reader :select
    attr_reader :traverse
    attr_reader :both

    # +select_expr+ and +traverse_expr+ can be a Proc, Symbol, true, false, or
    # nil. True, false, and nil have special meanings:
    #
    #   when +select+ is
    #     true    Select always. The default
    #     false   Never select (rather meaningless)
    #     nil     Select only if block returns truthy 
    #
    #   when +traverse+ is
    #     true    Traverse always. The default
    #     false   Traverse only if select didn't match. Execute block but ignore
    #             its value
    #     nil     Traverse only if block returns truthy
    #
    def initialize(select_expr = true, traverse_expr = true, &block)
      @match_method = :match_each
      if select_expr.nil? && traverse_expr.nil?
        if block_given?
          @both = block
          @match_method = :match_both
        else
          select_expr = traverse_expr = true
        end
      elsif select_expr.nil?
        block_given? or raise ArgumentError
        @select = block
        if traverse_expr == false
          @match_method = :match_stop
        else
          @traverse = mk_lambda(traverse_expr)
        end
      elsif traverse_expr.nil?
        block_given? or raise ArgumentError
        @select = mk_lambda(select_expr)
        @traverse = block
      else
        !block_given? or raise ArgumentError
        @select= mk_lambda(select_expr)
        if traverse_expr == false
          @match_method = :match_stop
        else
          @traverse = mk_lambda(traverse_expr)
        end
      end
    end

    # Match +node+ against the filter and a [select, traverse] tuple of bools
    def match(node) = self.send(@match_method, node)

  protected
    def match_each(node) = [@select.call(node), @traverse.call(@node)]
    def match_both(node) = @both.call(node)
    def match_stop(node) 
      match = @select.call(node)
      [match, !match]
    end

    def mk_lambda(arg)
      case arg
        when Proc
          arg
        when Symbol
          lambda { |node| node.send(arg) }
        when Array
          arg.all? { |a| a.is_a? Class }
          lambda { |node| arg.any? { |a| node.is_a? a } }
        when true, false
          lambda { |node| arg }
      else
        raise ArgumentError
      end
    end
  end

  class AbstractTree
    def node = abstract_method
    attr_reader :parent
    attr_reader :children

    def initialize(parent)
      @parent = parent
      @children = []
      @parent.children << self if @parent
    end

    def empty?() children.empty? end
    def size() descendants.to_a.size end

    def self.filter(*args, &block)
      if args.first.is_a?(Filter)
        args.size == 1 && !block_given? or raise ArgumentError
        args.first
      else
        Filter.new(*args, &block) 
      end
    end

    # If +prev+ is different from +false+, #preorder will return an enumerator
    # of [previous-match, current-match] tuples with the previous-match set to
    # the value of +prev+ on the first match
    #
    def preorder(*filter, this: true, &block)
      filter = self.class.filter(*filter, &block)
      Enumerator.new { |enum| do_preorder(enum, filter, this) }
    end

    # Enumerator of descendant nodes
    def descendants(*filter) = preorder(*filter, this: false)

    def edges(*filter, this: true, &block)
      filter = self.class.filter(*filter, &block)
      Enumerator.new { |enum| do_egdes(enum filter, this) }
    end

    # Enumerator of matching subtrees. Does not descend into the subtrees
    def subtrees(select_filter = true, prev: false, &block)
      preorder(select_filter, false, this: false, &block)
    end

    def visit(*filter, this: true, &block) = preorder(*filter, this: this).each(&block)

    def translate(*filter, this: true, initial: nil, &block)
      filter = self.class.filter(*filter)
      do_translate(filter, this, initial, &block)
    end

    def project(*filter, this: true) 
      translate(*filter, this: this) { |curr, node| ProjectedTree.new(curr, node) }
    end

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




