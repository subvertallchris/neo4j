module Neo4j::ActiveNode
  module Query
    class QueryBuilder

      attr_reader :node, :var, :persisted

      def initialize(node, var)
        @node = node
        @var = var
        @persisted = node.persisted?
      end

      def persisted?
        !!persisted
      end

      def to_s
        inspect
      end

      def inspect
        "(#{var}#{labels} #{match_props})"
      end

      def match_props
        "{props_#{object_id}}" unless persisted?
      end

      def params
        if persisted?
          { "props_#{object_id}" => { neo_id: node.neo_id }}
        else
          { "props_#{object_id}" => node.props }
        end
      end

      def labels
        ":#{node.class.mapped_label_names.join(':')}"
      end

    end
  end
end

# If unpersisted:
# CREATE (n:Label {props})
#
# If persisted:
# MATCH (n) WHERE ID(n) = {id}
#
# s = Student.new; l = Lesson.new; r = EnrolledIn.new(from_node: s, to_node: l); r.save
