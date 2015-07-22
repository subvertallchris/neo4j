module Neo4j
  module ActiveRel
    module Callbacks #:nodoc:
      extend ActiveSupport::Concern
      include Neo4j::Shared::Callbacks

      def save(*args)
        unless _persisted_obj || (from_node.respond_to?(:neo_id) && to_node.respond_to?(:neo_id))
          fail Neo4j::ActiveRel::Persistence::RelInvalidError, 'from_node and to_node must be node objects'
        end
        super(*args)
      end

      private

      def create_model
        return super if both_persisted?
        case
        when !from_node.persisted? && !to_node.persisted?
          Neo4j::Transaction.run do
            from_node.run_callbacks(:create) do
            to_node.run_callbacks(:create) { run_callbacks(:create) { super }}
            end
          end
        when one_unpersisted?
          Neo4j::Transaction.run do
            unpersisted.run_callbacks(:create) { run_callbacks(:create) { super }}
          end
        end
      end

      def rel_create_callback
        run_callbacks(:create) { super }
      end

      def both_persisted?
        from_node.persisted? && to_node.persisted?
      end

      def one_unpersisted?
        !from_node.persisted? || !to_node.persisted?
      end

      def unpersisted
        from_node.persisted? ? to_node : from_node
      end
    end
  end
end
