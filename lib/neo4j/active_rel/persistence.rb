module Neo4j::ActiveRel
  module Persistence
    extend ActiveSupport::Concern
    include Neo4j::Shared::Persistence

    class RelInvalidError < RuntimeError; end
    class ModelClassInvalidError < RuntimeError; end
    class RelCreateFailedError < RuntimeError; end

    # Should probably find a way to not need this
    def association_proxy_cache
      {}
    end

    def save(*)
      update_magic_properties
      create_or_update
    end

    def save!(*args)
      fail RelInvalidError, self unless save(*args)
    end

    def create_model(*)
      validate_node_classes!
      create_magic_properties
      set_timestamps
      properties = self.class.declared_property_manager.convert_properties_to(self, :db, props)
      rel = _create_rel(from_node, to_node, properties)
      return self unless rel.respond_to?(:_persisted_obj)
      init_on_load(rel._persisted_obj, from_node, to_node, @rel_type)
      true
    end

    module ClassMethods
      # Creates a new relationship between objects
      # @param [Hash] props the properties the new relationship should have
      def create(props = {})
        relationship_props = extract_association_attributes!(props) || {}
        new(props).tap do |obj|
          relationship_props.each do |prop, value|
            obj.send("#{prop}=", value)
          end
          obj.save
        end
      end

      # Same as #create, but raises an error if there is a problem during save.
      def create!(*args)
        props = args[0] || {}
        relationship_props = extract_association_attributes!(props) || {}
        new(props).tap do |obj|
          relationship_props.each do |prop, value|
            obj.send("#{prop}=", value)
          end
          obj.save!
        end
      end
    end

    private

    def validate_node_classes!
      [from_node, to_node].each do |node|
        type = from_node == node ? :_from_class : :_to_class
        type_class = self.class.send(type)

        next if [:any, false].include?(type_class)

        unless node.class.mapped_label_names.include?(type_class.to_s.constantize.mapped_label_name)
          fail ModelClassInvalidError, type_validation_error_message(node, type_class)
        end
      end
    end

    def type_validation_error_message(node, type_class)
      "Node class was #{node.class} (#{node.class.object_id}), expected #{type_class} (#{type_class.object_id})"
    end

    def _create_rel(from_node, to_node, *args)
      props = self.class.default_property_values(self)
      props.merge!(args[0]) if args[0].is_a?(Hash)
      set_classname(props, true)

      # if from_node.id.nil? || to_node.id.nil?
      #   fail RelCreateFailedError, "Unable to create relationship (id is nil). from_node: #{from_node}, to_node: #{to_node}"
      # end
      _rel_creation_query(from_node, to_node, props)
    end

    N1_N2_STRING = 'n1, n2'
    ACTIVEREL_NODE_MATCH_STRING = 'ID(n1) = {n1_neo_id} AND ID(n2) = {n2_neo_id}'
    def _rel_creation_query(from_node, to_node, props)
      from_as_query = from_node.to_query(:n1)
      to_as_query = to_node.to_query(:n2)
      match = from_node.persisted? || to_node.persisted?
      match_args = if match
        from_match = "(n1)" if from_node.persisted?
        to_match = "(n2)" if to_node.persisted?
        from_match && to_match ? "#{from_match}, #{to_match}" : "#{from_match || to_match}"
      end

      big_dumb_props = from_as_query.params.merge(to_as_query.params)
      query_start = Neo4j::Session.current.query
      matched_query = match ? query_start.match(match_args) : query_start
      create_query = matched_query.create("#{from_as_query.to_s}-[r:`#{type}`]->#{to_as_query.to_s}")
      create_with_props = create_query.with(:r).set(r: props).params(big_dumb_props)
      create_with_props.pluck(:r).first

      # Neo4j::Session.query.match(N1_N2_STRING)
      #   .where(ACTIVEREL_NODE_MATCH_STRING).params(n1_neo_id: from_node.neo_id, n2_neo_id: to_node.neo_id).break
      #   .send(create_method, "n1-[r:`#{type}`]->n2")
      #   .with('r').set(r: props).pluck(:r).first
    end

    def create_method
      self.class.unique? ? :create_unique : :create
    end
  end
end
