# encoding: utf-8

# EnumerateIt - Ruby Enumerations
#
# Author: Cássio Marques - cassiommc at gmail
#
# = Description
#
# Ok, I know there are a lot of different solutions to this problem. But none of them solved my problem,
# so here's EnumerateIt. I needed to build a Rails application around a legacy database and this database was
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
# Enter EnumerateIt.
#
# = Creating enumerations
#
# Enumerations are created as models, but you can put then anywhere in your application. In Rails
# applications, I put them inside models/.
#
# class RelationshipStatus < EnumerateIt::Base
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
# You can retrive a list with values for a group of enumeration constants
#
# RelationshipStatus.values_for %w(MARRIED SINGLE) # [2, 1]
#
# You can retrieve the value for a specific enumeration constant:
#
# RelationshipStatus.value_for("MARRIED") # 2
#
# You can iterate over the list of the enumeration's values:
#
#   RelationshipStatus.each_value { |value| # ... }
#
# You can iterate over the list of the enumeration's translations:
#
#   RelationshipStatus.each_translation { |translation| # ... }
#
# You can retrieve the symbol used to declare a specific enumeration value:
#
# RelationshipStatus.key_for(RelationshioStatus::MARRIED) # :married
#
# - You can manipulate the hash used to create the enumeration:
#
# RelationshipStatus.enumeration # returns the exact hash used to define the enumeration
#
# You can also create enumerations in the following ways:
#
# * Passing an array of symbols, so that the respective value for each symbol will be the stringified version of the symbol itself:
#
#    class RelationshipStatus < EnumerateIt::Base
#      associate_values :married, :single
#    end
#
#    RelationshipStatus::MARRIED # returns "married" and so on
#
# * Passing hashes where the value for each key/pair does not include a translation. In this case, the I18n feature will be used (more on this below):
#
#    class RelationshipStatus < EnumerateIt::Base
#      associate_values :married => 1, :single => 2
#    end
#
# = Using enumerations
#
# The cool part is that you can use these enumerations with any class, be it an ActiveRecord instance
# or not.
#
# class Person
#   extend EnumerateIt
#   attr_accessor :relationship_status
#
#   has_enumeration_for :relationship_status, :with => RelationshipStatus
# end
#
# The :with option is not required. If you ommit it, EnumerateIt will try to load an
# enumeration class based on the camelized attribute name.
#
# This will create:
#
# - A humanized description for the values of the enumerated attribute:
#
# p = Person.new
# p.relationship_status = RelationshipStatus::DIVORCED
# p.relationship_status_humanize # => 'Divorced'
#
# - If you don't supply a humanized string to represent an option, EnumerateIt will use a 'humanized'
# version of the hash's key to humanize the attribute's value
#
#  class RelationshipStatus < EnumerateIt::Base
#    associate_values(
#      :married => 1,
#      :single => 2
#    )
#  end
#
#  p = Person.new
#  p.relationship_status = RelationshipStatus::MARRIED
#  p.relationship_status_humanize # => 'Married'
#
# - The associated enumerations can be retrieved with the 'enumerations' class method.
#  Person.enumerations[:relationship_status] # => RelationshipStatus
#
# - If you pass the :create_helpers option as 'true', it will create a helper method for each enumeration
#  option (this option defaults to false):
#
#  class Person < ActiveRecord::Base
#    has_enumeration_for :relationship_status, :with => RelationshipStatus, :create_helpers => true
#  end
#
#  p = Person.new
#  p.relationship_status = RelationshipStatus::MARRIED
#  p.married? #=> true
#  p.divorced? #=> false
#
# - It's also possible to "namespace" the created helper methods, passing a hash to the :create_helpers option.
#  This can be useful when two or more of the enumerations used share the same constants.
#
#  class Person < ActiveRecord::Base
#    has_enumeration_for :relationship_status, :with => RelationshipStatus, :create_helpers => { :prefix => true }
#  end
#
#  p = Person.new
#  p.relationship_status = RelationshipStatus::MARRIED
#  p.relationship_status_married? #=> true
#  p.relationship_status_divoced? #=> false
#
# - You can define polymorphic behavior for the enum values, so you can define a class for each of
# them:
#
# class RelationshipStatus < EnumerateIt::Base
#   associate_values :married, :single
#
#   class Married
#     def saturday_night
#       "At home with the kids"
#     end
#   end
#
#   class Single
#     def saturday_night
#       "Party Hard!"
#     end
#   end
# end
#
#  class Person < ActiveRecord::Base
#    has_enumeration_for :relationship_status, :with => RelationshipStatus, :create_helpers => { :polymorphic => true }
#  end
#
#  p = Person.new
#  p.relationship_status = RelationshipStatus::MARRIED
#  p.relationship_status_object.saturday_night # => "At home with the kids"
#
#  p.relationship_status = RelationshipStatus::SINGLE
#  p.relationship_status_object.saturday_night # => "Party Hard!"
#
# You can also change the suffix '_object', using the :suffix option:
#
#  class Person < ActiveRecord::Base
#    has_enumeration_for :relationship_status, :with => RelationshipStatus, :create_helpers => { :polymorphic => { :suffix => "_mode" } }
#  end
#
#  p.relationship_status_mode.saturday_night
#
# - If you pass the :create_scopes option as 'true', it will create a scope method for each enumeration option (this option defaults to false):
#
#   class Person < ActiveRecord::Base
#     has_enumeration_for :relationship_status, :with => RelationshipStatus, :create_scopes => true
#   end
#
#   Person.married.to_sql # => SELECT "people".* FROM "people" WHERE "people"."relationship_status" = 1
#
# NOTE: The :create_scopes option can only be used for Rails.version >= 3.0.0.
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
# - Also, if your class responds to :validates_presence_of, you can pass an :required option and this validation
# will be added to your attribute:
#
# class Person < ActiveRecord::Base
#   has_enumeration_for :relationship_status, :required => true # => defaults to false
# end
#
# Remember that in Rails 3 you can add validations to any kind of class and not only to those derived from
# ActiveRecord::Base.
#
# = Using with Rails/ActiveRecord
#
# * Create an initializer with the following code:
#
# ActiveRecord::Base.extend EnumerateIt
#
# * Add the 'enumerate_it' gem as a dependency in your environment.rb (Rails 2.3.x) or Gemfile (if you're using Bundler)
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

require 'active_support/core_ext/class/attribute'
require 'enumerate_it/base'
require 'enumerate_it/class_methods'

module EnumerateIt
  def self.extended(receiver)
    receiver.class_attribute :enumerations, instance_writer: false, instance_reader: false
    receiver.enumerations = {}

    receiver.extend ClassMethods
  end
end


