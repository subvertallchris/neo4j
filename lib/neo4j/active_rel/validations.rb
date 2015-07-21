module Neo4j
  module ActiveRel
    module Validations
      extend ActiveSupport::Concern
      include Neo4j::Shared::Validations

      def valid?(context = nil)
        context ||= (new_record? ? :create : :update)
        super(context)
        if new_record?
          [from_node, to_node].each do |node|
            self.errors.add(:node, 'failed validation') if node.new_record? && !node.valid?
          end
        end
        errors.empty?
      end
    end
  end
end
