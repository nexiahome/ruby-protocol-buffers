module ProtocolBuffers
  class FullyQualifiedName
    def self.to_class(fully_qualified_name)
      return nil if fully_qualified_name.nil?
      service_typename(fully_qualified_name.to_s).split('::').inject(Object) { |mod, class_name|
        raise CompileError, "Unknown fully qualified name #{fully_qualified_name}" if mod.nil?
        mod.const_get(class_name) if mod.const_defined?(class_name)
      }
    end

    def self.service_typename(type_name)
      type_name.split(".").map { |t| camelize(t) }.join("::")
    end

    def self.camelize(lower_case_and_underscored_word)
      lower_case_and_underscored_word.to_s.gsub(/(?:^|_)(.)/) { $1.upcase }
    end

    def self.underscore(camelized_word)
      word = camelized_word.to_s.dup
      word.gsub!(/::/, '/')
      word.gsub!(/(?:([A-Za-z\d])|^)((?=\a)\b)(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def initialize(package, name)
      @fully_qualified_name = (package == nil || package.empty? ? name : "#{package}.#{name}")
    end

    def to_s
      @fully_qualified_name
    end
  end
end
