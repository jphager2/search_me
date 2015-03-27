module SearchMe
  module Search
    def search_attributes 
      @search_attributes ||= default_hash
    end

    def advanced_search_blocks
      @advanced_search_blocks ||= default_hash(:never_a_key_like_this)
    end

    def default_hash(flat_key = :simple)
      Hash.new { |h,k| 
        h[k] = (k == flat_key ? [] : Hash.new { |nh,nk| nh[nk] = [] })
      }
    end

    def attr_search(*attributes, type: :simple)
      unless ([:simple] + self.reflections.keys).include?(type)
        raise ArgumentError, 'incorect type given'
      end

      search_attributes_hash!(attributes, type, search_attributes)
    end

    def alias_advanced_search(attribute, type: :simple, &block)
      advanced_search_blocks[type][attribute] = block
    end

    def search_attributes_hash!(attributes, type, hash = default_hash)
      if type == :simple
        hash[:simple] += attributes
        hash[:simple] = hash[:simple].uniq
      else
        reflection = self.reflections[type]
        macro      = reflection.macro
        klass      = klass_for_reflection(reflection)

        if macro == :has_many
          macro = :has_many_through if reflection.options[:through]
        end

        hash[macro][type] += attributes
        hash[macro][type] = hash[macro][type].uniq

        unless klass.kind_of?(SearchMe::Search)
          klass.extend(SearchMe::Search)
        end
      end
      hash = sanitize_params!(hash)
    end

    def search_me(attribute, term)
      self.where(simple_search_where_condition(attribute, term))
    end

    def join(array)
      array.delete_if { |condition| condition.blank? }.join(joiner)
    end

    def search(term)
      @joiner = :or
      condition = join([
        simple_search_condition(term), 
        reflection_search_condition(term)
      ])
      self.where(condition)
    end

    def joiner 
      @joiner ||= :or
      " #{@joiner.upcase} "
    end

    def advanced_search(search_terms)
      search_terms = sanitize_params!(search_terms) 
      @joiner = :and

      hash = default_hash
      search_terms.each do |type, attributes|
        search_attributes_hash!(attributes.keys,type,hash)
      end
      @this_search_attributes = hash

      conditions = @this_search_attributes.keys.map { |type|
        case type
        when :simple
          join(@this_search_attributes[type].map { |attribute|
            term = search_terms[type][attribute]
            if advanced_search_block_for?(type, attribute)
              call_advanced_search_block_for(type, attribute, term)
            else
              simple_search_where_condition(attribute, term)           
            end
          })
        when :belongs_to
          self.advanced_search_reflection_group(type,search_terms) {
            |reflection,objs|
            "#{reflection.name}_id IN (#{object_ids(objs).join(',')})"
          }
        when :has_one
          self.advanced_search_reflection_group(type,search_terms) {
            |reflection,objs|
            f_key = "#{name_for(reflection.active_record.name)}_id"

            "id IN (#{object_ids(objs, f_key).join(',')})"
          }
        when :has_many
          self.advanced_search_reflection_group(type,search_terms) {
            |reflection,objs|
            f_key = reflection.options
              .fetch(:foreign_key) { "#{self.to_s.underscore}_id" }

            "id IN (#{object_ids(objs, f_key).join(',')})"
          }
        when :has_many_through
          warn 'WARNING: has_many_through relationships not available'
        end
      }
      self.where(join(conditions))
    end

    def reflection_search_condition(term)
      macro_groups = search_attributes
      @this_search_attributes = macro_groups

      condition = macro_groups.keys.map { |type|
        case type
        when :belongs_to
          self.search_reflection_group(type, term) { |reflection, objs|
            "#{reflection.name}_id IN (#{object_ids(objs).join(',')})"
          }
        when :has_many
          self.search_reflection_group(type, term) { |reflection, objs|
            f_key = reflection.options
              .fetch(:foreign_key) { "#{self.to_s.underscore}_id" }

            "id IN (#{object_ids(objs, f_key).join(',')})"
          }
        when :has_one
          self.search_reflection_group(type, term) { |reflection, objs|
            f_key = "#{name_for(reflection.active_record.name)}_id"

            "id IN (#{object_ids(objs, f_key).join(',')})"
          }
        when :has_many_through
          warn 'WARNING: has_many_through relationships not available'
        end
      }
      join(condition)
    end


    def reflection_search(term)
      self.where(reflection_search_condition(term))
    end

    def map_reflection_group(type, outer_block)
      cond = @this_search_attributes[type].map {|reflection, attributes|
        reflection = self.reflections[reflection]
        klass      = klass_for_reflection(reflection)

        reflection_condition = join(yield(attributes,klass,reflection))
          
        search_result = klass.where(reflection_condition)

        outer_block.call(reflection, search_result)
      }
      join(cond)
    end

    def search_reflection_group(type, term, &block)
      map_reflection_group(type, block) do |attributes,klass,reflection|
        attributes.map { |attribute|
          name = reflection.name
          if advanced_search_block_for?(name, attribute)
            call_advanced_search_block_for(name, attribute, term)
          else
            klass.simple_search_where_condition(attribute, term)
          end
        }
      end
    end

    def advanced_search_reflection_group(type, search_terms, &block)
      map_reflection_group(type, block) do |attributes,klass,reflection|
        attributes.map { |attribute|
          name = reflection.name
          term = search_terms[name][attribute]
          if advanced_search_block_for?(name, attribute)
            call_advanced_search_block_for(name, attribute, term)
          else
            klass.simple_search_where_condition(attribute, term)
          end
        }
      end
    end

    def simple_search_condition(term)
      condition = search_attributes[:simple].map { |attribute|
        simple_search_where_condition(attribute, term)
      }
      join(condition)
    end

    def simple_search(term)
      self.where(simple_search_condition(term))
    end

    def simple_search_where_condition(attribute, term)
      table_column = "#{self.table_name}.#{attribute}"
      column = self.columns.find { |col| col.name == attribute.to_s }

      case column.type
      when :string, :integer, :text, :float, :decimal
        "CAST(#{table_column} AS CHAR) LIKE '%#{term}%'"
      when :boolean
        term = {
          true => "= 't'", false => "= 'f'", nil => 'IS NULL',
          1 => "= 't'", 0 => "= 'f'", '1' => "= 't'", '0' => "= 'f'"
        }.fetch(term) {
          good_args = term.keys.map(:inspect).join(',')
          error = "boolean column term must be #{good_args}"
          raise ArgumentError, error
        } 
        "#{table_column} #{term}"
      else
        warn "#{column.type} type is not supported by SearchMe::Search"
      end
    end

    def advanced_search_block_for?(type, attribute)
      !advanced_search_blocks[type].blank? && 
        !advanced_search_blocks[type][attribute].blank?
    end

    def call_advanced_search_block_for(type, attribute, term)
      advanced_search_blocks[type][attribute].call(term)
    end

    def object_ids(objects, column = nil)
      (column ? objects.map(&column.to_sym) : objects.ids) << -5318008 
    end

    def klass_for_reflection(reflection)
      if name = reflection.options[:class_name]
        constant_for(name)
      else
        constant_for(reflection.name)
      end
    end

    def name_for(constant, plural: false)
      name = constant.to_s.underscore
      name = name.singularize unless plural
      name
    end

    def constant_for(name)
      name.to_s.camelize.singularize.constantize
    end

    def sanitize_params!(params)
      params.to_hash.symbolize_keys!.each { |k,v| 
        if v.is_a?(Hash)
          params[k] = v = v.to_hash
          sanitize_params!(v) and v.symbolize_keys!
        end
        params.delete(k) if v.blank? && !(v == false)
      }
    end
  end
end
