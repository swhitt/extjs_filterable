# ExtjsFilterable allows the use of the Ext.ux.grid.GridFilters plugin easily with an
# ActiveRecord model. Depends on Mislav's will_paginate gem.
#
# Author:: Steve Gulics and Steve Whittaker
#
# ExtjsFilterable should be set-up in the model using the +extjs_filterable+ method:
# 
#   class Person < ActiveRecord::Base
#     extjs_filterable :include => [:address, :account], :columns => {:address => 'address.description'}
#   end
#  
#   Person.paginate_by_filter(params)
# 
#
# See the +extjs_filterable+ documentation for more details.

# The base module that gets included in ActiveRecord::Base.
module ExtjsFilterable
  VERSION = '0.1'
  
  class << self
    def included(base)
      base.extend ClassMethods
    end
  end
  
  module ClassMethods
    # +extjs_filterable+ sets the model up for use with this plugin. There are a number of options you can 
    # set to change the behavior of the plugin:
    # * +columns+: Often times, the dataIndex used in an ExtJS store does not map 1:1 to a column name,
    #   or it may be in an entirely different table. This hash allows the mapping from dataIndex to sql selector.
    # * +per_page+: Sets the default per_page used by will_paginate and the plugin. If will_paginate is already set
    #   to use a certain number, uses that. If nothing is specified, defaults to 100.
    # * +include+: An array that contains the associations to load.
    def extjs_filterable(merge_opts=nil)
      old_per_page = class_variable_get(:@@per_page) rescue nil
      opts = { :per_page => (old_per_page || 100), :columns => {}, :include => []}
      opts.merge!(merge_opts) if merge_opts
      
      class_variable_set(:@@per_page, opts[:per_page])
      
      write_inheritable_attribute(:extjs_filterable_options, opts)
    end
    
    # +filter_and_sort_options+ will return the hash of the options that are meant to be sent to will_paginate when
    # using the +paginate_by_filter+ method. 
    def filter_and_sort_options(opts={})
      limit = opts[:limit].try(:to_i) || class_variable_get(:@@per_page) rescue 100
      page =  ((opts[:start].try(:to_i) || 0) / limit) + 1
      
      if opts[:sort].blank?
        sort = 'created_at'
      else
        if extjs_filterable_options[:columns][opts[:sort]]
          sort = "#{extjs_filterable_options[:columns][opts[:sort]]} #{opts[:dir]}"
        else
          sort = "#{opts[:sort]} #{opts[:dir]}"
        end
      end
      
      conditions = ["#{primary_key} is not null"]
      values = []
      
      opts[:filter].try(:each_pair) do |index,f|
        field = f[:field]
        type  = f[:data][:type]
        value = f[:data][:value]

        field = extjs_filterable_options[:columns][field]   if extjs_filterable_options[:columns][field]
      
        case type
        when 'string'
          conditions << "UPPER(#{connection.quote_column_name(field)}) like ?"
          values     << "%#{value.upcase}%"
        when 'list'
          conditions << "#{connection.quote_column_name(field)} IN (?)"
          values << value.split(',')
        end
      
      end
      
      {:page => page, :per_page => limit, :order => sort, :include => extjs_filterable_options[:include],
        :conditions => [conditions.join(" and ")].concat(values)}
    end
    
    # +paginate_by_filter+ is the main method used in controllers. Uses the options and parameters 
    # passed in, proccesses them and then passes them to will_paginate.
    def paginate_by_filter(opts={})
      paginate(filter_and_sort_options(opts))
    end
    
    # for will_paginate's default +per_page+
    def per_page
      @@per_page rescue nil
    end
    
    # Returns the options stored by the plugin.
    def extjs_filterable_options
      read_inheritable_attribute(:extjs_filterable_options)
    end
    
  end
end

