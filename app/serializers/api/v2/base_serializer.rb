# frozen_string_literal: true

module API
  module V2
    # Base serializer providing consistent serialization patterns for all v2 API
    # resources. Each subclass defines a SCHEMA hash of { field_name: source } where
    # source can be a method symbol, a proc, or a nested serializer class.
    #
    # Usage:
    #   OrganizationSerializer.serialize(org, include: [:servers])
    #   OrganizationSerializer.serialize_collection(orgs, fields: [:id, :name])
    #
    class BaseSerializer

      class << self

        # Serialize a single object
        def serialize(object, include: nil, fields: nil, context: {})
          return nil if object.nil?

          fields ||= default_fields
          result = {}

          fields.each do |field|
            next unless schema.key?(field)

            result[field] = resolve_field(object, field, context)
          end

          # Handle expansions/inclusions
          if include.present?
            includes = Array(include)
            includes.each do |rel|
              next unless inclusions.key?(rel)

              inclusion = inclusions[rel]
              related = if inclusion[:resolver]
                          inclusion[:resolver].call(object, context)
                        elsif object.respond_to?(rel)
                          object.public_send(rel)
                        end

              next unless related

              serializer = inclusion[:serializer]
              result[rel] = if related.respond_to?(:map)
                              serializer.serialize_collection(related, context: context)
                            else
                              serializer.serialize(related, context: context)
                            end
            end
          end

          result
        end

        # Serialize a collection of objects
        def serialize_collection(objects, include: nil, fields: nil, context: {})
          return [] if objects.nil?

          objects.map { |obj| serialize(obj, include: include, fields: fields, context: context) }
        end

        # The schema defines which fields are available and how to resolve them
        def schema
          self::SCHEMA
        rescue NameError
          {}
        end

        # Available inclusions (nested resources)
        def inclusions
          self::INCLUSIONS
        rescue NameError
          {}
        end

        # Default fields returned when none specified
        def default_fields
          self::DEFAULT_FIELDS
        rescue NameError
          schema.keys
        end

        private

        def resolve_field(object, field, context)
          source = schema[field]
          case source
          when Symbol
            object.public_send(source)
          when Proc
            if source.arity == 2
              source.call(object, context)
            else
              source.call(object)
            end
          else
            object.public_send(field)
          end
        end

      end

    end
  end
end
