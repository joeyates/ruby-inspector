require 'test/unit'
require_relative '../lib/ruby-inspector/rdoc-reader'

class TestRDocReader < Test::Unit::TestCase
  def test_path
    # make sure the RDoc::RI::Paths::SYSDIR constant exists
    assert_nothing_raised { RDocReader::Method.base_path }
    sRDocPath = RDocReader::Method.base_path
    assert(Dir.exist?(sRDocPath))
  end

  def test_missing
    # Ask for docs for a non-existent method
    rdr = RDocReader.find(String, true, 'wibble')
    assert_kind_of(rdr, RDocReader::Missing)
  end
  
  def test_present
    rdr = RDocReader.find(String, false, 'center')
    assert_kind_of(rdr, RDocReader::Method)
    assert(File.exist?(rdr.path_name))
    assert_not_equal(rdr.full_name, '')
    assert_equal(rdr.class_method, false)
    assert_not_equal(rdr.to_s, '')
  end
end
