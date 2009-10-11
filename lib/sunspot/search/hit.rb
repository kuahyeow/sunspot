module Sunspot
  class Search
    # 
    # Hit objects represent the raw information returned by Solr for a single
    # document. As well as the primary key and class name, hit objects give
    # access to stored field values, keyword relevance score, and geographical
    # distance (for geographical search).
    #
    class Hit
      SPECIAL_KEYS = Set.new(%w(id type score)) #:nodoc:

      # 
      # Primary key of object associated with this hit, as string.
      #
      attr_reader :primary_key
      # 
      # Class name of object associated with this hit, as string.
      #
      attr_reader :class_name
      # 
      # Keyword relevance score associated with this result. Nil if this hit
      # is not from a keyword search.
      #
      attr_reader :score
      #
      # For geographical searches, this is the distance between the search
      # centerpoint and the document's location. Otherwise, it's nil.
      # 
      attr_reader :distance

      attr_writer :instance #:nodoc:

      def initialize(raw_hit, highlights, search) #:nodoc:
        @class_name, @primary_key = *raw_hit['id'].match(/([^ ]+) (.+)/)[1..2]
        @score = raw_hit['score']
        @distance = raw_hit['geo_distance'].to_f if raw_hit['geo_distance']
        @search = search
        @stored_values = raw_hit
        @stored_cache = {}
        @highlights = highlights
      end
      
      #
      # Returns all highlights for this hit when called without parameters.
      # When a field_name is provided, returns only the highlight for this field.
      #
      def highlights(field_name = nil)
        if field_name.nil?
          highlights_cache.values.flatten 
        else
          highlights_cache[field_name.to_sym]
        end
      end

      # 
      # Retrieve stored field value. For any attribute field configured with
      # :stored => true, the Hit object will contain the stored value for
      # that field. The value of this field will be typecast according to the
      # type of the field.
      #
      # ==== Parameters
      #
      # field_name<Symbol>::
      #   The name of the field for which to retrieve the stored value.
      #
      def stored(field_name)
        @stored_cache[field_name.to_sym] ||=
          begin
            field = setup.field(field_name)
            field.cast(@stored_values[field.indexed_name])
          end
      end

      # 
      # Retrieve the instance associated with this hit. This is lazy-loaded, but
      # the first time it is called on any hit, all the hits for the search will
      # load their instances using the adapter's #load_all method.
      #
      def instance
        if @instance.nil?
          @search.populate_hits!
        end
        @instance
      end

      def inspect #:nodoc:
        "#<Sunspot::Search::Hit:#{@class_name} #{@primary_key}>"
      end

      private

      def setup
        @setup ||= Sunspot::Setup.for(@class_name)
      end

      def highlights_cache
        @highlights_cache ||=
          begin
            cache = {}
            if @highlights
              @highlights.each_pair do |indexed_field_name, highlight_strings|
                field_name = indexed_field_name.sub(/_[a-z]+$/, '').to_sym
                cache[field_name] = highlight_strings.map do |highlight_string|
                  Highlight.new(field_name, highlight_string)
                end
              end
            end
            cache
          end
      end
    end
  end
end
