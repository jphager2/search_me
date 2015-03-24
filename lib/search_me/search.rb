module SearchMe
  module Search
    def search_attributes 
      @search_attributes ||= default_hash 
    end

    def default_hash
      Hash.new { |h,k| 
        h[k] = (k == :simple ? [] : Hash.new { |nh,nk| nh[nk] = [] })
      }
    end

    def attr_search(*attributes, type: :simple)
      unless ([:simple] + self.reflections.keys).include?(type)
        raise ArgumentError, 'incorect type given'
      end

      search_attributes_hash!(attributes, type, @search_attributes)
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
      hash
    end

    def search_me(attribute, term)
      self.where(simple_search_where_condition(attribute, term))
    end

    def search(term)
      @joiner = :or
      self.simple_search(term).reflection_search(term)
    end

    def joiner 
      @joiner ||= :or
      " #{@joiner.upcase} "
    end

    def advanced_search(search_terms)
      sanitize_params!(search_terms) 
      @joiner = :and

      hash = default_hash
      search_terms.each do |type, attributes|
        search_attributes_hash!(attributes.keys,type,hash)
      end
      @this_search_attributes = hash

      @this_search_attributes.keys.map { |type|
        case type
        when :simple
          @this_search_attributes[type].map { |attribute|
            term = search_terms[type][attribute]
            simple_search_where_condition(attribute, term)           
          }.join(joiner)
        when :belongs_to
          self.advanced_search_reflection_group(type,search_terms) {
            |reflection,objs|
            "#{reflection.name}_id IN (#{objs.ids.join(',')})"
          }
        when :has_many
          self.advanced_search_reflection_group(type,search_terms) {
            |reflection,objs|
            f_key = reflection.options
              .fetch(:foreign_key) { "#{self.to_s.underscore}_id" }

            "id IN (#{objs.map(&f_key.to_sym).join(',')})"
          }
        when :has_many_through
          warn 'WARNING: has_many_through relationships not available'
        end
      }.join(joiner)
    end

    def reflection_search(term)
      macro_groups = search_attributes
      macro_groups.delete(:simple)
      @this_search_attributes = macro_groups

      condition = macro_groups.keys.map { |type|
        case type
        when :belongs_to
          self.search_reflection_group(type, term) { |reflection, objs|
            "#{reflection.name}_id IN (#{objs.ids.join(',')})"
          }
        when :has_many
          self.search_reflection_group(type, term) { |reflection, objs|
            f_key = reflection.options
              .fetch(:foreign_key) { "#{self.to_s.underscore}_id" }

            "id IN (#{objs.map(&f_key.to_sym).join(',')})"
          }
        when :has_many_through
          warn 'WARNING: has_many_through relationships not available'
        end
      }.compact.join(joiner)

      self.where(condition)
    end

    def map_reflection_group(type, outer_block)
      @this_search_attributes[type].map { |reflection, attributes|
        reflection = self.reflections[reflection]
        klass      = klass_for_reflection(reflection)

        reflection_condition = yield(attributes,klass,reflection)
          .join(joiner)
        search_res = klass.where(reflection_condition)

        outer_block.call(reflection, search_res)
      }.join(joiner)
    end

    def search_reflection_group(type, term, &block)
      map_reflection_group(type, block) do |attributes,klass,_|
        attributes.map { |attribute|
          klass.simple_search_where_condition(attribute, term)
        }
      end
    end

    def advanced_search_reflection_group(type, search_terms, &block)
      map_reflection_group(type, block) do |attributes,klass,reflection|
        attributes.map { |attribute|
          term = search_terms[reflection.name][attribute]
          klass.simple_search_where_condition(attribute, term)
        }
      end
    end

    def simple_search(term)
      condition = search_attributes[:simple].map { |attribute|
        simple_search_where_condition(attribute, term)
      }.join(joiner)
      self.where(condition)
    end

    def simple_search_where_condition(attribute, term)
      "CAST(#{self.table_name}.#{attribute} AS CHAR) LIKE '%#{term}%'"
    end

    def klass_for_reflection(reflection)
      if name = reflection.options[:class_name]
        name.constantize
      else
        reflection.name.to_s.camelize.singularize.constantize
      end
    end

    def sanitize_params!(params)
      params.each {|k,v| params.delete(k) if v.blank? && !(v == false)}
    end
  end
end
