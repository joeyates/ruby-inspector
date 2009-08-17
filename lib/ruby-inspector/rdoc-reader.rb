class RDocReader
  require 'rdoc/ri/paths'
  require 'yaml'

  def RDocReader.find_all(cls, bClassMethod, asMethods)
    asMethods.collect{ |sMethod|
      RDocReader.find(cls, bClassMethod, sMethod)
    }
  end

  def RDocReader.find(cls, bClassMethod, sMethod)
    Method.exists?(cls, bClassMethod, sMethod) ? Method.new(cls, bClassMethod, sMethod) : Missing.new(cls, sMethod)
  end

  class Base
    def initialize(cls, sMethod)
      @cls = cls
      @method = sMethod
    end
  end

  class Missing < Base
    def to_s
      "<h2>#{ @cls.name }##{ @method }</h2>\n[Documetation missing]\n"
    end
  end

  class Method
    attr_reader :path_name, :full_name, :class, :class_method, :method, :params, :comments, :aliases

    def self.base_path
      RDoc::RI::Paths::SYSDIR
    end

    def self.encoded_name(sMethod)
      sMethod.to_s.gsub(/([^a-z\_])/i) { |m| "%%%02x" % $1.getbyte(0) }
    end

    def self.path_name(cls, bClassMethod, sMethod)
      sExtension = bClassMethod ? '-c' : '-i'
      "#{ base_path }/#{ cls.name }/#{ encoded_name(sMethod) }#{ sExtension }.yaml"
    end

    def self.exists?(cls, bClassMethod, sMethod)
      File.exist?(path_name(cls, bClassMethod, sMethod))
    end

    def initialize(cls, bClassMethod, sMethod)
      raise 'No documentation found' if not Method.exists?(cls, bClassMethod, sMethod)

      @class, @class_method, @method = cls, bClassMethod, sMethod
      @path_name = Method.path_name(@class, @class_method, @method)

      sBase = open(@path_name).read
      s = sBase.clone
      s = s.gsub(/^---.*/, '---')
      s = s.gsub(/!ruby\/[^\n]*/, '')

      h = YAML.load(s)
      @full_name = h['full_name']
      @params = h['params']
      @comments = h['comment'] || []
      @aliases = h['aliases'] || []
    end

    def to_s
      s = "<h2>#{ @full_name }</h2>\n"
      s << "<pre>#{ @params }</pre>\n"
      s << '<p>' << @comments.collect {|h| h[:body]}.join("<br/>\n") << '</p>'
      s << '<p>' << @aliases.collect {|h| h[:body]}.join("<br/>\n") << '</p>'
    end
  end

end
