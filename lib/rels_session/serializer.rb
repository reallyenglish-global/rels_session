# frozen_string_literal: true

require "json"
require "oj"

module RelsSession
  module Serializers
    module_function

    def for(name)
      case name.to_sym
      when :json
        JsonSerializer.new
      when :oj
        OjSerializer.new
      else
        raise ArgumentError, "Unsupported serializer: #{name}"
      end
    end

    class JsonSerializer
      def dump(payload)
        JSON.generate(payload)
      end

      def load(payload)
        JSON.parse(payload)
      end
    end

    class OjSerializer
      def dump(payload)
        Oj.dump(payload, mode: :compat)
      end

      def load(payload)
        Oj.load(payload)
      end
    end
  end
end
