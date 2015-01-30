module Neo4j
  module ActiveNode
    module Query
      class QueryProxyPreloader
        attr_reader :queued_methods, :caller, :target_id, :child_id, :rel_id
        delegate :each, :each_with_rel, :each_rel, :to_a, :first, :last, :to_cypher, to: :caller

        def initialize(query_proxy, given_child_id)
          @caller = query_proxy
          @target_id = caller.identity
          @child_id = child_id || :"#{target_id}_child"
          @queued_methods = {}
        end

        def initial_queue(association_name, given_child_id, given_rel_id)
          @child_id = given_child_id || child_id
          @rel_id = given_rel_id || caller.rel_var
          @caller = caller.query.proxy_as_optional(caller.model, target_id).send(association_name, child_id, given_rel_id)
          caller.instance_variable_set(:@preloader, self)
          queue association_name
        end

        def queue(method_name, *args)
          # I think that the rel ids need to be stored in args for each_with_rel to work
          queued_methods[method_name] = args
          self
        end

        def replay(returned_node, child)
          @chained_node = returned_node
          queued_methods.each { |method, args| @chained_node_association = @chained_node.send(method, *args) }
          cypher_string = @chained_node_association.to_cypher_with_params([@chained_node_association.identity])
          returned_node.association_instance_set(cypher_string, child, returned_node.class.associations[queued_methods.keys.first])
        end

        def replay_with_rel(returned_node, rel, child, child_rel)
          @chained_node = returned_node
          queued_methods.each { |method, args| @chained_node_association = @chained_node.send(method, *args) }
          puts "replay cypher #{@chained_node_association.to_cypher_with_params([@chained_node_association.identity])}"
          puts "rel_id #{rel_id}"
          cypher_string = @chained_node_association.to_cypher_with_params([@chained_node_association.identity, ])
          puts "cypher_string #{cypher_string}"
          stash = [child, child_rel]
          returned_node.association_instance_set(cypher_string, stash, returned_node.class.associations[queued_methods.keys.first])
        end
      end
    end
  end
end
