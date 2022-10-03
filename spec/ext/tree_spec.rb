
describe "Tree" do
  class Node < Tree::Tree
    attr_reader :name
    def initialize(parent, name)
      super(parent)
      @name = name
    end
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

  describe "#subtrees" do
    it "returns the matching subtrees" do
      expect(root.subtrees.map(&:name)).to eq %w(a d)
      expect(a.subtrees.map(&:name)).to eq %w(b c)
      expect(e.subtrees.map(&:name)).to eq []
      expect(root.subtrees(is_vowel).map(&:name)).to eq %w(a e)
      expect(root.subtrees(is_vowel).map { |node| node.subtrees.to_a }.flatten.map(&:name)).to eq %w(b c)
    end
  end

  describe "#visit" do
    it "executes block on matching nodes" do
      a = []
      root.visit { |node| a << node.name }
      expect(a).to eq %w(root a b c d e)
    end
  end

  describe "#translate" do
    it "creates a new tree-like object" do
      t = root.translate(initial: {}) { |curr, node| curr[node.name] = {} }
      expect(t).to eq "a" => { "b" => {}, "c" => {} }, "d" => { "e" => {} }
    end
  end

  describe "#project" do
    it "creates a projection of the tree" do
      not_c = lambda { |node| node.name != "c" }
      t = root.project(not_c)
      expect(t.preorder.map(&:name)).to eq %w(root a b d e)
    end
  end


# describe "#traverse" do
#   context "without arguments" do
#     it "enumerates all nodes" do
#       expect(root.traverse.map(&:name)).to eq %w(root a b c d e)
#       expect(d.traverse.map(&:name)).to eq %(d e)
#       expect(e.traverse.map(&:name)).to eq []
#     end
#   end
# end

end
