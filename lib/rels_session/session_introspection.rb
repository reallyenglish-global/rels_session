# frozen_string_literal: true

module RelsSession
  # Helpers to infer attributes from serialized session payloads.
  module SessionIntrospection
    extend self

    STAGES = %i[anonymous authenticated in_course].freeze
    COURSE_KEYS = %i[course_id course_uuid].freeze
    SIGNED_IN_KEYS = ["warden.user.user.key", :"warden.user.user.key"].freeze

    def normalize_stage(stage)
      symbol = stage.to_sym
      return symbol if STAGES.include?(symbol)

      raise ArgumentError, "Unknown session stage: #{stage}"
    end

    def stage(payload)
      payload ||= {}
      return :anonymous unless signed_in?(payload)

      course_id(payload) ? :in_course : :authenticated
    end

    def course_id(payload)
      payload ||= {}
      COURSE_KEYS.each do |key|
        value = fetch_value(payload, key)
        return value if presence(value)
      end

      meta = meta_payload(payload)
      return unless meta.is_a?(Hash)

      COURSE_KEYS.each do |key|
        value = fetch_value(meta, key)
        return value if presence(value)
      end

      nil
    end

    def signed_in?(payload)
      SIGNED_IN_KEYS.any? { |key| presence(fetch_value(payload, key)) }
    end

    def meta_payload(payload)
      fetch_value(payload, :meta)
    end

    def fetch_value(payload, key)
      return unless payload.respond_to?(:[])

      string_key = key.to_s
      payload[string_key] || payload[key]
    rescue KeyError
      nil
    end

    def presence(value)
      return nil if value.nil?
      return nil if value.respond_to?(:empty?) && value.empty?

      value
    end
  end
end
