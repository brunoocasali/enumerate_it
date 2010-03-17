# encoding: utf-8

# Renum - Ruby Enumerations
#
# Author: Cássio Marques - cassiommc at gmail
#
# = Description
#
# Ok, I know there are a lot of different solutions to this problem. But none of them solved my problem,
# so here's Renum. I needed to build a Rails application around a legacy database and this database was
# filled with those small, unchangeable tables used to create foreign key constraints everywhere. 
#
# == For example:
#
#      Table "public.relationshipstatus"
#   Column     |     Type      | Modifiers 
# -------------+---------------+-----------
#  code        | character(1)  | not null
#  description | character(11) | 
# Indexes:
#     "relationshipstatus_pkey" PRIMARY KEY, btree (code)
#
#  select * from relationshipstatus;
#  code   |  description  
# --------+--------------
#  1      | Single   
#  2      | Married     
#  3      | Widow
#  4      | Divorced 
#  
# And then I had things like a people table with a 'relationship_status' column with a foreign key 
# pointing to the relationshipstatus table.
#
# While this is a good thing from the database normalization perspective, managing this values in
# my tests was very hard. More than this, referencing them in my code using magic numbers was terrible
# and meaningless: What's does it mean when we say that someone or something is '2'?
#
# Enter Renum.
#
# = Creating enumerations
#
# Enumerations are created as models, but you can put then anywhere in your application. In Rails 
# applications, I put them inside models/. 
#
# class RelationshipStatus < Renum::Base
#   associate_values(
#     :single   => [1, 'Single'],
#     :married  => [2, 'Married'],
#     :widow    => [3, 'Widow'],
#     :divorced => [4, 'Divorced'],
#   )
# end
#
# This will create some nice stuff:
#
# - Each enumeration's value will turn into a constant:
#
# RelationshipsStatus::SINGLE # returns 1
# RelationshipStatus::MARRIED # returns 2 and so on...
#
# - You can retrieve a list with all the enumeration codes:
#
# RelationshipStatus.list # [1,2,3,4]
#
# You can get an array of options, ready to use with the 'select', 'select_tag', etc family of Rails helpers.
#
# RelationshipStatus.to_a # [["Divorced", 4],["Married", 2],["Single", 1],["Widow", 3]]
#
# - You can manipulate the has used to create the enumeration:
#
# RelationshipStatus.enumeration # returns the exact hash used to define the enumeration
#
# = Using enumerations
#
# The cool part is that you can use these enumerations with any class, be it an ActiveRecord instance
# or not.
#
# class Person
#   include Renum
#   attr_accessor :relationship_status
#
#   has_enumeration_for :relationship_status, :with => RelationshipStatus
# end
#
# This will create: 
#
# - A humanized description for the values of the enumerated attribute:
#
# p = Person.new
# p.relationship_status = RelationshipStatus::DIVORCED
# p.relationsip_status_humanize # => 'Divorced'
# 
# - If your class can manage validations and responds to :validates_inclusion_of, it will create this
# validation:
#
# class Person < ActiveRecord::Base
#   has_enumeration_for :relationship_status, :with => RelationshipStatus
# end
#
# p = Person.new :relationship_status => 6 # => there is no '6' value in the enumeration
# p.valid? # => false
# p.errors[:relationship_status] # => "is not included in the list"
#
# Remember that in Rails 3 you can add validations to any kind of class and not only to those derived from 
# ActiveRecord::Base.
#
# = Using with Rails/ActiveRecord
# 
# * Create an initializer with the following code:
# 
# ActiveRecord::Base.send :include, Renum
# 
# * Add the 'renum' gem as a dependency in your environment.rb (Rails 2.3.x) or Gemfile (if you're using Bundler)
#
# = Why did you reinvent the wheel?
#
# There are other similar solutions to the problem out there, but I could not find one that
# worked both with strings and integers as the enumerations' codes. I had both situations in 
# my legacy database. 
#
# = Why defining enumerations outside the class that used it?
#
# - I think it's cleaner.
# - You can add behaviour to the enumeration class.
# - You can reuse the enumeration inside other classes.
# 
module Renum
  class Base
    @@registered_enumerations = {}

    def self.associate_values(values_hash)
      register_enumeration values_hash
      values_hash.each_pair { |value_name, attributes| define_enumeration_constant value_name, attributes[0] }
      define_enumeration_list values_hash
    end 

    private
    def self.register_enumeration(values_hash)
      @@registered_enumerations[self] = values_hash
    end

    def self.define_enumeration_constant(name, value)
      const_set name.to_s.upcase, value
    end

    def self.define_enumeration_list(values_hash)
      def self.list 
        @@registered_enumerations[self].values.map { |value| value[0] }.sort
      end

      def self.enumeration
        @@registered_enumerations[self]
      end

      def self.to_a
        @@registered_enumerations[self].values.map {|value| value.reverse }.sort_by { |value| value[0] }
      end
    end
  end

  module ClassMethods
    def has_enumeration_for(attribute, options)
      if self.respond_to? :validates_inclusion_of
        validates_inclusion_of attribute, :in => options[:with].list, :allow_blank => true
      end
      create_enumeration_humanize_method options[:with], attribute
    end

    private
    def create_enumeration_humanize_method(klass, attribute_name)
      class_eval do
        define_method "#{attribute_name}_humanize" do
          values = klass.enumeration.values.detect { |v| v[0] == self.send(attribute_name) }
          values ? values[1] : nil
        end
      end
    end    
  end

  def self.included(receiver)
    receiver.extend ClassMethods
  end
end

