# frozen_string_literal: true

require 'avro/builder/metadata'

module Avro
  module Builder
    module Types
      # This class represents a record in an Avro schema. Records may be defined
      # at the top-level or as the type for a field in a record.
      class RecordType < Avro::Builder::Types::NamedType
        include Avro::Builder::AnonymousTypes
        include Avro::Builder::Metadata

        DSL_METHODS = [:required, :optional, :extends].to_set.freeze

        dsl_attribute :doc
        dsl_attribute_alias :type_doc, :doc

        def initialize(name = nil, cache:, options: {}, field: nil, &block) # rubocop:disable Lint/MissingSuper
          # TODO: Fix missing call to super
          @avro_type_name = :record
          @name = name
          @cache = cache
          @field = field

          configure_options(options)
          instance_eval(&block) if block_given?
        end

        def dsl_method?(name)
          DSL_METHODS.include?(name)
        end

        # Add a required field to the record
        def required(name, avro_type_or_name, options = {}, &block)
          new_field = Avro::Builder::Field.new(name: name,
                                               avro_type_or_name: avro_type_or_name,
                                               record: self,
                                               cache: cache,
                                               internal: { type_namespace: namespace },
                                               options: options,
                                               &block)
          add_field(new_field)
        end

        # Add an optional field to the record. In Avro this is represented
        # as a union of null and the type specified here.
        def optional(name, avro_type_or_name, options = {}, &block)
          new_field = Avro::Builder::Field.new(name: name,
                                               avro_type_or_name: avro_type_or_name,
                                               record: self,
                                               cache: cache,
                                               internal: { type_namespace: namespace,
                                                           optional_field: true },
                                               options: options,
                                               &block)
          add_field(new_field)
        end

        # Adds fields from the record with the specified name to the current
        # record.
        def extends(name, options = {})
          fields.merge!(cache.lookup_named_type(name, options.delete(:namespace) || namespace).duplicated_fields)
        end

        def to_h(reference_state = SchemaSerializerReferenceState.new)
          reference_state.definition_or_reference(fullname) do
            attrs = {
              type: :record,
              name: name,
              namespace: namespace,
              fields: fields.values.map { |field| field.serialize(reference_state) }
            }

            self.class.dsl_attribute_names.reject do |attr|
              [:abstract, :type_name, :type_namespace, :type_aliases, :type_doc].include?(attr)
            end.each do |attr|
              attrs[attr] = send(attr)
            end

            attrs[:logicalType] = attrs.delete(:logical_type)

            attrs.reject { |_, v| v.nil? }
          end
        end
        alias_method :serialize, :to_h

        protected

        def duplicated_fields
          fields.each_with_object(Hash.new) do |(name, field), result|
            field_copy = field.dup
            result[name] = field_copy
          end
        end

        private

        # Add field, replacing any existing field with the same name.
        def add_field(field)
          fields[field.name] = field
        end

        def fields
          @fields ||= {}
        end
      end
    end
  end
end
