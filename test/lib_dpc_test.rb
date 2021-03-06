require 'test_helper'

describe Prosody do
  def setup
    FileUtils.mkdir_p('config')
    ENV['PATH'] = 'test/scripts'
  end

  def test_working_setup
    assert_equal 'Startup', %x(prosody)
    assert_equal 'Prosody 0.9.0', %x(prosodyctl)
  end

  def test_dpc
    pid = Prosody.start
    assert pid > 0, msg = "Prosody wasn't forked correctly"
  end
end
