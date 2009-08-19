class ObjectData
  attr_reader :object, :public_instance_methods, :public_methods, :private_methods, :constants, :included_modules, :singleton_methods

  def self.load_objects(a)
    a.sort!{|k1, k2| k1.name <=> k2.name}
    a.inject({}) do |memo, o|
      memo[o.name] = ObjectData.new(o)
      memo
    end
  end

  def initialize(o)
    @object                  = o
    @public_instance_methods = o.public_instance_methods(false).sort
    @public_methods          = ObjectData.base_methods(o, 'public_methods').sort
    @private_methods         = ObjectData.base_methods(o, 'private_methods').sort
    @constants               = ObjectData.base_methods(o, 'constants').sort
    if o.class == Class
      @included_modules      = ObjectData.base_methods(o, 'included_modules').collect{ |c| c.name } 
      @singleton_methods     = o.singleton_methods(false).sort
    end
  end

  private

=begin

The *_methods methods take a parameter, which, when 'false' excludes inherited methods.
Unfortunately, 'constants' and 'included_modules' lack this parameter, so this equivalent
has been written.

Eliminates items inherited from ancestors.

This could be Object.[sMethod](all = true) if I wanted to pollute base objects!

Even the methods with the 'false' parameter don't remove overridden methods.

=end

  def self.base_methods(cls, sMethod)
    case sMethod
    when 'public_methods'
      a = cls.__send__(sMethod, false)
    when 'private_methods'
      a = cls.__send__(sMethod, false)
      cls.included_modules.each { |mod| a -= mod.private_methods }
    else
      a = cls.__send__(sMethod)
    end
    a -= cls.superclass.__send__(sMethod) if cls.respond_to?('superclass') && cls.superclass
    a
  end
end
