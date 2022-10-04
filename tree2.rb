

module TreeNode
  attr_reader :parent
  attr_reader :children
  def initialize(parent)
    @parent = parent
    @children = []
    @parent.children << self if @parent
  end
end

class Tree
  include TreeNode

  # assorted algorithms
end

class Node < TreeNode
  attr_reader :name

  def self.projected_tree_class = ProjectedTreeNode
  def self.forrest_class = ForrestNode

  def initialize(parent, name)
    @name = name
    super(parent)
  end

  def uid(node = self) = [node.parent&.name, node.name].compact.join(".")
  def sig(node = self) = (node.name || "") + "(" + node.children.map(&:name).join(",") + ")"
end

class Nodes < Tree
  def algo(node) = nil end
end

module ProjectedTree
  include TreeNode
  def method_missing(method, *args, &block) # Gets called a gazillion number of times :-(
    
  end
end

# auto-derived - FIXME Should happen for every derived class :-( AND gets called a lot :-(
class ProjectedTreeNode < Node
  # override parent and children
  include ProjectedTree
end

# auto-derived
class ForrestNode < Node
  # override #node for root element
end





class Enum
  attr_reader :parent
  attr_reader :children
  attr_reader :node # Can be nil


end

class Tree
  attr_reader :node_klass

  def initialize(node_klass)
    @node_klass = node_klass
  end

  def add(node)
  end

  def make(*args) @node_klass.new(self, *args) end
end

t = Tree.new(Node)


n = t.make("root")


