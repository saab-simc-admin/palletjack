require 'psych'

# Read YAML files and remember where each value came from.
#
# Objects behave like normal in most respects. Objects that implement
# Traceable can be asked for their position by calling file(), line(),
# column() and byte().
#
# If the class attribute TraceableString.debug is set, +inspect+ and
# +to_yaml+ output position information for each atom, in the case of
# +to_yaml+ separated from its value by the string " =^.^= ".
#
# Example:
#
#   yaml = "---
#   foo:
#     bar: 1
#     baz:
#       - gazonk
#       - foobar"
#   handler = PositionHandler.new("<STDIN>")
#   parser = Psych::Parser.new(handler)
#   handler.parser = parser
#   parser.parse(yaml)
#   visitor = PositionVisitor.new
#   tree = visitor.accept(handler.root)
#
#   tree[0]['foo']['bar']
#   => "1"
#   tree[0]['foo']['bar'].file
#   => "<STDIN>"
#   tree[0]['foo']['bar'].line
#   => 3
#   tree[0]['foo']['bar'].column
#   => 2
#
#   puts tree[0].to_yaml
#   ---
#   foo:
#     bar: 1
#     baz:
#     - gazonk
#     - foobar
#
#   TraceableString.debug = true
#   puts tree[0].to_yaml.gsub(' =^.^= ', '  # ')
#   ---
#   foo  # <STDIN> (line 1, column 4):
#     bar  # <STDIN> (line 2, column 6): 1  # <STDIN> (line 3, column 2)
#     baz  # <STDIN> (line 3, column 6):
#     - gazonk  # <STDIN> (line 5, column 4)
#     - foobar  # <STDIN> (line 6, column 0)

# Attributes required to trace the origin of a value.
module Traceable
  attr_accessor :file
  attr_accessor :byte
  attr_accessor :line
  attr_accessor :column
end

# A string that remembers the source of its value, and can output it
# again when serialised to YAML.
class TraceableString < String
  include Traceable

  def encode_with(coder)
    coder.tag = nil
    coder.scalar = self.to_str
    if debug?
      # LibYAML, the C YAML library which underlies Ruby's Psych
      # library, does not handle comments at all. The parser ignores
      # them and the emitter cannot write them. Thus, to output the
      # sourcing information in a manner that is at least semi-sane,
      # we need to put it in the actual value, behind some sort of
      # separator.
      #
      # The separator needs to be representable in Latin-1, otherwise
      # LibYAML quotes it. It needs to be non-breaking, otherwise
      # LibYAML will break here to wrap at 80 characters. It cannot
      # have any special meaning in YAML (including the quote
      # character), otherwise LibYAML quotes it. It shouldn't appear
      # in real data, sine we'll need to substitute all instances of
      # it.
      #
      # Also, I like cats, even ASCII ones.
      coder.scalar += " =^.^= #{@file} (line #{@line}, column #{@column})"
    end
  end

  def inspect
    if debug?
      "\"%s\" (%s, line: %i, col: %i, byte: %i)" %
        [self.to_str, @file, @line, @column, @byte]
    else
      super
    end
  end

  def self.debug=(maybe)
    @@debug = maybe
  end

  def self.debug
    @@debug ||= false
  end

  private

  def debug?
    self.class.debug
  end
end

# Make the nodes in Psych's YAML parse tree track their positions.
class Psych::Nodes::Node
  include Traceable
end

# Extend the parser to remember the position of each object.
class PositionHandler < Psych::TreeBuilder

  # The handler needs access to the parser in order to call mark
  attr_accessor :parser

  # +filename+ is the name of the source file the YAML structure will
  # be parsed from. It is only copied into parsed objects, not
  # interpreted.
  def initialize(filename)
    super()
    @file = filename
  end

  # Copy a parser position from a +Psych::Parser::Mark+ to a parse
  # tree node.
  def record_position(node, mark)
    node.extend Traceable
    node.file = @file
    node.byte = mark.index
    node.line = mark.line
    node.column = mark.column
    node
  end

  def start_mapping(anchor, tag, implicit, style)
    record_position(super, parser.mark)
  end

  def start_sequence(anchor, tag, implicit, style)
    record_position(super, parser.mark)
  end

  def scalar(value, anchor, tag, plain, quoted, style)
    record_position(super, parser.mark)
  end
end

# Extend the Ruby structure builder to remeber each object's position.
class PositionVisitor < Psych::Visitors::ToRuby

  # Copy a parser position from a parse tree node to a primitive
  # object.
  def record_position(s, o)
    s.extend Traceable
    s.file = o.file
    s.byte = o.byte
    s.line = o.line
    s.column = o.column
    s
  end

  def visit_Psych_Nodes_Scalar o
    # Primitive YAML values can be either strings or integers. Ruby
    # integers cannot be extended, so convert everything to strings
    # before inserting position information.
    record_position(TraceableString.new(String(super)), o)
  end

  def visit_Psych_Nodes_Sequence o
    record_position(super, o)
  end

  def visit_Psych_Nodes_Mapping o
    record_position(super, o)
  end
end

module TraceableYAML

  # Parse a YAML document from the string +doc+, tagging each value
  # with the source +tag+, and return a Ruby object tree representing
  # the result.
  def self.parse(doc, tag)
    handler = PositionHandler.new(tag)
    parser = Psych::Parser.new(handler)
    handler.parser = parser
    parser.parse doc
    if PositionVisitor.respond_to?(:create)
      # Ruby 2.1 and above
      visitor = PositionVisitor.create
    else
      # Ruby 2.0
      visitor = PositionVisitor.new
    end
    tree = visitor.accept(handler.root)
    tree[0]
  end

  # Load a YAML document from the file +path+, tagging each value with
  # the source +tag+, and return a Ruby object tree representing the
  # result.
  def self.load_file(path, tag)
    File.open(path) do |f|
      parse(f.read, tag)
    end
  end
end
