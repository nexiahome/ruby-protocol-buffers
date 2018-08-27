require 'protocol_buffers/runtime/rpc'
require 'protocol_buffers/compiler/file_descriptor_to_ruby'
require 'protocol_buffers/compiler/fully_qualified_name'

module ProtocolBuffers
  class ServiceRegistry
    def self.register_service(fully_qualified_name, handler_factory)
      return nil unless fully_qualified_name && handler_factory
      @handler_factory_registry ||= Hash.new
      @handler_factory_registry = @handler_factory_registry.dup
      @handler_factory_registry[fully_qualified_name] = handler_factory
      @handler_factory_registry.freeze
    end

    def self.find(fully_qualified_name)
      return nil if fully_qualified_name.nil?
      return nil if @handler_factory_registry.nil?
      service_klass = self.to_class(fully_qualified_name)
      handler_factory = (@handler_factory_registry)[fully_qualified_name]
      service_klass.create_service(handler_factory.call)
    end

    def self.number_of_registered_services
      (@handler_factory_registry || {}).keys.length
    end

    def self.registered_services
      (@handler_factory_registry || {}).keys
    end

    def self.to_class(fully_qualified_name)
      ProtocolBuffers::FullyQualifiedName.to_class(fully_qualified_name)
    end
  end
end

module ProtocolBuffers
  class Service

    private_class_method :new

    def initialize(handler = nil)
      @handler = handler
    end

    def self.create_service(handler)
      new(handler)
    end

    def ensure_handler_defined!
      raise "No handler defined for #{self}\n #{Exception.new.backtrace}" unless @handler
    end

    def ensure_correct_request_type!(method_name, message)
      raise "Request Type Error: #{message} must be an instance of #{types_for(method_name)[:request]}" unless message.instance_of?(types_for(method_name)[:request])
    end

    def self.set_fully_qualified_name(name)
      @fully_qualified_name = name.dup.freeze
    end

    def self.fully_qualified_name
      @fully_qualified_name
    end

    def self.rpcs
      @rpcs
    end

    def self.rpc(name, proto_name, request_type, response_type)
      @rpcs ||= Array.new
      @rpcs = @rpcs.dup
      @rpcs << Rpc.new(name.to_sym, proto_name, request_type, response_type, self).freeze
      cache_rpc_argument_types(name, proto_name, request_type, response_type)
      @rpcs.freeze
    end

    def self.cache_rpc_argument_types(name, proto_name, request_type, response_type)
      @types_name ||= Hash.new
      @types_name = @types_name.dup
      @types_name[name] = {request: request_type, response: response_type}
      @types_name.freeze
    end

    def self.types_for(rpc_name)
      (@types_name || Hash.new)[rpc_name]
    end

    def types_for(rpc_name)
      self.class.types_for(rpc_name)
    end
  end
end