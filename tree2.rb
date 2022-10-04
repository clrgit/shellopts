
class Node
  # no parent, child

  def name() "hej" end

  def sig(enum) = (enum.node&.name || "") + "(" + enum.children.map(&:name).join(",") + ")"
end

t = Tree.new(Node)



