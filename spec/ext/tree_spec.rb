
describe "Tree::Pairs" do
  describe "group" do
    def groups_to_s(a)
      a.map { |first, rest| "#{first || 'nil'}->#{rest.join(',')}" }.join " "
    end

    it "groups pairs on first element" do
      a = [
        ["root", "a"],
        ["a", "b"],
        ["a", "c"],
        ["root", "d"],
        ["d", "e"]
      ]

      groups = Tree::Pairs.new { |enum| a.each { |e| enum << [e.first, e.last] } }.group
      expect(groups_to_s groups).to eq "root->a,d a->b,c d->e"
    end
  end
end

describe "Tree::Filter" do
  class SomeNode < Tree::Tree
    def yes? = true
    def no? = false
  end

  context "when given a method name" do
    let(:node) { SomeNode.new(nil) }

    it "matches if the method exists and returns true" do
      filter = Tree::Filter.new(:yes?, true)
      select, traverse = filter.match(node)
      expect(select).to eq true
    end
    it "doesn't match if the method returns false" do
      filter = Tree::Filter.new(:no?, true)
      select, traverse = filter.match(node)
      expect(select).to eq false
    end
    it "doesn't match if the method doesn't exist" do
      filter = Tree::Filter.new(:not_there, true)
      select, traverse = filter.match(node)
      expect(select).to eq false
    end
  end
  end

describe "Tree::Tree" do
  class Node < Tree::Tree
    attr_reader :name
    def initialize(parent, name)
      super(parent)
      @name = name
    end

    def sig = name + (empty? ? "" : "(#{children.map(&:sig).join(',')})")
  end

  class Tree::Pairs
    def to_s() = map { |first, second| "#{first&.name || 'nil'}->#{second.name}" }.join " "
  end

  # root
  #   a
  #     b
  #     c
  #   d
  #     e
  #
  let!(:root) { Node.new nil, "root" }
  let!(:a) { Node.new root, "a" }
  let!(:b) { Node.new a, "b" }
  let!(:c) { Node.new a, "c" }
  let!(:d) { Node.new root, "d" }
  let!(:e) { Node.new d, "e" }

  let(:is_vowel) { lambda { |node| %w(a e i o u).include? node.name } }
  def pairs_to_s(maps) = maps.map { |from, to| "#{from&.name || 'nil'}->#{to.name}" }.join " "

  def filter(*names)
    names = Array(names).flatten
    lambda { |node| names.include? node.name }
  end

  describe "#filter" do
    context "without arguments" do
      it "enumerates the nodes" do
        expect(root.filter.to_a).to eq root.each.to_a
      end
    end
    context "when :this is false" do
      it "excludes the root element" do
        expect(root.filter(this: false).to_a).to eq root.each.to_a[1..-1]
      end
    end
    context "with a filter" do
      it "returns the matching nodes" do
        expect(root.filter(is_vowel).to_a).to eq [a, e]
      end
    end
  end

  describe "#edges" do
    context "without arguments" do
      it "returns connected pairs of nodes" do
        pairs = a.edges
        expect(a.edges.to_s).to eq "nil->a a->b a->c"
      end
    end
    context "when :this is false" do
      it "excludes the root element" do
        pairs = a.edges(this: false)
        expect(pairs.to_s).to eq "nil->b nil->c"
      end
    end
    context "with a filter" do
      it "returns pairs of matching nodes" do
        l = filter %w(root c e)
        pairs = root.edges(l)
        expect(pairs.to_s).to eq "nil->root root->c root->e"
      end
    end
  end

  describe "#pairs" do
    context "without arguments" do
      it "returns pairs of nodes where the second node match an expression" do
        l = filter %w(c d)
        pairs = root.pairs(true, true, l)
        expect(pairs.to_s).to eq "a->c root->d"
      end
    end

    context "when :this is false" do
      it "excludes the root element" do
        l = filter %w(c d)
        pairs = root.pairs(true, true, l, this: false)
        expect(pairs.to_s).to eq "a->c"
      end
    end
    context "with filters" do
      it "leaves out intermediate nodes" do
        l = filter %w(a e)
        pairs = root.pairs(filter("root"), true, l)
        expect(pairs.to_s).to eq "root->a root->e"
      end
    end
  end

  describe "#preorder" do
    context "without arguments" do
      it "enumerates all nodes" do
        expect(root.preorder.map(&:name)).to eq %w(root a b c d e)
        expect(d.preorder.map(&:name)).to eq %w(d e)
        expect(e.preorder.map(&:name)).to eq %w(e)
      end
    end
    context "when :this is false" do
      it "excludes the root element" do
        expect(root.preorder(this: false).map(&:name)).to eq %w(a b c d e)
        expect(d.preorder(this: false).map(&:name)).to eq %w(e)
        expect(e.preorder(this: false).map(&:name)).to eq []
      end
    end
    context "with a filter" do
      it "only selects nodes matching the filter" do
        expect(root.preorder(is_vowel).map(&:name)).to eq %w(a e)
      end
    end
  end

  describe "#ancestors" do
    it "enumerates the ancestors of this object top-down" do
      expect(c.ancestors.map(&:name)).to eq %w(root a) 
    end
  end

  describe "#visit" do
    let(:acc) { [] }
    let(:block) { lambda { |node| acc << node.name } }

    it "executes block on matching nodes" do
      root.visit(&block)
      expect(acc).to eq %w(root a b c d e)
    end
    context "when :this is false" do
      it "excludes the root element" do
        root.visit(this: false, &block)
        expect(acc).to eq %w(a b c d e)
      end
    end
    context "with a filter" do
      it "only visits selected nodes" do
        root.visit(is_vowel, &block)
        expect(acc).to eq %w(a e)
      end
    end
  end

  describe "#accumulate" do
    it "computes a value top-down" do
      v = root.accumulate({}) { |acc, node| acc[node.name] = {} }
      expect(v).to eq "root"=>{"a"=>{"b"=>{}, "c"=>{}}, "d"=>{"e"=>{}}}
    end
  end

  describe "#aggregate" do
    it "computes a value bottom-up" do
      i = 0
      v = root.aggregate { |node, values|
        i += 1
        s = "#{i}:#{node.name}"
        s += ",#{values.join(',')}" if !values.empty?
        s
      }
      expect(v).to eq "6:root,3:a,1:b,2:c,5:d,4:e"
    end
  end
end

