ROOT_DIR = File.expand_path '../..', __FILE__
TMP_DIR = File.expand_path 'tmp', ROOT_DIR
FileUtils.mkdir_p TMP_DIR

module ElementExtensions
  def set_text(text)
    clear
    send_keys(text)
  end
end

class ::Selenium::WebDriver::Element
  prepend ElementExtensions
end
