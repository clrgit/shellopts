
describe "Tree" do
  class Node < Tree::Tree
    attr_reader :name
    def initialize(parent, name)
      super(parent)
      @name = name
    end

    def sig = name + (empty? ? "" : "(#{children.map(&:sig).join(',')})")
  end

  class Tree::ProjectedTree
    def sig = name + (empty? ? "" : "(#{children.map(&:sig).join(',')})")
  end

  class Tree::Forrest
    def sig = "(#{children.map(&:sig).join(',')})"
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

  describe "#project" do
    def root_selector = lambda { |node| [root, a, c, e].include? node }
    def selector = lambda { |node| [a, c, e].include? node }

    it "creates a projection of the tree" do
      v = root.project(root_selector)
      expect(v.sig).to eq "root(a(c),e)"
    end
    it "returns nil if the top node doesn't match" do
      v = root.project(selector)
      expect(v).to eq nil
    end
    context "when :this is false" do
      it "returns a forrest" do
        v = root.project(selector, this: false)
        expect(v.sig).to eq "(a(c),e)"
      end
    end
  end
end

