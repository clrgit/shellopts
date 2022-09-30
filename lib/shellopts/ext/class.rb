
class Class
  def name = to_s.sub(/.*::/, "")

  def descendants(this: false) = (this ? descendants_r : subclasses.map(&:descendants_r)).flatten

  def dump_hierarchy
    puts self.name
    indent { subclasses.each(&:dump_hierarchy) }
  end

#protected
  def descendants_r = [self] + descendants
end
