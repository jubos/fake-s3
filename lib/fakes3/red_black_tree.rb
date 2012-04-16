# Algorithm based on "Introduction to Algorithms" by Cormen and others
# Retrieved from
# https://github.com/headius/redblack/blob/master/red_black_tree.rb
#
# Modified by Curtis Spencer
class RedBlackTree
  class Node
    attr_accessor :color
    attr_accessor :key
    attr_accessor :left
    attr_accessor :right
    attr_accessor :parent
    attr_accessor :value

    RED = :red
    BLACK = :black
    COLORS = [RED, BLACK].freeze

    def initialize(key, value, color = RED)
      raise ArgumentError, "Bad value for color parameter" unless COLORS.include?(color)
      @color = color
      @key = key
      @value = value
      @left = @right = @parent = NilNode.instance
    end

    def black?
      return color == BLACK
    end

    def red?
      return color == RED
    end
  end

  class NilNode < Node
    class << self
      private :new
      @instance = nil

      # it's not thread safe
      def instance
        if @instance.nil?
          @instance = new

          def instance
            return @instance
          end
        end

        return @instance
      end
    end

    def initialize
      self.color = BLACK
      self.key = 0
      self.left = nil
      self.right = nil
      self.parent = nil
    end

    def nil?
      return true
    end
  end

  include Enumerable

  attr_accessor :root
  attr_accessor :size

  def initialize
    self.root = NilNode.instance
    self.size = 0
  end

  def add(key,value)
    insert(Node.new(key,value))
  end

  def insert(x)
    insert_helper(x)

    x.color = Node::RED
    while x != root && x.parent.color == Node::RED
      if x.parent == x.parent.parent.left
        y = x.parent.parent.right
        if !y.nil? && y.color == Node::RED
          x.parent.color = Node::BLACK
          y.color = Node::BLACK
          x.parent.parent.color = Node::RED
          x = x.parent.parent
        else
          if x == x.parent.right
            x = x.parent
            left_rotate(x)
          end
          x.parent.color = Node::BLACK
          x.parent.parent.color = Node::RED
          right_rotate(x.parent.parent)
        end
      else
        y = x.parent.parent.left
        if !y.nil? && y.color == Node::RED
          x.parent.color = Node::BLACK
          y.color = Node::BLACK
          x.parent.parent.color = Node::RED
          x = x.parent.parent
        else
          if x == x.parent.left
            x = x.parent
            right_rotate(x)
          end
          x.parent.color = Node::BLACK
          x.parent.parent.color = Node::RED
          left_rotate(x.parent.parent)
        end
      end
    end
    root.color = Node::BLACK
  end

  alias << insert

  def delete(z)
    y = (z.left.nil? || z.right.nil?) ? z : successor(z)
    x = y.left.nil? ? y.right : y.left
    x.parent = y.parent

    if y.parent.nil?
      self.root = x
    else
      if y == y.parent.left
        y.parent.left = x
      else
        y.parent.right = x
      end
    end

    z.key = y.key if y != z

    if y.color == Node::BLACK
      delete_fixup(x)
    end

    self.size -= 1
    return y
  end

  def minimum(x = root)
    while !x.left.nil?
      x = x.left
    end
    return x
  end

  def maximum(x = root)
    while !x.right.nil?
      x = x.right
    end
    return x
  end

  def successor(x)
    if !x.right.nil?
      return minimum(x.right)
    end
    y = x.parent
    while !y.nil? && x == y.right
      x = y
      y = y.parent
    end
    return y
  end

  def predecessor(x)
    if !x.left.nil?
      return maximum(x.left)
    end
    y = x.parent
    while !y.nil? && x == y.left
      x = y
      y = y.parent
    end
    return y
  end

  def inorder_walk(x = root)
    x = self.minimum
    while !x.nil?
      yield x.key
      x = successor(x)
    end
  end

  alias each inorder_walk

  def reverse_inorder_walk(x = root)
    x = self.maximum
    while !x.nil?
      yield x.key
      x = predecessor(x)
    end
  end

  alias reverse_each reverse_inorder_walk

  def search(key, x = root)
    while !x.nil? && x.key != key
      key < x.key ? x = x.left : x = x.right
    end
    return x
  end

  # Search for a successor even if the key doesn't exist
  def search_for_possible_successor(key, x = root)
    node = search(key)
    pseudo = false
    if node.class == NilNode
      insert(Node.new(key,nil))
      node = search(key)
      pseudo = true
    end

    succ = successor(node)
    delete(node) if pseudo
    return nil if !succ
    return succ
  end

  def delete_via_key(key)
    node = search(key)
    return if node.class == NilNode
    delete(node)
  end

  # Return array of matches and a boolean to denote whether truncation occurred
  def search_for_range(marker,prefix,max_keys,delimiter)
    succ = nil
    if marker
      succ = search_for_possible_successor(marker)
    else
      succ = self.minimum
    end

    return [],false if succ.class == NilNode

    keys_count = 0
    keys = []
    is_truncated = false

    loop do
      if !prefix or succ.key.index(prefix) == 0
        keys_count += 1
        if keys_count <= max_keys
          keys << succ.value
        else
          is_truncated = true
          break
        end
      end
      succ = successor(succ)
      if succ.class == NilNode
        break
      end
    end

    return keys,is_truncated
  end

  def empty?
    return self.root.nil?
  end

  def black_height(x = root)
    height = 0
    while !x.nil?
      x = x.left
      height +=1 if x.nil? || x.black?
    end
    return height
  end

private

  def left_rotate(x)
    raise "x.right is nil!" if x.right.nil?
    y = x.right
    x.right = y.left
    y.left.parent = x if !y.left.nil?
    y.parent = x.parent
    if x.parent.nil?
      self.root = y
    else
      if x == x.parent.left
        x.parent.left = y
      else
        x.parent.right = y
      end
    end
    y.left = x
    x.parent = y
  end

  def right_rotate(x)
    raise "x.left is nil!" if x.left.nil?
    y = x.left
    x.left = y.right
    y.right.parent = x if !y.right.nil?
    y.parent = x.parent
    if x.parent.nil?
      self.root = y
    else
      if x == x.parent.left
        x.parent.left = y
      else
        x.parent.right = y
      end
    end
    y.right = x
    x.parent = y
  end

  def insert_helper(z)
    y = NilNode.instance
    x = root
    while !x.nil?
      y = x
      z.key < x.key ? x = x.left : x = x.right
    end
    z.parent = y
    if y.nil?
      self.root = z
    else
      z.key < y.key ? y.left = z : y.right = z
    end
    self.size += 1
  end

  def delete_fixup(x)
    while x != root && x.color == Node::BLACK
      if x == x.parent.left
        w = x.parent.right
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          left_rotate(x.parent)
          w = x.parent.right
        end
        if w.left.color == Node::BLACK && w.right.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.right.color == Node::BLACK
            w.left.color = Node::BLACK
            w.color = Node::RED
            right_rotate(w)
            w = x.parent.right
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.right.color = Node::BLACK
          left_rotate(x.parent)
          x = root
        end
      else
        w = x.parent.left
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          right_rotate(x.parent)
          w = x.parent.left
        end
        if w.right.color == Node::BLACK && w.left.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.left.color == Node::BLACK
            w.right.color = Node::BLACK
            w.color = Node::RED
            left_rotate(w)
            w = x.parent.left
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.left.color = Node::BLACK
          right_rotate(x.parent)
          x = root
        end
      end
    end
    x.color = Node::BLACK
  end
end
